"""Add numbered, phase-coloured markers (and a north arrow, scale bar and key on plans) to renders.

usage: python3 annotate.py <render_dir> <out_dir> [name ...]
Each <name>.png needs the <name>.json written by sitekit.Site.render().
Writes <out_dir>/<name>.jpg plus <out_dir>/<name>.legend.json (number -> label, phase).
"""
import json, math, os, sys
from PIL import Image, ImageDraw, ImageFont

FONT = '/usr/share/fonts/opentype/inter/'
PHASE = {1: (194, 65, 12), 2: (29, 78, 216), 3: (21, 128, 61), 0: (60, 60, 60)}
FT = 0.3048


def font(weight, size):
    return ImageFont.truetype(FONT + f'Inter-{weight}.otf', size)


def place(markers, W, H, r):
    """Nudge markers apart so circles never overlap; keep them inside the frame."""
    for _ in range(200):
        moved = False
        for i, a in enumerate(markers):
            for b in markers[i + 1:]:
                dx, dy = b['mx'] - a['mx'], b['my'] - a['my']
                d = math.hypot(dx, dy) or 0.01
                if d < 2.35 * r:
                    push = (2.35 * r - d) / 2 + 0.5
                    ux, uy = dx / d, dy / d
                    a['mx'] -= ux * push; a['my'] -= uy * push
                    b['mx'] += ux * push; b['my'] += uy * push
                    moved = True
        for m in markers:
            m['mx'] = min(max(m['mx'], r + 4), W - r - 4)
            m['my'] = min(max(m['my'], r + 4), H - r - 4)
        if not moved:
            break


def annotate(src_dir, out_dir, name, phases=None):
    meta = json.load(open(os.path.join(src_dir, name + '.json')))
    im = Image.open(os.path.join(src_dir, meta['image'])).convert('RGB')
    W, H = im.size
    s = W / 2000.0
    r = int(17 * s) + 1
    plan = 'px_per_m' in meta
    d = ImageDraw.Draw(im, 'RGBA')
    anchors = [a for a in meta['anchors'] if phases is None or a['phase'] in phases]
    markers = []
    for a in anchors:
        off = (24 * s, -24 * s) if plan else (0, -10 * s)
        markers.append(dict(a, mx=a['x'] + off[0], my=a['y'] + off[1]))
    place(markers, W, H, r)
    f_num = font('Bold', int(17 * s) + 2)
    for m in markers:
        col = PHASE.get(m['phase'], PHASE[0])
        d.line([(m['x'], m['y']), (m['mx'], m['my'])], fill=(255, 255, 255, 230), width=max(2, int(2.5 * s)))
        d.ellipse([m['x'] - 3 * s, m['y'] - 3 * s, m['x'] + 3 * s, m['y'] + 3 * s], fill=(255, 255, 255, 255))
        d.ellipse([m['mx'] - r - 2, m['my'] - r + 2, m['mx'] + r + 2, m['my'] + r + 6], fill=(0, 0, 0, 70))
        d.ellipse([m['mx'] - r, m['my'] - r, m['mx'] + r, m['my'] + r], fill=col + (255,), outline=(255, 255, 255, 255), width=max(2, int(3 * s)))
        d.text((m['mx'], m['my'] + 0.5), str(m['n']), font=f_num, fill=(255, 255, 255, 255), anchor='mm')
    if plan:
        ppm = meta['px_per_m']
        # north arrow
        cx, cy = W - 70 * s, 70 * s
        d.ellipse([cx - 38 * s, cy - 38 * s, cx + 38 * s, cy + 38 * s], fill=(255, 255, 255, 215))
        d.polygon([(cx, cy - 28 * s), (cx + 13 * s, cy + 16 * s), (cx, cy + 8 * s), (cx - 13 * s, cy + 16 * s)], fill=(30, 30, 30, 255))
        d.text((cx, cy + 27 * s), 'N', font=font('Bold', int(15 * s)), fill=(30, 30, 30, 255), anchor='mm')
        site = ppm < 40
        segs = [0, 50, 100, 200] if site else [0, 5, 10, 20]
        x0, y0 = 40 * s, H - 46 * s
        L = segs[-1] * FT * ppm
        d.rounded_rectangle([x0 - 14 * s, y0 - 34 * s, x0 + max(L + 40 * s, 330 * s), y0 + 28 * s], radius=8 * s, fill=(255, 255, 255, 215))
        for i in range(len(segs) - 1):
            a = x0 + segs[i] * FT * ppm
            b = x0 + segs[i + 1] * FT * ppm
            d.rectangle([a, y0, b, y0 + 9 * s], fill=(30, 30, 30, 255) if i % 2 == 0 else (255, 255, 255, 255), outline=(30, 30, 30, 255), width=max(1, int(2 * s)))
        fl = font('Medium', int(14 * s))
        for v in segs:
            d.text((x0 + v * FT * ppm, y0 - 6 * s), f'{v}' + (' ft' if v == segs[-1] else ''), font=fl, fill=(30, 30, 30, 255), anchor='md')
        note = '660 ft x 330 ft = 5.0 acres   contours every 2 ft' if site else '32 ft x 20 ft outside = 640 sq ft'
        d.text((x0, y0 + 22 * s), note, font=font('Regular', int(12 * s)), fill=(50, 50, 50, 255), anchor='ls')
        if not site:
            items = []
        # key
        items = items if not site else [('line', (255, 255, 255), 'Property line'), ('dash', (232, 120, 42), 'Setbacks: 25 ft front, 15 ft sides + rear'),
                 ('ring', (47, 163, 107), 'Joshua tree 50-ft buffer: no work inside'), ('dashring', (210, 60, 60), '100 ft defensible space'),
                 ('dashring', (47, 127, 216), 'Well: no septic within 100 ft')]
        fk = font('Medium', int(13 * s))
        bw, bh = 318 * s, (len(items) * 24 + 16) * s
        if not items:
            bw = bh = 0
        bx, by = W - bw - 24 * s, H - bh - 18 * s
        if items:
            d.rounded_rectangle([bx, by, bx + bw, by + bh], radius=8 * s, fill=(255, 255, 255, 220))
        for i, (kind, col, txt) in enumerate(items):
            yy = by + (14 + i * 24) * s + 6 * s
            xx = bx + 14 * s
            if kind == 'line':
                d.line([(xx, yy), (xx + 30 * s, yy)], fill=(120, 120, 120, 255), width=int(6 * s))
                d.line([(xx, yy), (xx + 30 * s, yy)], fill=col + (255,), width=int(3 * s))
            elif kind == 'dash':
                for k in range(3):
                    d.line([(xx + k * 11 * s, yy), (xx + k * 11 * s + 7 * s, yy)], fill=col + (255,), width=int(3 * s))
            elif kind == 'ring':
                d.ellipse([xx + 8 * s, yy - 8 * s, xx + 24 * s, yy + 8 * s], outline=col + (255,), width=int(3 * s))
            else:
                d.arc([xx + 6 * s, yy - 10 * s, xx + 26 * s, yy + 10 * s], 0, 70, fill=col + (255,), width=int(3 * s))
                d.arc([xx + 6 * s, yy - 10 * s, xx + 26 * s, yy + 10 * s], 120, 190, fill=col + (255,), width=int(3 * s))
                d.arc([xx + 6 * s, yy - 10 * s, xx + 26 * s, yy + 10 * s], 240, 310, fill=col + (255,), width=int(3 * s))
            d.text((xx + 42 * s, yy), txt, font=fk, fill=(35, 35, 35, 255), anchor='lm')
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, name + '.jpg')
    im.save(out, quality=86, optimize=True, progressive=True)
    legend = sorted({(m['n'], m['label'], m['phase']) for m in markers})
    json.dump([{'n': n, 'label': l, 'phase': p} for n, l, p in legend], open(os.path.join(out_dir, name + '.legend.json'), 'w'), indent=1)
    print('annotated', out, len(markers), 'markers')


if __name__ == '__main__':
    src, out = sys.argv[1], sys.argv[2]
    names = sys.argv[3:] or sorted(f[:-5] for f in os.listdir(src) if f.endswith('.json') and not f.endswith('_stats.json') and f != 'mask_axes.json')
    for n in names:
        annotate(src, out, n)
