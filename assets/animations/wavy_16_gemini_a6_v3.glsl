// Variation 3: Signal Quantization
// Uses floor() on the wave output to create chunky, stair-stepped boundaries

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    vec3 col = vec3(0.1, 0.12, 0.15);
    float t = iTime * 0.4;

    const int NUM_LAYERS = 6;

    for (int i = 0; i < NUM_LAYERS; i++) {
        float fi = float(i);

        float heightInterval = fi * 0.18;
        float phaseInterval  = fi * 0.8;
        float transInterval  = fi * 0.3;
        float tilt = pos.x * 0.15;

        float x = pos.x + transInterval;

        // The raw, smooth wave
        float rawWave = 0.25 * sin(x * 1.5 + t + phaseInterval)
                      + 0.15 * cos(x * 0.8 - t * 0.6 + phaseInterval * 1.2);

        // Quantize the wave into rigid vertical steps
        float steps = 20.0; // Number of vertical increments
        float steppedWave = floor(rawWave * steps) / steps;

        float h = 1.0 - tilt - heightInterval + steppedWave;

        // Muted tech palette (Teals and Grays)
        vec3 layerCol = vec3(0.2 + fi * 0.05, 0.4 + fi * 0.1, 0.5 + fi * 0.05);
        if(mod(fi, 2.0) == 0.0) layerCol = vec3(0.15 + fi * 0.05); // Interleave gray

        // Hard edge step
        col = mix(col, layerCol, step(uv.y, h));
    }

    fragColor = vec4(col, 1.0);
}
