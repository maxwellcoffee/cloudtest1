"""The small permitted house: 20 ft x 32 ft (640 sq ft) single open room with a soft, radiant-heated floor.

Renders: house_exterior (golden hour from the south-east) and house_cutaway (roof off, interior layout).
Layout (local metres, +X east, -Y south / glass side):
  north service bar: bath (west) | closet + mechanical | open galley kitchen | genkan entry (east)
  everything south of it: one soft floor field (tatami / wool felt over the radiant slab)
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sitekit as K
import bpy
from mathutils import Vector

out, preview = K.args()
s = K.Site('H', out, preview)
FT = K.FT
L, D = 32 * FT, 20 * FT          # 9.75 m x 6.10 m outside
H = 3.05                          # wall height above slab
T = 0.25                          # wall thickness
OVER = 2.1                        # south roof overhang
PLINTH = 0.35
hx, hy = L / 2, D / 2

# small site so the house sits in context
e = s.pad(0, 0, L + 8, D + OVER + 9, coll='phase2', surface='pad')
s.t.add_pad(0, -hy - 4.5, 14, 6, elev=e, phase=2)

plaster = s.mat('plaster', '#ebe3d6', rough=0.85)
char = s.mat('charcoal', '#2b2c2e', rough=0.5, metal=0.25)
conc = s.mat('concrete', '#c2bcb2', rough=0.7)
glass = bpy.data.materials.new('clear_glass')
glass.use_nodes = True
p = glass.node_tree.nodes['Principled BSDF']
p.inputs['Base Color'].default_value = K.srgb('#dfe9ee')
p.inputs['Roughness'].default_value = 0.0
p.inputs['Transmission Weight'].default_value = 1.0
p.inputs['IOR'].default_value = 1.2
tile = s.mat('porcelain', '#d9d4cb', rough=0.35)
oak = s.mat('oak', '#b8956a', rough=0.55)
white = s.mat('cab_white', '#f1eee8', rough=0.4)
steel = s.mat('steel_brushed', '#9ea3a8', rough=0.3, metal=0.9)
pv = s.mat_bricks('pv', '#1d2b45', '#8d9bb0', scale=1.1, mortar=0.025)
tatami = s.mat_stripes('tatami', '#c9c08a', '#b9ae75', scale=60.0, rough=0.85, axis='Y')
border = s.mat('tatami_border', '#2f3a34', rough=0.7)
felt = s.mat('cushion_rust', '#b5653d', rough=0.95)
felt2 = s.mat('cushion_sand', '#d8c3a0', rough=0.95)
felt3 = s.mat('cushion_sage', '#8c9a7a', rough=0.95)
linen = s.mat('futon', '#f2ede2', rough=0.95)
warm = s.mat('lamp', '#ffd9a0', emit='#ffcf8a', emit_strength=6.0)

Z0 = e + PLINTH          # finished floor level


def B(name, size, loc, mat, coll='house', **kw):
    return s.box(name, size, (loc[0], loc[1], Z0 + loc[2]), mat, coll, **kw)


# ---- slab / plinth
s.box('plinth', (L + 0.3, D + 0.3, PLINTH), (0, 0, e + PLINTH / 2), conc, 'house')
s.box('patio', (L + 1.0, OVER + 2.2, 0.14), (0, -hy - (OVER + 2.2) / 2, e + 0.07), conc, 'house')


# ---- walls (full height + a cut-down copy for the cutaway)
def walls(coll, h):
    zc = h / 2
    B('wall_n', (L, T, h), (0, hy - T / 2, zc), plaster, coll)
    B('wall_w', (T, D, h), (-hx + T / 2, 0, zc), plaster, coll)
    # east wall with entry door opening (door 0.95 m wide near the north end)
    dy0, dy1 = hy - T - 2.05, hy - T - 1.1
    B('wall_e1', (T, (dy0 + hy)), (hx - T / 2, (-hy + dy0) / 2, zc), plaster, coll) if False else None
    B('wall_e_s', (T, dy0 - (-hy)), (0, 0, 0), plaster, coll) if False else None
    B('wall_e_south', (T, dy0 + hy, h), (hx - T / 2, (-hy + dy0) / 2, zc), plaster, coll)
    B('wall_e_north', (T, hy - dy1, h), (hx - T / 2, (dy1 + hy) / 2, zc), plaster, coll)
    B('wall_e_head', (T, dy1 - dy0, max(0.01, h - 2.25)), (hx - T / 2, (dy0 + dy1) / 2, 2.25 + max(0.01, h - 2.25) / 2), plaster, coll) if h > 2.3 else None
    # south: short return walls, the rest is glass
    B('wall_s_w', (0.6, T, h), (-hx + 0.3, -hy + T / 2, zc), plaster, coll)
    B('wall_s_e', (0.6, T, h), (hx - 0.3, -hy + T / 2, zc), plaster, coll)
    # interior partitions of the service bar (bath + closet)
    bar = 2.1
    yb = hy - T - bar
    B('part_bath_s', (2.55, 0.12, h), (-hx + T + 2.55 / 2, yb, zc), plaster, coll)
    B('part_bath_e', (0.12, bar, h), (-hx + T + 2.55, hy - T - bar / 2, zc), plaster, coll)
    B('part_clo_e', (0.12, bar, h), (-hx + T + 4.0, hy - T - bar / 2, zc), plaster, coll)
    B('part_clo_s', (1.45, 0.12, h), (-hx + T + 3.27, yb, zc), oak, coll)


walls('walls_full', H)
walls('walls_cut', 1.25)

# glazing: four sliding panels across the south face
gw = L - 1.2
for i in range(4):
    x = -gw / 2 + gw / 8 + i * gw / 4
    B('glass', (gw / 4 - 0.06, 0.03, H - 0.12), (x, -hy + 0.12, H / 2), glass, 'glass_full')
    B('frame', (0.06, 0.1, H), (x - gw / 8, -hy + 0.12, H / 2), char, 'glass_full')
B('frame_top', (gw, 0.1, 0.08), (0, -hy + 0.12, H - 0.04), char, 'glass_full')
B('frame_bot', (gw, 0.1, 0.05), (0, -hy + 0.12, 0.02), char, 'house')
for i in range(4):
    x = -gw / 2 + gw / 8 + i * gw / 4
    B('glass_low', (gw / 4 - 0.06, 0.03, 1.13), (x, -hy + 0.12, 0.62), glass, 'glass_cut')
# north clerestory + east door
B('clere', (L * 0.7, 0.05, 0.42), (0, hy - 0.02, H - 0.38), glass, 'glass_full')
B('door', (0.06, 0.95, 2.2), (hx + 0.01, hy - T - 1.575, 1.1), oak, 'glass_full')

# roof plate with deep south overhang, slim steel posts, PV
rt = 0.3
s.box('roof', (L + 0.8, D + OVER + 0.4, rt), (0, -OVER / 2 + 0.1, Z0 + H + rt / 2), char, 'roof')
for sx in (-1, 1):
    s.box('post', (0.1, 0.1, H), (sx * (hx + 0.25), -hy - OVER + 0.25, Z0 + H / 2), char, 'roof')
cols = 8
for row in range(2):
    for c in range(cols):
        px = -((cols - 1) * 1.08) / 2 + c * 1.08
        py = -0.9 + row * 1.85
        s.box('pv', (1.0, 1.7, 0.04), (px, py, Z0 + H + rt + 0.25), pv, 'roof', rot=(math.radians(-10), 0, 0))

# ---- floors: hard strip (genkan + kitchen aisle + bath) and the soft field
bar = 2.1
yb = hy - T - bar
B('genkan', (1.55, bar + 1.0, 0.02), (hx - T - 0.78, hy - T - (bar + 1.0) / 2, -0.12), tile)
B('aisle', (L - 2 * T - 4.0 - 1.55, 1.0, 0.02), (-hx + T + 4.0 + (L - 2 * T - 4.0 - 1.55) / 2, yb - 0.5 + 0.06, 0.005), tile)
B('bathfloor', (2.55, bar, 0.02), (-hx + T + 1.27, hy - T - bar / 2, 0.005), tile)
B('closetfloor', (1.45, bar, 0.02), (-hx + T + 3.27, hy - T - bar / 2, 0.005), oak)
# soft field = tatami grid (each mat ~0.91 x 1.82 m with dark borders)
fx0, fx1 = -hx + T, hx - T - 1.55
fy0, fy1 = -hy + 0.18, yb - 1.0 + 0.06
# bath + closet zone has no aisle, so the field runs up to the bar there
mats_ = []
mw, ml = 1.82, 0.91
nx = int((fx1 - fx0) // mw)
ny = int((fy1 - fy0) // ml)
gx = (fx1 - fx0 - nx * mw) / 2
gy = (fy1 - fy0 - ny * ml) / 2
for j in range(ny):
    for i in range(nx):
        cx = fx0 + gx + mw / 2 + i * mw
        cy = fy0 + gy + ml / 2 + j * ml
        B('mat_border', (mw - 0.01, ml - 0.01, 0.035), (cx, cy, 0.017), border)
        B('mat', (mw - 0.06, ml - 0.03, 0.04), (cx, cy, 0.02), tatami)
# strip of mats in front of the bath/closet (no aisle there)
for i in range(int(4.0 // mw)):
    cx = fx0 + 0.15 + mw / 2 + i * mw
    B('mat_border', (mw - 0.01, ml - 0.01, 0.035), (cx, yb - ml / 2 - 0.06, 0.017), border)
    B('mat', (mw - 0.06, ml - 0.03, 0.04), (cx, yb - ml / 2 - 0.06, 0.02), tatami)
B('soft_edge', (fx1 - fx0, fy1 - fy0 + 0.1, 0.03), ((fx0 + fx1) / 2, (fy0 + fy1) / 2, 0.0), border)
# south-east corner below the genkan: a thick wool-felt pad (the other soft-floor option)
gy0 = hy - T - bar - 1.0
B('felt_field', (hx - T - fx1 - 0.04, gy0 - fy0 - 0.04, 0.045), ((fx1 + hx - T) / 2, (fy0 + gy0) / 2, 0.022), s.mat('wool_felt', '#cdbb9b', rough=1.0))

# ---- kitchen (open galley on the north wall)
kx0, kx1 = -hx + T + 4.1, hx - T - 1.65
kw = kx1 - kx0
B('counter', (kw, 0.65, 0.9), ((kx0 + kx1) / 2, hy - T - 0.33, 0.45), white)
B('countertop', (kw, 0.67, 0.04), ((kx0 + kx1) / 2, hy - T - 0.33, 0.92), oak)
B('sink', (0.6, 0.42, 0.02), (kx0 + 1.0, hy - T - 0.33, 0.945), steel)
B('cooktop', (0.6, 0.5, 0.01), (kx0 + kw - 1.0, hy - T - 0.33, 0.945), s.mat('cooktop', '#141414', rough=0.1))
B('fridge', (0.7, 0.7, 2.0), (kx1 - 0.35, hy - T - 0.36, 1.0), white)
B('shelf', (kw - 0.9, 0.3, 0.04), ((kx0 + kx1 - 0.7) / 2, hy - T - 0.16, 1.6), oak, 'walls_full')
B('shelf', (kw - 0.9, 0.3, 0.04), ((kx0 + kx1 - 0.7) / 2, hy - T - 0.16, 2.0), oak, 'walls_full')

# ---- bath
B('shower_tray', (0.95, 1.0, 0.04), (-hx + T + 0.5, hy - T - 0.5, 0.02), tile)
B('shower_glass', (0.02, 1.0, 1.9), (-hx + T + 0.98, hy - T - 0.5, 0.95), glass)
B('vanity', (0.9, 0.5, 0.85), (-hx + T + 1.75, hy - T - 0.26, 0.42), oak)
B('toilet', (0.4, 0.62, 0.42), (-hx + T + 1.55, yb + 0.45, 0.21), white, bevel=0.12, seg=3)
B('ofuro_tub', (0.95, 0.75, 0.6), (-hx + T + 0.5, yb + 0.5, 0.3), s.mat('hinoki', '#c79a62', rough=0.6))

# ---- closet / mechanical: heat-pump buffer tank + manifold
s.cyl('buffer_tank', 0.28, 1.4, (-hx + T + 3.0, hy - T - 0.4, Z0 + 0.7), white, 'house')
B('manifold', (0.6, 0.12, 0.5), (-hx + T + 3.6, hy - T - 0.08, 0.6), s.mat('manifold', '#b2402a', rough=0.4, metal=0.4))
B('wardrobe', (0.6, 1.0, 2.1), (-hx + T + 3.65, hy - T - 1.4, 1.05), oak)

# ---- genkan: bench + shoe shelf
B('genkan_bench', (0.4, 1.2, 0.42), (hx - T - 0.25, hy - T - 2.4, 0.21 - 0.1), oak)
B('shoe_shelf', (1.3, 0.35, 0.9), (hx - T - 0.75, hy - T - 0.2, 0.33), oak)

# ---- soft-floor life: low table (kotatsu), cushions, futon, floor lamps, low bench
B('kotatsu_top', (1.2, 0.9, 0.04), (0.3, -0.6, 0.4), oak)
B('kotatsu_quilt', (1.5, 1.2, 0.36), (0.3, -0.6, 0.2), felt2, bevel=0.12, seg=3)
for (cx, cy, m) in ((0.3, -1.45, felt), (0.3, 0.25, felt3), (-0.75, -0.6, felt), (1.35, -0.6, felt3)):
    B('zabuton', (0.6, 0.6, 0.1), (cx, cy, 0.09), m, bevel=0.04, seg=2)
B('futon', (1.4, 2.05, 0.14), (-3.0, -0.95, 0.1), linen, bevel=0.05, seg=2)
B('pillow', (0.6, 0.35, 0.12), (-3.0, 0.0, 0.2), linen, bevel=0.05, seg=2)
B('blanket', (1.42, 1.1, 0.03), (-3.0, -1.4, 0.18), felt3, bevel=0.01, seg=1)
B('bolster', (2.6, 0.45, 0.4), (2.4, -2.3, 0.22), felt2, bevel=0.15, seg=3)
B('floor_cushion', (0.9, 0.9, 0.18), (3.1, -1.4, 0.12), felt, bevel=0.06, seg=2)
for (lx, ly) in ((-4.2, -2.45), (1.6, 0.6)):
    s.cyl('lamp_shade', 0.22, 0.45, (lx, ly, Z0 + 0.45), warm, 'house', seg=24)
B('low_storage', (0.45, 3.0, 0.45), (-hx + T + 0.25, -0.9, 0.22), oak)
B('plant_pot', (0.4, 0.4, 0.45), (-hx + T + 0.35, -hy + 0.55, 0.22), s.mat('pot', '#8c5a3c', rough=0.8))

# ductless mini-split head high on the north wall, above the kitchen shelves
B('minisplit', (0.9, 0.22, 0.3), (1.2, hy - T - 0.12, 2.55), white, 'walls_full')
B('minisplit_cut', (0.9, 0.22, 0.3), (1.2, hy - T - 0.12, 1.05), white, 'walls_cut')

# interior light for the glow through the glass
li = bpy.data.lights.new('interior', 'AREA')
li.energy = 650
li.size = 6.0
li.color = (1.0, 0.82, 0.62)
lo = bpy.data.objects.new('interior', li)
lo.location = (0, -0.5, Z0 + H - 0.15)
s.link(lo, 'interior_light')
# exterior: a couple of landscape elements
s.ramada('ramada', hx + 4.5, -hy - 1.5, w=4.0, l=4.0, coll='site', phase=2, anchor=False)

# ---- labels for the cutaway (numbers keyed in the plan document)
def A(label, x, y, z=0.2):
    s.anchors.append({'label': label, 'pos': (x, y, Z0 + z), 'phase': 2})


A('Soft floor field: tatami / wool felt over the heated slab (~300 sq ft)', -1.6, -1.6, 0.1)
A('Low kotatsu table + floor cushions (living / dining)', 0.3, -0.6, 0.6)
A('Futon rolls out here at night, folds away by day', -3.0, -0.9, 0.3)
A('Sliding glass wall to the south, 7 ft roof overhang shades summer sun', 2.6, -hy + 0.1, 1.3)
A('Open galley kitchen on a hard porcelain strip', kx0 + 1.6, hy - T - 0.6, 1.0)
A('Bath with shower + small soaking tub', -hx + T + 1.2, hy - T - 1.0, 1.0)
A('Mechanical closet: fire-sprinkler riser, heat-pump water heater, radiant manifold', -hx + T + 3.3, hy - T - 0.7, 1.3)
A('Ductless mini-split: the code-required main heat + cooling', 1.2, hy - T - 0.2, 2.5)
A('Genkan entry: shoes off, one step up', hx - T - 0.8, hy - T - 2.3, 0.3)

s.build_terrain(x0=-70, x1=70, y0=-70, y1=70, step=0.5, phases=(99,))
s.build_surfaces()
# vegetation near the house
rng = __import__('random').Random(5)
for k in range(140):
    x, y = rng.uniform(-60, 60), rng.uniform(-60, 60)
    if abs(x) < 13 and -14 < y < 9:
        continue
    s.shrub(x, y, rng.uniform(0.9, 1.9))
for (x, y, h) in ((-27, -24, 4.8), (31, -27, 3.4), (-40, -4, 5.6), (35, 14, 4.2), (-12, 32, 3.0)):   # all 50+ ft from the work area
    s.joshua_tree(x, y, h)
for (x, y, r) in ((-14, -9, 2.4), (-15.5, -7.5, 1.6), (15, -6, 2.0)):
    s.boulder(x, y, r)
s.capsule('pod', -30, 16, rot=-20, coll='site', pad=True)
s.lights(sun_az=258, sun_el=11, strength=4.4, sky_strength=0.4)

# exterior: golden hour, from the south-east, warm interior glow
ext = s.camera('ext', (11.5, -19.5, Z0 + 2.4), (-0.8, -1.0, Z0 + 1.5), lens=28)
s.render(ext, 'house_exterior', res=(1800, 1100), samples=96,
         hide=['walls_cut', 'glass_cut', 'plan', 'plan_fire'], extra_anchor_filter=lambda a: False)

# cutaway: roof off, walls cut at 1.25 m, bright daylight from above
s.set_sun(200, 58, 3.2)
li.energy = 120
cut = s.camera('cut', (6.2, -8.6, Z0 + 9.2), (0.0, 0.2, Z0), lens=33)
s.render(cut, 'house_cutaway', res=(1800, 1200), samples=64,
         hide=['walls_full', 'glass_full', 'roof', 'plan', 'plan_fire', 'site'])

# plan: straight down, walls cut, orthographic
plan = s.camera('hplan', (0, -0.6, Z0 + 30), ortho=12.4, rot=(0, 0, 0))
s.set_sun(200, 70, 3.0)
s.render(plan, 'house_plan', res=(1800, 1200), samples=48,
         hide=['walls_full', 'glass_full', 'roof', 'plan', 'plan_fire', 'site'])
