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

    // ── stars (night, clearer skies) ──
    if (isDay < 0.5 && cloudiness < 0.6) {
        float2 cell = floor(uv * float2(90.0 * aspect, 90.0));
        float h = hash21(cell);
        if (h > 0.985) {
            float twinkle = 0.35 + 0.65 * fabs(sin(time * (0.6 + h) + h * 40.0));
            float2 f = fract(uv * float2(90.0 * aspect, 90.0)) - 0.5;
            float star = exp(-dot(f, f) * 28.0);
            col += float3(0.9, 0.93, 1.0) * star * twinkle * (1.0 - cloudiness);
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

    return half4(half3(col), 1.0h);
}
