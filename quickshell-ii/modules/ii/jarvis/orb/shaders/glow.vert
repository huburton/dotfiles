// Généré par orb/gen-shaders.py depuis ~/qg/jarvis-3d/jarvis-orb.js — ne pas éditer à la main.
VARYING vec2 vUv;
void MAIN(){
  vec2 aQuad = VERTEX.xy;
 vUv = aQuad; vec2 s = aQuad * uGlowR / uDist * uProj; POSITION = vec4(s, 0.0, 1.0); 
  POSITION.y *= sign(PROJECTION_MATRIX[1][1]);
}
