// Variation 4: Chromatic Offset Split
// Calculates R, G, and B boundaries separately for a color-bleeding hard edge

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    vec3 col = vec3(0.95);
    float t = iTime * 0.6;

    const int NUM_LAYERS = 5;

    // How far the colors separate
    float rgbShift = 0.03; 

    for (int i = 0; i < NUM_LAYERS; i++) {
        float fi = float(i);

        float heightInterval = fi * 0.22;
        float phaseInterval  = fi * 0.9;
        float transInterval  = fi * 0.3;
        float tilt = pos.x * 0.1;

        // Calculate X position for R, G, B with slight horizontal shifts
        float xR = pos.x + transInterval - rgbShift;
        float xG = pos.x + transInterval;
        float xB = pos.x + transInterval + rgbShift;

        // Calculate three separate heights
        float wR = 0.2 * sin(xR * 2.0 + t + phaseInterval) + 0.1 * cos(xR * 1.2 - t);
        float wG = 0.2 * sin(xG * 2.0 + t + phaseInterval) + 0.1 * cos(xG * 1.2 - t);
        float wB = 0.2 * sin(xB * 2.0 + t + phaseInterval) + 0.1 * cos(xB * 1.2 - t);

        float baseH = 1.0 - tilt - heightInterval;
        float hR = baseH + wR;
        float hG = baseH + wG;
        float hB = baseH + wB;

        // Base dark gray color for the layer
        vec3 layerBase = vec3(0.8 - fi * 0.15);

        // Apply the layer color per channel using independent hard steps
        col.r = mix(col.r, layerBase.r, step(uv.y, hR));
        col.g = mix(col.g, layerBase.g, step(uv.y, hG));
        col.b = mix(col.b, layerBase.b, step(uv.y, hB));
    }

    fragColor = vec4(col, 1.0);
}
