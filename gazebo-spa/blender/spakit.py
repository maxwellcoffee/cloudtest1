"""spakit -- headless-Blender toolkit for the gazebo bathhouse schemes.

Builds on sitekit from the land plan (same lot, terrain, Joshua trees, sky and materials) but
re-centres the world on the spa: local metres, +X east, +Y north, origin at the spa centre,
which sits at lot coordinates (SX, SY), just south-east of the permitted house in land Scheme A.

Palette (style direction from the brief): bleached stone and white plaster, cedar, black-stained
timber, coral-red Korean lattice (changsal), blush and peach textiles, deep green planting.

Run a scheme with:  blender -b --python spa_a_pavilion.py -- <out_dir> [preview]
"""
import math, os, random, sys
import bpy, bmesh
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'yucca-valley-plan', 'blender'))
import sitekit as K  # noqa: E402

# ---------------------------------------------------------------- re-centre the lot on the spa
SX, SY = (float(v) for v in os.environ.get('SPA_CENTER', '50,46').split(','))   # lot coordinates of the local origin
_bh, _wf = K.base_height, K.wash_factor
Z0 = float(_bh(np.array([SX]), np.array([SY]))[0])
K.base_height = lambda x, y: _bh(np.asarray(x) + SX, np.asarray(y) + SY) - Z0
K.wash_factor = lambda x, y: _wf(np.asarray(x) + SX, np.asarray(y) + SY)
K.ROAD_Y = K.ROAD_Y - SY
K.JOSHUA_TREES = [(x - SX, y - SY, h) for (x, y, h) in K.JOSHUA_TREES]
K.BOULDERS = [(x - SX, y - SY, r, n) for (x, y, r, n) in K.BOULDERS]
HOUSE = (30 - SX, 60 - SY)          # the permitted house of land Scheme A, in spa coordinates

CORAL = '#df4537'
BLUSH = '#f2d1d1'
PEACH = '#fec6b4'
BLACK = '#1f1d1c'
CEDAR = '#b27a4e'
CEDAR2 = '#9f6a42'
STONE = '#e6dfd4'
PLASTER = '#f3ede6'
LEAF = '#3f6a35'

# marker categories on the plans: 1 water, 2 heat, 3 rest + garden, 0 structure
PALETTE = {1: (214, 64, 52), 2: (34, 32, 31), 3: (63, 112, 60), 0: (120, 112, 104)}


def args():
    return K.args()


class Leaves:
    """Accumulates many leaf strips / cards into one mesh (one object per plant keeps scenes light)."""

    def __init__(self):
        self.v, self.f = [], []

    def strip(self, base, ang, length, width, lift=0.6, droop=0.6, n=8, petiole=0.0, serrate=False, tilt=0.0, curl=0.0):
        """An arching leaf: starts at base heading at azimuth `ang` with initial elevation `lift` (radians-ish
        slope), bending down by `droop`. width profile is a lens; `petiole` keeps the first part thin."""
        bx, by, bz = base
        ca, sa = math.cos(ang), math.sin(ang)
        pts = []
        x = z = 0.0
        for i in range(n + 1):
            t = i / n
            slope = lift - droop * 2.2 * t
            x += length / n * math.cos(math.atan(slope))
            z += length / n * math.sin(math.atan(slope))
            if petiole and t < petiole:
                w = 0.012
            else:
                tt = (t - petiole) / max(1e-3, 1 - petiole)
                w = width * math.sin(math.pi * min(1.0, tt * 0.92 + 0.08)) ** 0.8 + 0.004
                if serrate and i % 2:
                    w *= 0.35
            pts.append((x, z, w))
        k0 = len(self.v)
        for (x, z, w) in pts:
            px, py = bx + ca * x, by + sa * x
            nx, ny = -sa * w / 2, ca * w / 2
            dz = w * 0.5 * tilt
            self.v.append((px + nx, py + ny, bz + z + dz + curl * w))
            self.v.append((px - nx, py - ny, bz + z - dz + curl * w))
        for i in range(n):
            a = k0 + 2 * i
            self.f.append((a, a + 2, a + 3, a + 1))

    def fan(self, P, d, n=22, span=2.6, length=0.85, width=0.07, droop=0.35):
        """Palmate fan blade at petiole tip P: n narrow segments radiating around direction d."""
        d = Vector(d).normalized()
        side = d.cross(Vector((0, 0, 1)))
        if side.length < 1e-3:
            side = Vector((1, 0, 0))
        side.normalize()
        up = side.cross(d).normalized()
        P = Vector(P)
        for i in range(n):
            th = -span / 2 + span * i / (n - 1)
            u = (d * math.cos(th) + side * math.sin(th)).normalized()
            L = length * (0.75 + 0.25 * math.cos(th))
            k0 = len(self.v)
            m = 4
            for j in range(m + 1):
                t = j / m
                c = P + u * (L * t) + up * (0.12 * L * math.sin(math.pi * t)) - Vector((0, 0, droop * L * t * t))
                w = width * (1 - 0.7 * t) + 0.004
                sd = (u.cross(up)).normalized() * (w / 2)
                self.v.append(tuple(c + sd))
                self.v.append(tuple(c - sd))
            for j in range(m):
                a = k0 + 2 * j
                self.f.append((a, a + 2, a + 3, a + 1))

    def card(self, c, normal, size, ang=0.0, shape='diamond'):
        """A single small leaf card centred at c facing `normal`."""
        nrm = Vector(normal).normalized()
        u = nrm.orthogonal().normalized()
        w = nrm.cross(u)
        cs, sn = math.cos(ang), math.sin(ang)
        a = (u * cs + w * sn) * size
        b = (-u * sn + w * cs) * size * 0.55
        c = Vector(c)
        k0 = len(self.v)
        if shape == 'diamond':
            for p in (c - a, c - b, c + a, c + b):
                self.v.append(tuple(p))
            self.f.append((k0, k0 + 1, k0 + 2, k0 + 3))
        else:
            for p in (c - a - b, c + a - b, c + a + b, c - a + b):
                self.v.append(tuple(p))
            self.f.append((k0, k0 + 1, k0 + 2, k0 + 3))

    def build(self, site, name, mat, coll, smooth=True):
        if not self.f:
            return None
        return site.mesh_from(name, self.v, self.f, mat, coll, smooth=smooth)


class Spa(K.Site):
    lantern_power = 9.0

    def __init__(self, sid, out, preview=False):
        super().__init__(sid, out, preview)
        self.e = 0.0
        self.z = 0.2
        self.night = False
        self.lamps = []

    # ================================================================ materials
    def m(self, key):
        f = {
            'timber': lambda: self.mat('timber_black', BLACK, rough=0.62),
            'cedar': lambda: self.mat_grain('cedar_v', CEDAR, CEDAR2, 'X', 9.0),
            'cedar_h': lambda: self.mat_grain('cedar_h', CEDAR, CEDAR2, 'Z', 7.0),
            'cedar_y': lambda: self.mat_grain('cedar_y', CEDAR, CEDAR2, 'Y', 9.0),
            'cedar_plain': lambda: self.mat('cedar_plain', '#a9744b', rough=0.6),
            'coral': lambda: self.mat('coral_lacquer', CORAL, rough=0.38),
            'roof': lambda: self.mat_grain('roof_tile', '#2c2a29', '#3a3735', 'X', 9.0, rough=0.55),
            'roof_flat': lambda: self.mat('roof_flat', '#2a2827', rough=0.5, metal=0.25),
            'plaster': lambda: self.mat('plaster_white', PLASTER, rough=0.92),
            'blush_plaster': lambda: self.mat('plaster_blush', '#f0d6cf', rough=0.95),
            'earth': lambda: self.mat('earth_plaster', '#c9a585', rough=0.97),
            'tile': lambda: self.mat_tile('tile_white', '#f3f0ea', '#ebe6de', '#c9c0b4', 2.2, 0.03, rough=0.18),
            'tile_wall': lambda: self.mat('tile_wall', '#eef0ec', rough=0.2),
            'pool_lining': lambda: self.mat('pool_lining', '#cdeeee', rough=0.25),
            'mosaic': lambda: self.mat_tile('mosaic_blue', '#1f4f7a', '#2b6a96', '#d9e6ea', 0.05, 0.08, rough=0.15),
            'pebble': lambda: self.mat_pebble(),
            'bronze': lambda: self.mat('bronze_frame', '#3a2f27', rough=0.35, metal=0.7),
            'pavers': lambda: self.mat_tile('pavers', '#e3dbcf', '#d6cdbf', '#b8ab9a', 0.42, 0.012, rough=0.85),
            'stone': lambda: self.mat('coping', STONE, rough=0.7),
            'stone_dark': lambda: self.mat('stone_dark', '#6e6862', rough=0.8),
            'blush': lambda: self.mat('blush', BLUSH, rough=0.95),
            'peach': lambda: self.mat('peach', PEACH, rough=0.95),
            'black_fabric': lambda: self.mat('black_fabric', BLACK, rough=0.95),
            'steel': lambda: self.mat('steel_galv', '#b4b8ba', rough=0.33, metal=0.9),
            'steel_dark': lambda: self.mat('steel_black', '#2a2b2d', rough=0.4, metal=0.7),
            'soil': lambda: self.mat('soil', '#4b3a2c', rough=1.0),
            'gravel': lambda: self.mat('gravel_light', '#d5c7b0', rough=1.0),
            'water': self.water_mat,
            'cold': lambda: self.water_mat('cold_water', '#c9eef0'),
            'glass': self.glass_mat,
            'paper': lambda: self.mat('hanji', '#fbf3e6', rough=0.9, emit='#ffd39b', emit_strength=self.paper_glow()),
            'lantern': lambda: self.mat('lantern', '#fff1dc', rough=0.8, emit='#ffc27a', emit_strength=self.lantern_strength()),
            'acrylic': lambda: self.mat('acrylic', '#f4f2ee', rough=0.15),
            'leaf': lambda: self.mat('leaf', LEAF, rough=0.55),
            'leaf_light': lambda: self.mat('leaf_light', '#5d8a3c', rough=0.55),
            'leaf_dark': lambda: self.mat('leaf_dark', '#2f5530', rough=0.5),
            'palm': lambda: self.mat('palm_leaf', '#5c7a3a', rough=0.6),
            'agave': lambda: self.mat('agave', '#8ea9a3', rough=0.5),
            'bract': lambda: self.mat('bougainvillea', '#d8357c', rough=0.7),
            'jasmine': lambda: self.mat('jasmine_flower', '#fbf8f2', rough=0.6),
            'bird_flower': lambda: self.mat('strelitzia_flower', '#f08a2a', rough=0.5),
            'trunk': lambda: self.mat_grain('palm_trunk', '#8b7259', '#6c5845', 'Z', 18.0, rough=0.95),
            'bamboo': lambda: self.mat_grain('bamboo_culm', '#7f9a44', '#617a30', 'Z', 2.2, rough=0.45),
        }[key]
        return f()

    def paper_glow(self):
        return 2.2 if self.night else 0.0

    def lantern_strength(self):
        return self.lantern_power if self.night else 0.6

    def mat_grain(self, name, c1, c2, axis, scale, rough=0.62):
        """Soft two-tone bands (timber grain, stave joints, tile courses)."""
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
        w.inputs['Distortion'].default_value = 1.2
        w.inputs['Detail'].default_value = 2.0
        tc = nt.nodes.new('ShaderNodeTexCoord')
        nt.links.new(tc.outputs['Object'], w.inputs['Vector'])
        r = nt.nodes.new('ShaderNodeValToRGB')
        r.color_ramp.elements[0].position = 0.25
        r.color_ramp.elements[0].color = K.srgb(c1)
        r.color_ramp.elements[1].position = 0.9
        r.color_ramp.elements[1].color = K.srgb(c2)
        nt.links.new(w.outputs['Fac'], r.inputs['Fac'])
        nt.links.new(r.outputs['Color'], p.inputs['Base Color'])
        p.inputs['Roughness'].default_value = rough
        self.mats[name] = m
        return m

    def mat_pebble(self):
        """Exposed-aggregate (pebble) deck, as at The Spring's pool house."""
        if 'pebble' in self.mats:
            return self.mats['pebble']
        m = bpy.data.materials.new('pebble')
        m.use_nodes = True
        nt = m.node_tree
        p = nt.nodes['Principled BSDF']
        v = nt.nodes.new('ShaderNodeTexVoronoi')
        v.inputs['Scale'].default_value = 60.0
        tc = nt.nodes.new('ShaderNodeTexCoord')
        nt.links.new(tc.outputs['Object'], v.inputs['Vector'])
        r = nt.nodes.new('ShaderNodeValToRGB')
        r.color_ramp.elements[0].color = K.srgb('#cbbfae')
        r.color_ramp.elements[1].position = 0.8
        r.color_ramp.elements[1].color = K.srgb('#ece5da')
        nt.links.new(v.outputs['Color'], r.inputs['Fac'])
        nt.links.new(r.outputs['Color'], p.inputs['Base Color'])
        b = nt.nodes.new('ShaderNodeBump')
        b.inputs['Strength'].default_value = 0.25
        nt.links.new(v.outputs['Distance'], b.inputs['Height'])
        nt.links.new(b.outputs['Normal'], p.inputs['Normal'])
        p.inputs['Roughness'].default_value = 0.8
        self.mats['pebble'] = m
        return m

    def mat_tile(self, name, c1, c2, line, scale, mortar, rough=0.5):
        if name in self.mats:
            return self.mats[name]
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        p = nt.nodes['Principled BSDF']
        b = nt.nodes.new('ShaderNodeTexBrick')
        b.offset = 0.5
        b.inputs['Color1'].default_value = K.srgb(c1)
        b.inputs['Color2'].default_value = K.srgb(c2)
        b.inputs['Mortar'].default_value = K.srgb(line)
        b.inputs['Scale'].default_value = 1.0
        b.inputs['Mortar Size'].default_value = mortar
        b.inputs['Brick Width'].default_value = scale * 1.5
        b.inputs['Row Height'].default_value = scale
        tc = nt.nodes.new('ShaderNodeTexCoord')
        nt.links.new(tc.outputs['Object'], b.inputs['Vector'])
        nt.links.new(b.outputs['Color'], p.inputs['Base Color'])
        p.inputs['Roughness'].default_value = rough
        self.mats[name] = m
        return m

    def water_mat(self, name='spa_water', tint='#cdeeea'):
        if name in self.mats:
            return self.mats[name]
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        N, L = nt.nodes, nt.links
        for n in list(N):
            if n.type != 'OUTPUT_MATERIAL':
                N.remove(n)
        out = next(n for n in N if n.type == 'OUTPUT_MATERIAL')
        tr = N.new('ShaderNodeBsdfTransparent')
        tr.inputs['Color'].default_value = K.srgb(tint)
        gl = N.new('ShaderNodeBsdfGlossy')
        gl.inputs['Roughness'].default_value = 0.02
        fr = N.new('ShaderNodeFresnel')
        fr.inputs['IOR'].default_value = 1.33
        noise = N.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 7.0
        noise.inputs['Detail'].default_value = 3.0
        bump = N.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = 0.08
        L.new(noise.outputs['Fac'], bump.inputs['Height'])
        L.new(bump.outputs['Normal'], gl.inputs['Normal'])
        L.new(bump.outputs['Normal'], fr.inputs['Normal'])
        mul = N.new('ShaderNodeMath')
        mul.operation = 'MULTIPLY'
        mul.inputs[1].default_value = 0.55
        L.new(fr.outputs['Fac'], mul.inputs[0])
        mix = N.new('ShaderNodeMixShader')
        L.new(mul.outputs[0], mix.inputs['Fac'])
        L.new(tr.outputs['BSDF'], mix.inputs[1])
        L.new(gl.outputs['BSDF'], mix.inputs[2])
        L.new(mix.outputs['Shader'], out.inputs['Surface'])
        self.mats[name] = m
        return m

    def glass_mat(self):
        if 'glass_thin' in self.mats:
            return self.mats['glass_thin']
        m = bpy.data.materials.new('glass_thin')
        m.use_nodes = True
        nt = m.node_tree
        N, L = nt.nodes, nt.links
        for n in list(N):
            if n.type != 'OUTPUT_MATERIAL':
                N.remove(n)
        out = next(n for n in N if n.type == 'OUTPUT_MATERIAL')
        tr = N.new('ShaderNodeBsdfTransparent')
        tr.inputs['Color'].default_value = K.srgb('#eef5f4')
        gl = N.new('ShaderNodeBsdfGlossy')
        gl.inputs['Roughness'].default_value = 0.0
        fr = N.new('ShaderNodeFresnel')
        fr.inputs['IOR'].default_value = 1.5
        mix = N.new('ShaderNodeMixShader')
        L.new(fr.outputs['Fac'], mix.inputs['Fac'])
        L.new(tr.outputs['BSDF'], mix.inputs[1])
        L.new(gl.outputs['BSDF'], mix.inputs[2])
        L.new(mix.outputs['Shader'], out.inputs['Surface'])
        self.mats['glass_thin'] = m
        return m

    # ================================================================ geometry helpers
    def mesh_from(self, name, verts, faces, mat, coll, smooth=False, parent=None):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
        me.update()
        if smooth:
            me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
        if isinstance(mat, (list, tuple)):
            for mm in mat:
                me.materials.append(mm)
        else:
            me.materials.append(mat)
        ob = bpy.data.objects.new(name, me)
        if parent:
            ob.parent = parent
        return self.link(ob, coll)

    def lathe(self, name, prof, loc, mat, coll, seg=64, parent=None, scale=(1, 1, 1), round_r=0.012):
        """Surface of revolution about local Z from a (r, z) profile; corners get a tiny round-over."""
        pts = [prof[0]]
        for i in range(1, len(prof) - 1):
            a, b, c = Vector(prof[i - 1]), Vector(prof[i]), Vector(prof[i + 1])
            d1, d2 = (a - b), (c - b)
            if d1.length > 2.5 * round_r and d2.length > 2.5 * round_r:
                pts.append(tuple(b + d1.normalized() * round_r))
                pts.append(tuple(b + d2.normalized() * round_r))
            else:
                pts.append(tuple(b))
        pts.append(prof[-1])
        n = len(pts)
        verts, faces = [], []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            for (r, z) in pts:
                verts.append((max(r, 0.0005) * math.cos(a), max(r, 0.0005) * math.sin(a), z))
        for k in range(seg):
            k2 = (k + 1) % seg
            for i in range(n - 1):
                faces.append((k * n + i, k2 * n + i, k2 * n + i + 1, k * n + i + 1))
        ob = self.mesh_from(name, verts, faces, mat, coll, smooth=True, parent=parent)
        ob.location = loc
        ob.scale = scale
        return ob

    def slab(self, name, pts2d, z0, z1, mat, coll, parent=None):
        """Extruded polygon (prism) between z0 and z1."""
        n = len(pts2d)
        verts = [(x, y, z0) for (x, y) in pts2d] + [(x, y, z1) for (x, y) in pts2d]
        faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
        for i in range(n):
            j = (i + 1) % n
            faces.append((i, j, n + j, n + i))
        return self.mesh_from(name, verts, faces, mat, coll, parent=parent)

    def beam(self, name, p1, p2, size, mat, coll, parent=None):
        """Box from p1 to p2 with cross-section size=(w, h)."""
        p1, p2 = Vector(p1), Vector(p2)
        d = p2 - p1
        ob = self.box(name, (size[0], size[1], d.length), (p1 + p2) / 2, mat, coll, parent=parent)
        ob.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
        return ob

    def wbox(self, name, size, loc, mat, coll, rot=0.0, **kw):
        """Box in local spa coords with a plan rotation in degrees."""
        return self.box(name, size, loc, mat, coll, rot=(0, 0, math.radians(rot)), **kw)

    # ================================================================ ground
    def ground(self, R=34.0, step=0.3):
        """Detailed terrain around the spa, outer horizon, native scatter and the Joshua trees."""
        self.build_terrain(x0=-R, x1=R, y0=-R, y1=R, step=step)
        self.build_surfaces()
        rnd = random.Random(5)
        fp = self.footprints

        def free(x, y, extra=0.0):
            for (cx, cy, rx, ry, ph) in fp:
                if ((x - cx) / (rx + extra)) ** 2 + ((y - cy) / (ry + extra)) ** 2 < 1.0:
                    return False
            return True
        for gx in np.arange(-R + 1, R - 1, 2.6):
            for gy in np.arange(-R + 1, R - 1, 2.6):
                x, y = gx + rnd.uniform(-1.1, 1.1), gy + rnd.uniform(-1.1, 1.1)
                if rnd.random() < 0.45 or not free(x, y):
                    continue
                near = max(abs(x), abs(y)) < 22
                r = rnd.random()
                if near:
                    self.bush(x, y, rnd.uniform(0.8, 1.6) if r < 0.65 else rnd.uniform(0.5, 0.9),
                              kind='creosote' if r < 0.65 else ('bursage' if r < 0.9 else 'brittle'))
                elif r < 0.72:
                    self.shrub(x, y, rnd.uniform(0.7, 1.7), kind='creosote')
                else:
                    self.shrub(x, y, rnd.uniform(0.45, 0.9), kind='bursage')
        # sparse shrubs on the coarse ground beyond, sunk to its level
        for k in range(900):
            a = rnd.uniform(0, 2 * math.pi)
            d = rnd.uniform(R + 2, 240)
            x, y = d * math.cos(a), d * math.sin(a)
            if abs(y - K.ROAD_Y) < 7:
                continue
            ob = self.shrub(x, y, rnd.uniform(0.8, 1.9), kind='creosote' if rnd.random() < 0.8 else 'bursage')
            ob.location.z -= 0.35
        for (x, y, h) in K.JOSHUA_TREES:
            ob = self.joshua_tree(x, y, h)
            if max(abs(x), abs(y)) > R:
                ob.location.z -= 0.35
        for k in range(70):
            a = rnd.uniform(0, 2 * math.pi)
            d = rnd.uniform(95, 400)
            x, y = d * math.cos(a), d * math.sin(a)
            lx, ly = x + SX, y + SY
            if -25 <= lx <= K.LOT_W + 25 and -25 <= ly <= K.LOT_D + 25:
                continue
            if abs(y - K.ROAD_Y) < 9:
                continue
            ob = self.joshua_tree(x, y, rnd.uniform(2.6, 6.0))
            ob.location.z -= 0.35
        for (bx, by, r, n) in K.BOULDERS:
            for k in range(n):
                a = rnd.uniform(0, 2 * math.pi)
                d = rnd.uniform(0, r)
                x, y = bx + d * math.cos(a), by + d * math.sin(a)
                ob = self.boulder(x, y, rnd.uniform(1.2, 3.4))
                if max(abs(x), abs(y)) > R:
                    ob.location.z -= 0.35

    def bush(self, x, y, s=1.0, kind='creosote', coll='veg', z=None):
        """Twiggy desert shrub made of leaf cards (reads better than a blob up close)."""
        z = self.t.h(x, y) if z is None else z
        rnd = random.Random(int(abs(x * 97 + y * 13)))
        cols = {'creosote': ('creosote_card', '#5f6a33'), 'bursage': ('bursage_card', '#a19c7f'),
                'brittle': ('brittlebush_card', '#a9b39a')}
        name, col = cols[kind]
        lv = Leaves()
        rx, rz = s * 0.55, s * (0.55 if kind == 'creosote' else 0.35)
        n = int(260 * s * s) if kind == 'creosote' else int(200 * s * s)
        for k in range(n):
            while True:
                u, v, w = rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)
                if u * u + v * v + w * w < 1:
                    break
            c = (x + u * rx, y + v * rx, z + rz + w * rz)
            lv.card(c, (rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.2, 1)), 0.045 * (1 + 0.3 * s), rnd.uniform(0, 6.28))
        if kind == 'creosote':
            st = Leaves()
            for k in range(7):
                a = rnd.uniform(0, 6.28)
                st.strip((x, y, z), a, rz * 2.0, 0.025, lift=rnd.uniform(1.5, 4.0), droop=0.1, n=3)
            st.build(self, 'twigs', self.mat('twig', '#4a3e33', rough=0.95), coll)
        ob = lv.build(self, 'bush', self.mat(name, col, rough=0.85), coll, smooth=False)
        if kind == 'brittle':
            fl = Leaves()
            for k in range(int(20 * s)):
                a = rnd.uniform(0, 6.28)
                rr = rx * rnd.uniform(0.3, 0.9)
                fl.card((x + rr * math.cos(a), y + rr * math.sin(a), z + 2 * rz + rnd.uniform(0.0, 0.15)), (0, 0, 1), 0.04, a)
            fl.build(self, 'brittle_flowers', self.mat('brittle_flower', '#f2c230', rough=0.6), coll, smooth=False)
        return ob

    def outline(self, pts, z, coll='plan_only', dash=0.5, w=0.07, color='#2d2a28'):
        """Dashed outline drawn only in plan views (e.g. a roof that the plan lifts off)."""
        m = self.mat('outline_' + color, color, rough=0.9)
        n = len(pts)
        for i in range(n):
            a, b = Vector((*pts[i], z)), Vector((*pts[(i + 1) % n], z))
            L = (b - a).length
            k = max(1, int(L / (2 * dash)))
            for j in range(k):
                t0, t1 = j / k, (j + 0.5) / k
                self.beam('dash', a.lerp(b, t0), a.lerp(b, t1), (w, 0.02), m, coll)

    def keep_clear(self, p1, p2, width=4.0, step=1.5):
        """Keep desert scatter out of a corridor (e.g. from a camera to its subject)."""
        for (x, y) in K.densify([p1[:2], p2[:2]], step):
            self.footprints.append((float(x), float(y), width / 2, width / 2, 99))

    def terrace(self, w, l, x=0.0, y=0.0, rot=0.0, mat='pavers', pad_extra=5.0):
        """Level the ground and lay a stone terrace. Sets self.e (pad) and self.z (finished floor)."""
        self.e = self.pad(x, y, w + pad_extra, l + pad_extra, rot, coll='spa', surface=None)
        self.z = self.e + 0.2
        self.terrace_obj = self.wbox('terrace', (w, l, 0.24), (x, y, self.e + 0.08), self.m(mat), 'spa', rot=rot)
        self.foot(x, y, w / 2 + 2.5, l / 2 + 2.5)
        return self.z

    def gravel_pad(self, w, l, x=0.0, y=0.0, rot=0.0):
        self.wbox('gravel', (w, l, 0.1), (x, y, self.e + 0.02), self.m('gravel'), 'spa', rot=rot)
        self.foot(x, y, w / 2 + 1.0, l / 2 + 1.0)

    def deck(self, w, l, x, y, rot=0.0, h=0.18):
        root = self.empty('deck', x, y, self.z - 0.02, rot, 'spa')
        n = int(w / 0.15)
        for i in range(n):
            self.box('deckboard', (0.135, l, 0.04), (-w / 2 + (i + 0.5) * w / n, 0, h - 0.02), self.m('cedar_y'), 'spa', parent=root)
        self.box('deckframe', (w, l, h - 0.04), (0, 0, (h - 0.04) / 2), self.m('timber'), 'spa', parent=root)
        return self.z - 0.02 + h

    def path_stones(self, pts, size=0.62, step=0.82, coll='spa'):
        dense = K.densify(pts, step)
        mat = self.mat('step_stone', '#d8cfc2', rough=0.85)
        for k, (px, py) in enumerate(dense):
            zz = max(self.t.h(px, py), self.e if abs(px) < 12 and abs(py) < 12 else -99)
            self.box('stone', (size, size * 0.78, 0.07), (px, py, zz + 0.04), mat, coll,
                     rot=(0, 0, k * 0.73), bevel=0.04, seg=2)
            self.foot(px, py, 0.7)

    # ================================================================ structures
    def lattice(self, name, w, h, loc, rot_z, coll, pattern='grid', cell=0.12, bar=0.024, depth=0.045,
                frame=0.075, mat=None, parent=None):
        """Korean changsal lattice panel in its local XZ plane (one mesh)."""
        bm = bmesh.new()

        def bx(cx, cz, sx, sz, sy=depth):
            g = bmesh.ops.create_cube(bm, size=1.0)
            bmesh.ops.scale(bm, vec=Vector((sx, sy, sz)), verts=g['verts'])
            bmesh.ops.translate(bm, vec=Vector((cx, 0, cz)), verts=g['verts'])

        fd = depth * 1.5
        bx(0, h / 2 - frame / 2, w, frame, fd)
        bx(0, -h / 2 + frame / 2, w, frame, fd)
        bx(-w / 2 + frame / 2, 0, frame, h - 2 * frame, fd)
        bx(w / 2 - frame / 2, 0, frame, h - 2 * frame, fd)
        iw, ih = w - 2 * frame, h - 2 * frame
        nx = max(2, int(round(iw / cell)))
        nz = max(2, int(round(ih / cell)))
        if pattern in ('grid', 'a'):                   # jeongjasal: even square grid
            for i in range(1, nx):
                bx(-iw / 2 + i * iw / nx, 0, bar, ih)
            for k in range(1, nz):
                bx(0, -ih / 2 + k * ih / nz, iw, bar)
        if pattern == 'a':                              # stepped key-fret motif (a-jasal) over the grid
            for (sx, sz) in ((0.78, 0.84), (0.5, 0.56)):
                fw, fh = iw * sx, ih * sz
                for zz in (fh / 2, -fh / 2):
                    bx(0, zz, fw, bar * 2.4)
                for xx in (fw / 2, -fw / 2):
                    bx(xx, 0, bar * 2.4, fh)
            bx(0, 0, iw, bar * 2.4)
            bx(0, 0, bar * 2.4, ih)
        elif pattern == 'tti':                          # ttisal: verticals with banded rails
            for i in range(1, nx):
                bx(-iw / 2 + i * iw / nx, 0, bar, ih)
            for zc in (-0.36, -0.33, -0.01, 0.01, 0.33, 0.36):
                bx(0, zc * ih, iw, bar)
        elif pattern == 'yong':                         # 用-like rails for low railings / friezes
            for i in range(1, nx):
                bx(-iw / 2 + i * iw / nx, 0, bar, ih)
            bx(0, 0, iw, bar * 1.6)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mat or self.m('coral'))
        ob = bpy.data.objects.new(name, me)
        ob.location = loc
        ob.rotation_euler = (0, 0, rot_z)
        if parent:
            ob.parent = parent
        return self.link(ob, coll)

    def bay(self, p1, p2, z, h, kind='screen', pattern='grid', back=None, coll='pavilion', post=0.2, frieze=False):
        """Fill the opening between two posts. kind: screen | half | frieze. back: None | glass | paper."""
        (x1, y1), (x2, y2) = p1, p2
        span = math.hypot(x2 - x1, y2 - y1)
        L = span - post - 0.04
        ang = math.atan2(y2 - y1, x2 - x1)
        cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
        nx, ny = -math.sin(ang), math.cos(ang)
        if kind in ('screen', 'half'):
            n = max(1, int(round(L / 1.15)))
            pw = L / n
            ph = h - 0.12 if kind == 'screen' else 1.0
            for i in range(n):
                t = -L / 2 + pw * (i + 0.5)
                px, py = cx + math.cos(ang) * t, cy + math.sin(ang) * t
                self.lattice('changsal', pw - 0.015, ph, (px, py, z + 0.06 + ph / 2), ang, coll, pattern=pattern)
                if back:
                    mat = self.m('glass') if back == 'glass' else self.m('paper')
                    self.box('back_' + back, (pw - 0.06, 0.008, ph - 0.1),
                             (px + nx * 0.035, py + ny * 0.035, z + 0.06 + ph / 2), mat, coll, rot=(0, 0, ang))
        if frieze or kind == 'frieze':
            fh = 0.34
            self.lattice('frieze', L, fh, (cx, cy, z + h - fh / 2 - 0.02), ang, coll, pattern='grid', cell=0.085, bar=0.02, frame=0.05)

    def hip_roof(self, name, w, l, z0, rise, overhang, coll, upturn=0.0, n=56, thickness=0.16, mat=None, ridge=True, cx=0.0, cy=0.0):
        """Hip roof over a w (x) by l (y) rectangle as a height field; concave slopes and optional
        hanok-style corner upturn. Ridge runs along the longer side."""
        W, L = w / 2 + overhang, l / 2 + overhang
        mn = min(W, L)
        xs = np.linspace(-W, W, n)
        ys = np.linspace(-L, L, n)
        verts, faces = [], []
        for yy in ys:
            for xx in xs:
                dx, dy = W - abs(xx), L - abs(yy)
                sl = min(dx, dy) / mn
                zz = z0 + rise * (sl ** 1.45 if upturn else sl)
                if upturn:
                    corner = ((abs(xx) / W) * (abs(yy) / L)) ** 3
                    zz += upturn * corner * (1 - sl) ** 0.7
                verts.append((cx + xx, cy + yy, zz))
        for j in range(n - 1):
            for i in range(n - 1):
                a = j * n + i
                faces.append((a, a + 1, a + n + 1, a + n))
        ob = self.mesh_from(name, verts, faces, mat or self.m('roof'), coll, smooth=True)
        sol = ob.modifiers.new('solid', 'SOLIDIFY')
        sol.thickness = thickness
        sol.offset = -1
        if ridge and abs(W - L) > 0.05:
            if L > W:
                self.box('ridge', (0.26, 2 * (L - W) + 0.5, 0.26), (cx, cy, z0 + rise + 0.08), self.m('roof_flat'), coll)
            else:
                self.box('ridge', (2 * (W - L) + 0.5, 0.26, 0.26), (cx, cy, z0 + rise + 0.08), self.m('roof_flat'), coll)
        return ob

    def rect_pavilion(self, label, w, l, h=2.8, nx=3, ny=3, post=0.2, rise=1.5, overhang=1.0, upturn=0.0,
                      roof='hip', floor_z=None, coll='pavilion', anchor_cat=0, cx=0.0, cy=0.0, plinths=True,
                      post_mat='timber', joists=True, slope=0.06):
        """Timber post-and-beam pavilion centred on (cx, cy). roof: hip | pergola | flat | shed.
        Returns the post ring (counter-clockwise from the south-west corner) and key heights."""
        z = self.z if floor_z is None else floor_z
        tim = self.m(post_mat)
        xs = np.linspace(-w / 2, w / 2, nx) + cx
        ys = np.linspace(-l / 2, l / 2, ny) + cy
        x0, x1, y0, y1 = cx - w / 2, cx + w / 2, cy - l / 2, cy + l / 2
        ring = [(float(x), y0) for x in xs] + [(x1, float(y)) for y in ys[1:]] + \
               [(float(x), y1) for x in xs[::-1][1:]] + [(x0, float(y)) for y in ys[::-1][1:-1]]
        for (px, py) in ring:
            self.box('post', (post, post, h), (px, py, z + h / 2), tim, coll)
            if plinths:
                self.box('plinth_stone', (post + 0.14, post + 0.14, 0.18), (px, py, z + 0.09), self.m('stone'), coll)
        bh = 0.3
        for yy in (y0, y1):
            self.box('beam', (w + 0.5, post + 0.04, bh), (cx, yy, z + h + bh / 2), tim, coll)
        for xx in (x0, x1):
            self.box('beam', (post + 0.04, l + 0.5, bh), (xx, cy, z + h + bh / 2), tim, coll)
        top = z + h + bh
        if joists and roof != 'pergola':
            k = max(2, int(w / 0.6))
            for i in range(k + 1):
                xx = x0 + i * w / k
                self.box('joist', (0.07, l + 0.3, 0.16), (xx, cy, top + 0.08), self.m('cedar_plain'), 'roof')
        if roof == 'hip':
            self.hip_roof('roof', w, l, top + 0.18, rise, overhang, 'roof', upturn=upturn, cx=cx, cy=cy)
        elif roof == 'pergola':
            for i in range(int((w + 1.0) / 0.9) + 1):
                xx = x0 - 0.5 + i * 0.9
                self.box('rafter', (0.09, l + 1.2, 0.24), (xx, cy, top + 0.12), self.m(post_mat), 'roof')
            for i in range(int((l + 1.2) / 0.3)):
                yy = y0 - 0.6 + i * 0.3
                self.box('lath', (w + 1.4, 0.05, 0.08), (cx, yy, top + 0.28), self.m('cedar_plain'), 'roof')
        elif roof == 'flat':
            self.box('roof', (w + 2 * overhang, l + 2 * overhang, 0.22), (cx, cy, top + 0.27), self.m('roof_flat'), 'roof')
        elif roof == 'shed':
            # low-slope roof (falls to the north) with exposed rafter tails, as at The Spring's pool house
            pitch = math.atan(slope)
            Lr = l + 2 * overhang
            self.box('roof', (w + 2 * overhang, Lr / math.cos(pitch), 0.12), (cx, cy, top + 0.3), self.m('roof_flat'), 'roof',
                     rot=(pitch, 0, 0))
            self.box('fascia', (w + 2 * overhang + 0.04, 0.05, 0.22), (cx, cy - Lr / 2, top + 0.3 - Lr / 2 * slope - 0.02), self.m('steel_dark'), 'roof')
            k = int((w + 2 * overhang) / 0.6)
            for i in range(k + 1):
                xx = cx - w / 2 - overhang + i * (w + 2 * overhang) / k
                self.box('rafter_tail', (0.07, Lr - 0.1, 0.16), (xx, cy, top + 0.17), self.m('cedar_plain'), 'roof', rot=(pitch, 0, 0))
        self.anchor(label, cx, y0, z, anchor_cat, dz=h)
        return {'z': z, 'h': h, 'top': top, 'ring': ring, 'xs': xs, 'ys': ys, 'box': (x0, x1, y0, y1)}

    def oct_shell(self, name, R, r_top, z0, z1, mat, coll, thickness=0.12):
        """Open octagonal roof cone (no ceiling), edges parallel to the beams, solidified downward."""
        verts = []
        for k in range(8):
            a = math.pi / 8 + k * math.pi / 4
            verts.append((R * math.cos(a), R * math.sin(a), z0))
        for k in range(8):
            a = math.pi / 8 + k * math.pi / 4
            verts.append((r_top * math.cos(a), r_top * math.sin(a), z1))
        faces = [(k, (k + 1) % 8, 8 + (k + 1) % 8, 8 + k) for k in range(8)] + [tuple(range(8, 16))]
        ob = self.mesh_from(name, verts, faces, mat, coll)
        sol = ob.modifiers.new('solid', 'SOLIDIFY')
        sol.thickness = thickness
        sol.offset = -1
        return ob

    def oct_pavilion(self, label, r, h=2.9, rise=2.0, overhang=0.85, coll='pavilion', anchor_cat=0):
        z = self.z
        tim = self.m('timber')
        pts = [(r * math.cos(math.pi / 8 + k * math.pi / 4), r * math.sin(math.pi / 8 + k * math.pi / 4)) for k in range(8)]
        for (px, py) in pts:
            self.box('post', (0.2, 0.2, h), (px, py, z + h / 2), tim, coll)
            self.box('plinth_stone', (0.34, 0.34, 0.18), (px, py, z + 0.09), self.m('stone'), coll)
        for k in range(8):
            (x1, y1), (x2, y2) = pts[k], pts[(k + 1) % 8]
            L = math.hypot(x2 - x1, y2 - y1)
            self.box('beam', (L + 0.22, 0.22, 0.3), ((x1 + x2) / 2, (y1 + y2) / 2, z + h + 0.15), tim, coll,
                     rot=(0, 0, math.atan2(y2 - y1, x2 - x1)))
        top = z + h + 0.3
        R = r + overhang / math.cos(math.pi / 8)
        rt = 0.55
        self.oct_shell('roof', R, rt, top, top + rise, self.m('roof'), 'roof')
        # cupola (vents steam) and finial
        self.cyl('cupola', 0.6, 0.55, (0, 0, top + rise + 0.27), self.m('timber'), 'roof', seg=8, rot=(0, 0, math.pi / 8))
        self.oct_shell('cupola_roof', 0.95, 0.06, top + rise + 0.55, top + rise + 1.0, self.m('roof'), 'roof')
        self.cyl('finial', 0.05, 0.5, (0, 0, top + rise + 1.2), self.m('coral'), 'roof', seg=8)
        # radial rafters following the underside of the roof
        def zr(rho):
            return top + rise * (R - rho) / (R - rt) - 0.2
        for (px, py) in pts:
            u = Vector((px, py, 0)).normalized()
            r1, r2 = r * 1.04, rt + 0.1
            self.beam('rafter', (u.x * r1, u.y * r1, zr(r1)), (u.x * r2, u.y * r2, zr(r2)), (0.09, 0.16), self.m('cedar_plain'), 'roof')
        self.cyl('ring_beam', rt + 0.15, 0.2, (0, 0, zr(rt + 0.1)), self.m('timber'), 'roof', seg=8, rot=(0, 0, math.pi / 8))
        self.anchor(label, 0, -r, z, anchor_cat, dz=h)
        return {'z': z, 'h': h, 'top': top, 'ring': pts}

    def hanok_plinth(self, w, l, hgt, x=0.0, y=0.0, hole=None, steps=None):
        """Raised stone platform (gidan) with an optional rectangular hole for a sunken tub.
        hole = (cx, cy, hw, hl). steps = list of (x, y, rot) for 3-step stairs on an edge."""
        z0, z1 = self.z, self.z + hgt
        mat = self.mat_tile('plinth_stone', '#ddd5c9', '#d2c9bb', '#b3a796', 0.32, 0.01, rough=0.8)
        if not hole:
            self.box('gidan', (w, l, hgt), (x, y, (z0 + z1) / 2), mat, 'spa')
        else:
            cx, cy, hw, hl = hole
            x0, x1, y0, y1 = x - w / 2, x + w / 2, y - l / 2, y + l / 2
            hx0, hx1, hy0, hy1 = cx - hw / 2, cx + hw / 2, cy - hl / 2, cy + hl / 2
            for (ax, bx_, ay, by) in ((x0, hx0, y0, y1), (hx1, x1, y0, y1), (hx0, hx1, y0, hy0), (hx0, hx1, hy1, y1)):
                if bx_ - ax > 0.01 and by - ay > 0.01:
                    self.box('gidan', (bx_ - ax, by - ay, hgt), ((ax + bx_) / 2, (ay + by) / 2, (z0 + z1) / 2), mat, 'spa')
        if not hole:
            self.box('gidan_cap', (w + 0.08, l + 0.08, 0.06), (x, y, z1 - 0.03), self.m('stone'), 'spa')
        for (sx, sy, rot) in (steps or []):
            n = 3
            for i in range(n):
                th = hgt / n
                d = 0.34
                root = self.empty('steps', sx, sy, z0, rot, 'spa')
                self.box('step', (1.6, d * (n - i), th), (0, -d * (n - i) / 2, th * (i + 0.5)), mat, 'spa', parent=root)
        return z1

    def hanok_floor(self, w, l, z, x=0.0, y=0.0, hole=None):
        """Wood floor boards (maru) at height z, optionally leaving a hole for the tub."""
        mat = self.mat_grain('maru', '#c69a6c', '#b58757', 'Y', 4.0, rough=0.5)
        # boards sit 4 cm proud of the stone (flush faces render black in Cycles)
        if not hole:
            self.box('maru_floor', (w, l, 0.04), (x, y, z + 0.02), mat, 'spa')
            return
        cx, cy, hw, hl = hole
        x0, x1, y0, y1 = x - w / 2, x + w / 2, y - l / 2, y + l / 2
        hx0, hx1, hy0, hy1 = cx - hw / 2, cx + hw / 2, cy - hl / 2, cy + hl / 2
        for (ax, bx_, ay, by) in ((x0, hx0, y0, y1), (hx1, x1, y0, y1), (hx0, hx1, y0, hy0), (hx0, hx1, hy1, y1)):
            if bx_ - ax > 0.01 and by - ay > 0.01:
                self.box('maru_floor', (bx_ - ax, by - ay, 0.04), ((ax + bx_) / 2, (ay + by) / 2, z + 0.02), mat, 'spa')

    def wall(self, p1, p2, h, t=0.3, mat=None, cap=True, openings=(), coll='spa'):
        """Plaster garden wall from p1 to p2 with tile cap. openings: list of (t0, t1, sill, head) along the wall."""
        (x1, y1), (x2, y2) = p1, p2
        L = math.hypot(x2 - x1, y2 - y1)
        ang = math.atan2(y2 - y1, x2 - x1)
        mat = mat or self.m('blush_plaster')
        root = self.empty('wall', x1, y1, self.z, math.degrees(ang), coll)
        cuts = sorted(openings)
        pos = 0.0
        for (a, b, sill, head) in cuts + [(L, L, 0, 0)]:
            if a - pos > 0.01:
                self.box('wall', (a - pos, t, h), ((pos + a) / 2, 0, h / 2), mat, coll, parent=root)
            if b > a:
                if sill > 0:
                    self.box('wall_sill', (b - a, t, sill), ((a + b) / 2, 0, sill / 2), mat, coll, parent=root)
                if head < h:
                    self.box('wall_head', (b - a, t, h - head), ((a + b) / 2, 0, (head + h) / 2), mat, coll, parent=root)
            pos = b
        if cap:
            self.box('wall_cap', (L + 0.3, t + 0.34, 0.12), (L / 2, 0, h + 0.06), self.m('roof_flat'), coll, parent=root)
            self.box('wall_cap2', (L + 0.1, t + 0.1, 0.12), (L / 2, 0, h + 0.17), self.m('roof_flat'), coll, parent=root)
        return root, L, ang


    # ================================================================ pool house (The Spring)
    @staticmethod
    def stadium(w, l, r=None, n=10, cx=0.0, cy=0.0):
        """Rounded-rectangle outline (counter-clockwise)."""
        r = min(w, l) / 2 * 0.9 if r is None else r
        pts = []
        for (ox, oy, a0) in ((w / 2 - r, -l / 2 + r, -90), (w / 2 - r, l / 2 - r, 0), (-w / 2 + r, l / 2 - r, 90), (-w / 2 + r, -l / 2 + r, 180)):
            for i in range(n + 1):
                a = math.radians(a0 + 90 * i / n)
                pts.append((cx + ox + r * math.cos(a), cy + oy + r * math.sin(a)))
        return pts

    @staticmethod
    def offset(pts, d):
        """Offset a convex counter-clockwise outline outward by d."""
        out = []
        n = len(pts)
        for i in range(n):
            p0, p1, p2 = Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % n])
            e1 = (p1 - p0).normalized() if (p1 - p0).length > 1e-6 else (p2 - p1).normalized()
            e2 = (p2 - p1).normalized() if (p2 - p1).length > 1e-6 else e1
            n1 = Vector((e1.y, -e1.x))
            n2 = Vector((e2.y, -e2.x))
            nn = (n1 + n2).normalized()
            out.append(tuple(p1 + nn * d / max(0.3, nn.dot(n1))))
        return out

    def ring_slab(self, name, inner, outer, z0, z1, mat, coll):
        n = len(inner)
        verts = [(x, y, z1) for (x, y) in inner] + [(x, y, z1) for (x, y) in outer] + \
                [(x, y, z0) for (x, y) in inner] + [(x, y, z0) for (x, y) in outer]
        faces = []
        for i in range(n):
            j = (i + 1) % n
            faces.append((i, n + i, n + j, j))                       # top
            faces.append((n + i, 3 * n + i, 3 * n + j, n + j))       # outer side
            faces.append((2 * n + j, 2 * n + i, i, j))               # inner side
        return self.mesh_from(name, verts, faces, mat, coll)

    def cut(self, target, cutter):
        mod = target.modifiers.new('cut', 'BOOLEAN')
        mod.operation = 'DIFFERENCE'
        mod.solver = 'EXACT'
        mod.object = cutter
        cutter.hide_render = True
        cutter.hide_viewport = True

    def sunk_pool(self, label, outline, depth=0.95, z_top=None, coping=0.3, targets=(), band=0.15, steps_at=None,
                  lining='pool_lining', band_mat='mosaic', coping_mat='stone'):
        """In-ground tiled pool/spa: blue mosaic band at the waterline, pale lining, stone coping.
        Cuts the terrace (and any `targets`) and dips the terrain under it."""
        zt = self.z if z_top is None else z_top
        zb = zt - depth
        xs = [p[0] for p in outline]
        ys = [p[1] for p in outline]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        self.t.add_pad(cx, cy, max(xs) - min(xs) + 0.6, max(ys) - min(ys) + 0.6, 0.0, zb - 0.5, slope=0.05, phase=1)
        cutter = self.slab('pool_cutter', self.offset(outline, 0.01), zb - 0.6, zt + 0.5, self.m('stone'), 'cutters')
        for t in list(targets) + ([self.terrace_obj] if getattr(self, 'terrace_obj', None) is not None else []):
            self.cut(t, cutter)
        n = len(outline)
        # walls: mosaic band on top, lining below
        for (z0, z1, mat) in ((zt - band, zt, self.m(band_mat)), (zb, zt - band, self.m(lining))):
            verts = [(x, y, z1) for (x, y) in outline] + [(x, y, z0) for (x, y) in outline]
            faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
            self.mesh_from('pool_wall', verts, faces, mat, 'spa')
        self.mesh_from('pool_floor', [(x, y, zb) for (x, y) in outline], [tuple(range(n))], self.m(lining), 'spa')
        self.ring_slab('coping', self.offset(outline, -0.02), self.offset(outline, coping), zt - 0.02, zt + 0.05, self.m(coping_mat), 'spa')
        self.mesh_from('water', [(x, y, zt - 0.12) for (x, y) in self.offset(outline, -0.005)], [tuple(range(n))], self.m('water'), 'spa')
        if steps_at:
            sx, sy, rot = steps_at
            root = self.empty('pool_steps', sx, sy, zb, rot, 'spa')
            for i in range(3):
                hh = depth * (i + 1) / 4
                self.box('pool_step', (1.0, 0.36 * (3 - i), hh), (0, 0.18 * (3 - i), hh / 2), self.m(lining), 'spa', parent=root)
        self.anchor(label, cx, cy, zt, 1, dz=0.3)
        return zb

    def glass_bay(self, p1, p2, z, h, knee=0.9, slat=0.32, band=True, door=None, coll='pavilion', post=0.2,
                  knee_mat='blush_plaster', slat_mat='timber'):
        """One bay of The Spring-style pool-house wall: solid knee wall, glass, a coral lattice band at eye
        level (in place of the frosted privacy stripe), and an open band of vertical slats under the header.
        door='slide' leaves the bay as an open sliding door (glass panel parked to one side)."""
        (x1, y1), (x2, y2) = p1, p2
        span = math.hypot(x2 - x1, y2 - y1)
        L = span - post
        ang = math.atan2(y2 - y1, x2 - x1)
        cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
        ux, uy = math.cos(ang), math.sin(ang)
        nx, ny = -uy, ux
        top_glass = h - slat
        if door != 'slide':
            self.box('knee_wall', (L, 0.16, knee), (cx, cy, z + knee / 2), self.m(knee_mat), coll, rot=(0, 0, ang))
            self.box('sill', (L + 0.02, 0.22, 0.04), (cx, cy, z + knee + 0.02), self.m('timber'), coll, rot=(0, 0, ang))
            self.box('glass', (L - 0.02, 0.01, top_glass - knee - 0.04), (cx, cy, z + (knee + 0.04 + top_glass) / 2), self.m('glass'), coll, rot=(0, 0, ang))
            if band:
                self.lattice('glass_band', L - 0.02, 0.36, (cx - nx * 0.04, cy - ny * 0.04, z + 1.62), ang, coll, pattern='grid', cell=0.09, bar=0.02, frame=0.04)
        else:
            # glass door panel slid in front of the neighbouring bay, bronze frame
            ox, oy = cx + ux * L * 0.45 + nx * 0.09, cy + uy * L * 0.45 + ny * 0.09
            self.box('door_glass', (L - 0.06, 0.012, top_glass - 0.04), (ox, oy, z + top_glass / 2), self.m('glass'), coll, rot=(0, 0, ang))
            for dd in (-1, 1):
                self.box('door_stile', (0.05, 0.05, top_glass), (ox + ux * dd * (L - 0.06) / 2, oy + uy * dd * (L - 0.06) / 2, z + top_glass / 2), self.m('bronze'), coll, rot=(0, 0, ang))
            for zz in (0.03, top_glass - 0.03):
                self.box('door_rail', (L - 0.06, 0.05, 0.06), (ox, oy, z + zz), self.m('bronze'), coll, rot=(0, 0, ang))
            self.box('track', (L * 2, 0.06, 0.02), (cx + ux * L * 0.5, cy + uy * L * 0.5, z + 0.01), self.m('bronze'), coll, rot=(0, 0, ang))
        self.box('header', (L, 0.14, 0.08), (cx, cy, z + top_glass + 0.04), self.m('timber'), coll, rot=(0, 0, ang))
        k = int(L / 0.075)
        for i in range(k):
            t = -L / 2 + (i + 0.5) * L / k
            self.box('slat', (0.03, 0.06, slat - 0.1), (cx + ux * t, cy + uy * t, z + top_glass + 0.08 + (slat - 0.1) / 2), self.m(slat_mat), coll, rot=(0, 0, ang))

    def sling_chair(self, x, y, rot=0.0, coll='spa', fabric='blush'):
        z = self.z
        root = self.empty('sling', x, y, z, rot, coll)
        wood = self.m('cedar_plain')
        for sx in (-0.28, 0.28):
            self.beam('sling_leg', (sx, -0.35, 0), (sx, 0.25, 0.95), (0.04, 0.04), wood, coll, parent=root)
            self.beam('sling_leg', (sx, 0.3, 0), (sx, -0.25, 0.6), (0.04, 0.04), wood, coll, parent=root)
        seat = self.box('sling_seat', (0.52, 0.85, 0.02), (0, -0.02, 0.5), self.m(fabric), coll, parent=root)
        seat.rotation_euler = (math.radians(-38), 0, 0)

    def cone_planter(self, x, y, ztop, drop=0.7, coll='plants'):
        """Hanging rusted-steel cone planter with trailing green (as on The Spring's pergola)."""
        zb = ztop - drop
        self.box('cone_cord', (0.006, 0.006, drop - 0.3), (x, y, ztop - (drop - 0.3) / 2), self.m('steel_dark'), coll)
        self.cyl('cone', 0.2, 0.42, (x, y, zb + 0.09), self.mat('rust', '#8a4a2a', rough=0.8, metal=0.3), coll, seg=20, r2=0.0, rot=(math.pi, 0, 0))
        rnd = random.Random(int(abs(x * 19 + y * 7)))
        lv = Leaves()
        for k in range(8):
            a = 2 * math.pi * k / 8
            L = rnd.uniform(0.25, 0.6)
            for j in range(int(L / 0.055)):
                t = j * 0.055
                lv.card((x + 0.2 * math.cos(a), y + 0.2 * math.sin(a), zb + 0.28 - t), (math.cos(a), math.sin(a), 0.3), 0.04, rnd.uniform(0, 6.28))
        lv.build(self, 'trailing', self.m('leaf_light'), coll, smooth=False)
        self.fern(x, y, zb + 0.28, s=0.25, n=9)

    def stump(self, x, y, h=0.45, r=0.26, coll='plants', z=None):
        z = self._z(z)
        self.cyl('stump', r, h, (x, y, z + h / 2), self.mat_grain('stump_bark', '#6b5442', '#56432f', 'Z', 30.0, rough=0.95), coll, seg=18)
        self.cyl('stump_top', r - 0.02, 0.01, (x, y, z + h), self.m('soil'), coll, seg=18)
        return z + h

    def rock(self, x, y, s=0.6, z=None, coll='spa'):
        z = self._z(z)
        ob = self.boulder(x, y, s, coll=coll)
        ob.location.z = z + s * 0.18
        return ob

    def mulch_bed(self, cx, cy, w, l, rot=0.0, coll='spa'):
        """Black pebble mulch bed draped on the ground."""
        return self._poly('mulch', cx, cy, w, l, rot, self.mat('black_pebble', '#4d4743', rough=0.9), coll, step=0.5, off=0.035)

    def sconce(self, x, y, z, rot=0.0, coll='spa'):
        self.box('sconce', (0.12, 0.08, 0.26), (x, y, z), self.m('lantern'), coll, rot=(0, 0, math.radians(rot)))
        self.point((x, y, z), 18, '#ffb871', radius=0.08)

    # ================================================================ bathing elements
    def round_tub(self, label, x, y, R=1.25, H=0.62, depth=0.55, kind='plaster', coll='spa', z=None):
        """Raised round soaking tub (hollow). kind: plaster | cedar."""
        z = self.z if z is None else z
        t = 0.16 if kind == 'plaster' else 0.06
        prof = [(R, 0.0), (R, H), (R - t, H), (R - t, H - depth), (0.0, H - depth)]
        mat = self.m('plaster') if kind == 'plaster' else self.m('cedar')
        self.lathe('tub', prof, (x, y, z), mat, coll, seg=72)
        if kind == 'plaster':
            self.lathe('coping', [(R + 0.06, H - 0.01), (R + 0.06, H + 0.05), (R - t - 0.02, H + 0.05), (R - t - 0.02, H - 0.01)],
                       (x, y, z), self.m('stone'), coll, seg=72)
            self.lathe('tub_lining', [(R - t + 0.002, H - 0.17), (R - t + 0.002, H - depth + 0.002), (0.0, H - depth + 0.002)],
                       (x, y, z), self.m('pool_lining'), coll, seg=72, round_r=0.03)
            self.lathe('tub_mosaic', [(R - t + 0.003, H - 0.02), (R - t + 0.003, H - 0.17)], (x, y, z), self.m('mosaic'), coll, seg=72, round_r=0.0)
        else:
            for zz in (0.12, H - 0.12):
                self.lathe('hoop', [(R + 0.012, zz - 0.025), (R + 0.012, zz + 0.025)], (x, y, z), self.m('steel_dark'), coll, seg=72)
        self.cyl('water', R - t - 0.004, 0.006, (x, y, z + H - 0.09), self.m('water'), coll, seg=72)
        self.anchor(label, x, y, z, 1, dz=H + 0.3)

    def square_tub(self, label, x, y, w, l, floor_z, depth=0.62, coll='spa'):
        """Sunken tub in a raised floor: tiled walls from floor_z - depth to floor_z, water just below."""
        zb = floor_z - depth
        t = 0.08
        for (cx, cy, sx, sy) in ((x, y + l / 2 + t / 2, w + 2 * t, t), (x, y - l / 2 - t / 2, w + 2 * t, t),
                                 (x + w / 2 + t / 2, y, t, l), (x - w / 2 - t / 2, y, t, l)):
            self.box('tub_wall', (sx, sy, depth), (cx, cy, zb + depth / 2), self.m('tile_wall'), coll)
        self.box('tub_floor', (w, l, 0.04), (x, y, zb + 0.02), self.m('tile'), coll)
        self.box('tub_bench', (w, 0.42, 0.34), (x, y + l / 2 - 0.21, zb + 0.17), self.m('tile_wall'), coll)
        self.box('water', (w, l, 0.006), (x, y, floor_z - 0.08), self.m('water'), coll)
        # stone coping frame
        c = 0.22
        for (cx, cy, sx, sy) in ((x, y + l / 2 + c / 2, w + 2 * c, c), (x, y - l / 2 - c / 2, w + 2 * c, c),
                                 (x + w / 2 + c / 2, y, c, l), (x - w / 2 - c / 2, y, c, l)):
            self.box('coping', (sx, sy, 0.05), (cx, cy, floor_z + 0.025), self.m('stone'), coll)
        self.anchor(label, x, y, floor_z, 1, dz=0.4)

    def acrylic_spa(self, label, x, y, s=2.13, coll='spa', rot=0.0):
        """Plug-and-play acrylic hot tub: cedar-look cabinet, white shell, rounded-square well."""
        z = self.z
        H = 0.9
        t = 0.08
        for (cx, cy, sx, sy) in ((0, s / 2 - t / 2, s, t), (0, -s / 2 + t / 2, s, t), (s / 2 - t / 2, 0, t, s - 2 * t), (-s / 2 + t / 2, 0, t, s - 2 * t)):
            self.box('spa_cabinet', (sx, sy, H - 0.06), (x + cx, y + cy, z + (H - 0.06) / 2), self.m('cedar_h'), coll)
        well = self.stadium(s - 0.34, s - 0.34, r=0.3, cx=x, cy=y)
        rim_out = self.stadium(s, s, r=0.1, cx=x, cy=y)
        n = len(well)
        verts = [(px, py, z + H - 0.04) for (px, py) in well] + [(px, py, z + 0.3) for (px, py) in well]
        faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        self.mesh_from('spa_shell', verts, faces, self.m('acrylic'), coll)
        self.mesh_from('spa_floor', [(px, py, z + 0.3) for (px, py) in well], [tuple(range(n))], self.m('acrylic'), coll)
        self.ring_slab('spa_rim', well, rim_out, z + H - 0.06, z + H, self.m('acrylic'), coll)
        self.mesh_from('water', [(px, py, z + H - 0.1) for (px, py) in self.offset(well, -0.005)], [tuple(range(n))], self.m('water'), coll)
        self.box('spa_steps', (0.9, 0.42, 0.42), (x, y - s / 2 - 0.25, z + 0.21), self.m('cedar_h'), coll)
        self.anchor(label, x, y, z, 1, dz=1.2)

    def barrel_sauna(self, label, x, y, rot=0.0, L=2.4, r=0.98, coll='sauna'):
        """Cedar barrel sauna; local +X end has the glass door. rot in degrees."""
        z = self.z
        root = self.empty('barrel', x, y, z, rot, coll)
        cz = r + 0.2
        shell = self.lathe('barrel_shell', [(r, -L / 2), (r, L / 2), (r - 0.05, L / 2), (r - 0.05, -L / 2)], (0, 0, cz),
                           self.m('cedar'), coll, seg=48, parent=root)
        shell.rotation_euler = (0, math.pi / 2, 0)
        self.cyl('back_wall', r - 0.03, 0.05, (-L / 2 + 0.05, 0, cz), self.m('cedar_h'), coll, parent=root, seg=48, rot=(0, math.pi / 2, 0))
        self.cyl('front_wall', r - 0.03, 0.05, (L / 2 - 0.05, 0, cz), self.m('cedar_h'), coll, parent=root, seg=48, rot=(0, math.pi / 2, 0))
        self.box('door_glass', (0.03, 0.66, 1.55), (L / 2 - 0.02, 0, 0.2 + 0.86), self.m('glass'), coll, parent=root)
        for (dy, dz, sy, sz) in ((-0.36, 0, 0.06, 1.6), (0.36, 0, 0.06, 1.6), (0, 0.8, 0.78, 0.06), (0, -0.8, 0.78, 0.06)):
            self.box('door_frame', (0.06, sy, sz), (L / 2, dy, 1.06 + dz), self.m('cedar_plain'), coll, parent=root)
        for k in range(3):
            xx = -L / 2 + 0.22 + k * (L - 0.44) / 2
            self.lathe('band', [(r + 0.012, -0.025), (r + 0.012, 0.025)], (xx, 0, cz), self.m('steel_dark'), coll, seg=48, parent=root).rotation_euler = (0, math.pi / 2, 0)
        for sx in (-1, 1):
            self.box('cradle', (0.22, 2 * r * 0.8, 0.3), (sx * (L / 2 - 0.35), 0, 0.15), self.m('cedar_plain'), coll, parent=root)
        self.box('sauna_porch', (0.8, 1.5, 0.08), (L / 2 + 0.45, 0, 0.04), self.m('cedar_plain'), coll, parent=root)
        self.cyl('chimney', 0.07, 1.1, (-L / 4, 0.0, 2 * r + 0.65), self.m('steel'), coll, parent=root, seg=16)
        self.box('glow', (L * 0.7, 0.5, 0.04), (0, 0, 0.75), self.mat('sauna_glow', '#ffcf8a', emit='#ffb15e', emit_strength=6.0 if self.night else 0.0), coll, parent=root)
        self.point((x, y, z + cz), 60, '#ffb066', radius=0.3)
        self.foot(x, y, L / 2 + 1.3, r + 1.2)
        self.anchor(label, x, y, z, 2, dz=2 * r + 0.6)
        return root

    def cabin_sauna(self, label, x, y, rot=0.0, w=2.2, d=2.2, h=2.3, coll='sauna'):
        """Cedar cabin sauna with a glass front; local -Y is the front."""
        z = self.z
        root = self.empty('cabin', x, y, z, rot, coll)
        self.box('cabin_base', (w, d, 0.12), (0, 0, 0.06), self.m('timber'), coll, parent=root)
        self.box('cabin', (w, d, h), (0, 0, h / 2 + 0.12), self.m('cedar_h'), coll, parent=root)
        self.box('cabin_roof', (w + 0.5, d + 0.6, 0.16), (0, -0.05, h + 0.22), self.m('roof_flat'), coll, parent=root, rot=(math.radians(4), 0, 0))
        self.box('glass_front', (w * 0.62, 0.02, h * 0.82), (-w * 0.12, -d / 2 - 0.012, h * 0.47 + 0.12), self.m('glass'), coll, parent=root)
        self.box('mullion', (0.07, 0.06, h * 0.82), (w * 0.2, -d / 2 - 0.02, h * 0.47 + 0.12), self.m('timber'), coll, parent=root)
        self.box('door_handle', (0.03, 0.06, 0.5), (w * 0.16, -d / 2 - 0.06, 1.1), self.m('cedar_plain'), coll, parent=root)
        self.box('sauna_porch', (w + 0.3, 0.9, 0.1), (0, -d / 2 - 0.45, 0.05), self.m('cedar_plain'), coll, parent=root)
        # benches seen through the glass
        for (bz, by, bd) in ((0.5, d / 2 - 0.55, 0.5), (0.95, d / 2 - 0.3, 0.5)):
            self.box('bench', (w - 0.2, bd, 0.05), (0, by, bz + 0.12), self.m('cedar_plain'), coll, parent=root)
        self.box('glow', (w - 0.3, 0.3, 0.04), (0, d / 2 - 0.4, 0.4), self.mat('sauna_glow', '#ffcf8a', emit='#ffb15e', emit_strength=6.0 if self.night else 0.0), coll, parent=root)
        self.cyl('chimney', 0.07, 0.9, (w / 2 - 0.4, d / 2 - 0.4, h + 0.6), self.m('steel'), coll, parent=root, seg=16)
        ox = Vector((0, 0.2, 1.3))
        ox.rotate(root.rotation_euler)
        self.point((x + ox.x, y + ox.y, z + ox.z), 80, '#ffad5e', radius=0.4)
        self.foot(x, y, w / 2 + 1.2, d / 2 + 1.4)
        self.anchor(label, x, y, z, 2, dz=h + 0.6)
        return root

    def clay_dome(self, label, x, y, r=1.45, rot=0.0, coll='sauna'):
        """Earthen dome warm room, after the Korean hanjeungmak kiln sauna (a low arched door)."""
        z = self.z
        root = self.empty('dome', x, y, z, rot, coll)
        prof = [(r * math.cos(a), r * 0.92 * math.sin(a)) for a in np.linspace(0, math.pi / 2, 14)]
        self.lathe('dome', prof, (0, 0, 0), self.m('earth'), coll, seg=56, parent=root, round_r=0.0)
        self.cyl('dome_base', r + 0.12, 0.2, (0, 0, 0.1), self.m('stone_dark'), coll, parent=root, seg=56)
        # arched door on local -Y
        self.box('dome_door', (0.62, 0.3, 0.95), (0, -r + 0.12, 0.62), self.m('black_fabric'), coll, parent=root)
        self.cyl('dome_arch', 0.31, 0.3, (0, -r + 0.12, 1.08), self.m('black_fabric'), coll, parent=root, seg=24, rot=(math.pi / 2, 0, 0))
        self.box('dome_sill', (0.8, 0.5, 0.06), (0, -r - 0.05, 0.03), self.m('stone'), coll, parent=root)
        self.foot(x, y, r + 0.8)
        self.anchor(label, x, y, z, 2, dz=r + 0.4)
        return root

    def cold_plunge(self, label, x, y, kind='stock', rot=0.0, coll='spa'):
        z = self.z
        if kind == 'stock':
            ob = self.lathe('stock_tank', [(0.8, 0.0), (0.8, 0.62), (0.77, 0.62), (0.77, 0.04), (0.0, 0.04)], (x, y, z),
                            self.m('steel'), coll, seg=56)
            ob.scale = (1.4, 1.0, 1.0)
            ob.rotation_euler = (0, 0, math.radians(rot))
            w = self.cyl('plunge_water', 0.765, 0.006, (x, y, z + 0.52), self.m('cold'), coll, seg=56)
            w.scale = (1.4, 1.0, 1.0)
            w.rotation_euler = (0, 0, math.radians(rot))
        else:
            self.lathe('plunge_tub', [(0.72, 0.0), (0.72, 1.05), (0.66, 1.05), (0.66, 0.06), (0.0, 0.06)], (x, y, z),
                       self.m('cedar'), coll, seg=56)
            for zz in (0.15, 0.9):
                self.lathe('hoop', [(0.732, zz - 0.025), (0.732, zz + 0.025)], (x, y, z), self.m('steel_dark'), coll, seg=56)
            self.cyl('plunge_water', 0.655, 0.006, (x, y, z + 0.95), self.m('cold'), coll, seg=56)
            self.box('plunge_step', (0.7, 0.4, 0.45), (x, y - 0.95, z + 0.225), self.m('cedar_plain'), coll)
        self.anchor(label, x, y, z, 1, dz=1.2)

    def shower(self, label, x, y, rot=0.0, coll='spa', anchor=True, cat=1):
        z = self.z
        root = self.empty('shower', x, y, z, rot, coll)
        self.box('shower_post', (0.14, 0.14, 2.35), (0, 0, 1.175), self.m('cedar_plain'), coll, parent=root)
        self.box('shower_arm', (0.035, 0.42, 0.035), (0, -0.21, 2.25), self.m('steel'), coll, parent=root)
        self.cyl('shower_head', 0.13, 0.025, (0, -0.42, 2.22), self.m('steel'), coll, parent=root, seg=24)
        self.box('shower_valve', (0.06, 0.08, 0.14), (0, -0.09, 1.2), self.m('steel'), coll, parent=root)
        n = 7
        for i in range(n):
            self.box('shower_slat', (0.95, 0.1, 0.04), (0, -0.42 - 0.45 + (i + 0.5) * 0.9 / n, 0.04), self.m('cedar_plain'), coll, parent=root)
        if anchor:
            self.anchor(label, x, y, z, cat, dz=2.5)

    def scrub_station(self, label, x, y, rot=0.0, coll='spa', roofed=True):
        """Seshin (Korean body-scrub) corner: a padded tiled table, low stools, basins, hand shower."""
        z = self.z
        root = self.empty('scrub', x, y, z, rot, coll)
        self.box('scrub_table', (1.9, 0.72, 0.56), (0, 0, 0.28), self.m('tile_wall'), coll, parent=root)
        self.box('scrub_pad', (1.94, 0.76, 0.1), (0, 0, 0.61), self.m('peach'), coll, parent=root, bevel=0.04, seg=2)
        self.box('scrub_pillow', (0.4, 0.5, 0.12), (-0.72, 0, 0.72), self.m('blush'), coll, parent=root, bevel=0.05, seg=2)
        for sx in (-0.45, 0.45):
            self.cyl('stool', 0.16, 0.3, (sx, 0.85, 0.15), self.m('coral'), coll, parent=root, seg=20)
            self.cyl('basin', 0.2, 0.11, (sx + 0.32, 0.92, 0.055), self.mat('basin', '#e9e4dc', rough=0.25), coll, parent=root, seg=24, r2=0.15)
        self.box('wet_wall', (2.2, 0.12, 1.6), (0, 1.3, 0.8), self.m('tile_wall'), coll, parent=root)
        for sx in (-0.5, 0.5):
            self.box('tap', (0.05, 0.12, 0.05), (sx, 1.2, 0.75), self.m('steel'), coll, parent=root)
            self.cyl('hand_shower', 0.035, 0.24, (sx + 0.15, 1.2, 1.05), self.m('steel'), coll, parent=root, seg=12)
        if roofed:
            for sx in (-1.15, 1.15):
                self.box('scrub_post', (0.12, 0.12, 2.4), (sx, -0.55, 1.2), self.m('timber'), coll, parent=root)
            self.box('scrub_roof', (2.8, 2.4, 0.12), (0, 0.4, 2.46), self.m('roof_flat'), coll, parent=root, rot=(math.radians(-6), 0, 0))
        self.anchor(label, x, y, z, 1, dz=1.0)
        return root

    def rest_platform(self, label, x, y, w=2.8, d=2.0, rot=0.0, coll='spa', h=0.42, z=None):
        """Maru / ondol rest platform: a raised heated floor with floor cushions and a low tea table."""
        z = self.z if z is None else z
        root = self.empty('maru', x, y, z, rot, coll)
        self.box('platform', (w, d, h), (0, 0, h / 2), self.mat_grain('maru', '#c69a6c', '#b58757', 'Y', 4.0, rough=0.5), coll, parent=root)
        self.box('ondol_mat', (w - 0.24, d - 0.24, 0.035), (0, 0, h + 0.017), self.mat('ondol_paper', '#e8c995', rough=0.55), coll, parent=root)
        self.box('tea_table', (0.8, 0.5, 0.06), (0.15, -0.1, h + 0.3), self.m('timber'), coll, parent=root)
        for (lx, ly) in ((-0.33, -0.3), (0.63, -0.3), (-0.33, 0.1), (0.63, 0.1)):
            self.box('tea_leg', (0.05, 0.05, 0.27), (lx - 0.0, ly + 0.0, h + 0.15), self.m('timber'), coll, parent=root)
        cush = [self.m('blush'), self.m('peach'), self.m('coral'), self.m('black_fabric')]
        for k, (cx, cy) in enumerate(((-0.75, -0.55), (0.95, -0.55), (-0.75, 0.35), (0.95, 0.35))):
            self.box('cushion', (0.58, 0.58, 0.1), (cx * w / 2.8, cy * d / 2.0, h + 0.085), cush[k], coll, parent=root, bevel=0.045, seg=2)
        self.box('bolster', (w - 0.5, 0.26, 0.26), (0, d / 2 - 0.24, h + 0.16), self.m('blush'), coll, parent=root, bevel=0.11, seg=3)
        self.anchor(label, x, y, z, 3, dz=h + 0.5)
        return root

    def lounger(self, x, y, rot=0.0, coll='spa', pad='blush'):
        z = self.z
        root = self.empty('lounger', x, y, z, rot, coll)
        self.box('lounger_frame', (0.7, 1.9, 0.08), (0, 0, 0.3), self.m('timber'), coll, parent=root)
        for (sx, sy) in ((-0.3, -0.85), (0.3, -0.85), (-0.3, 0.85), (0.3, 0.85)):
            self.box('lounger_leg', (0.05, 0.05, 0.28), (sx, sy, 0.14), self.m('timber'), coll, parent=root)
        self.box('lounger_pad', (0.66, 1.25, 0.09), (0, -0.3, 0.38), self.m(pad), coll, parent=root, bevel=0.035, seg=2)
        back = self.box('lounger_back', (0.66, 0.72, 0.09), (0, 0.55, 0.62), self.m(pad), coll, parent=root, bevel=0.035, seg=2)
        back.rotation_euler = (math.radians(48), 0, 0)
        self.box('towel', (0.5, 0.35, 0.05), (0, -0.7, 0.45), self.m('plaster'), coll, parent=root, bevel=0.02, seg=2)

    def lantern(self, x, y, z, r=0.2, h=0.4, coll='spa', cord=0.5, light=True):
        self.cyl('lantern', r, h, (x, y, z), self.m('lantern'), coll, seg=24)
        self.cyl('lantern_cap', r * 0.5, 0.04, (x, y, z + h / 2 + 0.02), self.m('timber'), coll, seg=12)
        if cord:
            self.box('cord', (0.008, 0.008, cord), (x, y, z + h / 2 + cord / 2), self.m('timber'), coll)
        if light:
            self.point((x, y, z), 35, '#ffb871', radius=r * 0.8)

    def string_lights(self, p1, p2, n=12, sag=0.35, coll='spa'):
        p1, p2 = Vector(p1), Vector(p2)
        bulb = self.mat('bulb', '#fff4dc', emit='#ffb45c', emit_strength=7.0 if self.night else 0.3)
        prev = p1
        for i in range(n + 1):
            t = i / n
            p = p1.lerp(p2, t)
            p.z -= sag * 4 * t * (1 - t)
            if i:
                self.beam('wire', prev, p, (0.006, 0.006), self.m('timber'), coll)
            if 0 < i < n:
                b = self.lathe('bulb', [(0.0, -0.05), (0.035, -0.035), (0.042, 0.0), (0.03, 0.03), (0.012, 0.045), (0.0, 0.05)], (p.x, p.y, p.z - 0.07), bulb, coll, seg=12, round_r=0.0)
                if i % 3 == 0:
                    self.point((p.x, p.y, p.z - 0.12), 12, '#ffc27c', radius=0.05)
            prev = p

    def point(self, loc, watts, color, radius=0.2):
        ld = bpy.data.lights.new('lamp', 'POINT')
        ld.energy = watts
        ld.color = K.srgb(color)[:3]
        ld.shadow_soft_size = radius
        ob = bpy.data.objects.new('lamp', ld)
        ob.location = loc
        ob.hide_render = not self.night
        self.lamps.append(ob)
        return self.link(ob, 'lights')

    def towel_rack(self, x, y, rot=0.0, coll='spa'):
        z = self.z
        root = self.empty('rack', x, y, z, rot, coll)
        for sx in (-0.45, 0.45):
            self.box('rack_post', (0.05, 0.05, 1.3), (sx, 0, 0.65), self.m('timber'), coll, parent=root)
        for k, col in enumerate(('blush', 'peach', 'plaster')):
            self.box('towel', (0.85, 0.03, 0.55), (0, 0.04 * (k - 1), 1.0 - 0.02 * k), self.m(col), coll, parent=root)
        self.box('rack_bar', (1.0, 0.04, 0.04), (0, 0, 1.25), self.m('timber'), coll, parent=root)

    # ================================================================ plants
    def _z(self, z):
        return self.z if z is None else z

    def palm(self, x, y, h=5.0, z=None, coll='plants', n=18, kind='fan', lean=(0.0, 0.0)):
        """Fan palm (Washingtonia / Chamaerops) or feather palm ('feather')."""
        z = self.t.h(x, y) if z is None else z
        rnd = random.Random(int(abs(x * 13 + y * 7)))
        lx, ly = lean
        self.cyl('palm_trunk', 0.2, h, (x + lx * h / 2, y + ly * h / 2, z + h / 2), self.m('trunk'), coll, seg=14, r2=0.15,
                      rot=(-ly, lx, 0))
        top = Vector((x + lx * h, y + ly * h, z + h))
        lv = Leaves()
        stems = Leaves()
        for k in range(n):
            a = k * 2.39996 + rnd.uniform(-0.15, 0.15)
            ring = k % 3
            el = [0.75, 0.25, -0.35][ring] + rnd.uniform(-0.15, 0.15)
            Lp = (0.55 if kind == 'fan' else 0.3) * (h / 5.0) ** 0.3 * rnd.uniform(0.85, 1.15)
            d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
            tip = top + d * Lp
            stems.strip(tuple(top), a, Lp, 0.035, lift=math.tan(el), droop=0.0, n=2)
            if kind == 'fan':
                sc = min(1.0, 0.45 + h / 8.0)
                lv.fan(tip, d + Vector((0, 0, -0.15)), n=20, span=2.4, length=0.95 * sc, width=0.08 * sc, droop=0.3)
            else:
                lv.strip(tuple(top), a, rnd.uniform(1.8, 2.5), 0.42, lift=math.tan(el), droop=0.45, n=10, serrate=True)
        stems.build(self, 'palm_stems', self.mat('palm_stem', '#7b7a4a', rough=0.7), coll)
        lv.build(self, 'palm_fronds', self.m('palm'), coll)
        if kind == 'fan':  # skirt of dry fronds
            self.cyl('palm_skirt', 0.36, 0.9, (top[0], top[1], top[2] - 0.55), self.mat('palm_skirt', '#a68a62', rough=1.0), coll, seg=12, r2=0.22)
        self.foot(x, y, 0.9)

    def bird_of_paradise(self, x, y, z=None, s=1.0, coll='plants', flowers=True):
        z = self._z(z)
        rnd = random.Random(int(abs(x * 5 + y * 11)))
        lv = Leaves()
        for k in range(11):
            a = 2 * math.pi * k / 11 + rnd.uniform(-0.25, 0.25)
            lv.strip((x, y, z), a, s * rnd.uniform(1.0, 1.45), 0.26 * s, lift=rnd.uniform(3.0, 5.5), droop=0.9, n=9, petiole=0.55, tilt=0.4)
        lv.build(self, 'strelitzia', self.m('leaf_dark'), coll)
        if flowers:
            for k in range(3):
                a = rnd.uniform(0, 6.28)
                fx, fy, fz = x + 0.15 * math.cos(a), y + 0.15 * math.sin(a), z + s * rnd.uniform(0.9, 1.15)
                self.beam('flower', (fx, fy, fz), (fx + 0.22 * math.cos(a + 1.5), fy + 0.22 * math.sin(a + 1.5), fz + 0.08), (0.05, 0.03), self.m('bird_flower'), coll)

    def fern(self, x, y, z=None, s=0.6, coll='plants', mat='leaf_light', n=16):
        z = self._z(z)
        rnd = random.Random(int(abs(x * 31 + y * 17)))
        lv = Leaves()
        for k in range(n):
            a = 2 * math.pi * k / n + rnd.uniform(-0.3, 0.3)
            lv.strip((x, y, z), a, s * rnd.uniform(0.8, 1.2), 0.2 * s, lift=rnd.uniform(1.1, 2.2), droop=0.9, n=12, serrate=True)
        return lv.build(self, 'fern', self.m(mat), coll)

    def snake_plant(self, x, y, z=None, s=0.8, coll='plants'):
        z = self._z(z)
        rnd = random.Random(int(abs(x * 7 + y * 29)))
        lv = Leaves()
        for k in range(12):
            a = rnd.uniform(0, 6.28)
            lv.strip((x + rnd.uniform(-0.08, 0.08), y + rnd.uniform(-0.08, 0.08), z), a, s * rnd.uniform(0.6, 1.0), 0.07,
                     lift=rnd.uniform(6, 14), droop=0.05, n=4, tilt=1.0)
        return lv.build(self, 'sansevieria', self.m('leaf_dark'), coll)

    def agave(self, x, y, z=None, s=0.7, coll='plants'):
        z = self.t.h(x, y) if z is None else z
        rnd = random.Random(int(abs(x * 3 + y * 19)))
        lv = Leaves()
        for k in range(22):
            a = 2.39996 * k
            ring = k / 22
            lv.strip((x, y, z + 0.05), a, s * (1.0 - 0.45 * ring), 0.16 * s * (1 - 0.4 * ring), lift=0.5 + 2.6 * ring, droop=0.1, n=5, tilt=0.6)
        lv.build(self, 'agave', self.m('agave'), coll)
        self.foot(x, y, s * 0.9)

    def yucca_rostrata(self, x, y, h=1.6, z=None, coll='plants'):
        z = self.t.h(x, y) if z is None else z
        self.cyl('yucca_trunk', 0.13, h, (x, y, z + h / 2), self.mat('yucca_trunk', '#7c6c5c', rough=1.0), coll, seg=10)
        rnd = random.Random(int(abs(x * 3 + y * 5)))
        lv = Leaves()
        for k in range(70):
            a = 2.39996 * k
            el = rnd.uniform(-1.2, 1.4)
            lv.strip((x, y, z + h), a, 0.55, 0.025, lift=math.tan(max(-1.4, min(1.4, el))), droop=0.0, n=2)
        lv.build(self, 'yucca_leaves', self.m('agave'), coll, smooth=False)
        self.foot(x, y, 0.8)

    def bamboo(self, x, y, h=4.2, n=12, spread=0.4, z=None, coll='plants'):
        z = self._z(z)
        rnd = random.Random(int(abs(x * 17 + y * 3)))
        lv = Leaves()
        for k in range(n):
            cx, cy = x + rnd.uniform(-spread, spread), y + rnd.uniform(-spread, spread)
            hh = h * rnd.uniform(0.75, 1.08)
            lx, ly = rnd.uniform(-0.06, 0.06), rnd.uniform(-0.06, 0.06)
            self.cyl('culm', 0.024, hh, (cx + lx * hh / 2, cy + ly * hh / 2, z + hh / 2), self.m('bamboo'), coll, seg=6, rot=(-ly, lx, 0))
            for j in range(16):
                t = rnd.uniform(0.45, 1.0)
                c = Vector((cx + lx * hh * t, cy + ly * hh * t, z + hh * t))
                for q in range(4):
                    a = rnd.uniform(0, 6.28)
                    lv.strip(tuple(c), a, rnd.uniform(0.16, 0.24), 0.035, lift=rnd.uniform(-0.6, 0.4), droop=0.4, n=3)
        lv.build(self, 'bamboo_leaves', self.m('leaf_light'), coll)

    def vine_post(self, x, y, z, h, coll='plants', flowers=True, r=0.15):
        """Star jasmine / ivy climbing a post."""
        rnd = random.Random(int(abs(x * 41 + y * 23)))
        lv = Leaves()
        fl = Leaves()
        for k in range(int(h * 70)):
            t = rnd.uniform(0.0, 1.0)
            a = rnd.uniform(0, 6.28)
            rr = r * rnd.uniform(0.7, 1.6)
            c = (x + rr * math.cos(a), y + rr * math.sin(a), z + t * h)
            nrm = (math.cos(a) + rnd.uniform(-0.6, 0.6), math.sin(a) + rnd.uniform(-0.6, 0.6), rnd.uniform(-0.3, 0.8))
            lv.card(c, nrm, 0.055, rnd.uniform(0, 6.28))
            if flowers and rnd.random() < 0.18:
                fl.card((c[0] * 1.0, c[1], c[2] + 0.02), nrm, 0.022, rnd.uniform(0, 6.28))
        lv.build(self, 'vine', self.m('leaf_dark'), coll, smooth=False)
        fl.build(self, 'vine_flowers', self.m('jasmine'), coll, smooth=False)

    def vine_beam(self, p1, p2, coll='plants', density=55, droop=0.35):
        """Leaves draped along a beam (ivy on the pergola)."""
        p1, p2 = Vector(p1), Vector(p2)
        L = (p2 - p1).length
        rnd = random.Random(int(abs(p1.x * 7 + p2.y * 13)))
        lv = Leaves()
        for k in range(int(L * density)):
            t = rnd.random()
            c = p1.lerp(p2, t) + Vector((rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15), -rnd.random() ** 2 * droop))
            lv.card(tuple(c), (rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.2, 1)), 0.055, rnd.uniform(0, 6.28))
        lv.build(self, 'ivy', self.m('leaf_dark'), coll, smooth=False)

    def wall_creeper(self, p1, p2, z0, z1, kind='bougainvillea', coll='plants', density=90, depth=0.12, side=1):
        """Leaves/bracts spread over a wall face between p1 and p2 (plan points)."""
        (x1, y1), (x2, y2) = p1, p2
        ang = math.atan2(y2 - y1, x2 - x1)
        nx, ny = -math.sin(ang) * side, math.cos(ang) * side
        L = math.hypot(x2 - x1, y2 - y1)
        rnd = random.Random(int(abs(x1 * 3 + y2 * 7)))
        lv, br = Leaves(), Leaves()
        for k in range(int(L * (z1 - z0) * density)):
            t = rnd.random()
            u = rnd.random() ** 0.7
            zz = z0 + (z1 - z0) * (1 - u * u * 0.0) * rnd.random() ** 0.6
            off = rnd.uniform(0.02, depth)
            c = (x1 + (x2 - x1) * t + nx * off, y1 + (y2 - y1) * t + ny * off, zz)
            nrm = (nx + rnd.uniform(-0.5, 0.5), ny + rnd.uniform(-0.5, 0.5), rnd.uniform(-0.3, 0.6))
            if kind == 'bougainvillea' and rnd.random() < 0.42:
                br.card(c, nrm, 0.05, rnd.uniform(0, 6.28))
            else:
                lv.card(c, nrm, 0.06, rnd.uniform(0, 6.28))
        lv.build(self, 'creeper', self.m('leaf'), coll, smooth=False)
        br.build(self, 'bracts', self.m('bract'), coll, smooth=False)

    def hanging_plant(self, x, y, ztop, coll='plants', drop=0.55):
        zb = ztop - drop
        self.box('hang_cord', (0.006, 0.006, drop), (x, y, ztop - drop / 2), self.m('timber'), coll)
        self.lathe('hang_pot', [(0.12, -0.16), (0.17, 0.0), (0.155, 0.0), (0.1, -0.15), (0.0, -0.15)], (x, y, zb), self.m('plaster'), coll, seg=24)
        rnd = random.Random(int(abs(x * 9 + y * 5)))
        lv = Leaves()
        for k in range(9):
            a = 2 * math.pi * k / 9 + rnd.uniform(-0.2, 0.2)
            L = rnd.uniform(0.35, 0.95)
            for j in range(int(L / 0.06)):
                t = j * 0.06
                c = (x + (0.16 + 0.04 * t) * math.cos(a), y + (0.16 + 0.04 * t) * math.sin(a), zb - t)
                lv.card(c, (math.cos(a), math.sin(a), 0.3), 0.045, rnd.uniform(0, 6.28))
        self.fern(x, y, zb - 0.02, s=0.32, coll=coll, mat='leaf_light', n=10)
        lv.build(self, 'pothos', self.m('leaf_light'), coll, smooth=False)

    def pot(self, x, y, r=0.32, h=0.55, coll='plants', mat='plaster', z=None):
        z = self._z(z)
        self.lathe('pot', [(r * 0.75, 0.0), (r, h), (r - 0.03, h), (r * 0.72, 0.05), (0.0, 0.05)], (x, y, z), self.m(mat), coll, seg=32)
        self.cyl('pot_soil', r - 0.035, 0.01, (x, y, z + h - 0.05), self.m('soil'), coll, seg=32)
        return z + h - 0.05

    def planter(self, x, y, w, d, h=0.45, coll='plants', rot=0.0, mat='plaster', z=None):
        z = self._z(z)
        root = self.empty('planter', x, y, z, rot, coll)
        t = 0.08
        for (cx, cy, sx, sy) in ((0, d / 2 - t / 2, w, t), (0, -d / 2 + t / 2, w, t), (w / 2 - t / 2, 0, t, d - 2 * t), (-w / 2 + t / 2, 0, t, d - 2 * t)):
            self.box('planter_wall', (sx, sy, h), (cx, cy, h / 2), self.m(mat), coll, parent=root)
        self.box('planter_soil', (w - 2 * t, d - 2 * t, h - 0.06), (0, 0, (h - 0.06) / 2), self.m('soil'), coll, parent=root)
        return z + h - 0.06

    def groundcover(self, x, y, w, d, z=None, coll='plants', density=160, rot=0.0, mat='leaf'):
        z = self._z(z)
        rnd = random.Random(int(abs(x * 11 + y * 3)))
        lv = Leaves()
        c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        for k in range(int(w * d * density)):
            u, v = rnd.uniform(-w / 2, w / 2), rnd.uniform(-d / 2, d / 2)
            px, py = x + u * c - v * s, y + u * s + v * c
            lv.card((px, py, z + rnd.uniform(0.02, 0.12)), (rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), 1), 0.05, rnd.uniform(0, 6.28))
        lv.build(self, 'groundcover', self.m(mat), coll, smooth=False)

    def olive(self, x, y, h=2.6, z=None, coll='plants'):
        z = self._z(z)
        rnd = random.Random(int(abs(x * 13 + y * 31)))
        self.beam('olive_trunk', (x, y, z), (x + 0.15, y - 0.1, z + h * 0.5), (0.14, 0.14), self.mat('olive_bark', '#6d6458', rough=0.95), coll)
        me = self._blob_mesh('olive_canopy', '#7d8b67', jitter=0.35, subdiv=3)
        for k in range(5):
            ob = bpy.data.objects.new('olive', me)
            ob.location = (x + 0.15 + rnd.uniform(-0.5, 0.5), y - 0.1 + rnd.uniform(-0.5, 0.5), z + h * rnd.uniform(0.62, 0.88))
            s = rnd.uniform(0.8, 1.15)
            ob.scale = (s, s, s * 0.7)
            self.link(ob, coll)

    # ================================================================ lights, cameras, render
    def daylight(self, az=250, el=14, strength=4.2, sky=0.55):
        self.lights(sun_az=az, sun_el=el, strength=strength, sky_strength=sky)

    def set_night(self, on):
        """Switch lanterns, paper screens, sauna glow and lamps on for dusk renders."""
        self.night = on
        for m in self.mats.values():
            if not m.use_nodes:
                continue
            p = m.node_tree.nodes.get('Principled BSDF')
            if p is None:
                continue
            if m.name == 'hanji':
                p.inputs['Emission Strength'].default_value = self.paper_glow()
            elif m.name == 'lantern':
                p.inputs['Emission Strength'].default_value = self.lantern_strength()
            elif m.name == 'sauna_glow':
                p.inputs['Emission Strength'].default_value = 6.0 if on else 0.0
            elif m.name == 'bulb':
                p.inputs['Emission Strength'].default_value = 7.0 if on else 0.3
        for ob in self.lamps:
            ob.hide_render = not on

    def cam(self, name, loc, target, lens=28, shift=(0, 0)):
        c = self.camera(name, loc, target, lens=lens)
        c.data.shift_x, c.data.shift_y = shift
        c.data.sensor_width = 36
        return c

    def plan_view(self, width=24.0, center=(0, 0)):
        return self.camera('plan', (center[0], center[1], 60), ortho=width, rot=(0, 0, 0))

    def render(self, cam, name, res=(2000, 1000), samples=48, contours=0.0, hide=(), show=(), extra_anchor_filter=None,
               exposure=0.0, look='AgX - Medium High Contrast'):
        import json
        from bpy_extras.object_utils import world_to_camera_view
        sc = self.scene
        sc.camera = cam
        sc.render.engine = 'CYCLES'
        sc.cycles.device = 'CPU'
        sc.cycles.samples = 16 if self.preview else samples
        sc.cycles.use_denoising = True
        sc.cycles.max_bounces = 6
        sc.cycles.diffuse_bounces = 3
        sc.cycles.glossy_bounces = 3
        sc.cycles.transmission_bounces = 3
        sc.cycles.transparent_max_bounces = 24
        sc.cycles.light_tree = True
        sc.render.threads_mode = 'AUTO'
        f = 0.4 if self.preview else 1.0
        sc.render.resolution_x = int(res[0] * f)
        sc.render.resolution_y = int(res[1] * f)
        sc.render.resolution_percentage = 100
        sc.view_settings.view_transform = 'AgX'
        sc.view_settings.look = look
        sc.view_settings.exposure = exposure
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
        print('RENDERED', path, flush=True)
        return path

    def shot(self, cam, name, res=(1600, 900), samples=56, hide=(), exposure=0.0, look='AgX - Medium High Contrast'):
        """A beauty render (no markers; plan-only outlines hidden)."""
        p = self.render(cam, name, res=res, samples=samples, hide=list(hide) + ['plan_only'], exposure=exposure, look=look)
        os.remove(os.path.join(self.out, f'{name}.json'))
        return p

    def plan_shot(self, name, width=24.0, center=(0, 0), note='', key=None, res=(2000, 1300), samples=40):
        """Top-down plan with the roofs lifted off; writes the anchor JSON for annotate.py."""
        cam = self.plan_view(width, center)
        self.set_sun(200, 62, 3.6)
        self.render(cam, name, res=res, samples=samples, hide=['roof', 'lights'])
        import json
        jp = os.path.join(self.out, f'{name}.json')
        meta = json.load(open(jp))
        meta['note'] = note
        meta['font_scale'] = 1.6
        meta['palette'] = {str(k): v for k, v in PALETTE.items()}
        meta['key'] = key or [['dot', PALETTE[1], 'Water: hot tub, cold plunge, showers, scrub'],
                              ['dot', PALETTE[2], 'Heat: sauna, warm rooms'],
                              ['dot', PALETTE[3], 'Rest and garden'],
                              ['dot', PALETTE[0], 'Structure']]
        json.dump(meta, open(jp, 'w'), indent=1)
