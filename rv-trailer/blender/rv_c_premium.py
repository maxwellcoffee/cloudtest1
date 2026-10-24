"""Tier C - Premium: a 25-ft aluminium Airstream under a black steel ramada with a cedar-slat west end,
a 12 x 12 ft cedar deck with coral lattice screens, blush lounge chairs, olive trees in pots, string lights,
an outdoor shower, 28 solar panels (about 12 kW) with battery, water and propane tanks, Starlink, and a
storage shed off the pad."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rvkit as RK

out, preview = RK.SK.args()
s = RK.Camp('RC', out, preview)

s.pad_gravel(17.0, 10.5, y=-1.2)
z = s.pad_z
s.z = z
TX, TY, TL, TW = 0.0, 0.8, 6.83, 2.59
s.shell_trailer('Airstream Flying Cloud 25FB, 26 ft 2 in overall', TX, TY, L=TL, W=TW, kind='airstream', cat=0)
s.skirting(TX, TY, TL - 0.4, TW, h=0.4, color='#5f6467', inset=0.16)
s.shade_ramada('Black steel ramada, 39 x 23 ft, cedar-slat west end', 0.0, -0.6, L=12.0, W=7.0, H=4.0)
DY = TY - TW / 2 - 0.08 - 1.83
deck_top = s.free_deck('Cedar deck, 12 x 12 ft', 0.0, DY, w=3.66, d=3.66, h=0.5)
s.z = deck_top
for k in range(3):
    s.lattice('deck_screen', 1.05, 2.0, (-1.78, DY - 1.1 + k * 1.1, deck_top + 1.0), math.pi / 2, 'camp', pattern='a')
s.anchor('Coral lattice screens', -1.78, DY, deck_top, 3, dz=2.1)
s.lounger(0.25, DY - 0.35, rot=180)
s.lounger(1.1, DY - 0.35, rot=180, pad='peach')
t = s.pot(-1.35, DY - 1.4, r=0.3, h=0.55, mat='black_fabric', z=deck_top)
s.olive(-1.35, DY - 1.4, h=1.8, z=t)
s.z = z
t = s.pot(-4.2, -2.6, r=0.34, h=0.6, mat='black_fabric')
s.olive(-4.2, -2.6, h=2.1, z=t)
s.string_lights((-6.0, -4.1, z + 3.8), (6.0, -4.1, z + 3.8), n=16, sag=0.4, coll='lights')
s.shower('Outdoor shower', 5.0, -1.4, rot=180, coll='camp', cat=3)
s.water_tank('1,550-gal water tank + pump', 8.4, 2.6, r=1.0, h=2.0, color='#e6e1d8')
s.propane_tank('250-gal propane tank', -9.2, 3.6)
s.solar_array('28 panels (about 12 kW) + 20 kWh battery (moves to the house)', -1.2, 12.7, cols=14, rows=2, battery=True)   # clear of the ramada's winter shadow
s.starlink('Starlink dish on a short mast', 7.4, -3.6)
s.storage_shed('Storage shed, 10 x 12 ft, off the pad', -12.0, -2.0, color='#3a3a3c', door='#df4537', cat=1)
s.pickup(11.6, 4.0, rot=90, color='#2b2d30')
for (px, py, h) in ((-7.6, -6.4, 6.0), (8.4, 6.6, 5.0)):
    s.palm(px, py, h=h, n=20)
for (px, py) in ((-3.6, -6.6), (3.4, -6.8)):
    s.agave(px, py, s=0.7)
s.house_frame('Your house going up', *RK.SK.HOUSE)
CAM, TGT = (9.6, -12.6, z + 1.6), (-0.6, 0.4, z + 1.7)
DUSK, DT = (7.8, -10.0, z + 1.5), (-0.4, 0.0, z + 1.8)
s.keep_clear(CAM, TGT, width=5.0)
s.keep_clear(DUSK, DT, width=4.0)
s.clear_view(CAM, TGT)
s.clear_view(DUSK, DT)
s.ground()
s.daylight(az=235, el=30, strength=4.4, sky=0.5)

hero = s.cam('hero', CAM, TGT, lens=27)
dusk = s.cam('dusk', DUSK, DT, lens=26)
s.shot(hero, 'RC_hero', samples=56)
s.set_night(True)
s.set_sun(262, -1.5, 0.6)
s.sky.sun_intensity = 0.6
s.shot(dusk, 'RC_dusk', samples=72, exposure=0.7)
s.set_night(False)
s.plan_shot('RC_plan', width=34.0, center=(-0.5, 4.4), note='Gravel pad 56 x 34 ft   ramada 39 x 23 ft   trailer 26 ft overall')
