"""Assemble the plan page: template.html + verified research digests + annotated renders -> index.html.

usage: python3 build.py <research_dir> <digest_dir> <renders_dir>
"""
import hashlib, html, json, os, re, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
RES, DIG, RND = sys.argv[1], sys.argv[2], sys.argv[3]
EDIT = sys.argv[4] if len(sys.argv) > 4 else None
E = html.escape


def load(d, name):
    p = os.path.join(d, name + '.json')
    return json.load(open(p)) if os.path.exists(p) else None


TOPICS = [
    ('diligence_team', 'The land itself', 'What to check before you make an offer, and how to run a site visit.'),
    ('zoning_legal', 'Zoning, permits and living on site', 'Town or County, the permit clock, the temporary-occupancy route and how many pods are allowed.'),
    ('utilities', 'Water, sewer, power and access', 'Usually the biggest cost and the biggest deal-breaker on raw desert land.'),
    ('grading_jt', 'The slope, drainage and Joshua trees', 'Flattening pads, flash-flood paths, dust rules and the protected trees.'),
    ('interim_storage_security', 'The interim pod, storage and leaving it alone', 'What a $20k capsule really is, the legal alternatives, and protecting things while you travel.'),
    ('house_design', 'The small house', 'Minimum size, desert-smart design, radiant heat and a floor you can lie on.'),
    ('plants', 'Plants, water and food', 'What thrives at 3,300 ft, water harvesting, and keeping young trees alive while you are away.'),
    ('finance_timeline', 'Money, insurance and the timeline', 'Land prices, three budget tiers, financing, insurance and a realistic schedule.'),
    ('bhutan', 'Bhutan', 'Visas, the daily fee, what a sponsor really is, and when to go.'),
]

TRIGGERS = ['Land + boundaries', 'Us: roles, energy, time alone', 'Town or County rules', 'Water', 'Sewer / septic', 'Power + solar', 'Road + fire access',
            'Grading + drainage', 'Joshua trees + wildlife', 'Interim pod', 'Storage + security', 'The house', 'Soft heated floor',
            'More pods later', 'Plants + orchard', 'Money + insurance', 'Timeline + seasons', 'Bhutan', 'People to call']


def digest(t):
    """Edited digest (reconciled with the key-rule sheet) when available, else the verified digest."""
    if EDIT:
        e = load(EDIT, t)
        if e:
            return e
    d = load(DIG, t)
    return d['digest'] if d else None


def checked_sources(t):
    d = load(DIG, t) or {}
    return [s for c in d.get('claim_checks', []) if c.get('verdict') in ('confirmed', 'corrected') for s in c.get('sources', [])]


def research(t):
    return load(RES, t)


def ul(items, cls=''):
    items = [i for i in items if i]
    return f'<ul class="{cls}">' + ''.join(f'<li>{i}</li>' for i in items) + '</ul>' if items else ''


def linkify(u):
    short = re.sub(r'^https?://(www\.)?', '', u)
    short = short if len(short) < 70 else short[:67] + '…'
    return f'<a href="{E(u, quote=True)}" target="_blank" rel="noopener">{E(short)}</a>'


def cid(text):
    return 'c' + hashlib.sha1(text.encode()).hexdigest()[:12]


# ------------------------------------------------------------------ considerations
EXTRA_CONS_TOP = ''


def considerations():
    cards = []
    for key, title, sub in TOPICS:
        g = digest(key)
        r = research(key)
        if not g and not r:
            continue
        if g:
            head = g['headline']
            points = [E(p) for p in g['key_points']]
            risks = [f'<span class="sev {E(x["severity"])}">{E(x["severity"])}</span>{E(x["risk"])} <em>→ {E(x["mitigation"])}</em>' for x in g.get('risks', [])]
            qs = [E(q) for q in g.get('questions_for_couple', [])]
            src = g.get('key_sources', [])
        else:
            head = r['executive_summary'].split('. ')[0] + '.'
            points = [f'<b>{E(f["title"])}.</b> {E(f["implication"])}' for f in r['findings']]
            risks = [f'<span class="sev {E(x["severity"])}">{E(x["severity"])}</span>{E(x["risk"])} <em>→ {E(x["mitigation"])}</em>' for x in r.get('risks', [])][:6]
            qs = [E(q) for q in r.get('brainstorm_prompts', [])][:8]
            src = sorted({s for f in r['findings'] for s in f['sources']})[:8]
        cards.append(f'''
<details class="topic" id="topic-{key}">
  <summary><h3>{E(title)}</h3><p><b>{E(head)}</b></p></summary>
  <div class="topic-body">
    <p style="color:var(--ink-2)">{E(sub)}</p>
    <div><h4>What we found</h4>{ul(points)}</div>
    {f'<div><h4>Risks and how to handle them</h4>{ul(risks)}</div>' if risks else ''}
    {f'<div><h4>Talk about together</h4>{ul(qs)}</div>' if qs else ''}
    {f'<div><h4>Best sources</h4>{ul([linkify(s) for s in src])}</div>' if src else ''}
  </div>
</details>''')
    return f'''
<section class="sheet" id="considerations" aria-labelledby="cons-h">
  <header>
    <div class="sheet-code"><span>C-1</span><span>Researched {len(cards)} topics · claims checked a second time</span></div>
    <h2 id="cons-h">Everything to think about</h2>
    <p class="lede">The reference for your brainstorm, best read after you have each written your own thoughts. Each topic was researched from County code and handouts, state agencies, utilities and Bhutan's tourism department (Town of Yucca Valley code was read on a third-party copy because the Town's site blocked access), then a second reviewer tried to disprove the key claims. Where something is still uncertain, it says who to ask. Rules change: confirm the ones you rely on in writing.</p>
  </header>
  <div class="col">{EXTRA_CONS_TOP}</div>
  <div class="col topics">{''.join(cards)}</div>
</section>'''


# ------------------------------------------------------------------ team
STAGES = [('Phase 0', 'Before the offer'), ('Phase 1', 'During escrow'), ('Phase 2', 'Design'), ('Phase 3', 'Permits + building'), ('Phase 4', 'Before you travel')]


def stage_of(when):
    for code, label in STAGES:
        if when.startswith(code):
            return code, label
    return 'Phase 2', 'Design'


def team():
    r = research('diligence_team') or {}
    people = r.get('people_to_involve', [])
    rows = []
    order = {c: i for i, (c, _) in enumerate(STAGES)}
    people = sorted(people, key=lambda p: order[stage_of(p.get('when', ''))[0]])
    last = None
    for p in people:
        code, label = stage_of(p.get('when', ''))
        if code != last:
            rows.append(f'<tr><td colspan="4" style="background:var(--panel)"><span class="stage">{E(label)}</span></td></tr>')
            last = code
        qs = p.get('questions_to_ask', [])[:3]
        rows.append(f'''<tr><td><b>{E(p["role"])}</b><br><span style="color:var(--ink-2);font-size:.85rem">{E(p.get("when", ""))}</span></td>
<td>{E(p["why"])}</td><td class="money" style="white-space:normal;min-width:150px">{E(p.get("typical_cost", ""))}</td>
<td>{ul([E(q) for q in qs])}</td></tr>''')
    visit = r.get('site_visit_checks', [])
    checks = ''.join(f'<li><label><input type="checkbox" data-check="{cid(v)}"><span>{E(v)}</span></label></li>' for v in visit)
    return f'''
<section class="sheet" id="team" aria-labelledby="team-h">
  <header>
    <div class="sheet-code"><span>T-1</span><span>{len(people)} roles · in the order you'll need them</span></div>
    <h2 id="team-h">People to bring to the land</h2>
    <p class="lede">Most of the deal-breakers can be checked for free by the two of you and a phone. Then pay for studies during escrow, in the order that lets each one inform the next: survey and tree census first, so the perc test and pads go in the right place.</p>
  </header>
  <div class="tablewrap"><table>
    <thead><tr><th>Who</th><th>Why</th><th>Typical cost (estimates)</th><th>Ask them</th></tr></thead>
    <tbody>{''.join(rows)}</tbody>
  </table></div>
  <div class="col">
    <h3>Site-visit kit and checklist</h3>
    <p>Visit three times if you can: a weekday (military booms from Twentynine Palms, traffic), a Saturday afternoon (off-road vehicles, shooting, generators) and after dark. Go once on a windy spring afternoon. Until you own it, get the seller's written permission (through your agent) before flagging, staking or digging. Ticks save to your shared worksheet.</p>
    <ul class="checklist">{checks}</ul>
  </div>
</section>'''


# ------------------------------------------------------------------ schemes
SCHEMES = [
    ('A', 'Road-Front Cluster', 'Everything within about 300 ft of the gate. The front of the lot is the flattest and closest to the road, where power and water usually run, so this is the cheapest and fastest scheme. The back 3.5 acres stay wild, with a trail to a sunset lookout on the granite knoll.',
     ['Shortest driveway and utility trenches', 'Least grading of the four (the front of the lot is nearly flat), though it still passes the 100 cubic-yard permit threshold', 'Easy deliveries; easy to watch over and lock up before a trip', 'Whole back of the lot stays untouched'],
     ['Closest to road dust and passing traffic', 'Views are lower and less dramatic', 'Container sits uphill behind the house, off the driveway']),
    ('B', 'Hilltop Terraces', 'The house takes the high ground for the long views south. Pods and orchard terraces step down the slope; water tanks on the highest point give gravity pressure.',
     ['Best views and the most privacy', 'House sits above any sheet flow', 'Tanks on the high point need little pumping', 'Contour terraces catch rain for the orchard'],
     ['Longest, steepest driveway: gravel only up to 8% grade, turnaround required', 'Most earthwork: expect a grading permit and an engineered plan', 'Longest power and water trenches from the road', 'Most exposed to spring wind']),
    ('C', 'Courtyard Compound', 'House, pods and the storage container wrap one wind-sheltered courtyard on a mid-slope bench, with a ramada, garden beds and the soaking tub in the middle. A windbreak arcs around the west and north-west.',
     ['A sheltered outdoor room out of the spring wind', 'Compact: one bench, short utility runs', 'Everything inside one defensible-space zone', 'Best for hosting and for daily life outdoors'],
     ['One big pad: likely over the 100 cubic-yard permit threshold', 'Guests live close; less privacy if you rent a pod later', 'Buildings need 10 ft between walls and ember-resistant construction']),
    ('D', 'Scattered Retreat', 'A service hub (solar, tanks, well, parking) at the gate keeps trucks out of the living areas. The house sits on the west rise; pods spread out, each on a small pad with its own view.',
     ['Real privacy for each pod: best for guests or a future rental', 'Small pads: little grading at each spot', 'Uses the whole 5 acres'],
     ['Longest lanes and trenches overall', 'Fire access must reach within 150 ft of every building', 'More ground to keep cleared for fire, harder to secure while away']),
]


def legend_items(sid):
    items = {}
    for name in (f'{sid}_plan', f'{sid}_plan_p1', f'{sid}_plan_p2', f'{sid}_aerial'):
        p = os.path.join(RND, name + '.legend.json')
        if os.path.exists(p):
            for it in json.load(open(p)):
                items[it['n']] = it
    return [items[k] for k in sorted(items)]


def shown(name):
    p = os.path.join(RND, name + '.legend.json')
    return ','.join(str(i['n']) for i in json.load(open(p))) if os.path.exists(p) else ''


def stats(sid):
    p = os.path.join(RND, sid + '_stats.json')
    return json.load(open(p)) if os.path.exists(p) else None


def schemes():
    blocks, rows = [], []
    for sid, name, blurb, pros, cons in SCHEMES:
        leg = legend_items(sid)
        lis = ''.join(f'<li data-n="{i["n"]}"><span class="dot ph{i["phase"]}">{i["n"]}</span><span>{E(i["label"])}</span></li>' for i in leg)
        tabs = [('Phase 1: move in', f'{sid}_plan_p1'), ('Phase 2: the house', f'{sid}_plan_p2'), ('Phase 3: grown in', f'{sid}_plan'), ('From the air', f'{sid}_aerial')]
        btns = ''.join(f'<button type="button" role="tab" aria-selected="{"true" if n == f"{sid}_plan" else "false"}" data-src="img/{n}.jpg" data-alt="Scheme {sid} {E(lbl)}" data-show="{shown(n)}">{E(lbl)}</button>' for lbl, n in tabs)
        st = stats(sid)
        stat_html = ''
        if st:
            full = st['99']
            stat_html = f'<p class="mono" style="font-size:.85rem;color:var(--ink-2)">Modeled: {st["drive_ft"]} ft of driveway and lanes · about {full["cut_cy"] + full["fill_cy"]:,} cubic yards of cut + fill (permit threshold: 100) · {full["disturbed_acres"]} acres disturbed</p>'
            rows.append(f'<tr><td><b>{sid}. {E(name)}</b></td><td class="money">{st["drive_ft"]} ft</td><td class="money">{st["1"]["cut_cy"] + st["1"]["fill_cy"]:,} cy</td><td class="money">{full["cut_cy"] + full["fill_cy"]:,} cy</td><td class="money">{full["disturbed_acres"]} ac</td></tr>')
        badge = '<span class="badge">Start here</span>' if sid == 'A' else ('<span class="badge">Best to live in</span>' if sid == 'C' else '')
        blocks.append(f'''
<div class="scheme" id="scheme-{sid}">
  <h3><span class="code">S-{sid}</span>{E(name)} {badge}</h3>
  <p>{E(blurb)}</p>
  <figure class="plate">
    <div class="tabs" role="tablist" data-tabs="img-{sid}">{btns}</div>
    <img id="img-{sid}" src="img/{sid}_plan.jpg" alt="Scheme {sid} site plan, fully grown in" loading="lazy" width="2000" height="1000">
    <ul class="legend" id="img-{sid}-legend">{lis}</ul>
  </figure>
  {stat_html}
  <div class="proscons"><div><h4>Why choose it</h4>{ul([E(x) for x in pros])}</div><div><h4>Watch out for</h4>{ul([E(x) for x in cons])}</div></div>
</div>''')
    for sid, *_ in SCHEMES:
        pass
    table = f'''<div class="tablewrap"><table><thead><tr><th>Scheme</th><th>Driveway + lanes</th><th>Earthwork, phase 1</th><th>Earthwork, all phases</th><th>Ground disturbed</th></tr></thead><tbody>{''.join(rows)}</tbody></table></div>''' if rows else ''
    return f'''
<section class="sheet" id="schemes" aria-labelledby="schemes-h">
  <header>
    <div class="sheet-code"><span>S-1</span><span>4 schemes · one 660 × 330 ft lot · rendered in Blender</span></div>
    <h2 id="schemes-h">Site schemes for 5 acres</h2>
    <p class="lede">Four ways to arrange the same land: a 5-acre lot with a dirt road along the south edge, about 30 ft of rise to the north, a sandy wash across the east third, a granite knoll, and Joshua trees clustered along the wash and the knoll. Every layout respects the setbacks, the 100-ft well-to-septic separation and the County's 50-ft Joshua tree buffer. Use the tabs to watch each one grow in three phases.</p>
  </header>
  <div class="col">
    <div class="phasekey"><span><i class="ph1"></i>Phase 1: move in (temporary permit)</span><span><i class="ph2"></i>Phase 2: the permitted house</span><span><i class="ph3"></i>Phase 3: grow (pods, orchard, trails)</span></div>
    <div class="callout"><h4>The 50-ft Joshua tree rule shapes every plan</h4><p>San Bernardino County requires state (CDFW) approval before any grading, building, septic, trenching, fencing, solar or driveway work within 50 ft of a western Joshua tree, and trees on a neighbor's land count. The green circles show those buffers. On this model lot they cover about 1.3 of the 5 acres, all on the east side, which is what a good lot looks like. On your real lot, map every tree (and any within 50 ft of your lines) on the first visit and draw the circles before you fall in love with a building spot.</p></div>
    <div class="callout"><h4>The pod story in every scheme</h4><p>Pod #1 is where you live while you build. To be legal it has to be a DMV-registered RV or travel trailer on a temporary-occupancy permit, which needs the house's building permit first. When the house is finaled, the trailer leaves and its pad, already graded and plumbed, becomes the site of a permitted ADU pod. On 5+ acres in the unincorporated County that leaves room for an ADU, a guest house (no kitchen) and a studio you don't sleep in.</p></div>
    <p style="font-size:.9rem;color:var(--ink-2)">The land is a stand-in for your parcel: same size, typical slope and typical features. Swap in the real survey, tree census and perc location and the same moves apply.</p>
  </div>
  {''.join(blocks)}
  {('<div class="col"><h3>Side by side</h3>' + table + '<p style="font-size:.88rem;color:var(--ink-2)">Earthwork is measured from the 3D grading model (pads flattened to their center height, 2:1 side slopes). Every scheme passes the 100 cubic-yard County threshold by the time the house pad is cut, so plan on a grading permit whichever you choose. Real numbers come from your surveyor and civil engineer, but the ranking holds: the closer to the road and the flatter the ground, the less you move.</p></div>') if table else ''}
</section>'''


def copy_images():
    dst = os.path.join(HERE, 'img')
    os.makedirs(dst, exist_ok=True)
    for f in os.listdir(RND):
        if f.endswith(('.jpg', '.webp')):
            shutil.copy(os.path.join(RND, f), os.path.join(dst, f))


def build(sections):
    t = open(os.path.join(HERE, 'template.html')).read()
    chips = ''.join(f'<span class="chip">{E(x)}</span>' for x in TRIGGERS)
    t = t.replace('{{TRIGGER_CHIPS}}', chips)
    for k, v in sections.items():
        t = t.replace('{{' + k + '}}', v)
    left = re.findall(r'\{\{[A-Z_]+\}\}', t)
    for k in left:
        t = t.replace(k, '')
    open(os.path.join(HERE, 'index.html'), 'w').write(t)
    print('built', len(t) // 1024, 'KB; unfilled:', left)


if __name__ == '__main__':
    import extra   # hand-written sections (overview, house, bhutan, money, next, sources)
    copy_images()
    sec = {
        'CONSIDERATIONS': considerations(),
        'TEAM': team(),
        'SCHEMES': schemes(),
    }
    globals()['EXTRA_CONS_TOP'] = extra.cons_top(sys.modules[__name__])
    sec['CONSIDERATIONS'] = considerations()
    sec.update(extra.sections(sys.modules[__name__]))
    build(sec)
