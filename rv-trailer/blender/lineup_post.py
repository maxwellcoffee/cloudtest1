"""Turn the orthographic trailer lineup into a labelled elevation: overall-length dimension lines,
a caption under each trailer, a scale bar and a note on the figure.

usage: python3 lineup_post.py <raw_dir> <out_dir>
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

FONT = '/usr/share/fonts/opentype/inter/'
FT = 0.3048
INK, MUTED, PAPER, RULE = (45, 42, 40), (110, 104, 98), (248, 245, 240), (200, 192, 182)


def font(w, size):
    return ImageFont.truetype(FONT + f'Inter-{w}.otf', size)


def ft_in(m):
    inches = round(m / FT * 12)
    return f"{inches // 12} ft {inches % 12} in" if inches % 12 else f"{inches // 12} ft"


raw, out = sys.argv[1], sys.argv[2]
meta = json.load(open(os.path.join(raw, 'RL_lineup.meta.json')))
rgba = Image.open(os.path.join(raw, meta['image'])).convert('RGBA')
im = Image.new('RGBA', rgba.size, PAPER + (255,))
im.alpha_composite(rgba)
im = im.convert('RGB')
W, H = im.size
s = W / 2400.0
band = int(185 * s)
canvas = Image.new('RGB', (W, H + band), PAPER)
canvas.paste(im, (0, 0))
d = ImageDraw.Draw(canvas)
f_t, f_s, f_d = font('SemiBold', int(25 * s)), font('Regular', int(19 * s)), font('Medium', int(19 * s))
ppm = meta['px_per_m']
for it in meta['items']:
    a, b = it['px0'], it['px1']
    y = H + int(22 * s)
    d.line([(a, y), (b, y)], fill=INK, width=max(1, int(2 * s)))
    for xx in (a, b):
        d.line([(xx, y - 9 * s), (xx, y + 9 * s)], fill=INK, width=max(1, int(2 * s)))
    lab = ft_in(it['x1'] - it['x0']) + ' overall'
    tw = d.textlength(lab, font=f_d)
    d.rectangle([(a + b) / 2 - tw / 2 - 8 * s, y - 12 * s, (a + b) / 2 + tw / 2 + 8 * s, y + 12 * s], fill=PAPER)
    d.text(((a + b) / 2, y), lab, font=f_d, fill=INK, anchor='mm')
    d.text(((a + b) / 2, H + int(66 * s)), it['title'], font=f_t, fill=INK, anchor='mm')
    d.text(((a + b) / 2, H + int(100 * s)), it['sub'], font=f_s, fill=MUTED, anchor='mm')
# scale bar: 0-10 ft, bottom left
x0, yb = int(24 * s), H + band - int(18 * s)
step = 5 * FT * ppm
for k in range(2):
    d.rectangle([x0 + k * step, yb - 6 * s, x0 + (k + 1) * step, yb], fill=INK if k == 0 else PAPER, outline=INK)
d.text((x0 + 2 * step + 10 * s, yb - 3 * s), '10 ft', font=f_s, fill=INK, anchor='lm')
d.text((W - int(24 * s), yb - 3 * s), 'Same scale, side view. The figure is 5 ft 9 in tall.', font=f_s, fill=MUTED, anchor='rm')
d.line([(0, H), (W, H)], fill=RULE, width=1)
os.makedirs(out, exist_ok=True)
canvas.save(os.path.join(out, 'RL_lineup.jpg'), quality=88, optimize=True, progressive=True)
print('saved RL_lineup', canvas.size)
