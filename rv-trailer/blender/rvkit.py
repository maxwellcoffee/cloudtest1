"""rvkit -- headless-Blender toolkit for the trailer-living setups (where the couple lives while building).

Re-uses the spa toolkit (same lot, terrain, Joshua trees, materials, plants, render + plan annotation) with the
local origin moved to the trailer pad at lot coordinates (48, 40): south-east of the house site in land
Scheme A, so the house going up is in the background of every view.

Trailer local axes: +X is the hitch end, -Y is the curb (door) side. Placed with rot=0 the hitch faces east and
the door faces south (sun and views), and the narrow back end takes the west/south-west wind.
Lengths passed to the trailer builders are BODY lengths; overall length adds the A-frame tongue (about 1.1 m).
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
    def tint(self):
        return self.mat('rv_glass', '#14181c', rough=0.05, metal=0.3, spec=0.9, emit='#ffb36b', emit_strength=0.0)

    def gravel_mat(self):
        """Decomposed-granite / crushed-rock pad with a speckled texture."""
        if 'crushed_rock' in self.mats:
            return self.mats['crushed_rock']
        m = bpy.data.materials.new('crushed_rock')
        m.use_nodes = True
        nt = m.node_tree
        p = nt.nodes['Principled BSDF']
        v = nt.nodes.new('ShaderNodeTexVoronoi')
        v.inputs['Scale'].default_value = 28.0
        tc = nt.nodes.new('ShaderNodeTexCoord')
        nt.links.new(tc.outputs['Object'], v.inputs['Vector'])
        r = nt.nodes.new('ShaderNodeValToRGB')
        r.color_ramp.elements[0].color = K.srgb('#a8977f')
        r.color_ramp.elements[1].position = 0.75
        r.color_ramp.elements[1].color = K.srgb('#d3c4ab')
        nt.links.new(v.outputs['Color'], r.inputs['Fac'])
        nt.links.new(r.outputs['Color'], p.inputs['Base Color'])
        bmp = nt.nodes.new('ShaderNodeBump')
        bmp.inputs['Strength'].default_value = 0.35
        nt.links.new(v.outputs['Distance'], bmp.inputs['Height'])
        nt.links.new(bmp.outputs['Normal'], p.inputs['Normal'])
        p.inputs['Roughness'].default_value = 1.0
        self.mats['crushed_rock'] = m
        return m

    def set_night(self, on):
        """Also light the trailer windows from inside at dusk."""
        super().set_night(on)
        m = self.mats.get('rv_glass')
        if m:
            m.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = 1.1 if on else 0.0
        for k in ('shell_airstream', 'shell_oliver'):
            if k in self.mats:
                self.mats[k].node_tree.nodes['glass'].inputs['Emission Strength'].default_value = 1.1 if on else 0.0

    # ------------------------------------------------------------ running gear shared by all trailers
    def running_gear(self, root, L, W, axle_x, z_frame, coll, tongue=1.1, tires=0.36):
        tire = self.mat('tire', '#1b1b1b', rough=0.85)
        rim = self.mat('rim', '#c9cccf', rough=0.3, metal=0.9)
        for ax in axle_x:
            for sy in (-1, 1):
                self.cyl('tire', tires, 0.22, (ax, sy * (W / 2 - 0.2), tires), tire, coll, parent=root, seg=32, rot=(math.pi / 2, 0, 0))
                self.cyl('rim', tires * 0.55, 0.23, (ax, sy * (W / 2 - 0.2), tires), rim, coll, parent=root, seg=24, rot=(math.pi / 2, 0, 0))
        steel = self.m('steel_dark')
        for sy in (-1, 1):
            self.beam('tongue', (L / 2 - 0.1, sy * 0.85, z_frame), (L / 2 + tongue, 0, z_frame), (0.1, 0.15), steel, coll, parent=root)
        self.cyl('jack', 0.05, z_frame, (L / 2 + tongue - 0.25, 0, z_frame / 2), steel, coll, parent=root, seg=12)
        self.box('jack_foot', (0.25, 0.25, 0.05), (L / 2 + tongue - 0.25, 0, 0.03), steel, coll, parent=root)
        for sy in (-0.22, 0.22):
            self.cyl('lp', 0.18, 0.62, (L / 2 + 0.45, sy, z_frame + 0.38), self.mat('lp_white', '#eeeeea', rough=0.4), coll, parent=root, seg=20)
        self.box('battery_box', (0.4, 0.6, 0.35), (L / 2 + 0.85, 0, z_frame + 0.25), self.mat('box_black', '#232323', rough=0.6), coll, parent=root)
        # stabilizer jacks at the corners
        for sx in (-1, 1):
            for sy in (-1, 1):
                self.box('stab_jack', (0.06, 0.06, z_frame), (sx * (L / 2 - 0.5), sy * (W / 2 - 0.35), z_frame / 2), steel, coll, parent=root)
                self.box('stab_pad', (0.2, 0.2, 0.04), (sx * (L / 2 - 0.5), sy * (W / 2 - 0.35), 0.02), self.mat('pad_wood', '#7a6650', rough=0.9), coll, parent=root)

    def entry_steps(self, root, x, y, z_floor, coll, n=3):
        """Fold-down entry steps under a curb-side door at local (x, y)."""
        steel = self.m('steel_dark')
        for i in range(n):
            zz = z_floor - (i + 1) * z_floor / (n + 0.5)
            self.box('tread', (0.6, 0.26, 0.04), (x, y - 0.13 - i * 0.24, zz), self.mat('tread_grey', '#55585b', rough=0.6, metal=0.6), coll, parent=root)
        self.beam('step_rail', (x - 0.32, y - 0.05, z_floor), (x - 0.32, y - 0.05 - n * 0.24, 0.12), (0.03, 0.03), steel, coll, parent=root)

    # ------------------------------------------------------------ lofted shells (Airstream, molded fiberglass)
    def shell_trailer(self, label, x, y, rot=0.0, L=6.7, W=2.59, kind='airstream', coll='rv', cat=0):
        """Lofted trailer shell. kind='airstream': riveted aluminium, superelliptic section, long tapered ends.
        kind='oliver': two-tone molded fiberglass, boxier section, raised front, gray lower shell and seam.
        Windows, door and trim are face groups chosen on the loft grid, so their edges follow the shell."""
        z0 = self.t.h(x, y) if not getattr(self, 'pad_z', None) else self.pad_z
        root = self.empty(label, x, y, z0, rot, coll)
        air = kind == 'airstream'
        zb, zt = (0.58, 2.72) if air else (0.62, 2.62)
        nx, nt = (110, 64) if air else (90, 64)
        Lf, Lr = (1.9, 1.9) if air else (1.1, 0.9)
        xs = np.linspace(-L / 2, L / 2, nx)
        rows, verts = [], []
        for xx in xs:
            df, dr = L / 2 - xx, xx + L / 2
            if df < Lf:
                t = df / Lf
            elif dr < Lr:
                t = dr / Lr
            else:
                t = 1.0
            e = math.sqrt(max(0.0, 1 - (1 - t) ** 2))
            if air:
                sw, tf, lift = 0.16 + 0.84 * e, 0.4 + 0.6 * e, 0.10 * (1 - t)
            else:
                sw, tf, lift = 0.55 + 0.45 * e, (0.72 if df < Lf else 0.62) + (0.28 if df < Lf else 0.38) * e, 0.12 * (1 - t)
            top = zb + (zt - zb) * tf
            bot = zb + lift
            a, b = W / 2 * sw, (top - bot) / 2
            zc = (top + bot) / 2
            row = []
            for k in range(nt):
                ang = 2 * math.pi * k / nt
                c, s_ = math.cos(ang), math.sin(ang)
                nexp = (2.4 if s_ > 0 else 5.0) if air else (3.2 if s_ > 0 else 6.0)
                yy = a * math.copysign(abs(c) ** (2 / nexp), c)
                zz = zc + b * math.copysign(abs(s_) ** (2 / nexp), s_)
                row.append(len(verts))
                verts.append((xx, yy, zz))
            rows.append(row)
        # side faces wound (k, k+1, i+1) so normals point out; windows, door and trim are painted by the shell
        # shader from object position + normal, so their edges stay smooth and rounded on the curved skin
        quads = [(rows[i][k], rows[i][(k + 1) % nt], rows[i + 1][(k + 1) % nt], rows[i + 1][k]) for i in range(nx - 1) for k in range(nt)]
        faces = list(quads)
        d0, d1 = -L * 0.12, -L * 0.12 + 0.66
        if air:
            wz = (zb + 1.18, zb + 1.72)
            rects = [((-L * 0.36, -L * 0.2), wz, 0.1), ((-L * 0.0, L * 0.12), wz, 0.1), ((L * 0.17, L * 0.27), wz, 0.1)]
            band = (zb + 1.02, zb + 1.5)
        else:
            wz = (zb + 1.08, zb + 1.6)
            rects = [((-L * 0.34, -L * 0.15), wz, 0.14), ((L * 0.06, L * 0.22), wz, 0.14)]
            band = (zb + 1.0, zb + 1.55)
        shell = self.shell_material(kind, L, W, zb, rects, band, door=((d0, d1), (zb + 0.06, zb + 1.86), 0.08),
                                    door_win=((d0 + 0.16, d1 - 0.16), (zb + 1.22, zb + 1.62), 0.06))
        for row, sign in ((rows[0], -1), (rows[-1], 1)):
            cx = verts[row[0]][0] + sign * (0.06 if air else 0.03)
            ci = len(verts)
            verts.append((cx, 0.0, sum(verts[r][2] for r in row) / nt))
            for k in range(nt):
                faces.append((row[k], row[(k + 1) % nt], ci) if sign > 0 else (row[(k + 1) % nt], row[k], ci))
        me = bpy.data.meshes.new(kind)
        me.from_pydata(verts, [], faces)
        me.update()
        me.polygons.foreach_set('use_smooth', [True] * len(me.polygons))
        me.materials.append(shell)
        ob = bpy.data.objects.new(kind, me)
        ob.parent = root
        self.link(ob, coll)
        sub = ob.modifiers.new('smooth', 'SUBSURF')
        sub.levels = 1
        sub.render_levels = 1
        # belly, roof A/C, awning case, door handle, steps
        if air:
            self.box('belly', (L - 1.6, W * 0.86, 0.12), (0, 0, zb + 0.03), self.mat('belly', '#6d7175', rough=0.5, metal=0.6), coll, parent=root)
            self.cyl('awning_roll', 0.07, L * 0.6, (-L * 0.02, -W / 2 - 0.02, zt - 0.3), self.mat('awning_case', '#e9e9e6', rough=0.3, metal=0.5), coll, parent=root, seg=16, rot=(0, math.pi / 2, 0))
        ac = self.mat('ac_white', '#f2f2ef', rough=0.4)
        self.box('roof_ac', (0.75, 0.7, 0.26), (-0.4, 0, zt + 0.1), ac, coll, parent=root, bevel=0.08, seg=3)
        self.box('door_handle', (0.14, 0.05, 0.04), (d0 + 0.12, -W / 2 - 0.03, zb + 0.95), self.m('steel'), coll, parent=root)
        self.entry_steps(root, (d0 + d1) / 2, -W / 2 + 0.05, zb, coll)
        self.running_gear(root, L, W, (-0.45, 0.45) if air else (-0.35, 0.35), zb - 0.02, coll, tongue=1.15, tires=0.36 if air else 0.38)
        self.foot(x, y, L / 2 + 2.5, W / 2 + 2.0)
        self.anchor(label, x, y, z0, cat, dz=zt + 0.6)
        self.door_world = self._local_to_world(root, ((d0 + d1) / 2, -W / 2, zb))
        return root

    def shell_material(self, kind, L, W, zb, rects, band, door, door_win):
        """Shader that paints a lofted shell: skin, side windows (rounded rectangles seen from the side),
        a wraparound front window (a height band on forward-facing skin), a rear window, door and door window,
        each opening ringed by dark trim. Uses object-space position and normal, so edges are exact."""
        name = 'shell_' + kind
        if name in self.mats:
            return self.mats[name]
        air = kind == 'airstream'
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        nodes, links = nt.nodes, nt.links
        out = nodes['Material Output']
        nodes.remove(nodes['Principled BSDF'])

        def bsdf(color, rough, metal=0.0, emit=None):
            p = nodes.new('ShaderNodeBsdfPrincipled')
            if isinstance(color, str):
                p.inputs['Base Color'].default_value = K.srgb(color)
            else:
                links.new(color, p.inputs['Base Color'])
            p.inputs['Roughness'].default_value = rough
            p.inputs['Metallic'].default_value = metal
            if emit:
                p.inputs['Emission Color'].default_value = K.srgb(emit)
                p.inputs['Emission Strength'].default_value = 0.0
            return p

        def op(o, a, b=None):
            n = nodes.new('ShaderNodeMath')
            n.operation = o
            for i, v in enumerate((a, b)):
                if v is None:
                    continue
                if isinstance(v, (int, float)):
                    n.inputs[i].default_value = v
                else:
                    links.new(v, n.inputs[i])
            return n.outputs[0]

        tc = nodes.new('ShaderNodeTexCoord')
        sp = nodes.new('ShaderNodeSeparateXYZ')
        links.new(tc.outputs['Object'], sp.inputs[0])
        geo = nodes.new('ShaderNodeNewGeometry')
        vt = nodes.new('ShaderNodeVectorTransform')
        vt.vector_type, vt.convert_from, vt.convert_to = 'NORMAL', 'WORLD', 'OBJECT'
        links.new(geo.outputs['Normal'], vt.inputs[0])
        sn = nodes.new('ShaderNodeSeparateXYZ')
        links.new(vt.outputs[0], sn.inputs[0])
        X, Y, Z = sp.outputs[0], sp.outputs[1], sp.outputs[2]
        NX, NY = sn.outputs[0], sn.outputs[1]

        def rrect(xr, zr, r):
            """signed distance (m) to a rounded rectangle in the side (x, z) plane"""
            cx, hx = (xr[0] + xr[1]) / 2, (xr[1] - xr[0]) / 2
            cz, hz = (zr[0] + zr[1]) / 2, (zr[1] - zr[0]) / 2
            qx = op('SUBTRACT', op('ABSOLUTE', op('SUBTRACT', X, cx)), hx - r)
            qz = op('SUBTRACT', op('ABSOLUTE', op('SUBTRACT', Z, cz)), hz - r)
            mx, mz = op('MAXIMUM', qx, 0.0), op('MAXIMUM', qz, 0.0)
            ln = op('SQRT', op('ADD', op('MULTIPLY', mx, mx), op('MULTIPLY', mz, mz)))
            inner = op('MINIMUM', op('MAXIMUM', qx, qz), 0.0)
            return op('SUBTRACT', op('ADD', ln, inner), r)

        def inside(dist, grow=0.0):
            return op('LESS_THAN', dist, grow)

        def band_mask(lo, hi, grow=0.0):
            return op('MULTIPLY', op('GREATER_THAN', Z, lo - grow), op('LESS_THAN', Z, hi + grow))

        TRIM = 0.035
        side = op('GREATER_THAN', op('ABSOLUTE', NY), 0.42)
        curb = op('LESS_THAN', NY, -0.42)
        glass, trim = [], []
        for (xr, zr, r) in rects:
            d = rrect(xr, zr, r)
            glass.append(op('MULTIPLY', inside(d), side))
            trim.append(op('MULTIPLY', inside(d, TRIM), side))
        fwd = op('GREATER_THAN', NX, 0.3)
        fwd_t = op('GREATER_THAN', NX, 0.24)
        near_front = op('GREATER_THAN', X, L / 2 - 1.7)
        glass.append(op('MULTIPLY', op('MULTIPLY', band_mask(*band), fwd), near_front))
        trim.append(op('MULTIPLY', op('MULTIPLY', band_mask(*band, grow=TRIM), fwd_t), near_front))
        rear = op('LESS_THAN', NX, -0.45)
        narrow = op('LESS_THAN', op('ABSOLUTE', Y), W * 0.22)
        rz = (zb + 1.15, zb + 1.45)
        glass.append(op('MULTIPLY', op('MULTIPLY', band_mask(*rz), rear), narrow))
        trim.append(op('MULTIPLY', op('MULTIPLY', band_mask(*rz, grow=TRIM), op('LESS_THAN', NX, -0.4)),
                       op('LESS_THAN', op('ABSOLUTE', Y), W * 0.22 + TRIM)))
        dd = rrect(*door)
        door_m = op('MULTIPLY', inside(dd), curb)
        trim.append(op('MULTIPLY', op('SUBTRACT', inside(dd, 0.025), inside(dd)), curb))     # a ring, not the door
        dw = rrect(*door_win)
        glass.append(op('MULTIPLY', inside(dw), curb))

        def any_of(ms):
            acc = ms[0]
            for mm in ms[1:]:
                acc = op('MAXIMUM', acc, mm)
            return acc

        G, T = any_of(glass), any_of(trim)
        if air:
            b = nodes.new('ShaderNodeTexBrick')
            b.offset = 0.0
            b.inputs['Color1'].default_value = K.srgb('#cfd3d6')
            b.inputs['Color2'].default_value = K.srgb('#c6cacf')
            b.inputs['Mortar'].default_value = K.srgb('#8e9399')
            b.inputs['Scale'].default_value = 1.0
            b.inputs['Mortar Size'].default_value = 0.004
            b.inputs['Brick Width'].default_value = 1.2
            b.inputs['Row Height'].default_value = 30.0
            links.new(tc.outputs['Object'], b.inputs['Vector'])
            skin = bsdf(b.outputs['Color'], 0.3, 1.0)
            skin.inputs['Anisotropic'].default_value = 0.5
            door_b = bsdf('#b9bec2', 0.42, 1.0)
        else:
            skin = bsdf('#f6f5f2', 0.22)
            door_b = bsdf('#efeeea', 0.26)
            low = op('LESS_THAN', Z, zb + 0.32)
            lower_b = bsdf('#8d9296', 0.3)
            mix0 = nodes.new('ShaderNodeMixShader')
            links.new(low, mix0.inputs[0])
            links.new(skin.outputs[0], mix0.inputs[1])
            links.new(lower_b.outputs[0], mix0.inputs[2])
            skin = mix0
            T = op('MAXIMUM', T, op('MULTIPLY', op('GREATER_THAN', Z, zb + 0.32), op('LESS_THAN', Z, zb + 0.37)))
        trim_b = bsdf('#1c1d1f', 0.5)
        glass_b = bsdf('#14181c', 0.05, 0.3, emit='#ffb36b')
        glass_b.name = 'glass'
        acc = skin.outputs[0]
        for fac, sh in ((door_m, door_b), (T, trim_b), (G, glass_b)):
            mx = nodes.new('ShaderNodeMixShader')
            links.new(fac, mx.inputs[0])
            links.new(acc, mx.inputs[1])
            links.new(sh.outputs[0], mx.inputs[2])
            acc = mx.outputs[0]
        links.new(acc, out.inputs['Surface'])
        self.mats[name] = m
        return m

    def _local_to_world(self, root, p):
        v = Vector(p)
        v.rotate(root.rotation_euler)
        return (root.location.x + v.x, root.location.y + v.y, root.location.z + v.z)

    # ------------------------------------------------------------ conventional laminated trailer
    def box_trailer(self, label, x, y, rot=0.0, L=7.9, W=2.44, H=2.9, coll='rv', style='modern', slide=True, cat=0, awning_open=False):
        """Conventional laminated travel trailer: fiberglass front cap, slide-out on the street side.
        style: 'modern' (white, charcoal graphics, two roof A/Cs) or 'classic' (cream, brown graphics, older and boxier)."""
        z0 = self.t.h(x, y) if not getattr(self, 'pad_z', None) else self.pad_z
        root = self.empty(label, x, y, z0, rot, coll)
        modern = style == 'modern'
        zb = 0.62
        zt = zb + H
        if modern:
            prof = [(-L / 2, zb), (-L / 2, zt - 0.08), (-L / 2 + 0.08, zt), (L / 2 - 1.0, zt), (L / 2 - 0.45, zt - 0.18),
                    (L / 2 - 0.12, zt - 0.75), (L / 2, zt - 1.4), (L / 2, zb + 0.35), (L / 2 - 0.25, zb)]
        else:
            prof = [(-L / 2, zb), (-L / 2, zt - 0.05), (-L / 2 + 0.05, zt), (L / 2 - 0.55, zt), (L / 2 - 0.1, zt - 0.5),
                    (L / 2, zt - 1.2), (L / 2, zb + 0.2), (L / 2 - 0.15, zb)]
        bm = bmesh.new()
        vs = [bm.verts.new((px, -W / 2, pz)) for (px, pz) in prof]
        f = bm.faces.new(vs)
        r = bmesh.ops.extrude_face_region(bm, geom=[f])
        bmesh.ops.translate(bm, vec=Vector((0, W, 0)), verts=[v for v in r['geom'] if isinstance(v, bmesh.types.BMVert)])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        cap_x = L / 2 - (1.0 if modern else 0.55) + 0.01
        for fc in bm.faces:                       # the molded front cap: roof slope, nose and chin strips
            if abs(fc.normal.y) < 0.5 and fc.calc_center_median().x > cap_x:
                fc.material_index = 1
        body_col = '#f3f2ee' if modern else '#ece3d0'
        body = self.mat('gelcoat_' + style, body_col, rough=0.3 if modern else 0.5)
        cap = self.mat('cap_' + style, '#dcdcda' if modern else '#e2d6bf', rough=0.22 if modern else 0.45)
        ob = self.mesh_obj('trailer_body', bm, [body, cap], coll, parent=root)
        mod = ob.modifiers.new('bevel', 'BEVEL')
        mod.width = 0.07 if modern else 0.04
        mod.segments = 3
        mod.limit_method = 'ANGLE'
        ob.data.polygons.foreach_set('use_smooth', [True] * len(ob.data.polygons))
        g1 = self.mat('graphic1_' + style, '#2c2d2f' if modern else '#4a3a33', rough=0.4)
        g2 = self.mat('graphic2_' + style, '#8d9196' if modern else '#9c8f7a', rough=0.4)
        trim = self.mat('trim_black', '#1c1d1f', rough=0.5)
        dx = -L * 0.08
        for sy in (-1, 1):
            yy = sy * (W / 2 + 0.006)
            self.box('stripe', (L * 0.55, 0.01, 0.16), (L * 0.15, yy, zb + 0.55), g1, coll, parent=root, rot=(0, math.radians(4), 0))
            self.box('stripe', (L * 0.35, 0.01, 0.08), (L * 0.25, yy, zb + 0.82), g2, coll, parent=root, rot=(0, math.radians(7), 0))
            for (wx, ww) in ((-L * 0.32, 1.1), (L * 0.2, 0.8)):
                self.box('window_frame', (ww + 0.08, 0.015, 0.83), (wx, yy, zb + 1.75), trim, coll, parent=root, bevel=0.04, seg=2)
                self.box('window', (ww, 0.025, 0.75), (wx, yy, zb + 1.75), self.tint(), coll, parent=root, bevel=0.04, seg=2)
        # side graphics: two slanted swoosh bands rising toward the cap (inside the bevelled outline)
        top = zt - 0.18
        for (x_lo, wd, mm, z_lo) in ((L / 2 - 2.35, 0.34, g1, zb + 0.2), (L / 2 - 1.85, 0.12, g2, zb + 0.45)):
            dxs = 1.0                                                  # run of the slant from bottom to top
            quad = [(x_lo, z_lo), (x_lo + wd, z_lo), (x_lo + wd + dxs, top), (x_lo + dxs, top)]
            for sy in (-1, 1):
                y0, y1 = sy * (W / 2 + 0.004), sy * (W / 2 + 0.014)
                vv = [(px, y0, pz) for (px, pz) in quad] + [(px, y1, pz) for (px, pz) in quad]
                ff = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
                self.mesh_from('swoosh', vv, ff, mm, coll, parent=root)
        # front window lying on the sloped nose segment, with a dark frame
        p1, p2 = (prof[5], prof[6]) if modern else (prof[4], prof[5])
        mx_, mz_ = (p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2
        tilt = math.atan2(p1[0] - p2[0], p1[1] - p2[1])
        nrm = (math.cos(tilt), -math.sin(tilt))
        seg_len = math.hypot(p1[0] - p2[0], p1[1] - p2[1])
        self.box('front_window_frame', (0.02, W * 0.84, seg_len * 0.82), (mx_ + nrm[0] * 0.01, 0, mz_ + nrm[1] * 0.01), trim, coll, parent=root, rot=(0, tilt, 0))
        self.box('front_window', (0.02, W * 0.8, seg_len * 0.74), (mx_ + nrm[0] * 0.02, 0, mz_ + nrm[1] * 0.02), self.tint(), coll, parent=root, rot=(0, tilt, 0))
        self.box('baggage_door', (0.75, 0.015, 0.5), (L / 2 - 0.8, -W / 2 - 0.006, zb + 0.4), self.mat('door_' + style, '#e2e0da' if modern else '#d9cdb5', rough=0.35), coll, parent=root)
        self.box('baggage_door', (0.79, 0.01, 0.54), (L / 2 - 0.8, -W / 2 - 0.001, zb + 0.4), trim, coll, parent=root)
        # door (curb side, -Y): trimmed frame, handle, window, grab handle, fold-down steps
        yy = -W / 2 - 0.012
        self.box('door_frame', (0.8, 0.02, 1.98), (dx, yy, zb + 0.99), trim, coll, parent=root)
        self.box('door', (0.7, 0.03, 1.9), (dx, yy - 0.006, zb + 0.97), self.mat('door_' + style, '#e2e0da' if modern else '#d9cdb5', rough=0.35), coll, parent=root)
        self.box('door_win', (0.4, 0.035, 0.45), (dx, yy - 0.01, zb + 1.55), self.tint(), coll, parent=root)
        self.box('door_handle', (0.05, 0.05, 0.16), (dx + 0.27, yy - 0.04, zb + 0.95), self.m('steel'), coll, parent=root)
        self.box('grab_handle', (0.04, 0.05, 0.6), (dx - 0.48, yy - 0.04, zb + 1.1), self.m('steel'), coll, parent=root)
        self.entry_steps(root, dx, -W / 2, zb, coll)
        if slide:
            self.box('slide', (3.1, 0.55, 1.9), (-L * 0.12, W / 2 + 0.25, zb + 1.1), body, coll, parent=root, bevel=0.03, seg=2)
            self.box('slide_win', (1.3, 0.02, 0.7), (-L * 0.12, W / 2 + 0.53, zb + 1.35), self.tint(), coll, parent=root)
        ac = self.mat('ac_white', '#f2f2ef', rough=0.4)
        if modern:
            for ax in (-L * 0.28, L * 0.28):
                self.box('roof_ac', (0.75, 0.72, 0.3), (ax, 0, zt + 0.13), ac, coll, parent=root, bevel=0.06, seg=2)
        else:
            self.box('roof_ac', (0.75, 0.72, 0.3), (-L * 0.2, 0, zt + 0.13), ac, coll, parent=root, bevel=0.06, seg=2)
            self.box('roof_vent', (0.4, 0.4, 0.12), (L * 0.2, 0, zt + 0.06), self.mat('vent_smoke', '#6e6a62', rough=0.4), coll, parent=root)
        self.box('ladder', (0.04, 0.42, H - 0.2), (-L / 2 - 0.05, 0.6, zb + H / 2), self.m('steel'), coll, parent=root)
        # awning: rolled case, or open (fabric and arms in the roof collection so plans show the deck)
        ax0, ax1 = dx - 0.4, dx - 0.4 + L * 0.55
        self.box('awning_case', (L * 0.55, 0.12, 0.12), ((ax0 + ax1) / 2, -W / 2 - 0.08, zt - 0.2), self.mat('awning_case', '#e9e9e6', rough=0.3, metal=0.5), coll, parent=root)
        if awning_open:
            fab = self.mat_grain('awning_fabric', '#2b2b2b', '#e8e2d8', 'X', 1.6, rough=0.9)
            out_y, out_z = -W / 2 - 2.4, zt - 0.62
            p0, p1 = Vector(((ax0 + ax1) / 2, -W / 2 - 0.1, zt - 0.22)), Vector(((ax0 + ax1) / 2, out_y, out_z))
            aw = self.beam('awning', p0, p1, (L * 0.55, 0.02), fab, 'roof', parent=root)
            self.cyl('roller', 0.05, L * 0.55, ((ax0 + ax1) / 2, out_y, out_z), self.mat('awning_case', '#e9e9e6', rough=0.3, metal=0.5), 'roof', parent=root, seg=12, rot=(0, math.pi / 2, 0))
            for axx in (ax0 + 0.05, ax1 - 0.05):
                self.beam('awning_arm', (axx, -W / 2 - 0.02, zb + 0.15), (axx, out_y, out_z), (0.05, 0.05), self.m('steel'), 'roof', parent=root)
        self.running_gear(root, L, W, (-0.55, 0.55), zb - 0.04, coll, tongue=1.15)
        self.foot(x, y, L / 2 + 2.5, W / 2 + 2.5)
        self.anchor(label, x, y, z0, cat, dz=zt + 0.6)
        self.door_world = self._local_to_world(root, (dx, -W / 2, zb))
        return root

    # ------------------------------------------------------------ the camp around the trailer
    def pad_gravel(self, w, l, x=0.0, y=0.0):
        """Level, compacted crushed-rock pad. Sets self.pad_z (trailers stand on it)."""
        self.e = self.pad(x, y, w + 3, l + 3, 0.0, coll='camp', surface=None)
        self.z = self.e
        self.pad_z = self.e + 0.04
        self._poly('gravel_pad', x, y, w, l, 0.0, self.gravel_mat(), 'camp', step=0.6, off=0.04)
        self.foot(x, y, w / 2 + 1.5, l / 2 + 1.5)
        return self.pad_z

    def rv_cover(self, label, x, y, L=12.5, W=7.3, H=4.27, color='#e9e9e6', cat=0, coll='camp', gable=0.6, bays=4):
        """Certified steel RV cover: square-tube legs at about 3 m, eave beams, a truss at every leg line,
        corrugated roof sheets with a fascia."""
        z = self.pad_z
        frame = self.mat('cover_frame_' + color, color, rough=0.45, metal=0.6)
        roofm = self.mat_grain('cover_roof_' + color, color, '#cfcfca', 'Y', 40.0, rough=0.35)
        for i in range(bays + 1):
            xx = x - L / 2 + i * L / bays
            for sy in (-1, 1):
                self.box('leg', (0.1, 0.1, H), (xx, y + sy * W / 2, z + H / 2), frame, coll)
                self.box('leg_base', (0.3, 0.3, 0.04), (xx, y + sy * W / 2, z + 0.02), self.m('stone'), coll)
                self.beam('knee_brace', (xx, y + sy * W / 2, z + H - 0.7), (xx, y + sy * (W / 2 - 0.6), z + H), (0.06, 0.06), frame, coll)
            self.beam('truss', (xx, y - W / 2, z + H), (xx, y, z + H + gable), (0.08, 0.12), frame, coll)
            self.beam('truss', (xx, y + W / 2, z + H), (xx, y, z + H + gable), (0.08, 0.12), frame, coll)
            self.box('tie', (0.06, W, 0.06), (xx, y, z + H - 0.03), frame, coll)
        ang = math.atan2(gable, W / 2)
        for sy in (-1, 1):
            self.box('eave_beam', (L + 0.1, 0.1, 0.14), (x, y + sy * W / 2, z + H - 0.04), frame, coll)
            self.box('roof_panel', (L + 0.3, W / 2 / math.cos(ang) + 0.25, 0.05),
                     (x, y + sy * (W / 4 + 0.1), z + H + gable / 2 + 0.08), roofm, 'roof', rot=(-sy * ang, 0, 0))
            self.box('fascia', (L + 0.32, 0.04, 0.16), (x, y + sy * (W / 2 + 0.22), z + H - 0.02), frame, 'roof')
            for k in range(3):
                yy = y + sy * (W / 2) * (k + 0.5) / 3
                zz = z + H + gable * (1 - (k + 0.5) / 3)
                self.box('purlin', (L, 0.05, 0.08), (x, yy, zz + 0.02), frame, coll)
        self.outline([(x - L / 2 - 0.15, y - W / 2 - 0.2), (x + L / 2 + 0.15, y - W / 2 - 0.2), (x + L / 2 + 0.15, y + W / 2 + 0.2), (x - L / 2 - 0.15, y + W / 2 + 0.2)], z + 0.1)
        self.foot(x, y, L / 2 + 1.0, W / 2 + 1.0)
        self.anchor(label, x, y - W / 2, z, cat, dz=H + 0.4)
        return [x - L / 2 + i * L / bays for i in range(bays + 1)]

    def shade_ramada(self, label, x, y, L=12.0, W=7.0, H=4.0, cat=0, coll='camp'):
        """Modern black steel shade ramada with a flat roof and a cedar-slat west end carried by the structure."""
        z = self.pad_z
        blk = self.mat('ramada_black', '#1f1f20', rough=0.5, metal=0.5)
        cols = (x - L / 2, x - L / 6, x + L / 6, x + L / 2)
        for xx in cols:
            for sy in (-1, 1):
                self.box('col', (0.15, 0.15, H), (xx, y + sy * W / 2, z + H / 2), blk, coll)
                self.box('col_base', (0.35, 0.35, 0.05), (xx, y + sy * W / 2, z + 0.025), self.m('stone'), coll)
        for sy in (-1, 1):
            self.box('beam', (L + 0.3, 0.15, 0.3), (x, y + sy * W / 2, z + H + 0.15), blk, coll)
        for xx in cols:
            self.box('cross_beam', (0.12, W, 0.22), (xx, y, z + H + 0.11), blk, coll)
        self.box('roof', (L + 0.8, W + 0.8, 0.12), (x, y, z + H + 0.36), self.mat('ramada_roof', '#2f2f31', rough=0.5, metal=0.4), 'roof')
        # slatted west end: bottom rail on the pad, top ledger under the beam, slats between
        xw = x - L / 2 - 0.12
        self.box('slat_rail', (0.08, W, 0.08), (xw, y, z + 0.04), blk, coll)
        self.box('slat_ledger', (0.08, W, 0.1), (xw, y, z + H - 0.05), blk, coll)
        for k in range(int(W / 0.22)):
            yy = y - W / 2 + 0.15 + k * 0.22
            self.box('slat', (0.05, 0.12, H - 0.18), (xw, yy, z + 0.08 + (H - 0.18) / 2), self.m('cedar_plain'), coll)
        self.outline([(x - L / 2 - 0.4, y - W / 2 - 0.4), (x + L / 2 + 0.4, y - W / 2 - 0.4), (x + L / 2 + 0.4, y + W / 2 + 0.4), (x - L / 2 - 0.4, y + W / 2 + 0.4)], z + 0.1)
        self.foot(x, y, L / 2 + 1.0, W / 2 + 1.0)
        self.anchor(label, x, y - W / 2, z, cat, dz=H + 0.5)
        return [(xx, y + sy * W / 2) for xx in cols for sy in (-1, 1)]

    def shade_sail(self, label, pts, posts_h=(3.4, 2.6, 3.8, 2.8), color='#efe9df', cat=0, coll='camp'):
        """Tensioned four-corner shade sail (a twisted hypar) on steel posts, edges curved inward."""
        z = self.pad_z
        corners = [Vector((px, py, z + h)) for (px, py), h in zip(pts, posts_h)]
        cen = sum(corners, Vector()) / 4
        for (px, py), h in zip(pts, posts_h):
            self.cyl('sail_post', 0.07, h + 0.35, (px, py, z + (h + 0.35) / 2), self.m('steel_dark'), coll, seg=12)
            self.box('post_footing', (0.4, 0.4, 0.05), (px, py, z + 0.025), self.m('stone'), coll)
        n = 12
        verts, faces = [], []
        for j in range(n + 1):
            for i in range(n + 1):
                u, v = i / n, j / n
                p = corners[0] * (1 - u) * (1 - v) + corners[1] * u * (1 - v) + corners[2] * u * v + corners[3] * (1 - u) * v
                pull = 0.0
                if j == 0 or j == n:
                    pull = math.sin(math.pi * u)
                if i == 0 or i == n:
                    pull = max(pull, math.sin(math.pi * v))
                if 0 < i < n and 0 < j < n and (i in (1, n - 1) or j in (1, n - 1)):
                    pull = 0.5 * max(math.sin(math.pi * u) * (j in (1, n - 1)), math.sin(math.pi * v) * (i in (1, n - 1)))
                q = p + (cen - p) * (0.12 * pull)
                q.z -= 0.08 * math.sin(math.pi * u) * math.sin(math.pi * v)
                verts.append(tuple(q))
        for j in range(n):
            for i in range(n):
                a = j * (n + 1) + i
                faces.append((a, a + 1, a + n + 2, a + n + 1))
        sail = self.mesh_from('sail', verts, faces, self.mat('sail_' + color, color, rough=0.9), 'roof', smooth=True)
        sol = sail.modifiers.new('solid', 'SOLIDIFY')
        sol.thickness = 0.01
        for c in corners:
            self.cyl('d_ring', 0.05, 0.02, tuple(c), self.m('steel'), 'roof', seg=10)
        self.outline([tuple(c[:2]) for c in corners], z + 0.1)
        self.anchor(label, cen.x, cen.y, z, cat, dz=3.4)

    def skirting(self, x, y, L, W, h=0.6, coll='camp', color='#c4b79f', inset=0.04):
        """Ribbed vinyl skirting set just inside the body line."""
        z = self.pad_z
        m = self.mat_grain('skirt_' + color, color, '#a99c84', 'X', 60.0, rough=0.8)
        for sy in (-1, 1):
            self.box('skirt', (L - 0.6, 0.03, h), (x, y + sy * (W / 2 - inset), z + h / 2), m, coll)
        for sx in (-1, 1):
            self.box('skirt', (0.03, W - 2 * inset, h), (x + sx * (L / 2 - 0.3), y, z + h / 2), m, coll)
        self.box('skirt_vent', (0.4, 0.035, 0.2), (x + L * 0.25, y - (W / 2 - inset) - 0.01, z + h * 0.55), self.mat('vent_grey', '#7c776f', rough=0.6), coll)

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
        """Ribbed vertical poly water tank with a domed top, lid, spigot and a hose to the trailer."""
        z = self.pad_z if abs(x) < 9 and abs(y) < 6 else self.t.h(x, y)
        m = self.mat('poly_' + color, color, rough=0.55)
        prof = [(r * 0.97, 0.0)]
        for k in range(6):
            z0 = 0.15 + k * (h - 0.3) / 6
            prof += [(r, z0), (r * 0.975, z0 + (h - 0.3) / 12)]
        prof += [(r, h - 0.1), (r * 0.8, h + 0.12), (r * 0.35, h + 0.25), (0.0, h + 0.27)]
        self.lathe('water_tank', prof, (x, y, z), m, coll, seg=40, round_r=0.0)
        self.cyl('tank_lid', 0.22, 0.07, (x, y, z + h + 0.3), m, coll, seg=20)
        self.cyl('spigot', 0.04, 0.2, (x + r + 0.05, y, z + 0.18), self.m('steel'), coll, seg=10, rot=(0, math.pi / 2, 0))
        self.box('pump_box', (0.5, 0.4, 0.45), (x + r + 0.45, y, z + 0.22), self.mat('box_black', '#232323', rough=0.6), coll)
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

    def solar_array(self, label, x, y, cols=6, rows=1, tilt=28, cat=2, coll='camp', battery=False):
        """Ground-mount PV: separate framed modules (1.05 x 1.75 m) in portrait, tilted to the south on racking."""
        z = self.t.h(x, y)
        cells = self.mat_tile('pv_cells', '#121a28', '#16203a', '#33435e', 0.165, 0.035, rough=0.08)
        frame = self.mat('pv_frame', '#b9bdc1', rough=0.3, metal=0.9)
        steel = self.m('steel')
        pw, ph = 1.05, 1.75
        span = cols * (pw + 0.03)
        c, s_ = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
        for r_ in range(rows):
            yy = y + (r_ - (rows - 1) / 2) * (ph * c + 1.6)
            zc = z + 0.5 + ph * s_ / 2
            for k in range(cols):
                xx = x - span / 2 + (k + 0.5) * (pw + 0.03)
                self.box('pv', (pw - 0.04, ph - 0.04, 0.035), (xx, yy, zc), cells, coll, rot=(math.radians(tilt), 0, 0))
                self.box('pv_frame', (pw, ph, 0.03), (xx, yy, zc - 0.012), frame, coll, rot=(math.radians(tilt), 0, 0))
            for k in range(0, cols + 1, 2):
                px = x - span / 2 + k * (pw + 0.03)
                self.box('pv_leg', (0.06, 0.06, 0.55), (px, yy - ph * c / 2 + 0.1, z + 0.27), steel, coll)
                self.box('pv_leg', (0.06, 0.06, 0.5 + ph * s_), (px, yy + ph * c / 2 - 0.1, z + (0.5 + ph * s_) / 2), steel, coll)
            for sgn in (-1, 1):
                self.box('pv_rail', (span, 0.05, 0.05), (x, yy + sgn * ph * c * 0.3, zc - 0.06 + sgn * ph * s_ * 0.3), steel, coll)
        bx = x + span / 2 + 0.7
        self.box('inverter', (0.6, 0.3, 0.9), (bx, y, z + 0.6), self.mat('inverter_white', '#e7e7e3', rough=0.4), coll)
        if battery:
            self.box('battery_cabinet', (1.2, 0.6, 1.8), (bx + 1.1, y, z + 0.9), self.mat('battery_grey', '#9fa3a6', rough=0.4, metal=0.4), coll)
        self.foot(x, y, span / 2 + 2.0, rows * 1.9)
        self.anchor(label, x, y, z, cat, dz=2.4)

    def power_pole(self, label, x, y, cat=2, coll='camp'):
        """Temporary construction power: a 4 m service pole with a crossarm, meter and a 50 A RV pedestal."""
        z = self.t.h(x, y)
        self.cyl('pole', 0.11, 4.2, (x, y, z + 2.1), self.mat('pole_wood', '#6b5a48', rough=0.9), coll, seg=12)
        self.box('crossarm', (1.0, 0.09, 0.09), (x, y, z + 3.9), self.mat('pole_wood', '#6b5a48', rough=0.9), coll)
        self.box('meter', (0.35, 0.25, 0.6), (x, y - 0.18, z + 1.6), self.mat('meter_grey', '#a6aaa9', rough=0.4, metal=0.6), coll)
        self.box('pedestal', (0.3, 0.3, 1.1), (x + 0.7, y - 0.3, z + 0.55), self.mat('pedestal_grey', '#8f9395', rough=0.4, metal=0.5), coll)
        self.anchor(label, x, y, z, cat, dz=4.5)

    def starlink(self, label, x, y, h=2.0, coll='camp', cat=2):
        """Starlink dish (about 20 x 12 in, tilted toward the northern sky) on a short mast."""
        z = self.t.h(x, y)
        self.cyl('dish_mast', 0.035, h, (x, y, z + h / 2), self.m('steel'), coll, seg=10)
        self.box('dish', (0.58, 0.38, 0.04), (x, y + 0.05, z + h + 0.12), self.mat('dish_white', '#f4f4f1', rough=0.35), coll, rot=(math.radians(25), 0, 0), bevel=0.02, seg=2)
        self.box('dish_kick', (0.06, 0.06, 0.25), (x, y - 0.05, z + h), self.m('steel'), coll)
        self.anchor(label, x, y, z, cat, dz=h + 0.5)

    def generator(self, label, x, y, coll='camp', cat=2):
        z = self.pad_z if abs(x) < 9 and abs(y) < 6 else self.t.h(x, y)
        self.box('generator', (0.52, 0.3, 0.45), (x, y, z + 0.23), self.mat('gen_red', '#b3241b', rough=0.4), coll, bevel=0.04, seg=2)
        self.box('gen_panel', (0.02, 0.18, 0.12), (x - 0.27, y, z + 0.28), self.mat('gen_black', '#222222', rough=0.5), coll)
        self.anchor(label, x, y, z, cat, dz=0.8)

    def storage_shed(self, label, x, y, rot=0.0, w=3.66, d=3.05, h=2.6, color='#3a3a3c', door='#df4537', cat=1, coll='camp'):
        """10 x 12 ft storage shed: board-and-batten cladding, a door with hardware, a small window, roof overhang."""
        z = self.t.h(x, y)
        root = self.empty('shed', x, y, z, rot, coll)
        clad = self.mat_grain('shed_clad_' + color, color, '#2e2e30' if color != '#e8e1d4' else '#d8d0c2', 'X', 18.0, rough=0.7)
        self.box('shed_base', (w + 0.1, d + 0.1, 0.15), (0, 0, 0.075), self.m('stone_dark'), coll, parent=root)
        self.box('shed', (w, d, h), (0, 0, h / 2 + 0.15), clad, coll, parent=root)
        self.box('shed_roof', (w + 0.5, d + 0.6, 0.12), (0, 0, h + 0.25), self.mat('shed_roof', '#2b2b2c', rough=0.5, metal=0.4), coll, parent=root, rot=(math.radians(-4), 0, 0))
        self.box('shed_door', (1.5, 0.04, 2.0), (0, -d / 2 - 0.02, 1.15), self.mat('shed_door_' + door, door, rough=0.4), coll, parent=root)
        self.box('door_split', (0.02, 0.05, 2.0), (0, -d / 2 - 0.03, 1.15), self.mat('trim_black', '#1c1d1f', rough=0.5), coll, parent=root)
        for sx in (-0.12, 0.12):
            self.box('door_pull', (0.03, 0.05, 0.3), (sx, -d / 2 - 0.05, 1.2), self.m('steel'), coll, parent=root)
        self.box('shed_window', (0.04, 0.6, 0.45), (w / 2 + 0.02, 0, 1.75), self.tint(), coll, parent=root)
        self.foot(x, y, w / 2 + 1.0, d / 2 + 1.2)
        self.anchor(label, x, y, z, cat, dz=h + 0.6)

    def pickup(self, x, y, rot=0.0, color='#4b5560', coll='camp'):
        """A pickup truck with cab glass and wheels."""
        z = self.t.h(x, y) if not (abs(x) < 9 and abs(y) < 6) else self.pad_z
        root = self.empty('pickup', x, y, z, rot, coll)
        body = self.mat('truck_' + color, color, rough=0.3, metal=0.5)
        glass = self.mat('truck_glass', '#151b22', rough=0.05, metal=0.3, spec=0.9)
        tire = self.mat('tire', '#1b1b1b', rough=0.85)
        self.box('truck_body', (5.6, 2.0, 0.8), (0, 0, 0.85), body, coll, parent=root, bevel=0.12, seg=3)
        self.box('truck_cab', (2.4, 1.85, 0.75), (0.55, 0, 1.6), body, coll, parent=root, bevel=0.15, seg=3)
        self.box('truck_glass', (2.3, 1.87, 0.42), (0.55, 0, 1.68), glass, coll, parent=root, bevel=0.1, seg=2)
        self.box('truck_bed', (1.9, 1.8, 0.05), (-1.75, 0, 1.28), self.mat('bedliner', '#2a2a2a', rough=0.9), coll, parent=root)
        for ax in (-1.75, 1.75):
            for sy in (-1, 1):
                self.cyl('truck_tire', 0.42, 0.3, (ax, sy * 0.88, 0.42), tire, coll, parent=root, seg=28, rot=(math.pi / 2, 0, 0))
        self.foot(x, y, 3.2, 1.6)

    def person(self, x, y, rot=0.0, coll='camp', color='#3a3633'):
        """A 5 ft 9 in (1.75 m) figure for scale: legs, hips, torso, arms, neck and head."""
        z = self.pad_z if getattr(self, 'pad_z', None) else self.t.h(x, y)
        root = self.empty('person', x, y, z, rot, coll)
        m = self.mat('figure_' + color, color, rough=0.8)
        for sx in (-0.1, 0.1):
            self.cyl('leg', 0.075, 0.86, (sx, 0, 0.43), m, coll, parent=root, seg=12, r2=0.065)
            self.box('shoe', (0.12, 0.26, 0.07), (sx, -0.05, 0.035), m, coll, parent=root, bevel=0.03, seg=2)
        self.box('hips', (0.36, 0.2, 0.16), (0, 0, 0.9), m, coll, parent=root, bevel=0.06, seg=2)
        t = self.cyl('torso', 0.16, 0.56, (0, 0, 1.24), m, coll, parent=root, seg=16, r2=0.2)
        t.scale = (1.05, 0.62, 1.0)
        for sx in (-1, 1):
            self.beam('arm', (sx * 0.23, 0, 1.47), (sx * 0.27, 0.02, 0.86), (0.085, 0.085), m, coll, parent=root)
        self.cyl('neck', 0.05, 0.08, (0, 0, 1.55), m, coll, parent=root, seg=10)
        self.lathe('head', [(0.0, -0.11), (0.07, -0.095), (0.1, -0.03), (0.1, 0.03), (0.07, 0.095), (0.0, 0.11)], (0, 0, 1.64), m, coll, seg=20, parent=root)

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
                    continue
                self.box('stud', (0.09, 0.09, H), (px, py, 0.35 + H / 2), stud, coll, parent=root, rot=(0, 0, ang))
            for zz in (0.35 + H, 0.35 + H + 0.05):
                self.box('plate', (L, 0.09, 0.045), ((p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2, zz), stud, coll, parent=root, rot=(0, 0, ang))
        for k in range(0, int(W / 0.61) + 1):
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
