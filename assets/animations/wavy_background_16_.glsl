#ifdef GL_ES
precision highp float;
#endif

// Wavy Backgrounds 16 - procedural GLSL approximation
// Standalone WebGL/GLSL fragment shader.
// Expected uniforms:
//   u_resolution : viewport size in pixels
//   u_time       : elapsed time in seconds
//
// The source video has a short repeating cycle of layered grayscale waves.
// Change LOOP_SECONDS if you want a slower/faster loop.

uniform vec2  u_resolution;
uniform float u_time;

#define TAU 6.28318530718
#define LOOP_SECONDS 2.85

float saturate(float x) {
    return clamp(x, 0.0, 1.0);
}

vec2 rotate2D(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float blob(vec2 p, vec2 center, vec2 scale, float radius) {
    vec2 q = (p - center) * scale;
    return exp(-dot(q, q) / max(radius * radius, 0.0001));
}

float waveCurve(vec2 p, float center, float slope, float amp, float freq, float phase) {
    return center
         + slope * p.x
         + amp * sin(freq * p.x + phase)
         + amp * 0.38 * sin(freq * 0.57 * p.x - phase * 0.52 + 1.70);
}

float fillBelowWave(vec2 p, float center, float slope, float amp, float freq, float phase, float aa) {
    float c = waveCurve(p, center, slope, amp, freq, phase);
    float d = p.y - c;
    return 1.0 - smoothstep(-aa, aa, d);
}

float fillAboveWave(vec2 p, float center, float slope, float amp, float freq, float phase, float aa) {
    float c = waveCurve(p, center, slope, amp, freq, phase);
    float d = c - p.y;
    return 1.0 - smoothstep(-aa, aa, d);
}

float waveBand(vec2 p, float center, float halfWidth, float slope, float amp, float freq, float phase, float aa) {
    float c = waveCurve(p, center, slope, amp, freq, phase);
    float d = abs(p.y - c) - halfWidth;
    return 1.0 - smoothstep(-aa, aa, d);
}

float edgeGlowFromBand(vec2 p, float center, float halfWidth, float slope, float amp, float freq, float phase, float aa) {
    float c = waveCurve(p, center, slope, amp, freq, phase);
    float d = abs(abs(p.y - c) - halfWidth);
    return 1.0 - smoothstep(0.0, aa * 18.0, d);
}

float paperTone(float base, vec2 p, float phase, vec2 hotSpot, float hotStrength) {
    float g = base;
    g += 0.030 * sin(1.65 * p.x - 0.80 * p.y + phase);
    g += 0.026 * cos(2.10 * p.y + 0.55 * phase);
    g += hotStrength * blob(p, hotSpot, vec2(0.90, 1.25), 0.62);
    return saturate(g);
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 uv  = gl_FragCoord.xy / res;

    // Aspect-correct centered coordinates. y grows upward.
    vec2 p = (gl_FragCoord.xy - 0.5 * res) / res.y;

    float phase = TAU * fract(u_time / LOOP_SECONDS);
    float aa = 1.35 / res.y;

    // Soft silver base gradient.
    float g = 0.680;
    g += 0.095 * (1.0 - uv.y);                       // lighter toward the bottom
    g += 0.018 * uv.x;
    g += 0.055 * blob(p, vec2(-0.62,  0.38), vec2(1.00, 1.25), 0.78);
    g += 0.035 * blob(p, vec2( 0.18, -0.28), vec2(1.18, 0.85), 0.86);
    g -= 0.030 * blob(p, vec2( 0.88,  0.05), vec2(0.82, 1.15), 0.92);

    vec3 col = vec3(saturate(g));

    // Darkest rear crescent on the right.
    vec2 pd = rotate2D(p + vec2(0.035 * cos(phase + 0.4), 0.030 * sin(phase * 0.8)), -0.12);
    float darkBoundary = 0.55 - 0.17 * cos(phase - 4.35)
                       + 0.120 * sin(2.10 * pd.y - 0.75 * phase + 1.10);
    float darkMask = smoothstep(-aa, aa, pd.x - darkBoundary);
    float darkTone = paperTone(0.405, pd, phase + 1.7, vec2(0.78, 0.15), 0.060);
    col = mix(col, vec3(darkTone), darkMask * 0.96);

    // Upper/back soft gray layer.
    vec2 pu = rotate2D(p + vec2(0.055 * cos(phase + 1.2), 0.020 * sin(phase)), -0.08);
    float upperMask = fillAboveWave(
        pu,
        0.315 + 0.035 * cos(phase + 0.4),
       -0.035,
        0.115,
        3.05,
        phase + 1.25,
        aa
    );
    float upperTone = paperTone(0.705, pu, phase + 0.5, vec2(-0.10, 0.36), 0.045);
    col = mix(col, vec3(upperTone), upperMask * 0.82);

    // Broad central sheet.
    vec2 pm = rotate2D(p + vec2(0.080 * cos(phase - 0.7), 0.024 * sin(phase * 1.1)), 0.025);
    float middleMask = fillBelowWave(
        pm,
        0.030 + 0.035 * sin(phase + 1.0),
        0.020,
        0.115,
        3.10,
       -phase + 0.45,
        aa
    );
    float middleTone = paperTone(0.760, pm, -phase + 0.2, vec2(0.26, 0.07), 0.055);
    col = mix(col, vec3(middleTone), middleMask * 0.74);

    // Diagonal pale sweep that appears as the cycle turns.
    float sweepGate = smoothstep(-0.20, 0.62, sin(phase - 0.45));
    vec2 ps = rotate2D(p + vec2(0.105 * cos(phase + 2.2), 0.060 * sin(phase + 1.0)), -0.56);
    float sweepCenter = -0.045 + 0.115 * sin(phase - 1.15);
    float sweepMask = waveBand(
        ps,
        sweepCenter,
        0.190,
        0.015,
        0.085,
        2.35,
        phase * 0.72 + 2.40,
        aa
    );
    float sweepTone = paperTone(0.850, ps, phase + 2.0, vec2(-0.20, 0.03), 0.085);
    col = mix(col, vec3(sweepTone), sweepMask * sweepGate * 0.94);

    float sweepEdge = edgeGlowFromBand(
        ps,
        sweepCenter,
        0.190,
        0.015,
        0.085,
        2.35,
        phase * 0.72 + 2.40,
        aa
    );
    col *= 1.0 - sweepEdge * sweepGate * 0.010;

    // Bright rounded lobe from the left edge.
    float lobeGate = smoothstep(-0.30, 0.55, sin(phase - 0.30));
    vec2 plobe = rotate2D(p + vec2(0.090 * cos(phase + 3.8), 0.020 * sin(phase + 1.6)), -0.35);
    float lobeEdge = plobe.x + 0.570 + 0.095 * sin(2.65 * plobe.y + phase * 0.55);
    float lobeMask = 1.0 - smoothstep(-aa, aa, lobeEdge);
    float lobeTone = 0.835 + 0.085 * blob(plobe, vec2(-0.56, 0.04), vec2(0.95, 1.10), 0.62)
                    - 0.018 * plobe.y;
    col = mix(col, vec3(saturate(lobeTone)), lobeMask * lobeGate * 0.76);

    // Lower pale wave in the foreground.
    vec2 pb = rotate2D(p + vec2(0.060 * cos(phase + 3.1), -0.018 * sin(phase)), 0.055);
    float lowerMask = fillBelowWave(
        pb,
       -0.335 + 0.045 * sin(phase + 0.6),
        0.018,
        0.105,
        3.00,
        phase + 3.45,
        aa
    );
    float lowerTone = paperTone(0.835, pb, phase + 3.2, vec2(0.12, -0.40), 0.070);
    col = mix(col, vec3(lowerTone), lowerMask * 0.88);

    // Very subtle vignette to keep the flat background from looking synthetic.
    float vignette = dot(p * vec2(0.82, 1.22), p * vec2(0.82, 1.22));
    col -= 0.030 * smoothstep(0.55, 1.25, vignette);

    gl_FragColor = vec4(saturate(col.r), saturate(col.g), saturate(col.b), 1.0);
}
