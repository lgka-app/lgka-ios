"""Assemble App/AppIcon.icon (Icon Composer bundle) for LGKA+ from the flat reference icon.

The reference PNG (black background, blue lions / arch / pillars) is split into three
disjoint premultiplied-alpha layers -- lions, pillars, arch -- so iOS 26 can render the
Liquid Glass stack. The split is exact: recompositing the layers over black reproduces
the reference pixel for pixel.
"""
import json, os, subprocess, sys
import numpy as np
from PIL import Image

ROOT = '/Users/luka/Documents/lgka-ios'
REF = os.path.join(ROOT, 'branding/icon-1024.png')
BUNDLE = os.path.join(ROOT, 'App/AppIcon.icon')
ASSETS = os.path.join(BUNDLE, 'Assets')
ICTOOL = '/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool'
OUT = sys.argv[1] if len(sys.argv) > 1 else '/private/tmp/claude-501/-Users-luka-Documents-lgka-app/1e92e123-0464-44bc-83b6-5354a08bb9ec/scratchpad/icon'

os.makedirs(ASSETS, exist_ok=True)
os.makedirs(OUT, exist_ok=True)

ref = np.array(Image.open(REF).convert('RGB')).astype(np.float64)
H, W, _ = ref.shape
mask = ref.max(2) > 8

# ---- find the two background gutters that separate the arch from the side assemblies ----
ARCH_TOP, BOTTOM = 355, H - 1
guide_l, guide_r = 380.0, 644.0
Lb = np.full(H, 380.0)
Rb = np.full(H, 644.0)
for y in range(ARCH_TOP, BOTTOM + 1):
    row = mask[y]
    for side, guide in (('l', guide_l), ('r', guide_r)):
        best, bestd = None, 1e9
        x = 0
        while x < W:
            if not row[x]:
                x0 = x
                while x < W and not row[x]:
                    x += 1
                c = (x0 + x - 1) / 2.0
                if 250 < c < 780 and abs(c - guide) < bestd:
                    best, bestd = c, abs(c - guide)
            else:
                x += 1
        if best is not None and bestd < 90:
            if side == 'l':
                guide_l = best
            else:
                guide_r = best
    Lb[y], Rb[y] = guide_l, guide_r
# above the arch springing the arch has not started: push the boundaries together
Lb[:ARCH_TOP] = 512
Rb[:ARCH_TOP] = 512

xs = np.arange(W)[None, :]
arch_mask = (xs >= Lb[:, None]) & (xs <= Rb[:, None])

# plinth top: lions above, pillars below
PLINTH_Y = 505
rows = np.arange(H)[:, None]
lions = mask & ~arch_mask & (rows < PLINTH_Y)
pillars = mask & ~arch_mask & (rows >= PLINTH_Y)
arch = mask & arch_mask

assert not (lions & pillars).any() and not (lions & arch).any() and not (pillars & arch).any()
assert ((lions | pillars | arch) == mask).all()


def save(name, m):
    """Un-premultiply the reference (composited on black) into a straight-alpha layer."""
    a = ref.max(2) / 255.0
    a = np.where(m, a, 0.0)
    with np.errstate(divide='ignore', invalid='ignore'):
        rgb = np.where(a[..., None] > 0, ref / np.maximum(a[..., None], 1e-6), 0.0)
    rgb = np.clip(rgb, 0, 255)
    out = np.dstack([rgb, a * 255.0]).astype(np.uint8)
    Image.fromarray(out, 'RGBA').save(os.path.join(ASSETS, name))
    return out


save('lions.png', lions)
save('pillars.png', pillars)
save('arch.png', arch)

GLASS = os.environ.get('GLASS', '1') == '1'
SPECULAR = os.environ.get('SPECULAR', '0') == '1'


def group(name, image, specular=SPECULAR, glass=GLASS, shadow=0.0):
    return {
        'name': name,
        'specular': specular,
        'shadow': {'kind': 'neutral', 'opacity': shadow} if shadow else {'kind': 'none', 'opacity': 0.0},
        'blur-material': None,
        'translucency': {'enabled': False, 'value': 0.0},
        'lighting': 'individual',
        'layers': [{'image-name': image, 'name': name.lower(), 'glass': glass}],
    }


manifest = {
    'supported-platforms': {'squares': 'shared'},
    'fill-specializations': [
        {'value': {'solid': 'srgb:0.00000,0.00000,0.00000,1.00000'}},
        {'appearance': 'dark', 'value': {'solid': 'srgb:0.00000,0.00000,0.00000,1.00000'}},
    ],
    # front to back
    'groups': [
        group('Lions', 'lions.png'),
        group('Pillars', 'pillars.png'),
        group('Arch', 'arch.png'),
    ],
}
with open(os.path.join(BUNDLE, 'icon.json'), 'w') as f:
    json.dump(manifest, f, indent=2)
print('wrote', BUNDLE)

for rendition in ['Default', 'Dark', 'ClearDark', 'TintedDark']:
    dst = os.path.join(OUT, f'icon-{rendition}.png')
    r = subprocess.run([ICTOOL, BUNDLE, '--export-image', '--output-file', dst,
                        '--platform', 'iOS', '--rendition', rendition,
                        '--width', '1024', '--height', '1024', '--scale', '1'],
                       capture_output=True, text=True)
    print(rendition, 'ok' if r.returncode == 0 else 'FAILED: ' + r.stderr[:300])

# ---- exports for Android / stores ----
# Square 1024 PNG of the rendered default appearance, flattened on black.
d = np.array(Image.open(os.path.join(OUT, 'icon-Default.png')).convert('RGBA')).astype(float)
flat = (d[..., :3] * (d[..., 3:] / 255.0)).astype(np.uint8)
Image.fromarray(flat, 'RGB').save(os.path.join(OUT, 'lgka-icon-1024.png'))

# Transparent foreground (no background) built from the three layers.
fg = np.zeros((H, W, 4), np.float64)
for n in ('arch.png', 'pillars.png', 'lions.png'):
    l = np.array(Image.open(os.path.join(ASSETS, n)).convert('RGBA')).astype(float)
    la = l[..., 3:] / 255.0
    fg[..., :3] = l[..., :3] * la + fg[..., :3] * (1 - la)
    fg[..., 3:] = l[..., 3:] + fg[..., 3:] * (1 - la)
Image.fromarray(np.clip(fg, 0, 255).astype(np.uint8), 'RGBA').save(os.path.join(OUT, 'lgka-icon-foreground-1024.png'))
print('exported', OUT)
