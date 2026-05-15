// Variation 4: Prismatic Drift
// Multiple intersecting, rotating planes with volumetric coloring.

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    float t = iTime * 0.08; // Very slow movement
    vec3 col = vec3(0.0); // Pure black base for depth

    const int NUM_PRISMS = 6;
    for (int i = 0; i < NUM_PRISMS; i++) {
        float fi = float(i);

        // --- 3D TRANSFORMATIONS ---
        // Drift position over time, different per prism
        float driftAngle = t * 1.5 + fi * 0.8;
        vec2 p = pos + vec2(0.5 * cos(driftAngle * 0.6), 0.3 * sin(driftAngle * 0.4));

        // Rotate the space for a dynamic angle
        float rot = t * (fi * 0.1 + 0.1);
        vec2 rotatedP = p * mat2(cos(rot), -sin(rot), sin(rot), cos(rot));

        // Rotate in the other direction too (like 3D skewing)
        rotatedP.y *= 1.2 + 0.3 * cos(t + fi);

        // --- GEOMETRY ---
        // A distance field defining a rectangular plane (the 'Prism')
        vec2 d = abs(rotatedP) - vec2(0.4, 0.2 + fi * 0.01);
        float prism = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);

        // Distance function to create a clean shape
        float shape = smoothstep(0.05, 0.0, prism);

        // --- COLORING & BLENDING ---
        // Translucent colors (Muted Blue/Gray)
        vec3 c_blue = vec3(0.18, 0.22, 0.25); // Stone Blue
        vec3 c_gray = vec3(0.12, 0.14, 0.18); // Charcoal Gray

        vec3 prismColor = (mod(fi, 2.0) < 0.5) ? c_blue : c_gray;

        // --- EDGES ---
        // Thin, faint silver line at the boundary
        float edge = smoothstep(0.01, 0.0, abs(prism));
        vec3 silverCol = vec3(0.7, 0.72, 0.75); // Polished Silver

        // --- COMPOSITE (Add/Multiply style for transparency) ---
        // The core translucent plane
        col += prismColor * shape * 0.3; // Volumetric blend
        // Add the edge on top
        col += silverCol * edge * 0.2;
    }

    // Add subtle ambient texture
    float n = fract(sin(dot(uv * 100.0, vec2(12.9898, 78.233))) * 43758.5453);
    col *= 1.0 - 0.05 * n;

    // Broad vignetting for architectural lighting
    col *= 1.0 - 0.4 * length(uv - 0.5);

    fragColor = vec4(col, 1.0);
}
