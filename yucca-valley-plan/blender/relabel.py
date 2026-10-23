"""Apply late label wording fixes to rendered anchor JSON (labels only; images are unchanged)."""
import glob, json, os, sys

FIX = {
    'Sunset lookout on the granite knoll': 'Sunset lookout: a bench on the rocks, no clearing',
    'Lookout across the wash': 'Lookout across the wash: a bench, no clearing',
    'Pod #1: interim home (RV-certified, temporary permit while the house is built)': 'Pod #1: interim home, a DMV-registered trailer on a temporary permit while the house is built',
    'Radiant heat: PEX loops ~9 in apart fed by an air-to-water heat pump (or thin electric mats, the simpler DIY option)': 'Radiant heat: PEX loops about 9 in apart, fed by an air-to-water heat pump',
    'Soft top: floor-heating tatami (15-30 mm) or wool felt; keep the covering at or under about R-1.5': 'Soft top: floor-heating tatami (15-30 mm) or wool felt; keep everything above the heat at about R-1.4 or less',
    'Ductless mini-split: the code-required main heat + cooling': 'Ductless mini-split for summer cooling (the slab does the heating)',
    'Sliding glass wall to the south, 7 ft roof overhang shades summer sun': 'Sliding glass wall to the south under a deep terrace roof that shades the summer sun',
    'Closet + heat-pump buffer tank + radiant manifold': 'Mechanical closet: fire-sprinkler riser, heat-pump water heater, radiant manifold',
}
d = sys.argv[1]
n = 0
for f in glob.glob(os.path.join(d, '*.json')):
    m = json.load(open(f))
    if not isinstance(m, dict) or 'anchors' not in m:
        continue
    for a in m['anchors']:
        if a['label'] in FIX:
            a['label'] = FIX[a['label']]
            n += 1
    json.dump(m, open(f, 'w'), indent=1)
print('relabelled', n)
