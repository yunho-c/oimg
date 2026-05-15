// Variation 3: Topographic Pulse
// Drifting contour lines on an dynamic field from above.

// Simple 2D noise for the field distortion
float hash2(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash2(i);
    float b = hash2(i + vec2(1.0, 0.0));
    float c = hash2(i + vec2(0.0, 1.0));
    float d = hash2(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 pos = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    float t = iTime * 0.1; // Extremely slow movement
    vec3 col = vec3(0.01, 0.01, 0.02); // Matter Black base

    // --- THE FIELD FUNCTION ---
    // A distance field (radial gradient from the center)
    float field = length(pos);

    // A slow radial pulse
    float pulse = 0.5 + 0.5 * sin(t * 1.5 + field * 6.0);

    // Add complexity and drift with 2D noise
    vec2 noiseP = pos * 3.0 + vec2(t * 0.5, t * 0.8);
    field += 0.15 * noise2(noiseP) * pulse; // Amplitude of pulse varies by noise
    field -= 0.1 * noise2(noiseP * 2.0); // Add smaller features

    // Density of the contour lines
    float contourDensity = 15.0;

    // Use fract() to get repeating, dynamic bands
    float bands = fract(field * contourDensity);

    // Draw thin contour lines at the edges of the bands
    float lineWidth = 0.015 + 0.01 * sin(t * 2.0); // Line thickness pulses subtly
    float lineDist = abs(bands - 0.5);
    float lines = smoothstep(lineWidth + 0.01, lineWidth - 0.01, lineDist);

    // Styling: Muted bronze/copper color for the lines
    vec3 lineColorTop = vec3(0.6, 0.5, 0.45); // Muted Copper
    vec3 lineColorBot = vec3(0.4, 0.3, 0.25); // Dark Bronze

    // Composite coloring for lines
    vec3 lineCol = mix(lineColorBot, lineColorTop, smoothstep(0.0, 1.0, bands));

    // Draw lines onto background
    col = mix(col, lineCol, lines);

    // Fade lines at the screen edges for sophisticated framing
    col *= smoothstep(0.8, 0.3, length(pos));

    fragColor = vec4(col, 1.0);
}
