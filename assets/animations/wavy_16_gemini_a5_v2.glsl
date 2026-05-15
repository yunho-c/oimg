// Variation 2: Flowing Strand Weave
// An intricate, moving weave of separate mathematical strands.

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    float t = iTime * 0.2; // Slow flow
    vec3 col = vec3(0.12, 0.14, 0.18); // Deep Slate background

    const int NUM_STRANDS = 12;
    for (int i = 0; i < NUM_STRANDS; i++) {
        float fi = float(i);

        // --- WEAVE PARAMETERS ---
        float y0 = 0.2 + fi * 0.05; // Base Y position
        float freq = 2.0 + fi * 0.1; // Frequency/density of waves
        float speed = 0.5 + fi * 0.1; // Speed of each strand
        float phase = fi * 0.8;
        float amplitude = 0.1 + fi * 0.01;

        // --- THE WAVE (PARAMETRIC) ---
        float x = pos.x;
        float waveShape = amplitude * sin(x * freq + t * speed + phase)
                        + amplitude * 0.5 * cos(x * freq * 1.5 - t * speed * 0.7 + phase * 1.2);

        float h = y0 + waveShape;

        // --- STRAND MORPHOLOGY (Thickness) ---
        // How close is the pixel to the center of the strand?
        float dist = abs(uv.y - h);

        // Define a varying width for each strand
        float strandWidth = 0.01 + 0.005 * sin(x * 5.0 + t + fi);

        // --- COLORING ---
        // Color alternating strands Slate Blue / Charcoal Gray
        vec3 strandColor = (mod(fi, 2.0) > 0.5) ? vec3(0.25, 0.3, 0.35) : vec3(0.18, 0.2, 0.22);

        // Add subtle light reflections on the top of the strands
        float topLight = smoothstep(h - 0.001, h + strandWidth * 0.5, uv.y)
                       - smoothstep(h + 0.001, h + strandWidth * 1.0, uv.y);
        topLight *= (1.0 - uv.y); // Fade with height

        // Add subtle depth gradient within the strand
        float depth = smoothstep(strandWidth, 0.0, dist);

        // Final coloring of this strand
        vec3 strandCol = mix(strandColor * 0.6, strandColor, depth);
        strandCol += vec3(0.3) * topLight; // Add reflection

        // --- COMPOSITE (Additive/Volumetric blend) ---
        col += strandCol * depth;
    }

    // Add texture noise to mimic the feel of polished stone/fabric
    float n = fract(sin(dot(uv * 100.0, vec2(12.9898, 78.233))) * 43758.5453);
    col *= 1.0 - 0.05 * n;

    // Add a broad vignetting to frame the view
    col *= smoothstep(0.8, 0.2, length(uv - vec2(0.5, 0.6)));

    fragColor = vec4(col, 1.0);
}
