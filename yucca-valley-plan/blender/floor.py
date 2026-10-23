"""Exploded floor build-up: radiant slab with a soft, lie-down finish (thicknesses exaggerated for clarity)."""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sitekit as K
import bpy
from mathutils import Vector

out, preview = K.args()
s = K.Site('F', out, preview)
W, Dp = 2.4, 1.6
GAP = 0.30
layers = []                      # (label, thickness, material)
gravel = s.mat('gravel_base', '#9d9183', rough=1.0)
vapor = s.mat('vapor', '#5d7486', rough=0.2, alpha=0.85)
foam = s.mat('foam', '#8fb6db', rough=0.8)
conc = s.mat('slab', '#bdb7ad', rough=0.6)
cork = s.mat('cork', '#b98f5f', rough=0.9)
tatami = s.mat_stripes('tatami', '#cfc58e', '#bdb27a', scale=70.0, rough=0.85, axis='Y')
border = s.mat('tatami_border', '#2f3a34', rough=0.7)
tile = s.mat('porcelain', '#dcd7cf', rough=0.3)
pex = s.mat('pex', '#d3482b', rough=0.35)
mesh = s.mat('mesh', '#6f747a', rough=0.5, metal=0.7)

z = 0.0


def slab(name, t, mat, w=W, d=Dp, x=0.0):
    global z
    s.box(name, (w, d, t), (x, 0, z + t / 2), mat, 'stack')
    top = z + t
    return top


def A(label, x, y, zz):
    s.anchors.append({'label': label, 'pos': (x, y, zz), 'phase': 2})


t = slab('base', 0.14, gravel); A('Compacted gravel base, 4-6 in', W / 2 - 0.2, -Dp / 2, t - 0.05); z = t + GAP
t = slab('vapor', 0.012, vapor); A('15-mil vapor barrier (keeps ground moisture out of the tatami)', W / 2 - 0.2, -Dp / 2, t); z = t + GAP
t = slab('foam', 0.09, foam); A('2 in rigid foam under the whole slab + edges (R-10): heat goes up, not into the ground', W / 2 - 0.2, -Dp / 2, t - 0.03); z = t + GAP
# PEX loops on reinforcing mesh
for i in range(9):
    s.box('mesh_x', (W - 0.1, 0.006, 0.006), (0, -Dp / 2 + 0.1 + i * 0.175, z), mesh, 'stack')
for i in range(13):
    s.box('mesh_y', (0.006, Dp - 0.1, 0.006), (-W / 2 + 0.1 + i * 0.183, 0, z), mesh, 'stack')
pts = []
n = 9
for i in range(n):
    x = -W / 2 + 0.18 + i * (W - 0.36) / (n - 1)
    ys = (-Dp / 2 + 0.12, Dp / 2 - 0.12) if i % 2 == 0 else (Dp / 2 - 0.12, -Dp / 2 + 0.12)
    pts += [(x, ys[0], z + 0.022), (x, ys[1], z + 0.022)]
cd = bpy.data.curves.new('pex', 'CURVE')
cd.dimensions = '3D'
cd.bevel_depth = 0.016
cd.bevel_resolution = 3
sp = cd.splines.new('POLY')
sp.points.add(len(pts) - 1)
for i, p in enumerate(pts):
    sp.points[i].co = (p[0], p[1], p[2], 1)
cob = bpy.data.objects.new('pex', cd)
cob.data.materials.append(pex)
s.link(cob, 'stack')
A('Radiant heat: PEX loops ~9 in apart fed by an air-to-water heat pump (or thin electric mats, the simpler DIY option)', W / 2 - 0.25, -Dp / 2 + 0.12, z + 0.03)
z = z + 0.05 + GAP * 0.6
t = slab('concrete', 0.13, conc); A('4 in concrete slab = thermal battery (stores heat for cold desert nights)', W / 2 - 0.2, -Dp / 2, t - 0.04); z = t + GAP
# top: hard porcelain strip on the left, soft assembly on the right
hard_w = 0.7
s.box('tile', (hard_w, Dp, 0.035), (-W / 2 + hard_w / 2, 0, z + 0.0175), tile, 'stack')
A('Hard zones (kitchen, bath, entry): porcelain tile, same heat', -W / 2 + 0.3, -Dp / 2, z + 0.035)
soft_x0 = -W / 2 + hard_w + 0.04
soft_w = W - hard_w - 0.04
s.box('cork', (soft_w, Dp, 0.035), (soft_x0 + soft_w / 2, 0, z + 0.0175), cork, 'stack')
A('1/4 in cork underlay (adds cushion, low R-value)', soft_x0 + soft_w - 0.15, -Dp / 2, z + 0.02)
z2 = z + 0.035 + GAP * 0.7
for j in range(2):
    cy = -Dp / 4 + j * Dp / 2
    s.box('tb', (soft_w - 0.02, Dp / 2 - 0.02, 0.06), (soft_x0 + soft_w / 2, cy, z2 + 0.03), border, 'stack')
    s.box('tm', (soft_w - 0.07, Dp / 2 - 0.06, 0.064), (soft_x0 + soft_w / 2, cy, z2 + 0.032), tatami, 'stack')
A('Soft top: floor-heating tatami (15-30 mm) or wool felt; keep the covering at or under about R-1.5', soft_x0 + soft_w / 2 + 0.3, -Dp / 2 + 0.05, z2 + 0.064)
# zabuton + person-scale cue on top
s.box('cushion', (0.5, 0.5, 0.09), (soft_x0 + soft_w * 0.7, 0.25, z2 + 0.11), s.mat('cushion_rust', '#b5653d', rough=0.95), 'stack', bevel=0.03, seg=2)

world = bpy.data.worlds.new('w')
s.scene.world = world
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = K.srgb('#f3efe8')
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.9
sd = bpy.data.lights.new('key', 'SUN')
sd.energy = 2.6
sd.angle = math.radians(8)
so = bpy.data.objects.new('key', sd)
so.rotation_euler = (math.radians(40), math.radians(-25), math.radians(20))
s.link(so, 'land')
cam = s.camera('fc', (3.1, -3.9, 2.9), (0.1, 0.0, 0.85), lens=40)
s.render(cam, 'floor_buildup', res=(1800, 1300), samples=64)
