"""Tier B - Balanced: a new four-season 30-ft travel trailer (Imagine / Arctic Fox class) under a 24 x 41 ft
steel RV cover, skirting, an 8 x 12 ft deck with coral lattice privacy panels, 14 solar panels (about 6 kW)
with a battery that can later serve the house, water tank, 250-gal propane tank, Starlink, and a storage shed
off the pad."""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rvkit as RK

out, preview = RK.SK.args()
s = RK.Camp('RB', out, preview)

s.pad_gravel(17.0, 10.0, y=-1.0)
z = s.pad_z
s.z = z
TX, TY, TL = 0.0, 0.8, 7.9
s.box_trailer('New 30-ft four-season travel trailer', TX, TY, L=TL, style='modern', cat=0)
s.skirting(TX, TY, TL, 2.44, h=0.58, color='#6f7275')
legs = s.rv_cover('Steel RV cover, 24 x 41 ft, 14 ft legs', 0.0, -0.4, L=12.5, W=7.3, H=4.27, color='#ecebe7', bays=4)
DX = (legs[1] + legs[2]) / 2                           # centre the deck in the bay that holds the door
deck_top = s.free_deck('Freestanding 8 x 12 ft deck', DX, TY - 1.22 - 0.06 - 1.22, w=3.66, d=2.44, h=0.55)
for k in range(3):
    s.lattice('privacy_screen', 0.78, 1.8, (DX - 1.78, TY - 2.5 - 0.8 + k * 0.8, deck_top + 0.9), math.pi / 2, 'camp', pattern='a')
s.anchor('Coral lattice privacy screen', DX - 1.78, TY - 2.5, deck_top, 3, dz=1.9)
s.bistro_set(DX + 0.6, TY - 2.5, z=deck_top)
for (px, py) in ((DX + 1.55, TY - 3.45), (DX - 1.35, TY - 3.45)):
    t = s.pot(px, py, r=0.25, h=0.45, z=deck_top, mat='black_fabric')
    s.agave(px, py, z=t, s=0.45)
s.water_tank('1,550-gal water tank + pump', 7.9, 2.4, r=1.0, h=2.0)
s.propane_tank('250-gal propane tank', 8.6, 5.6, rot=0)
s.solar_array('14 panels (about 6 kW) + 10 kWh battery', -0.5, 11.1, cols=14, rows=1, battery=True)   # north of the cover's winter shadow
s.starlink('Starlink dish on a short mast', 7.2, -3.2)
s.generator('Backup inverter generator', 11.4, 0.4)
s.storage_shed('Storage shed, 10 x 12 ft, off the pad', -11.8, -1.8, color='#3a3a3c', door='#df4537', cat=1)
s.pickup(11.6, 4.0, rot=90, color='#4b5560')
for (px, py) in ((-3.4, -6.0), (3.8, -6.2), (-7.6, 5.8)):
    s.agave(px, py, s=0.65)
s.house_frame('Your house going up', *RK.SK.HOUSE)
CAM, TGT = (12.8, -14.0, z + 1.7), (-1.2, 0.4, z + 1.9)
BIRD, BT = (18.0, -20.0, z + 14.0), (-4.5, 4.5, z + 0.5)
s.keep_clear(CAM, TGT, width=5.0)
s.clear_view(CAM, TGT)
s.ground()
s.daylight(az=235, el=30, strength=4.4, sky=0.5)

hero = s.cam('hero', CAM, TGT, lens=26)
bird = s.cam('bird', BIRD, BT, lens=28)
s.shot(hero, 'RB_hero', samples=56)
s.shot(bird, 'RB_bird', samples=48)
s.plan_shot('RB_plan', width=29.5, center=(-0.5, 2.8), note='Gravel pad 56 x 33 ft   RV cover 24 x 41 ft   trailer 30 ft overall')
