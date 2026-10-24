"""Tier B - Balanced: a new four-season 30-ft travel trailer (Imagine / Arctic Fox class) under a 24 x 41 ft
steel RV cover, skirting, an 8 x 12 ft deck with coral lattice privacy panels, 6 kW of ground solar with a
battery that can later serve the house, water tank, 250-gal propane tank, power pedestal and Starlink."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rvkit as RK

out, preview = RK.SK.args()
s = RK.Camp('RB', out, preview)

s.pad_gravel(17.0, 10.0, y=-1.0)
z = s.pad_z
s.box_trailer('New 30-ft four-season travel trailer', 0.0, 0.8, L=9.0, style='modern', cat=0)
s.skirting(0.0, 0.8, 9.0, 2.44, h=0.58, color='#3a3a3b')
s.rv_cover('Steel RV cover, 24 x 41 ft, 14 ft legs', 0.0, -0.4, L=12.5, W=7.3, H=4.27, color='#ecebe7')
deck_top = s.free_deck('Freestanding 8 x 12 ft deck', -0.45, -1.75, w=3.66, d=2.44, h=0.55, rails=False)
for k in range(3):
    s.lattice('privacy_screen', 1.15, 1.8, (-2.33, -1.75 - 0.8 + k * 0.8 + 0.4, deck_top + 0.9), math.pi / 2, 'camp', pattern='a')
s.anchor('Coral lattice privacy screen', -2.33, -1.75, deck_top, 3, dz=1.9)
s.bistro_set(0.2, -1.7, z=deck_top)
for (px, py) in ((1.1, -2.6), (-1.9, -2.6)):
    t = s.pot(px, py, r=0.25, h=0.45, z=deck_top, mat='black_fabric')
    s.agave(px, py, z=t, s=0.45)
s.water_tank('1,550-gal water tank + pump', -8.4, 3.4, r=1.0, h=2.0)
s.propane_tank('250-gal propane tank', 9.6, 4.2, rot=0)
s.solar_array('6 kW ground solar + 10 kWh battery', 0.5, 8.6, cols=8, rows=2)
s.power_pole('Temporary power pole + 50 A pedestal', 8.4, -3.2)
s.starlink(-7.0, -3.4)
s.storage_shed('Storage shed, 10 x 12 ft', -10.0, -3.8, color='#1f1f20', door='#df4537', cat=1)
s.car(12.2, -1.8, rot=90, color='#4b5560')
for (px, py) in ((-3.4, -5.6), (3.8, -5.8), (-6.0, 6.0)):
    s.agave(px, py, s=0.65)
s.house_frame('Your house going up', *RK.SK.HOUSE)
s.ground()
s.daylight(az=248, el=14, strength=4.4, sky=0.5)

hero = s.cam('hero', (11.8, -13.5, z + 1.7), (-1.2, 0.4, z + 1.8), lens=28)
bird = s.cam('bird', (17.0, -19.0, z + 13.0), (-5.5, 5.0, z + 0.5), lens=28)
s.shot(hero, 'RB_hero', samples=56)
s.shot(bird, 'RB_bird', samples=48)
s.plan_shot('RB_plan', width=26.0, center=(-0.5, 1.5), note='Gravel pad 56 x 33 ft   RV cover 24 x 41 ft   trailer 30 ft')
