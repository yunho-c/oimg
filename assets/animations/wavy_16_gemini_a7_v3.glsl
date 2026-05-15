// Variation 3: True Parallax
// Modulates wave amplitude, frequency, and speed based on layer depth

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    vec3 col = vec3(0.95);
    const int NUM_LAYERS = 6;

    for (int i = 0; i < NUM_LAYERS; i++) {
        float fi = float(i);

        // Depth scale (1.0 is front, smaller is further back)
        float z = (fi + 1.0) / float(NUM_LAYERS);

        float heightInterval = fi * 0.18;
        float phaseInterval  = fi * 0.8;
        float transInterval  = fi * 0.3;
        float tilt = pos.x * 0.15;

        float x = pos.x + transInterval;

        // --- PARALLAX MODULATION ---
        // Slower time for background layers
        float t = iTime * (0.2 + z * 0.6);

        // Amplitude grows as layers get closer (higher z)
        float ampBase = 0.1 + z * 0.25;

        // Frequency drops as layers get closer (they appear wider)
        float freqBase = 2.0 - z * 1.0;

        float waveShape = ampBase * sin(x * freqBase + t + phaseInterval)
                        + (ampBase*0.6) * cos(x * (freqBase*0.7) - t * 0.6 + phaseInterval * 1.2);

        float h = 1.05 - tilt - heightInterval + waveShape;

        vec3 layerTopColor = vec3(0.92 - fi * 0.10);
        vec3 layerBotColor = layerTopColor - vec3(0.15);
        vec3 layerCol = mix(layerBotColor, layerTopColor, uv.y / max(h, 0.001));

        col = mix(col, layerCol, step(uv.y, h));
    }

    fragColor = vec4(col, 1.0);
}
