#!/usr/bin/env python3
"""Génère les shaders Quick3D de l'orbe (orb/*.vert|frag) à partir des sources GLSL de ~/qg/jarvis-3d/jarvis-orb.js.
Le GLSL est recopié tel quel autant que possible ; seules changent les entrées (attributs Quick3D) et la sortie
(POSITION / FRAGCOLOR). Relancer après toute retouche des shaders web, puis comparer les captures."""
import pathlib, re, sys

out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent / "shaders")
src = pathlib.Path.home().joinpath("qg/jarvis-3d/jarvis-orb.js")
if not src.exists():
    src = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "jarvis-orb.js")
js = src.read_text()

def block(name):
    m = re.search(r"const " + name + r" = /\* glsl \*/ `(.*?)`;", js, re.S)
    return m.group(1)

NOISE = block("NOISE")
# COMMON sans ses déclarations d'uniformes (Quick3D les déclare depuis les propriétés QML)
COMMON = "\n".join(l for l in block("COMMON").splitlines() if not l.startswith("uniform"))
COMMON = COMMON.replace("uniform mat3 uRot;", "")
# uRot est un matrix4x4 côté QML
COMMON = COMMON.replace("uRot * p", "mat3(uRot) * p")

HEAD = "// Généré par orb/gen-shaders.py depuis ~/qg/jarvis-3d/jarvis-orb.js — ne pas éditer à la main.\n"
# Clip space : Quick3D (RHI) peut inverser Y selon le backend ; PROJECTION_MATRIX de la caméra le dit.
FLIP = "  gl_Position.y *= sign(PROJECTION_MATRIX[1][1]);\n"

def vs(body, attrs, varyings):
    body = body.split("\n", 2)[2]           # retire #version / precision
    body = re.sub(r"^\$\{NOISE\}\n\$\{COMMON\}\n", "", body, flags=re.M)
    body = re.sub(r"^in .*\n", "", body, flags=re.M)
    body = re.sub(r"^out .*\n", "", body, flags=re.M)
    body = re.sub(r"^uniform .*\n", "", body, flags=re.M)
    body = body.replace("void main(){", "void MAIN(){\n" + attrs, 1)
    body = body.replace("gl_PointSize", "float ptSize")
    body = re.sub(r"\}\s*$", "", body.rstrip())
    body = body.replace("gl_Position", "POSITION")
    return HEAD + varyings + NOISE + COMMON + body + FLIP.replace("gl_Position", "POSITION") + "}\n"

def fs(body, varyings, pre=""):
    body = body.split("\n", 2)[2]
    body = re.sub(r"^in .*\n", "", body, flags=re.M)
    body = re.sub(r"^out .*\n", "", body, flags=re.M)
    body = re.sub(r"^uniform .*\n", "", body, flags=re.M)
    body = body.replace("void main(){", "void MAIN(){\n" + pre, 1)
    body = body.replace("frag = ", "FRAGCOLOR = ")
    return HEAD + varyings + body + "\n"

LV = "VARYING float vAcross;\nVARYING float vT;\nVARYING float vAlpha;\nVARYING vec4 vSeed;\nVARYING float vFront;\nVARYING float vScanL;\nVARYING float vRim;\n"
line_vs = vs(block("LINE_VS"),
             "  vec3 aA = VERTEX; vec3 aB = vec3(UV0, UV1.x); vec4 aSeed = COLOR; vec2 aCorner = vec2(sign(UV1.y), abs(UV1.y) - 1.0);\n", LV)
# curve() lit aSeed (attribut global en WebGL) : on le passe en varying-like global
line_vs = line_vs.replace("vec3 curve(vec3 pA, vec3 pB, float s, float syn){", "vec4 aSeed;\nvec3 curve(vec3 pA, vec3 pB, float s, float syn){")
line_vs = line_vs.replace("vec4 aSeed = COLOR;", "aSeed = COLOR;")  # curve() lit le aSeed global
line_fs = fs(block("LINE_FS"), LV)

PV = "VARYING float vBright;\nVARYING float vKind;\nVARYING float vFront;\nVARYING float vTw;\nVARYING vec2 vCoord;\n"
point_vs = vs(block("POINT_VS"),
              "  vec3 aPos = VERTEX; vec4 aSeed = COLOR; float aKind = UV1.x; vCoord = UV0;\n", PV)
# point sprite → quad : on décale chaque coin de la moitié de la taille en pixels
point_vs = point_vs.replace(FLIP.replace("gl_Position", "POSITION"),
    "  POSITION.xy += UV0 * ptSize * 0.5 / uRes * POSITION.w;\n" + FLIP.replace("gl_Position", "POSITION"))
point_vs = point_vs.replace("float ptSize = clamp", "float ptSize = clamp")
point_vs = point_vs.replace("  float ptSize = clamp", "  float ptSize; ptSize = clamp")
point_fs = fs(block("POINT_FS"), PV).replace("vec2 d = gl_PointCoord * 2.0 - 1.0;", "vec2 d = vCoord;")

GV = "VARYING vec2 vUv;\n"
glow_vs = HEAD + GV + "void MAIN(){\n  vec2 aQuad = VERTEX.xy;\n" + \
    block("GLOW_VS").split("void main(){", 1)[1].rstrip().rstrip("}") + "\n" + FLIP.replace("gl_Position", "POSITION") + "}\n"
glow_vs = glow_vs.replace("gl_Position", "POSITION")
glow_fs = fs(block("GLOW_FS"), GV)

out.mkdir(parents=True, exist_ok=True)
def fixrot(t):
    return re.sub(r"(?<!mat3\()uRot \*", "mat3(uRot) *", t)

for name, txt in [("lines.vert", line_vs), ("lines.frag", line_fs), ("points.vert", point_vs),
                  ("points.frag", point_fs), ("glow.vert", glow_vs), ("glow.frag", glow_fs)]:
    (out / name).write_text(fixrot(txt))
    print("écrit", out / name)
