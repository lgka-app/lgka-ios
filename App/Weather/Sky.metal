//
// GPU sky: gradient + fbm noise clouds + sun glow + twinkling stars.
// Driven via SwiftUI .colorEffect (see WeatherSky.swift).
//
#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float vnoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbm(float2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 5; i++) {
        v += amp * vnoise(p);
        p = p * 2.03 + float2(17.0, 9.2);
        amp *= 0.55;
    }
    return v;
}

[[stitchable]] half4 sky(float2 position, half4 color, float4 bounds,
                         float time, float cloudiness, float isDay) {
    float2 uv = (position - bounds.xy) / max(bounds.zw, float2(1.0, 1.0));
    float aspect = bounds.z / max(bounds.w, 1.0);

    // ── base gradient ──
    float3 dayTop = float3(0.16, 0.42, 0.82);
    float3 dayBottom = float3(0.52, 0.72, 0.94);
    float3 grayTop = float3(0.36, 0.42, 0.50);
    float3 grayBottom = float3(0.55, 0.60, 0.66);
    float3 nightTop = float3(0.015, 0.03, 0.10);
    float3 nightBottom = float3(0.08, 0.12, 0.26);

    float overcast = smoothstep(0.55, 0.95, cloudiness);
    float3 top = isDay > 0.5 ? mix(dayTop, grayTop, overcast) : nightTop;
    float3 bottom = isDay > 0.5 ? mix(dayBottom, grayBottom, overcast) : nightBottom;
    float3 col = mix(top, bottom, uv.y);

    // ── sun (day, not fully overcast) ──
    if (isDay > 0.5 && cloudiness < 0.8) {
        float2 sunPos = float2(0.78, 0.20);
        float2 d2 = (uv - sunPos) * float2(aspect, 1.0);
        float d = length(d2);
        float pulse = 0.95 + 0.05 * sin(time * 0.8);
        float glow = exp(-d * d * 28.0) * 0.55 * pulse;
        float core = exp(-d * d * 420.0) * 1.1;
        float visible = 1.0 - cloudiness * 0.85;
        col += float3(1.0, 0.86, 0.45) * (glow + core) * visible;
    }

    // ── stars (night, clearer skies) — two layers, Apple-Weather quality ──
    if (isDay < 0.5 && cloudiness < 0.6) {
        float dim = (1.0 - cloudiness) * (1.0 - smoothstep(0.55, 0.95, uv.y));
        float2 suv = uv * float2(aspect, 1.0);

        // layer 1: dense field of faint pin-prick stars
        {
            float2 g = suv * 150.0;
            float2 cell = floor(g);
            float h = hash21(cell);
            if (h > 0.90) {
                float2 starPos = cell + 0.15 + 0.7 * float2(hash21(cell + 7.0), hash21(cell + 13.0));
                float d = length(g - starPos);
                float size = 0.045 + 0.05 * hash21(cell + 3.0);
                float core = exp(-d * d / (size * size)) * 0.6;
                float tw = 0.55 + 0.45 * sin(time * (0.4 + h * 1.6) + h * 40.0);
                col += float3(0.85, 0.9, 1.0) * core * tw * dim;
            }
        }

        // layer 2: sparse bright stars with gaussian glow + diffraction spikes,
        // scanning the 3x3 neighborhood so glow is never clipped at cell edges
        {
            float2 g = suv * 34.0;
            float2 base = floor(g);
            for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                    float2 cell = base + float2(dx, dy);
                    float h = hash21(cell);
                    if (h <= 0.965) continue;
                    float2 starPos = cell + 0.2 + 0.6 * float2(hash21(cell + 7.0), hash21(cell + 13.0));
                    float2 dvec = g - starPos;
                    float d = length(dvec);
                    float mag = (h - 0.965) / 0.035; // 0..1 brightness class
                    float size = 0.05 + 0.10 * mag;
                    float tw = 0.65 + 0.35 * sin(time * (0.5 + h * 2.0) + h * 60.0);
                    float core = exp(-d * d / (size * size));
                    float glow = exp(-d * d / (size * size * 26.0)) * 0.20 * mag;
                    // 4-point diffraction spikes on the brightest stars
                    float spikes = 0.0;
                    if (mag > 0.5) {
                        float sx = exp(-fabs(dvec.x) * 26.0) * exp(-fabs(dvec.y) * 3.2);
                        float sy = exp(-fabs(dvec.y) * 26.0) * exp(-fabs(dvec.x) * 3.2);
                        spikes = (sx + sy) * 0.35 * (mag - 0.5) * 2.0;
                    }
                    // slight color temperature: cool blue-white to warm
                    float3 tint = mix(float3(0.80, 0.88, 1.0), float3(1.0, 0.92, 0.78),
                                      hash21(cell + 21.0));
                    col += tint * (core + glow + spikes) * tw * dim * (0.55 + 0.45 * mag);
                }
            }
        }
    }

    // ── clouds: two drifting fbm layers ──
    float2 p1 = uv * float2(2.6 * aspect, 5.2) + float2(time * 0.020, 0.0);
    float2 p2 = uv * float2(4.6 * aspect, 8.8) + float2(time * 0.045, 3.7);
    float n = fbm(p1) * 0.72 + fbm(p2) * 0.42;
    float threshold = 0.72 - cloudiness * 0.38;
    float shape = smoothstep(threshold, threshold + 0.32, n) * min(cloudiness * 1.25, 1.0);

    float shade = fbm(p1 + float2(0.0, 0.35)); // darker undersides
    float3 cloudDay = mix(float3(0.99, 0.99, 1.0), float3(0.72, 0.74, 0.79), shade * 0.8);
    float3 cloudNight = mix(float3(0.20, 0.22, 0.28), float3(0.10, 0.11, 0.15), shade * 0.8);
    float3 cloudCol = isDay > 0.5 ? cloudDay : cloudNight;

    col = mix(col, cloudCol, shape * 0.92);

    // dither: breaks up gradient banding (visible in dark night skies)
    float grain = hash21(position + fract(time) * 61.7) - 0.5;
    col += grain / 160.0;

    return half4(half3(col), 1.0h);
}
