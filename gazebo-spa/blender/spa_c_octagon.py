"""Scheme C - Octagon Garden Gazebo: an octagonal timber gazebo around one round in-ground hot tub, screened
with coral lattice on the windward side, planted inside; a cedar barrel sauna a few steps east."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spakit as SK

out, preview = SK.args()
s = SK.Spa('C', out, preview)

s.terrace(15.0, 11.0, x=1.6, y=0.0)
z = s.z

# ---- the gazebo: 8 posts on a 3.3 m radius (about 21 ft across), cupola vents the steam
g = s.oct_pavilion('Octagonal gazebo, 21 ft across', 3.3, h=2.85, rise=2.0)
ring = g['ring']
# faces k: between ring[k] and ring[k+1]; face 0 faces east, then counter-clockwise (NE, N, NW, W, SW, S, SE)
for k in range(8):
    p1, p2 = ring[k], ring[(k + 1) % 8]
    if k in (2, 3, 4, 5):          # N, NW, W, SW: windbreak screens (westerly winds), glass behind on W and NW
        s.bay(p1, p2, z, g['h'], kind='screen', pattern='a' if k in (3, 4) else 'grid',
              back='glass' if k in (3, 4) else None, frieze=False)
    elif k == 6:                   # S: entry, open with a frieze
        s.bay(p1, p2, z, g['h'], kind='frieze')
    else:                          # E, NE, SE: open to the view, low lattice railing + frieze
        if k != 0:
            s.bay(p1, p2, z, g['h'], kind='half', pattern='yong')
        s.bay(p1, p2, z, g['h'], kind='frieze')

# ---- the one hot tub: in-ground, round, 8 ft across, plaster with a blue mosaic waterline and stone coping
s.sunk_pool('In-ground round hot tub, 8 ft', s.stadium(2.5, 2.5, r=1.25, n=16, cx=0.0, cy=0.15), depth=0.95,
            coping=0.28, steps_at=(0.0, 0.15 - 1.05, 0))

# ---- planting inside the screened half: planters along N/NW/W/SW faces, palms in pots, hanging pothos
for k in (2, 3, 4, 5):
    (x1, y1), (x2, y2) = ring[k], ring[(k + 1) % 8]
    mx, my = (x1 + x2) / 2 * 0.86, (y1 + y2) / 2 * 0.86
    ang = math.degrees(math.atan2(y2 - y1, x2 - x1))
    top = s.planter(mx, my, 2.0, 0.5, h=0.42, rot=ang)
    s.fern(mx + 0.4 * math.cos(math.radians(ang)), my + 0.4 * math.sin(math.radians(ang)), top, s=0.55)
    s.fern(mx - 0.5 * math.cos(math.radians(ang)), my - 0.5 * math.sin(math.radians(ang)), top, s=0.45, mat='leaf')
    if k in (3, 5):
        s.bird_of_paradise(mx, my, top, s=1.05)
    else:
        s.snake_plant(mx, my, top, s=0.7)
s.anchor('Planters: ferns, bird of paradise, snake plant', ring[3][0] * 0.8, ring[3][1] * 0.8, z, 3, dz=1.0)
for (px, py) in (ring[2], ring[5]):
    t = s.pot(px * 0.78, py * 0.78, r=0.32, h=0.55, mat='black_fabric')
    s.palm(px * 0.78, py * 0.78, h=1.5, z=t, n=14, kind='fan')
s.anchor('Potted fan palms', ring[2][0] * 0.78, ring[2][1] * 0.78, z, 3, dz=2.2)
for k in (1, 3, 5, 7):
    (x1, y1), (x2, y2) = ring[k], ring[(k + 1) % 8]
    s.hanging_plant((x1 + x2) / 2 * 0.93, (y1 + y2) / 2 * 0.93, z + g['h'] - 0.05, drop=0.6)
s.anchor('Hanging pothos on the beams', (ring[1][0] + ring[2][0]) / 2 * 0.93, (ring[1][1] + ring[2][1]) / 2 * 0.93, z, 3, dz=2.3)
for k in (6, 7):                    # star jasmine on the two entry posts
    s.vine_post(ring[k][0], ring[k][1], z, g['h'] - 0.1)
s.anchor('Star jasmine on the entry posts', ring[6][0], ring[6][1], z, 3, dz=1.5)

# robe bench + towels inside the entry
s.box('robe_bench', (1.3, 0.4, 0.42), (-1.9, -2.15, z + 0.21), s.m('cedar_plain'), 'spa', rot=(0, 0, math.radians(-25)))
s.towel_rack(1.95, -2.25, rot=25)

# lanterns: more than 5 ft (1.5 m) from the water, per the electrical rule
for k in (0, 2, 4, 6):
    (px, py) = ring[k]
    s.lantern(px * 0.9, py * 0.9, z + 2.35, cord=0.45)
s.string_lights((ring[7][0], ring[7][1], z + 2.75), (5.2, -3.4, z + 2.4), n=10, sag=0.35)

# ---- the sauna: cedar barrel, 6 ft across x 7 ft, door facing the gazebo (8 ft away)
s.barrel_sauna('Cedar barrel sauna (2-4 people)', 6.4, 1.1, rot=180, L=2.15, r=0.92)
s.deck(2.6, 3.4, 6.4, 1.1)

# ---- cold plunge + rinse shower on the path between sauna and tub
s.cold_plunge('Cold plunge (stock tank + chiller)', 5.1, -2.5, kind='stock', rot=0)
s.shower('Outdoor rinse shower', 6.9, -2.2, rot=180)

# ---- seshin scrub corner tucked behind the west screen, roofed
s.scrub_station('Scrub + seated wash station', -5.5, 0.2, rot=-90)

# ---- rest: loungers and a floor platform under the string lights
s.lounger(3.2, -4.3, rot=0)
s.lounger(4.2, -4.3, rot=0, pad='peach')
s.anchor('Loungers for the rest round', 3.7, -4.3, z, 3, dz=1.0)
s.rest_platform('Warm rest platform (ondol-style)', -3.2, -4.2, w=2.4, d=1.8, rot=0)

# ---- garden around the terrace (The Spring's palms + native planting)
for (px, py, h) in ((-8.8, -6.4, 6.5), (-6.8, 6.2, 5.2), (9.6, 5.4, 7.0), (11.0, -7.4, 5.8)):
    s.palm(px, py, h=h, n=20)
s.anchor('Fan palms (low water once established)', 9.6, 5.4, None, 3, dz=7.4)
for (px, py) in ((-8.5, -1.5), (-8.8, 2.8), (3.5, -6.6), (-1.5, 6.4), (9.4, -1.0), (8.0, 7.2)):
    s.agave(px, py, s=0.75)
for (px, py) in ((-2.8, -6.8), (5.8, 6.9), (-9.2, 5.4)):
    s.yucca_rostrata(px, py, h=1.3)
s.path_stones([(-15, 9), (-11, 5.8), (-8.2, 2.5)])            # from the house
s.path_stones([(2.0, -6.0), (2.0, -9.5), (1.0, -14)])         # from the trailer / parking

s.house('Permitted house (context)', *SK.HOUSE)
s.ground()
s.daylight(az=248, el=13, strength=4.4, sky=0.5)

# ---- cameras
hero = s.cam('hero', (2.5, -13.0, z + 1.65), (0.4, 0.3, z + 1.8), lens=28)
inner = s.cam('inner', (1.7, -2.45, z + 1.45), (-1.4, 1.9, z + 0.95), lens=18)
dusk = s.cam('dusk', (12.5, -6.0, z + 1.9), (0.8, 0.4, z + 1.7), lens=28)
bird = s.cam('bird', (-14, -17, z + 13), (1.5, 0.0, z + 1.0), lens=30)

s.shot(hero, 'C_hero', samples=56)
s.shot(bird, 'C_bird', samples=48)
s.set_sun(150, 58, 4.0)
s.shot(inner, 'C_inner', samples=64, exposure=0.35)
s.set_night(True)
s.set_sun(262, -1.5, 0.6)
s.sky.sun_intensity = 0.6
s.shot(dusk, 'C_dusk', samples=72, exposure=0.6)
s.set_night(False)
s.plan_shot('C_plan', width=26.0, center=(1.4, -0.4),
            note='Gazebo 21 ft across, about 340 sq ft under roof   terrace 49 x 36 ft')
