// Variation 2: Terminal Amber Dither
// Hard wave boundaries filled with a screen-space 1-bit dither pattern

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    // Dark terminal background
    vec3 col = vec3(0.05, 0.02, 0.0);
    float t = iTime * 0.5;

    // Screen-space dither calculation (1-bit checkerboard)
    vec2 pixel = floor(fragCoord);
    float dither = mod(pixel.x + pixel.y, 2.0);

    const int NUM_LAYERS = 5;

    for (int i = 0; i < NUM_LAYERS; i++) {
        float fi = float(i);

        float heightInterval = fi * 0.2;
        float phaseInterval  = fi * 0.8;
        float transInterval  = fi * 0.3;
        float tilt = pos.x * 0.1;

        float x = pos.x + transInterval;
        float waveShape = 0.25 * sin(x * 1.5 + t + phaseInterval)
                        + 0.15 * cos(x * 1.0 - t * 0.6 + phaseInterval * 1.2);

        float h = 1.0 - tilt - heightInterval + waveShape;

        // Amber palette, darkening per layer
        vec3 layerBase = vec3(1.0, 0.6, 0.0) * (1.0 - fi * 0.15);

        // Apply dither: If dither is 1.0, use the color; if 0.0, use a dark variant
        vec3 layerCol = mix(layerBase * 0.2, layerBase, dither);

        // Hard edge
        col = mix(col, layerCol, step(uv.y, h));
    }

    // Add slight scanline effect
    col *= 0.9 + 0.1 * sin(fragCoord.y * 3.14);

    fragColor = vec4(col, 1.0);
}
