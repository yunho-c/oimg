// Variation 1: Neon Cyberpunk Glow
// Uses the wave math to draw glowing boundary lines with additive blending

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    // Dark background
    vec3 col = vec3(0.05, 0.02, 0.1);
    float t = iTime * 0.6;
    const int NUM_LAYERS = 6;

    for (int i = 0; i < NUM_LAYERS; i++) {
        float fi = float(i);

        float heightInterval = fi * 0.15;
        float phaseInterval  = fi * 1.2;
        float transInterval  = fi * 0.4;
        float tilt = pos.x * 0.2;

        float x = pos.x + transInterval;
        float waveShape = 0.3 * sin(x * 1.5 + t + phaseInterval)
                        + 0.15 * cos(x * 1.0 - t * 0.8 + phaseInterval * 1.5);

        float h = 0.9 - tilt - heightInterval + waveShape;

        // Neon color palette (Cyan to Purple/Pink)
        vec3 neonColor = 0.5 + 0.5 * cos(iTime * 0.2 + fi * 0.8 + vec3(0, 2, 4));

        // Calculate distance to the wave boundary for glowing effect
        float dist = abs(uv.y - h);
        float glow = 0.005 / (dist + 0.001); // Inverse distance glow

        // Additive blending
        col += neonColor * glow;
    }

    // Output to screen
    fragColor = vec4(col, 1.0);
}
