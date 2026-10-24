"""Scheme B - Jeongja Bathhouse: a hanok-inspired pavilion on a raised stone platform, in three 8-ft bays
(wash + scrub / soak / warm rest), with coral lattice and paper screens that glow at night; a cedar cabin
sauna, cold plunge and shower a few steps east."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spakit as SK

out, preview = SK.args()
s = SK.Spa('B', out, preview)
s.paper_glow = lambda: 3.0 if s.night else 0.0

s.terrace(16.0, 12.5, x=1.6, y=0.2)
z = s.z

# ---- raised stone platform (gidan), 2 ft high, with a hole for the sunken tub in the middle bay
W, L, PH = 7.3, 4.9, 0.6
zt = z + PH + 0.04          # finished floor: stone platform + 4 cm boards
tub = s.stadium(1.95, 1.95, r=0.22, cx=0.0, cy=-0.1)
s.hanok_plinth(W + 1.3, L + 1.3, PH, hole=(0.0, -0.1, 1.97, 1.97), steps=[(0.0, -(L + 1.3) / 2, 0), (W / 2 + 0.65, -1.2, 90)])
s.hanok_floor(W + 1.3, L + 1.3, z + PH, hole=(0.0, -0.1, 1.97, 1.97))
s.box('wet_floor', (2.6, L + 0.6, 0.02), (-W / 2 + 1.2, 0.0, zt + 0.01), s.mat('slate', '#3b3a39', rough=0.6), 'spa')
s.sunk_pool('Sunken tiled hot tub, 6.5 x 6.5 ft, 104 F max', tub, depth=0.95, z_top=zt, coping=0.22)

# ---- the pavilion: 24 x 16 ft, three bays, black-stained posts, upturned tile roof
g = s.rect_pavilion('Jeongja bathhouse, 24 x 16 ft, three bays', W, L, h=2.7, nx=4, ny=3, roof='hip', rise=1.7,
                    overhang=1.25, upturn=0.5, floor_z=zt, anchor_cat=0)
ring = g['ring']
x0, x1, y0, y1 = g['box']
for i in range(len(ring)):
    p1, p2 = ring[i], ring[(i + 1) % len(ring)]
    mx, my = (p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2
    if abs(my - y1) < 1e-6:                     # north: paper-backed ttisal screens (privacy, glow at night)
        s.bay(p1, p2, zt, g['h'], kind='screen', pattern='tti', back='paper', frieze=False)
    elif abs(mx - x0) < 1e-6:                   # west: behind the wash bay, key-fret lattice with paper
        s.bay(p1, p2, zt, g['h'], kind='screen', pattern='a', back='paper')
    elif abs(my - y0) < 1e-6:                   # south: wash bay screened with glass, soak + rest bays open to the view
        if mx < -1.5:
            s.bay(p1, p2, zt, g['h'], kind='screen', pattern='grid', back='glass')
        else:
            s.bay(p1, p2, zt, g['h'], kind='frieze')
    else:                                       # east: north half screened, south half open to the sauna steps
        if my > 0:
            s.bay(p1, p2, zt, g['h'], kind='screen', pattern='grid', back='glass')
        else:
            s.bay(p1, p2, zt, g['h'], kind='frieze')

# ---- bay 1 (west): seated wash + scrub
s.z = zt
s.scrub_station('Bay 1: two seated wash stations + scrub table', -2.45, 0.35, rot=90, roofed=False)
s.box('robe_bench', (0.4, 1.3, 0.42), (-3.3, -1.75, zt + 0.21), s.m('cedar_plain'), 'spa')
s.towel_rack(-2.0, -1.95, rot=0)
# ---- bay 2 (middle): soak; planting along the paper screen
top = s.planter(0.0, 1.95, 2.1, 0.5, h=0.4, z=zt)
s.fern(-0.65, 1.95, top, s=0.5)
s.bird_of_paradise(0.05, 1.95, top, s=1.05)
s.fern(0.7, 1.95, top, s=0.45, mat='leaf')
s.anchor('Bay 2 planter: bird of paradise + ferns', 0.0, 1.95, zt, 3, dz=1.0)
for (bx, by) in ((-1.0, 2.0), (1.05, 2.0)):
    t = s.pot(bx, by, r=0.24, h=0.5, z=zt, mat='black_fabric')
    s.bamboo(bx, by, h=2.4, n=6, spread=0.12, z=t)
for (hx, hy) in ((-1.9, 1.9), (1.95, -2.05), (3.2, 1.9)):
    s.hanging_plant(hx, hy, zt + g['h'] + 0.15, drop=0.7)
# ---- bay 3 (east): warm ondol platform, 7 x 8 ft, with the sikhye + egg station
s.rest_platform('Bay 3: heated ondol rest platform, 7 x 8 ft', 2.45, 0.1, w=2.13, d=2.44, rot=90, z=zt)
s.box('sikhye_cabinet', (0.9, 0.45, 0.85), (3.15, 2.0, zt + 0.425), s.m('timber'), 'spa')
s.box('sikhye_top', (0.95, 0.5, 0.04), (3.15, 2.0, zt + 0.87), s.m('cedar_plain'), 'spa')
s.cyl('egg_tray', 0.18, 0.05, (3.0, 2.0, zt + 0.92), s.m('coral'), 'spa', seg=24)
s.anchor('Sikhye + baked-egg station', 3.15, 2.0, zt, 3, dz=1.1)
# lanterns in the side bays (more than 5 ft from the water)
for (lx, ly) in ((-2.45, -0.6), (2.45, -0.9)):
    s.lantern(lx, ly, zt + 2.25, cord=0.5)
s.z = z

# ---- outside: sauna, cold plunge, shower to the east
s.cabin_sauna('Cedar cabin sauna, 7 x 7 ft', 7.4, 2.5, rot=-90, w=2.2, d=2.2)
s.cold_plunge('Cedar cold plunge tub', 6.4, -1.7, kind='cedar')
s.shower('Rinse shower', 7.9, -1.1, rot=90)
s.path_stones([(4.9, -1.2), (5.8, 0.4), (6.0, 2.4)], size=0.55, step=0.75)

# ---- garden: bamboo along the north (windbreak + backdrop), olives, stone-and-agave beds, palms
for bx in (-4.5, -1.5, 1.5, 4.5):
    t = s.planter(bx, 5.3, 2.4, 0.9, h=0.55)
    s.bamboo(bx, 5.3, h=4.4, n=14, spread=0.8, z=t)
s.anchor('Bamboo in raised planters (north windbreak)', -1.5, 5.3, z, 3, dz=3.0)
for (ox, oy) in ((-5.8, -4.6), (8.6, -4.2)):
    s.olive(ox, oy, h=2.8)
s.anchor('Olive trees', 8.6, -4.2, z, 3, dz=2.6)
s.mulch_bed(-9.0, -0.5, 2.6, 6.5)
for (px, py, sc) in ((-8.8, -2.3, 0.75), (-9.3, 1.4, 0.6)):
    s.agave(px, py, s=sc)
s.boulder(-8.7, 0.2, 1.4)
for (px, py, h) in ((-8.6, 5.9, 7.0), (11.0, 3.6, 6.2)):
    s.palm(px, py, h=h, n=20)
s.path_stones([(-15, 9), (-11.5, 6.8), (-8.0, 4.4)])
s.path_stones([(0.0, -6.4), (0.4, -10.0), (0.0, -14)])

s.house('Permitted house (context)', *SK.HOUSE)
s.ground()
s.daylight(az=248, el=13, strength=4.4, sky=0.5)

hero = s.cam('hero', (-5.8, -12.8, z + 1.7), (0.6, 0.0, z + 1.75), lens=28)
inner = s.cam('inner', (3.3, -2.2, zt + 1.45), (-3.0, 0.9, zt + 0.55), lens=18)
dusk = s.cam('dusk', (9.0, -11.5, z + 1.9), (0.4, 0.4, z + 1.9), lens=28)

s.shot(hero, 'B_hero', samples=56)
s.set_sun(150, 58, 4.0)
s.shot(inner, 'B_inner', samples=64, exposure=0.6)
s.set_night(True)
s.set_sun(262, -1.5, 0.6)
s.sky.sun_intensity = 0.6
s.shot(dusk, 'B_dusk', samples=72, exposure=0.6)
s.set_night(False)
s.plan_shot('B_plan', width=24.0, center=(1.9, 0.3),
            note='Pavilion 24 x 16 ft = 384 sq ft on a 28 x 20 ft stone platform, 2 ft high')
