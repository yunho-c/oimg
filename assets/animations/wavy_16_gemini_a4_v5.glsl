// Variation 5: Ethereal Aurora
// Abandons solid shapes for soft, cumulative bands of translucent color

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    // Deep night sky background
    vec3 col = vec3(0.01, 0.02, 0.05);

    float t = iTime * 0.3;
    const int NUM_LAYERS = 8; // More layers for a voluminous feel

    for (int i = 0; i < NUM_LAYERS; i++) {
        float fi = float(i);

        float heightInterval = fi * 0.1;
        float phaseInterval  = fi * 0.5;
        float transInterval  = fi * 0.2;
        float tilt = pos.x * 0.3;

        float x = pos.x + transInterval;

        // More erratic, swiping waves
        float waveShape = 0.4 * sin(x * 1.0 + t + phaseInterval)
                        + 0.2 * sin(x * 2.5 - t * 1.5 + phaseInterval * 2.0);

        float h = 0.8 - tilt - heightInterval + waveShape;

        // Aurora colors (Greens, Teals, Purples)
        vec3 bandColor = 0.5 + 0.5 * cos(fi * 0.6 + vec3(0.0, 1.0, 2.0));

        // Instead of a hard step, calculate distance and use a soft bell curve (Gaussian-like)
        float dist = abs(uv.y - h);
        float intensity = exp(-dist * 15.0); // Soft, wide fade

        // Additive blending with a slight vertical stretch (aurora curtains)
        col += bandColor * intensity * 0.3 * (1.0 - uv.y);
    }

    // Add some subtle stars/noise in the background
    float star = fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
    if(star > 0.995) col += vec3(1.0);

    // Vignette to frame it
    col *= 1.0 - 0.5 * length(uv - 0.5);

    fragColor = vec4(col, 1.0);
}
