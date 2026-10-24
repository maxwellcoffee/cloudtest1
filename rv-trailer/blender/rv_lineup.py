"""What it could look like: four kinds of trailer side by side, drawn as a true-scale elevation (orthographic
camera), hitches east, doors facing you. Left to right: molded fiberglass (Oliver class), aluminium Airstream,
new four-season trailer, older used trailer. A 5 ft 9 in figure stands by for scale. lineup_post.py adds the
captions, overall lengths and a scale bar from RL_lineup.json."""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rvkit as RK
from mathutils import Vector

out, preview = RK.SK.args()
s = RK.Camp('RL', out, preview)
s.pad_gravel(48.0, 8.0, y=0.0)
z = s.pad_z
GAP, T = 3.0, 1.15                       # gap between trailers; A-frame tongue length
TRAILERS = [  # (title, subtitle, body length, builder)
    ('Molded fiberglass, Oliver class', 'Small, tough, four-season shell; one-piece hulls', 6.05,
     lambda t, x: s.shell_trailer(t, x, 0.0, L=6.05, W=2.13, kind='oliver')),
    ('Aluminum Airstream', 'Riveted aluminum; holds value; premium price', 6.83,
     lambda t, x: s.shell_trailer(t, x, 0.0, L=6.83, W=2.59, kind='airstream')),
    ('New four-season trailer', 'Laminated fiberglass; slide-out; dual-pane option', 7.9,
     lambda t, x: s.box_trailer(t, x, 0.0, L=7.9, style='modern')),
    ('Used trailer, about 2017-2019', 'Laminated fiberglass; check roof, floor and seals', 7.4,
     lambda t, x: s.box_trailer(t, x, 0.0, L=7.4, style='classic')),
]
total = sum(L + T for (_, _, L, _) in TRAILERS) + GAP * (len(TRAILERS) - 1)
x0 = -total / 2
spans = []
for (title, sub, L, build) in TRAILERS:
    cx = x0 + L / 2                       # body centre; the tongue runs east of the body
    build(title, cx)
    spans.append({'title': title, 'sub': sub, 'x0': x0, 'x1': x0 + L + T, 'body': L})
    x0 += L + T + GAP
s.person(spans[1]['x0'] + 1.6, -1.9)
s.daylight(az=185, el=34, strength=4.4, sky=0.55)
s.scene.render.film_transparent = True     # no hillside behind: lineup_post.py lays it on paper

# orthographic camera tilted 10 degrees down: true horizontal scale, and the pad (with shadows) shows as a strip
TILT = math.radians(10)
u = Vector((0.0, math.sin(TILT), math.cos(TILT)))          # screen up
fwd = Vector((0.0, math.cos(TILT), -math.sin(TILT)))
v_lo = -4.0 * math.sin(TILT) - 0.3                            # front edge of the pad, plus a margin
v_hi = 3.95 * math.cos(TILT) + 0.45                           # roof A/Cs, plus a margin
W_M = total + 4.0
H_M = v_hi - v_lo
RES = (2400, int(round(2400 * H_M / W_M)))
centre = Vector((0.0, 0.0, z)) + u * ((v_lo + v_hi) / 2)
cam = s.camera('lineup', tuple(centre - fwd * 30.0), ortho=W_M, rot=(math.pi / 2 - TILT, 0.0, 0.0))
s.shot(cam, 'RL_lineup', res=RES, samples=56)
f = 0.4 if preview else 1.0
W, H = int(RES[0] * f), int(RES[1] * f)
ppm = W / W_M
meta = {'image': 'RL_lineup.png', 'width': W, 'height': H, 'px_per_m': ppm,
        'items': [dict(sp, px0=(sp['x0'] + W_M / 2) * ppm, px1=(sp['x1'] + W_M / 2) * ppm) for sp in spans]}
json.dump(meta, open(os.path.join(out, 'RL_lineup.meta.json'), 'w'), indent=1)
