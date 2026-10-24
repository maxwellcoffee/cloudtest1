"""Scheme A - Spring Glass House: a timber-and-glass pool house like the enclosed "greenhouse" pool at
The Spring (knee wall, glass, a slatted band under a low roof), with one in-ground tiled hot tub, a seated
wash/scrub corner and plants inside; a cedar sauna, cold plunge and a vine-covered pergola outside."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spakit as SK

out, preview = SK.args()
s = SK.Spa('A', out, preview)


def face(x, y, tx, ty):
    """Rotation (degrees) that turns a builder whose front is local -Y toward (tx, ty)."""
    return math.degrees(math.atan2(ty - y, tx - x)) + 90


s.terrace(15.5, 11.2, x=2.25, y=-0.95, mat='pebble')
z = s.z

# ---- pool house: 24 x 18 ft, posts at 6 ft, 8 ft to the top plate, low shed roof
W, L = 7.3, 5.5
g = s.rect_pavilion('Glass pool house, 24 x 18 ft', W, L, h=2.45, nx=5, ny=4, roof='shed', overhang=0.6,
                    plinths=False, anchor_cat=0)
ring = g['ring']
x0, x1, y0, y1 = g['box']
for i in range(len(ring)):
    p1, p2 = ring[i], ring[(i + 1) % len(ring)]
    mx, my = (p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2
    side = 'S' if abs(my - y0) < 1e-6 else 'N' if abs(my - y1) < 1e-6 else 'E' if abs(mx - x1) < 1e-6 else 'W'
    door = None
    if side == 'S' and abs(mx) < 1.5:
        door = 'slide'
    if side == 'E' and abs(my) < 0.5:
        door = 'slide'
    s.glass_bay(p1, p2, z, g['h'], door=door)

# ---- the one hot tub: in-ground, 9.5 x 7 ft, blue mosaic waterline, stone coping, steps at the east end
outline = s.stadium(2.9, 2.1, r=0.75, cx=0.45, cy=0.2)
s.sunk_pool('In-ground hot tub, 9.5 x 7 ft, 104 F max', outline, depth=0.95, steps_at=(1.62, 0.2, 90))

# ---- seated wash + scrub corner against the west wall
s.scrub_station('Seated wash + seshin scrub table', -2.25, 0.15, rot=90, roofed=False)

# ---- plants inside: planter along the north glass, potted palm and yucca, stump planter, boulders
top = s.planter(0.6, 2.33, 3.3, 0.55, h=0.45)
s.fern(-0.6, 2.33, top, s=0.55)
s.snake_plant(0.15, 2.36, top, s=0.75)
s.bird_of_paradise(0.95, 2.33, top, s=1.15)
s.fern(1.9, 2.33, top, s=0.5, mat='leaf')
s.anchor('Planter: ferns, bird of paradise, snake plant', 0.6, 2.33, z, 3, dz=1.0)
t = s.pot(2.95, 2.05, r=0.36, h=0.6, mat='black_fabric')
s.palm(2.95, 2.05, h=1.7, z=t, n=16)
s.anchor('Potted fan palm', 2.95, 2.05, z, 3, dz=2.2)
t = s.pot(2.95, -2.05, r=0.32, h=0.5, mat='plaster')
s.yucca_rostrata(2.95, -2.05, h=0.9, z=t)
t = s.stump(-1.55, 2.3, h=0.5)
s.fern(-1.55, 2.3, t, s=0.42)
s.rock(-0.7, -2.25, s=0.75)
s.rock(1.95, -2.3, s=0.55)
for (hx, hy) in ((-2.9, 2.25), (2.2, -2.25), (-0.4, -2.3)):
    s.hanging_plant(hx, hy, z + g['h'] + 0.2, drop=0.75)
s.anchor('Hanging pothos', -2.9, 2.25, z, 3, dz=1.9)
for (cx, cy) in ((-2.6, -2.05), (-1.75, -2.25)):
    s.sling_chair(cx, cy, rot=face(cx, cy, 0.45, 0.2), fabric='blush' if cx < -2 else 'peach')
s.anchor('Wood sling chairs', -2.2, -2.15, z, 3, dz=1.0)
# sconces on posts at least 5 ft from the water (electrical code)
for (px, py, r) in ((x0 + 0.12, -0.92, 90), (x0 + 0.12, 0.92, 90), (x1 - 0.12, 0.92, -90), (x1 - 0.12, -0.92, -90)):
    s.sconce(px, py, z + 1.95, rot=r)

# ---- outside: cedar sauna a few steps from the east door, cold plunge + shower between
s.cabin_sauna('Cedar cabin sauna, 7 x 7 ft (2-4 people)', 6.7, 1.75, rot=-90, w=2.2, d=2.2)
s.cold_plunge('Cold plunge (stock tank + chiller)', 5.4, -1.35, kind='stock', rot=90)
s.shower('Rinse shower', 7.4, -0.75, rot=90)
s.towel_rack(4.6, 2.9, rot=0)

# ---- vine pergola with the warm rest platform and hanging cone planters
pg = s.rect_pavilion('Vine pergola', 4.2, 3.0, h=2.55, nx=2, ny=2, roof='pergola', cx=7.1, cy=-3.75, anchor_cat=3)
s.rest_platform('Heated rest platform (ondol-style)', 7.1, -3.7, w=2.4, d=1.9, rot=0)
for (px, py) in pg['ring']:
    s.vine_post(px, py, z, 2.5)
bx0, bx1, by0, by1 = pg['box']
s.vine_beam((bx0, by1, z + 2.7), (bx1, by1, z + 2.7))
s.vine_beam((bx0, by0, z + 2.7), (bx0, by1, z + 2.7))
for (hx, hy) in ((6.0, -2.55), (8.2, -2.55), (6.0, -4.95), (8.2, -4.95)):
    s.cone_planter(hx, hy, z + 2.85, drop=0.8)
s.string_lights((x1 + 0.3, y0 - 0.3, z + 2.4), (bx0, by1, z + 2.5), n=8, sag=0.25)
s.string_lights((bx0, by0, z + 2.5), (bx1, by1, z + 2.5), n=10, sag=0.3)

# loungers on the south deck
s.lounger(-1.3, -4.6, rot=0)
s.lounger(-0.3, -4.6, rot=0, pad='peach')
s.anchor('Loungers', -0.8, -4.6, z, 3, dz=1.0)

# ---- garden: tall Mexican fan palms, Mediterranean fan palm clumps, black pebble beds, agaves, boulders
for (px, py, h) in ((-7.6, -6.6, 8.0), (10.6, 3.2, 7.0), (-6.4, 5.4, 6.0)):
    s.palm(px, py, h=h, n=22)
for (px, py) in ((-4.8, 3.3), (4.4, 3.7)):
    for k, (dx, dy, hh) in enumerate(((0, 0, 2.2), (0.45, 0.2, 1.6), (-0.3, 0.35, 1.3))):
        s.palm(px + dx, py + dy, h=hh, n=14, lean=(dx * 0.12, dy * 0.12))
s.anchor('Fan palms (The Spring planting)', 10.6, 3.2, None, 3, dz=7.4)
s.mulch_bed(-7.8, -1.2, 3.2, 6.0, rot=4)
s.mulch_bed(11.7, -2.3, 2.6, 6.2, rot=-3)
for (px, py, sc) in ((-8.2, -2.6, 0.8), (-7.0, 0.6, 0.65), (11.5, -3.6, 0.85), (11.8, -0.4, 0.7)):
    s.agave(px, py, s=sc)
for (px, py, sc) in ((-7.7, -0.9, 1.3), (12.0, -2.0, 1.6), (-8.7, 1.4, 0.8)):
    s.boulder(px, py, sc)
for (px, py) in ((-7.4, -3.4), (11.2, 0.0)):
    s.yucca_rostrata(px, py, h=1.4)
s.path_stones([(-15, 9), (-11, 5.8), (-6.3, 1.0)])
s.path_stones([(0.0, -6.8), (0.6, -10.0), (0.0, -14)])

s.house('Permitted house (context)', *SK.HOUSE)
s.ground()
s.daylight(az=248, el=13, strength=4.4, sky=0.5)

hero = s.cam('hero', (-4.6, -12.6, z + 1.65), (1.8, 0.0, z + 1.2), lens=28)
inner = s.cam('inner', (3.15, -0.35, z + 1.5), (-3.0, 0.7, z + 0.85), lens=18)
dusk = s.cam('dusk', (3.6, -13.5, z + 1.7), (1.2, 0.2, z + 1.45), lens=26)

s.shot(hero, 'A_hero', samples=56)
s.set_sun(150, 58, 4.0)
s.shot(inner, 'A_inner', samples=64, exposure=0.7)
s.set_night(True)
s.set_sun(262, -1.5, 0.6)
s.sky.sun_intensity = 0.6
s.shot(dusk, 'A_dusk', samples=72, exposure=0.6)
s.set_night(False)
s.plan_shot('A_plan', width=23.0, center=(2.3, -0.9),
            note='Pool house 24 x 18 ft = 432 sq ft   terrace 51 x 37 ft')
