// Variation 1: Op-Art Zebra Stripes
// High-contrast, tightly packed layers using modulo for alternating colors

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    vec3 col = vec3(1.0); // Start with white background
    float t = iTime * 0.4;

    const int NUM_LAYERS = 24; // High layer count

    for (int i = 0; i < NUM_LAYERS; i++) {
        float fi = float(i);

        // Tightly packed intervals
        float heightInterval = fi * 0.06;
        float phaseInterval  = fi * 0.15;
        float transInterval  = fi * 0.05;
        float tilt = pos.x * 0.2;

        float x = pos.x + transInterval;

        // Slightly higher frequency waves
        float waveShape = 0.15 * sin(x * 3.0 + t + phaseInterval)
                        + 0.1 * cos(x * 2.0 - t * 0.5 + phaseInterval * 1.5);

        float h = 1.2 - tilt - heightInterval + waveShape;

        // Strictly alternate black and white
        vec3 layerCol = (mod(fi, 2.0) < 0.5) ? vec3(0.0) : vec3(1.0);

        // Hard edge step
        col = mix(col, layerCol, step(uv.y, h));
    }

    fragColor = vec4(col, 1.0);
}
