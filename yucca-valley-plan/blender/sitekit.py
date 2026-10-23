"""sitekit -- shared headless-Blender toolkit for the Yucca Valley 5-acre site schemes.

Coordinates are metres: +X east, +Y north, +Z up.  The parcel is a 660 ft x 330 ft
(5.0 acre) rectangle with its south (low) edge on a dirt road; the ground rises
~9 m (30 ft) toward the north, with a shallow wash crossing the east third and a
granite knoll in the north-east corner.  Every scheme uses the same land, the same
Joshua trees and the same boulders, so the schemes are directly comparable.

Run a scheme with:  blender -b --python scheme_X.py -- <out_dir> [preview]
"""
import bpy, bmesh, math, json, os, sys, random
import numpy as np
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view

FT = 0.3048
LOT_W = 660 * FT          # 201.17 m east-west
LOT_D = 330 * FT          # 100.58 m north-south
ROAD_Y = -6.0             # centreline of the dirt road along the south edge

# Setbacks used for the dashed "buildable area" line.  Placeholder values typical of
# rural-living zones; the research section of the plan says which to verify.
JT_BUFFER = 50 * FT
SETBACK_FRONT = 25 * FT
SETBACK_SIDE = 15 * FT
SETBACK_REAR = 15 * FT

WASH = np.array([(116, 180), (119, 130), (123, 100.6), (129, 72), (137, 46), (143, 22), (149, 0), (156, -40), (160, -90)], float)

# Fixed Joshua trees (x, y, height) -- identical in every scheme.  Layouts must avoid them.
JOSHUA_TREES = [
    # Placed where every scheme keeps the County's 50-ft no-disturbance buffer; the last five stand on neighbors' land
    (150, 96, 4.6), (158, 88, 3.2), (176, 98, 6.2), (196, 92, 3.9), (186, 76, 6.4), (198, 62, 2.7),
    (180, 66, 5.0), (192, 44, 3.1), (182, 22, 4.8), (196, 12, 3.4), (166, 10, 3.3), (154, 24, 2.9),
    (150, 30, 4.0), (148, 16, 3.6), (146, 6, 3.7), (198, 30, 4.4), (-16, 70, 5.2), (-16, 28, 3.0),
    (8, -18, 4.1), (150, -18, 3.5), (190, -14, 5.6),
]
if os.environ.get('YV_DRYRUN'):
    JOSHUA_TREES = []
# Granite boulder clusters (x, y, radius of cluster, count)
BOULDERS = [(171, 84, 9, 14), (187, 92, 5, 6), (150, 96, 4, 4), (58, 92, 3, 3), (196, 66, 4, 5), (24, 98, 3, 3)]


# ----------------------------------------------------------------------------- utils
def srgb(h):
    h = h.lstrip('#')
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4) for v in c) + (1.0,)


def S(node, name, typ='RGBA'):
    """Mix-node socket by name *and* type (Mix nodes reuse the names A/B per data type)."""
    return next(sk for sk in node.inputs if sk.name == name and sk.type == typ)


def O(node, typ='RGBA'):
    return next(sk for sk in node.outputs if sk.type == typ)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def densify(pts, step=1.0):
    pts = np.asarray(pts, float)
    out = [pts[0]]
    for a, b in zip(pts[:-1], pts[1:]):
        n = max(1, int(np.ceil(np.linalg.norm(b - a) / step)))
        for i in range(1, n + 1):
            out.append(a + (b - a) * i / n)
    return np.array(out)


def polyline_nearest(x, y, pts):
    """Distance from points (x, y) to a polyline; also returns segment index and t."""
    best = np.full(x.shape, np.inf)
    bi = np.zeros(x.shape, int)
    bt = np.zeros(x.shape)
    for i in range(len(pts) - 1):
        ax, ay = pts[i]
        bx, by = pts[i + 1]
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy or 1e-9
        t = np.clip(((x - ax) * dx + (y - ay) * dy) / L2, 0, 1)
        d = np.hypot(x - (ax + t * dx), y - (ay + t * dy))
        m = d < best
        best[m] = d[m]
        bi[m] = i
        bt[m] = t[m]
    return best, bi, bt


def base_height(x, y):
    t = y / LOT_D
    h = 1.4 * t + 7.2 * smoothstep(0.28, 1.3, t)          # gentle front, steeper back half
    h += 1.1 * (1 - x / LOT_W)                             # slight cross-fall to the east
    h += 0.35 * np.sin(x * 0.071 + 1.3) * np.cos(y * 0.093 + 0.4)
    h += 0.22 * np.sin(x * 0.19 + y * 0.13) + 0.08 * np.sin(x * 0.53 - y * 0.41)
    h += 3.4 * np.exp(-(((x - 172) / 22) ** 2 + ((y - 86) / 17) ** 2))   # granite knoll
    d, _, _ = polyline_nearest(x, y, WASH)
    h -= 0.95 * np.exp(-(d / 4.2) ** 2)                    # wash channel
    return h


def wash_factor(x, y):
    d, _, _ = polyline_nearest(x, y, WASH)
    return np.exp(-(d / 5.5) ** 2)


# ----------------------------------------------------------------------------- terrain
class Terrain:
    def __init__(self):
        self.ops = []

    def h(self, x, y):
        return float(self.height(np.array([float(x)]), np.array([float(y)]))[0])

    def add_pad(self, cx, cy, w, l, rot=0.0, elev=None, slope=2.0, phase=1):
        if elev is None:
            elev = self.h(cx, cy)
        self.ops.append(('pad', cx, cy, w, l, math.radians(rot), elev, slope, phase))
        return elev

    def add_road(self, pts, width, slope=2.0, smooth=9, phase=1):
        dense = densify(pts, 1.0)
        z = self.height(dense[:, 0], dense[:, 1])
        k = np.ones(smooth) / smooth
        zp = np.pad(z, (smooth // 2, smooth // 2), mode='edge')
        z = np.convolve(zp, k, mode='valid')[:len(dense)]
        self.ops.append(('road', dense, z, width, slope, phase))
        return dense, z

    def height(self, x, y, max_phase=99):
        h = base_height(x, y)
        for op in self.ops:
            if op[-1] > max_phase:
                continue
            if op[0] == 'pad':
                _, cx, cy, w, l, r, e, s, _ph = op
                dx, dy = x - cx, y - cy
                u = dx * math.cos(r) + dy * math.sin(r)
                v = -dx * math.sin(r) + dy * math.cos(r)
                d = np.hypot(np.maximum(np.abs(u) - w / 2, 0), np.maximum(np.abs(v) - l / 2, 0))
                reach = s * np.abs(h - e) + 0.4
                k = smoothstep(0.0, 1.0, d / reach)
                h = e + (h - e) * k
            else:
                _, dense, z, wd, s, _ph = op
                xmin, ymin = dense.min(0) - 40
                xmax, ymax = dense.max(0) + 40
                m = (x > xmin) & (x < xmax) & (y > ymin) & (y < ymax)
                if not m.any():
                    continue
                d, i, t = polyline_nearest(x[m], y[m], dense)
                zr = z[i] + (z[np.minimum(i + 1, len(z) - 1)] - z[i]) * t
                hm = h[m]
                dd = np.maximum(d - wd / 2, 0)
                reach = s * np.abs(hm - zr) + 0.4
                k = smoothstep(0.0, 1.0, dd / reach)
                h[m] = zr + (hm - zr) * k
        return h


def phase_of(coll):
    return int(coll[5:]) if isinstance(coll, str) and coll.startswith('phase') else 1


# ----------------------------------------------------------------------------- scene
class Site:
    def __init__(self, scheme_id, out_dir, preview=False):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.id = scheme_id
        self.out = out_dir
        self.preview = preview
        os.makedirs(out_dir, exist_ok=True)
        self.t = Terrain()
        self.scene = bpy.context.scene
        self.colls = {}
        self.mats = {}
        self.footprints = []        # (cx, cy, rx, ry) exclusion ellipses for scatter
        self.anchors = []           # dicts: num, label, pos, phase, views
        self.rng = random.Random(7)
        self.terrain_obj = None
        self._proto = {}

    # ---- collections
    def coll(self, name):
        if name not in self.colls:
            c = bpy.data.collections.new(name)
            self.scene.collection.children.link(c)
            self.colls[name] = c
        return self.colls[name]

    def link(self, ob, coll):
        self.coll(coll).objects.link(ob)
        return ob

    # ---- materials
    def mat(self, name, color, rough=0.6, metal=0.0, spec=0.5, emit=None, emit_strength=0.0, alpha=1.0, transmission=0.0):
        if name in self.mats:
            return self.mats[name]
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        p = m.node_tree.nodes['Principled BSDF']
        p.inputs['Base Color'].default_value = srgb(color)
        p.inputs['Roughness'].default_value = rough
        p.inputs['Metallic'].default_value = metal
        p.inputs['Specular IOR Level'].default_value = spec
        if emit:
            p.inputs['Emission Color'].default_value = srgb(emit)
            p.inputs['Emission Strength'].default_value = emit_strength
        if transmission:
            p.inputs['Transmission Weight'].default_value = transmission
        if alpha < 1:
            p.inputs['Alpha'].default_value = alpha
        self.mats[name] = m
        return m

    def mat_bricks(self, name, color, line, scale=6.0, mortar=0.04):
        """Solar-cell / grid look via a brick texture."""
        if name in self.mats:
            return self.mats[name]
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        p = nt.nodes['Principled BSDF']
        b = nt.nodes.new('ShaderNodeTexBrick')
        b.offset = 0.0
        b.inputs['Color1'].default_value = srgb(color)
        b.inputs['Color2'].default_value = srgb(color)
        b.inputs['Mortar'].default_value = srgb(line)
        b.inputs['Scale'].default_value = scale
        b.inputs['Mortar Size'].default_value = mortar
        b.inputs['Brick Width'].default_value = 0.5
        b.inputs['Row Height'].default_value = 0.5
        tc = nt.nodes.new('ShaderNodeTexCoord')
        nt.links.new(tc.outputs['Object'], b.inputs['Vector'])
        nt.links.new(b.outputs['Color'], p.inputs['Base Color'])
        p.inputs['Roughness'].default_value = 0.25
        p.inputs['Metallic'].default_value = 0.2
        self.mats[name] = m
        return m

    def mat_stripes(self, name, c1, c2, scale=1.0, rough=0.8, axis='X'):
        if name in self.mats:
            return self.mats[name]
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        p = nt.nodes['Principled BSDF']
        w = nt.nodes.new('ShaderNodeTexWave')
        w.wave_type = 'BANDS'
        w.bands_direction = axis
        w.inputs['Scale'].default_value = scale
        w.inputs['Distortion'].default_value = 0.0
        tc = nt.nodes.new('ShaderNodeTexCoord')
        nt.links.new(tc.outputs['Object'], w.inputs['Vector'])
        r = nt.nodes.new('ShaderNodeValToRGB')
        r.color_ramp.interpolation = 'CONSTANT'
        r.color_ramp.elements[0].color = srgb(c1)
        r.color_ramp.elements[1].position = 0.5
        r.color_ramp.elements[1].color = srgb(c2)
        nt.links.new(w.outputs['Fac'], r.inputs['Fac'])
        nt.links.new(r.outputs['Color'], p.inputs['Base Color'])
        p.inputs['Roughness'].default_value = rough
        self.mats[name] = m
        return m

    # ---- mesh helpers
    def mesh_obj(self, name, bm, mats, coll, loc=(0, 0, 0), parent=None):
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for m in mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(name, me)
        ob.location = loc
        if parent:
            ob.parent = parent
        return self.link(ob, coll)

    def box(self, name, size, loc, mat, coll, parent=None, bevel=0.0, seg=4, rot=(0, 0, 0)):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
        ob = self.mesh_obj(name, bm, [mat], coll, loc, parent)
        ob.rotation_euler = rot
        if bevel:
            mod = ob.modifiers.new('bevel', 'BEVEL')
            mod.width = bevel
            mod.segments = seg
            mod.limit_method = 'NONE'
            ob.data.polygons.foreach_set('use_smooth', [True] * len(ob.data.polygons))
        return ob

    def cyl(self, name, r, h, loc, mat, coll, parent=None, seg=24, r2=None, rot=(0, 0, 0)):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
        ob = self.mesh_obj(name, bm, [mat], coll, loc, parent)
        ob.rotation_euler = rot
        return ob

    def empty(self, name, x, y, z, rot, coll):
        e = bpy.data.objects.new(name, None)
        e.location = (x, y, z)
        e.rotation_euler = (0, 0, math.radians(rot))
        return self.link(e, coll)

    def foot(self, x, y, rx, ry=None, kind='disturb'):
        # phase comes from the calling builder's `coll` argument
        coll = sys._getframe(1).f_locals.get('coll', 'phase1')
        self.footprints.append((x, y, rx, ry or rx, phase_of(coll)))
        self.kinds = getattr(self, 'kinds', []) + [kind]

    def anchor(self, label, x, y, z=None, phase=1, dz=0.0, until=99):
        if z is None:
            z = self.t.h(x, y)
        self.anchors.append({'label': label, 'pos': (x, y, z + dz), 'phase': phase, 'until': until})

    # ------------------------------------------------------------------ grading API
    def pad(self, cx, cy, w, l, rot=0.0, elev=None, coll='phase1', surface='pad', show=True):
        e = self.t.add_pad(cx, cy, w, l, rot, elev, phase=phase_of(coll))
        if show:
            self._pads = getattr(self, '_pads', [])
            # the interim pod's pad is reused by the ADU pod: draw the surface once (coincident faces render black)
            if not any(abs(p[0] - cx) < 0.01 and abs(p[1] - cy) < 0.01 and abs(p[2] - w) < 0.01 and abs(p[3] - l) < 0.01 for p in self._pads):
                self._pads.append((cx, cy, w, l, rot, e, coll, surface))
        return e

    def road(self, pts, width=4.9, coll='phase1', surface='gravel'):
        dense, z = self.t.add_road(pts, width, phase=phase_of(coll))
        self._roads = getattr(self, '_roads', [])
        self._roads.append((dense, width, coll, surface))
        for (x, y) in dense[::3]:
            self.foot(x, y, width / 2 + 1.0)
        return dense

    def path(self, pts, width=1.2, coll='phase3'):
        dense = densify(pts, 0.6)
        self._paths = getattr(self, '_paths', [])
        self._paths.append((dense, width, coll))
        for (x, y) in dense[::4]:
            self.foot(x, y, width / 2 + 0.6, kind='path')

    # ------------------------------------------------------------------ build terrain
    def build_terrain(self, x0=-90, x1=290, y0=-70, y1=190, step=0.7, phases=(99,)):
        for ph in phases:
            self._terrain_mesh(x0, x1, y0, y1, step, ph)
        self._outer(x0, x1, y0, y1)

    def _terrain_mesh(self, x0, x1, y0, y1, step, ph):
        xs = np.arange(x0, x1 + 1e-6, step)
        ys = np.arange(y0, y1 + 1e-6, step)
        X, Y = np.meshgrid(xs, ys)
        xf, yf = X.ravel(), Y.ravel()
        Z = self.t.height(xf, yf, max_phase=ph)
        Z0 = base_height(xf, yf)
        nx, ny = len(xs), len(ys)
        verts = np.stack([xf, yf, Z], 1).astype(np.float32)
        I, J = np.meshgrid(np.arange(nx - 1), np.arange(ny - 1))
        a = (J * nx + I).ravel()
        quads = np.stack([a, a + 1, a + nx + 1, a + nx], 1).astype(np.int32)
        me = bpy.data.meshes.new('terrain')
        me.vertices.add(len(verts))
        me.vertices.foreach_set('co', verts.ravel())
        me.loops.add(quads.size)
        me.loops.foreach_set('vertex_index', quads.ravel())
        me.polygons.add(len(quads))
        me.polygons.foreach_set('loop_start', np.arange(0, quads.size, 4, dtype=np.int32))
        me.polygons.foreach_set('loop_total', np.full(len(quads), 4, dtype=np.int32))
        me.update(calc_edges=True)
        me.polygons.foreach_set('use_smooth', np.ones(len(quads), bool))
        graded = np.clip(np.abs(Z - Z0) / 0.35, 0, 1).astype(np.float32)
        wash = wash_factor(xf, yf).astype(np.float32)
        for nm, arr in (('graded', graded), ('wash', wash)):
            at = me.attributes.new(nm, 'FLOAT', 'POINT')
            at.data.foreach_set('value', arr)
        if not hasattr(self, 'ground_mat'):
            self.terrain_material()
        me.materials.append(self.ground_mat)
        ob = bpy.data.objects.new('terrain', me)
        self.link(ob, f'terrain_{ph}')
        self.terrain_obj = ob

    def _outer(self, x0, x1, y0, y1):
        # coarse outer ground for the aerial horizon
        xs2 = np.arange(-1500, 1700, 8.0)
        ys2 = np.arange(-900, 1800, 8.0)
        X2, Y2 = np.meshgrid(xs2, ys2)
        xr, yr = X2.ravel(), Y2.ravel()
        Z2 = base_height(xr, yr) - 0.35
        # sink the coarse ground well below the detailed terrain wherever both exist
        inside = np.minimum.reduce([xr - x0, x1 - xr, yr - y0, y1 - yr])
        Z2 -= 4.0 * smoothstep(2.0, 14.0, inside)
        # rocky ridge a few hundred metres north (typical of the hills behind Yucca Valley)
        ridge = smoothstep(320, 700, yr) * (0.6 + 0.4 * np.sin(xr * 0.006 + 1.1) * np.cos(xr * 0.0023))
        Z2 += 85 * ridge + 14 * np.sin(xr * 0.017 + yr * 0.004) * smoothstep(300, 520, yr)
        Z2 += 40 * smoothstep(900, 1500, yr)
        Z2 += ridge * (7 * np.sin(xr * 0.05) * np.sin(yr * 0.045) + 4 * np.sin(xr * 0.11 + yr * 0.07) + 2.5 * np.sin(xr * 0.23 - yr * 0.19))
        nx2, ny2 = len(xs2), len(ys2)
        v2 = np.stack([xr, yr, Z2], 1).astype(np.float32)
        I2, J2 = np.meshgrid(np.arange(nx2 - 1), np.arange(ny2 - 1))
        a2 = (J2 * nx2 + I2).ravel()
        q2 = np.stack([a2, a2 + 1, a2 + nx2 + 1, a2 + nx2], 1).astype(np.int32)
        me2 = bpy.data.meshes.new('outer')
        me2.vertices.add(len(v2))
        me2.vertices.foreach_set('co', v2.ravel())
        me2.loops.add(q2.size)
        me2.loops.foreach_set('vertex_index', q2.ravel())
        me2.polygons.add(len(q2))
        me2.polygons.foreach_set('loop_start', np.arange(0, q2.size, 4, dtype=np.int32))
        me2.polygons.foreach_set('loop_total', np.full(len(q2), 4, dtype=np.int32))
        me2.update(calc_edges=True)
        me2.polygons.foreach_set('use_smooth', np.ones(len(q2), bool))
        me2.materials.append(self.outer_material())
        ob2 = bpy.data.objects.new('outer', me2)
        self.link(ob2, 'land')
        # dirt road strip (outside the lot)
        self._strip('road_dirt', np.array([(-1500, ROAD_Y), (1700, ROAD_Y)]), 7.5,
                    self.mat('road', '#b59c7c', rough=0.95), 'land', step=2.0, off=0.05)

    def terrain_material(self):
        m = bpy.data.materials.new('ground')
        m.use_nodes = True
        nt = m.node_tree
        N, L = nt.nodes, nt.links
        p = N['Principled BSDF']
        p.inputs['Roughness'].default_value = 0.95
        p.inputs['Specular IOR Level'].default_value = 0.25

        def node(t, **kw):
            n = N.new(t)
            for k, v in kw.items():
                setattr(n, k, v)
            return n

        def math_node(op, a=None, b=None, va=None, vb=None):
            n = node('ShaderNodeMath', operation=op)
            if a is not None:
                L.new(a, n.inputs[0])
            elif va is not None:
                n.inputs[0].default_value = va
            if b is not None:
                L.new(b, n.inputs[1])
            elif vb is not None:
                n.inputs[1].default_value = vb
            return n

        geo = node('ShaderNodeNewGeometry')
        sep = node('ShaderNodeSeparateXYZ')
        L.new(geo.outputs['Position'], sep.inputs[0])
        nsep = node('ShaderNodeSeparateXYZ')
        L.new(geo.outputs['Normal'], nsep.inputs[0])
        # sand base colour from layered noise
        noise1 = node('ShaderNodeTexNoise')
        noise1.inputs['Scale'].default_value = 0.035
        noise1.inputs['Detail'].default_value = 4
        noise2 = node('ShaderNodeTexNoise')
        noise2.inputs['Scale'].default_value = 1.6
        noise2.inputs['Detail'].default_value = 6
        tc = node('ShaderNodeTexCoord')
        L.new(tc.outputs['Object'], noise1.inputs['Vector'])
        L.new(tc.outputs['Object'], noise2.inputs['Vector'])
        mixn = node('ShaderNodeMix', data_type='FLOAT')
        mixn.inputs['Factor'].default_value = 0.35
        L.new(noise1.outputs['Fac'], mixn.inputs['A'])
        L.new(noise2.outputs['Fac'], mixn.inputs['B'])
        ramp = node('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].position = 0.35
        ramp.color_ramp.elements[0].color = srgb('#a88f6e')
        ramp.color_ramp.elements[1].position = 0.68
        ramp.color_ramp.elements[1].color = srgb('#cdb795')
        L.new(mixn.outputs['Result'], ramp.inputs['Fac'])
        # wash: paler, finer sand
        aw = node('ShaderNodeAttribute', attribute_name='wash')
        mw = node('ShaderNodeMix', data_type='RGBA')
        S(mw, 'B').default_value = srgb('#d6c5a6')
        L.new(aw.outputs['Fac'], mw.inputs['Factor'])
        L.new(ramp.outputs['Color'], S(mw, 'A'))
        # graded / disturbed soil: lighter compacted DG
        ag = node('ShaderNodeAttribute', attribute_name='graded')
        mg = node('ShaderNodeMix', data_type='RGBA')
        S(mg, 'B').default_value = srgb('#d8c4a2')
        gfac = math_node('MULTIPLY', ag.outputs['Fac'], vb=0.85)
        L.new(gfac.outputs[0], mg.inputs['Factor'])
        L.new(O(mw), S(mg, 'A'))
        # contour lines with constant horizontal width: dz / slope
        nx2 = math_node('MULTIPLY', nsep.outputs['X'], nsep.outputs['X'])
        ny2 = math_node('MULTIPLY', nsep.outputs['Y'], nsep.outputs['Y'])
        nxy = math_node('SQRT', math_node('ADD', nx2.outputs[0], ny2.outputs[0]).outputs[0])
        nz = math_node('MAXIMUM', nsep.outputs['Z'], vb=0.2)
        slope = math_node('MAXIMUM', math_node('DIVIDE', nxy.outputs[0], nz.outputs[0]).outputs[0], vb=0.012)

        def contour(interval, width):
            q = math_node('DIVIDE', sep.outputs['Z'], vb=interval)
            fr = math_node('FRACT', q.outputs[0])
            inv = math_node('SUBTRACT', va=1.0, b=fr.outputs[0])
            dmin = math_node('MINIMUM', fr.outputs[0], inv.outputs[0])
            dz = math_node('MULTIPLY', dmin.outputs[0], vb=interval)
            horiz = math_node('DIVIDE', dz.outputs[0], slope.outputs[0])
            ln = math_node('LESS_THAN', horiz.outputs[0], vb=width)
            return ln

        minor = contour(2 * FT, 0.16)
        major = contour(10 * FT, 0.30)
        cstr = node('ShaderNodeValue', label='contour_strength', name='contour_strength')
        cstr.outputs[0].default_value = 0.0
        mc1 = node('ShaderNodeMix', data_type='RGBA')
        S(mc1, 'B').default_value = srgb('#7a5f43')
        f1 = math_node('MULTIPLY', minor.outputs[0], cstr.outputs[0])
        f1b = math_node('MULTIPLY', f1.outputs[0], vb=0.55)
        L.new(f1b.outputs[0], mc1.inputs['Factor'])
        L.new(O(mg), S(mc1, 'A'))
        mc2 = node('ShaderNodeMix', data_type='RGBA')
        S(mc2, 'B').default_value = srgb('#5a4129')
        f2 = math_node('MULTIPLY', major.outputs[0], cstr.outputs[0])
        L.new(f2.outputs[0], mc2.inputs['Factor'])
        L.new(O(mc1), S(mc2, 'A'))
        L.new(O(mc2), p.inputs['Base Color'])
        # gentle bump
        bump = node('ShaderNodeBump')
        bump.inputs['Strength'].default_value = 0.12
        L.new(noise2.outputs['Fac'], bump.inputs['Height'])
        L.new(bump.outputs['Normal'], p.inputs['Normal'])
        self.ground_mat = m
        return m

    def outer_material(self):
        m = bpy.data.materials.new('outer_ground')
        m.use_nodes = True
        nt = m.node_tree
        p = nt.nodes['Principled BSDF']
        p.inputs['Roughness'].default_value = 1.0
        geo = nt.nodes.new('ShaderNodeNewGeometry')
        sep = nt.nodes.new('ShaderNodeSeparateXYZ')
        nt.links.new(geo.outputs['Position'], sep.inputs[0])
        # hills get hazier/bluer with height (fake aerial perspective)
        mr = nt.nodes.new('ShaderNodeMapRange')
        mr.inputs['From Min'].default_value = 8
        mr.inputs['From Max'].default_value = 90
        nt.links.new(sep.outputs['Z'], mr.inputs['Value'])
        noise = nt.nodes.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 0.012
        noise.inputs['Detail'].default_value = 8
        noise.inputs['Roughness'].default_value = 0.7
        tco = nt.nodes.new('ShaderNodeTexCoord')
        nt.links.new(tco.outputs['Object'], noise.inputs['Vector'])
        ramp = nt.nodes.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].position = 0.42
        ramp.color_ramp.elements[0].color = srgb('#8a7660')
        ramp.color_ramp.elements[1].position = 0.62
        ramp.color_ramp.elements[1].color = srgb('#c9b291')
        nt.links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
        mix = nt.nodes.new('ShaderNodeMix')
        mix.data_type = 'RGBA'
        S(mix, 'B').default_value = srgb('#7d6e60')
        mult = nt.nodes.new('ShaderNodeMath')
        mult.operation = 'MULTIPLY'
        mult.inputs[1].default_value = 0.55
        nt.links.new(mr.outputs['Result'], mult.inputs[0])
        nt.links.new(mult.outputs[0], mix.inputs['Factor'])
        nt.links.new(ramp.outputs['Color'], S(mix, 'A'))
        nt.links.new(O(mix), p.inputs['Base Color'])
        return m

    # ------------------------------------------------------------------ draped overlays
    def _strip(self, name, pts, width, mat, coll, step=0.6, off=0.07, dashed=None):
        dense = densify(pts, step)
        bm = bmesh.new()
        n = len(dense)
        left, right = [], []
        for i in range(n):
            a = dense[max(i - 1, 0)]
            b = dense[min(i + 1, n - 1)]
            t = b - a
            t = t / (np.linalg.norm(t) or 1)
            nrm = np.array([-t[1], t[0]])
            pl = dense[i] + nrm * width / 2
            pr = dense[i] - nrm * width / 2
            left.append(bm.verts.new((pl[0], pl[1], 0)))
            right.append(bm.verts.new((pr[0], pr[1], 0)))
        acc = 0.0
        for i in range(n - 1):
            seg = float(np.linalg.norm(dense[i + 1] - dense[i]))
            if dashed:
                on, offl = dashed
                if (acc % (on + offl)) >= on:
                    acc += seg
                    continue
            acc += seg
            bm.faces.new((left[i], right[i], right[i + 1], left[i + 1]))
        ob = self.mesh_obj(name, bm, [mat], coll)
        self._drape(ob, off)
        return ob

    def _poly(self, name, cx, cy, w, l, rot, mat, coll, step=0.7, off=0.06):
        nx = max(2, int(math.ceil(w / step)) + 1)
        ny = max(2, int(math.ceil(l / step)) + 1)
        bm = bmesh.new()
        vs = []
        r = math.radians(rot)
        for j in range(ny):
            row = []
            for i in range(nx):
                u = -w / 2 + w * i / (nx - 1)
                v = -l / 2 + l * j / (ny - 1)
                x = cx + u * math.cos(r) - v * math.sin(r)
                y = cy + u * math.sin(r) + v * math.cos(r)
                row.append(bm.verts.new((x, y, 0)))
            vs.append(row)
        for j in range(ny - 1):
            for i in range(nx - 1):
                bm.faces.new((vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]))
        ob = self.mesh_obj(name, bm, [mat], coll)
        self._drape(ob, off)
        return ob

    def _ring(self, name, cx, cy, r, width, mat, coll, seg=48, off=0.08, dashed=False):
        bm = bmesh.new()
        outer, inner = [], []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            outer.append(bm.verts.new((cx + (r + width / 2) * math.cos(a), cy + (r + width / 2) * math.sin(a), 0)))
            inner.append(bm.verts.new((cx + (r - width / 2) * math.cos(a), cy + (r - width / 2) * math.sin(a), 0)))
        for i in range(seg):
            if dashed and i % 2:
                continue
            j = (i + 1) % seg
            bm.faces.new((inner[i], outer[i], outer[j], inner[j]))
        ob = self.mesh_obj(name, bm, [mat], coll)
        self._drape(ob, off)
        return ob

    def _disk(self, name, cx, cy, r, mat, coll, seg=24, off=0.05):
        bm = bmesh.new()
        c = bm.verts.new((cx, cy, 0))
        ring = [bm.verts.new((cx + r * math.cos(2 * math.pi * i / seg), cy + r * math.sin(2 * math.pi * i / seg), 0)) for i in range(seg)]
        for i in range(seg):
            bm.faces.new((c, ring[i], ring[(i + 1) % seg]))
        ob = self.mesh_obj(name, bm, [mat], coll)
        self._drape(ob, off)
        return ob

    def _drape(self, ob, off):
        ob.location.z = 0
        ph = phase_of(ob.users_collection[0].name) if ob.users_collection and ob.users_collection[0].name.startswith('phase') else 99
        co = np.zeros(len(ob.data.vertices) * 3, np.float32)
        ob.data.vertices.foreach_get('co', co)
        co = co.reshape(-1, 3)
        co[:, 2] = self.t.height(co[:, 0].astype(float), co[:, 1].astype(float), max_phase=ph) + off
        ob.data.vertices.foreach_set('co', co.ravel())
        ob.data.update()

    # ------------------------------------------------------------------ prototypes (vegetation)
    def _proto_mesh(self, key, builder):
        if key not in self._proto:
            self._proto[key] = builder()
        return self._proto[key]

    def _jt_mesh(self, variant):
        """Joshua tree in metres (~5 m reference): fibrous trunk, forked limbs, spiky leaf tufts."""
        rnd = random.Random(100 + variant)
        bm = bmesh.new()

        def cone(base, d, length, r0, r1, mi, seg=7):
            d = Vector(d).normalized()
            g = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r0, radius2=r1, depth=length)
            m = Matrix.Translation(Vector(base) + d * length / 2) @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4()
            bmesh.ops.transform(bm, matrix=m, verts=g['verts'])
            for f in {f for v in g['verts'] for f in v.link_faces}:
                f.material_index = mi

        def tuft(tip):
            core = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.26)
            for v in core['verts']:
                v.co += tip
            for f in {f for v in core['verts'] for f in v.link_faces}:
                f.material_index = 1
            for k in range(34):
                z = rnd.uniform(-0.45, 1.0)
                a = rnd.uniform(0, 2 * math.pi)
                rr = math.sqrt(max(0.0, 1 - z * z))
                cone(tip, (rr * math.cos(a), rr * math.sin(a), z), rnd.uniform(0.5, 0.78), 0.05, 0.004, 1, seg=4)

        def limb(base, d, length, r0, r1, depth):
            cone(base, d, length, r0, r1, 0)
            tip = Vector(base) + Vector(d).normalized() * length
            if depth == 0:
                tuft(tip)
                return
            for _ in range(rnd.choice([2, 2, 3])):
                a = rnd.uniform(0, 2 * math.pi)
                tilt = rnd.uniform(0.55, 1.1)
                limb(tip, (math.cos(a) * tilt, math.sin(a) * tilt, 1.0), length * rnd.uniform(0.6, 0.85), r1 * 0.85, r1 * 0.72, depth - 1)

        if variant == 0:
            limb((0, 0, 0), (0.05, 0, 1), 2.4, 0.24, 0.2, 0)
        elif variant == 1:
            limb((0, 0, 0), (0, 0, 1), 1.9, 0.3, 0.24, 1)
        else:
            limb((0, 0, 0), (0.04, 0.03, 1), 2.1, 0.34, 0.27, 2)
        top = max(v.co.z for v in bm.verts)
        self._jt_h = getattr(self, '_jt_h', {})
        self._jt_h[variant] = top
        return bm

    def joshua_tree(self, x, y, height, coll='veg', variant=None):
        if variant is None:
            variant = 0 if height < 3.2 else (1 if height < 4.6 else 2 + int(abs(x * 7 + y * 3)) % 2)
        key = f'jt{variant}'
        if key not in self._proto:
            bm = self._jt_mesh(variant)
            me = bpy.data.meshes.new(key)
            bm.to_mesh(me)
            bm.free()
            me.materials.append(self.mat('jt_trunk', '#5e5044', rough=0.95))
            me.materials.append(self.mat('jt_leaf', '#7b8a50', rough=0.8))
            self._proto[key] = me
        ob = bpy.data.objects.new('JT', self._proto[key])
        ob.location = (x, y, self.t.h(x, y) - 0.05)
        k = height / self._jt_h[variant]
        ob.scale = (k, k, k)
        ob.rotation_euler = (0, 0, (x * 13 + y * 7) % 6.28)
        return self.link(ob, coll)

    def _blob_mesh(self, key, color, rough=0.9, jitter=0.25, subdiv=2):
        if key in self._proto:
            return self._proto[key]
        rnd = random.Random(hash(key) % 1000)
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=0.5)
        for v in bm.verts:
            v.co *= rnd.uniform(1 - jitter, 1 + jitter)
        me = bpy.data.meshes.new(key)
        bm.to_mesh(me)
        bm.free()
        me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
        me.materials.append(self.mat(key + '_m', color, rough=rough))
        self._proto[key] = me
        return me

    def shrub(self, x, y, s, coll='veg', kind='creosote'):
        if kind == 'creosote':
            me = self._blob_mesh(f'creo{int(x * 3 + y) % 3}', ['#6f6f3c', '#7b7a44', '#5f6536'][int(x * 3 + y) % 3], jitter=0.3)
            sc = (s, s, s * 0.7)
        else:   # bursage / low grey shrubs
            me = self._blob_mesh('bursage', '#9a9476', jitter=0.25)
            sc = (s, s, s * 0.55)
        ob = bpy.data.objects.new('shrub', me)
        ob.location = (x, y, self.t.h(x, y) + sc[2] * 0.25)
        ob.scale = sc
        return self.link(ob, coll)

    def boulder(self, x, y, s, coll='veg'):
        key = f'rock{int(x + y * 3) % 4}'
        if key not in self._proto:
            rnd = random.Random(int(x + y * 3) % 4)
            bm = bmesh.new()
            bmesh.ops.create_icosphere(bm, subdivisions=3, radius=0.5)
            ph = [rnd.uniform(0, 6) for _ in range(6)]
            for v in bm.verts:
                c = v.co
                f = 1 + 0.18 * math.sin(c.x * 5 + ph[0]) * math.cos(c.y * 4 + ph[1]) + 0.12 * math.sin(c.z * 6 + ph[2])
                v.co = Vector((c.x * f * 1.1, c.y * f, c.z * f * 0.75))
            me = bpy.data.meshes.new(key)
            bm.to_mesh(me)
            bm.free()
            me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
            me.materials.append(self.mat('granite', '#b8a68c', rough=0.85))
            self._proto[key] = me
        ob = bpy.data.objects.new('rock', self._proto[key])
        ob.location = (x, y, self.t.h(x, y) + s * 0.12)
        ob.scale = (s, s * 0.9, s)
        ob.rotation_euler = (0, 0, (x * 5.1 + y) % 6.28)
        return self.link(ob, coll)

    # ------------------------------------------------------------------ structures
    def capsule(self, label, x, y, rot=0.0, length=6.0, coll='phase1', phase=1, deck=True, pad=True, until=99):
        """Space-capsule style pod: rounded white shell, wraparound glass band, end window, deck."""
        pcoll = f'phase{phase}'
        if pad:
            e = self.pad(x, y, length + 4.0, 6.5, rot, coll=pcoll)
        else:
            e = self.t.h(x, y)
        root = self.empty(label, x, y, e, rot, coll)
        white = self.mat('capsule_shell', '#eef0ef', rough=0.22, metal=0.15, spec=0.7)
        glass = self.mat('capsule_glass', '#16202a', rough=0.05, metal=0.4, spec=0.9)
        steel = self.mat('steel_dark', '#2b2d30', rough=0.4, metal=0.8)
        wood = self.mat('deck_wood', '#9b7653', rough=0.7)
        L, W, H, lift = length, 2.9, 2.6, 0.55
        for sx in (-1, 1):
            for sy in (-1, 1):
                self.cyl('leg', 0.07, lift, (sx * (L / 2 - 0.9), sy * (W / 2 - 0.6), lift / 2), steel, coll, root)
        self.box('shell', (L, W, H), (0, 0, lift + H / 2), white, coll, root, bevel=0.95, seg=6)
        self.box('band', (L * 0.66, W + 0.06, 0.75), (-0.2, 0, lift + H * 0.55), glass, coll, root, bevel=0.3, seg=4)
        self.box('endglass', (0.3, W * 0.55, H * 0.45), (L / 2 - 0.12, 0, lift + H * 0.52), glass, coll, root, bevel=0.12, seg=3)
        if deck:
            self.box('deck', (2.4, W + 0.6, 0.12), (L / 2 + 1.2, 0, lift - 0.06), wood, coll, root)
        r = math.radians(rot)
        self.foot(x, y, L / 2 + 3, W / 2 + 3)
        self.anchor(label, x, y, e, phase, dz=lift + H + 0.6, until=until)
        return root

    def house(self, label, x, y, rot=0.0, W=9.75, D=6.1, H=3.05, overhang=2.1, coll='phase2', phase=2, patio=True):
        """Small modern box: plaster walls, glass south wall under a deep roof plate, PV on roof."""
        e = self.pad(x, y, W + 7, D + overhang + 7, rot, coll=coll)
        root = self.empty(label, x, y, e, rot, coll)
        plaster = self.mat('plaster', '#e9e1d4', rough=0.85)
        char = self.mat('charcoal', '#2e2f31', rough=0.55, metal=0.2)
        glass = self.mat('house_glass', '#1b2733', rough=0.04, metal=0.35, spec=0.9)
        conc = self.mat('concrete', '#bdb6aa', rough=0.8)
        pv = self.mat_bricks('pv', '#1d2b45', '#8d9bb0', scale=1.1, mortar=0.025)
        plinth = 0.35
        self.box('plinth', (W + 0.3, D + 0.3, plinth), (0, 0, plinth / 2), conc, coll, root)
        self.box('walls', (W, D, H), (0, 0, plinth + H / 2), plaster, coll, root)
        # south glass wall (local -Y is the "front"; rot turns it)
        self.box('glazing', (W * 0.78, 0.08, H * 0.86), (W * 0.06, -D / 2 - 0.04, plinth + H * 0.46), glass, coll, root)
        self.box('mullion', (0.06, 0.1, H * 0.86), (W * 0.06, -D / 2 - 0.05, plinth + H * 0.46), char, coll, root)
        # north clerestory band
        self.box('clere', (W * 0.8, 0.08, 0.45), (0, D / 2 + 0.04, plinth + H - 0.4), glass, coll, root)
        # roof plate with deep south overhang
        rt = 0.28
        self.box('roof', (W + 0.7, D + overhang + 0.35, rt), (0, -overhang / 2 + 0.1, plinth + H + rt / 2), char, coll, root)
        # PV array on roof
        cols = max(2, int((W - 1.2) / 1.08))
        for row in range(2):
            for c in range(cols):
                px = -((cols - 1) * 1.08) / 2 + c * 1.08
                py = -0.2 + row * 1.85 - 0.6
                self.box('pv', (1.0, 1.7, 0.04), (px, py, plinth + H + rt + 0.22), pv, coll, root, rot=(math.radians(-10), 0, 0))
        if patio:
            self.box('patio', (W, overhang + 1.6, 0.12), (0, -D / 2 - (overhang + 1.6) / 2, 0.06), conc, coll, root)
        self.foot(x, y, W / 2 + 4, D / 2 + overhang + 4)
        self.anchor(label, x, y, e, phase, dz=plinth + H + 1.2)
        return root

    def container(self, label, x, y, rot=0.0, L=6.06, coll='phase1', phase=1, shade=False, color='#b39a72'):
        e = self.pad(x, y, L + 3, 6.0, rot, coll=coll)
        root = self.empty(label, x, y, e, rot, coll)
        corr = self.mat_stripes('container_' + color, color, '#8f7a58' if color == '#b39a72' else '#5a2a20', scale=9.0, rough=0.6)
        self.box('box', (L, 2.44, 2.59), (0, 0, 0.15 + 2.59 / 2), corr, coll, root)
        self.box('doors', (0.05, 2.3, 2.4), (L / 2 + 0.02, 0, 0.15 + 1.3), self.mat('container_door', '#6e5f48', rough=0.6), coll, root)
        if shade:
            steel = self.mat('steel_dark', '#2b2d30', rough=0.4, metal=0.8)
            roof = self.mat('shade_roof', '#c9c5bd', rough=0.35, metal=0.6)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    self.box('post', (0.1, 0.1, 3.5), (sx * (L / 2 + 0.3), sy * 1.9, 1.75), steel, coll, root)
            self.box('shade', (L + 1.2, 4.4, 0.06), (0, 0, 3.5), roof, coll, root, rot=(math.radians(4), 0, 0))
        self.foot(x, y, L / 2 + 2.5, 3.5)
        self.anchor(label, x, y, e, phase, dz=4.2)
        return root

    def solar(self, label, x, y, rot=0.0, rows=2, cols=8, coll='phase1', phase=1, tilt=28):
        e = self.pad(x, y, cols * 1.05 + 3, rows * 4.5 + 2, rot, coll=coll)
        root = self.empty(label, x, y, e, rot, coll)
        pv = self.mat_bricks('pv', '#1d2b45', '#8d9bb0', scale=1.1, mortar=0.025)
        steel = self.mat('steel_dark', '#2b2d30', rough=0.4, metal=0.8)
        for r in range(rows):
            yy = -((rows - 1) * 4.5) / 2 + r * 4.5
            self.box('rack', (cols * 1.05, 3.4, 0.05), (0, yy, 1.6), pv, coll, root, rot=(math.radians(tilt), 0, 0))
            for c in range(0, cols + 1, 3):
                px = -cols * 1.05 / 2 + c * 1.05
                self.box('post', (0.08, 0.08, 1.4), (px, yy - 0.9, 0.7), steel, coll, root)
                self.box('post', (0.08, 0.08, 2.4), (px, yy + 0.9, 1.2), steel, coll, root)
        self.foot(x, y, cols * 0.53 + 1.5, rows * 2.3 + 1)
        self.anchor(label, x, y, e, phase, dz=3.0)
        return root

    def tanks(self, label, x, y, n=2, r=1.3, h=2.5, coll='phase1', phase=1, color='#55603f', rot=0.0):
        e = self.pad(x, y, n * (2 * r + 0.8) + 2, 2 * r + 3, rot, coll=coll)
        root = self.empty(label, x, y, e, rot, coll)
        m = self.mat('tank_' + color, color, rough=0.55)
        for i in range(n):
            px = -((n - 1) * (2 * r + 0.8)) / 2 + i * (2 * r + 0.8)
            rr = r * (1.0 if i == 0 else 1.15)
            hh = h * (1.0 if i == 0 else 1.15)
            self.cyl('tank', rr, hh, (px, 0, hh / 2), m, coll, root, seg=32)
            self.cyl('lid', rr * 0.98, 0.35, (px, 0, hh + 0.17), m, coll, root, seg=32, r2=rr * 0.35)
        self.foot(x, y, n * (r + 0.4) + 1.5, r + 1.5)
        self.anchor(label, x, y, e, phase, dz=h + 1.2)
        return root

    def ramada(self, label, x, y, rot=0.0, w=6.0, l=4.5, coll='phase3', phase=3, anchor=True):
        e = self.t.h(x, y)
        root = self.empty(label, x, y, e, rot, coll)
        wood = self.mat('ramada_wood', '#8a6a4c', rough=0.75)
        for sx in (-1, 1):
            for sy in (-1, 1):
                self.box('post', (0.18, 0.18, 2.8), (sx * (w / 2 - 0.2), sy * (l / 2 - 0.2), 1.4), wood, coll, root)
        for i in range(int(w / 0.35)):
            self.box('slat', (0.08, l + 0.4, 0.12), (-w / 2 + 0.2 + i * 0.35, 0, 2.86), wood, coll, root)
        self.box('beam', (w + 0.3, 0.2, 0.25), (0, l / 2 - 0.2, 2.72), wood, coll, root)
        self.box('beam', (w + 0.3, 0.2, 0.25), (0, -l / 2 + 0.2, 2.72), wood, coll, root)
        self.foot(x, y, w / 2 + 1, l / 2 + 1)
        if anchor:
            self.anchor(label, x, y, e, phase, dz=3.4)
        return root

    def hot_tub(self, label, x, y, coll='phase3', phase=3, anchor=True):
        e = self.t.h(x, y)
        root = self.empty(label, x, y, e, 0, coll)
        self.box('tubdeck', (3.4, 3.4, 0.15), (0, 0, 0.08), self.mat('deck_wood', '#9b7653', rough=0.7), coll, root)
        self.cyl('tub', 0.95, 0.8, (0, 0, 0.55), self.mat('hinoki', '#c79a62', rough=0.6), coll, root, seg=32)
        self.cyl('water', 0.85, 0.02, (0, 0, 0.9), self.mat('water', '#3d7f8c', rough=0.05, spec=0.9), coll, root, seg=32)
        self.foot(x, y, 2.4)
        if anchor:
            self.anchor(label, x, y, e, phase, dz=1.6)
        return root

    def fire_pit(self, x, y, coll='phase3'):
        e = self.t.h(x, y)
        stone = self.mat('stone', '#8d8478', rough=0.9)
        for i in range(10):
            a = i * 2 * math.pi / 10
            self.box('stone', (0.35, 0.3, 0.3), (x + 0.8 * math.cos(a), y + 0.8 * math.sin(a), e + 0.12), stone, coll, rot=(0, 0, a))
        self._disk('ash', x, y, 0.65, self.mat('ash', '#3a3430', rough=1.0), coll, off=0.04)
        self.foot(x, y, 1.5)

    def beds(self, label, x, y, rot=0.0, n=4, coll='phase2', phase=2, anchor=True):
        e = self.pad(x, y, n * 1.9 + 2, 5.0, rot, coll=coll)
        root = self.empty(label, x, y, e, rot, coll)
        wood = self.mat('bed_wood', '#8b6b4a', rough=0.8)
        soil = self.mat('soil', '#4a3a2c', rough=1.0)
        green = self.mat('veg_green', '#6c8a3e', rough=0.8)
        for i in range(n):
            px = -((n - 1) * 1.9) / 2 + i * 1.9
            self.box('bed', (1.2, 3.0, 0.55), (px, 0, 0.28), wood, coll, root)
            self.box('soil', (1.05, 2.85, 0.05), (px, 0, 0.56), soil, coll, root)
            for k in range(3):
                self.box('crop', (0.7, 0.6, 0.25), (px, -0.9 + k * 0.9, 0.7), green, coll, root, bevel=0.2, seg=2)
        # shade cloth frame
        self.box('shadecloth', (n * 1.9 + 0.6, 4.0, 0.03), (0, 0, 2.3), self.mat('shadecloth', '#3b3f37', rough=0.9, alpha=0.6), coll, root)
        steel = self.mat('steel_dark', '#2b2d30', rough=0.4, metal=0.8)
        for sx in (-1, 1):
            for sy in (-1, 1):
                self.box('post', (0.06, 0.06, 2.3), (sx * (n * 0.95 + 0.25), sy * 1.9, 1.15), steel, coll, root)
        self.foot(x, y, n * 0.95 + 1.2, 2.6)
        if anchor:
            self.anchor(label, x, y, e, phase, dz=2.8)
        return root

    def orchard(self, label, x, y, rot=0.0, nx=5, ny=3, sx=6.0, sy=6.0, coll='phase3', phase=3, maturity=1.0, kinds=None):
        r = math.radians(rot)
        basin = self.mat('basin', '#7d6448', rough=1.0)
        trunk = self.mat('fruit_trunk', '#5b4636', rough=0.9)
        palette = kinds or ['#5f7d3a', '#6b8a42', '#4f6e36', '#7a8f4a']
        n = 0
        for j in range(ny):
            for i in range(nx):
                u = -((nx - 1) * sx) / 2 + i * sx
                v = -((ny - 1) * sy) / 2 + j * sy
                px = x + u * math.cos(r) - v * math.sin(r)
                py = y + u * math.sin(r) + v * math.cos(r)
                if any((px - jx) ** 2 + (py - jy) ** 2 < 16 for jx, jy, _ in JOSHUA_TREES):
                    continue
                z = self.t.h(px, py)
                self._disk('basin', px, py, 1.5, basin, coll, off=0.04)
                cr = (1.0 + 0.9 * maturity) * (0.9 + 0.2 * ((i * 7 + j * 3) % 5) / 4)
                self.cyl('trunk', 0.08, 1.2, (px, py, z + 0.6), trunk, coll, seg=8)
                me = self._blob_mesh('canopy%d' % ((i + j) % len(palette)), palette[(i + j) % len(palette)], jitter=0.18)
                ob = bpy.data.objects.new('canopy', me)
                ob.location = (px, py, z + 1.2 + cr * 0.75)
                ob.scale = (cr * 2, cr * 2, cr * 1.6)
                self.link(ob, coll)
                self.foot(px, py, 2.2)
                n += 1
        self.anchor(label, x, y, None, phase, dz=4.0)
        return n

    def windbreak(self, label, pts, spacing=5.0, coll='phase3', phase=3, height=4.5):
        """Two staggered rows of native windbreak plants: mesquite, desert willow and four-wing saltbush."""
        dense = densify(pts, spacing)
        trunk = self.mat('fruit_trunk', '#5b4636', rough=0.9)
        kinds = [('mesq', '#56653a', 1.0), ('dwillow', '#768a48', 0.9), ('saltbush', '#9aa27c', 0.45)]
        for k, (px, py) in enumerate(dense):
            a = dense[min(k + 1, len(dense) - 1)] - dense[max(k - 1, 0)]
            a = a / (np.linalg.norm(a) or 1)
            nrm = np.array([-a[1], a[0]])
            for row in (0, 1):
                if row and k % 2:
                    continue
                qx, qy = np.array([px, py]) + nrm * (row * 3.0) + a * (row * spacing / 2)
                if any((qx - jx) ** 2 + (qy - jy) ** 2 < 12 for jx, jy, _ in JOSHUA_TREES):
                    continue
                key, col, hk = kinds[(k + row * 2) % 3]
                hgt = height * hk * (0.85 + 0.3 * ((k * 37) % 10) / 10)
                z = self.t.h(qx, qy)
                if hk > 0.6:
                    self.cyl('wb_trunk', 0.1, hgt * 0.45, (qx, qy, z + hgt * 0.22), trunk, coll, seg=6)
                me = self._blob_mesh(key, col, jitter=0.22)
                ob = bpy.data.objects.new(key, me)
                w = hgt * (0.95 if hk > 0.6 else 1.6)
                ob.location = (qx, qy, z + (hgt * 0.62 if hk > 0.6 else hgt * 0.35))
                ob.scale = (w, w, hgt * (0.6 if hk > 0.6 else 0.7))
                self.link(ob, coll)
                self.foot(qx, qy, 2.4)
        mid = dense[len(dense) // 2]
        self.anchor(label, mid[0], mid[1], None, phase, dz=height + 0.8)

    def car(self, x, y, rot=0.0, coll='phase1', color='#6d7b86'):
        e = self.t.h(x, y)
        root = self.empty('car', x, y, e, rot, coll)
        body = self.mat('car_' + color, color, rough=0.3, metal=0.5)
        glass = self.mat('capsule_glass', '#16202a', rough=0.05, metal=0.4, spec=0.9)
        self.box('body', (4.6, 1.85, 0.9), (0, 0, 0.75), body, coll, root, bevel=0.25, seg=3)
        self.box('cab', (2.6, 1.7, 0.65), (-0.2, 0, 1.45), glass, coll, root, bevel=0.2, seg=3)
        self.foot(x, y, 3)

    def gate(self, label, x, y, coll='phase1', phase=1, width=6.0):
        e = self.t.h(x, y)
        steel = self.mat('steel_dark', '#2b2d30', rough=0.4, metal=0.8)
        for sx in (-1, 1):
            self.box('gatepost', (0.25, 0.25, 2.2), (x + sx * width / 2, y, e + 1.1), steel, coll)
        self.box('gatebar', (width, 0.08, 0.08), (x, y, e + 1.6), steel, coll)
        self.box('gatebar', (width, 0.08, 0.08), (x, y, e + 0.8), steel, coll)
        self.anchor(label, x, y, e, phase, dz=2.8)

    def septic(self, label, x, y, w=10.0, l=16.0, rot=0.0, coll='phase2', phase=2):
        m = self.mat_stripes('leach', '#cbb592', '#8a6e4b', scale=1.6, rough=1.0, axis='X')
        self._poly('leachfield', x, y, w, l, rot, m, coll, off=0.05)
        self.foot(x, y, w / 2 + 1, l / 2 + 1)
        self.anchor(label, x, y, None, phase, dz=1.0)

    def well(self, label, x, y, coll='phase1', phase=1):
        e = self.pad(x, y, 4.0, 4.0, coll=coll)
        conc = self.mat('concrete', '#bdb6aa', rough=0.8)
        steel = self.mat('steel_dark', '#2b2d30', rough=0.4, metal=0.8)
        self.box('wellpad', (2.2, 2.2, 0.15), (x, y, e + 0.075), conc, coll)
        self.cyl('casing', 0.12, 0.6, (x - 0.4, y, e + 0.45), steel, coll, seg=16)
        self.box('pumpbox', (1.0, 0.8, 1.1), (x + 0.5, y + 0.2, e + 0.7), self.mat('pumphouse', '#8f8a7e', rough=0.7), coll)
        self.wells = getattr(self, 'wells', []) + [(x, y)]
        self.foot(x, y, 2.5)
        self.anchor(label, x, y, e, phase, dz=1.8)

    def lookout(self, label, x, y, coll='phase3', phase=3):
        e = self.t.h(x, y)
        wood = self.mat('ramada_wood', '#8a6a4c', rough=0.75)
        self.box('bench', (2.2, 0.5, 0.45), (x, y, e + 0.25), wood, coll)
        self.anchor(label, x, y, e, phase, dz=1.4)

    def neighbor(self, x, y, rot=0.0, W=12, D=8):
        e = self.t.h(x, y)
        root = self.empty('neighbor', x, y, e, rot, 'context')
        self.box('nh', (W, D, 3.2), (0, 0, 1.6), self.mat('nh_wall', '#d6cbb8', rough=0.9), 'context', root)
        self.box('nhroof', (W + 0.8, D + 0.8, 0.3), (0, 0, 3.35), self.mat('nh_roof', '#7d7468', rough=0.8), 'context', root)
        self.foot(x, y, W / 2 + 3, D / 2 + 3)

    def poles(self):
        wood = self.mat('pole', '#5d4b3b', rough=0.9)
        for px in np.arange(-400, 700, 55.0):
            z = self.t.h(px, ROAD_Y - 6)
            self.cyl('pole', 0.15, 10.0, (px, ROAD_Y - 6, z + 5), wood, 'context', seg=8)
            self.box('xarm', (0.15, 2.2, 0.15), (px, ROAD_Y - 6, z + 9.3), wood, 'context')

    # ------------------------------------------------------------------ plan overlays
    def overlays(self, defensible=None):
        white = self.mat('boundary', '#ffffff', rough=0.5, emit='#ffffff', emit_strength=0.6)
        orange = self.mat('setback', '#e8782a', rough=0.5, emit='#e8782a', emit_strength=0.4)
        green = self.mat('jt_ring', '#2fa36b', rough=0.5, emit='#2fa36b', emit_strength=0.5)
        red = self.mat('fire_ring', '#e03131', rough=0.5, emit='#e03131', emit_strength=1.2)
        rect = [(0, 0), (LOT_W, 0), (LOT_W, LOT_D), (0, LOT_D), (0, 0)]
        self._strip('boundary', np.array(rect), 0.45, white, 'plan', step=0.8, off=0.12)
        sb = [(SETBACK_SIDE, SETBACK_FRONT), (LOT_W - SETBACK_SIDE, SETBACK_FRONT), (LOT_W - SETBACK_SIDE, LOT_D - SETBACK_REAR),
              (SETBACK_SIDE, LOT_D - SETBACK_REAR), (SETBACK_SIDE, SETBACK_FRONT)]
        self._strip('setback', np.array(sb), 0.25, orange, 'plan', step=0.5, off=0.11, dashed=(2.5, 2.0))
        buf = self.mat('jt_buffer', '#2fa36b', rough=0.6, emit='#2fa36b', emit_strength=0.35, alpha=0.2)
        for (jx, jy, _) in JOSHUA_TREES:
            self._disk('jt_buffer', jx, jy, JT_BUFFER, buf, 'plan', seg=64, off=0.09)
            self._ring('jt_ring', jx, jy, JT_BUFFER, 0.3, green, 'plan', seg=96)
        blue = self.mat('well_ring', '#2f7fd8', rough=0.5, emit='#2f7fd8', emit_strength=1.0)
        for (wx, wy) in getattr(self, 'wells', []):
            self._ring('well_ring', wx, wy, 30.5, 0.4, blue, 'plan', seg=120, dashed=True)
        for (fx, fy, r) in (defensible or []):
            self._ring('fire_ring', fx, fy, r, 0.45, red, 'plan_fire', seg=120, dashed=True)
        # aerial-visible boundary (thin, subtle)
        self._strip('boundary_aerial', np.array(rect), 0.5, self.mat('boundary_a', '#fff6e0', rough=0.5, emit='#fff6e0', emit_strength=0.12), 'aerial_only', step=1.0, off=0.12)

    # ------------------------------------------------------------------ finalise
    def build_surfaces(self):
        dg = self.mat('dg', '#d9c7a6', rough=1.0)
        gravel = self.mat('gravel', '#cdb898', rough=1.0)
        pathm = self.mat('path', '#e2d2b4', rough=1.0)
        for (cx, cy, w, l, rot, e, coll, surface) in getattr(self, '_pads', []):
            if surface:
                self._poly('pad', cx, cy, w, l, rot, dg, coll, off=0.04)
        for (dense, width, coll, surface) in getattr(self, '_roads', []):
            self._strip('drive', dense, width, gravel, coll, step=0.8, off=0.06)
        for (dense, width, coll) in getattr(self, '_paths', []):
            self._strip('path', dense, width, pathm, coll, step=0.6, off=0.05)

    def scatter(self, density=1.0):
        rnd = random.Random(11)
        pts = []
        fp = self.footprints

        def blocked_phase(x, y):
            """0 = free; otherwise the earliest phase whose footprint covers the point."""
            for (jx, jy, _) in JOSHUA_TREES:
                if (x - jx) ** 2 + (y - jy) ** 2 < 6:
                    return 1
            if abs(y - ROAD_Y) < 6:
                return 1
            best = 0
            for (cx, cy, rx, ry, ph) in fp:
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 < 1.0:
                    best = ph if best == 0 else min(best, ph)
                    if best == 1:
                        break
            return best

        def blocked(x, y):
            return blocked_phase(x, y) != 0

        step = 5.2 / math.sqrt(density)
        for gx in np.arange(-85, 285, step):
            for gy in np.arange(-65, 185, step):
                x = gx + rnd.uniform(-step * 0.45, step * 0.45)
                y = gy + rnd.uniform(-step * 0.45, step * 0.45)
                if rnd.random() < 0.35:
                    continue
                bp = blocked_phase(x, y)
                if bp == 1:
                    continue
                coll = 'veg' if bp == 0 else f'veg_until{bp}'
                if rnd.random() < 0.75:
                    self.shrub(x, y, rnd.uniform(1.0, 2.1), coll=coll, kind='creosote')
                else:
                    self.shrub(x, y, rnd.uniform(0.6, 1.1), coll=coll, kind='bursage')
        for (x, y, h) in JOSHUA_TREES:
            self.joshua_tree(x, y, h)
        # extra Joshua trees on neighbouring land
        for k in range(40):
            x = rnd.uniform(-85, 285)
            y = rnd.uniform(-60, 185)
            if -25 <= x <= LOT_W + 25 and -25 <= y <= LOT_D + 25:
                continue
            if abs(y - ROAD_Y) < 8 or blocked(x, y):
                continue
            self.joshua_tree(x, y, rnd.uniform(2.5, 6.0))
        for (bx, by, r, n) in BOULDERS:
            for k in range(n):
                a = rnd.uniform(0, 2 * math.pi)
                d = rnd.uniform(0, r)
                x, y = bx + d * math.cos(a), by + d * math.sin(a)
                if blocked(x, y):
                    continue
                self.boulder(x, y, rnd.uniform(1.2, 3.6))

    def lights(self, sun_az=225, sun_el=42, strength=4.2, sky_strength=0.5):
        world = bpy.data.worlds.new('world')
        self.scene.world = world
        world.use_nodes = True
        nt = world.node_tree
        bg = nt.nodes['Background']
        sky = nt.nodes.new('ShaderNodeTexSky')
        sky.sky_type = 'NISHITA'
        sky.sun_disc = False
        sky.sun_elevation = math.radians(sun_el)
        sky.sun_rotation = math.radians(sun_az)
        sky.altitude = 1000
        sky.dust_density = 0.8
        nt.links.new(sky.outputs['Color'], bg.inputs['Color'])
        bg.inputs['Strength'].default_value = sky_strength
        sd = bpy.data.lights.new('sun', 'SUN')
        sd.energy = strength
        sd.angle = math.radians(1.2)
        sd.color = (1.0, 0.95, 0.88)
        sun = bpy.data.objects.new('sun', sd)
        a, el = math.radians(sun_az), math.radians(sun_el)
        to_sun = Vector((math.sin(a) * math.cos(el), math.cos(a) * math.cos(el), math.sin(el)))
        sun.rotation_euler = (-to_sun).to_track_quat('-Z', 'Y').to_euler()
        self.link(sun, 'land')
        self.sun = sun
        self.sky = sky

    def set_sun(self, az, el, strength=None):
        a, e = math.radians(az), math.radians(el)
        to_sun = Vector((math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e)))
        self.sun.rotation_euler = (-to_sun).to_track_quat('-Z', 'Y').to_euler()
        self.sky.sun_elevation = e
        self.sky.sun_rotation = a
        if strength:
            self.sun.data.energy = strength

    def camera(self, name, loc, target=None, ortho=None, lens=35, rot=None):
        cd = bpy.data.cameras.new(name)
        cam = bpy.data.objects.new(name, cd)
        cam.location = loc
        if ortho:
            cd.type = 'ORTHO'
            cd.ortho_scale = ortho
        else:
            cd.lens = lens
        cd.clip_end = 6000
        if target is not None:
            d = Vector(target) - Vector(loc)
            cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
        if rot is not None:
            cam.rotation_euler = rot
        self.link(cam, 'land')
        return cam

    def render(self, cam, name, res=(2000, 1000), samples=48, contours=0.0, hide=(), show=(), extra_anchor_filter=None):
        sc = self.scene
        sc.camera = cam
        sc.render.engine = 'CYCLES'
        sc.cycles.device = 'CPU'
        sc.cycles.samples = 12 if self.preview else samples
        sc.cycles.use_denoising = True
        sc.cycles.max_bounces = 4
        sc.cycles.diffuse_bounces = 2
        sc.cycles.glossy_bounces = 2
        sc.cycles.transmission_bounces = 2
        sc.render.threads_mode = 'AUTO'
        f = 0.4 if self.preview else 1.0
        sc.render.resolution_x = int(res[0] * f)
        sc.render.resolution_y = int(res[1] * f)
        sc.render.resolution_percentage = 100
        sc.render.film_transparent = False
        sc.view_settings.view_transform = 'AgX'
        sc.view_settings.look = 'AgX - Medium High Contrast'
        sc.view_settings.exposure = 0.0
        sc.render.image_settings.file_format = 'PNG'
        if hasattr(self, 'ground_mat'):
            self.ground_mat.node_tree.nodes['contour_strength'].outputs[0].default_value = contours
        for c in self.colls.values():
            c.hide_render = False
        for h in hide:
            if h in self.colls:
                self.colls[h].hide_render = True
        path = os.path.join(self.out, f'{name}.png')
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        # project anchors for labelling
        W, H = sc.render.resolution_x, sc.render.resolution_y
        pts = []
        for i, a in enumerate(self.anchors):
            if extra_anchor_filter and not extra_anchor_filter(a):
                continue
            co = world_to_camera_view(sc, cam, Vector(a['pos']))
            if 0 <= co.x <= 1 and 0 <= co.y <= 1 and co.z > 0:
                pts.append({'n': i + 1, 'label': a['label'], 'x': co.x * W, 'y': (1 - co.y) * H, 'phase': a['phase']})
        meta = {'image': f'{name}.png', 'width': W, 'height': H, 'anchors': pts}
        if cam.data.type == 'ORTHO':
            meta['px_per_m'] = W / cam.data.ortho_scale
        with open(os.path.join(self.out, f'{name}.json'), 'w') as fh:
            json.dump(meta, fh, indent=1)
        print('RENDERED', path)
        return path

    # standard cameras
    def plan_cam(self):
        return self.camera('plan', (LOT_W / 2, LOT_D / 2 - 4.0, 400), ortho=232, rot=(0, 0, 0))

    def aerial_cam(self, loc=(30, -98, 64), target=(104, 54, 12), lens=27):
        return self.camera('aerial', loc, target, lens=lens)


def earthwork(s):
    """Cut/fill volumes and disturbed area of the grading model, inside the lot, per phase."""
    st = 0.5
    xs = np.arange(0, LOT_W, st) + st / 2
    ys = np.arange(0, LOT_D, st) + st / 2
    X, Y = np.meshgrid(xs, ys)
    x, y = X.ravel(), Y.ravel()
    h0 = base_height(x, y)
    out = {}
    for ph in (1, 2, 99):
        d = s.t.height(x, y, max_phase=ph) - h0
        cut = float(np.clip(-d, 0, None).sum() * st * st)
        fill = float(np.clip(d, 0, None).sum() * st * st)
        dist = float((np.abs(d) > 0.05).sum() * st * st)
        out[str(ph)] = {'cut_cy': round(cut * 1.30795), 'fill_cy': round(fill * 1.30795),
                        'disturbed_sqft': round(dist * 10.7639), 'disturbed_acres': round(dist / 4046.86, 2)}
    roads = getattr(s, '_roads', [])
    out['drive_ft'] = round(sum(float(np.linalg.norm(np.diff(dn, axis=0), axis=1).sum()) for dn, *_ in roads) / FT)
    with open(os.path.join(s.out, f'{s.id}_stats.json'), 'w') as fh:
        json.dump(out, fh, indent=1)
    print('STATS', out)



def disturbance_mask(s, step=1.0, pad=25.0):
    """Boolean grid of ground the scheme disturbs (grading, structures, plantings), excluding footpaths."""
    xs = np.arange(-pad, LOT_W + pad, step)
    ys = np.arange(-pad, LOT_D + pad, step)
    X, Y = np.meshgrid(xs, ys)
    x, y = X.ravel(), Y.ravel()
    m = np.abs(s.t.height(x, y) - base_height(x, y)) > 0.02
    for (cx, cy, rx, ry, ph), kind in zip(s.footprints, s.kinds):
        if kind == 'path':
            continue
        m |= ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 < 1.0
    return xs, ys, m.reshape(X.shape)


def check_trees(s):
    xs, ys, m = disturbance_mask(s)
    X, Y = np.meshgrid(xs, ys)
    px, py = X[m], Y[m]
    bad = []
    for (jx, jy, h) in JOSHUA_TREES:
        d = np.sqrt((px - jx) ** 2 + (py - jy) ** 2).min() if len(px) else 1e9
        if d < JT_BUFFER:
            bad.append((jx, jy, round(float(d), 1)))
    print('JT-CHECK', s.id, 'violations:', bad)
    return bad


def finish(s, defensible, aerial=None, phases=True):
    if os.environ.get('YV_DRYRUN'):
        xs, ys, m = disturbance_mask(s)
        np.save(os.path.join(s.out, f'{s.id}_mask.npy'), m)
        np.save(os.path.join(s.out, 'mask_axes.npy'), np.array([xs[0], ys[0], 1.0, len(xs), len(ys)]))
        print('DRYRUN mask saved', s.id, int(m.sum()))
        return
    bad = check_trees(s)
    if os.environ.get('YV_CHECK'):
        return
    earthwork(s)
    s.build_terrain(phases=(1, 2, 99) if phases else (99,))
    s.build_surfaces()
    s.overlays(defensible=defensible)
    s.scatter()
    s.lights(sun_az=225, sun_el=42)
    plan = s.plan_cam()
    aer = s.aerial_cam(**(aerial or {}))
    full_hide = ['aerial_only', 'terrain_1', 'terrain_2', 'veg_until2', 'veg_until3', 'until3']
    s.render(plan, f'{s.id}_plan', contours=1.0, hide=full_hide,
             extra_anchor_filter=lambda a: a.get('until', 99) > 3)
    if phases:
        s.render(plan, f'{s.id}_plan_p1', contours=1.0,
                 hide=['aerial_only', 'terrain_2', 'terrain_99', 'phase2', 'phase3', 'plan_fire'],
                 extra_anchor_filter=lambda a: a['phase'] == 1)
        s.render(plan, f'{s.id}_plan_p2', contours=1.0,
                 hide=['aerial_only', 'terrain_1', 'terrain_99', 'phase3', 'veg_until2'],
                 extra_anchor_filter=lambda a: a['phase'] <= 2 and a.get('until', 99) > 2)
    s.set_sun(245, 22, 4.6)
    s.render(aer, f'{s.id}_aerial', res=(1800, 1000), hide=['plan', 'plan_fire'] + full_hide[1:],
             extra_anchor_filter=lambda a: a.get('until', 99) > 3)


def args():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    out = argv[0] if argv else os.path.join(os.path.dirname(__file__), '..', 'renders')
    preview = len(argv) > 1 and argv[1] == 'preview'
    return out, preview
