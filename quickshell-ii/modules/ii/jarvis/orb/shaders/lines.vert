// Généré par orb/gen-shaders.py depuis ~/qg/jarvis-3d/jarvis-orb.js — ne pas éditer à la main.
VARYING float vAcross;
VARYING float vT;
VARYING float vAlpha;
VARYING vec4 vSeed;
VARYING float vFront;
VARYING float vScanL;
VARYING float vRim;

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
float scanBand(vec3 world){ return exp(-pow((world.y - uScanY) * 9.0, 2.0)) * uScan; }
// filament courbe : suit la sphère (arc) et ondule lentement comme un tissu nerveux
vec4 aSeed;
vec3 curve(vec3 pA, vec3 pB, float s, float syn){
  vec3 m = mix(pA, pB, s);
  float rr = mix(length(pA), length(pB), s);
  vec3 arc = normalize(m + 1e-5) * rr;
  bool isSyn = syn > 0.5 && syn < 1.5;
  m = mix(m, arc, isSyn ? 0.25 : 0.95);
  vec3 e = pB - pA; float L = length(e);
  vec3 side = normalize(cross(e, m + vec3(0.013, 0.007, 0.0)) + 1e-5);
  float sway = sin(uT * 2.1 + aSeed.y * 6.283) * 0.6 + sin(uT * 3.7 + aSeed.z * 9.0) * 0.4;
  m += side * sin(3.14159 * s) * L * sway * (isSyn ? 0.28 : syn > 1.5 ? 0.0 : 0.12);
  return m;
}
void MAIN(){
  vec3 aA = VERTEX; vec3 aB = vec3(UV0, UV1.x); aSeed = COLOR; vec2 aCorner = vec2(sign(UV1.y), abs(UV1.y) - 1.0);

  float syn = aSeed.w, s = aCorner.y;
  vec3 pA = displace(aA, 1.0), pB = displace(aB, 1.0);
  vec3 p  = curve(pA, pB, s, syn);
  float ds = s < 0.98 ? 0.02 : -0.02;
  vec3 p2 = curve(pA, pB, s + ds, syn);
  vec3 v = toView(p), v2 = toView(p2);
  vec4 c = toClip(v), c2 = toClip(v2);
  vec2 dir = (c2.xy / c2.w - c.xy / c.w) * uRes * sign(ds);
  float len = length(dir); dir = len > 1e-4 ? dir / len : vec2(1.0, 0.0);
  vec2 nrm = vec2(-dir.y, dir.x);
  // hiérarchie : quelques « nerfs » épais et lumineux, beaucoup de fils fins
  float nerve = pow(aSeed.z, 4.0);
  float stream = step(1.5, syn), isS = step(0.5, syn) - stream;
  float w = uLineW * (0.7 + 1.6 * nerve * (1.0 - stream) + 0.5 * isS - 0.15 * stream);
  c.xy += nrm * aCorner.x * w / uRes * c.w;
  POSITION = c;
  vAcross = aCorner.x; vT = s; vSeed = aSeed;
  // reconnexions : chaque filament s'allume/s'éteint selon un bruit lent (rapide en réflexion)
  float restLen = length(aA - aB), curLen = length(pA - pB);
  float stretch = smoothstep(1.6, 1.15, curLen / max(restLen, 1e-3));
  float fl = snoise(vec3(aSeed.y * 37.0, aSeed.z * 11.0, uFlickT));
  float on = mix(1.0, smoothstep(-0.05 + 0.5 * (1.0 - uFlicker), 0.35, fl), uFlicker);
  on = max(on, 0.06 + 0.12 * (1.0 - uFlicker));
  // pointes effilées aux extrémités, comme des fibres
  float taper = mix(smoothstep(0.0, 0.12, s) * smoothstep(1.0, 0.88, s) * 0.75 + 0.25, 1.0, stream);
  on = mix(on, 1.0, stream);
  vFront = frontness(v);
  vec3 vn = normalize(mat3(uRot) * p);
  vRim = 1.0 - abs(vn.z);
  vScanL = scanBand(mat3(uRot) * p);
  vAlpha = mix(stretch, 1.0, stream) * on * taper * (0.75 + 0.9 * nerve) * (isS > 0.5 ? 0.7 : 1.0);
  POSITION.y *= sign(PROJECTION_MATRIX[1][1]);
}
