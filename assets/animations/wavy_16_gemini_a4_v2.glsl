// Variation 2: Liquid Magma
// Uses soft blending, warm colors, and a slightly distorted coordinate space

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    // Distort the space itself slightly for a "boiling" feel
    pos.y += sin(pos.x * 8.0 + iTime * 2.0) * 0.02;

    // Dark red base
    vec3 col = vec3(0.1, 0.0, 0.0);
    float t = iTime * 0.4;
    const int NUM_LAYERS = 6;

    for (int i = 0; i < NUM_LAYERS; i++) {
        float fi = float(i);

        float heightInterval = fi * 0.18;
        float phaseInterval  = fi * 0.7;
        float transInterval  = fi * 0.25;
        float tilt = pos.x * 0.1;

        float x = pos.x + transInterval;
        float waveShape = 0.25 * sin(x * 1.2 + t + phaseInterval)
                        + 0.15 * cos(x * 0.8 - t * 0.6 + phaseInterval * 1.2);

        float h = 1.0 - tilt - heightInterval + waveShape;

        // Magma color palette (Dark Red -> Bright Orange/Yellow)
        vec3 layerBotColor = vec3(0.4 + fi*0.1, 0.0, 0.0);
        vec3 layerTopColor = vec3(1.0, 0.4 + fi*0.1, 0.0);

        vec3 layerCol = mix(layerBotColor, layerTopColor, clamp(uv.y / h, 0.0, 1.0));

        // Very soft edge for a liquid blending look
        float softEdge = smoothstep(h + 0.08, h - 0.08, uv.y);
        col = mix(col, layerCol, softEdge);
    }

    fragColor = vec4(col, 1.0);
}
