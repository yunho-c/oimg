// Variation 5: Cellular Stone (Corrected)
// Polished dynamic Voronoi cells that drift like tectonic plates.

// Simple noise for the points to drift
float hash(float n) { return fract(sin(n) * 43758.5453); }

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    float t = iTime * 0.12; // Slow flow
    vec3 col = vec3(0.08, 0.08, 0.1); // Matte Black base

    // Scale of the tessellation
    float scale = 4.0;
    vec2 gridP = pos * scale + vec2(t * 0.3, t * 0.2); // Drifting coordinate system

    float distToCell = 1.0e10; // Closest
    float distToEdge = 1.0e10; // Second closest (for edges)
    vec2 cellID = vec2(0.0);

    // Iterate through a grid to find dynamic Voronoi points
    vec2 gi = floor(gridP);
    vec2 gf = fract(gridP);

    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 neighbour = vec2(float(i), float(j));
            vec2 cell_root = gi + neighbour;

            // Generate a dynamic point for this cell that drifts
            float seed = hash(cell_root.x + cell_root.y * 57.0);
            vec2 point = 0.5 + 0.5 * vec2(cos(t + seed * 6.28), sin(t * 0.7 + seed * 6.28));

            vec2 r = neighbour - gf + point;
            float d = dot(r, r); // Distance squared for Voronoi

            // Store closest distance to get the cell shape
            if (d < distToCell) {
                distToEdge = distToCell;
                distToCell = d;
                cellID = cell_root;
            } else if (d < distToEdge) {
                // Second closest to get boundary lines
                distToEdge = d;
            }
        }
    }

    // --- CELL COLORING ---
    // Use the cell ID to generate a consistent color per cell
    float cellSeed = fract(sin(dot(cellID, vec2(12.9898, 78.233))) * 43758.5453);

    // Deep slate color range for the cells
    vec3 cellColorTop = vec3(0.25, 0.28, 0.3); // Medium Slate
    vec3 cellColorBot = vec3(0.12, 0.14, 0.18); // Deep Charcoal

    // Apply internal gradient based on distance to center and time pulse
    float pulse = 0.5 + 0.5 * sin(t * 1.5 + cellSeed * 6.28);

    // FIXED: Replaced undeclared 'height' with 'pulse' for the internal color mix
    vec3 cellCol = mix(cellColorBot, cellColorTop, smoothstep(0.0, 1.0, 1.0 - distToCell * (1.0 + pulse * 0.5)));

    // Use a distance function for a dynamic texture on each cell
    cellCol *= mix(0.7, 1.0, 1.0 - distToCell * 0.5);

    // Composite cells on black base
    col = cellCol;

    // --- EDGES ("Cracks" filled with Bronze) ---
    // The Voronoi edge is defined where distToCell == distToEdge
    float edge = distToEdge - distToCell;
    float edgeLine = smoothstep(0.0, 0.05, edge); // Boundary width

    // Bronze color for the cracks
    vec3 bronze = vec3(0.55, 0.5, 0.45); // Muted Copper

    // Soft glow on the cracks, stronger near the edges of the screen
    float edgeGlow = pow(1.0 - edgeLine, 8.0);
    col = mix(bronze, col, edgeLine);
    col += bronze * edgeGlow * 0.3 * (1.0 - uv.y); // Vertical fade

    // Add subtle noise texture
    float n = fract(sin(dot(uv * 100.0, vec2(12.9898, 78.233))) * 43758.5453);
    col *= 1.0 - 0.05 * n;

    // Dark vignette for depth
    col *= smoothstep(0.8, 0.3, length(uv - 0.5));

    fragColor = vec4(col, 1.0);
}
