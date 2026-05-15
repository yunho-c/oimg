// Wavy Backgrounds 16 — procedural GLSL recreation
// Shadertoy-compatible fragment shader.
// Paste into Shadertoy, or run in a Shadertoy-compatible VSCode shader preview.
// Expected uniforms: iResolution, iTime

#define PI 3.14159265359

// Soft value noise: used only for very subtle cloth/paper-like shading.
float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// One broad moving ribbon. Positive values are inside the ribbon.
float ribbonMask(vec2 uv, float phase, float yBase, float thickness, float amp, float freq, float tilt) {
    float x = uv.x;
    float t = iTime * 0.105;

    // Wide sine + secondary low-frequency bend gives the "slow abstract layers" look.
    float center = yBase
                 + amp * sin(freq * (x + phase + t) + 0.65 * sin(2.0 * x - t))
                 + 0.08 * sin(1.7 * x - 0.7 * t + phase * 4.0)
                 + tilt * (x - 0.5);

    float d = uv.y - center;
    return thickness - d;
}

// Soft-edged horizontal/diagonal band with a mild vertical lighting gradient.
vec3 addRibbon(vec2 uv, vec3 base, vec3 color, float mask, float softness, float shadeBias) {
    float a = smoothstep(-softness, softness, mask);

    // Slight shape shading: brighter near upper-left, darker toward lower-right.
    float shade = 1.0
                + 0.050 * (1.0 - uv.x)
                + 0.060 * uv.y
                + shadeBias;

    vec3 shaded = color * shade;
    return mix(base, shaded, a);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 res = iResolution.xy;
    vec2 uv = fragCoord / res;

    // Preserve the 16:9 composition from the source video.
    vec2 p = uv;
    p.x = (p.x - 0.5) * (res.x / res.y) + 0.5;

    float t = iTime;

    // Base: soft silver-gray field with gentle radial illumination.
    vec3 col = vec3(0.785);
    col += 0.090 * (1.0 - uv.y);
    col += 0.045 * (1.0 - uv.x);
    col += 0.035 * sin(uv.x * 2.2 + uv.y * 1.3 + t * 0.08);

    // A few very large, slow, overlapping paper-like waves.
    // Colors are intentionally close together; the video is low-contrast grayscale.
    float m1 = ribbonMask(p + vec2(0.00, 0.00), 0.00, 0.69, 0.36, 0.18, 3.15, -0.14);
    col = addRibbon(uv, col, vec3(0.835), m1, 0.070, 0.010);

    float m2 = ribbonMask(p + vec2(0.06, 0.00), 0.28, 0.39, 0.42, 0.20, 3.65, 0.10);
    col = addRibbon(uv, col, vec3(0.735), m2, 0.085, -0.010);

    float m3 = ribbonMask(p + vec2(-0.10, 0.00), 0.56, 0.08, 0.34, 0.21, 3.00, -0.03);
    col = addRibbon(uv, col, vec3(0.895), m3, 0.095, 0.030);

    float m4 = ribbonMask(p + vec2(0.18, 0.00), 0.82, 0.96, 0.30, 0.23, 2.75, 0.16);
    col = addRibbon(uv, col, vec3(0.655), m4, 0.075, -0.035);

    // Subtle darker right-side sweep that appears in later frames of the video.
    float rightSweep = smoothstep(0.72, 1.15, p.x + 0.18 * sin(2.4 * p.y + t * 0.17));
    col = mix(col, col * 0.72, rightSweep * 0.34);

    // Soft bright lower-left crescent.
    float lowerLight = smoothstep(0.78, 0.05, length((uv - vec2(0.03, 0.03)) * vec2(1.25, 0.75)));
    col += lowerLight * 0.055;

    // Very slight grain/texture to avoid a perfectly synthetic flat look.
    float n = noise(uv * res.xy * 0.55 + t * 3.0) - 0.5;
    col += n * 0.006;

    // Soft vignette, matching the darker top/right falloff in the source.
    float vignette = smoothstep(0.95, 0.25, length((uv - 0.5) * vec2(1.20, 0.95)));
    col *= mix(0.93, 1.035, vignette);

    col = clamp(col, 0.0, 1.0);
    fragColor = vec4(col, 1.0);
}
