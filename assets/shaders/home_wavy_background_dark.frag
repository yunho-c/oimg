#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 safeSize = max(uSize, vec2(1.0));
  vec2 uv = fragCoord / safeSize;

  vec2 pos = uv;
  pos.x *= safeSize.x / safeSize.y;

  vec3 col = vec3(0.145, 0.145, 0.155);
  float t = uTime * 0.5;

  const int numLayers = 6;
  const float levelTiltInfluence = 0.175;

  for (int i = 0; i < numLayers; i++) {
    float fi = float(i);

    float heightInterval = fi * 0.18;
    float phaseInterval = fi * 0.4;
    float tilt = pos.x * 0.15;
    float levelTilt = pos.x * fi * levelTiltInfluence;
    float waveShape = 0.30 * sin(pos.x * 1.2 + t + phaseInterval);
    float h = 1.05 - tilt - levelTilt - heightInterval + waveShape;

    float levelMix = fi / float(numLayers - 1);
    vec3 layerHue = vec3(0.135, 0.135, 0.148);
    vec3 layerTopColor = layerHue * mix(1.72, 0.82, levelMix);
    vec3 layerBotColor = layerHue * mix(0.94, 0.42, levelMix);
    vec3 layerCol = mix(
      layerBotColor,
      layerTopColor,
      uv.y / max(h, 0.001)
    );

    col = mix(col, layerCol, step(uv.y, h));
  }

  float cyanGlow = smoothstep(0.0, 1.0, 1.0 - distance(uv, vec2(0.18, 0.18)));
  float violetGlow = smoothstep(0.0, 1.0, 1.0 - distance(uv, vec2(0.88, 0.78)));
  col += vec3(0.02, 0.025, 0.03) * cyanGlow * 0.14;
  col += vec3(0.045, 0.035, 0.055) * violetGlow * 0.16;

  fragColor = vec4(col, 1.0);
}
