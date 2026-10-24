"""Tier A - Lean, used: an older 28-ft travel trailer on a gravel pad, a shade sail over the door side,
vinyl skirting, a small deck, a 1,550-gal water tank, generator + a few solar panels, and a 10 x 12 ft
storage shed (the no-permit size). Pump-out service until the septic is in."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rvkit as RK

out, preview = RK.SK.args()
s = RK.Camp('RA', out, preview)

s.pad_gravel(17.0, 10.0, y=-1.0)
z = s.pad_z
s.box_trailer('Used 28-ft travel trailer (about 2017-2019)', 0.0, 0.8, L=8.5, style='classic', awning_open=True, cat=0)
s.skirting(0.0, 0.8, 8.5, 2.44, h=0.55, color='#cfc6b6')
s.anchor('Vinyl skirting (keeps out cold + rodents)', -3.5, -0.4, z, 0, dz=0.5)
s.shade_sail('Shade sail on the west + door side', [(-6.2, -4.2), (2.5, -4.6), (2.0, 3.2), (-6.0, 3.4)], posts_h=(3.4, 4.2, 4.4, 3.6))
deck_top = s.free_deck('Freestanding 8 x 8 ft deck + steps', -0.45, -1.75, w=2.44, d=2.44, h=0.5)
s.bistro_set(-0.6, -1.7, z=deck_top)
s.water_tank('1,550-gal water tank + pump', -8.2, 3.2, r=1.0, h=2.0)
s.generator(5.6, 1.6)
s.anchor('Inverter generator (backup for A/C)', 5.6, 1.6, z, 2, dz=0.8)
s.solar_array('Starter solar: 6 panels + battery', 1.0, 8.0, cols=6, rows=1)
s.starlink(-6.8, -3.4)
s.anchor('Starlink dish', -6.8, -3.4, z, 2, dz=2.6)
s.storage_shed('Storage shed, 10 x 12 ft (no permit if no power)', -9.8, -3.6, rot=0, color='#e8e1d4', door='#df4537', cat=1)
s.car(12.0, -1.6, rot=90)
for (px, py) in ((-3.2, -5.2), (3.6, -5.4)):
    s.agave(px, py, s=0.6)
s.house_frame('Your house going up (permit issued first)', *RK.SK.HOUSE)
s.ground()
s.daylight(az=248, el=14, strength=4.4, sky=0.5)

hero = s.cam('hero', (11.5, -13.0, z + 1.7), (-1.2, 0.6, z + 1.5), lens=28)
s.shot(hero, 'RA_hero', samples=56)
s.plan_shot('RA_plan', width=26.0, center=(-0.5, 1.5), note='Gravel pad 56 x 33 ft   trailer 28 ft')
