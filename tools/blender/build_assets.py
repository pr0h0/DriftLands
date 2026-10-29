"""Procedural asset generator for Driftlands.

Run headless:
    blender -b -P tools/blender/build_assets.py -- assets/models [asset_name ...]

Every asset is built from code (no hand-made meshes) and exported as its own .glb.
Material *names* are the contract with Godot: res://scripts/mats.gd maps each name
to a stylized shader, so Blender materials here are just empty slots.
Vertex colors carry per-asset tint/AO (linear space).
"""
import bpy, bmesh, math, random, sys, os
from mathutils import Vector, Matrix, Euler, noise

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else "assets/models")
ONLY = set(argv[1:])
os.makedirs(OUT, exist_ok=True)

ASSETS = {}


def asset(name):
    def deco(fn):
        ASSETS[name] = fn
        return fn
    return deco


# ---------------------------------------------------------------- helpers

def clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def mat(name):
    return bpy.data.materials.get(name) or bpy.data.materials.new(name)


def fbm(p, octaves=3, seed=0.0):
    s, a, f = 0.0, 1.0, 1.0
    off = Vector((seed * 1.7, seed * 0.73, seed * 1.31))
    for _ in range(octaves):
        s += a * noise.noise(p * f + off)
        a *= 0.5
        f *= 2.0
    return s


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def lin(c):
    """Author colors in sRGB, store linear."""
    return tuple(max(0.0, x) ** 2.2 for x in c)


def mix3(a, b, t):
    return tuple(lerp(a[i], b[i], t) for i in range(3))


class Builder:
    """Accumulates geometry in one bmesh, with per-face material slots and corner colors."""

    def __init__(self, mats):
        self.bm = bmesh.new()
        self.mats = list(mats)
        self.col = self.bm.loops.layers.float_color.new("Color")

    def faces_of(self, verts):
        return list({f for v in verts for f in v.link_faces})

    def paint(self, faces, color):
        """color: rgb tuple, or fn(vertex_co) -> rgb."""
        for f in faces:
            for l in f.loops:
                c = color(l.vert.co) if callable(color) else color
                l[self.col] = (c[0], c[1], c[2], 1.0)

    def paint_faces(self, faces, fn):
        """fn(face_center) -> rgb, constant per face (hard-edged patterns)."""
        for f in faces:
            c = fn(f.calc_center_median())
            for l in f.loops:
                l[self.col] = (c[0], c[1], c[2], 1.0)

    def tag(self, faces, m, color=(1, 1, 1), smooth=False):
        idx = self.mats.index(m)
        for f in faces:
            f.material_index = idx
            f.smooth = smooth
        self.paint(faces, color)
        return faces

    def _add(self, res, m, color, smooth):
        verts = res["verts"]
        self.tag(self.faces_of(verts), m, color, smooth)
        return verts

    def box(self, loc, size, rot=(0, 0, 0), m=None, color=(1, 1, 1), smooth=False):
        mtx = Matrix.LocRotScale(Vector(loc), Euler(rot), Vector(size))
        return self._add(bmesh.ops.create_cube(self.bm, size=1.0, matrix=mtx), m or self.mats[0], color, smooth)

    def cyl(self, loc, r1, r2, h, segs=12, rot=(0, 0, 0), m=None, color=(1, 1, 1), smooth=False):
        mtx = Matrix.LocRotScale(Vector(loc), Euler(rot), None)
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segs,
                                    radius1=r1, radius2=r2, depth=h, matrix=mtx)
        return self._add(res, m or self.mats[0], color, smooth)

    def ico(self, loc, r, sub=2, scale=(1, 1, 1), m=None, color=(1, 1, 1), smooth=False):
        mtx = Matrix.LocRotScale(Vector(loc), None, Vector(scale))
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=r, matrix=mtx)
        return self._add(res, m or self.mats[0], color, smooth)

    def uvsphere(self, loc, r, u=16, v=10, scale=(1, 1, 1), m=None, color=(1, 1, 1), smooth=True):
        mtx = Matrix.LocRotScale(Vector(loc), None, Vector(scale))
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=u, v_segments=v, radius=r, matrix=mtx)
        return self._add(res, m or self.mats[0], color, smooth)

    def solid(self, cos, faces_idx, m=None, color=(1, 1, 1), smooth=False):
        vs = [self.bm.verts.new(c) for c in cos]
        fs = [self.bm.faces.new([vs[i] for i in f]) for f in faces_idx]
        bmesh.ops.recalc_face_normals(self.bm, faces=fs)
        self.tag(fs, m or self.mats[0], color, smooth)
        return vs

    def tube(self, pts, radii, segs=6, m=None, color=(1, 1, 1), smooth=False, cap=True):
        bm = self.bm
        d = (pts[-1] - pts[0]).normalized()
        up = Vector((1, 0, 0)) if abs(d.z) > 0.7 else Vector((0, 0, 1))
        rings = []
        for i, p in enumerate(pts):
            t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            u = t.cross(up).normalized()
            w = t.cross(u).normalized()
            rings.append([bm.verts.new(p + (u * math.cos(a) + w * math.sin(a)) * radii[i])
                          for a in (k / segs * math.tau for k in range(segs))])
        fs = []
        for A, B in zip(rings, rings[1:]):
            for j in range(segs):
                jn = (j + 1) % segs
                fs.append(bm.faces.new((A[j], A[jn], B[jn], B[j])))
        if cap:
            tip = bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * radii[-1])
            for j in range(segs):
                fs.append(bm.faces.new((rings[-1][j], rings[-1][(j + 1) % segs], tip)))
        bmesh.ops.recalc_face_normals(bm, faces=fs)
        self.tag(fs, m or self.mats[0], color, smooth)
        return [v for r in rings for v in r]

    def displace(self, verts, amp, freq, seed=0.0, center=None, octaves=2):
        self.bm.normal_update()
        for v in verts:
            dirv = (v.co - center).normalized() if center is not None else v.normal
            v.co += dirv * fbm(v.co * freq, octaves, seed) * amp

    def finish(self, name):
        me = bpy.data.meshes.new(name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(mat(m))
        attr = me.color_attributes.get("Color")
        if attr:
            me.color_attributes.active_color = attr
            try:
                me.color_attributes.render_color_index = me.color_attributes.find("Color")
            except Exception:
                pass
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def wedge(b, cx, cz, r0, r1, a0, a1, y0, y1, m="stone", color=(1, 1, 1)):
    """Ring segment in the XZ plane (for arch voussoirs), thickness along Y."""
    cos = []
    for y in (y0, y1):
        for a in (a0, a1):
            for r in (r0, r1):
                cos.append((cx + math.cos(a) * r, y, cz + math.sin(a) * r))
    # index = yi*4 + ai*2 + ri
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return b.solid(cos, faces, m, color)


def flat_wedge(b, r0, r1, a0, a1, z0, z1, m="stone", color=(1, 1, 1)):
    """Ring segment in the XY plane (floor tiles), thickness along Z."""
    cos = []
    for z in (z0, z1):
        for a in (a0, a1):
            for r in (r0, r1):
                cos.append((math.cos(a) * r, math.sin(a) * r, z))
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return b.solid(cos, faces, m, color)


MOSS = (0.62, 0.74, 0.48)


def stone_color(rnd, moss_height=0.9):
    t = rnd.uniform(0.86, 1.06)
    tone = (t, t * rnd.uniform(0.97, 1.01), t * rnd.uniform(0.95, 1.0))

    def fn(co):
        if moss_height <= 0 or co.z >= moss_height:
            return tone
        return mix3(MOSS, tone, smoothstep(0.0, moss_height, co.z))
    return fn


def export(name):
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_apply=True,
                              export_vertex_color='ACTIVE', export_yup=True)


# ---------------------------------------------------------------- islands

def build_island(R, depth, seed, flat_r=0.0, lobes=0.18, bumps=0.5, stal=6):
    rnd = random.Random(seed)
    b = Builder(["grass", "soil", "rock"])
    bm = b.bm
    NS = max(28, int(R * 2.6))
    NR = max(5, int(R / 1.4))
    NU = 7
    soff = Vector((seed * 3.1, seed * 1.7, 0))

    def rim(a):
        d = Vector((math.cos(a), math.sin(a), 0))
        return R * (1 + lobes * noise.noise(d * 1.2 + soff) + 0.05 * noise.noise(d * 4 + soff + Vector((0, 0, 3))))

    def top_h(x, y, t):
        h = (1 - t * t) * R * 0.04 + fbm(Vector((x, y, 0)) * 0.07, 3, seed) * bumps
        if flat_r > 0:
            k = smoothstep(flat_r, flat_r + 5, math.hypot(x, y))
            h = h * k + 0.25 * (1 - k)
        h -= smoothstep(0.82, 1.0, t) * 0.45
        return h

    angles = [i / NS * math.tau for i in range(NS)]
    rims = [rim(a) for a in angles]
    center = bm.verts.new((0, 0, top_h(0, 0, 0)))
    rings = []
    for i in range(1, NR + 1):
        t = i / NR
        ring = []
        for j, a in enumerate(angles):
            r = rims[j] * t
            x, y = math.cos(a) * r, math.sin(a) * r
            ring.append(bm.verts.new((x, y, top_h(x, y, t))))
        rings.append(ring)

    under = []
    lip = []
    for j in range(NS):
        v = rings[-1][j].co
        lip.append(bm.verts.new((v.x * 0.97, v.y * 0.97,
                                 v.z - 0.9 - 0.35 * abs(noise.noise(Vector((v.x * 0.3, v.y * 0.3, seed)))))))
    under.append(lip)
    tipoff = Vector((rnd.uniform(-1, 1) * R * 0.15, rnd.uniform(-1, 1) * R * 0.15, 0))
    for k in range(1, NU + 1):
        s = k / (NU + 1)
        ring = []
        for j, a in enumerate(angles):
            d = Vector((math.cos(a), math.sin(a), 0))
            jag = 1 + 0.2 * noise.noise(Vector((d.x * 2.5, d.y * 2.5, s * 3 + seed)))
            rr = rims[j] * 0.95 * (1 - s) ** 1.15 * jag
            z = -0.9 - depth * s ** 0.9 * (1 + 0.12 * noise.noise(Vector((d.x * 3, d.y * 3, seed + 5))))
            c = tipoff * s ** 1.5
            ring.append(bm.verts.new((c.x + d.x * rr, c.y + d.y * rr, z)))
        under.append(ring)
    tip = bm.verts.new((tipoff.x, tipoff.y, -0.9 - depth * 1.05))

    top_faces, soil_faces, rock_faces = [], [], []
    for j in range(NS):
        top_faces.append(bm.faces.new((center, rings[0][j], rings[0][(j + 1) % NS])))
    for i in range(NR - 1):
        for j in range(NS):
            jn = (j + 1) % NS
            top_faces.append(bm.faces.new((rings[i][j], rings[i + 1][j], rings[i + 1][jn], rings[i][jn])))
    chain = [rings[-1]] + under
    for k in range(len(chain) - 1):
        A, B = chain[k], chain[k + 1]
        for j in range(NS):
            jn = (j + 1) % NS
            (soil_faces if k == 0 else rock_faces).append(bm.faces.new((A[j], B[j], B[jn], A[jn])))
    for j in range(NS):
        rock_faces.append(bm.faces.new((chain[-1][j], tip, chain[-1][(j + 1) % NS])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])

    def rock_col(co):
        v = 0.45 + 0.55 * smoothstep(-depth, 0.0, co.z)
        return (v, v, v)

    b.tag(top_faces, "grass", lambda co: (1, 1, 1) if math.hypot(co.x, co.y) < R * 0.85 else (0.82, 0.82, 0.82),
          smooth=True)
    b.tag(soil_faces, "soil")
    b.tag(rock_faces, "rock", rock_col)

    # hanging rock teeth
    for _ in range(stal):
        a = rnd.uniform(0, math.tau)
        s = rnd.uniform(0.12, 0.5)
        rr = R * 0.95 * (1 - s) ** 1.15 * 0.8
        z = -0.9 - depth * s ** 0.9
        L = rnd.uniform(0.3, 0.6) * depth * (1 - s)
        r = rnd.uniform(0.5, 1.1) * R / 10
        vs = b.cyl((math.cos(a) * rr, math.sin(a) * rr, z - L / 2 + 0.6), 0.08, r, L, segs=6, m="rock")
        b.displace(vs, r * 0.35, 0.8, seed + _)
        b.paint(b.faces_of(vs), rock_col)
    b.finish("Island")


@asset("island_hub")
def _():
    build_island(24, 28, seed=3, flat_r=10, lobes=0.1, bumps=0.45, stal=9)


@asset("island_east")
def _():
    build_island(14, 18, seed=11, lobes=0.2, stal=6)


@asset("island_north")
def _():
    build_island(12, 26, seed=21, lobes=0.15, bumps=0.6, stal=5)


@asset("island_west")
def _():
    build_island(15, 20, seed=31, lobes=0.2, stal=7)


@asset("island_mid")
def _():
    build_island(10, 14, seed=41, lobes=0.22, stal=4)


@asset("island_small_a")
def _():
    build_island(5, 7, seed=51, lobes=0.15, bumps=0.25, stal=3)


@asset("island_small_b")
def _():
    build_island(4.5, 6, seed=61, lobes=0.2, bumps=0.25, stal=2)


@asset("island_small_c")
def _():
    build_island(5.5, 9, seed=71, lobes=0.2, bumps=0.3, stal=3)


# ---------------------------------------------------------------- ruins

def pillar(b, rnd, height=5.5, drums=4, broken=0, tilt=0.0):
    b.box((0, 0, 0.15), (1.25, 1.25, 0.3), color=stone_color(rnd))
    b.box((0, 0, 0.36), (1.02, 1.02, 0.12), color=stone_color(rnd))
    z = 0.42
    dh = (height - 0.42 - 0.4) / drums
    n = drums - broken
    for i in range(n):
        r = 0.4 - 0.015 * i
        last = broken and i == n - 1
        rot = (rnd.uniform(-1, 1) * tilt, rnd.uniform(-1, 1) * tilt, rnd.uniform(0, 1)) if last else (0, 0, rnd.uniform(0, 1))
        off = (rnd.uniform(-1, 1) * 0.05, rnd.uniform(-1, 1) * 0.05) if last else (0, 0)
        vs = b.cyl((off[0], off[1], z + dh / 2), r, r - 0.015, dh - 0.025, segs=12, rot=rot, color=stone_color(rnd))
        if last:
            for v in vs:
                if v.co.z > z + dh * 0.4:
                    v.co.z -= rnd.uniform(0.0, dh * 0.55)
        z += dh
    if not broken:
        b.box((0, 0, z + 0.09), (0.98, 0.98, 0.18), color=stone_color(rnd))
        b.box((0, 0, z + 0.28), (1.18, 1.18, 0.2), color=stone_color(rnd))


@asset("pillar_tall")
def _():
    b = Builder(["stone"])
    pillar(b, random.Random(1))
    b.finish("Pillar")


@asset("pillar_broken_a")
def _():
    b = Builder(["stone"])
    pillar(b, random.Random(2), broken=2)
    b.finish("Pillar")


@asset("pillar_broken_b")
def _():
    b = Builder(["stone"])
    pillar(b, random.Random(3), broken=1, tilt=0.12)
    b.finish("Pillar")


@asset("pillar_fallen")
def _():
    rnd = random.Random(4)
    b = Builder(["stone"])
    pillar(b, rnd, broken=3)
    y = 1.2
    for i in range(3):
        L = 1.12
        b.cyl((rnd.uniform(-0.25, 0.25), y + L / 2, 0.38), 0.39, 0.38, L - 0.03, segs=12,
              rot=(math.pi / 2 + rnd.uniform(-0.05, 0.05), 0, rnd.uniform(-0.2, 0.2)), color=stone_color(rnd, 2.0))
        y += L + rnd.uniform(0.05, 0.4)
    b.finish("Pillar")


def arch(b, rnd, broken=False):
    span, pier_h = 2.2, 3.4
    for sx in (-1, 1):
        hb = 1.5 if (broken and sx > 0) else pier_h
        z = 0.0
        while z < hb - 0.1:
            bh = min(rnd.uniform(0.45, 0.6), hb - z)
            b.box((sx * span + rnd.uniform(-0.02, 0.02), 0, z + bh / 2),
                  (1.0 + rnd.uniform(-0.04, 0.04), 1.1, bh - 0.025), rot=(0, 0, rnd.uniform(-0.03, 0.03)),
                  color=stone_color(rnd))
            z += bh
        if not (broken and sx > 0):
            b.box((sx * span, 0, pier_h + 0.1), (1.25, 1.25, 0.2), color=stone_color(rnd))
    cz = pier_h + 0.2
    N = 9
    for i in range(N):
        if broken and i < 5:
            continue
        a0 = i / N * math.pi + 0.008
        a1 = (i + 1) / N * math.pi - 0.008
        key = i == N // 2
        ro = span + 0.5 + (0.15 if key else 0)
        dy = 0.58 if key else 0.5
        wedge(b, 0, cz, span - 0.5, ro, a0, a1, -dy, dy, color=stone_color(rnd, 0.0))
    if broken:
        for _ in range(6):
            s = rnd.uniform(0.35, 0.6)
            b.box((span + rnd.uniform(-0.3, 2.2), rnd.uniform(-1.4, 1.4), s * 0.4),
                  (s * 1.6, s, s * 0.9), rot=(rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(0, 3)),
                  color=stone_color(rnd, 2.0))


@asset("arch")
def _():
    b = Builder(["stone"])
    arch(b, random.Random(5))
    b.finish("Arch")


@asset("arch_broken")
def _():
    b = Builder(["stone"])
    arch(b, random.Random(6), broken=True)
    b.finish("Arch")


def wall(b, rnd, seed, length=6.0, rows=6, bh=0.5, depth=0.7):
    def prof(x):
        return rows * (0.35 + 0.65 * (0.5 + 0.5 * noise.noise(Vector((x * 0.45, seed, 0.5)))))
    for r in range(rows):
        x = -length / 2 - (0.5 if r % 2 else 0.0)
        while x < length / 2:
            w = rnd.uniform(0.8, 1.25)
            x0, x1 = max(x, -length / 2), min(x + w, length / 2)
            cx = (x0 + x1) / 2
            if r < prof(cx) and x1 - x0 > 0.25:
                b.box((cx, rnd.uniform(-0.03, 0.03), r * bh + bh / 2),
                      (x1 - x0 - 0.03, depth + rnd.uniform(-0.06, 0.06), bh - 0.03),
                      rot=(0, 0, rnd.uniform(-0.025, 0.025)), color=stone_color(rnd))
            x += w
    for _ in range(5):
        s = rnd.uniform(0.3, 0.55)
        b.box((rnd.uniform(-length / 2, length / 2), rnd.choice((-1, 1)) * rnd.uniform(0.6, 1.4), s * 0.35),
              (s * 1.5, s, s * 0.8), rot=(rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(0, 3)),
              color=stone_color(rnd, 2.0))


@asset("wall_a")
def _():
    b = Builder(["stone"])
    wall(b, random.Random(7), 7)
    b.finish("Wall")


@asset("wall_b")
def _():
    b = Builder(["stone"])
    wall(b, random.Random(8), 8, length=4.5, rows=5)
    b.finish("Wall")


@asset("stairs")
def _():
    rnd = random.Random(9)
    n, rise, run, width = 6, 0.3, 0.55, 3.0
    steps = Builder(["stone"])
    for i in range(n):
        steps.box((rnd.uniform(-0.03, 0.03), i * run + run / 2, (i + 1) * rise / 2),
                  (width, run - 0.02, (i + 1) * rise), color=stone_color(rnd))
    for sx in (-1, 1):
        steps.box((sx * (width / 2 + 0.3), n * run / 2, n * rise / 2 + 0.1), (0.6, n * run, n * rise + 0.2),
                  color=stone_color(rnd))
    steps.finish("Steps_deco")
    plat = Builder(["stone"])
    top = n * rise
    plat.box((0, n * run + 2.0, top / 2), (4.2, 4.0, top), color=stone_color(rnd))
    for k in range(4):
        a = k / 4 * math.tau + math.pi / 4
        plat.box((math.cos(a) * 1.75, n * run + 2.0 + math.sin(a) * 1.75, top + 0.1), (0.5, 0.5, 0.2),
                 color=stone_color(rnd))
    plat.finish("Platform")
    ramp = Builder(["stone"])
    ramp.solid([(-width / 2, -0.15, 0), (width / 2, -0.15, 0), (width / 2, n * run, top), (-width / 2, n * run, top),
                (-width / 2, n * run, 0), (width / 2, n * run, 0)],
               [(0, 1, 2, 3), (0, 3, 4), (1, 5, 2), (0, 4, 5, 1), (3, 2, 5, 4)])
    ramp.finish("Ramp_invis")


@asset("plaza")
def _():
    rnd = random.Random(10)
    b = Builder(["stone"])
    flat_wedge(b, 0.0, 1.4, 0, math.tau / 3 - 0.02, -0.6, rnd.uniform(-0.02, 0.02), color=stone_color(rnd, -1))
    flat_wedge(b, 0.0, 1.4, math.tau / 3, 2 * math.tau / 3 - 0.02, -0.6, 0.0, color=stone_color(rnd, -1))
    flat_wedge(b, 0.0, 1.4, 2 * math.tau / 3, math.tau - 0.02, -0.6, 0.0, color=stone_color(rnd, -1))
    r = 1.45
    ring = 0
    while r < 9.5:
        w = 1.35
        n = max(6, int(math.tau * (r + w / 2) / 1.5))
        for k in range(n):
            if ring >= 3 and rnd.random() < 0.12 * (ring - 2):
                continue
            a0 = k / n * math.tau + (ring * 0.37)
            a1 = a0 + math.tau / n - 0.025
            top = rnd.uniform(-0.035, 0.03)
            moss = (0.75, 0.82, 0.62) if rnd.random() < 0.25 else (1, 1, 1)
            t = rnd.uniform(0.85, 1.05)
            flat_wedge(b, r, r + w - 0.03, a0, a1, -0.6, top, color=(moss[0] * t, moss[1] * t, moss[2] * t))
        r += w
        ring += 1
    b.finish("Plaza")


@asset("monolith")
def _():
    rnd = random.Random(12)
    b = Builder(["stone"])
    b.box((0, 0, 0.25), (3.4, 3.4, 0.5), color=stone_color(rnd, 0.4))
    b.box((0, 0, 0.7), (2.6, 2.6, 0.4), color=stone_color(rnd, 0.0))
    b.box((0, 0, 1.05), (1.8, 1.8, 0.3), color=stone_color(rnd, 0.0))
    z0, z1, h0, h1 = 1.2, 8.2, 0.55, 0.385
    vs = b.box((0, 0, (z0 + z1) / 2), (h0 * 2, h0 * 2, z1 - z0), color=stone_color(rnd, 0.0))
    for v in vs:
        if v.co.z > (z0 + z1) / 2:
            v.co.x *= h1 / h0
            v.co.y *= h1 / h0
    b.finish("Monolith")

    cap = Builder(["crystal"])
    cap.cyl((0, 0, z1 + 0.35), h1 * math.sqrt(2) * 0.98, 0.02, 0.7, segs=4, rot=(0, 0, math.pi / 4))
    cap.finish("Capstone_deco")

    def half(z):
        return lerp(h0, h1, (z - z0) / (z1 - z0))

    for band in range(3):
        rb = Builder(["rune"])
        zc = 2.5 + band * 1.9
        for face in range(4):
            for g, xo in enumerate((-0.24, 0.0, 0.24)):
                bars = [(0, 0, 0.06, 0.4)]  # (x, z, w, h) in glyph cell
                bars += [(rnd.choice((-0.06, 0.06)), rnd.uniform(-0.12, 0.12), 0.14, 0.05) for _ in range(rnd.randint(1, 3))]
                if rnd.random() < 0.5:
                    bars.append((rnd.choice((-0.07, 0.07)), rnd.uniform(-0.1, 0.1), 0.05, 0.2))
                for (bx, bz, bw, bhh) in bars:
                    zz = zc + bz
                    d = half(zz) + 0.012
                    u = xo + bx
                    if face == 0:
                        loc, size = (d, u, zz), (0.04, bw, bhh)
                    elif face == 1:
                        loc, size = (-d, -u, zz), (0.04, bw, bhh)
                    elif face == 2:
                        loc, size = (-u, d, zz), (bw, 0.04, bhh)
                    else:
                        loc, size = (u, -d, zz), (bw, 0.04, bhh)
                    rb.box(loc, size)
        rb.finish("Runes%d_deco" % (band + 1))


@asset("shrine")
def _():
    rnd = random.Random(13)
    b = Builder(["stone"])
    n = 10
    for k in range(n):
        a0, a1 = k / n * math.tau, (k + 1) / n * math.tau - 0.03
        flat_wedge(b, 0.0, 2.0, a0, a1, -0.4, 0.12 + rnd.uniform(-0.02, 0.02), color=stone_color(rnd, -1))
    b.cyl((0, 0, 0.6), 0.62, 0.5, 0.9, segs=8, color=stone_color(rnd, 0.6))
    b.cyl((0, 0, 1.12), 0.72, 0.78, 0.16, segs=8, color=stone_color(rnd, 0.0))
    for k in range(3):
        a = k / 3 * math.tau + 0.4
        h = rnd.uniform(0.7, 1.5)
        vs = b.cyl((math.cos(a) * 1.55, math.sin(a) * 1.55, h / 2 + 0.1), 0.2, 0.18, h, segs=6,
                   color=stone_color(rnd, 0.6))
        for v in vs:
            if v.co.z > h * 0.6:
                v.co.z -= rnd.uniform(0, 0.25)
    b.finish("Shrine")


@asset("shard")
def _():
    b = Builder(["crystal"])
    cos = [(0, 0, 0.65), (0, 0, -0.45)] + [(math.cos(a) * 0.22, math.sin(a) * 0.22, 0.0)
                                           for a in (k / 6 * math.tau for k in range(6))]
    faces = []
    for k in range(6):
        faces.append((0, 2 + k, 2 + (k + 1) % 6))
        faces.append((1, 2 + (k + 1) % 6, 2 + k))
    b.solid(cos, faces)
    b.finish("Shard_deco")


# ---------------------------------------------------------------- vegetation

def canopy_painter(tint, zmin, zmax):
    base = lin(tint)

    def fn(co):
        k = 0.45 + 0.7 * smoothstep(zmin, zmax, co.z)
        return (base[0] * k, base[1] * k, base[2] * k)
    return fn


def round_tree(seed, H=4.2, crown=2.2, blobs=5, tint=(0.36, 0.6, 0.22), lean=0.7):
    rnd = random.Random(seed)
    trunk = Builder(["bark"])
    lx, ly = rnd.uniform(-lean, lean), rnd.uniform(-lean, lean)
    pts, radii = [], []
    for i in range(7):
        t = i / 6
        pts.append(Vector((lx * t * t + rnd.uniform(-0.05, 0.05), ly * t * t + rnd.uniform(-0.05, 0.05), H * t - 0.3)))
        radii.append(0.28 * (1 - 0.6 * t) * (1.6 if i == 0 else 1.0))
    trunk.tube(pts, radii, segs=7, color=lambda co: (0.8, 0.8, 0.8) if co.z < 0.5 else (1, 1, 1))
    top = pts[-1]
    centers = [top + Vector((0, 0, crown * 0.35))]
    for k in range(blobs):
        a = rnd.uniform(0, math.tau)
        c = top + Vector((math.cos(a) * crown * 0.75, math.sin(a) * crown * 0.75, rnd.uniform(-0.3, 0.6) * crown * 0.5))
        centers.append(c)
        start = pts[4]
        mid = start.lerp(c, 0.5) + Vector((0, 0, 0.3))
        trunk.tube([start, mid, c], [0.13, 0.09, 0.05], segs=5, cap=False)
    trunk.finish("Trunk")

    leaves = Builder(["leaf"])
    allv = []
    for i, c in enumerate(centers):
        r = crown * (0.8 if i == 0 else rnd.uniform(0.5, 0.68))
        vs = leaves.ico(c, r, sub=2, scale=(1, 1, 0.82))
        leaves.displace(vs, r * 0.22, 0.9, seed + i, center=c)
        allv += vs
    zmin = min(v.co.z for v in leaves.bm.verts)
    zmax = max(v.co.z for v in leaves.bm.verts)
    leaves.paint(leaves.bm.faces[:], canopy_painter(tint, zmin, zmax))
    leaves.finish("Canopy_deco")


@asset("tree_a")
def _():
    round_tree(1)


@asset("tree_b")
def _():
    round_tree(2, H=5.5, crown=2.8, blobs=6, tint=(0.3, 0.55, 0.24), lean=1.1)


@asset("tree_autumn")
def _():
    round_tree(3, H=4.6, crown=2.4, blobs=5, tint=(0.95, 0.5, 0.16))


@asset("tree_autumn_b")
def _():
    round_tree(4, H=3.8, crown=2.0, blobs=4, tint=(0.88, 0.3, 0.12), lean=0.9)


@asset("tree_blossom")
def _():
    round_tree(5, H=4.4, crown=2.5, blobs=6, tint=(1.0, 0.68, 0.78), lean=1.0)


def pine(seed, H=6.5, tiers=4, tint=(0.2, 0.42, 0.26)):
    rnd = random.Random(seed)
    trunk = Builder(["bark"])
    trunk.tube([Vector((0, 0, -0.3)), Vector((0, 0, H * 0.5)), Vector((0, 0, H * 0.85))], [0.26, 0.17, 0.08], segs=6)
    trunk.finish("Trunk")
    leaves = Builder(["leaf"])
    allv = []
    for i in range(tiers):
        t = i / tiers
        z = 1.4 + t * (H - 2.2)
        r = lerp(2.0, 0.75, t) * rnd.uniform(0.9, 1.1)
        h = lerp(2.4, 1.8, t)
        vs = leaves.cyl((0, 0, z + h / 2), r, 0.04, h, segs=9, rot=(0, 0, rnd.uniform(0, 1)))
        for v in vs:
            if v.co.z < z + 0.05:
                v.co.z += rnd.uniform(-0.25, 0.1)
                v.co.x *= rnd.uniform(0.9, 1.15)
                v.co.y *= rnd.uniform(0.9, 1.15)
        allv += vs
    zmin = min(v.co.z for v in leaves.bm.verts)
    zmax = max(v.co.z for v in leaves.bm.verts)
    leaves.paint(leaves.bm.faces[:], canopy_painter(tint, zmin, zmax))
    leaves.finish("Canopy_deco")


@asset("pine_a")
def _():
    pine(1)


@asset("pine_b")
def _():
    pine(2, H=8.0, tiers=5, tint=(0.24, 0.45, 0.28))


def bush(seed, tint, n=4, size=0.7):
    rnd = random.Random(seed)
    b = Builder(["leaf"])
    allv = []
    for i in range(n):
        r = size * rnd.uniform(0.6, 1.0)
        c = Vector((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), r * 0.5))
        vs = b.ico(c, r, sub=2, scale=(1, 1, 0.8))
        b.displace(vs, r * 0.2, 1.4, seed + i, center=c)
        allv += vs
    zmax = max(v.co.z for v in b.bm.verts)
    b.paint(b.bm.faces[:], canopy_painter(tint, -0.1, zmax))
    b.finish("Bush_deco")


@asset("bush_a")
def _():
    bush(1, (0.32, 0.56, 0.22))


@asset("bush_b")
def _():
    bush(2, (0.42, 0.6, 0.2), n=3, size=0.55)


@asset("bush_flower")
def _():
    bush(3, (0.95, 0.85, 0.55), n=3, size=0.6)


def rock(seed, scale, amp=0.35, flat=-0.3):
    b = Builder(["rock"])
    vs = b.ico((0, 0, 0), 1.0, sub=2)
    for v in vs:
        d = v.co.normalized()
        v.co += d * fbm(v.co * 0.9, 3, seed) * amp
        v.co.x *= scale[0]
        v.co.y *= scale[1]
        v.co.z = max(v.co.z * scale[2], flat * scale[2])
    zmin = min(v.co.z for v in vs)
    zmax = max(v.co.z for v in vs)
    for v in vs:
        v.co.z -= zmin + 0.12 * scale[2]
    b.paint(b.bm.faces[:], lambda co: (lambda k: (k, k, k))(0.6 + 0.4 * smoothstep(0, zmax - zmin, co.z)))
    b.finish("Rock")


@asset("rock_a")
def _():
    rock(1, (1.3, 1.0, 0.9))


@asset("rock_b")
def _():
    rock(2, (1.8, 1.2, 0.5), amp=0.25)


@asset("rock_c")
def _():
    rock(3, (0.7, 0.7, 1.8), amp=0.4)


@asset("rock_d")
def _():
    rock(4, (0.6, 0.5, 0.45), amp=0.3)


# ---------------------------------------------------------------- character

@asset("wanderer")
def _():
    b = Builder(["cloth", "trim", "cloth_dark", "mask", "eye"])
    bm = b.bm
    S = 18
    levels = [(0.0, 0.44), (0.1, 0.42), (0.17, 0.405), (0.42, 0.34), (0.7, 0.27), (0.95, 0.2), (1.12, 0.14)]
    rings = []
    for li, (z, r) in enumerate(levels):
        ring = []
        for j in range(S):
            a = j / S * math.tau
            zz = z + (0.035 * math.sin(a * 5) if li == 0 else 0.0)
            rr = r * (1 + (0.04 * math.sin(a * 7) if li == 0 else 0.0))
            ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr * 0.86, zz)))
        rings.append(ring)
    top = bm.verts.new((0, 0, 1.18))
    trim, cloth = [], []
    for li in range(len(rings) - 1):
        A, B = rings[li], rings[li + 1]
        for j in range(S):
            jn = (j + 1) % S
            (trim if li == 1 else cloth).append(bm.faces.new((A[j], A[jn], B[jn], B[j])))
    for j in range(S):
        cloth.append(bm.faces.new((rings[-1][j], rings[-1][(j + 1) % S], top)))
    bmesh.ops.recalc_face_normals(bm, faces=trim + cloth)
    b.tag(cloth, "cloth", smooth=True)
    b.tag(trim, "trim", smooth=True)

    b.uvsphere((0, 0.02, 1.3), 0.17, m="cloth_dark")
    hood_c = Vector((0, -0.02, 1.33))
    hv = b.uvsphere(hood_c, 0.205, u=18, v=12, scale=(1, 1.05, 1.1), m="cloth")
    front = [f for f in b.faces_of(hv) if (f.calc_center_median() - hood_c).normalized().y > 0.5]
    bmesh.ops.delete(bm, geom=front, context='FACES')
    b.cyl((0, -0.31, 1.47), 0.11, 0.01, 0.3, segs=8, rot=(0.93, 0, 0), m="cloth", smooth=True)
    b.uvsphere((0, 0.115, 1.3), 0.14, scale=(1, 0.45, 1.15), m="mask")
    for sx in (-1, 1):
        b.ico((sx * 0.05, 0.178, 1.32), 0.022, sub=1, scale=(1.5, 0.5, 0.7), m="eye")
    b.finish("Wanderer_deco")


@asset("glider")
def _():
    b = Builder(["sail", "wood"])
    nose = Vector((0, 0.95, 0.05))
    tail = Vector((0, -0.25, 0.0))
    spans = [-1, -0.85, -0.7, -0.55, -0.35, -0.15, 0, 0.15, 0.35, 0.55, 0.7, 0.85, 1]
    chords = [0, 0.12, 0.4, 0.7, 1]
    grid = []
    for s in spans:
        tipv = Vector((1.65 * s, -0.55, 0.22 * abs(s)))
        le = nose.lerp(tipv, abs(s))
        scallop = 0.12 * math.sin(abs(s) * math.pi * 3) ** 2
        te = tail.lerp(tipv, abs(s)) + Vector((0, scallop, 0))
        col = []
        for c in chords:
            p = le.lerp(te, c)
            p.z += 0.16 * (1 - s * s) * math.sin(math.pi * c) + 0.05 * math.sin(math.pi * c)
            col.append(b.bm.verts.new(p))
        grid.append(col)
    fs = []
    for i in range(len(spans) - 1):
        for j in range(len(chords) - 1):
            fs.append(b.bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1])))
    bmesh.ops.recalc_face_normals(b.bm, faces=fs)
    for f in fs:
        if f.normal.z < 0:
            f.normal_flip()
    b.tag(fs, "sail", smooth=True)
    cream, red, gold = lin((0.96, 0.9, 0.8)), lin((0.78, 0.18, 0.12)), lin((0.9, 0.7, 0.3))

    def pattern(c):
        s = abs(c.x) / 1.65
        if 0.55 < s < 0.7:
            return red
        if c.y > 0.55 - s * 1.1 + 0.2 and s < 0.5:
            return gold
        return cream
    b.paint_faces(fs, pattern)
    for sx in (-1, 1):
        b.tube([nose + Vector((0, 0, -0.01)), Vector((1.65 * sx, -0.55, 0.2))], [0.025, 0.018], segs=5, m="wood", cap=False)
    b.tube([nose + Vector((0, 0, -0.02)), tail + Vector((0, -0.05, 0.02))], [0.025, 0.02], segs=5, m="wood", cap=False)
    b.tube([Vector((0, 0.1, 0.05)), Vector((0, 0.05, -0.45))], [0.02, 0.02], segs=5, m="wood", cap=False)
    b.finish("Glider_deco")



# ---------------------------------------------------------------- mechanics

@asset("launch_pad")
def _():
    rnd = random.Random(20)
    b = Builder(["stone", "rune"])
    n = 8
    for k in range(n):
        a0, a1 = k / n * math.tau, (k + 1) / n * math.tau - 0.04
        flat_wedge(b, 1.15, 1.75, a0, a1, -0.3, 0.22, color=stone_color(rnd, -1))
    b.cyl((0, 0, -0.05), 1.15, 1.15, 0.4, segs=24, color=(0.7, 0.7, 0.72))
    for k in range(n):
        a = (k + 0.5) / n * math.tau
        b.box((math.cos(a) * 1.45, math.sin(a) * 1.45, 0.24), (0.12, 0.3, 0.03), rot=(0, 0, a), m="rune")
    b.finish("LaunchPad")
    g = Builder(["rune"])
    g.cyl((0, 0, 0.16), 1.0, 1.0, 0.04, segs=24)
    g.finish("PadGlow_deco")


@asset("pressure_plate")
def _():
    rnd = random.Random(21)
    b = Builder(["stone"])
    for (x, y, w, d) in [(0, 1.05, 2.4, 0.3), (0, -1.05, 2.4, 0.3), (1.05, 0, 0.3, 1.8), (-1.05, 0, 0.3, 1.8)]:
        b.box((x, y, 0.05), (w, d, 0.3), color=stone_color(rnd, -1))
    b.finish("PlateFrame")
    p = Builder(["stone", "rune"])
    p.box((0, 0, 0.0), (1.75, 1.75, 0.3), color=(0.85, 0.85, 0.9))
    p.box((0, 0, 0.16), (0.9, 0.1, 0.02), m="rune")
    p.box((0, 0, 0.16), (0.1, 0.9, 0.02), m="rune")
    p.finish("Plate_deco")


@asset("push_stone")
def _():
    rnd = random.Random(22)
    b = Builder(["stone", "rune"])
    vs = b.box((0, 0, 0.6), (1.2, 1.2, 1.2), color=stone_color(rnd, 0.5))
    for v in vs:
        v.co += Vector((rnd.uniform(-0.03, 0.03), rnd.uniform(-0.03, 0.03), rnd.uniform(-0.03, 0.03)))
    for ax in range(4):
        a = ax * math.pi / 2
        d = Vector((math.cos(a), math.sin(a), 0)) * 0.605
        b.box((d.x, d.y, 0.6), (0.04 + abs(math.sin(a)) * 0.4, 0.04 + abs(math.cos(a)) * 0.4, 0.06), m="rune")
        b.box((d.x, d.y, 0.6), (0.04 + abs(math.sin(a)) * 0.06, 0.04 + abs(math.cos(a)) * 0.06, 0.4), m="rune")
    b.finish("PushStone_deco")


@asset("mirror")
def _():
    rnd = random.Random(23)
    base = Builder(["stone"])
    base.cyl((0, 0, 0.2), 0.85, 0.8, 0.4, segs=8, color=stone_color(rnd, -1))
    base.cyl((0, 0, 0.5), 0.35, 0.3, 0.3, segs=8, color=stone_color(rnd, 0))
    base.finish("MirrorBase")
    m = Builder(["stone", "mirror", "trim"])
    m.box((-0.75, 0, 1.45), (0.14, 0.22, 1.7), color=stone_color(rnd, 0))
    m.box((0.75, 0, 1.45), (0.14, 0.22, 1.7), color=stone_color(rnd, 0))
    m.box((0, 0, 0.62), (1.64, 0.26, 0.14), color=stone_color(rnd, 0))
    m.box((0, 0, 2.3), (1.64, 0.26, 0.14), color=stone_color(rnd, 0))
    m.box((0, 0.02, 1.45), (1.36, 0.06, 1.55), m="mirror")
    m.box((0, -0.04, 1.45), (1.4, 0.04, 1.6), m="trim")
    m.finish("MirrorFrame_deco")


@asset("beam_pedestal")
def _():
    rnd = random.Random(24)
    b = Builder(["stone", "trim"])
    b.cyl((0, 0, 0.5), 0.6, 0.45, 1.0, segs=8, color=stone_color(rnd, 0.5))
    b.cyl((0, 0, 1.05), 0.55, 0.6, 0.12, segs=8, color=stone_color(rnd, 0))
    for k in range(4):
        a = k / 4 * math.tau + math.pi / 4
        b.box((math.cos(a) * 0.42, math.sin(a) * 0.42, 1.35), (0.08, 0.08, 0.5), rot=(0, 0, a), m="trim")
    b.finish("Pedestal")


@asset("sentinel")
def _():
    rnd = random.Random(25)
    b = Builder(["basalt", "eye_red"])
    z = 0.0
    for i, (w, h) in enumerate([(1.6, 0.6), (1.2, 1.2), (1.0, 1.0), (1.25, 0.5), (0.9, 0.9)]):
        b.box((rnd.uniform(-0.04, 0.04), rnd.uniform(-0.04, 0.04), z + h / 2), (w, w, h), rot=(0, 0, rnd.uniform(-0.15, 0.15)),
              color=(0.9 + 0.1 * rnd.random(),) * 3)
        z += h
    b.cyl((0, 0, z + 0.4), 0.55, 0.05, 0.8, segs=4, rot=(0, 0, math.pi / 4), m="basalt")
    for ang in (0, math.pi / 2, math.pi, -math.pi / 2):
        d = Vector((math.cos(ang), math.sin(ang), 0))
        b.box((d.x * 0.62, d.y * 0.62, 3.0), (0.3 + abs(d.y) * 0.2, 0.3 + abs(d.x) * 0.2, 0.12), m="eye_red")
    b.finish("Sentinel")


@asset("cairn")
def _():
    rnd = random.Random(26)
    b = Builder(["rock", "rune"])
    z = 0.0
    for i, r in enumerate([0.7, 0.55, 0.42, 0.3]):
        vs = b.ico((rnd.uniform(-0.05, 0.05), rnd.uniform(-0.05, 0.05), z + r * 0.35), r, sub=1, scale=(1, 0.9, 0.5))
        b.displace(vs, r * 0.15, 2.0, i)
        z += r * 0.68
    b.ico((0, 0, z + 0.18), 0.16, sub=1, scale=(1, 1, 1.4), m="rune")
    b.finish("Cairn")


@asset("sundial")
def _():
    rnd = random.Random(27)
    b = Builder(["stone", "trim", "rune"])
    n = 12
    for k in range(n):
        a0, a1 = k / n * math.tau, (k + 1) / n * math.tau - 0.03
        flat_wedge(b, 0.0, 2.4, a0, a1, -0.4, 0.25, color=stone_color(rnd, -1))
        a = (k + 0.5) / n * math.tau
        b.box((math.cos(a) * 2.0, math.sin(a) * 2.0, 0.27), (0.08, 0.35, 0.03), rot=(0, 0, a), m="rune")
    b.solid([(0, -0.9, 0.25), (0, 0.9, 0.25), (0, 0.9, 1.7), (0.06, -0.9, 0.25), (0.06, 0.9, 0.25), (0.06, 0.9, 1.7)],
            [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (0, 2, 5, 3)], m="trim")
    b.finish("Sundial")


@asset("slab")
def _():
    rnd = random.Random(28)
    b = Builder(["stone"])
    bm = b.bm
    S = 10
    top, bot = [], []
    for j in range(S):
        a = j / S * math.tau
        r = 2.2 * (1 + 0.12 * math.sin(a * 3 + 1) + rnd.uniform(-0.05, 0.05))
        top.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, rnd.uniform(-0.03, 0.03))))
        bot.append(bm.verts.new((math.cos(a) * r * 0.8, math.sin(a) * r * 0.8, -0.5 + rnd.uniform(-0.1, 0.1))))
    tip = bm.verts.new((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), -1.4))
    c = bm.verts.new((0, 0, 0.02))
    fs = [bm.faces.new((c, top[j], top[(j + 1) % S])) for j in range(S)]
    fs += [bm.faces.new((top[j], bot[j], bot[(j + 1) % S], top[(j + 1) % S])) for j in range(S)]
    fs += [bm.faces.new((bot[j], tip, bot[(j + 1) % S])) for j in range(S)]
    bmesh.ops.recalc_face_normals(bm, faces=fs)
    b.tag(fs, "stone", lambda co: (lambda k: (k, k, k))(0.6 + 0.4 * smoothstep(-1.4, 0, co.z)))
    b.finish("Slab")


@asset("ring_frame")
def _():
    rnd = random.Random(29)
    b = Builder(["stone", "rune"])
    n = 14
    R0, R1 = 2.55, 3.1
    for k in range(n):
        a0, a1 = k / n * math.tau + 0.01, (k + 1) / n * math.tau - 0.01
        wedge(b, 0, 0, R0, R1, a0, a1, -0.3, 0.3, color=stone_color(rnd, -1))
        a = (k + 0.5) / n * math.tau
        b.box((math.cos(a) * (R0 + R1) / 2, 0.31, math.sin(a) * (R0 + R1) / 2), (0.1, 0.02, 0.25), rot=(0, -a, 0), m="rune")
        b.box((math.cos(a) * (R0 + R1) / 2, -0.31, math.sin(a) * (R0 + R1) / 2), (0.1, 0.02, 0.25), rot=(0, -a, 0), m="rune")
    b.finish("RingFrame_deco")


@asset("basalt_spire")
def _():
    rnd = random.Random(30)
    b = Builder(["basalt", "grass"])
    cols = []
    for i in range(16):
        a = rnd.uniform(0, math.tau)
        r = 1.2 * math.sqrt(rnd.random()) * 2.4
        cols.append((math.cos(a) * r, math.sin(a) * r))
    cols.append((0, 0))
    for (x, y) in cols:
        d = math.hypot(x, y)
        top = 0.4 - d * 0.18 + rnd.uniform(-0.25, 0.1)
        h = 14 + rnd.uniform(0, 8) - d * 2
        b.cyl((x, y, top - h / 2), 0.75, 0.75, h, segs=6, rot=(0, 0, rnd.uniform(0, 1)),
              color=(lambda k: (k, k, k))(rnd.uniform(0.8, 1.05)))
        b.cyl((x, y, top + 0.02), 0.74, 0.74, 0.06, segs=6, m="grass")
    b.finish("Spire")


def extra_island(name, R, depth, seed, **kw):
    @asset(name)
    def _():
        build_island(R, depth, seed, **kw)


extra_island("island_big", 18, 24, 81, flat_r=7, lobes=0.15, stal=8)
extra_island("island_tall", 9, 34, 91, lobes=0.12, stal=4)
extra_island("island_flat", 11, 12, 101, bumps=0.15, lobes=0.25, stal=5)
extra_island("island_long", 13, 16, 111, lobes=0.35, stal=6)


@asset("mushroom")
def _():
    rnd = random.Random(40)
    b = Builder(["stem", "cap", "rune"])
    b.tube([Vector((0, 0, -0.2)), Vector((0.05, 0, 0.45)), Vector((0, 0.03, 0.85))], [0.32, 0.26, 0.3], segs=10, m="stem", smooth=True)
    cap = b.uvsphere((0, 0, 0.85), 1.35, u=20, v=10, scale=(1, 1, 0.42), m="cap")
    for v in cap:
        if v.co.z < 0.85:
            v.co.z = 0.85 - (0.85 - v.co.z) * 0.3
    for i in range(9):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.2, 1.0)
        z = 0.85 + 0.56 * math.sqrt(max(0.0, 1 - (r / 1.35) ** 2)) + 0.01
        b.ico((math.cos(a) * r, math.sin(a) * r, z), rnd.uniform(0.08, 0.15), sub=1, scale=(1, 1, 0.35), m="rune")
    b.finish("Mushroom_deco")


@asset("bell")
def _():
    rnd = random.Random(41)
    frame = Builder(["stone", "wood"])
    for sx in (-1, 1):
        frame.box((sx * 0.9, 0, 1.2), (0.3, 0.3, 2.4), color=stone_color(rnd, 0.6))
    frame.box((0, 0, 2.5), (2.3, 0.4, 0.25), color=stone_color(rnd, 0))
    frame.box((0, 0, 0.1), (2.3, 1.0, 0.2), color=stone_color(rnd, -1))
    frame.finish("BellFrame")
    bell = Builder(["trim"])
    pts = [Vector((0, 0, 2.35)), Vector((0, 0, 2.15)), Vector((0, 0, 1.85)), Vector((0, 0, 1.55)), Vector((0, 0, 1.4))]
    bell.tube(pts, [0.12, 0.3, 0.38, 0.5, 0.55], segs=14, smooth=True, cap=False)
    bell.finish("Bell_deco")


@asset("vent")
def _():
    rnd = random.Random(42)
    b = Builder(["stone", "rune", "basalt"])
    n = 10
    for k in range(n):
        a0, a1 = k / n * math.tau + 0.02, (k + 1) / n * math.tau - 0.02
        flat_wedge(b, 2.3, 3.2, a0, a1, -0.5, 0.35 + rnd.uniform(-0.04, 0.04), color=stone_color(rnd, -1))
    b.cyl((0, 0, -0.35), 2.3, 2.3, 0.3, segs=24, m="basalt")
    for k in range(8):
        a = k / 8 * math.pi
        b.box((0, 0, 0.0), (4.4, 0.12, 0.12), rot=(0, 0, a), m="rune")
    b.cyl((0, 0, 0.02), 0.5, 0.5, 0.16, segs=12, m="rune")
    for k in range(4):
        a = k / 4 * math.tau + math.pi / 4
        h = rnd.uniform(1.1, 1.6)
        vs = b.box((math.cos(a) * 3.0, math.sin(a) * 3.0, h / 2), (0.45, 0.45, h), rot=(0, 0, a), color=stone_color(rnd, 0.6))
        b.box((math.cos(a) * 2.76, math.sin(a) * 2.76, h * 0.62), (0.03, 0.22, 0.4), rot=(0, 0, a), m="rune")
    b.finish("Vent")


@asset("lever")
def _():
    rnd = random.Random(43)
    base = Builder(["stone", "rune"])
    base.box((0, 0, 0.3), (1.2, 0.9, 0.6), color=stone_color(rnd, 0.3))
    base.box((0, 0.46, 0.35), (0.6, 0.02, 0.12), m="rune")
    base.finish("LeverBase")
    arm = Builder(["wood", "trim"])
    arm.tube([Vector((0, 0, 0)), Vector((0, 0, 1.1))], [0.06, 0.05], segs=6, m="wood")
    arm.uvsphere((0, 0, 1.15), 0.13, m="trim")
    arm.finish("LeverArm_deco")


@asset("causeway")
def _():
    rnd = random.Random(44)
    b = Builder(["stone", "rune"])
    n = 12
    for k in range(n):
        a0, a1 = k / n * math.tau + 0.01, (k + 1) / n * math.tau - 0.01
        flat_wedge(b, 0.0, 4.2, a0, a1, -0.8, 0.0, color=stone_color(rnd, -1))
    for sx in (-1, 1):
        x = 4.0
        while x < 16.0:
            w = rnd.uniform(1.6, 2.2)
            b.box((sx * (x + w / 2), rnd.uniform(-0.05, 0.05), -0.35), (w - 0.06, 3.0, 0.7), color=stone_color(rnd, -1))
            x += w
        for x in (6.0, 10.0, 14.0):
            for sy in (-1, 1):
                if rnd.random() < 0.75:
                    h = rnd.uniform(0.5, 1.0)
                    b.box((sx * x, sy * 1.4, h / 2), (0.3, 0.3, h), color=stone_color(rnd, 0))
        b.box((sx * 15.5, 0, 0.02), (0.15, 2.4, 0.03), m="rune")
    b.cyl((0, 0, -2.5), 1.4, 0.6, 3.5, segs=8, color=(0.7, 0.7, 0.72))
    for k in range(6):
        a = k / 6 * math.tau
        b.box((math.cos(a) * 3.3, math.sin(a) * 3.3, 0.02), (0.6, 0.12, 0.03), rot=(0, 0, a), m="rune")
    b.finish("Causeway")


def crystal_cluster(seed, tint, n=7, scale=1.0):
    rnd = random.Random(seed)
    b = Builder(["crystal_rock"])
    for i in range(n):
        h = rnd.uniform(0.8, 2.6) * scale
        r = rnd.uniform(0.18, 0.4) * scale
        tilt = (rnd.uniform(-0.45, 0.45), rnd.uniform(-0.45, 0.45), rnd.uniform(0, 1))
        off = (rnd.uniform(-0.5, 0.5) * scale, rnd.uniform(-0.5, 0.5) * scale)
        mtx = Matrix.LocRotScale(Vector((off[0], off[1], 0)), Euler(tilt), None)
        vs = [b.bm.verts.new(mtx @ Vector(c)) for c in
              [(math.cos(a) * r, math.sin(a) * r, 0) for a in (k / 6 * math.tau for k in range(6))] +
              [(math.cos(a) * r, math.sin(a) * r, h) for a in (k / 6 * math.tau for k in range(6))] + [(0, 0, h + r * 1.6)]]
        fs = []
        for k in range(6):
            kn = (k + 1) % 6
            fs.append(b.bm.faces.new((vs[k], vs[kn], vs[6 + kn], vs[6 + k])))
            fs.append(b.bm.faces.new((vs[6 + k], vs[6 + kn], vs[12])))
        bmesh.ops.recalc_face_normals(b.bm, faces=fs)
        c = lin(tint)
        b.tag(fs, "crystal_rock", lambda co, c=c: (lambda k: (c[0] * k, c[1] * k, c[2] * k))(0.55 + 0.45 * smoothstep(0, 2.5 * scale, co.z)))
    b.finish("Crystals_deco")


@asset("crystals_a")
def _():
    crystal_cluster(1, (0.75, 0.6, 1.0))


@asset("crystals_b")
def _():
    crystal_cluster(2, (0.55, 0.9, 1.0), n=5, scale=1.6)


@asset("cactus")
def _():
    rnd = random.Random(45)
    b = Builder(["cactus"])
    b.tube([Vector((0, 0, -0.2)), Vector((0, 0, 1.2)), Vector((0, 0, 2.6))], [0.32, 0.3, 0.26], segs=8, smooth=True)
    for sx in (-1, 1):
        h = rnd.uniform(0.9, 1.5)
        b.tube([Vector((0, 0, h)), Vector((sx * 0.6, 0, h + 0.05)), Vector((sx * 0.65, 0, h + 0.9))], [0.17, 0.16, 0.14], segs=7, smooth=True)
    b.finish("Cactus")


@asset("dead_tree")
def _():
    rnd = random.Random(46)
    b = Builder(["bark"])
    b.tube([Vector((0, 0, -0.3)), Vector((0.2, 0, 1.5)), Vector((0.1, 0.2, 3.2))], [0.25, 0.17, 0.08], segs=6)
    for i in range(5):
        a = rnd.uniform(0, math.tau)
        z = rnd.uniform(1.4, 2.8)
        L = rnd.uniform(0.8, 1.6)
        start = Vector((0.15, 0.05, z))
        b.tube([start, start + Vector((math.cos(a) * L * 0.6, math.sin(a) * L * 0.6, L * 0.4)), start + Vector((math.cos(a) * L, math.sin(a) * L, L * 0.9))], [0.07, 0.05, 0.02], segs=5)
    b.finish("DeadTree")


@asset("ice_spire")
def _():
    b = Builder(["ice"])
    vs = b.cyl((0, 0, 1.6), 0.9, 0.05, 3.2, segs=6)
    b.displace(vs, 0.15, 1.5, 3)
    b.finish("IceSpire")

# ---------------------------------------------------------------- main

for name, fn in ASSETS.items():
    if ONLY and name not in ONLY:
        continue
    clear()
    fn()
    export(name)
    print("built", name)
