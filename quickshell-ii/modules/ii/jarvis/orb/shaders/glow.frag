// Généré par orb/gen-shaders.py depuis ~/qg/jarvis-3d/jarvis-orb.js — ne pas éditer à la main.
VARYING vec2 vUv;
void MAIN(){

  float r = length(vUv);
  float fade = smoothstep(1.0, 0.55, r);
  float g1 = exp(-r * r * 7.0), g2 = exp(-r * r * 40.0), g3 = exp(-r * r * 2.2) * 0.35 * fade;
  float ang = atan(vUv.y, vUv.x);
  float rays = 0.85 + 0.15 * sin(ang * 7.0 + uTime * 0.4) * sin(ang * 3.0 - uTime * 0.27);
  vec3 c = uDeep * g3 * 0.6 + uMid * g1 * 0.45 * rays + mix(uMid, uHot, 0.6 + uHeat) * g2 * (0.55 + uGlowPulse);
  c *= (0.45 + 0.55 * uEnergy) * uIntensity;
  FRAGCOLOR = vec4(c, clamp(max(c.r, max(c.g, c.b)), 0.0, 1.0));
}
