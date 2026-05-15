// Variation 5: Hard Drop Shadows
// Computes an offset mask to draw crisp drop shadows beneath layers

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    vec3 col = vec3(0.95);
    float t = iTime * 0.5;
    const int NUM_LAYERS = 6;

    for (int i = 0; i < NUM_LAYERS; i++) {
        float fi = float(i);

        float heightInterval = fi * 0.18;
        float phaseInterval  = fi * 0.8;
        float transInterval  = fi * 0.3;
        float tilt = pos.x * 0.15;

        float x = pos.x + transInterval;
        float waveShape = 0.25 * sin(x * 1.2 + t + phaseInterval)
                        + 0.15 * cos(x * 0.8 - t * 0.6 + phaseInterval * 1.2);

        float h = 1.05 - tilt - heightInterval + waveShape;

        vec3 layerTopColor = vec3(0.92 - fi * 0.10);
        vec3 layerBotColor = layerTopColor - vec3(0.15);
        vec3 layerCol = mix(layerBotColor, layerTopColor, uv.y / max(h, 0.001));

        // --- SHADOW CALCULATION ---
        // Offset the height downward and simulate a shift to the right by modifying x slightly
        float shadowOffset = 0.03 + fi * 0.005; // Shadows get slightly longer for foreground

        // Instead of recalculating the wave for the X offset, we cheat by just tilting the shadow mask
        float hShadow = h - shadowOffset + (pos.x * 0.05);

        // Darken the existing background where the shadow falls
        vec3 shadowColor = col * 0.6; // Multiply existing color by 0.6 for translucent shadow feel
        col = mix(col, shadowColor, step(uv.y, hShadow));

        // Draw the hard-edged layer on top of the shadow
        col = mix(col, layerCol, step(uv.y, h));
    }

    fragColor = vec4(col, 1.0);
}
