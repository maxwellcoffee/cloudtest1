"""Split a research-workflow result into the data files build.py reads.

usage: python3 import_run.py <workflow-output.json>

The workflow output is the JSON file the research run wrote (its "result" holds
stats, products, watchTech, watchApps, proposals, critique, final, curation).
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, '..', 'data')

raw = json.load(open(sys.argv[1]))
r = raw.get('result', raw)
if isinstance(r, str):
    r = json.loads(r)

os.makedirs(DATA, exist_ok=True)
products = sorted(r['products'], key=lambda p: (p['category'], p['name'].lower()))
for p in products:
    p.pop('exists', None)


def dump(name, obj):
    with open(os.path.join(DATA, name), 'w') as f:
        json.dump(obj, f, indent=1, ensure_ascii=False)
        f.write('\n')


dump('catalog.json', products)
dump('stats.json', r['stats'])
dump('curation.json', r.get('curation', {}))
dump('panel.json', {'proposals': r.get('proposals', []), 'critique': r.get('critique', [])})
if r.get('final'):
    dump('recommendation.json', r['final'])
else:
    print('warning: no final recommendation in this run')
with open(os.path.join(DATA, 'watch-technical.md'), 'w') as f:
    f.write(r['watchTech'].strip() + '\n')
with open(os.path.join(DATA, 'watch-apps.md'), 'w') as f:
    f.write(r['watchApps'].strip() + '\n')
print(len(products), 'products written to', os.path.normpath(DATA))
