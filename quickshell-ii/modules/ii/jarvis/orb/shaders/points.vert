// Généré par orb/gen-shaders.py depuis ~/qg/jarvis-3d/jarvis-orb.js — ne pas éditer à la main.
VARYING float vBright;
VARYING float vKind;
VARYING float vFront;
VARYING float vTw;
VARYING vec2 vCoord;

// Description : Array and textureless GLSL 2D/3D/4D simplex noise functions.
//      Author : Ian McEwan, Ashima Arts.  Maintainer : stegu
//     License : Copyright (C) 2011 Ashima Arts. All rights reserved.
//               Distributed under the MIT License. See LICENSE file.
//               https://github.com/stegu/webgl-noise
vec3 mod289(vec3 x){return x-floor(x*(1.0/289.0))*289.0;}
vec4 mod289(vec4 x){return x-floor(x*(1.0/289.0))*289.0;}
vec4 permute(vec4 x){return mod289(((x*34.0)+10.0)*x);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159-0.85373472095314*r;}
float snoise(vec3 v){
  const vec2 C=vec2(1.0/6.0,1.0/3.0); const vec4 D=vec4(0.0,0.5,1.0,2.0);
  vec3 i=floor(v+dot(v,C.yyy)); vec3 x0=v-i+dot(i,C.xxx);
  vec3 g=step(x0.yzx,x0.xyz); vec3 l=1.0-g; vec3 i1=min(g.xyz,l.zxy); vec3 i2=max(g.xyz,l.zxy);
  vec3 x1=x0-i1+C.xxx; vec3 x2=x0-i2+C.yyy; vec3 x3=x0-D.yyy;
  i=mod289(i);
  vec4 p=permute(permute(permute(i.z+vec4(0.0,i1.z,i2.z,1.0))+i.y+vec4(0.0,i1.y,i2.y,1.0))+i.x+vec4(0.0,i1.x,i2.x,1.0));
  float n_=0.142857142857; vec3 ns=n_*D.wyz-D.xzx;
  vec4 j=p-49.0*floor(p*ns.z*ns.z); vec4 x_=floor(j*ns.z); vec4 y_=floor(j-7.0*x_);
  vec4 x=x_*ns.x+ns.yyyy; vec4 y=y_*ns.x+ns.yyyy; vec4 h=1.0-abs(x)-abs(y);
  vec4 b0=vec4(x.xy,y.xy); vec4 b1=vec4(x.zw,y.zw);
  vec4 s0=floor(b0)*2.0+1.0; vec4 s1=floor(b1)*2.0+1.0; vec4 sh=-step(h,vec4(0.0));
  vec4 a0=b0.xzyw+s0.xzyw*sh.xxyy; vec4 a1=b1.xzyw+s1.xzyw*sh.zzww;
  vec3 p0=vec3(a0.xy,h.x); vec3 p1=vec3(a0.zw,h.y); vec3 p2=vec3(a1.xy,h.z); vec3 p3=vec3(a1.zw,h.w);
  vec4 norm=taylorInvSqrt(vec4(dot(p0,p0),dot(p1,p1),dot(p2,p2),dot(p3,p3)));
  p0*=norm.x; p1*=norm.y; p2*=norm.z; p3*=norm.w;
  vec4 m=max(0.5-vec4(dot(x0,x0),dot(x1,x1),dot(x2,x2),dot(x3,x3)),0.0); m=m*m;
  return 105.0*dot(m*m,vec4(dot(p0,x0),dot(p1,x1),dot(p2,x2),dot(p3,x3)));
}


vec3 displace(vec3 p, float mobility){
  float r = length(p);
  vec3 n = r > 1e-4 ? p / r : vec3(0.0, 1.0, 0.0);
  vec3 q = p * 1.35;
  vec3 d = vec3(snoise(q + vec3(0.0, 0.0, uT)),
                snoise(q + vec3(31.4, 0.0, uT * 1.13)),
                snoise(q + vec3(0.0, 17.2, uT * 0.91)));
  float lv = uLevel * uLevelGain;
  float amp = (uNoiseAmp + lv * 0.16) * mobility;
  vec3 o = p * uBreath * uScale + d * amp * (0.45 + 0.55 * r);
  // écoute : le réseau gonfle avec la voix, rugosité fine en plus
  o += n * lv * 0.11 * r;
  o += n * lv * 0.05 * snoise(p * 4.0 + uT * 3.0);
  // réponse : ondes radiales qui partent du cœur + battement global
  float w = pow(0.5 + 0.5 * sin(r * 8.0 - uWavePhase), 3.0);
  o += n * uWave * (0.025 + 0.11 * uBeat) * w * r;
  o += n * uWave * uBeat * 0.05 * r;
  // ping : front d'onde qui balaie la sphère
  float s = dot(n, uShockDir);
  float front = uShock * 2.8 - 1.4;
  o += n * exp(-pow((s - front) * 5.0, 2.0)) * 0.13 * uShockAmp * r;
  return o;
}
vec3 toView(vec3 p){ vec3 v = mat3(uRot) * p; v.z -= uDist; return v; }
vec4 toClip(vec3 v){ return vec4(v.x * uProj.x, v.y * uProj.y, -v.z * 1.002 - 0.2, -v.z); }
// 0 = arrière de la sphère, 1 = avant
float frontness(vec3 v){ return clamp((v.z + uDist + 1.4) / 2.8, 0.0, 1.0); }
float scanBand(vec3 world){ return exp(-pow((world.y - uScanY) * 9.0, 2.0)) * uScan; }mat3 rotAxis(vec3 a, float t){
  float c = cos(t), s = sin(t), ic = 1.0 - c;
  return mat3(c + a.x*a.x*ic, a.y*a.x*ic + a.z*s, a.z*a.x*ic - a.y*s,
              a.x*a.y*ic - a.z*s, c + a.y*a.y*ic, a.z*a.y*ic + a.x*s,
              a.x*a.z*ic + a.y*s, a.y*a.z*ic - a.x*s, c + a.z*a.z*ic);
}
void MAIN(){
  vec3 aPos = VERTEX; vec4 aSeed = COLOR; float aKind = UV1.x; vCoord = UV0;

  vec3 world; vec3 v; float size = aSeed.x; float bright = 1.0;
  if (aKind > 3.5) {
    // anneaux holographiques : hors réseau, rotation propre, respirent avec le niveau
    bool b = aKind > 4.5;
    vec3 axis = b ? normalize(vec3(0.35, 1.0, -0.2)) : normalize(vec3(-0.25, 1.0, 0.45));
    float sc = uScale * uBreath * (1.0 + uLevel * uLevelGain * 0.07 + uBeat * uWave * 0.025);
    world = rotAxis(axis, b ? uRingB : uRingA) * aPos * sc;
    v = world; v.z -= uDist;      // les anneaux ne suivent pas la rotation du réseau
    bright = uRing;
  } else if (aKind > 2.5) {
    // poussière : dérive lente et ample
    vec3 p = aPos + vec3(snoise(aPos * 0.6 + uT * 0.3), snoise(aPos * 0.6 + 9.1 + uT * 0.3), snoise(aPos * 0.6 + 4.7 + uT * 0.3)) * 0.18;
    world = mat3(uRot) * (p * uScale);
    v = world; v.z -= uDist;
    bright = 0.55;
  } else {
    vec3 p = displace(aPos, aKind < 0.5 ? 0.6 : 1.0);
    world = mat3(uRot) * p;
    v = toView(p);
  }
  POSITION = toClip(v);
  vFront = frontness(v);
  float tw = 0.65 + 0.35 * sin(uTime * (1.2 + 2.5 * aSeed.z) + aSeed.y * 40.0);
  vTw = tw;
  bright *= tw * (0.35 + 0.65 * vFront) * (1.0 + scanBand(world) * 2.5);
  vBright = bright;
  vKind = aKind;
  float ptSize; ptSize = clamp(size * uPx / -v.z * (0.75 + 0.25 * uEnergy + 0.25 * uBeat * uWave), 1.0, 48.0);
  POSITION.xy += UV0 * ptSize * 0.5 / uRes * POSITION.w;
  POSITION.y *= sign(PROJECTION_MATRIX[1][1]);
}
