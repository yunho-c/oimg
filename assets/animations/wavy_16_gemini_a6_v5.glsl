// Variation 5: Layered Papercraft Landscape
// Uses absolute value sine waves to create sharp, mountainous papercut folds

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    // Soft yellow "sky"
    vec3 col = vec3(1.0, 0.9, 0.7);
    float t = iTime * 0.3;

    const int NUM_LAYERS = 6;

    for (int i = 0; i < NUM_LAYERS; i++) {
        float fi = float(i);

        float heightInterval = fi * 0.15;
        float phaseInterval  = fi * 1.2;
        float transInterval  = fi * 0.5;
        float tilt = 0.0; // Flat horizon

        float x = pos.x + transInterval;

        // abs(sin()) creates sharp, bouncing peaks instead of rolling curves
        float waveShape = 0.25 * abs(sin(x * 1.2 + t + phaseInterval))
                        - 0.15 * cos(x * 3.0 - t * 0.5 + phaseInterval);

        float h = 0.85 - tilt - heightInterval + waveShape;

        // Warm sunset to deep purple/navy palette
        vec3 layerCol;
        if(i == 0) layerCol = vec3(1.0, 0.5, 0.3);   // Orange
        if(i == 1) layerCol = vec3(0.8, 0.2, 0.3);   // Crimson
        if(i == 2) layerCol = vec3(0.5, 0.1, 0.4);   // Plum
        if(i == 3) layerCol = vec3(0.3, 0.1, 0.45);  // Deep Purple
        if(i == 4) layerCol = vec3(0.15, 0.1, 0.35); // Dark Violet
        if(i == 5) layerCol = vec3(0.05, 0.05, 0.2); // Navy Blue

        // Hard edge step
        col = mix(col, layerCol, step(uv.y, h));
    }

    fragColor = vec4(col, 1.0);
}
