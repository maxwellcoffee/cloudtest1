"""rvkit -- headless-Blender toolkit for the trailer-living setups (where the couple lives while building).

Re-uses the spa toolkit (same lot, terrain, Joshua trees, materials, plants, render + plan annotation) with the
local origin moved to the trailer pad at lot coordinates (48, 40): south-east of the house site in land
Scheme A, so the house going up is in the background of every view.

Trailer local axes: +X is the hitch end, -Y is the curb (door) side. Placed with rot=0 the hitch faces east and
the door faces south (sun and views), and the narrow back end takes the west/south-west wind.
"""
import math, os, sys
os.environ.setdefault('SPA_CENTER', '48,40')
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'gazebo-spa', 'blender'))
import bpy, bmesh  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402
import spakit as SK  # noqa: E402
K = SK.K

FT = 0.3048
PALETTE = {1: (214, 64, 52), 2: (47, 110, 170), 3: (63, 112, 60), 0: (120, 112, 104)}


class Camp(SK.Spa):
    """A Spa scene plus trailers and the gear around them."""

    # ------------------------------------------------------------ materials
    def aluminum(self):
        if 'aluminum' in self.mats:
            return self.mats['aluminum']
        m = bpy.data.materials.new('aluminum')
        m.use_nodes = True
        nt = m.node_tree
        p = nt.nodes['Principled BSDF']
        b = nt.nodes.new('ShaderNodeTexBrick')
        b.offset = 0.0
        b.inputs['Color1'].default_value = K.srgb('#d7dadc')
        b.inputs['Color2'].default_value = K.srgb('#cfd3d6')
        b.inputs['Mortar'].default_value = K.srgb('#9ea3a7')
        b.inputs['Scale'].default_value = 1.0
        b.inputs['Mortar Size'].default_value = 0.004
        b.inputs['Brick Width'].default_value = 1.2
        b.inputs['Row Height'].default_value = 30.0
        tc = nt.nodes.new('ShaderNodeTexCoord')
        nt.links.new(tc.outputs['Object'], b.inputs['Vector'])
        nt.links.new(b.outputs['Color'], p.inputs['Base Color'])
        p.inputs['Metallic'].default_value = 1.0
        p.inputs['Roughness'].default_value = 0.2
        self.mats['aluminum'] = m
        return m

    def tint(self):
        return self.mat('rv_glass', '#14181c', rough=0.05, metal=0.3, spec=0.9, emit='#ffb36b', emit_strength=0.0)

    def set_night(self, on):
        """Also light the trailer windows from inside at dusk."""
        super().set_night(on)
        m = self.mats.get('rv_glass')
        if m:
            m.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = 1.6 if on else 0.0

    # ------------------------------------------------------------ running gear shared by all trailers
    def running_gear(self, root, L, W, axle_x, z_frame, coll, tongue=1.5, tires=0.36):
        tire = self.mat('tire', '#1b1b1b', rough=0.85)
        rim = self.mat('rim', '#c9cccf', rough=0.3, metal=0.9)
        for ax in axle_x:
            for sy in (-1, 1):
                self.cyl('tire', tires, 0.22, (ax, sy * (W / 2 - 0.2), tires), tire, coll, parent=root, seg=32, rot=(math.pi / 2, 0, 0))
                self.cyl('rim', tires * 0.55, 0.23, (ax, sy * (W / 2 - 0.2), tires), rim, coll, parent=root, seg=24, rot=(math.pi / 2, 0, 0))
        steel = self.m('steel_dark')
        # A-frame tongue, jack, propane cylinders and battery box
        for sy in (-1, 1):
            self.beam('tongue', (L / 2 - 0.1, sy * 0.85, z_frame), (L / 2 + tongue, 0, z_frame), (0.1, 0.15), steel, coll, parent=root)
        self.cyl('jack', 0.05, z_frame, (L / 2 + tongue - 0.25, 0, z_frame / 2), steel, coll, parent=root, seg=12)
        self.box('jack_foot', (0.25, 0.25, 0.05), (L / 2 + tongue - 0.25, 0, 0.03), steel, coll, parent=root)
        for sy in (-0.22, 0.22):
            self.cyl('lp', 0.18, 0.62, (L / 2 + 0.55, sy, z_frame + 0.38), self.mat('lp_white', '#eeeeea', rough=0.4), coll, parent=root, seg=20)
        self.box('battery_box', (0.4, 0.6, 0.35), (L / 2 + 0.95, 0, z_frame + 0.25), self.mat('box_black', '#232323', rough=0.6), coll, parent=root)

    # ------------------------------------------------------------ trailers
    def airstream(self, label, x, y, rot=0.0, L=7.6, W=2.59, coll='rv', cat=0):
        """Riveted-aluminium travel trailer (Flying Cloud size): superelliptic section, tapered nose and tail,
        wraparound front window, side windows, roof A/C, door on the curb side."""
        z0 = self.t.h(x, y) if not getattr(self, 'pad_z', None) else self.pad_z
        root = self.empty(label, x, y, z0, rot, coll)
        zb, zt = 0.58, 2.72                     # belly and roof heights above the pad
        nx, nt = 90, 56
        Lt = 1.7
        verts, faces, mats = [], [], []
        xs = np.linspace(-L / 2, L / 2, nx)
        rows = []
        for i, xx in enumerate(xs):
            d = min(xx + L / 2, L / 2 - xx)
            t = min(1.0, d / Lt)
            e = math.sqrt(max(0.0, 1 - (1 - t) ** 2))
            sw = 0.5 + 0.5 * e
            top = zb + (zt - zb) * (0.58 + 0.42 * e)
            bot = zb + 0.06 * (1 - t)
            a, b = W / 2 * sw, (top - bot) / 2
            zc = (top + bot) / 2
            row = []
            for k in range(nt):
                ang = 2 * math.pi * k / nt
                c, s_ = math.cos(ang), math.sin(ang)
                n = 2.4 if s_ > 0 else 5.0
                yy = a * math.copysign(abs(c) ** (2 / n), c)
                zz = zc + b * math.copysign(abs(s_) ** (2 / n), s_)
                row.append(len(verts))
                verts.append((xx, yy, zz))
            rows.append(row)
        dx = xs[1] - xs[0]
        door_x = (-L * 0.08, -L * 0.08 + 0.66)
        for i in range(nx - 1):
            for k in range(nt):
                k2 = (k + 1) % nt
                faces.append((rows[i][k], rows[i + 1][k], rows[i + 1][k2], rows[i][k2]))
                vx = (xs[i] + xs[i + 1]) / 2
                vy, vz = verts[rows[i][k]][1], verts[rows[i][k]][2]
                m = 0
                # wraparound front window (hitch end) and a smaller rear window
                if vx > L / 2 - 1.15 and zb + 1.05 < vz < zb + 1.6 and abs(vy) < W * 0.42:
                    m = 1
                if vx < -L / 2 + 0.7 and zb + 1.2 < vz < zb + 1.55 and abs(vy) < W * 0.25:
                    m = 1
                # side windows
                for (w0, w1) in ((-L * 0.36, -L * 0.22), (-L * 0.02, L * 0.14), (L * 0.2, L * 0.31)):
                    if w0 < vx < w1 and zb + 1.0 < vz < zb + 1.55 and abs(vy) > W * 0.4:
                        m = 1
                if door_x[0] < vx < door_x[1] and vz < zb + 1.9 and vy < -W * 0.4:
                    m = 2
                mats.append(m)
        # end caps
        for row in (rows[0], rows[-1]):
            cx = verts[row[0]][0]
            ci = len(verts)
            verts.append((cx, 0.0, sum(verts[r][2] for r in row) / nt))
            for k in range(nt):
                faces.append((row[k], row[(k + 1) % nt], ci))
                mats.append(0)
        me = bpy.data.meshes.new('airstream')
        me.from_pydata(verts, [], faces)
        me.update()
        me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
        me.polygons.foreach_set('material_index', mats)
        for mm in (self.aluminum(), self.tint(), self.mat('door_alu', '#b9bdc0', rough=0.3, metal=1.0)):
            me.materials.append(mm)
        ob = bpy.data.objects.new('airstream', me)
        ob.parent = root
        self.link(ob, coll)
        # belly band, roof A/C, awning, door handle, steps
        self.box('belly', (L - 1.4, W * 0.9, 0.12), (0, 0, zb + 0.02), self.mat('belly', '#6d7175', rough=0.5, metal=0.6), coll, parent=root)
        self.box('roof_ac', (0.75, 0.7, 0.28), (-0.4, 0, zt + 0.12), self.mat('ac_white', '#f2f2ef', rough=0.4), coll, parent=root, bevel=0.08, seg=3)
        self.box('roof_ac2', (0.75, 0.7, 0.26), (1.8, 0, zt + 0.1), self.mat('ac_white', '#f2f2ef', rough=0.4), coll, parent=root, bevel=0.08, seg=3)
        self.cyl('awning_roll', 0.07, L * 0.62, (-L * 0.02, -W / 2 - 0.02, zt - 0.32), self.mat('awning_case', '#e9e9e6', rough=0.3, metal=0.5), coll, parent=root, seg=16, rot=(0, math.pi / 2, 0))
        self.box('door_handle', (0.12, 0.04, 0.04), (door_x[0] + 0.12, -W / 2 - 0.02, zb + 0.95), self.m('steel'), coll, parent=root)
        self.running_gear(root, L, W, (-0.45, 0.45), zb - 0.02, coll, tongue=1.45)
        self.foot(x, y, L / 2 + 2.5, W / 2 + 2.0)
        self.anchor(label, x, y, z0, cat, dz=zt + 0.6)
        return root

    def box_trailer(self, label, x, y, rot=0.0, L=9.0, W=2.44, H=2.9, coll='rv', style='modern', slide=True, cat=0, awning_open=False):
        """Conventional laminated travel trailer: fiberglass front cap, slide-out on the street side,
        two roof A/Cs. style: 'modern' (white + charcoal graphics) or 'classic' (cream + brown swirl, older used unit)."""
        z0 = self.t.h(x, y) if not getattr(self, 'pad_z', None) else self.pad_z
        root = self.empty(label, x, y, z0, rot, coll)
        zb = 0.62
        zt = zb + H
        # side profile (x, z), extruded across the width
        prof = [(-L / 2, zb), (-L / 2, zt - 0.08), (-L / 2 + 0.08, zt), (L / 2 - 1.0, zt), (L / 2 - 0.45, zt - 0.18),
                (L / 2 - 0.12, zt - 0.75), (L / 2, zt - 1.4), (L / 2, zb + 0.35), (L / 2 - 0.25, zb)]
        bm = bmesh.new()
        vs = [bm.verts.new((px, -W / 2, pz)) for (px, pz) in prof]
        f = bm.faces.new(vs)
        r = bmesh.ops.extrude_face_region(bm, geom=[f])
        bmesh.ops.translate(bm, vec=Vector((0, W, 0)), verts=[v for v in r['geom'] if isinstance(v, bmesh.types.BMVert)])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        body_col = '#f3f2ee' if style == 'modern' else '#efe6d4'
        ob = self.mesh_obj('trailer_body', bm, [self.mat('gelcoat_' + style, body_col, rough=0.3)], coll, parent=root)
        mod = ob.modifiers.new('bevel', 'BEVEL')
        mod.width = 0.07
        mod.segments = 3
        mod.limit_method = 'ANGLE'
        ob.data.polygons.foreach_set('use_smooth', [True] * len(ob.data.polygons))
        # graphics on both sides
        g1 = self.mat('graphic1_' + style, '#2c2d2f' if style == 'modern' else '#8a5a3a', rough=0.4)
        g2 = self.mat('graphic2_' + style, '#8d9196' if style == 'modern' else '#c79a63', rough=0.4)
        for sy in (-1, 1):
            yy = sy * (W / 2 + 0.006)
            self.box('stripe', (L * 0.55, 0.01, 0.16), (L * 0.18, yy, zb + 0.55), g1, coll, parent=root, rot=(0, math.radians(4), 0))
            self.box('stripe', (L * 0.35, 0.01, 0.08), (L * 0.28, yy, zb + 0.82), g2, coll, parent=root, rot=(0, math.radians(7), 0))
            self.box('skirt_band', (L - 0.3, 0.01, 0.3), (-0.1, yy, zb + 0.15), g1, coll, parent=root)
            for (wx, ww) in ((-L * 0.32, 1.2), (L * 0.22, 0.8)):
                self.box('window', (ww, 0.02, 0.75), (wx, yy, zb + 1.75), self.tint(), coll, parent=root, bevel=0.04, seg=2)
        self.box('front_window', (0.03, W * 0.8, 0.45), (L / 2 - 0.05, 0, zt - 1.05), self.tint(), coll, parent=root, rot=(0, math.radians(-25), 0))
        # door (curb side, -Y) and entry step
        self.box('door', (0.68, 0.03, 1.9), (-L * 0.05, -W / 2 - 0.01, zb + 0.98), self.mat('door_' + style, body_col, rough=0.3), coll, parent=root)
        self.box('door_win', (0.4, 0.035, 0.5), (-L * 0.05, -W / 2 - 0.02, zb + 1.55), self.tint(), coll, parent=root)
        self.box('step', (0.62, 0.35, 0.05), (-L * 0.05, -W / 2 - 0.25, zb - 0.25), self.m('steel_dark'), coll, parent=root)
        if slide:
            self.box('slide', (3.3, 0.55, 1.9), (-L * 0.12, W / 2 + 0.25, zb + 1.1), self.mat('gelcoat_' + style, body_col, rough=0.3), coll, parent=root, bevel=0.03, seg=2)
            self.box('slide_win', (1.3, 0.02, 0.7), (-L * 0.12, W / 2 + 0.53, zb + 1.35), self.tint(), coll, parent=root)
        for ax in (-L * 0.3, L * 0.3):
            self.box('roof_ac', (0.75, 0.72, 0.3), (ax, 0, zt + 0.13), self.mat('ac_white', '#f2f2ef', rough=0.4), coll, parent=root, bevel=0.06, seg=2)
        self.box('ladder', (0.04, 0.42, H - 0.2), (-L / 2 - 0.05, 0.6, zb + H / 2), self.m('steel'), coll, parent=root)
        # awning: rolled case, or open (striped fabric on arms)
        self.box('awning_case', (L * 0.55, 0.12, 0.12), (0.2, -W / 2 - 0.08, zt - 0.2), self.mat('awning_case', '#e9e9e6', rough=0.3, metal=0.5), coll, parent=root)
        if awning_open:
            fab = self.mat_grain('awning_fabric', '#2b2b2b', '#e8e2d8', 'X', 1.6, rough=0.9)
            aw = self.box('awning', (L * 0.55, 2.4, 0.02), (0.2, -W / 2 - 1.25, zt - 0.45), fab, coll, parent=root)
            aw.rotation_euler = (math.radians(-10), 0, 0)
            for ax in (0.2 - L * 0.27, 0.2 + L * 0.27):
                self.beam('awning_arm', (ax, -W / 2 - 0.05, zb + 0.1), (ax, -W / 2 - 2.4, zt - 0.66), (0.05, 0.05), self.m('steel'), coll, parent=root)
        self.running_gear(root, L, W, (-0.55, 0.55) if L < 9.5 else (-0.65, 0.65), zb - 0.04, coll, tongue=1.4)
        self.foot(x, y, L / 2 + 2.5, W / 2 + 2.5)
        self.anchor(label, x, y, z0, cat, dz=zt + 0.6)
        return root

    def egg_trailer(self, label, x, y, rot=0.0, L=7.3, W=2.13, coll='rv', cat=0):
        """Double-hull fiberglass trailer (Oliver size): smooth white shell, black window band."""
        z0 = self.t.h(x, y) if not getattr(self, 'pad_z', None) else self.pad_z
        root = self.empty(label, x, y, z0, rot, coll)
        zb, zt = 0.62, 2.75
        body = self.box('shell', (L, W, zt - zb), (0, 0, (zb + zt) / 2), self.mat('fiberglass', '#f6f5f2', rough=0.18), coll, parent=root, bevel=0.75, seg=8)
        self.box('band', (L * 0.86, W + 0.04, 0.5), (0.1, 0, zb + 1.35), self.tint(), coll, parent=root, bevel=0.22, seg=4)
        self.box('roof_ac', (0.7, 0.65, 0.26), (-0.6, 0, zt + 0.08), self.mat('ac_white', '#f2f2ef', rough=0.4), coll, parent=root, bevel=0.06, seg=2)
        self.box('door', (0.6, 0.03, 1.7), (-L * 0.12, -W / 2 - 0.01, zb + 0.9), self.mat('fiberglass', '#f6f5f2', rough=0.18), coll, parent=root)
        self.running_gear(root, L, W, (-0.4, 0.4), zb - 0.04, coll, tongue=1.3, tires=0.38)
        self.foot(x, y, L / 2 + 2.5, W / 2 + 2.0)
        self.anchor(label, x, y, z0, cat, dz=zt + 0.6)
        return root

    # ------------------------------------------------------------ the camp around the trailer
    def pad_gravel(self, w, l, x=0.0, y=0.0):
        """Level, compacted crushed-rock pad. Sets self.pad_z (trailers stand on it)."""
        self.e = self.pad(x, y, w + 3, l + 3, 0.0, coll='camp', surface=None)
        self.z = self.e
        self.pad_z = self.e + 0.06
        self._poly('gravel_pad', x, y, w, l, 0.0, self.mat('crushed_rock', '#cdbfa8', rough=1.0), 'camp', step=0.6, off=0.06)
        self.foot(x, y, w / 2 + 1.5, l / 2 + 1.5)
        return self.pad_z

    def rv_cover(self, label, x, y, L=12.5, W=7.3, H=4.27, color='#e9e9e6', cat=0, coll='camp', gable=0.5):
        """Steel RV cover / carport: legs every ~1.5 m, A-frame vertical-panel roof."""
        z = self.pad_z
        frame = self.mat('cover_frame_' + color, color, rough=0.45, metal=0.6)
        roofm = self.mat('cover_roof_' + color, color, rough=0.35, metal=0.5)
        n = int(L / 1.5) + 1
        for i in range(n):
            xx = x - L / 2 + i * L / (n - 1)
            for sy in (-1, 1):
                self.box('leg', (0.08, 0.08, H), (xx, y + sy * W / 2, z + H / 2), frame, coll)
            self.beam('truss', (xx, y - W / 2, z + H), (xx, y, z + H + gable), (0.06, 0.1), frame, coll)
            self.beam('truss', (xx, y + W / 2, z + H), (xx, y, z + H + gable), (0.06, 0.1), frame, coll)
            self.box('tie', (0.05, W, 0.05), (xx, y, z + H - 0.05), frame, coll)
        ang = math.atan2(gable, W / 2)
        for sy in (-1, 1):
            self.box('roof_panel', (L + 0.3, W / 2 / math.cos(ang) + 0.25, 0.03),
                     (x, y + sy * (W / 4 + 0.1), z + H + gable / 2 + 0.06), roofm, 'roof', rot=(-sy * ang, 0, 0))
            self.box('rail', (L, 0.06, 0.12), (x, y + sy * W / 2, z + H), frame, coll)
        self.foot(x, y, L / 2 + 1.0, W / 2 + 1.0)
        self.anchor(label, x, y - W / 2, z, cat, dz=H + 0.4)

    def shade_ramada(self, label, x, y, L=12.0, W=7.0, H=4.0, cat=0, coll='camp'):
        """Modern black steel shade ramada with a flat roof and slatted west end."""
        z = self.pad_z
        blk = self.mat('ramada_black', '#1f1f20', rough=0.5, metal=0.5)
        for xx in (x - L / 2, x - L / 6, x + L / 6, x + L / 2):
            for sy in (-1, 1):
                self.box('col', (0.15, 0.15, H), (xx, y + sy * W / 2, z + H / 2), blk, coll)
        for sy in (-1, 1):
            self.box('beam', (L + 0.3, 0.15, 0.3), (x, y + sy * W / 2, z + H + 0.15), blk, coll)
        self.box('roof', (L + 0.8, W + 0.8, 0.12), (x, y, z + H + 0.36), self.mat('ramada_roof', '#2a2a2b', rough=0.5, metal=0.4), 'roof')
        for k in range(int(W / 0.25)):
            self.box('slat', (0.05, 0.12, H - 0.6), (x - L / 2 - 0.1, y - W / 2 + 0.2 + k * 0.25, z + 0.3 + (H - 0.6) / 2), self.m('cedar_plain'), coll)
        self.foot(x, y, L / 2 + 1.0, W / 2 + 1.0)
        self.anchor(label, x, y - W / 2, z, cat, dz=H + 0.5)

    def shade_sail(self, label, pts, posts_h=(3.6, 2.6, 3.6, 2.6), color='#efe9df', cat=0, coll='camp'):
        """Tensioned four-corner shade sail on steel posts."""
        z = self.pad_z
        corners = [Vector((px, py, z + h)) for (px, py), h in zip(pts, posts_h)]
        for (px, py), h in zip(pts, posts_h):
            self.cyl('sail_post', 0.06, h + 0.3, (px, py, z + (h + 0.3) / 2), self.m('steel_dark'), coll, seg=12)
        n = 10
        verts, faces = [], []
        for j in range(n + 1):
            for i in range(n + 1):
                u, v = i / n, j / n
                p = corners[0] * (1 - u) * (1 - v) + corners[1] * u * (1 - v) + corners[2] * u * v + corners[3] * (1 - u) * v
                p.z -= 0.25 * math.sin(math.pi * u) * math.sin(math.pi * v)
                verts.append(tuple(p))
        for j in range(n):
            for i in range(n):
                a = j * (n + 1) + i
                faces.append((a, a + 1, a + n + 2, a + n + 1))
        self.mesh_from('sail', verts, faces, self.mat('sail_' + color, color, rough=0.9), 'roof', smooth=True)
        cx = sum(p[0] for p in pts) / 4
        cy = sum(p[1] for p in pts) / 4
        self.anchor(label, cx, cy, z, cat, dz=3.4)

    def skirting(self, x, y, L, W, h=0.6, coll='camp', color='#d9d3c7'):
        z = self.pad_z
        m = self.mat('skirt_' + color, color, rough=0.8)
        for sy in (-1, 1):
            self.box('skirt', (L - 0.6, 0.03, h), (x, y + sy * (W / 2 - 0.02), z + h / 2), m, coll)
        for sx in (-1, 1):
            self.box('skirt', (0.03, W - 0.04, h), (x + sx * (L / 2 - 0.3), y, z + h / 2), m, coll)

    def free_deck(self, label, x, y, w=3.66, d=2.44, h=0.55, rails=False, mat='cedar_y', cat=3, coll='camp'):
        """Freestanding deck at the door (not attached to the trailer) with steps down the front."""
        z = self.pad_z
        root = self.empty('deck', x, y, z, 0, coll)
        n = int(w / 0.15)
        for i in range(n):
            self.box('deckboard', (0.135, d, 0.04), (-w / 2 + (i + 0.5) * w / n, 0, h - 0.02), self.m(mat), coll, parent=root)
        self.box('deck_frame', (w, d, h - 0.04), (0, 0, (h - 0.04) / 2), self.m('timber'), coll, parent=root)
        for k in range(2):
            self.box('deck_step', (1.4, 0.32, h * (k + 1) / 3), (0, -d / 2 - 0.16 - 0.32 * (1 - k), h * (k + 1) / 6), self.m(mat), coll, parent=root)
        if rails:
            for sx in (-1, 1):
                self.box('rail', (0.04, d, 0.04), (sx * w / 2, 0, h + 0.95), self.m('timber'), coll, parent=root)
                for k in range(5):
                    self.box('baluster', (0.04, 0.04, 0.95), (sx * w / 2, -d / 2 + k * d / 4, h + 0.47), self.m('timber'), coll, parent=root)
        self.foot(x, y, w / 2 + 0.8, d / 2 + 1.2)
        self.anchor(label, x, y, z, cat, dz=h + 0.8)
        return z + h

    def water_tank(self, label, x, y, r=1.0, h=2.0, color='#2d2f2c', cat=2, coll='camp'):
        z = self.pad_z if abs(x) < 12 and abs(y) < 12 else self.t.h(x, y)
        m = self.mat('poly_' + color, color, rough=0.55)
        self.cyl('water_tank', r, h, (x, y, z + h / 2), m, coll, seg=40)
        self.cyl('tank_dome', r, 0.25, (x, y, z + h + 0.12), m, coll, seg=40, r2=r * 0.4)
        self.cyl('tank_lid', 0.2, 0.06, (x, y, z + h + 0.27), m, coll, seg=20)
        self.box('pump_box', (0.5, 0.4, 0.45), (x + r + 0.35, y, z + 0.22), self.mat('box_black', '#232323', rough=0.6), coll)
        self.foot(x, y, r + 0.8)
        self.anchor(label, x, y, z, cat, dz=h + 0.6)

    def propane_tank(self, label, x, y, rot=0.0, L=2.3, r=0.38, cat=2, coll='camp'):
        z = self.t.h(x, y)
        root = self.empty('lp_tank', x, y, z, rot, coll)
        wht = self.mat('lp_white', '#eeeeea', rough=0.4)
        self.cyl('lp_tank', r, L - 2 * r, (0, 0, r + 0.35), wht, coll, parent=root, seg=32, rot=(0, math.pi / 2, 0))
        for sx in (-1, 1):
            self.lathe('lp_end', [(r, 0.0), (r * 0.85, 0.18), (r * 0.5, 0.3), (0.0, 0.34)], (sx * (L / 2 - r), 0, r + 0.35), wht, coll, seg=32, parent=root).rotation_euler = (0, sx * math.pi / 2, 0)
        for sx in (-0.5, 0.5):
            self.box('lp_leg', (0.1, 0.5, 0.35), (sx, 0, 0.18), wht, coll, parent=root)
        self.cyl('lp_dome', 0.12, 0.12, (0, 0, 2 * r + 0.38), self.m('steel'), coll, parent=root, seg=16)
        self.foot(x, y, L / 2 + 0.8, r + 0.8)
        self.anchor(label, x, y, z, cat, dz=1.4)

    def solar_array(self, label, x, y, cols=6, rows=2, tilt=25, cat=2, coll='camp'):
        z = self.t.h(x, y)
        pv = self.mat_tile('pv_cells', '#1c2638', '#202c42', '#7f8ea6', 0.16, 0.04, rough=0.2)
        frame = self.m('steel')
        pw, ph = 1.05, 1.75
        for r in range(rows):
            yy = y + (r - (rows - 1) / 2) * (ph * math.cos(math.radians(tilt)) + 1.4)
            self.box('pv_row', (cols * pw, ph * rows / rows, 0.04), (x, yy, z + 1.2), pv, coll, rot=(math.radians(tilt), 0, 0))
            for c in range(0, cols + 1, 2):
                px = x - cols * pw / 2 + c * pw
                self.box('pv_leg', (0.06, 0.06, 0.9), (px, yy - 0.6, z + 0.45), frame, coll)
                self.box('pv_leg', (0.06, 0.06, 1.65), (px, yy + 0.6, z + 0.82), frame, coll)
        self.box('inverter', (0.6, 0.3, 0.9), (x + cols * pw / 2 + 0.6, y, z + 0.6), self.mat('inverter_white', '#e7e7e3', rough=0.4), coll)
        self.foot(x, y, cols * pw / 2 + 1.2, rows * 1.8)
        self.anchor(label, x, y, z, cat, dz=2.4)

    def power_pole(self, label, x, y, cat=2, coll='camp'):
        """Temporary power: pedestal with a 50 A RV outlet (meter on a pole where grid power is used)."""
        z = self.t.h(x, y)
        self.cyl('pole', 0.13, 6.0, (x, y, z + 3.0), self.mat('pole_wood', '#6b5a48', rough=0.9), coll, seg=12)
        self.box('meter', (0.35, 0.25, 0.6), (x, y - 0.18, z + 1.6), self.mat('meter_grey', '#a6aaa9', rough=0.4, metal=0.6), coll)
        self.box('pedestal', (0.3, 0.3, 1.1), (x + 0.7, y - 0.3, z + 0.55), self.mat('pedestal_grey', '#8f9395', rough=0.4, metal=0.5), coll)
        self.anchor(label, x, y, z, cat, dz=6.4)

    def starlink(self, x, y, h=2.2, coll='camp'):
        z = self.t.h(x, y)
        self.cyl('dish_pole', 0.03, h, (x, y, z + h / 2), self.m('steel'), coll, seg=10)
        self.box('dish', (0.5, 0.3, 0.03), (x, y, z + h + 0.05), self.mat('dish_white', '#f1f1ee', rough=0.4), coll, rot=(math.radians(-25), 0, 0))

    def generator(self, x, y, coll='camp'):
        z = self.pad_z
        self.box('generator', (0.52, 0.3, 0.45), (x, y, z + 0.23), self.mat('gen_red', '#b3241b', rough=0.4), coll, bevel=0.04, seg=2)

    def storage_shed(self, label, x, y, rot=0.0, w=3.66, d=3.05, h=2.6, color='#1f1f20', door='#df4537', cat=0, coll='camp'):
        """120 sq ft storage shed (10 x 12 ft): no permit needed in the County if no utilities and under 14 ft."""
        z = self.t.h(x, y)
        root = self.empty('shed', x, y, z, rot, coll)
        self.box('shed_base', (w + 0.1, d + 0.1, 0.15), (0, 0, 0.075), self.m('stone_dark'), coll, parent=root)
        self.box('shed', (w, d, h), (0, 0, h / 2 + 0.15), self.mat('shed_' + color, color, rough=0.6), coll, parent=root)
        self.box('shed_roof', (w + 0.35, d + 0.45, 0.12), (0, 0, h + 0.25), self.mat('shed_roof', '#2b2b2c', rough=0.5, metal=0.4), coll, parent=root, rot=(math.radians(-4), 0, 0))
        self.box('shed_door', (1.5, 0.04, 2.0), (0, -d / 2 - 0.02, 1.15), self.mat('shed_door_' + door, door, rough=0.4), coll, parent=root)
        self.foot(x, y, w / 2 + 1.0, d / 2 + 1.2)
        self.anchor(label, x, y, z, cat, dz=h + 0.6)

    def house_frame(self, label, x, y, W=9.75, D=6.1, H=3.05, cat=0, coll='house'):
        """The permitted house under construction: slab, stud walls, top plates and a few roof joists."""
        e = self.pad(x, y, W + 7, D + 7, 0.0, coll='house', surface=None)
        root = self.empty('house_frame', x, y, e, 0.0, coll)
        conc = self.mat('slab', '#c7c1b6', rough=0.8)
        stud = self.mat('fir', '#d6b98d', rough=0.7)
        self.box('slab', (W + 0.3, D + 0.3, 0.35), (0, 0, 0.175), conc, coll, parent=root)
        for (p1, p2) in (((-W / 2, -D / 2), (W / 2, -D / 2)), ((W / 2, -D / 2), (W / 2, D / 2)), ((W / 2, D / 2), (-W / 2, D / 2)), ((-W / 2, D / 2), (-W / 2, -D / 2))):
            L = math.hypot(p2[0] - p1[0], p2[1] - p1[1])
            ang = math.atan2(p2[1] - p1[1], p2[0] - p1[0])
            n = int(L / 0.406)
            for k in range(n + 1):
                t = k / n
                px, py = p1[0] + (p2[0] - p1[0]) * t, p1[1] + (p2[1] - p1[1]) * t
                if abs(p1[1] - p2[1]) < 1e-6 and p1[1] < 0 and 0.15 < t < 0.85 and k % 3:
                    continue                    # big south openings
                self.box('stud', (0.09, 0.09, H), (px, py, 0.35 + H / 2), stud, coll, parent=root, rot=(0, 0, ang))
            for zz in (0.35 + H, 0.35 + H + 0.05):
                self.box('plate', (L, 0.09, 0.045), ((p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2, zz), stud, coll, parent=root, rot=(0, 0, ang))
        for k in range(0, int(W / 0.61) + 1, 1):
            if k > int(W / 0.61) * 0.6:
                break
            self.box('joist', (0.05, D + 2.2, 0.28), (-W / 2 + k * 0.61, -1.0, 0.35 + H + 0.2), stud, coll, parent=root)
        self.box('lumber_stack', (3.0, 1.2, 0.5), (W / 2 + 2.0, D / 2 + 1.5, 0.25), stud, coll, parent=root)
        self.foot(x, y, W / 2 + 3, D / 2 + 3)
        self.anchor(label, x, y, e, cat, dz=H + 1.2)
        return root

    def bistro_set(self, x, y, coll='camp', z=None):
        z = self.pad_z if z is None else z
        self.cyl('bistro_top', 0.38, 0.03, (x, y, z + 0.74), self.m('timber'), coll, seg=24)
        self.cyl('bistro_leg', 0.03, 0.72, (x, y, z + 0.37), self.m('timber'), coll, seg=8)
        for a in (0.3, 3.4):
            cx, cy = x + 0.6 * math.cos(a), y + 0.6 * math.sin(a)
            self.box('chair_seat', (0.42, 0.42, 0.05), (cx, cy, z + 0.45), self.m('coral'), coll)
            self.box('chair_back', (0.42, 0.04, 0.4), (cx + 0.2 * math.cos(a), cy + 0.2 * math.sin(a), z + 0.68), self.m('coral'), coll, rot=(0, 0, a + math.pi / 2))
            for (lx, ly) in ((-0.17, -0.17), (0.17, -0.17), (-0.17, 0.17), (0.17, 0.17)):
                self.box('chair_leg', (0.03, 0.03, 0.44), (cx + lx, cy + ly, z + 0.22), self.m('steel_dark'), coll)

    def plan_shot(self, name, width=24.0, center=(0, 0), note='', key=None, res=(2000, 1300), samples=40):
        key = key or [['dot', PALETTE[0], 'Trailer + shelter'], ['dot', PALETTE[2], 'Water, power, propane, internet'],
                      ['dot', PALETTE[3], 'Outdoor living'], ['dot', PALETTE[1], 'Storage']]
        super().plan_shot(name, width=width, center=center, note=note, key=key, res=res, samples=samples)
        import json
        jp = os.path.join(self.out, f'{name}.json')
        meta = json.load(open(jp))
        meta['palette'] = {str(k): v for k, v in PALETTE.items()}
        json.dump(meta, open(jp, 'w'), indent=1)
