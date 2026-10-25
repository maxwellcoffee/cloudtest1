"""Hand-written sections of the plan page. Facts follow the reconciled key-rule sheet."""
import json, os


RULES = [
    ('Building permit life', 'County: start within 12 months; the permit expires if work stops for 12 months. Town of Yucca Valley: also expires 180 days after the last required inspection (ask the Town). Extensions of up to 180 days on written request.', 'Pass an inspection at least every 5 months until the County or Town confirms otherwise in writing.'),
    ('Living on site while building', 'County: a DMV-registered RV or travel trailer, only after the house permit is issued; 12-month terms renewable up to 5 years (one older code clause reads as 2 years); the trailer permit also lapses if no inspection is called within 180 days. Town: a manufactured home or self-contained RV, up to 4 years.', 'Get the County\'s 2-vs-5-year answer in writing. Check that any park model has current DMV registration before buying.'),
    ('Camping before permits', 'County, 5+ acres zoned RL, AG or RC: owners may camp up to 4 days in any 30. Town: no allowance.', 'Fine for weekend visits during escrow and design, not for living there.'),
    ('Joshua trees', 'No grading, building, septic, trenching, fencing, solar, driveway or brush clearing within 50 ft of a western Joshua tree, including a neighbor\'s, without state (CDFW) approval. Removal fees at 2026 rates: $354.75 / $521.75 / $2,609 per stem by height.', 'Map every stem and draw 50-ft circles before choosing building spots. CDFW Region 6: r6cesa@wildlife.ca.gov, (909) 484-0167.'),
    ('Wildlife', 'Desert tortoise state-endangered since July 2025; burrowing owl and two thrashers are protected candidates.', 'Budget a biologist\'s survey before any clearing.'),
    ('Water', 'A new house can\'t rely on hauled water. Hi-Desert Water District service: $5,418 (sprinkler-ready 5/8-in) or $10,836 (1-in), plus $200 fire-flow fee and installation at cost. A private well: roughly $25k-$100k+ (estimate).', 'Get a written will-serve letter or two well-driller quotes before removing contingencies.'),
    ('Sewage', 'Septic ban only in the Town\'s mapped sewer Phase 1-2 areas: plan on Dec 31, 2028 (the water district says 2031; get it in writing), then connect within 180 days. Everywhere else: a passing perc test and County-approved septic.', 'Septic stays 100 ft from any well and 50 ft from washes.'),
    ('Grading', 'County permit above 100 cubic yards of cut plus fill; hillside standards at 15%+ slope; soils engineer above 20% slope; 1+ acre disturbed needs a state stormwater permit.', 'Every scheme here passes 100 cubic yards, so plan on a grading permit.'),
    ('Fire access', 'Driveway 12 ft wide minimum, up to 12% grade (gravel only to 8%), a turnaround if longer than 150 ft, fire access within 150 ft of every wall. New houses need fire sprinklers, and so do later ADUs.', 'Keep buildings close to the drive.'),
    ('Pods', 'County, 5+ acres: up to 3 accessory units in total (one guest house at most; a junior unit must be inside the house). ADUs are 200-1,200 sq ft and can\'t be finaled before the main house. Up to 2 short-term-rental permits on 2+ acres.', 'Realistic build-out: house + ADU pod + guest-house pod + a non-sleeping studio.'),
    ('Storage container', 'County permit, painted to blend in, behind the house, 5 ft from lot lines, 10 ft from buildings, no utilities. On a lot with no house yet: also a Temporary Use Permit and removal bond. Town: one container on RL lots of 2.5+ acres.', 'Easiest after the house permit is issued.'),
    ('House size', 'County: no minimum (one 70 sq ft room, a bathroom and a kitchen sink). Town: 725 sq ft with two covered parking spaces (under review in 2026; ask the Town).', '640 sq ft in the County; 748 sq ft in the Town.'),
    ('Energy code', 'Heat-pump heating and hot water are the baseline. Solar is likely optional at 640 sq ft (the formula gives about 1.73 kW, under the 1.8 kW cutoff). Whole-floor electric mats don\'t count as supplemental heat.', 'Hydronic slab + air-to-water heat pump for the soft floor; a mini-split for cooling.'),
    ('Bhutan', 'Daily fee (SDF) $100 per adult per night, guaranteed to Aug 31, 2027, may return to $200 after. Visa $40. Tourist stays up to 90 days with a licensed guide and certified lodging only.', 'A 2-3 week spring 2027 trip fits both the fee and the land timeline.'),
]


def cons_top(b):
    E = b.E
    rows = ''.join(f'<tr><th>{E(a)}</th><td>{E(r)}</td><td>{E(n)}</td></tr>' for a, r, n in RULES)
    lot_fields = [
        ('lot-apn', 'Parcel number (APN) and asking price'), ('lot-juris', 'Town or County? Zone and suffix (e.g. RL-5)'),
        ('lot-acres', 'Recorded acreage (5.00 or more?)'), ('lot-water', 'Water source and all-in cost'),
        ('lot-sewer', 'Sewer area or perc test result'), ('lot-power', 'Distance to the nearest power pole; SCE estimate'),
        ('lot-access', 'Recorded legal access? Road condition'), ('lot-jt', 'Joshua tree stems within 50 ft of the likely pads'),
        ('lot-slope', 'Slope at the likely house spot; washes; flood zone'), ('lot-fire', 'Fire hazard zone; nearest hydrant'),
    ]
    lot = ''.join(f'<div class="field"><label for="{k}">{E(l)}</label><input type="text" id="{k}" data-ws="{k}"></div>' for k, l in lot_fields)
    return f'''
    <h3>Our lot</h3>
    <p>Fill this in as facts arrive; it saves to your shared worksheet. Five tests decide most lots: water, sewage, legal access, a building spot 50 ft clear of every Joshua tree, and Town vs County rules. If your lot fails one, that's when to shortlist alternatives.</p>
    <div class="grid2">{lot}</div>
    <div class="field"><label for="lot-walkaway">Our walk-away rules</label><textarea id="lot-walkaway" data-ws="lot-walkaway" placeholder="We walk away if…"></textarea></div>
    <h3>Key rules at a glance</h3>
    <p>One place for the rules that shape everything else. The topic cards below go deeper.</p>
    <div class="tablewrap"><table><thead><tr><th>Topic</th><th>The rule (Oct 2026)</th><th>What it means for you</th></tr></thead><tbody>{rows}</tbody></table></div>
    <div class="callout">
      <h4>Living on the land while you build</h4>
      <p><b>Before the house permit:</b> you can visit and camp up to 4 days in any 30 (County, 5+ acres), but not live there. Plan on renting nearby or an RV-park site for the months between closing and the permit.</p>
      <p><b>During the build:</b> one sleeping unit, a DMV-registered trailer on the temporary permit, plus a permitted storage container. A non-sleeping studio pod can be a permitted accessory structure. Extra sleeping pods can be permitted as ADUs alongside the house, but no one can live in them until the house is finaled. Ask the County whether "temporary security quarters" would allow a second unit for a house-sitter.</p>
      <p><b>Day one in the trailer:</b> power from a temporary construction service once the permit is issued (or a generator or solar generator until then; a rooftop air conditioner needs about 1.5-2 kW on July afternoons); a signed septic pump-out contract; ask the County whether a water tank is acceptable for the trailer until the meter or well is in; shade and tie-downs for spring wind; a P.O. box until an address is assigned; test cell and satellite internet first.</p>
    </div>'''


# A-2 is fixed text around the supplied AI concept board (renders/yucca-earth-sheltered-concept.webp);
# it carries no worksheet fields or checkboxes.
EARTH_SHELTERED = '''

<section class="sheet" id="earth-sheltered" aria-labelledby="earth-h">
  <header>
    <div class="sheet-code"><span>A-2</span><span>Design option · the same 20 × 32 ft, 640 sq ft house</span></div>
    <h2 id="earth-h">Earth sheltered courtyard</h2>
    <p class="lede">A way to set the <a href="#house">A-1 house</a> partly into the ground. Its north service strip tucks shallowly into an uphill slope, and the south glass and the shaded courtyard stay open at downhill grade.</p>
  </header>
  <figure class="plate">
    <img src="img/yucca-earth-sheltered-concept.webp" alt="Concept board titled Yucca Valley, earth sheltered courtyard. Top: a low flat-roofed house with a full-height glass south wall opening onto a shaded courtyard with a pergola, a wood soaking tub and built-in seating among desert plants and Joshua trees. Bottom: a cutaway with the north side set into an uphill earth berm, a clerestory window above the berm, a retaining wall with waterproofing and a drain pipe, and the soft heated living floor." loading="lazy" width="1536" height="1024">
    <figcaption><b>AI generated concept, not a surveyed site plan or construction detail.</b> The drainage arrows are schematic, not engineered drain sizing.</figcaption>
  </figure>
  <div class="col">
    <h3>The design</h3>
    <ul>
      <li><b>Same house.</b> The compact 20 × 32 ft, 640 sq ft room and the soft heated floor from A-1 don't change.</li>
      <li><b>Back into the hill.</b> The north service strip (bath, mechanical closet, galley and entry) sits shallowly into a suitable uphill slope. Engineered retaining walls hold the cut, and short side berms wrap the east and west ends.</li>
      <li><b>Front open to the courtyard.</b> The south glass wall and the shaded courtyard stay at downhill grade, so you still walk straight out onto level ground.</li>
      <li><b>Roof in the open air.</b> The insulated roof stays exposed above the earth, and a rear clerestory brings daylight in over the berm. The retaining walls take the soil, so no earth bears on the SIP or steel shell. There's no buried shipping container.</li>
      <li><b>Where it could fit.</b> It may suit the mid-slope bench of <a href="#scheme-C">S-C Courtyard Compound</a>, if the survey and the drainage support it. It's an additional design option. It doesn't change the preferred scheme or the agreed budget.</li>
    </ul>
    <div class="proscons">
      <div><h4>What it could give you</h4><ul>
        <li>Earth against the north and side walls blocks wind and evens out temperature swings on those walls.</li>
        <li>A lower profile from uphill, and a courtyard sheltered on three sides.</li>
        <li>The south glass, the courtyard and the floor plan work as they do in A-1.</li>
      </ul></div>
      <div><h4>What it asks of you</h4><ul>
        <li>Excavation, retaining walls, waterproofing and drainage become extra work, each with its own engineering and inspections.</li>
        <li>Uphill runoff and desert cloudbursts have to be steered around the house, and water behind the walls carried away.</li>
        <li>Daylight and fresh air on the back side come only through the clerestory and fans, and the back walls are hard to change later.</li>
        <li>The cut is grading, so it still has to stay 50 ft clear of every Joshua tree.</li>
      </ul></div>
    </div>
    <div class="callout">
      <h4>Before you choose it</h4>
      <p>A geotechnical, civil and structural review must establish a suitable slope, the excavation, the retaining wall design, runoff diversion, external waterproofing and drainage to a lawful outlet, daylight and ventilation, and a safe way out. Price those items separately before selecting this option. Partial earth sheltering is not proof of a lower installed cost, or that the house will be more affordable.</p>
    </div>
    <p style="color:var(--ink-2);font-size:.9rem">Background reading: <a href="https://dahp.wa.gov/historic-preservation/historic-buildings/architectural-style-guide/earth-shelter">Earth shelter (Washington State DAHP architectural style guide)</a> · <a href="https://bsesc.energy.gov/energy-basics/foundation-drain-gutters-downspouts">Foundation drains, gutters and downspouts (U.S. DOE Building Science Education)</a></p>
  </div>
</section>'''


def sections(b):
    E, ul, cid, linkify, digest, research = b.E, b.ul, b.cid, b.linkify, b.digest, b.research
    out = {}

    # ------------------------------------------------------------------ overview
    facts = [
        ('You can live on the land while you build, in a registered trailer.',
         'Once the house\'s building permit is issued, the County gives a temporary permit to live in a DMV-registered RV or travel trailer, renewed a year at a time. '
         'The $20k imported capsule is different: California only lets people live in an RV with a valid label, a HUD manufactured home, state-approved factory-built housing or a permitted house, and most imported pods are none of these. '
         'Keep a capsule as a permitted studio or storage you don\'t sleep in, or buy certified units for sleeping.'),
        ('"As long as we\'re making progress" means passed inspections.',
         'In the County a building permit expires if work stops for 12 months; the Town of Yucca Valley also cuts it off 180 days after the last required inspection. '
         'Your permit to live on site ends with the building permit. Pass an inspection at least every 5 months, and take long trips before construction starts or after it\'s finished.'),
        ('Water and sewage decide the deal.',
         'A new house can\'t rely on trucked-in water, so you need a water-district meter or a permitted well (roughly $25k-$100k+). '
         'In the Town\'s mapped sewer areas septic is being phased out; everywhere else you need a passing perc test. '
         'Together these can cost as much as the house. Get both answers in writing before you remove contingencies.'),
        ('Joshua trees decide where you can build.',
         'In the County, any grading, building, septic, trenching, fencing, solar or driveway work within 50 ft of a western Joshua tree, even one on the neighbor\'s side of the line, needs state approval first, and removal fees run $355 to $2,609 per stem. '
         'The desert tortoise is now state-endangered too, so plan on a biologist\'s survey. Map the trees on your first walk and draw 50-ft circles before choosing a building spot.'),
        ('Unincorporated County land fits this plan best.',
         'County rural zones give a 12-month permit clock, up to three accessory units on 5+ acres (so a house plus an ADU pod and a guest pod), permitted storage containers, and short-term rentals of permitted ADUs. '
         'The Town adds a 180-day inspection rule, a capped rental waitlist and the sewer-area septic ban.'),
    ]
    fact_html = ''.join(f'<div class="fact"><span class="k">{i + 1}</span><div><b>{E(h)}</b> {E(t)}</div></div>' for i, (h, t) in enumerate(facts))
    out['OVERVIEW'] = f'''
<section class="sheet hero" id="overview" aria-labelledby="ov-h">
  <div class="sheet-code"><span>G-0</span><span>Prepared 23 Oct 2026 · Yucca Valley, CA · about 3,300 ft</span></div>
  <h1 id="ov-h">A small house on five desert acres</h1>
  <p class="lede">A plan for buying a rural lot near Yucca Valley, living on it while you slowly build a tiny modern house with a soft, heated floor, adding a few pods and an orchard, and fitting in time in Bhutan. It follows the five-step planning method from <i>Getting Things Done</i>: an hour for you alone, then a 90-minute meeting together, backed by research, a team list, four site designs and a checklist.</p>
  <figure>
    <img src="img/house_exterior.jpg" alt="Rendering of the small modern house at dusk: a white box with a glass south wall under a deep roof, a capsule pod and Joshua tree behind" width="1800" height="1100">
    <figcaption>The 640 sq ft house concept at dusk, rendered in Blender. Glass faces south under a deep terrace roof; the whole living floor is soft.</figcaption>
  </figure>
  <nav class="npm" aria-label="The five planning steps">
    <a href="#solo-1"><span class="n">1</span><span class="t">Defining purpose and principles</span></a>
    <a href="#solo-2"><span class="n">2</span><span class="t">Outcome visioning</span></a>
    <a href="#solo-3"><span class="n">3</span><span class="t">Brainstorming</span></a>
    <a href="#solo-4"><span class="n">4</span><span class="t">Organizing</span></a>
    <a href="#solo-5"><span class="n">5</span><span class="t">Identifying next actions</span></a>
  </nav>
  <div class="col">
    <h3>Five things the research changed</h3>
    <div class="facts">{fact_html}</div>
    <div class="callout">
      <h4>The plan in one paragraph</h4>
      <p>Check your lot against five tests: water, sewage, legal access, a building spot 50 ft clear of every Joshua tree, and Town or County rules. Offer with a 45-60 day due-diligence period. After closing, take a 2-3 week Bhutan trip in spring 2027 while the daily fee is still $100 and the designer starts. Then survey, test, design and submit a small, simple house. When the permit is issued, move onto the land in a registered trailer, grade and plumb the pads, and build in steps that each end in a passed inspection. When the house is finaled, the trailer pad becomes a permitted ADU pod, and the guest pod, studio and orchard follow.</p>
    </div>
    <p style="color:var(--ink-2);font-size:.9rem">How to use this page: do sheet <a href="#solo">P-1</a> alone, send the note in <a href="#meeting">P-2</a> and run the meeting, use C-1 to M-1 as reference after you've each written your own thoughts, and tick things off in <a href="#next">N-1</a>. What either of you types or ticks is saved to a shared worksheet, so you can each use your own phone.</p>
  </div>
</section>'''

    # ------------------------------------------------------------------ house
    house_legend, floor_legend = {}, []
    for name in ('house_cutaway', 'house_plan'):
        p = os.path.join(b.RND, name + '.legend.json')
        if os.path.exists(p):
            for it in json.load(open(p)):
                house_legend[it['n']] = it
    house_legend = [house_legend[k] for k in sorted(house_legend)]
    p = os.path.join(b.RND, 'floor_buildup.legend.json')
    if os.path.exists(p):
        floor_legend = json.load(open(p))
    hl = ''.join(f'<li data-n="{i["n"]}"><span class="dot ph2">{i["n"]}</span><span>{E(i["label"])}</span></li>' for i in house_legend)
    fl = ''.join(f'<li><span class="dot ph1">{i["n"]}</span><span>{E(i["label"])}</span></li>' for i in floor_legend)
    shown = ','.join(str(i['n']) for i in house_legend)
    paths = [
        ('Custom 640 sq ft house as the main dwelling', 'Permit, then a trailer on site while you build (about 24-30 months from offer to final)', 'Full: the modern box, soft floor, your layout', 'Recommended. Design it as a simple core that can be finaled within the trailer permit.'),
        ('County pre-approved 560 sq ft plan filed as the main house', 'Faster plan check; the same trailer route while building', 'Low: pitched roof, set layout', 'Ask the County whether an ADU plan can be filed as a main house. Useful as a checked template either way.'),
        ('HUD manufactured home first, modern house later as an ADU', 'About 4-5 weeks after the County accepts a complete application (average fees about $4,800), plus site work', 'None at first; full for the later ADU (up to 1,200 sq ft)', 'Gets you a legal home soonest; the modern house becomes the second unit.'),
    ]
    prow = ''.join(f'<tr><td><b>{E(a)}</b></td><td>{E(c)}</td><td>{E(d)}</td><td>{E(e)}</td></tr>' for a, c, d, e in paths)
    out['HOUSE'] = f'''
<section class="sheet" id="house" aria-labelledby="house-h">
  <header>
    <div class="sheet-code"><span>A-1</span><span>20 × 32 ft · 640 sq ft · one room</span></div>
    <h2 id="house-h">The house: small, open, soft underfoot</h2>
    <p class="lede">One room you can lie down anywhere in. A north "service bar" holds the bath, a mechanical closet, a galley kitchen and a Japanese-style entry where shoes come off. Everything south of it is one soft, heated floor that opens through sliding glass to the terrace and the view.</p>
  </header>
  <div class="tabs" role="tablist" data-tabs="img-house">
    <button type="button" role="tab" aria-selected="true" data-src="img/house_cutaway.jpg" data-alt="Cutaway of the house with the roof removed" data-show="{shown}">Cutaway</button>
    <button type="button" role="tab" aria-selected="false" data-src="img/house_plan.jpg" data-alt="Floor plan of the house from above" data-show="{shown}">Plan</button>
    <button type="button" role="tab" aria-selected="false" data-src="img/house_exterior.jpg" data-alt="Exterior of the house at dusk" data-show="">Outside at dusk</button>
  </div>
  <figure class="plate">
    <img id="img-house" src="img/house_cutaway.jpg" alt="Cutaway of the house with the roof removed" loading="lazy" width="1800" height="1200">
    <ul class="legend" id="img-house-legend">{hl}</ul>
  </figure>
  <div class="col">
    <h3>Design brief</h3>
    <div class="tablewrap"><table>
      <tbody>
        <tr><th>Size</th><td>20 × 32 ft outside (640 sq ft) in the unincorporated County, which has no minimum house size; state code needs only one 70 sq ft room, a bathroom and a kitchen sink. A 16 × 30 ft (480 sq ft) version still fits floor-living for two; tape both out on the ground before you decide. Inside the Town the minimum is 725 sq ft with two covered parking spaces, so the Town version is 22 × 34 ft (748 sq ft) with a carport.</td></tr>
        <tr><th>Shape</th><td>An east-west bar with a flat roof and a deep roof over an 8 × 32 ft south terrace. The roof edge stops the high summer sun and lets the low winter sun in. About 100 sq ft of south glass, a clerestory strip to the north, very little glass east and west. Ceiling 8'-6" to 9'.</td></tr>
        <tr><th>On the slope</th><td>Cut into the hill rather than filling (deep fill under a slab needs engineering). A slab that steps with the contour gives the entry a natural step down, so you take your shoes off and step up onto the soft floor.</td></tr>
        <tr><th>Structure</th><td>SIP panels or a steel kit shell put up by a crew in days, then you finish the inside yourselves (owner-builders may do their own electrical and plumbing under the permit). Class A roof, fiber-cement or steel siding, ember-resistant vents and tempered glass; a noncombustible paver terrace for the first 5 ft around the house.</td></tr>
        <tr><th>Heat + cool</th><td>A hydronic slab fed by an air-to-water heat pump heats the whole soft floor and meets the energy code's heat-pump baseline. A small ductless mini-split handles summer cooling. Electric mats are fine only for small zones; whole-floor mats don't count as "supplemental" heat. A heat-pump water heater completes it. Solar is likely optional at 640 sq ft (confirm with a Title 24 energy consultant) but worth it.</td></tr>
        <tr><th>Fire sprinklers</th><td>Required in every new house, and in later ADUs once the main house has them. Plan a 4 × 6 ft mechanical closet for the sprinkler riser, water heater and radiant manifold, and budget roughly $4k-12k for sprinklers plus a tank and pump if water pressure is low.</td></tr>
        <tr><th>The soft floor</th><td>Keep everything above the heat at about R-1.4 or less. <b>Most Japanese:</b> thin floor-heating tatami (15-30 mm) set flush in a 1-inch slab recess. <b>Softest and simplest:</b> cork underlay with wool felt or low-pile wool carpet. <b>Alternative:</b> a raised tatami platform 12-16 inches high with storage underneath (needs a 9-ft ceiling). Traditional thick tatami (55-60 mm) blocks too much heat. Test samples on a warm floor first.</td></tr>
        <tr><th>Living on the floor</th><td>A low kotatsu table, floor cushions, a futon that rolls out at night and folds into a closet by day, low built-in storage. Hard porcelain only where water or shoes go: kitchen strip, bath, entry.</td></tr>
      </tbody>
    </table></div>
    <h3>Three paths to a legal home</h3>
  </div>
  <div class="tablewrap"><table><thead><tr><th>Path</th><th>Time to a legal place to live</th><th>Design freedom</th><th>Notes</th></tr></thead><tbody>{prow}</tbody></table></div>
  <div class="col"><h3>Floor build-up</h3></div>
  <figure class="plate">
    <img src="img/floor_buildup.jpg" alt="Exploded diagram of the floor layers from gravel base to tatami" loading="lazy" width="1800" height="1300">
    <ul class="legend">{fl}</ul>
    <figcaption>Layer thicknesses are exaggerated so each one shows. More detail in <a href="#topic-house_design">C-1 · The small house</a>.</figcaption>
  </figure>
</section>'''

    out['HOUSE'] += EARTH_SHELTERED   # A-2: design option for setting the A-1 house partly into the ground

    # ------------------------------------------------------------------ bhutan
    bd = digest('bhutan')
    routes = [
        ('Guided tourist trip', '2 weeks to 90 days', 'Daily fee $100 per adult per night to Aug 31, 2027 (may return to $200 after), plus a licensed guide, car and certified lodging', 'About $11k-18k for two for 2 weeks, flights included', 'Anyone'),
        ('Personal guest of a Bhutanese friend', 'Up to 30 days, one visit (reported)', 'Daily fee reportedly waived; the host files the paperwork and is liable if you are really touring', 'Flights and your own costs', 'Only a real friend who is a Bhutanese citizen living in Bhutan and can show they know you; it uses their yearly allowance of 2 guests'),
        ('Volunteer, teaching or consulting role', 'Set by the role', 'Daily fee reportedly waived; a registered Bhutanese organization sponsors the visa', 'Flights and living costs', 'A genuine role offered by a registered organization, usually months of lead time'),
        ('Gelephu Mindfulness City nomad residence', '12 months, renewable to 24', '$2,800 a year plus a $10,000 refundable deposit (sold by a private operator; not yet confirmed by the city)', 'Fee + deposit + living', 'Professionals in the city\'s priority sectors; confirm with info@gmc.bt before paying'),
    ]
    rrows = ''.join(f'<tr><td><b>{E(a)}</b></td><td>{E(b_)}</td><td>{E(c)}</td><td>{E(d)}</td><td>{E(e)}</td></tr>' for a, b_, c, d, e in routes)
    out['BHUTAN'] = f'''
<section class="sheet" id="bhutan" aria-labelledby="bt-h">
  <header>
    <div class="sheet-code"><span>X-1</span><span>Bhutan · fee guaranteed to 31 Aug 2027</span></div>
    <h2 id="bt-h">Bhutan, and what a sponsor really is</h2>
    <p class="lede">{E(bd['headline']) if bd else ''}</p>
  </header>
  <div class="col">
    <div class="callout">
      <h4>Two windows that fit the land</h4>
      <p><b>Spring 2027 (recommended for a first trip):</b> 2-3 weeks in late March or April, after you close and while the designer starts. No permit clock is running, the $100 fee still applies, and it's before the monsoon. The lot has no permits yet, so a container there would need its own temporary permit and bond: keep belongings in a climate-controlled storage unit in town for this trip (about $84-131 a month).</p>
      <p><b>Later, with your things stored on the land:</b> once the house permit is issued, a permitted container can sit behind the house pad. A trip mid-build only works right after a passed inspection, kept under about 5 months, with any extension approved in writing first, and someone checking the site. The easiest long stay comes after the house is finaled, when nothing is on a permit clock. A steel container on a summer lot gets hot enough to ruin electronics, photos and adhesives, so store those in town either way.</p>
    </div>
    <h3>Four legal ways in</h3>
  </div>
  <div class="tablewrap"><table>
    <thead><tr><th>Route</th><th>Length</th><th>Fees</th><th>Rough cost</th><th>Who it fits</th></tr></thead>
    <tbody>{rrows}</tbody>
  </table></div>
  <div class="col">
    <h3>Finding a sponsor the right way</h3>
    <ul>
      <li>Start with people you already know. If neither of you knows a Bhutanese citizen living in Bhutan, cross the personal-guest route off rather than looking for a host online: anyone offering to "sponsor" you for a fee is a red flag, and the host carries the risk.</li>
      <li>Lead with what you can give. Write a 150-word skills offer (design, building, water harvesting, gardens, whatever is true) and send it to organizations such as the Bhutan Foundation (a US charity with a Thimphu office) and the Tarayana Foundation (rural housing and livelihoods). Let them decide whether a volunteer role fits.</li>
      <li>A first 2-3 week guided trip is the natural way to meet people who might later host you for longer.</li>
      <li>Only Bhutanese citizens living in Bhutan can host a personal guest; many people of Bhutanese origin in the US are not Bhutanese citizens.</li>
    </ul>
    <p>Full details, risks and contacts: <a href="#topic-bhutan">C-1 · Bhutan</a>.</p>
  </div>
</section>'''

    # ------------------------------------------------------------------ money + timeline
    fr = research('finance_timeline') or {}
    costs = fr.get('costs', [])
    tiers = [c for c in costs if c['item'].startswith('TOTAL')]
    lines = [c for c in costs if not c['item'].startswith('TOTAL') and 'carrying' not in c['item'].lower() and 'Bhutan' not in c['item']]
    money = lambda v: f'${v / 1000:,.0f}k' if v < 1_000_000 else f'${v / 1_000_000:.2f}M'
    tier_notes = {
        'lean': 'Remote dirt-road lot, district water close by, conventional septic, DIY solar, a used trailer, about 400 sq ft built mostly by you. Excluding land: about $182k-$391k.',
        'balanced': 'Lot near utilities, water connection, contractor shell with your finishes, about 500 sq ft. Our 640 sq ft design lands near the top of this tier. Excluding land: about $351k-$699k.',
        'mostly': 'Premium lot ($180k-$300k), an architect, possibly a well and a long power line, about 600 sq ft mostly hired out, 15-20% contingency. The top end stacks every expensive case at once.',
    }
    trows = ''
    for c in tiers:
        name = c['item'].replace('TOTAL ', '').split(' tier')[0].strip()
        key = 'lean' if 'lean' in name.lower() else ('balanced' if 'balanced' in name.lower() else 'mostly')
        trows += f'<tr><td><b>{E(name.capitalize())}</b></td><td class="money">{money(c["low_usd"])} – {money(c["high_usd"])}</td><td>{E(tier_notes[key])}</td></tr>'
    lrows = ''.join(f'<tr><td>{E(c["item"])}</td><td class="money">{money(c["low_usd"])} – {money(c["high_usd"])}</td><td>{E(c.get("notes", ""))}</td></tr>' for c in lines)
    steps = [
        ('Nov – Dec 2026', 'Research and visits', 'Solo hour and the meeting. Desktop checks, calls to the County and the water district, first walks with a land agent.'),
        ('Jan – Feb 2027', 'Offer', 'Offer with a 45-60 day due-diligence period: survey, Joshua tree census, perc test or sewer letter, water will-serve or well opinion, power estimate, insurance quote.'),
        ('Mar – Apr 2027', 'Close; Bhutan', 'Close and buy vacant-land liability insurance. Hire the designer, then take a 2-3 week Bhutan trip in late March or April while the daily fee is $100. Weekend camping on the land is allowed up to 4 days in any 30 (County, 5+ acres).'),
        ('Apr – Aug 2027', 'Design and submit', 'Topographic survey, perc test, biologist, design, structural and energy work, then submit house, grading and septic plans.'),
        ('Sep – Dec 2027', 'Permit and move in', 'Plan check, permit, temporary trailer permit. Move the trailer on, set the container, grade the pads, bring in water, septic and power. Plant the first natives in fall once water is in.'),
        ('2028', 'Build', 'Slab with radiant tubing, shell, roof, windows, then the inside. Pass an inspection at least every 5 months.'),
        ('Late 2028 – 2029', 'Final', 'Final inspection and certificate of occupancy, about 24-30 months from the offer. The trailer leaves; the ADU pod goes on its pad.'),
        ('2029 onward', 'Grow', 'Guest pod, studio, orchard, trails, and a longer Bhutan stay with nothing on a permit clock.'),
    ]
    tl = ''.join(f'<div class="tl"><span class="when">{E(w)}</span><h4>{E(t)}</h4><p>{E(d)}</p></div>' for w, t, d in steps)
    out['MONEY'] = f'''
<section class="sheet" id="money" aria-labelledby="money-h">
  <header>
    <div class="sheet-code"><span>M-1</span><span>2026 dollars · land included · estimates unless noted</span></div>
    <h2 id="money-h">Money and timeline</h2>
    <p class="lede">The land is the cheap part. Water, septic, power, grading and the driveway together often cost as much as the house. Five-acre lots listed in 2026 ran about $25k-$60k on remote dirt roads (Landers, Flamingo Heights), $60k-$180k near Yucca Valley with power and water close, and $225k-$475k in Pioneertown and Pipes Canyon. Compare lots on price plus infrastructure: a $40k lot that needs a $60k well and $40k of power costs more than a $120k lot with a meter and a pole at the road.</p>
  </header>
  <div class="col">
    <h3>Three budget tiers</h3>
    <div class="tablewrap"><table><thead><tr><th>Tier</th><th>All-in range</th><th>What it assumes</th></tr></thead><tbody>{trows}</tbody></table></div>
    <p>While you build, carrying costs run about $5k-10k a year (property tax, insurance, fixed utility charges, permit renewals, storage), plus a caretaker while you're away. Few lenders fund owner-builders, so plan to pay cash in phases (land, then infrastructure, then the house) and refinance after the final inspection.</p>
    <details class="topic"><summary><h3>Line items</h3><p>Every cost in the budget model, low to high.</p></summary>
      <div class="topic-body"><div class="tablewrap"><table><thead><tr><th>Item</th><th>Range</th><th>Notes</th></tr></thead><tbody>{lrows}</tbody></table></div></div>
    </details>
    <h3>A realistic schedule</h3>
    <div class="timeline">{tl}</div>
    <p>More on financing and insurance: <a href="#topic-finance_timeline">C-1 · Money, insurance and the timeline</a>.</p>
  </div>
</section>'''

    # ------------------------------------------------------------------ next actions
    calls = [
        ('County Land Use Services', '(909) 387-8311', 'Is APN ___ a legal lot, and what zone and suffix? Is the temporary trailer permit 2 years or 5 in total? How long does a building permit stay alive without an inspection, and how many 180-day extensions are possible? Does the 50-ft Joshua tree rule apply to every project? How many ADUs on 5+ acres, and do a guest house and junior unit count? Can the 560 sq ft pre-approved plan be filed as a main house? Can a container count as construction storage? Ask for the answers by email with the staff member\'s name.'),
        ('Water district for the APN', 'Hi-Desert, Bighorn-Desert View or Joshua Basin', 'Is there a main along the frontage? All-in cost of a sprinkler-ready meter? How do we get a will-serve letter? (Hi-Desert) Is the lot in a sewer phase, and which deadline applies?'),
        ('County Environmental Health', 'via County Land Use Services', 'Perc test and septic design requirements; well permits if there is no main; whether a tank is acceptable for the temporary trailer.'),
        ('CDFW Region 6', 'r6cesa@wildlife.ca.gov · (909) 484-0167', 'Send the APN, tree map and site sketch: does a design that keeps 50 ft from every stem need anything from you?'),
        ('Southern California Edison', 'sce.com new service', 'Preliminary estimate to bring power to the house spot; temporary construction power once the permit is issued.'),
        ('County Fire', 'Office of the Fire Marshal', 'Hazard zone, driveway and turnaround standard, water storage and sprinkler requirements.'),
        ('Town of Yucca Valley Planning', 'only if the lot is in the Town', 'Current minimum house size, ADU rules, permit expiration, temporary use permit for a trailer, container rules.'),
        ('Independent insurance broker', 'one who writes the California FAIR Plan', 'Vacant-land liability now, builder\'s risk later, the trailer as an RV, and how a long absence affects coverage.'),
    ]
    call_rows = ''.join(f'<tr><td><b>{E(a)}</b><br><span class="mono" style="font-size:.8rem">{E(c)}</span></td><td>{E(q)}</td></tr>' for a, c, q in calls)
    first = [
        ('@computer', 'Look up the parcel on the County Assessor map viewer: Town or County, zoning and suffix, and whether it is at least 5.00 acres.'),
        ('@computer', 'Screenshot the parcel on the FEMA flood map, the CAL FIRE hazard map and the County hazard maps; keep them in one folder.'),
        ('@phone', 'Call County Land Use Services (909-387-8311) with the questions in the call sheet above; ask for the answers by email.'),
        ('@phone', 'Call the water district for the parcel: main at the frontage, meter cost, will-serve letter, and (in the Town) the sewer phase.'),
        ('@land', 'Walk the lot with the seller\'s permission: count Joshua tree stems with photos and GPS points, find the flattest spot 50 ft clear of every tree, look for wash debris lines, check cell signal, photograph the nearest power pole and water meter.'),
        ('@phone', 'Ask Southern California Edison for a preliminary estimate to bring power to the likely house spot.'),
        ('@phone', 'Interview two land-savvy buyer\'s agents: how many Morongo Basin land deals they closed, and whether they will write a 45-60 day due-diligence contingency.'),
        ('@computer', 'Price a used DMV-registered travel trailer for the build; ask any capsule seller for its RV, HUD or state factory-built label in writing.'),
        ('@phone', 'Get an insurance quote from an independent broker: vacant-land liability now, builder\'s risk later.'),
        ('@email', 'Email hosts@tourism.gov.bt: which fee applies to nights after Aug 31, 2027, and whether a guide is needed every day on a slow 2-3 week stay.'),
        ('@together', 'Book the 90-minute planning meeting, the money hour, and a standing 30-minute weekly review.'),
        ('@computer', 'Write your 150-word skills offer for Bhutanese organizations.'),
    ]
    first_html = ''.join(f'<li><label><input type="checkbox" data-check="{cid(t)}"><span><span class="ctx">{E(c)}</span>{E(t)}</span></label></li>' for c, t in first)
    groups = []
    for key, title, _ in b.TOPICS:
        g = digest(key)
        acts = (g or {}).get('next_actions', [])
        if not acts:
            continue
        lis = ''.join(f'<li><label><input type="checkbox" data-check="{cid(a)}"><span>{E(a)}</span></label></li>' for a in acts)
        groups.append(f'<details class="topic"><summary><h3>{E(title)}</h3><p>{len(acts)} actions</p></summary><div class="topic-body"><ul class="checklist">{lis}</ul></div></details>')
    out['NEXT'] = f'''
<section class="sheet" id="next" aria-labelledby="next-h">
  <header>
    <div class="sheet-code"><span>N-1</span><span>Verb first · one sitting each · ticks are shared</span></div>
    <h2 id="next-h">Next actions</h2>
    <p class="lede">One call per agency covers most of the open questions, so start with the call sheet. Then the first dozen actions in a sensible order, then each topic's own list.</p>
  </header>
  <div class="col">
    <h3>One call per agency</h3>
  </div>
  <div class="tablewrap"><table><thead><tr><th>Who</th><th>Ask, in one conversation</th></tr></thead><tbody>{call_rows}</tbody></table></div>
  <div class="col">
    <h3>Start with these</h3>
    <ul class="checklist">{first_html}</ul>
    <h3>By topic</h3>
    <div class="topics">{''.join(groups)}</div>
  </div>
</section>'''

    # ------------------------------------------------------------------ sources
    seen, rows = set(), []
    for key, title, _ in b.TOPICS:
        g = digest(key) or {}
        lst = list(g.get('key_sources', [])) + b.checked_sources(key)
        for s in lst:
            if s in seen or not s.startswith('http'):
                continue
            seen.add(s)
            rows.append(f'<div><span class="mono" style="color:var(--flag)">{E(title)}</span><br>{linkify(s)}</div>')
    out['SOURCES'] = f'''
<section class="sheet" id="sources" aria-labelledby="src-h">
  <header>
    <div class="sheet-code"><span>R-1</span><span>Researched 22-23 Oct 2026 · {len(rows)} sources</span></div>
    <h2 id="src-h">Sources</h2>
    <p class="lede">The sources behind each topic, including every source a second reviewer used to confirm or correct a claim. Codes, fees and Bhutan's rules change; confirm anything you rely on with the agency, in writing.</p>
  </header>
  <div class="sources">{''.join(rows)}</div>
</section>'''
    return out
