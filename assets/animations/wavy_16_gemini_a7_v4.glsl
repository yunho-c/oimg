// Variation 4: Crisp Edge Stroking
// Adds a rigid, pixel-perfect highlight strictly to the edge of the step

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    vec3 col = vec3(0.15); // Darker background to make highlights pop
    float t = iTime * 0.5;
    const int NUM_LAYERS = 6;

    for (int i = 0; i < NU  M_LAYERS; i++) {
        float fi = float(i);

        float heightInterval = fi * 0.18;
        float phaseInterval  = fi * 0.8;
        float transInterval  = fi * 0.3;
        float tilt = pos.x * 0.15;

        float x = pos.x + transInterval;
        float waveShape = 0.25 * sin(x * 1.2 + t + phaseInterval)
                        + 0.15 * cos(x * 0.8 - t * 0.6 + phaseInterval * 1.2);

        float h = 1.05 - tilt - heightInterval + waveShape;

        // Deep teal/slate base colors
        vec3 layerTopColor = vec3(0.2, 0.3, 0.35) + (fi * 0.05);
        vec3 layerBotColor = layerTopColor - vec3(0.1);
        vec3 layerCol = mix(layerBotColor, layerTopColor, uv.y / max(h, 0.001));

        // --- STROKE CALCULATION ---
        // step(uv.y, h) fills everything below the line
        // step(uv.y, h - 0.005) fills everything slightly deeper below the line
        // The difference is exactly the 0.005-thick top edge.
        float strokeThickness = 0.006;
        float isBody = step(uv.y, h - strokeThickness);
        float isEdge = step(uv.y, h) - isBody;

        vec3 edgeColor = vec3(0.8, 0.85, 0.9); // Pale crisp highlight

        // Apply the body, then forcefully overwrite the edge pixels
        col = mix(col, layerCol, step(uv.y, h));
        col = mix(col, edgeColor, isEdge);
    }

    fragColor = vec4(col, 1.0);
}
