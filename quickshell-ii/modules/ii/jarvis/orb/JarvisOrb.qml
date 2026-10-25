import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import "geometry.js" as OrbGeometry

// Orbe « Jarvis vivant » : même réseau neuronal que la version web (~/qg/jarvis-3d/jarvis-orb.js),
// rendu par Quick3D avec les mêmes shaders GLSL (shaders/*.vert|frag, générés par gen-shaders.py).
// Aucune dépendance à ii : se teste seul avec `qml`. Ne tourne (FrameAnimation) que si `running`.
//
// Réglages d'apparence (pour l'évolution « L'Ère d'Ultron ») : orbPalette, intensity, quality, glowScale,
// lineWidth, ringBrightness, dustBrightness ; les cibles par état sont dans `stateTargets`.
Item {
    id: orb

    // --- API (mêmes noms que l'élément web)
    property string jarvisState: "idle"    // idle | listening | thinking | speaking
    property real level: 0                 // 0..1 ; à mettre à jour en continu (micro / voix)
    property var orbPalette: "blue"        // nom de `palettes` ou { deep:[r,g,b], mid:[…], hot:[…] } (0..1)
    property real intensity: 1
    property int quality: 1                // 0 (1100 nœuds) … 4 (180 nœuds)
    property bool running: visible
    property bool reducedMotion: false
    // Dossier des shaders (URL ou chemin absolu). Sous Quickshell, passer un chemin file:// explicite.
    property string shaderBase: Qt.resolvedUrl("shaders/")
    function _shader(n) { const b = shaderBase.startsWith("/") ? "file://" + shaderBase : shaderBase; return b + (b.endsWith("/") ? "" : "/") + n; }
    // Niveau sonore : à appeler à chaque mesure, même si la valeur ne change pas (horodatage)
    function setLevel(v) { s.levelRaw = Math.max(0, Math.min(1, +v || 0)); s.levelAt = Date.now(); }

    // --- Réglages fins d'apparence
    property real glowScale: 1.0           // taille du halo du cœur
    property real lineWidth: 1.0           // épaisseur des filaments
    property real ringBrightness: 1.0      // anneaux HUD
    property real pointScale: 1.0          // taille des nœuds / poussière
    property real fov: 28                  // champ de vision (°) : plus petit = orbe plus grande dans le cadre

    readonly property var palettes: ({
        blue: { deep: [0.03, 0.20, 1.00], mid: [0.16, 0.62, 1.00], hot: [0.80, 0.97, 1.00] },
        gold: { deep: [1.00, 0.26, 0.02], mid: [1.00, 0.60, 0.14], hot: [1.00, 0.93, 0.72] },
        ii:   { deep: [0.05, 0.30, 0.95], mid: [0.44, 0.83, 1.00], hot: [0.90, 0.99, 1.00] },
        cyan: { deep: [0.00, 0.42, 0.75], mid: [0.10, 0.90, 0.95], hot: [0.85, 1.00, 1.00] }
    })
    // Cibles par état (interpolées à chaque image), copie de STATES dans jarvis-orb.js
    property var stateTargets: ({
        idle:      { breathAmp: 0.040, breathSpeed: 1.15, noiseAmp: 0.070, noiseSpeed: 0.10, flicker: 0.12,
                     pulseSpeed: 0.22, pulseDensity: 0.22, pulseDir: 1, spin: 0.055, energy: 0.78, heat: 0.0,
                     wave: 0.0, levelGain: 0.0, scale: 1.0, scan: 0.12, ring: 0.55 },
        listening: { breathAmp: 0.018, breathSpeed: 1.6, noiseAmp: 0.060, noiseSpeed: 0.22, flicker: 0.20,
                     pulseSpeed: 0.55, pulseDensity: 0.50, pulseDir: -1, spin: 0.09, energy: 0.92, heat: 0.12,
                     wave: 0.0, levelGain: 1.0, scale: 1.02, scan: 0.25, ring: 0.9 },
        thinking:  { breathAmp: 0.012, breathSpeed: 2.4, noiseAmp: 0.150, noiseSpeed: 0.55, flicker: 0.85,
                     pulseSpeed: 1.30, pulseDensity: 0.95, pulseDir: 1, spin: 0.36, energy: 1.0, heat: 0.38,
                     wave: 0.0, levelGain: 0.0, scale: 0.93, scan: 0.55, ring: 1.0 },
        speaking:  { breathAmp: 0.010, breathSpeed: 1.2, noiseAmp: 0.085, noiseSpeed: 0.25, flicker: 0.28,
                     pulseSpeed: 0.95, pulseDensity: 0.65, pulseDir: 1, spin: 0.12, energy: 1.0, heat: 0.22,
                     wave: 1.0, levelGain: 0.45, scale: 1.0, scan: 0.3, ring: 0.85 }
    })

    function ping() {
        const a = Math.random() * Math.PI * 2, y = Math.random() * 1.2 - 0.6, r = Math.sqrt(1 - y * y);
        s.shockDir = Qt.vector3d(Math.cos(a) * r, y, Math.sin(a) * r); s.shock = 0; s.shockAmp = 1;
    }

    // Niveau reçu : horodaté pour savoir s'il est récent (sinon enveloppe synthétique en parole)
    onLevelChanged: setLevel(level)

    readonly property var geo: OrbGeometry.build(quality)
    readonly property real dpr: Screen.devicePixelRatio || 1

    // --- État animé (équivalent de l'objet S du moteur web)
    QtObject {
        id: s
        property var cur: Object.assign({}, orb.stateTargets.idle)
        property var pal: orb._pal(orb.orbPalette)
        property real levelRaw: 0
        property real levelAt: -1e9
        property real lvl: 0
        property real beat: 0
        property real t: 0
        property real noiseT: 0
        property real breathPh: 0
        property real rotY: 0
        property real pulsePh: 0
        property real flickT: 0
        property real wavePh: 0
        property real ringA: 0
        property real ringB: 0
        property real scanPh: 0
        property real shock: 1
        property real shockAmp: 0
        property vector3d shockDir: Qt.vector3d(0, 1, 0)
        // valeurs dérivées poussées aux shaders
        property real breath: 1
        property matrix4x4 rot: Qt.matrix4x4()
        property vector3d deep: Qt.vector3d(0, 0, 1)
        property vector3d mid: Qt.vector3d(0, 0.5, 1)
        property vector3d hot: Qt.vector3d(1, 1, 1)
        // copies des cibles interpolées, en propriétés pour les liaisons des matériaux
        property real noiseAmp: 0
        property real scale: 1
        property real levelGain: 0
        property real wave: 0
        property real scan: 0
        property real energy: 0.78
        property real heat: 0
        property real pulseDensity: 0.2
        property real flicker: 0.12
        property real ring: 0.55
    }

    function _pal(p) {
        const v = (typeof p === "object" && p) ? p : (palettes[p] || palettes.blue);
        return { deep: v.deep.slice(), mid: v.mid.slice(), hot: v.hot.slice() };
    }
    property var _targetPal: _pal(orbPalette)

    function _lerp(a, b, t) { return a + (b - a) * t; }

    function _step(dt) {
        const tgt = stateTargets[jarvisState] || stateTargets.idle;
        const motion = reducedMotion ? 0.18 : 1;
        const ease = 1 - Math.exp(-dt * 2.6);
        const c = s.cur;
        for (const k in tgt) c[k] = _lerp(c[k], tgt[k], k === "pulseDir" ? 1 - Math.exp(-dt * 1.5) : ease);
        const tp = _targetPal, pk = 1 - Math.exp(-dt * 3);
        for (const k of ["deep", "mid", "hot"]) for (let i = 0; i < 3; i++) s.pal[k][i] = _lerp(s.pal[k][i], tp[k][i], pk);

        // niveau : attaque rapide, relâche lente ; enveloppe synthétique en « speaking » sans entrée récente
        const now = Date.now();
        let raw = s.levelRaw;
        if (jarvisState === "speaking" && now - s.levelAt > 400) {
            const t = s.t;
            const syl = Math.max(0, Math.sin(t * 10.5) * 0.6 + Math.sin(t * 6.3 + 1.1) * 0.4);
            const phrase = 0.55 + 0.45 * Math.sin(t * 1.3) * Math.sin(t * 0.47 + 2.0);
            raw = Math.min(1, syl * syl * phrase * 1.4);
        } else if (now - s.levelAt > 1500) raw *= Math.exp(-dt * 2);
        s.levelRaw = raw;
        s.lvl = _lerp(s.lvl, raw, 1 - Math.exp(-dt * (raw > s.lvl ? 22 : 6)));
        s.beat = _lerp(s.beat, jarvisState === "speaking" ? s.lvl : 0, 1 - Math.exp(-dt * 18));

        s.t += dt * motion;
        s.noiseT += dt * c.noiseSpeed * motion * (1 + s.lvl * c.levelGain * 1.5);
        s.breathPh += dt * c.breathSpeed * (reducedMotion ? 0.5 : 1);
        s.rotY += dt * c.spin * motion;
        s.pulsePh += dt * c.pulseSpeed * c.pulseDir * motion * (reducedMotion ? 0 : 1);
        s.flickT += dt * (0.15 + c.flicker * 1.6) * motion;
        s.wavePh += dt * (5 + s.beat * 6) * motion;
        s.ringA += dt * (0.18 + c.spin * 0.8) * motion;
        s.ringB -= dt * (0.11 + c.spin * 0.6) * motion;
        s.scanPh += dt * (0.35 + c.flicker * 0.9) * motion;
        if (s.shock < 1) s.shock = Math.min(1, s.shock + dt * 0.9); else s.shockAmp = _lerp(s.shockAmp, 0, 1 - Math.exp(-dt * 4));

        // valeurs dérivées
        s.breath = 1 + c.breathAmp * Math.sin(s.breathPh) + c.breathAmp * 0.35 * Math.sin(s.breathPh * 0.43 + 1.3);
        const ay = s.rotY, ax = 0.32 + Math.sin(s.t * 0.07) * 0.08;
        const cy = Math.cos(ay), sy = Math.sin(ay), cx = Math.cos(ax), sx = Math.sin(ax);
        // R = Rx * Ry ; le web passe la matrice en colonne-major, matrix4x4 se donne ligne par ligne
        s.rot = Qt.matrix4x4(cy, 0, sy, 0,
                             sx * sy, cx, -sx * cy, 0,
                             -cx * sy, sx, cx * cy, 0,
                             0, 0, 0, 1);
        s.deep = Qt.vector3d(s.pal.deep[0], s.pal.deep[1], s.pal.deep[2]);
        s.mid = Qt.vector3d(s.pal.mid[0], s.pal.mid[1], s.pal.mid[2]);
        s.hot = Qt.vector3d(s.pal.hot[0], s.pal.hot[1], s.pal.hot[2]);
        s.noiseAmp = c.noiseAmp; s.scale = c.scale; s.levelGain = c.levelGain; s.wave = c.wave; s.scan = c.scan;
        s.energy = c.energy; s.heat = c.heat; s.pulseDensity = c.pulseDensity; s.flicker = c.flicker; s.ring = c.ring;
    }

    // Cadence plafonnée (Timer, pas FrameAnimation) : sur un écran 360 Hz l'orbe ne se redessine que `fps` fois/s,
    // et seulement quand une propriété change (Qt Quick ne rend rien sinon).
    property int fps: 60
    property real _last: 0
    Timer {
        interval: Math.max(8, Math.round(1000 / Math.max(1, orb.fps)))
        repeat: true
        running: orb.running && orb.visible && orb.width > 0
        onRunningChanged: orb._last = 0
        onTriggered: {
            const now = Date.now();
            const dt = orb._last ? (now - orb._last) / 1000 : interval / 1000;
            orb._last = now;
            orb._step(Math.min(dt, 0.05));
        }
    }

    // --- Projection (identique à draw() côté web)
    readonly property real pxW: Math.max(1, width * dpr)
    readonly property real pxH: Math.max(1, height * dpr)
    readonly property real focal: 1 / Math.tan((fov * Math.PI / 180) / 2)
    readonly property vector2d proj: pxW >= pxH ? Qt.vector2d(focal / (pxW / pxH), focal) : Qt.vector2d(focal, focal * (pxW / pxH))
    readonly property real dist: 6.0
    readonly property vector2d res: Qt.vector2d(pxW * 0.5, pxH * 0.5)

    View3D {
        id: view
        anchors.fill: parent
        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Transparent
            clearColor: "transparent"
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
            tonemapMode: SceneEnvironment.TonemapModeNone
        }
        // La caméra ne sert qu'à exposer PROJECTION_MATRIX (sens de l'axe Y) : les shaders écrivent POSITION eux-mêmes.
        camera: OrthographicCamera { z: 10 }

        // Lueur du cœur
        Model {
            geometry: ProceduralMesh {
                positions: [Qt.vector3d(-1, -1, 0), Qt.vector3d(1, -1, 0), Qt.vector3d(-1, 1, 0), Qt.vector3d(1, 1, 0)]
                indexes: [0, 1, 2, 1, 3, 2]
            }
            materials: CustomMaterial {
                shadingMode: CustomMaterial.Unshaded
                sourceBlend: CustomMaterial.One
                destinationBlend: CustomMaterial.One
                depthDrawMode: Material.NeverDepthDraw
                cullMode: Material.NoCulling
                vertexShader: orb._shader("glow.vert")
                fragmentShader: orb._shader("glow.frag")
                property vector2d uProj: orb.proj
                property real uDist: orb.dist
                property real uGlowR: 1.45 * s.scale * orb.glowScale * (1 + s.lvl * s.levelGain * 0.12 + s.beat * 0.08)
                property vector3d uDeep: s.deep
                property vector3d uMid: s.mid
                property vector3d uHot: s.hot
                property real uEnergy: s.energy
                property real uHeat: s.heat
                property real uIntensity: orb.intensity
                property real uGlowPulse: s.beat * 0.9 + s.lvl * s.levelGain * 0.5 + s.heat * 0.3
                property real uTime: s.t
            }
        }

        // Filaments
        Model {
            geometry: ProceduralMesh {
                positions: orb.geo.lines.positions
                uv0s: orb.geo.lines.uv0s
                uv1s: orb.geo.lines.uv1s
                colors: orb.geo.lines.colors
                indexes: orb.geo.lines.indexes
            }
            materials: CustomMaterial {
                shadingMode: CustomMaterial.Unshaded
                sourceBlend: CustomMaterial.One
                destinationBlend: CustomMaterial.One
                depthDrawMode: Material.NeverDepthDraw
                cullMode: Material.NoCulling
                vertexShader: orb._shader("lines.vert")
                fragmentShader: orb._shader("lines.frag")
                // communs
                property matrix4x4 uRot: s.rot
                property vector2d uProj: orb.proj
                property real uDist: orb.dist
                property vector2d uRes: orb.res
                property real uT: s.noiseT
                property real uNoiseAmp: s.noiseAmp
                property real uBreath: s.breath
                property real uScale: s.scale
                property real uLevel: s.lvl
                property real uLevelGain: s.levelGain
                property real uWave: s.wave
                property real uBeat: s.beat
                property real uWavePhase: s.wavePh
                property real uShock: s.shock
                property real uShockAmp: s.shockAmp
                property vector3d uShockDir: s.shockDir
                property real uScanY: Math.sin(s.scanPh) * 1.25
                property real uScan: s.scan
                property real uEnergy: s.energy
                property real uHeat: s.heat
                property vector3d uDeep: s.deep
                property vector3d uMid: s.mid
                property vector3d uHot: s.hot
                // filaments
                property real uLineW: (1.15 * orb.dpr + 0.6) * orb.lineWidth
                property real uFlicker: s.flicker
                property real uFlickT: s.flickT
                property real uPulsePhase: s.pulsePh
                property real uPulseDensity: s.pulseDensity
                property real uIntensity: orb.intensity
                property real uDensity: Math.min(1.25, Math.pow(760 / orb.geo.nodes, 0.6))
            }
        }

        // Nœuds, poussière, anneaux
        Model {
            geometry: ProceduralMesh {
                positions: orb.geo.points.positions
                uv0s: orb.geo.points.uv0s
                uv1s: orb.geo.points.uv1s
                colors: orb.geo.points.colors
                indexes: orb.geo.points.indexes
            }
            materials: CustomMaterial {
                shadingMode: CustomMaterial.Unshaded
                sourceBlend: CustomMaterial.One
                destinationBlend: CustomMaterial.One
                depthDrawMode: Material.NeverDepthDraw
                cullMode: Material.NoCulling
                vertexShader: orb._shader("points.vert")
                fragmentShader: orb._shader("points.frag")
                property matrix4x4 uRot: s.rot
                property vector2d uProj: orb.proj
                property real uDist: orb.dist
                property vector2d uRes: orb.res
                property real uT: s.noiseT
                property real uNoiseAmp: s.noiseAmp
                property real uBreath: s.breath
                property real uScale: s.scale
                property real uLevel: s.lvl
                property real uLevelGain: s.levelGain
                property real uWave: s.wave
                property real uBeat: s.beat
                property real uWavePhase: s.wavePh
                property real uShock: s.shock
                property real uShockAmp: s.shockAmp
                property vector3d uShockDir: s.shockDir
                property real uScanY: Math.sin(s.scanPh) * 1.25
                property real uScan: s.scan
                property real uEnergy: s.energy
                property real uHeat: s.heat
                property vector3d uDeep: s.deep
                property vector3d uMid: s.mid
                property vector3d uHot: s.hot
                property real uPx: Math.min(orb.pxW, orb.pxH) * 0.0105 * orb.pointScale
                property real uTime: s.t
                property real uRingA: s.ringA
                property real uRingB: s.ringB
                property real uRing: s.ring * orb.ringBrightness
                property real uIntensity: orb.intensity
            }
        }
    }
}
