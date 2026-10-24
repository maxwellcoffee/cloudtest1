"""What it could look like: four kinds of trailer side by side on one pad, hitches east, doors facing you.
Left to right: fiberglass double-hull (Oliver class), aluminium Airstream, new four-season trailer, older used trailer."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rvkit as RK

out, preview = RK.SK.args()
s = RK.Camp('RL', out, preview)
s.pad_gravel(44.0, 9.0, y=0.0)
z = s.pad_z
s.egg_trailer('Fiberglass double-hull, 24 ft', -16.0, 0.0)
s.airstream('Aluminium Airstream, 26 ft', -5.5, 0.0, L=7.6)
s.box_trailer('New four-season, 30 ft', 5.5, 0.0, L=9.0, style='modern')
s.box_trailer('Used, 28 ft', 16.5, 0.0, L=8.5, style='classic')
s.foot(0.0, -15.0, 26.0, 10.0)          # keep the foreground clear of shrubs
s.ground(R=40.0)
s.daylight(az=210, el=24, strength=4.4, sky=0.55)
cam = s.cam('lineup', (0.0, -33.0, z + 2.6), (0.0, 0.0, z + 1.4), lens=27)
s.shot(cam, 'RL_lineup', res=(2400, 820), samples=56)
