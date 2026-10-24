"""Text sections of the gazebo bathhouse page (numbers come from data/research and the fact-check)."""


def intro():
    return '''
<header class="wrap hero">
  <div class="wide hero-grid">
    <div class="hero-text">
      <p class="eyebrow">Yucca Valley lot &middot; bathhouse plans &middot; October 2026</p>
      <h1>The Garden Bathhouse</h1>
      <p class="lede">Five plans for a Korean-style bathhouse on the land: one hot tub built into the ground, under a
      roof with plants inside, a cedar sauna a few steps away, then cold water and a warm floor to rest on. The
      starting point is the enclosed pool house at The Spring in Desert Hot Springs.</p>
      <p class="muted">The colors and the coral lattice come from kwonyin.global: blush, peach, coral and black, with
      bright black-and-white desert light. If you want a different palette or lattice pattern, the renders can be
      redone. Every image is a Blender render of the lot model: same slope, same Joshua trees, same mountains to the
      north. Prices are what makers listed on October 24, 2026 (some are sale or "from" prices) or labeled estimates.</p>
    </div>
    <div class="lattice"><button class="zoom" type="button" data-full="img/A_hero_bw.jpg" data-cap="Scheme A, the Spring Glass House, in black and white">
      <img src="img/A_hero_bw.jpg" alt="Scheme A, the Spring Glass House, in black and white" width="1600" height="900"></button></div>
  </div>
</header>'''


def spring():
    return '''
<section class="wrap" id="spring"><div class="col stack">
  <p class="eyebrow">The precedent</p>
  <h2>What The Spring's gazebo really is</h2>
  <p>The "gazebo" at The Spring Resort &amp; Spa is an enclosed pool house at one end of the main pool, which one
  guide calls "the pool inside the greenhouse". The resort keeps that pool "slightly above body temperature"
  (a hot-springs guide puts it at about 101F) and the outdoor soaking pool at 104F. The property was built in
  1957, was known for more than 45 years as The Moors Hotel, became The Spring in 2003, and is adults-only.
  Reconstructed from the resort's own photos, the pool house is:</p>
  <ul>
    <li>A one-story timber post-and-beam room under a low-slope roof with exposed rafter tails. Posts are roughly 6 ft apart, about 8 ft to the top plate.</li>
    <li>Walls in three bands: a solid knee wall about 3 ft high, glass with a frosted privacy stripe, and an open band of painted vertical slats under the header.</li>
    <li>A dark-bronze sliding glass door to the main pool.</li>
    <li>Inside: a freeform pool about 4 ft deep with a blue mosaic band at the waterline, a pebble-finish deck, wood sling chairs, boulders, potted yucca and snake plant, and fan palms just outside.</li>
    <li>Around it: pergolas of rough-sawn posts with vines and hanging rusted cone planters, fan palms, and black pebble mulch.</li>
  </ul>
  <div class="note"><p><b>What these plans borrow:</b> the glass room that stops the wind, warm water a little
  above body temperature, plants growing right beside the tub, a slatted band that lets steam out, and a pergola
  with vines. <b>What they add:</b> the Korean order of wash, soak, sauna, cold and rest; coral lattice in place of
  frosted glass; and blush, peach and black against white plaster and cedar.</p></div>
  <p class="small muted">Dimensions are estimates from photos; review sites blocked automated reading.</p>
</div></section>'''


def ritual(wave):
    return f'''
<section class="wrap" id="ritual" style="background:var(--wash)"><div class="wide stack-lg">
  <div class="col stack">
    <p class="eyebrow">How you would use it</p>
    <h2>The bathing round</h2>
    <p>A mogyoktang is a Korean bathhouse for washing and soaking; a jjimjilbang adds hot rooms and a heated floor to
    lie on. Both follow the same pattern: clean, hot, cold, rest. For two people at home a full round takes about 2
    to 2.5 hours. Steps 3, 4 and 5 repeat two or three times, and the round ends with a longer 20-30 minute rest.</p>
  </div>
  <ol class="round">
    <li><span class="t">Wash</span><span>Seated shower on a low stool, about 10 minutes. Hair tied up. Nobody gets in the tub unwashed.</span></li>
    <li><span class="t">Soak</span><span>10 to 15 minutes at 100-104F, heart above the water. In summer run it as a warm tub at 97-100F.</span></li>
    <li><span class="t">Sauna</span><span>8 to 12 minutes at 176-194F. No more than about 30 minutes of high heat in total.</span></li>
    <li><span class="t">Cold</span><span>30 seconds to 2 minutes at 57-64F, head out, feet first, never alone. From about November to April the water is cold enough on its own.</span></li>
    <li><span class="t">Rest</span><span>10 to 15 minutes lying on the warm floor (about 97F) with a glass of water.</span></li>
  </ol>
  <div class="col stack">
    {wave}
    <p>Once a week at most, after a soak, scrub each other with an Italy towel, a coarse mitt (the scrub itself is
    called seshin). Never on the face; rinse after. Finish lying on the warm floor with cold sikhye (a sweet rice
    drink) and slow-baked eggs (maekbanseok eggs, baked ahead in an oven or rice cooker until the whites turn tan).</p>
    <div class="note"><p><b>Safety.</b> Korean bathhouses run their hot tubs at 106-109F. At home, cap the tub at
    104F, the long-standing U.S. Consumer Product Safety Commission guideline (from 1979; advice, not a regulation),
    and at 100F or less for anyone pregnant. Drink water after every round and skip alcohol before and between
    rounds. Anyone with a heart condition should ask a doctor about sauna and cold plunges first. Keep the warm floor
    at or below about 104F for long lying.</p></div>
  </div>
</div></section>'''


def parts():
    rows = [
        ('Wash station', 'A low stool, a basin, a hand shower and a mirror at seated height. Wash head to toe before touching any tub.'),
        ('Hot tub (ontang)', 'The one in-ground tub. Soak with your heart above the water; keep it covered between uses.'),
        ('Cedar sauna', 'Takes the place of a jjimjilbang\'s hot rooms: dry heat, 8 to 12 minutes a round.'),
        ('Cold plunge (naengtang)', 'A short dip that ends each round. In summer it needs a chiller to stay cold.'),
        ('Warm floor (ondol)', 'A heated platform you lie on between rounds, the heart of a jjimjilbang.'),
        ('Scrub table', 'For the weekly partner scrub with an Italy towel.'),
        ('Clay dome (hanjeungmak)', 'Only in Scheme D, and optional: a dome of clay or stone, traditionally heated by a pine fire. Rounds of 10 minutes or less.'),
        ('Snack corner', 'Cold sikhye and baked eggs, eaten on the warm floor.'),
    ]
    trs = ''.join(f'<tr><td><b>{a}</b></td><td>{b}</td></tr>' for a, b in rows)
    return f'''
<section class="wrap" id="parts"><div class="col stack">
  <p class="eyebrow">The pieces</p><h2>What each part is for</h2>
  <div class="scroll"><table><tbody>{trs}</tbody></table></div>
  <p><b>What to wear.</b> Korean bathhouses are nude and split by gender. At home with guests, wear swimsuits in the
  tub and loose cotton clothes (jjimjilbok, a T-shirt and shorts) in the sauna and on the warm floor; peach sets for
  guests suit the palette.</p>
  <p><b>Barrel or cabin sauna?</b> A barrel heats fast and costs less, but you sit upright. A 7 x 7 ft cabin has a
  bench long enough to lie on, which is how many Koreans rest in the heat. Ask for red cedar: Almost Heaven's
  barrels come in red cedar, while some other makers use hemlock or spruce.</p>
</div></section>'''


def seasons():
    return '''
<section class="wrap" id="seasons" style="background:var(--wash)"><div class="col stack">
  <p class="eyebrow">Living with it</p><h2>Summer, water and running costs</h2>
  <p><b>June to September:</b> use the bathhouse at dawn or after dark. Set the tub to 97-100F, keep sauna rounds
  short, and run a chiller on the plunge; without one it is only cold from about November to April. A glass room
  (Scheme A) overheats on summer afternoons unless its doors open wide and the west and south glass is shaded.</p>
  <p><b>Winter:</b> nights reach 17-25F. Keep the tub covered and heated, and disconnect and drain outdoor plunge
  chillers on freezing nights (Penguin rates its outdoor units only above 32F). Don't open a cover lifter in winds
  above about 25 mph.</p>
  <p><b>Where the water goes:</b> decide before pouring a slab. Shower and wash-floor water goes to the septic system
  or to a permitted graywater line for the plants; ask the County which it allows. To drain the tub, let the
  chlorine fade for a few days, then drain it slowly onto the land, not into the septic tank. Ask the County before
  the first drain.</p>
  <p><b>Running costs (rough estimates at about 35 cents per kWh; check your utility):</b> a covered tub about
  $40-90 a month in winter and less in summer; a sauna session about $2-3; a plunge chiller about $20-50 a month in
  summer; the warm floor about 50 cents for two hours.</p>
</div></section>'''


def compare(schemes):
    rows = [
        ('A', 'Spring Glass House', '432 sq ft, glass room', 'In-ground tiled, 9.5 x 7 ft', 'Cabin, 7 x 7 ft', 'Inside: wash + scrub. Outside: plunge, warm platform', 'Enclosed; warm in winter', 'Premium'),
        ('B', 'Jeongja Bathhouse', '384 sq ft, open south', 'In-ground tiled, 6.5 x 6.5 ft', 'Cabin, 7 x 7 ft', 'Wash, soak and rest in three bays; sauna and plunge outside', 'Half open, very Korean', 'Upper balanced to premium'),
        ('C', 'Octagon Garden Gazebo', '340 sq ft, open east + south', 'In-ground round, 8 ft', 'Barrel, 6 ft', 'Outside: wash, plunge, warm platform', 'Open-air garden', 'Upper balanced'),
        ('D', 'Walled Garden Courtyard', 'About 100 sq ft of roofs plus a pergola, in a 1,600 sq ft walled garden', 'In-ground round, 6.5 ft', 'Cabin + clay dome', 'One per corner', 'Private, most plants', 'Premium'),
        ('E', 'Starter Kit', '144 sq ft kit', 'Plug-and-play, recessed, 7 x 7 ft', 'Barrel, 6 ft', 'Plunge and post shower', 'Lowest cost', 'Lean'),
    ]
    trs = ''.join('<tr>' + ''.join(f'<td>{c}</td>' for c in r) + '</tr>' for r in rows)
    build = [
        ('E', 'Yes, in a few weekends once the pit is dug and lined.'),
        ('C', 'Mostly, from a kit; hire the pool builder for the tub.'),
        ('B', 'Hire a carpenter for the curved roof and a pool builder for the tub.'),
        ('A', 'Hire a contractor, a glazier and a pool builder.'),
        ('D', 'Hire a mason for the walls and a pool builder for the tub.'),
    ]
    lis = ''.join(f'<li><b>{k}:</b> {t}</li>' for k, t in build)
    return f'''
<section class="wrap" id="compare"><div class="wide stack">
  <p class="eyebrow">Side by side</p><h2>Compare the five</h2>
  <div class="scroll"><table>
    <thead><tr><th></th><th>Plan</th><th>Under roof</th><th>Hot tub</th><th>Sauna</th><th>Korean extras</th><th>Feel</th><th>Budget tier</th></tr></thead>
    <tbody>{trs}</tbody></table></div>
  <div class="col stack">
    <h3>Which one?</h3>
    <p>To start soon and for the least money: E, then grow toward C. For the full Korean bath in order: B. For The
    Spring's glass room and comfort on cold nights: A. If plants and privacy matter most: D.</p>
    <p><b>Decide these first:</b> open or enclosed; how the in-ground tub is built (tiled concrete, fiberglass shell,
    or a recessed acrylic tub); barrel or cabin sauna; electric or wood-fired heat; how many people will use it at once.</p>
    <p><b>Can we build it ourselves?</b> In every plan, hire the electrician, the engineer for the footings, and a
    licensed builder for the in-ground tub.</p>
    <ul>{lis}</ul>
    <div class="note"><p><b>A way to phase it.</b> Because the tub is built into the ground, pick its final spot from
    the start. Build the tub where it will stay, roof it simply at first (E), and add the bigger structure of A, B, C
    or D around it later. The barrel sauna fits C, and the plunge and shower move into any plan. Start only once the
    County confirms the trailer permit counts as the main use, or issues a Temporary Use Permit.</p></div>
  </div>
</div></section>'''


def plants():
    inside = [
        ('Windmill palm', 'In the ground at a back corner, out of the west wind', 'Hardiest palm here (zones 7-11). Wind shreds the leaves.'),
        ('Mediterranean fan palm', 'At the bright edge or entry', 'Clumping, 6-15 ft. Gritty soil; overwatering rots it.'),
        ('Clumping bamboo (Bambusa multiplex)', 'Lined planters along the west and south-west', 'A living screen. Never golden bamboo, which runs.'),
        ('Star jasmine', 'Trained up posts and lattice', 'Fragrant white flowers in late spring; drought tolerant once settled.'),
        ('Holly fern', 'Deep shade by benches or the warm platform', 'The fern most likely to cope with dry desert air. Needs drip.'),
        ('Bird of paradise', 'In large pots', 'Bring under cover below about 32F (zone 10 plant; the lot is zone 9a).'),
        ('Pothos', 'Hanging pots under the roof', 'Frost-tender. Winter indoors.'),
    ]
    outside = [
        ('Apricot mallow', 'Peach flowers, very low water'), ('Firecracker and desert penstemon', 'Coral-red and pink along paths'),
        ('Chuparosa, California fuchsia', 'Coral-red, near the sauna; hummingbirds'), ('Fairy duster', 'Blush pink, foreground beds'),
        ('Ocotillo', 'A sculpture against white walls, red tips'), ('Desert willow', 'West or south-west of the bathhouse for summer shade'),
        ('California fan palm', 'The native palm; a grove marks the spa, away from roofs and power lines'), ('Coral yucca', 'Coral flower spikes in gravel beds'),
        ('Pink or bush muhly', 'A pink haze in fall'), ('Smoketree, beavertail cactus', 'Silver and magenta, good in black-and-white photos'),
    ]
    t1 = ''.join(f'<tr><td>{a}</td><td>{b}</td><td>{c}</td></tr>' for a, b, c in inside)
    t2 = ''.join(f'<tr><td>{a}</td><td>{b}</td></tr>' for a, b in outside)
    return f'''
<section class="wrap" id="plants" style="background:var(--wash)"><div class="col stack">
  <p class="eyebrow">Planting</p><h2>Plants inside, desert plants outside</h2>
  <p>ZIP 92284 is USDA zone 9a (a higher parcel can run colder): winter lows of 20-25F, with a record 17F and 115F at the Joshua Tree station. Inside a
  partly enclosed bathhouse it stays warmer and more humid, but plants still need drip irrigation and a winter plan.
  Keep plants out of the splash zone; tub chemicals burn leaves.</p>
  <h3>Under the roof</h3>
  <div class="scroll"><table><thead><tr><th>Plant</th><th>Where</th><th>Care</th></tr></thead><tbody>{t1}</tbody></table></div>
  <h3>Around the bathhouse</h3>
  <p>Mostly Mojave natives in coral, peach and pink, sold by the Mojave Desert Land Trust for about $12-55 each.
  Coral yucca and pink muhly are desert-tough nursery plants, not natives.</p>
  <div class="scroll"><table><thead><tr><th>Plant</th><th>Why</th></tr></thead><tbody>{t2}</tbody></table></div>
  <p class="small muted">Large existing natives (Joshua trees, yuccas, creosote rings 10 ft or wider, mesquite, smoke trees) need a County removal permit, so plant around them.</p>
</div></section>'''


def inground():
    rows = [
        ('Custom concrete (shotcrete or gunite), plaster or tile', 'A, B, C, D', '$30,000-80,000', 'The most authentic: any shape, a tiled interior, a flush stone rim. A desert builder quotes $30k-50k for a standalone spa; a fully tiled 9.5 x 7 ft tub on a remote lot runs higher.'),
        ('Formed concrete or block walls, waterproofed and tiled', 'A, B', '$22,000-55,000', 'Suits the square tubs in A and B; needs a structural engineer.'),
        ('Prefab fiberglass spa shell', 'C, D, maybe B', '$15,000-45,000', 'San Juan makes an 8 ft round (Isle, about 600 gal) that fits C, a 6 ft 10 in octagon (Haven) for D, and 6 ft 11 in x 7 ft 1 in squares (Lido, Scottsdale) for B. Ask the dealer in writing whether a standalone install is approved.'),
        ('Acrylic spa recessed into a drained concrete pit', 'E', '$12,000-40,000', 'The budget way. Only with the maker\'s written approval: Bullfrog and Master Spas describe full recessing; Master Spas asks for about 3 ft of service access around it (or removable deck panels) and a floor drain.'),
    ]
    trs = ''.join(f'<tr><td>{a}</td><td>{b}</td><td class="num">{c}</td><td>{d}</td></tr>' for a, b, c, d in rows)
    return f'''
<section class="wrap" id="inground"><div class="wide stack">
  <p class="eyebrow">The tub</p><h2>Building the tub into the ground</h2>
  <div class="scroll"><table><thead><tr><th>How</th><th>Plans</th><th class="num">Installed, estimate</th><th>Notes</th></tr></thead><tbody>{trs}</tbody></table></div>
  <div class="col stack">
    <p class="small muted">Every cost here is a planning estimate, not a quote; get two or three local bids. Ranges
    include digging, the shell, plumbing, a heat pump, bonding and a cover, but not the roof structure, barrier,
    long trenches or soils engineering. Caliche (hardpan) under the sand can add $1,000-4,000 to the dig.</p>
    <p><b>Heating is a heat pump now.</b> Since January 1, 2026, California's energy code requires the main heater
    for a new permanent spa to be a heat pump (sized to the code's method) or solar. An electric or propane heater
    can only be a backup. A listed portable electric spa (Scheme E) is exempt; ask plan check whether a recessed one
    still counts. Most heat pumps stop heating below about 40-50F, so on 17-25F nights the tub relies on a tight
    cover, daytime recovery and a backup heater. The cover is required anyway, and standing pilot lights are banned.</p>
    <p><b>A tub this deep counts as a pool.</b> The County treats any water over 18 in deep, hot tubs included, as a
    pool. That means a 60-in barrier (gates single, no wider than 4 ft, opening outward, self-closing, with the latch
    60 in or higher), or a locking safety cover plus one more feature: a door exit alarm, a high door latch, or an
    in-water alarm. State law exempts spas with locking ASTM F1346 covers, but the County's handout doesn't mention
    that, so ask in writing and budget for a cover plus one alarm. A cover only counts if its label says F1346-23
    (many say F1346-91). Single covers come only up to 96 in, so Scheme A's 9.5 x 7 ft tub needs a two-piece or
    automatic cover. The cold plunge is a pool too if its water is over 18 in deep.</p>
    <p><b>Bonding.</b> Every in-ground tub needs its steel and the deck within 3 ft bonded together under the paving,
    and a recessed portable spa loses the exemption a free-standing one has, so its deck needs bonding too. Design
    the grid before the slab is poured.</p>
    <p><b>Water volumes</b> (rough): A 1,300-1,700 gal, B 850-1,100, C 1,000-1,300, D 650-870, E 350-450.</p>
  </div>
</div></section>'''


def rules():
    items = [
        '<b>Check the jurisdiction first.</b> Everything here assumes unincorporated San Bernardino County. Confirm by parcel number; inside the Town of Yucca Valley the Town\'s rules apply instead, and they weren\'t checked here.',
        '<b>Joshua trees.</b> Any digging, grading, slab, trench or path within 50 ft of a western Joshua tree (a neighbor\'s counts too) needs approval from California Fish and Wildlife first. Treat 50 ft as the trigger, not a safe distance. If a permit is needed, the in-lieu fee is $156.50-2,609 per tree depending on its height and the fee area. Map the trees before siting anything, including the power and water trenches.',
        '<b>When you can build it.</b> An accessory structure needs a legally established main use; until then it can only be built under a Temporary Use Permit. Nobody has confirmed whether the trailer permit counts, so ask County Building and Safety before buying anything. Starting work before a permit is issued adds a fee equal to the permit.',
        '<b>Permits.</b> The spa permit is $335 plus a $57 intake fee, and $195 more for plan review if it isn\'t a standard plan (County fee schedule effective July 1, 2026); a large site-built tub may be billed as a pool instead ($704-1,000). The gazebo or bathhouse needs its own building permit (any patio cover, solid or lattice, or anything over 120 sq ft), and all electrical work needs a permit. A grading permit is needed only if all grading on the site together tops 100 cubic yards.',
        '<b>Setbacks and coverage</b> (Rural Living zoning): only the tub itself may sit in the rear setback (at least 5 ft from the line); any roof over it must meet the full 25 ft front and 15 ft side and rear setbacks (sides on lots wider than 75 ft). Walls inside a side or rear setback are capped at 6 ft. No more than 20% of the lot may be under structures and paving combined.',
        '<b>Septic and well.</b> Keep roofed structures at least 5 ft from the septic tank and 8 ft from the leach field, and the septic system 100 ft from a well. Never drain the tub into the septic system; drain it, once the chlorine has faded, onto an area at least 10 ft from the septic tank and leach field. Ask County Environmental Health before the first drain.',
        '<b>Wiring and lights.</b> A hardwired tub needs its disconnect within sight of the tub and at least 5 ft away; Hot Spring\'s 240 V tubs need a 50 A GFCI subpanel no more than 50 ft away. Outdoors (B to E), a line-voltage light within 5 ft of the water must be 12 ft above it; under a low gazebo roof, use listed low-voltage spa lights or keep fixtures farther away. Indoors (A): 12 ft without GFCI, 7.5 ft with GFCI, and lower only for listed enclosed types with GFCI. A 6 kW sauna heater needs its own 30 A circuit. These follow the 2023 National Electrical Code; confirm with your electrician.',
        '<b>Warm floors near the tub.</b> The electrical code restricts electric heating cables in or under the deck within 20 ft of a pool, so heat the rest platforms with hot water (hydronic tubing) rather than electric mats.',
        '<b>Wind.</b> The County assumes open, flat land with nothing to block the wind ("Exposure C" in the building code). Spring wind advisories bring gusts of 40-50 mph, so anchor any gazebo to engineered footings and strap the tub cover.',
        '<b>Fire.</b> The parcel\'s fire hazard zone hasn\'t been checked. If it is mapped, ember-resistant building rules may apply. Prefer noncombustible roofing, keep 5 ft of gravel around structures, use electric heat, and never light a wood-fired stove on windy or red-flag days.',
    ]
    return f'''
<section class="wrap" id="rules"><div class="col stack">
  <p class="eyebrow">Before you build</p><h2>The rules that shape it</h2>
  <ul class="stack" style="padding-left:1.1em">{''.join(f'<li>{i}</li>' for i in items)}</ul>
</div></section>'''


def budget():
    tiers = [
        ('Lean (Scheme E)', 'about $24,000 - $64,000', ['Acrylic spa recessed into a drained concrete pit with service access, wiring and bonding (estimate), $12,000-40,000', '12 x 12 to 12 x 16 ft cedar gazebo kit, $2,599-4,340', '2-person cedar barrel sauna (Almost Heaven Salem), $4,485', 'Stock-tank plunge (no chiller) or Ice Barrel, $300-1,750', 'Outdoor shower and bench, warm platform (estimates), $1,600-4,500', 'Sauna circuit, permits, plants, a safety cover and one alarm (estimates), $3,000-9,000']),
        ('Balanced (Scheme C; B with a simpler roof)', 'about $53,000 - $123,000', ['Fiberglass in-ground shell with heat pump, bonding and cover (estimate), $15,000-45,000', 'Timber-frame or octagon gazebo kit with coral screens and a west windbreak, $9,100-14,200', '2-4 person cedar barrel sauna, $5,184 (installation from $1,400 more) or a 6-person barrel at $7,799', 'Cold plunge with a chiller, $3,950-6,790', 'Tiled warm platform with hot-water floor heat, and a wash station (estimates), $4,500-11,000', 'Slab, spa subpanel, permits, wind engineering, plants, lighting (estimates), $15,000-38,000']),
        ('Premium (Schemes A and D; B as drawn)', 'about $128,000 - $316,000', ['Custom concrete in-ground tub, tiled (estimate), $30,000-80,000', 'Custom pavilion, pool house or walled courtyard with lattice (estimate), $25,000-70,000; D\'s walls can add more', 'Cabin or cube sauna with a Wi-Fi heater, $10,722-14,600', 'Turnkey cold plunge, $7,990-8,999', 'Clay or stone warm platform and tiled wet room (estimates), $16,000-40,000', 'Site work, 200 A service, design and permits, landscape, lighting (estimates), $38,000-102,000']),
    ]
    cards = ''.join(f'''<div><h4>{t}</h4><p class="figure">{rng}</p>{"<ul>" + "".join(f"<li>{x}</li>" for x in items) + "</ul>"}</div>''' for t, rng, items in tiers)
    return f'''
<section class="wrap" id="budget" style="background:var(--wash)"><div class="wide stack-lg">
  <div class="col stack"><p class="eyebrow">Money</p><h2>Three budget tiers</h2>
  <p>Totals add up list prices for the equipment and planning estimates for the in-ground tub, site work and
  labor. They are not quotes: get two or three local bids before relying on any of them. Each tier prices a
  typical version; a plan built exactly as drawn can land higher.</p></div>
  <div class="facts">{cards}</div>
</div></section>'''


def products():
    rows = [
        ('In-ground tub', 'San Juan fiberglass spa shells', 'ask a dealer', 'Isle 8 ft round (about 600 gal) for C; Haven 6 ft 10 in octagon for D; Lido or Scottsdale 6 ft 11 in x 7 ft 1 in for B', 'https://sanjuanpools.com/spas/'),
        ('In-ground tub', 'Recessed acrylic spa, e.g. Jacuzzi J-335 (7 x 7 ft)', '$13,895', 'One retailer\'s sale price (list $15,441). Recess only with the maker\'s written approval', 'https://galaxyhomerecreation.com/product/jacuzzi-j-335-hot-tub/'),
        ('In-ground tub', 'Hot Spring Hot Spot Relay (7 x 7 ft)', '$12,999', '340 gal, 240 V / 50 A. Hot Spring\'s documents don\'t address recessing, so ask the dealer', 'https://www.hotspring.com/shop/hot-spot/relay'),
        ('Gazebo', 'Yardistry 16 x 16 Timber Frame Gazebo', '$7,100', '12 ft 2.5 in clear between posts; fits a 6 x 6 or 7 x 7 tub', 'https://yardistrystructures.com/products/16-x-16-timber-frame-gazebo'),
        ('Gazebo', 'Yardistry 12 x 16 Meridian (cedar)', '$3,360', 'Cedar kit; the extra length leaves room to service a recessed tub', 'https://yardistrystructures.com/products/12-x-16-meridian-gazebo'),
        ('Gazebo', 'Forever Redwood pavilion kits', 'from $6,000', 'Custom-sized redwood kits, drawings approved before building', 'https://www.foreverredwood.com/'),
        ('Sauna', 'Almost Heaven Salem barrel (2 person)', '$4,485', 'Red cedar; 6 kW heater on 240 V / 30 A', 'https://www.almostheaven.com/products/salem-2-person-barrel-sauna'),
        ('Sauna', 'Almost Heaven Watoga barrel (2-4 person)', '$5,184', '78 x 59 in; installation from $1,400. The Quick Ship kit with a smart heater is $6,183', 'https://www.almostheaven.com/products/watoga-2-4-person-barrel-sauna'),
        ('Sauna', 'Almost Heaven cube and cabin saunas', 'from about $8,400', 'Blackwater 4-person $11,268 on sale; a cabin bench is long enough to lie on. Ask for cedar', 'https://www.almostheaven.com/collections/cabin-saunas'),
        ('Cold', 'Ice Barrel 500', '$1,750', '94 gal; chiller sold separately', 'https://www.icebarrel.com/products/ice-barrel-500'),
        ('Cold', 'Penguin outdoor chiller', '$1,500-2,200', 'Adds summer cold to a barrel or stock tank; drain it on freezing nights', 'https://penguinchillers.com/collections/cold-therapy'),
        ('Cold', 'Plunge All-In', '$7,990', '105 gal, down to 37F, 120 V', 'https://www.plunge.com/products/plunge-all-in'),
    ]
    trs = ''.join(f'<tr><td>{a}</td><td><a href="{u}" target="_blank" rel="noopener">{b}</a></td><td class="num">{c}</td><td>{d}</td></tr>' for a, b, c, d, u in rows)
    return f'''
<section class="wrap" id="products"><div class="wide stack">
  <p class="eyebrow">Shopping list</p><h2>Products worth a look</h2>
  <p class="col">Prices listed on the makers' sites on October 24, 2026, before tax, delivery and installation. Yardistry and Plunge were showing sale prices; Penguin prices are "from" prices.</p>
  <div class="scroll"><table><thead><tr><th>Part</th><th>Product</th><th class="num">Price</th><th>Notes</th></tr></thead><tbody>{trs}</tbody></table></div>
</div></section>'''


def actions():
    items = [
        ('@together', 'Pick the two plans you like best, and decide whether to start with the Starter Kit while you live in the trailer.'),
        ('@land', 'Walk the lot and pin every Joshua tree, yucca and big creosote ring; draw 50-ft circles and choose the bathhouse spot outside them.'),
        ('@phone', 'Call County Building and Safety, Joshua Tree office (open Wednesdays, 760-995-8140): does the trailer permit count as the main use for a gazebo, spa and sauna, or do we need a Temporary Use Permit? Will a locking ASTM F1346 cover satisfy the barrier rules on its own?'),
        ('@computer', 'Run the ASCE 7 Hazard Tool for the lot\'s design wind speed, so the gazebo footings can be engineered for it.'),
        ('@phone', 'Ask an electrician for a load calculation and a quote on a spa subpanel: 50 A tub, 30-40 A sauna, 120 V circuits.'),
        ('@errand', 'Visit a Hot Spring dealer; sit in a TX and a Relay; confirm the cover is labeled ASTM F1346.'),
        ('@errand', 'Spend a weekday afternoon at The Spring and measure the pool house: post spacing, wall heights, how the slats vent.'),
        ('@computer', 'Check the parcel\'s fire hazard zone on the CAL FIRE map before choosing roof and wall materials.'),
        ('@errand', 'Buy coral and peach natives at the Mojave Desert Land Trust plant sale (Saturday, Oct 24, 2026, 9am-2pm, 60124 Twentynine Palms Hwy, Joshua Tree) or at its next sale; fall is the best planting window.'),
    ]
    lis = ''.join(f'<li><input type="checkbox" id="act{i}" aria-label="Done"><label for="act{i}"><span class="ctx">{c}</span>{t}</label></li>' for i, (c, t) in enumerate(items))
    return f'''
<section class="wrap" id="next" style="background:var(--wash)"><div class="col stack">
  <p class="eyebrow">Next actions</p><h2>What to do next</h2>
  <p class="small muted">Ticks are saved in this browser only.</p>
  <ul class="actions">{lis}</ul>
</div></section>'''


def sources():
    src = [
        ('The Spring: day spa and pools', 'https://the-spring.com/spa/day-spa/'), ('The Spring: our story', 'https://the-spring.com/about/our-story/'),
        ('The Spring gallery', 'https://the-spring.com/gallery/'), ('ResortPass: The Spring', 'https://www.resortpass.com/hotels/the-spring-resort-and-spa'),
        ('Wi Spa: the Korean spa experience', 'https://wispausa.com/the-wi-spa-experience/'), ('CPSC: hot tub temperatures', 'https://www.cpsc.gov/Newsroom/News-Releases/1980/CPSC-Warns-Of-Hot-Tub-Temperatures'),
        ('Harvard Health: saunas and your health', 'https://www.health.harvard.edu/staying-healthy/saunas-and-your-health'), ('Korea Herald: jjimjilbang floor temperatures', 'https://www.koreaherald.com/article/1864232'),
        ('County: Western Joshua Tree quick reference (Feb 2026)', 'https://lus.sbcounty.gov/wp-content/uploads/sites/48/WJT_Quick-Reference-Guide_REV-2-25-2026.pdf'),
        ('CDFW: Western Joshua tree FAQ', 'https://wildlife.ca.gov/Conservation/Environmental-Review/WJT/FAQ'),
        ('County Building and Safety: permits', 'https://lus.sbcounty.gov/building-safety-home/permits/'),
        ('County Development Code', 'https://lus.sbcounty.gov/wp-content/uploads/sites/48/DevelopmentCode/DCWebsite.pdf'),
        ('Hot Spring spa specs and wiring', 'https://www.hotspring.com/shop/hot-spot/relay'), ('Almost Heaven saunas', 'https://www.almostheaven.com/collections/barrel-saunas'),
        ('Harvia KIP heater specs', 'https://almostheaven.com/products/kip-dials'), ('Yardistry gazebos', 'https://yardistrystructures.com/'),
        ('Mojave Desert Land Trust 2026 plant sale list', 'https://static1.squarespace.com/static/61815979dfa7a7572c721a67/t/6ad0e905a0b45d7fd3978168/1792076037349/2026+plant+sale+inventory.pdf'),
        ('ASCE 7 Hazard Tool', 'https://asce7hazardtool.online'),
        ('California Energy Commission: 2025 pool and spa rules (heat pumps)', 'https://www.energy.ca.gov/2025-single-family-pools-and-spas-faqs'),
        ('County IB-0007: pool, spa and hot tub barriers', 'https://lus.sbcounty.gov/wp-content/uploads/sites/48/IB-0007-Swimming-Pool-Spa-and-Hot-Tub-Barrier-Requirements.pdf'),
        ('County pool and spa permits', 'https://wp.sbcounty.gov/ezop/permits/pool-and-spa/'),
        ('County fee ordinance effective July 1, 2026', 'https://lus.sbcounty.gov/wp-content/uploads/sites/48/Ordinance-No.-4509-af-16.0204-LUS-BNS-2026-27-04-07-26-Board-Mtg.pdf'),
        ('San Juan Pools spa shells', 'https://sanjuanpools.com/spas/'),
        ('Bullfrog Spas: in-ground hot tubs', 'https://www.bullfrogspas.com/in-ground-hot-tubs/'),
        ('Master Spas: recessed installs', 'https://masterspas.com/blog/?p=3030'),
    ]
    lis = ''.join(f'<li>{t}: <a href="{u}" target="_blank" rel="noopener">{u}</a></li>' for t, u in src)
    return f'''
<section class="wrap" id="sources"><div class="col stack sources"><p class="eyebrow">Sources</p><ol>{lis}</ol>
<p>Research and renders: October 2026. The 3D models, research files and build scripts live in the gazebo-spa folder of the repository.</p></div></section>
<footer class="wrap"><div class="col small muted">Style direction from kwonyin.global: blush, peach, coral and black, coral lattice, high-key black-and-white desert light.</div></footer>'''
