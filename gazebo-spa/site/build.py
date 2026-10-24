"""Build the gazebo bathhouse page: copies the finished renders into site/img and writes site/index.html.

usage: python3 build.py ../renders
"""
import html, json, os, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REN = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'renders'))
IMG = os.path.join(HERE, 'img')
PALETTE = {1: '#d64034', 2: '#22201f', 3: '#3f703c', 0: '#787068'}
E = html.escape


def img(name, cap, cls=''):
    src = f'img/{name}.jpg'
    return (f'<figure class="{cls}"><button class="zoom" type="button" data-full="{src}" data-cap="{E(cap)}">'
            f'<img src="{src}" alt="{E(cap)}" loading="lazy" width="1600" height="900"></button><figcaption>{E(cap)}</figcaption></figure>')


def legend(name):
    p = os.path.join(REN, name + '.legend.json')
    if not os.path.exists(p):
        return ''
    items = json.load(open(p))
    lis = ''.join(f'<li><span class="n" style="background:{PALETTE.get(i["phase"], PALETTE[0])}">{i["n"]}</span><span>{E(i["label"])}</span></li>' for i in items)
    return f'<ol class="legend" aria-label="Plan key">{lis}</ol>'


def ul(items):
    return '<ul>' + ''.join(f'<li>{x}</li>' for x in items) + '</ul>'


SCHEMES = [
    dict(k='A', name='Spring Glass House', tag='Closest to The Spring',
         idea="A 24 x 18 ft timber-and-glass bath house, built the way The Spring built its enclosed pool: a solid knee wall, a band of glass, and an open band of slats under a low roof. Where The Spring has a frosted privacy stripe across the glass, this one has a strip of coral lattice at eye level. Sliding glass doors open south to the view and east to a small sauna courtyard.",
         inside=['One in-ground tiled hot tub, 9.5 x 7 ft, with a blue mosaic waterline like The Spring\'s', 'Seated wash station and scrub table against the west wall', 'Planter along the north glass: bird of paradise, ferns, snake plant', 'Potted fan palm, yucca, stump planter, boulders, hanging pothos, wood sling chairs'],
         outside=['Cedar cabin sauna, 7 x 7 ft, eight steps from the east door', 'Stock-tank cold plunge and a rinse shower between the two', 'Vine pergola with hanging cone planters over a heated rest platform', 'Mexican and Mediterranean fan palms in black pebble beds'],
         size='About 432 sq ft under roof. Terrace 51 x 37 ft.',
         good='Use in every season: the glass and knee wall stop the spring wind and hold heat on 20F nights, and steam leaves through the slats. In summer, open the doors wide, shade the west and south glass, and use it early or late.',
         watch='The most permits and the highest cost. If the pool house walls serve as the safety barrier, its doors must be single, outswinging and self-closing (sliding glass doors don\'t qualify), plus an alarm; otherwise fence the tub. The 9.5 x 7 ft tub needs a two-piece or automatic cover. The inspector may treat the room as indoor, which changes the wiring rules. Needs an exhaust fan for steam.',
         tier='Premium', shots=['A_hero', 'A_inner', 'A_dusk']),
    dict(k='B', name='Jeongja Bathhouse', tag='The full Korean bath',
         idea="A jeongja, the open garden pavilion of a traditional Korean wooden house (hanok), on a low stone base, 24 x 16 ft, in three 8-ft bays that follow the Korean bath in order: wash, soak, rest. Paper-backed lattice screens close the north and west sides for privacy and glow at night. The south side stays open to the view, and the black tile roof turns up at the corners.",
         inside=['Bay 1: two seated wash stations and a scrub table on a slate floor', 'Bay 2: an in-ground tiled tub, 6.5 x 6.5 ft, its rim flush with the floor', 'Bay 3: a heated rest platform (ondol, the Korean warm floor you lie on), 7 x 8 ft, with floor cushions and a sikhye and baked-egg station', 'Planter of bird of paradise and ferns, bamboo in pots, hanging plants'],
         outside=['Cedar cabin sauna, 7 x 7 ft, a few steps east', 'Cedar cold-plunge tub and a rinse shower', 'Bamboo in raised planters as a north windbreak, olive trees'],
         size='About 384 sq ft under roof. Stone base 28 x 20 ft, 1 ft high.',
         good='Doing the whole ritual in order: wash, soak, sauna, cold, rest. It is the most clearly Korean of the five.',
         watch='The curved roof is custom carpentry; a straight hip roof costs less. Use polycarbonate behind the paper so rain and splash don\'t ruin it.',
         tier='Balanced to premium', shots=['B_hero', 'B_inner', 'B_dusk']),
    dict(k='C', name='Octagon Garden Gazebo', tag='The classic garden gazebo',
         idea="A 21-ft octagonal gazebo with a cupola that lets the steam out. Coral lattice screens close the windward north and west faces; the east and south stay open to the view, with a low lattice rail. The round tub sits in the middle, with planters, palms and hanging plants around it.",
         inside=['In-ground round tub, 8 ft across: plaster over concrete, or a fiberglass shell such as San Juan\'s 8 ft Isle, with a blue mosaic waterline and stone coping', 'Planters on the screened side: bird of paradise, ferns, snake plant', 'Two potted fan palms, hanging pothos on the beams, star jasmine on the entry posts', 'Paper lanterns kept more than 5 ft from the water'],
         outside=['Cedar barrel sauna, 6 ft across, about 8 ft from the gazebo', 'Stock-tank cold plunge and a rinse shower', 'Seated wash and scrub corner behind the west screen', 'Heated rest platform and loungers under string lights'],
         size='About 340 sq ft under roof. Terrace 49 x 36 ft.',
         good='The romantic, open-air garden gazebo. You can buy many of the parts as a kit and build the rest yourselves.',
         watch='Open sides let in dust and cold wind; plan on roll-down screens or glass panels on the west for winter. An open gazebo is not a barrier, so fence the tub area or use a locking cover plus an alarm.',
         tier='Balanced', shots=['C_hero', 'C_inner', 'C_dusk']),
    dict(k='D', name='Walled Garden Courtyard', tag='The most plants and privacy',
         idea="Blush plaster walls, 7.5 ft high with tile caps, enclose a 40 x 40 ft garden room out of the wind, with a coral lattice gate and lattice windows. In the middle, a vine-covered pergola stands over one in-ground hot tub. Each corner holds one part of the bath. It is the only plan without a solid roof over the tub; add a shade sail or a solid pergola roof for sun and rain.", head='Inside the walls',
         inside=['In-ground round tub, 6.5 ft across, under a jasmine pergola', 'North-east: cedar cabin sauna, cold plunge and shower', 'North-west: a clay dome warm room, after the Korean hanjeungmak kiln sauna (optional)', 'South-west: roofed wash and scrub corner. South-east: covered heated rest platform', 'Bird of paradise, ferns and bamboo in beds (bring the bird of paradise under cover below about 32F); bougainvillea on the warmest wall; potted fan palms'],
         outside=['Tall fan palms over the wall line', 'Agaves and natives outside the walls'],
         size='1,600 sq ft inside the walls; about 100 sq ft of roofs plus the pergola.',
         good='A sheltered microclimate where tender plants survive, and complete privacy. Can be built in stages: walls and tub first, the corners later.',
         watch='The walls are the big cost; garden walls this tall need a building permit and wind engineering, and must sit outside the side and rear setbacks (walls inside them are capped at 6 ft). The walls can be the safety barrier, but the gate must then be a single self-closing leaf no wider than 4 ft that opens outward, not the double gate drawn. The clay dome is a custom build; skip it at first.',
         tier='Premium', shots=['D_bird', 'D_inner', 'D_dusk'],
         caps=['From above: the walled courtyard, sauna and rest room in the corners', 'Inside the courtyard, by the tub', 'Dusk, lanterns and screens lit']),
    dict(k='E', name='Starter Kit', tag='Start while you build',
         idea="The lean version. A 12 x 12 ft cedar gazebo kit over a plug-and-play hot tub that is set into the ground, so its rim sits at ground level, with two coral lattice screens on the wind side and plants in pots. A 6-ft barrel sauna, a stock-tank plunge and a post shower stand beside it.",
         inside=['Plug-and-play acrylic hot tub, about 7 x 7 ft, on 240 V, recessed into a lined pit with its rim at ground level', 'A hatch beside it to reach the pumps and heater', 'Two coral lattice screens on the north and west', 'Potted fan palm, bird of paradise and fern; a hanging plant'],
         outside=['Cedar barrel sauna, 6 ft (2 to 4 people)', 'Stock-tank cold plunge and a post shower', 'Two loungers and string lights'],
         size='144 sq ft under roof. Paver pad 32 x 24 ft.',
         good='The lowest-cost way to get an in-ground tub. The sauna and plunge can move into Scheme A, B, C or D later.',
         watch='Recess the tub only with the maker\'s written approval; makers that allow it ask for a drained pit and service access all around (Master Spas suggests about 3 ft), and a 7 x 7 tub in a 12 x 12 gazebo leaves only about 2.5 ft a side, so use removable deck panels or a 12 x 16 kit. Light kits publish little wind data, so anchor to engineered footings. Before the house is finished, it needs a Temporary Use Permit unless the County says the trailer permit counts as the main use.',
         tier='Lean', shots=['E_hero', 'E_inner', 'E_dusk']),
]


def scheme_html(s):
    k = s['k']
    shots = ''.join(img(n, cap, 'span2' if i == 0 else '') for i, (n, cap) in enumerate(
        zip(s['shots'], s.get('caps', ['Afternoon, from the approach', 'Inside, by the tub', 'Dusk, lanterns and screens lit']))))
    plan = (f'<div class="plan-row"><div class="lattice">{img(k + "_plan", "Plan with the roofs lifted off, north up")}</div>'
            f'<div class="stack"><p class="eyebrow">Plan key</p>{legend(k + "_plan")}'
            f'<p class="small muted">Marker colors: coral for water, black for heat, green for rest and garden, grey for structure.</p></div></div>')
    return f'''
<article class="scheme" id="scheme-{k.lower()}">
  <div class="scheme-head"><span class="scheme-letter" aria-hidden="true">{k}</span>
    <h3>{E(s["name"])}</h3><p><span class="pill">{E(s["tag"])}</span> <span class="small muted">Budget tier: {E(s["tier"])}</span></p></div>
  <p>{E(s["idea"])}</p>
  <div class="shots">{shots}</div>
  {plan}
  <div class="facts">
    <div><h4>{E(s.get("head", "Under the roof"))}</h4>{ul([E(x) for x in s["inside"]])}</div>
    <div><h4>Around it</h4>{ul([E(x) for x in s["outside"]])}</div>
    <div><h4>Size</h4><p>{E(s["size"])}</p><h4>Best for</h4><p>{E(s["good"])}</p><h4>Watch out for</h4><p>{E(s["watch"])}</p></div>
  </div>
</article>'''


def page(sections):
    css = open(os.path.join(HERE, 'style.css')).read()
    return f'''<title>Garden Bathhouse Plans</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Fondamento&family=Inknut+Antiqua:wght@600&family=Inter+Tight:wght@400;600;700&display=swap">
<style>{css}</style>
{sections}
<div class="lightbox" id="lightbox" hidden role="dialog" aria-modal="true" aria-label="Enlarged render">
  <button type="button" id="lb-close">Close</button>
  <div><img id="lb-img" alt=""><p id="lb-cap"></p></div>
</div>
<script>
(function () {{
  var lb = document.getElementById('lightbox'), im = document.getElementById('lb-img'), cap = document.getElementById('lb-cap');
  var last = null;
  function open(b) {{ last = b; im.src = b.dataset.full; im.alt = b.dataset.cap; cap.textContent = b.dataset.cap; lb.hidden = false; document.getElementById('lb-close').focus(); }}
  function close() {{ lb.hidden = true; im.removeAttribute('src'); if (last) last.focus(); }}
  document.addEventListener('click', function (e) {{
    var b = e.target.closest('.zoom'); if (b) {{ open(b); return; }}
    if (!lb.hidden && (e.target === lb || e.target.id === 'lb-close')) close();
  }});
  document.addEventListener('keydown', function (e) {{ if (e.key === 'Escape' && !lb.hidden) close(); }});
  // remember ticked next actions in this browser only
  document.querySelectorAll('.actions input').forEach(function (cb) {{
    try {{ cb.checked = localStorage.getItem('spa-' + cb.id) === '1'; }} catch (err) {{}}
    cb.addEventListener('change', function () {{ try {{ localStorage.setItem('spa-' + cb.id, cb.checked ? '1' : '0'); }} catch (err) {{}} }});
  }});
}})();
</script>'''


WAVE = '<svg class="wave" viewBox="0 0 120 14" aria-hidden="true"><path d="M0 7 Q10 0 20 7 T40 7 T60 7 T80 7 T100 7 T120 7" fill="none" stroke="currentColor" stroke-width="2"/></svg>'


def main():
    os.makedirs(IMG, exist_ok=True)
    for f in os.listdir(REN):
        if f.endswith('.jpg'):
            shutil.copy(os.path.join(REN, f), os.path.join(IMG, f))
    from content import intro, spring, ritual, parts, seasons, compare, inground, plants, rules, budget, products, actions, sources
    toc = ('<nav class="toc wrap" aria-label="Sections"><ul>'
           '<li><a href="#spring">The Spring</a></li><li><a href="#ritual">The bathing round</a></li><li><a href="#parts">The pieces</a></li>'
           '<li><a href="#schemes">Five plans</a></li><li><a href="#compare">Compare</a></li><li><a href="#inground">The tub</a></li><li><a href="#plants">Plants</a></li>'
           '<li><a href="#rules">Rules</a></li><li><a href="#budget">Budget</a></li><li><a href="#next">Next actions</a></li></ul></nav>')
    schemes = ('<section class="wrap" id="schemes"><div class="wide stack-lg"><div class="col stack"><p class="eyebrow">Five plans</p>'
               '<h2>Five ways to build it</h2><p>All five sit on the same spot: a level terrace just south-east of the house site in the land plan, placed in the model outside 50-ft circles around the Joshua trees we know about (confirm with a tree map, including trench routes, before building). '
               'Each has one hot tub built into the ground, a cedar sauna a few steps away, a cold plunge or cold shower, a wash and scrub station, a warm rest platform, and plants inside. '
               'Click any image to enlarge it.</p></div>'
               + ''.join(scheme_html(s) for s in SCHEMES) + '</div></section>')
    banner = ''
    if os.environ.get('SPA_PREVIEW'):
        banner = ('<div class="wrap"><div class="col note" style="margin-block:16px"><p><b>Preview.</b> Every plan now has its hot tub '
                  'built into the ground. Scheme A and the first Scheme B images are final; the rest are quick low-resolution '
                  'renders while the final images finish (within the hour). The budget section still shows above-ground tub '
                  'prices; in-ground costs are being researched and will replace them.</p></div></div>')
    body = intro() + toc + banner + spring() + ritual(WAVE) + parts() + schemes + compare(SCHEMES) + inground() + seasons() + plants() + rules() + budget() + products() + actions() + sources()
    open(os.path.join(HERE, 'index.html'), 'w').write(page(body))
    print('wrote index.html', len(page(body)) // 1024, 'KB')


if __name__ == '__main__':
    sys.path.insert(0, HERE)
    main()
