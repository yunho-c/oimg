// Variation 2: Atmospheric Depth
// Distant layers fade into a misty background color

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    // The "Atmosphere" color (Mist/Fog)
    vec3 fogColor = vec3(0.96, 0.97, 0.98);
    vec3 col = fogColor;

    float t = iTime * 0.5;
    const int NUM_LAYERS = 8; // Added more layers to emphasize depth

    for (int i = 0; i < NUM_LAYERS; i++) {
        float fi = float(i);
        float depthRatio = fi / float(NUM_LAYERS - 1); // 0.0 (Back) to 1.0 (Front)

        float heightInterval = fi * 0.12;
        float phaseInterval  = fi * 0.8;
        float transInterval  = fi * 0.3;
        float tilt = pos.x * 0.15;

        float x = pos.x + transInterval;
        float waveShape = 0.25 * sin(x * 1.2 + t + phaseInterval)
                        + 0.15 * cos(x * 0.8 - t * 0.6 + phaseInterval * 1.2);

        float h = 1.05 - tilt - heightInterval + waveShape;

        // The "true" color of the wave material (Slate Blue)
        vec3 materialColor = vec3(0.3, 0.4, 0.5);
        vec3 layerCol = mix(materialColor * 0.5, materialColor, uv.y / max(h, 0.001));

        // --- ATMOSPHERIC FADING ---
        // As depthRatio goes from 0 to 1, mix from fog to solid material
        // An exponential curve (pow) makes the fog feel physically realistic
        float visibility = pow(depthRatio, 1.5);
        layerCol = mix(fogColor, layerCol, visibility + 0.05);

        col = mix(col, layerCol, step(uv.y, h));
    }

    fragColor = vec4(col, 1.0);
}
