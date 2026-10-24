"""Scheme D - Walled Garden Courtyard: blush plaster walls with tile caps make a 40 x 40 ft garden room,
out of the wind; a vine pergola over one in-ground hot tub in the middle; cedar sauna, clay dome warm room,
wash corner and a covered rest platform in the four corners; palms, bird of paradise and bougainvillea."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spakit as SK

out, preview = SK.args()
s = SK.Spa('D', out, preview)


def face(x, y, tx, ty):
    return math.degrees(math.atan2(ty - y, tx - x)) + 90


s.terrace(13.6, 13.6, x=0.0, y=0.0, mat='pavers')
z = s.z
R = 6.1          # inner half-size of the courtyard (wall centre lines)
H = 2.3          # wall height (7.5 ft)

# ---- garden walls: gate on the south, lattice windows on the other three sides
corners = [(-R, -R), (R, -R), (R, R), (-R, R)]
openings = {0: [(R - 0.85, R + 0.85, 0.0, 2.15)],             # south gate, 5.5 ft wide
            1: [(R - 0.8, R + 0.8, 1.0, 2.0)],                # east window
            2: [(R - 3.4, R - 1.8, 1.0, 2.0), (R + 1.8, R + 3.4, 1.0, 2.0)],
            3: [(R - 0.8, R + 0.8, 1.0, 2.0)]}
for k in range(4):
    p1, p2 = corners[k], corners[(k + 1) % 4]
    root, Lw, ang = s.wall(p1, p2, H, openings=openings[k])
    for (a, b, sill, head) in openings[k]:
        t = (a + b) / 2
        cx, cy = p1[0] + math.cos(ang) * t, p1[1] + math.sin(ang) * t
        if sill > 0:
            s.lattice('wall_window', b - a, head - sill, (cx, cy, z + (sill + head) / 2), ang, 'spa', pattern='a')
s.anchor('Blush plaster walls, 7.5 ft, tile caps', -R, 0.0, z, 0, dz=2.6)
# gate leaves (coral lattice), hinged at the jambs and swung 70 degrees into the courtyard
for sgn in (-1, 1):
    a = math.radians(90 + sgn * 20)
    hx, hy = sgn * 0.85, -R
    s.lattice('gate_leaf', 0.84, 2.1, (hx + math.cos(a) * 0.42, hy + math.sin(a) * 0.42, z + 1.07), a, 'spa', pattern='a')
s.anchor('Coral lattice gate', 0.0, -R, z, 0, dz=2.4)

# ---- centre: vine pergola (14 x 14 ft) over one round cedar soaking tub
pg = s.rect_pavilion('Vine pergola, 14 x 14 ft', 4.3, 4.3, h=2.6, nx=2, ny=2, roof='pergola', cx=0.0, cy=0.6, anchor_cat=3)
s.sunk_pool('In-ground round hot tub, 6.5 ft', s.stadium(2.0, 2.0, r=1.0, n=16, cx=0.0, cy=0.6), depth=0.95,
            coping=0.3, steps_at=(0.0, 0.6 - 0.82, 0))
for (px, py) in pg['ring']:
    s.vine_post(px, py, z, 2.55)
bx0, bx1, by0, by1 = pg['box']
for (a, b) in (((bx0, by1), (bx1, by1)), ((bx0, by0), (bx0, by1)), ((bx1, by0), (bx1, by1)), ((bx0, by0), (bx1, by0))):
    s.vine_beam((a[0], a[1], z + 2.78), (b[0], b[1], z + 2.78), density=70)
s.anchor('Star jasmine on posts and beams', bx1, by1, z, 3, dz=2.0)
for (lx, ly) in pg['ring']:
    s.lantern(lx * 0.92, 0.6 + (ly - 0.6) * 0.92, z + 2.2, cord=0.4)

# ---- corners: sauna (NE), clay dome warm room (NW), wash + scrub (SW), covered rest platform (SE)
s.cabin_sauna('Cedar cabin sauna, 7 x 7 ft', 4.4, 4.4, rot=face(4.4, 4.4, 0.0, 0.6), w=2.2, d=2.2)
s.cold_plunge('Cold plunge (stock tank + chiller)', 4.7, 1.2, kind='stock', rot=90)
s.shower('Rinse shower', 5.55, -0.4, rot=90)
s.clay_dome('Clay dome warm room (after the Korean hanjeungmak)', -4.3, 4.3, r=1.4, rot=face(-4.3, 4.3, 0.0, 0.6))
s.scrub_station('Wash + scrub corner (roofed)', -4.3, -4.55, rot=180)
rp = s.rect_pavilion('Covered rest platform', 3.0, 2.6, h=2.3, nx=2, ny=2, roof='flat', overhang=0.3, cx=4.35, cy=-4.4, anchor_cat=3)
s.rest_platform('Heated rest platform (ondol-style)', 4.35, -4.4, w=2.4, d=2.0, rot=0)

# ---- planting inside the walls
top = s.planter(-5.55, 0.2, 0.8, 4.6, h=0.5)
for (py, kind) in ((-1.6, 'bop'), (-0.3, 'fern'), (1.0, 'bop'), (2.1, 'fern')):
    if kind == 'bop':
        s.bird_of_paradise(-5.55, py, top, s=1.2)
    else:
        s.fern(-5.55, py, top, s=0.55)
s.anchor('Bird of paradise + ferns (west bed)', -5.55, 0.2, z, 3, dz=1.4)
top = s.planter(0.0, 5.55, 4.6, 0.8, h=0.5)
for bx in (-1.6, 0.0, 1.6):
    s.bamboo(bx, 5.55, h=3.8, n=10, spread=0.35, z=top)
s.anchor('Bamboo bed against the north wall', 0.0, 5.55, z, 3, dz=3.0)
s.wall_creeper((R - 0.15, -2.4), (R - 0.15, 3.0), z + 0.3, z + 2.3, side=1, density=70)
s.wall_creeper((-3.0, -R + 0.15), (-1.1, -R + 0.15), z + 0.2, z + 2.2, side=1, density=70)
s.anchor('Bougainvillea on the walls', R - 0.2, 1.0, z, 3, dz=1.6)
for (px, py) in ((-2.9, -2.6), (2.9, -2.4)):
    t = s.pot(px, py, r=0.42, h=0.6, mat='black_fabric')
    s.palm(px, py, h=2.0, z=t, n=16)
    s.palm(px + 0.35, py + 0.2, h=1.4, z=t, n=12, lean=(0.08, 0.04))
s.anchor('Mediterranean fan palms in pots', -2.9, -2.6, z, 3, dz=2.6)
for (gx, gy, w, d) in ((-3.0, 1.6, 1.3, 3.2), (3.0, 1.6, 1.0, 1.6), (-1.5, -3.6, 2.0, 0.9), (1.6, -3.6, 1.8, 0.9)):
    top = s.planter(gx, gy, w, d, h=0.3)
    s.groundcover(gx, gy, w - 0.15, d - 0.15, z=top, density=220, mat='leaf_light')
for (px, py) in ((-3.0, 0.6), (-3.0, 2.6)):
    s.fern(px, py, z + 0.25, s=0.45)

# ---- outside the walls: tall palms over the wall line, agaves
for (px, py, h) in ((-8.2, 7.4, 8.0), (8.4, -8.0, 7.2), (7.8, 7.8, 6.4)):
    s.palm(px, py, h=h, n=22)
for (px, py) in ((-8.5, -3.0), (-8.8, 1.8), (8.6, -2.6), (2.5, -8.6), (-3.2, -8.8)):
    s.agave(px, py, s=0.8)
s.path_stones([(-15, 9), (-11, 2), (-6, -8.4), (0.0, -8.0)])
s.path_stones([(0.0, -8.0), (0.0, -14.0)])

s.house('Permitted house (context)', *SK.HOUSE)
s.ground()
s.daylight(az=248, el=13, strength=4.4, sky=0.5)

hero = s.cam('hero', (-5.5, -13.2, z + 1.7), (0.3, -2.0, z + 2.0), lens=26)
bird = s.cam('bird', (-11.5, -14.5, z + 13.0), (0.3, 0.4, z + 0.5), lens=30)
inner = s.cam('inner', (-1.9, -1.55, z + 1.5), (1.8, 3.2, z + 0.9), lens=18)
dusk = s.cam('dusk', (-5.1, -0.5, z + 1.6), (1.6, 2.2, z + 1.2), lens=20)

s.shot(hero, 'D_hero', samples=56)
s.shot(bird, 'D_bird', samples=48)
s.set_sun(150, 58, 4.0)
s.shot(inner, 'D_inner', samples=64, exposure=0.4)
s.set_night(True)
s.set_sun(262, -1.5, 0.6)
s.sky.sun_intensity = 0.6
s.shot(dusk, 'D_dusk', samples=72, exposure=0.7)
s.set_night(False)
s.plan_shot('D_plan', width=18.5, center=(0.0, 0.0),
            note='Courtyard 40 x 40 ft inside the walls = 1,600 sq ft; walls 7.5 ft')
