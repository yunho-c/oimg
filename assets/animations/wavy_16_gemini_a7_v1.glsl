// Variation 1: True Rotated Horizon
// Uses a 2D rotation matrix to tilt the entire coordinate space

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    // --- HORIZON ROTATION ---
    // Angle in radians (e.g., -0.2 is roughly -11 degrees)
    float angle = -0.2;
    mat2 rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));

    // Shift origin to center before rotating so it pivots nicely, then shift back
    vec2 pivot = vec2(0.5 * iResolution.x / iResolution.y, 0.5);
    vec2 rotatedPos = rot * (pos - pivot) + pivot;
    // We also rotate UV for the step() function so the cutoffs match the new horizon
    vec2 rotatedUV = rot * (uv - vec2(0.5)) + vec2(0.5);

    vec3 col = vec3(0.95);
    float t = iTime * 0.5;
    const int NUM_LAYERS = 6;

    for (int i = 0; i < NUM_LAYERS; i++) {
        float fi = float(i);

        float heightInterval = fi * 0.18;
        float phaseInterval  = fi * 0.8;
        float transInterval  = fi * 0.3;
        // Notice: 'tilt' is completely removed here.

        float x = rotatedPos.x + transInterval;
        float waveShape = 0.25 * sin(x * 1.2 + t + phaseInterval)
                        + 0.15 * cos(x * 0.8 - t * 0.6 + phaseInterval * 1.2);

        float h = 1.0 - heightInterval + waveShape;

        vec3 layerTopColor = vec3(0.92 - fi * 0.10);
        vec3 layerBotColor = layerTopColor - vec3(0.15);
        vec3 layerCol = mix(layerBotColor, layerTopColor, rotatedUV.y / max(h, 0.001));

        // Step uses the rotated UV y-coordinate
        col = mix(col, layerCol, step(rotatedUV.y, h));
    }

    fragColor = vec4(col, 1.0);
}
