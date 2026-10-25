// Généré par orb/gen-shaders.py depuis ~/qg/jarvis-3d/jarvis-orb.js — ne pas éditer à la main.
VARYING float vAcross;
VARYING float vT;
VARYING float vAlpha;
VARYING vec4 vSeed;
VARYING float vFront;
VARYING float vScanL;
VARYING float vRim;
void MAIN(){

  float across = exp(-vAcross * vAcross * 3.0);
  // impulsions (synapses) qui voyagent le long des filaments
  float stream = step(1.5, vSeed.w);
  float carrier = max(smoothstep(1.0 - uPulseDensity, 1.0 - uPulseDensity + 0.08, vSeed.x), stream * (0.35 + 0.65 * uPulseDensity));
  float head = fract(vSeed.y * 7.0 + uPulsePhase * (0.6 + 0.8 * vSeed.z) * (1.0 + stream * 1.5));
  float dp = vT - head; dp -= floor(dp + 0.5);
  float pulse = (exp(-dp * dp * 900.0) + 0.35 * exp(-dp * dp * 90.0)) * carrier;
  float rim = 0.55 + 0.9 * vRim * vRim;
  float base = (0.07 + 0.2 * vFront) * uEnergy * rim * (1.0 - 0.45 * stream);
  vec3 col = mix(uDeep, uMid, clamp(vFront * 0.7 + vRim * 0.35 + uHeat * 0.3, 0.0, 1.0));
  col = col * base + uHot * pulse * (0.9 + 0.6 * uEnergy) + uMid * vScanL * 0.6;
  float a = across * vAlpha * uIntensity * uDensity;
  FRAGCOLOR = vec4(col * a, a * (base + pulse));
}
