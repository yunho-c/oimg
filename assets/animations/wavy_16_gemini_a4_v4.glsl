// Variation 4: Retro 8-Bit Glitch
// Quantizes coordinates and time to create a chunky, staggered pixel-art look

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Pixelate the UV coordinates
    float pixels = 60.0;
    vec2 blockyUV = floor(uv * pixels) / pixels;

    vec2 pos = blockyUV;
    pos.x *= iResolution.x / iResolution.y;

    vec3 col = vec3(0.1, 0.1, 0.15); // Dark gray base

    // Quantize time to create a "choppy" framerate feel
    float t = floor(iTime * 8.0) / 8.0 * 1.5;

    const int NUM_LAYERS = 5;

    for (int i = 0; i < NUM_LAYERS; i++) {
        float fi = float(i);

        float heightInterval = fi * 0.2;
        float phaseInterval  = fi * 1.0;
        float transInterval  = fi * 0.5;
        float tilt = pos.x * 0.1;

        float x = pos.x + transInterval;
        float waveShape = 0.3 * sin(x * 1.8 + t + phaseInterval)
                        + 0.2 * cos(x * 1.2 - t + phaseInterval * 1.5);

        float h = 1.0 - tilt - heightInterval + waveShape;

        // High-contrast CGA/EGA retro palette
        vec3 layerCol = vec3(mod(fi, 2.0), mod(fi*0.5, 1.0), 1.0 - fi*0.2);
        if(i == 0) layerCol = vec3(1.0, 0.0, 0.5); // Magenta
        if(i == 1) layerCol = vec3(0.0, 1.0, 1.0); // Cyan
        if(i == 2) layerCol = vec3(1.0, 1.0, 0.0); // Yellow
        if(i == 3) layerCol = vec3(0.0, 0.0, 0.8); // Deep Blue
        if(i == 4) layerCol = vec3(0.8, 0.8, 0.8); // Light Gray

        // Hard pixelated edge
        col = mix(col, layerCol, step(blockyUV.y, h));
    }

    fragColor = vec4(col, 1.0);
}
