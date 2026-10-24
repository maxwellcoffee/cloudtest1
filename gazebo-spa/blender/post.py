"""Post-process the spa renders: annotate the plans (numbered markers, north arrow, scale, key),
save the beauty renders as JPEG, and make high-key black-and-white versions of the hero shots.

usage: python3 post.py <raw_dir> <out_dir>
"""
import glob, os, sys
from PIL import Image, ImageEnhance, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'yucca-valley-plan', 'blender'))
import annotate  # noqa: E402

raw, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for js in sorted(glob.glob(os.path.join(raw, '*_plan.json'))):
    annotate.annotate(raw, out, os.path.basename(js)[:-5])
for png in sorted(glob.glob(os.path.join(raw, '*.png'))):
    name = os.path.basename(png)[:-4]
    if name.endswith('_plan'):
        continue
    im = Image.open(png).convert('RGB')
    im.save(os.path.join(out, name + '.jpg'), quality=86, optimize=True, progressive=True)
    if name.endswith('_hero'):
        g = ImageOps.grayscale(im)
        g = g.point(lambda v: int(255 * (v / 255) ** 0.72))          # lift the shadows: high-key
        g = ImageEnhance.Contrast(g).enhance(1.18)
        g.convert('RGB').save(os.path.join(out, name + '_bw.jpg'), quality=86, optimize=True, progressive=True)
    print('saved', name)
