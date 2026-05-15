// Variation 1: Submerged Facets
// 3D Hexagonal grid with variable pulsing heights.

// Core hexagonal grid function
vec4 hexagon(vec2 p) {
    vec2 q = vec2( p.x*1.1547, p.y + p.x*0.57735 );
    vec2 pi = floor(q);
    vec2 pf = fract(q);
    if( pf.x+pf.y > 1.0 ) {
        pi += 1.0;
        pf = 1.0 - pf;
    }
    return vec4(pi, pf.x, pf.y); // Cell ID (xy), internal coord (zw)
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    float t = iTime * 0.15; // Extremely slow movement
    vec3 col = vec3(0.08, 0.08, 0.1); // Matte Black base

    // Grid scale
    float scale = 8.0;
    vec2 hexP = pos * scale + vec2(t * 0.2, t * 0.3); // Drifting grid

    vec4 hex = hexagon(hexP);
    vec2 cellID = hex.xy;

    // Internal coordinate for shading (how close to center/edge)
    float dist = 1.0 - (hex.z + hex.w) * 0.6;
    dist = smoothstep(0.0, 1.0, dist);

    // Height calculation based on cell ID and noise
    float heightSeed = fract(sin(dot(cellID, vec2(12.9898, 78.233))) * 43758.5453);
    float pulse = 0.5 + 0.5 * sin(t + heightSeed * 6.28 + pos.x);

    // This gives each cell a height based on its position and time
    float height = 0.6 + 0.3 * heightSeed + 0.3 * pulse;

    // --- COLORING ---
    // Deep slate palette
    vec3 cellColorTop = vec3(0.2, 0.22, 0.25); // Medium Slate
    vec3 cellColorBot = vec3(0.12, 0.14, 0.18); // Deep Charcoal

    vec3 cellCol = mix(cellColorBot, cellColorTop, dist * height);

    // Apply a simple diffuse lighting effect based on the distance
    float light = pow(dist * height, 2.0);
    cellCol *= mix(0.5, 1.0, light);

    // --- EDGES ---
    // Make the edge of each hexagon catch a faint, bronze-like light
    float edge = pow(dist, 10.0); // Very narrow edge
    vec3 edgeCol = vec3(0.5, 0.45, 0.4); // Subtle Bronze

    // Final composite: Background, Cell, and glowing Edge
    col = mix(col, cellCol, smoothstep(0.1, 0.05, 1.0 - dist * height));
    col = mix(col, edgeCol, edge * 0.5);

    // Vignette for depth
    col *= 1.0 - 0.3 * length(uv - 0.5);

    fragColor = vec4(col, 1.0);
}
