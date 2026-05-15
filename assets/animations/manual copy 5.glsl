// Wavy Grayscale Background - Synchronized
// Replicates a continuous wave function with consistent phase, translation, and height intervals

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    // Normalize pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Correct aspect ratio for uniform wave stretching
    vec2 pos = uv;
    pos.x *= iResolution.x / iResolution.y;

    // Base background color (lightest gray)
    vec3 col = vec3(0.95);

    // Global speed of the animation
    float t = iTime * 0.5;

    // Number of wave layers
    const int NUM_LAYERS = 6;

    // Iterate through layers back-to-front
    for (int i = 0; i < NUM_LAYERS; i++) {

        float fi = float(i); // Convert index to float for math

        // --- SYNCHRONIZATION VARIABLES ---
        // These constants define the "consistent interval" between each wave

        float heightInterval = fi * 0.18;      // Drops the height for each layer
        float phaseInterval  = fi * 0.9;       // Offsets the rhythm/timing
        float transInterval  = fi * 0.0;       // Shifts the wave horizontally

        // A global tilt to make the waves flow diagonally across the screen
        float tilt = pos.x * 0.15;

        // --- THE WAVE FUNCTION ---
        // We calculate the X position specific to this layer's translation
        float x = pos.x + transInterval;

        // The master curve (combination of sines for a smooth, complex shape)
        float waveShape = 0.10 * sin(x * 1.2 + t + phaseInterval)
                        // ;
                        - 0.15 * cos(x * 0.8 - t * 0.6 + phaseInterval * 1.2);

        // Calculate the final boundary height for this specific layer
        float h = 1.05 - tilt - heightInterval + waveShape;

        // --- COLORING ---
        // Each layer gets progressively darker
        vec3 layerTopColor = vec3(0.92 - fi * 0.10);
        vec3 layerBotColor = layerTopColor - vec3(0.15); // Gradient within the layer

        // Calculate gradient coloring for this specific layer
        vec3 layerCol = mix(layerBotColor, layerTopColor, uv.y / max(h, 0.001));

        // Draw the layer with a hard edge using step()
        col = mix(col, layerCol, step(uv.y, h));
    }

    // Output to screen
    fragColor = vec4(col, 1.0);
}

