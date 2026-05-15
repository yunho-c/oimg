// Wavy Grayscale Background
// Replicates a smooth, overlapping sine-wave animation

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalize pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Correct aspect ratio for uniform wave stretching
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    // Base background color (lightest gray)
    vec3 col = vec3(0.92);

    // Speed of the animation
    float t = iTime * 0.4;

    // --- Layer 1 (Back) ---
    float h1 = 0.7 + 0.15 * sin(pos.x * 1.5 + t) + 0.1 * cos(pos.x * 1.2 - t * 0.8);
    vec3 c1_bottom = vec3(0.75);
    vec3 c1_top = vec3(0.88);
    // Gradient coloring
    vec3 col1 = mix(c1_bottom, c1_top, uv.y / max(h1, 0.001));
    // Smooth anti-aliased edge
    col = mix(col, col1, smoothstep(h1 + 0.01, h1 - 0.01, uv.y));

    // --- Layer 2 ---
    float h2 = 0.5 + 0.2 * sin(pos.x * 1.8 - t * 1.1) + 0.12 * cos(pos.x * 2.0 + t * 0.9);
    vec3 c2_bottom = vec3(0.65);
    vec3 c2_top = vec3(0.82);
    vec3 col2 = mix(c2_bottom, c2_top, uv.y / max(h2, 0.001));
    col = mix(col, col2, smoothstep(h2 + 0.01, h2 - 0.01, uv.y));

    // --- Layer 3 ---
    float h3 = 0.35 + 0.12 * sin(pos.x * 2.2 + t * 1.3) + 0.1 * cos(pos.x * 2.5 - t * 1.2);
    vec3 c3_bottom = vec3(0.55);
    vec3 c3_top = vec3(0.72);
    vec3 col3 = mix(c3_bottom, c3_top, uv.y / max(h3, 0.001));
    col = mix(col, col3, smoothstep(h3 + 0.01, h3 - 0.01, uv.y));

    // --- Layer 4 ---
    float h4 = 0.2 + 0.1 * sin(pos.x * 2.8 - t * 1.5) + 0.08 * cos(pos.x * 1.5 + t * 1.4);
    vec3 c4_bottom = vec3(0.45);
    vec3 c4_top = vec3(0.62);
    vec3 col4 = mix(c4_bottom, c4_top, uv.y / max(h4, 0.001));
    col = mix(col, col4, smoothstep(h4 + 0.01, h4 - 0.01, uv.y));

    // --- Layer 5 (Front-most) ---
    float h5 = 0.05 + 0.08 * sin(pos.x * 3.5 + t * 1.8);
    vec3 c5_bottom = vec3(0.35);
    vec3 c5_top = vec3(0.52);
    vec3 col5 = mix(c5_bottom, c5_top, uv.y / max(h5, 0.001));
    col = mix(col, col5, smoothstep(h5 + 0.01, h5 - 0.01, uv.y));

    // Add a very subtle vignette to match the smooth studio lighting feel
    float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = clamp(pow(16.0 * vignette, 0.1), 0.0, 1.0);
    col *= mix(0.9, 1.0, vignette);

    // Output to screen
    fragColor = vec4(col, 1.0);
}
