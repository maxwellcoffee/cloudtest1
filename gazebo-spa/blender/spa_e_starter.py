"""Scheme E - Starter Kit: the lean version. A 12 x 12 ft cedar gazebo kit over a
plug-and-play hot tub recessed into the ground, two coral lattice screens on the wind side, potted plants inside; a 6-ft cedar barrel
sauna, stock-tank plunge and post shower beside it. Everything can move to its final spot later."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import spakit as SK

out, preview = SK.args()
s = SK.Spa('E', out, preview)

s.terrace(9.8, 7.4, x=1.2, y=-0.3, mat='pavers')
z = s.z

G = 3.66
g = s.rect_pavilion('Cedar gazebo kit, 12 x 12 ft', G, G, h=2.35, nx=2, ny=2, roof='hip', rise=1.15, overhang=0.45,
                    post_mat='cedar_plain', plinths=False, anchor_cat=0)
ring = g['ring']          # SW, SE, NE, NW
s.bay(ring[2], ring[3], z, g['h'], kind='screen', pattern='a')         # north
s.bay(ring[3], ring[0], z, g['h'], kind='screen', pattern='grid')      # west
s.bay(ring[0], ring[1], z, g['h'], kind='frieze')
s.bay(ring[1], ring[2], z, g['h'], kind='frieze')
s.anchor('Two coral lattice screens on the wind side', ring[3][0], 0.0, z, 0, dz=1.5)

s.sunk_pool('Recessed hot tub, 7 x 7 ft, rim at ground level', s.stadium(1.85, 1.85, r=0.35, n=8, cx=0.15, cy=-0.1), depth=0.9,
            coping=0.14, band=0.06, lining='acrylic', band_mat='acrylic', coping_mat='acrylic')
s.box('equipment_hatch', (0.9, 0.55, 0.05), (1.62, -0.1, z + 0.025), s.m('cedar_h'), 'spa')
s.anchor('Hatch to the tub equipment (pumps, heater)', 1.62, -0.1, z, 0, dz=0.3)
for (px, py, kind) in ((-1.5, 1.5, 'palm'), (1.55, 1.5, 'bop'), (-1.55, -1.5, 'fern')):
    t = s.pot(px, py, r=0.28, h=0.5, mat='black_fabric' if kind != 'fern' else 'plaster')
    if kind == 'palm':
        s.palm(px, py, h=1.4, z=t, n=14)
    elif kind == 'bop':
        s.bird_of_paradise(px, py, t, s=1.0)
    else:
        s.fern(px, py, t, s=0.5)
s.anchor('Potted palm, bird of paradise, fern', 1.55, 1.5, z, 3, dz=1.6)
s.hanging_plant(-1.5, -1.55, z + g['h'] + 0.1, drop=0.6)

s.barrel_sauna('Cedar barrel sauna, 6 ft (2-4 people)', 4.65, 0.75, rot=180, L=1.85, r=0.9)
s.cold_plunge('Stock-tank cold plunge', 3.6, -2.35, kind='stock', rot=0)
s.shower('Post shower', 5.2, -2.1, rot=180)
s.lounger(-2.8, -1.1, rot=90)
s.lounger(-2.8, 0.15, rot=90, pad='peach')
s.anchor('Loungers', -2.8, -0.45, z, 3, dz=1.0)
s.string_lights((ring[1][0], ring[1][1], z + 2.4), (4.0, -3.6, z + 2.3), n=8, sag=0.25)
s.box('light_post', (0.1, 0.1, 2.4), (4.0, -3.6, z + 1.2), s.m('timber'), 'spa')
for (px, py) in ((-3.4, 3.4), (5.6, 2.9), (-0.5, -4.5)):
    s.agave(px, py, s=0.7)
s.path_stones([(-15, 9), (-9, 4), (-3.9, 0.8)])

s.house('Permitted house (context)', *SK.HOUSE)
s.ground()
s.daylight(az=248, el=13, strength=4.4, sky=0.5)

hero = s.cam('hero', (-4.6, -8.8, z + 1.65), (1.4, 0.0, z + 1.25), lens=28)
inner = s.cam('inner', (1.35, -2.75, z + 1.6), (-1.0, 1.2, z + 0.85), lens=20)
dusk = s.cam('dusk', (7.8, -7.0, z + 1.8), (1.2, 0.0, z + 1.3), lens=28)

s.shot(hero, 'E_hero', samples=56)
s.set_sun(150, 58, 4.0)
s.shot(inner, 'E_inner', samples=64, exposure=0.4)
s.set_night(True)
s.set_sun(262, -1.5, 0.6)
s.sky.sun_intensity = 0.6
s.shot(dusk, 'E_dusk', samples=72, exposure=0.7)
s.set_night(False)
s.plan_shot('E_plan', width=13.0, center=(1.2, -0.3), note='Gazebo kit 12 x 12 ft = 144 sq ft   pad 32 x 24 ft')
