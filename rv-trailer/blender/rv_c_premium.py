"""Tier C - Premium: a 26-ft aluminium Airstream under a black steel ramada with a cedar-slat west end,
a 12 x 12 ft cedar deck with coral lattice screens, blush lounge chairs, olive trees in pots, string lights,
an outdoor shower, 12 kW of solar with battery, water and propane tanks, Starlink."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rvkit as RK

out, preview = RK.SK.args()
s = RK.Camp('RC', out, preview)

s.pad_gravel(17.0, 10.5, y=-1.2)
z = s.pad_z
s.airstream('Airstream Flying Cloud, about 26 ft', 0.0, 0.8, L=7.6, cat=0)
s.skirting(0.0, 0.8, 7.0, 2.4, h=0.5, color='#c9ccce')
s.shade_ramada('Black steel ramada, 39 x 23 ft, cedar-slat west end', 0.0, -0.6, L=12.0, W=7.0, H=4.0)
deck_top = s.free_deck('Cedar deck, 12 x 12 ft', 0.2, -2.3, w=3.66, d=3.66, h=0.5)
s.z = deck_top
for k in range(3):
    s.lattice('deck_screen', 1.15, 2.0, (-1.63, -2.3 - 1.2 + k * 1.2 + 0.0, deck_top + 1.0), math.pi / 2, 'camp', pattern='a')
s.anchor('Coral lattice screens', -1.63, -2.3, deck_top, 3, dz=2.1)
s.lounger(0.4, -2.6, rot=180)
s.lounger(1.3, -2.6, rot=180, pad='peach')
for (px, py) in ((-1.25, -3.75), (1.75, -3.75)):
    t = s.pot(px, py, r=0.3, h=0.55, mat='black_fabric')
    s.olive(px, py, h=1.8, z=t)
s.z = z
s.string_lights((-6.0, -4.1, z + 3.8), (6.0, -4.1, z + 3.8), n=16, sag=0.4)
s.shower('Outdoor shower', 4.6, -2.8, rot=180)
s.water_tank('1,550-gal water tank + pump', -8.6, 3.6, r=1.0, h=2.0, color='#e6e1d8')
s.propane_tank('250-gal propane tank', 9.6, 4.2)
s.solar_array('12 kW solar + 20 kWh battery (moves to the house)', 0.5, 9.0, cols=10, rows=2)
s.starlink(-7.2, -3.6)
s.storage_shed('Storage shed, 10 x 12 ft', -10.2, -3.9, color='#1f1f20', door='#df4537', cat=1)
s.car(12.2, -1.8, rot=90, color='#2b2d30')
for (px, py, h) in ((-7.4, -6.2, 6.0), (7.8, 6.8, 5.0)):
    s.palm(px, py, h=h, n=20)
for (px, py) in ((-3.6, -6.4), (4.2, -6.6)):
    s.agave(px, py, s=0.7)
s.house_frame('Your house going up', *RK.SK.HOUSE)
s.ground()
s.daylight(az=248, el=14, strength=4.4, sky=0.5)

hero = s.cam('hero', (6.5, -14.0, z + 1.6), (-0.8, 0.2, z + 1.7), lens=28)
dusk = s.cam('dusk', (5.5, -11.0, z + 1.6), (-0.4, -0.6, z + 1.8), lens=26)
s.shot(hero, 'RC_hero', samples=56)
s.set_night(True)
s.set_sun(262, -1.5, 0.6)
s.sky.sun_intensity = 0.6
s.shot(dusk, 'RC_dusk', samples=72, exposure=0.7)
s.set_night(False)
s.plan_shot('RC_plan', width=26.0, center=(-0.5, 1.5), note='Gravel pad 56 x 34 ft   ramada 39 x 23 ft   trailer 26 ft')
