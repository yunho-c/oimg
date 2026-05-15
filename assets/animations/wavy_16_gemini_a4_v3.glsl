// Variation 3: Topographic Contours
// Abandons the loop for a continuous field, using fract() to draw infinite contour lines

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    float t = iTime * 0.2;

    // Create a 2D heightmap field using intersecting waves
    float field = pos.y + pos.x * 0.3; // Base tilt

    field += 0.2 * sin(pos.x * 3.0 + t) * cos(pos.y * 2.0 - t);
    field += 0.15 * sin(pos.x * 5.0 - t * 1.5);
    field -= 0.1 * cos((pos.x + pos.y) * 4.0 + t * 2.0);

    // Density of the contour lines
    float contourDensity = 12.0;

    // Extract fractional part to get repeating bands
    float bands = fract(field * contourDensity);

    // Draw thin lines at the edges of the bands
    float lines = smoothstep(0.05, 0.0, bands) + smoothstep(0.95, 1.0, bands);

    // Styling: Dark teal background, bright mint/cyan lines
    vec3 bgColor = vec3(0.02, 0.08, 0.12);
    vec3 lineColor = vec3(0.2, 1.0, 0.8);

    vec3 col = mix(bgColor, lineColor, lines);

    // Add a subtle depth gradient based on the raw field
    col += vec3(0.0, 0.1, 0.2) * field;

    fragColor = vec4(col, 1.0);
}
