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

  vec3 col = vec3(0.965);
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

    vec3 layerTopColor = vec3(0.92 - fi * 0.10);
    vec3 layerBotColor = layerTopColor - vec3(0.15);
    vec3 layerCol = mix(layerBotColor, layerTopColor, uv.y / max(h, 0.001));

    col = mix(col, layerCol, step(uv.y, h));
  }

  fragColor = vec4(col, 1.0);
}
