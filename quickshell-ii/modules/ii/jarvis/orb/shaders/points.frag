// Généré par orb/gen-shaders.py depuis ~/qg/jarvis-3d/jarvis-orb.js — ne pas éditer à la main.
VARYING float vBright;
VARYING float vKind;
VARYING float vFront;
VARYING float vTw;
VARYING vec2 vCoord;
void MAIN(){

  vec2 d = vCoord; float r2 = dot(d, d);
  if (r2 > 1.0) discard;
  float halo = exp(-r2 * 4.5), core = exp(-r2 * 28.0);
  vec3 col;
  if (vKind > 3.5)      col = mix(uDeep, uMid, 0.55 + 0.3 * vFront);
  else if (vKind > 2.5) col = mix(uDeep, uMid, 0.35);
  else                  col = mix(uMid, uHot, clamp(0.25 + uHeat + (vKind < 0.5 ? 0.45 : 0.0) + 0.25 * vTw * vFront, 0.0, 1.0));
  float k = vKind > 3.5 ? 2.2 : vKind > 2.5 ? 0.35 : 1.0;
  float i = vBright * uEnergy * uIntensity * k;
  vec3 c = (col * halo * 0.55 + mix(col, uHot, 0.7) * core) * i;
  float a = clamp((halo * 0.4 + core) * i, 0.0, 1.0);
  FRAGCOLOR = vec4(c, a);
}
