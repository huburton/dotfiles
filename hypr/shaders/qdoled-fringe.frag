#version 300 es
// Généré par ~/.local/bin/oled-fringe — ne pas éditer à la main.
// Compensation des franges QD-OLED (vert en haut, rouge bas-gauche, bleu bas-droite)
// sur le seul framebuffer 2560x1440 ; les autres écrans passent tels quels.
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const ivec2 TARGET = ivec2(2560, 1440);
const float VG = 0.2500;
const float VRB = 0.2500;
const float H = 0.2000;
const int MARKER = 0;  // 0 rien, 1 bande en haut, 2 petit carré en haut à gauche

vec3 lin(vec3 c) { return pow(max(c, vec3(0.0)), vec3(2.2)); }
vec3 enc(vec3 c) { return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2)); }

void main() {
    // Sens de l'écran : la ligne 0 du buffer de sortie est le haut de la dalle et
    // gl_FragCoord.y croît vers le bas ; on suit v_texcoord dans ce sens.
    // (Dérivées calculées avant tout branchement.)
    float dy = dFdy(v_texcoord.y);
    float dx = dFdx(v_texcoord.x);
    vec4 c = texture(tex, v_texcoord);
    ivec2 size = textureSize(tex, 0);
    if (size != TARGET) { fragColor = c; return; }

    if (MARKER == 1 && gl_FragCoord.y < 24.0) { fragColor = vec4(1.0, 0.0, 1.0, 1.0); return; }
    if (MARKER == 2 && gl_FragCoord.y < 10.0 && gl_FragCoord.x < 10.0) { fragColor = vec4(1.0, 0.0, 1.0, 1.0); return; }

    ivec2 down = ivec2(0, dy > 0.0 ? 1 : -1);
    ivec2 right = ivec2(dx > 0.0 ? 1 : -1, 0);
    ivec2 p = clamp(ivec2(floor(v_texcoord * vec2(size))), ivec2(0), size - 1);
    ivec2 hi = size - 1;

    vec3 c0 = lin(texelFetch(tex, p, 0).rgb);
    vec3 cu = lin(texelFetch(tex, clamp(p - down, ivec2(0), hi), 0).rgb);
    vec3 cd = lin(texelFetch(tex, clamp(p + down, ivec2(0), hi), 0).rgb);
    vec3 cl = lin(texelFetch(tex, clamp(p - right, ivec2(0), hi), 0).rgb);
    vec3 cr = lin(texelFetch(tex, clamp(p + right, ivec2(0), hi), 0).rgb);
    vec3 cdl = lin(texelFetch(tex, clamp(p + down - right, ivec2(0), hi), 0).rgb);
    vec3 cdr = lin(texelFetch(tex, clamp(p + down + right, ivec2(0), hi), 0).rgb);

    float g = mix(c0.g, cu.g, VG);
    float r = mix(mix(c0.r, cd.r, VRB), mix(cl.r, cdl.r, VRB), H);
    float b = mix(mix(c0.b, cd.b, VRB), mix(cr.b, cdr.b, VRB), H);

    fragColor = vec4(enc(vec3(r, g, b)), c.a);
}
