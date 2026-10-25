.pragma library
// Géométrie de l'orbe Jarvis : portage de buildGeometry() de ~/qg/jarvis-3d/jarvis-orb.js (même graine, même réseau).
// Différences avec la version web, imposées par Quick3D (ProceduralMesh = attributs standard seulement) :
//   filaments : positions = aA, uv0s = aB.xy, uv1s = (aB.z, côté × (1 + s)), colors = aSeed
//   points    : dessinés en quads (pas de gl_PointCoord) : positions = aPos, colors = aSeed, uv0s = coin, uv1s = (kind, 0)
// (pas de normals : Quick3D peut les normaliser, ce qui déplacerait les nœuds intérieurs)
// Le résultat est mis en cache par niveau de qualité : ouvrir l'orbe une 2e fois ne recalcule rien.

var TIERS = [
    { nodes: 1100, dust: 1300, ring: 420, k: 4, seg: 6 },
    { nodes: 760,  dust: 850,  ring: 340, k: 4, seg: 5 },
    { nodes: 500,  dust: 520,  ring: 260, k: 3, seg: 4 },
    { nodes: 300,  dust: 260,  ring: 180, k: 3, seg: 3 },
    { nodes: 180,  dust: 120,  ring: 120, k: 3, seg: 3 },
];

var _cache = {};

function mulberry32(a) {
    return function () {
        a |= 0; a = (a + 0x6D2B79F5) | 0; var t = Math.imul(a ^ (a >>> 15), 1 | a);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

function hyp(p) { return Math.sqrt(p[0] * p[0] + p[1] * p[1] + p[2] * p[2]); }

function build(tierIndex) {
    tierIndex = Math.max(0, Math.min(TIERS.length - 1, tierIndex | 0));
    if (_cache[tierIndex]) return _cache[tierIndex];
    var tier = TIERS[tierIndex];
    var rnd = mulberry32(20151);   // graine fixe : le « visage » de Jarvis est toujours le même
    var nodes = [];
    var nCore = Math.round(tier.nodes * 0.08), nInner = Math.round(tier.nodes * 0.27);
    var nShell = tier.nodes - nCore - nInner;
    var golden = Math.PI * (3 - Math.sqrt(5));
    var i, j, q;
    for (i = 0; i < nShell; i++) {
        var y = 1 - (i + 0.5) / nShell * 2, rr = Math.sqrt(1 - y * y), th = golden * i;
        var r = 1 + (rnd() - 0.5) * 0.09, jit = 0.06;
        nodes.push({ p: [Math.cos(th) * rr * r + (rnd() - .5) * jit, y * r + (rnd() - .5) * jit, Math.sin(th) * rr * r + (rnd() - .5) * jit], kind: 2 });
    }
    var randDir = function () { var u = rnd() * 2 - 1, t = rnd() * Math.PI * 2, s = Math.sqrt(1 - u * u); return [s * Math.cos(t), u, s * Math.sin(t)]; };
    for (i = 0; i < nInner; i++) { var d1 = randDir(), r1 = 0.42 + Math.pow(rnd(), 0.7) * 0.42; nodes.push({ p: [d1[0] * r1, d1[1] * r1, d1[2] * r1], kind: 1 }); }
    for (i = 0; i < nCore; i++) { var d2 = randDir(), r2 = Math.pow(rnd(), 1.5) * 0.3; nodes.push({ p: [d2[0] * r2, d2[1] * r2, d2[2] * r2], kind: 0 }); }

    // filaments : k plus proches voisins (dans une distance max), sans doublons
    var N = nodes.length, edges = new Map();
    var dist2 = function (a, b) { var x = a[0] - b[0], y = a[1] - b[1], z = a[2] - b[2]; return x * x + y * y + z * z; };
    var maxD = Math.sqrt(4 * Math.PI / nShell) * 2.1;
    var addEdge = function (a, b, syn) { var key = a < b ? a * N + b : b * N + a; if (!edges.has(key)) edges.set(key, [a, b, syn]); };
    var extra = [];
    for (i = 0; i < N; i++) {
        var best = [];
        for (j = 0; j < N; j++) {
            if (j === i) continue;
            var dd = dist2(nodes[i].p, nodes[j].p);
            if (best.length < tier.k) { best.push([dd, j]); best.sort(function (a, b) { return a[0] - b[0]; }); }
            else if (dd < best[tier.k - 1][0]) { best[tier.k - 1] = [dd, j]; best.sort(function (a, b) { return a[0] - b[0]; }); }
        }
        var lim = nodes[i].kind === 2 ? maxD : maxD * 1.6;
        for (q = 0; q < best.length; q++) if (Math.sqrt(best[q][0]) < lim) addEdge(i, best[q][1], 0);
    }
    // synapses longues : du cœur/intérieur vers la coque
    var nSyn = Math.round(tier.nodes * 0.07);
    for (var s = 0; s < nSyn; s++) {
        var a = nShell + Math.floor(rnd() * (nInner + nCore));
        var pa = nodes[a].p, la = hyp(pa) || 1;
        var bestJ = -1, bestD = 1e9;
        for (var t = 0; t < 24; t++) {
            var jj = Math.floor(rnd() * nShell);
            var d3 = dist2([pa[0] / la, pa[1] / la, pa[2] / la], nodes[jj].p);
            if (d3 < bestD) { bestD = d3; bestJ = jj; }
        }
        if (bestJ >= 0) addEdge(a, bestJ, 1);
    }
    // flux : arcs de grands cercles autour de la sphère, découpés en tronçons
    var nStreams = Math.round(tier.nodes / 70);
    var cr = function (a, b) { return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]; };
    var nz = function (v) { var l = hyp(v); return [v[0] / l, v[1] / l, v[2] / l]; };
    for (s = 0; s < nStreams; s++) {
        var ax = randDir(), tmp = Math.abs(ax[1]) < 0.9 ? [0, 1, 0] : [1, 0, 0];
        var u = nz(cr(ax, tmp)), w = cr(ax, u);
        var R = 1.07 + rnd() * 0.2, len = 0.9 + rnd() * 2.2, a0 = rnd() * Math.PI * 2, pieces = Math.ceil(len / 0.16);
        var sz = rnd(), sy = rnd(), sx = rnd();
        var at = (function (u, w, R) { return function (ang) {
            return [(u[0] * Math.cos(ang) + w[0] * Math.sin(ang)) * R, (u[1] * Math.cos(ang) + w[1] * Math.sin(ang)) * R, (u[2] * Math.cos(ang) + w[2] * Math.sin(ang)) * R];
        }; })(u, w, R);
        for (q = 0; q < pieces; q++) extra.push([at(a0 + len * q / pieces), at(a0 + len * (q + 1) / pieces), 2, [sx, sy, sz, 2]]);
    }

    var all = [];
    edges.forEach(function (e) {
        var i0 = e[0], j0 = e[1];
        // orientation : A = plus proche du centre (les impulsions « sortent » du cœur)
        if (hyp(nodes[i0].p) > hyp(nodes[j0].p) + (rnd() - 0.5) * 0.02) { var sw = i0; i0 = j0; j0 = sw; }
        all.push([nodes[i0].p, nodes[j0].p, [rnd(), rnd(), rnd(), e[2]]]);
    });
    for (q = 0; q < extra.length; q++) all.push([extra[q][0], extra[q][1], extra[q][3]]);

    var SEG = tier.seg, VPE = (SEG + 1) * 2;
    var lPos = [], lUv0 = [], lUv1 = [], lCol = [], lIdx = [];
    var v3 = Qt.vector3d, v4 = Qt.vector4d, v2 = Qt.vector2d;
    for (var e = 0; e < all.length; e++) {
        var A = all[e][0], B = all[e][1], sd = all[e][2];
        var vA = v3(A[0], A[1], A[2]), vBxy = v2(B[0], B[1]), vS = v4(sd[0], sd[1], sd[2], sd[3]);
        for (q = 0; q <= SEG; q++) for (var side = 0; side < 2; side++) {
            lPos.push(vA); lUv0.push(vBxy); lCol.push(vS); lUv1.push(v2(B[2], (side ? 1 : -1) * (1 + q / SEG)));
        }
        for (q = 0; q < SEG; q++) {
            var b = e * VPE + q * 2;
            lIdx.push(b, b + 1, b + 2, b + 1, b + 3, b + 2);
        }
    }

    // points (quads) : nœuds + poussière + 2 anneaux en pointillés
    var pPos = [], pUv0 = [], pUv1 = [], pCol = [], pIdx = [], np = 0;
    var corners = [[-1, -1], [1, -1], [-1, 1], [1, 1]];
    var pushPt = function (p, size, kind) {
        var vp = v3(p[0], p[1], p[2]), vs = v4(size, rnd(), rnd(), rnd());
        if (size <= 0) return;   // trous des pointillés : rien à dessiner
        var vk = v2(kind, 0);
        for (var c = 0; c < 4; c++) { pPos.push(vp); pCol.push(vs); pUv0.push(v2(corners[c][0], corners[c][1])); pUv1.push(vk); }
        var b = np * 4; pIdx.push(b, b + 1, b + 2, b + 1, b + 3, b + 2); np++;
    };
    var deg = new Uint16Array(N);
    edges.forEach(function (e) { deg[e[0]]++; deg[e[1]]++; });
    var densityK = Math.sqrt(760 / tier.nodes);
    for (i = 0; i < N; i++) {
        var n = nodes[i];
        var base = n.kind === 0 ? 4.2 : n.kind === 1 ? 3.0 : 3.3;
        pushPt(n.p, (base + deg[i] * 0.55 + rnd() * 1.5) * densityK, n.kind);
    }
    for (i = 0; i < tier.dust; i++) { var d4 = randDir(), r4 = 1.18 + Math.pow(rnd(), 1.6) * 1.2; pushPt([d4[0] * r4, d4[1] * r4, d4[2] * r4], 1.2 + rnd() * 2.2, 3); }
    for (var ring = 0; ring < 2; ring++) {
        var RR = ring ? 1.36 : 1.24, nr = tier.ring;
        for (i = 0; i < nr; i++) {
            var tt = i / nr;
            var sg = Math.floor(tt * (ring ? 14 : 22));
            if (ring === 0 && sg % 4 === 3) { pushPt([0, 0, 0], 0, 4); continue; }
            if (ring === 1 && (sg % 7 === 2 || sg % 7 === 5) && (tt * 98) % 1 > 0.3) { pushPt([0, 0, 0], 0, 5); continue; }
            var ang = tt * Math.PI * 2;
            pushPt([Math.cos(ang) * RR, (rnd() - 0.5) * 0.008, Math.sin(ang) * RR], (ring ? 2.4 : 3.0) + rnd() * 0.6, 4 + ring);
        }
    }
    _cache[tierIndex] = {
        lines: { positions: lPos, uv0s: lUv0, uv1s: lUv1, colors: lCol, indexes: lIdx },
        points: { positions: pPos, uv0s: pUv0, uv1s: pUv1, colors: pCol, indexes: pIdx },
        nodes: N, edges: all.length, pointCount: np,
    };
    return _cache[tierIndex];
}
