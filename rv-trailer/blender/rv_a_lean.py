"""Tier A - Lean, used: an older 28-ft travel trailer (about 24 ft of body) on a gravel pad, a shade sail
over the door side, vinyl skirting, an 8 x 8 ft deck, a 1,550-gal water tank, an inverter generator parked
about 18 ft east, six solar panels with a small battery, Starlink, and a 10 x 12 ft storage shed off the
pad. Pump-out service until the septic is in."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rvkit as RK

out, preview = RK.SK.args()
s = RK.Camp('RA', out, preview)

s.pad_gravel(17.0, 10.0, y=-1.0)
z = s.pad_z
s.z = z
TX, TY, TL = -0.5, 0.8, 7.4
s.box_trailer('Used 28-ft travel trailer (about 2017-2019)', TX, TY, L=TL, style='classic', cat=0)
s.skirting(TX, TY, TL, 2.44, h=0.55, color='#9c8a70')
s.anchor('Vinyl skirting (keeps out cold + rodents)', TX - 3.0, TY - 1.22, z, 0, dz=0.45)
dx = TX - TL * 0.08                                   # the door
s.shade_sail('Shade sail over the door side', [(-5.6, -0.95), (2.6, -1.0), (2.9, -5.2), (-5.9, -4.8)], posts_h=(3.6, 2.8, 3.4, 2.5))
deck_top = s.free_deck('Freestanding 8 x 8 ft deck + steps', dx, TY - 1.22 - 0.06 - 1.22, w=2.44, d=2.44, h=0.5)
s.bistro_set(dx - 0.2, TY - 2.55, z=deck_top)
s.water_tank('1,550-gal water tank + pump', 6.4, 3.4, r=1.0, h=2.0)
s.generator('Inverter generator, about 18 ft east (backup for A/C)', 9.4, -0.6)
s.solar_array('Starter solar: 6 panels + small battery', 0.0, 7.6, cols=6, rows=1, battery=True)
s.starlink('Starlink dish on a short mast', 4.9, -2.9)
s.storage_shed('Storage shed, 10 x 12 ft, off the pad', -11.6, -1.8, color='#3a3a3c', door='#df4537', cat=1)
s.pickup(11.6, 4.0, rot=90)
for (px, py) in ((-3.4, -5.6), (3.9, -5.7)):
    s.agave(px, py, s=0.6)
s.house_frame('Your house going up (permit issued first)', *RK.SK.HOUSE)
CAM, TGT = (12.5, -13.5, z + 1.7), (-1.4, 0.4, z + 1.6)
s.keep_clear(CAM, TGT, width=5.0)
s.ground()
s.daylight(az=235, el=30, strength=4.4, sky=0.5)

hero = s.cam('hero', CAM, TGT, lens=26)
s.shot(hero, 'RA_hero', samples=56)
s.plan_shot('RA_plan', width=28.5, center=(-0.5, 2.3), note='Gravel pad 56 x 33 ft   trailer 28 ft overall')
