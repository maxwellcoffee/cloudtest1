"""Text sections of the gazebo bathhouse page (numbers come from data/research and the fact-check)."""


def intro():
    return '''
<header class="wrap hero">
  <div class="wide hero-grid">
    <div class="hero-text">
      <p class="eyebrow">Yucca Valley lot &middot; bathhouse plans &middot; October 2026</p>
      <h1>The Garden Bathhouse</h1>
      <p class="lede">Five plans for a Korean-style bathhouse on the land: one hot tub under a roof with plants inside,
      a cedar sauna a few steps away, then cold water and a warm floor to rest on. The starting point is the enclosed
      pool house at The Spring in Desert Hot Springs.</p>
      <p class="muted">Every image is a Blender render of the real lot model: same slope, same Joshua trees, same
      mountains to the north. Prices are 2025-2026 list prices or labeled estimates.</p>
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
  (guides say about 101F) and the outdoor soaking pool at 104F. The hotel opened in 1957 as The Moors and is
  adults-only. Reconstructed from the resort's own photos, the pool house is:</p>
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
    <p>A Korean bathhouse (mogyoktang) and its rest halls (jjimjilbang) follow one order: clean, hot, cold, rest.
    For two people at home a full round takes about 2 to 2.5 hours. Steps 3 and 4 repeat two or three times.</p>
  </div>
  <ol class="round">
    <li><span class="t">Wash</span><span>Seated shower on a low stool, about 10 minutes. Hair tied up. Nobody gets in the tub unwashed.</span></li>
    <li><span class="t">Soak</span><span>10 to 15 minutes at 100-104F, heart above the water. In summer run it as a warm tub at 97-100F.</span></li>
    <li><span class="t">Sauna</span><span>8 to 12 minutes at 176-194F. About 30 minutes of high heat in total.</span></li>
    <li><span class="t">Cold</span><span>30 seconds to 2 minutes at 57-64F, head out, feet first, never alone. In winter the water is cold enough on its own.</span></li>
    <li><span class="t">Rest</span><span>10 to 15 minutes lying on the warm floor (about 97F) with a glass of water.</span></li>
  </ol>
  <div class="col stack">
    {wave}
    <p>Once a week, after a soak, scrub each other with an Italy towel (seshin), then rinse. Finish with cold sikhye
    (sweet rice drink) and baked eggs on the warm floor.</p>
    <div class="note"><p><b>Safety.</b> Korean bathhouses run their hot tubs at 106-109F; at home, cap the tub at
    104F (the U.S. Consumer Product Safety Commission limit) and at 100F or less for anyone pregnant. Drink water
    after every round and skip alcohol before and between rounds. Anyone with heart conditions should ask a doctor
    about sauna and cold plunges first. Keep the warm floor at or below about 104F for long lying.</p></div>
  </div>
</div></section>'''


def compare(schemes):
    rows = [
        ('A', 'Spring Glass House', '432 sq ft, glass room', 'In-ground tiled, 9.5 x 7 ft', 'Cabin, 7 x 7 ft', 'Inside: wash + scrub. Outside: plunge, warm platform', 'Enclosed, warm in winter', 'Premium'),
        ('B', 'Jeongja Bathhouse', '384 sq ft, open south', 'Sunken tiled, 6.5 x 6.5 ft', 'Cabin, 7 x 7 ft', 'All inside in three bays; ondol floor, sikhye station', 'Half open, very Korean', 'Balanced to premium'),
        ('C', 'Octagon Garden Gazebo', '340 sq ft, open east + south', 'Round raised, 8 ft', 'Barrel, 6 ft', 'Outside: wash, plunge, warm platform', 'Open-air garden', 'Balanced'),
        ('D', 'Walled Garden Courtyard', '1,600 sq ft walled garden', 'Cedar round, 6.5 ft', 'Cabin + clay dome', 'One per corner', 'Private, most plants', 'Premium'),
        ('E', 'Starter Kit', '144 sq ft kit', 'Plug-and-play, 7 x 7 ft', 'Barrel, 6 ft', 'Plunge and post shower', 'Quick, movable', 'Lean'),
    ]
    trs = ''.join('<tr>' + ''.join(f'<td>{c}</td>' for c in r) + '</tr>' for r in rows)
    return f'''
<section class="wrap" id="compare"><div class="wide stack">
  <p class="eyebrow">Side by side</p><h2>Compare the five</h2>
  <div class="scroll"><table>
    <thead><tr><th></th><th>Plan</th><th>Under roof</th><th>Hot tub</th><th>Sauna</th><th>Korean extras</th><th>Feel</th><th>Budget tier</th></tr></thead>
    <tbody>{trs}</tbody></table></div>
  <div class="col stack"><div class="note"><p><b>A way to phase it.</b> Start with E once the house permit is issued
  (or with a Temporary Use Permit), while you live in the trailer. When the house is finished, move the tub, sauna
  and plunge into A, B, C or D. Nothing in E is wasted.</p></div></div>
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
  <p class="eyebrow">Planting</p><h2>Plants inside, natives outside</h2>
  <p>The lot is USDA zone 9a: winter lows of 20-25F, with a record 17F and 115F at the Joshua Tree station. Inside a
  partly enclosed bathhouse it stays warmer and more humid, but plants still need drip irrigation and a winter plan.
  Keep plants out of the splash zone; tub chemicals burn leaves.</p>
  <h3>Under the roof</h3>
  <div class="scroll"><table><thead><tr><th>Plant</th><th>Where</th><th>Care</th></tr></thead><tbody>{t1}</tbody></table></div>
  <h3>Around the bathhouse</h3>
  <p>Mojave natives in coral, peach and pink. The Mojave Desert Land Trust sells them for about $12-55 each.</p>
  <div class="scroll"><table><thead><tr><th>Plant</th><th>Why</th></tr></thead><tbody>{t2}</tbody></table></div>
  <p class="small muted">Large existing natives (Joshua trees, yuccas, creosote rings 10 ft or wider, mesquite, smoke trees) need a County removal permit, so plant around them.</p>
</div></section>'''


def rules():
    items = [
        '<b>Joshua trees.</b> No digging, grading, slabs, trenches or paths within 50 ft of a western Joshua tree (including a neighbor\'s) without approval from California Fish and Wildlife. Map the trees before siting anything.',
        '<b>When you can build it.</b> In the County, an accessory structure needs a legally established main use. Before the house is finished, a gazebo, spa and sauna may need a Temporary Use Permit. Ask County Building and Safety whether the trailer permit counts.',
        '<b>Building permits.</b> Needed for any structure over 120 sq ft, any patio cover (solid or lattice), any pool or spa, and all electrical work. Setbacks (25 ft front, 15 ft sides and rear in Rural Living) apply even when no permit is needed.',
        '<b>Drowning prevention.</b> A new spa needs safety features under the California Pool Safety Act. A locking safety cover labeled ASTM F1346 is the usual one; confirm with the inspector whether it is enough on its own.',
        '<b>Wiring.</b> A 240 V hot tub needs a 50 A GFCI disconnect within sight of the tub, at least 5 ft away. No light fixture within 5 ft of the water unless it is 12 ft or more above it. A 6 kW sauna heater needs its own 30 A circuit.',
        '<b>Wind.</b> The County designs for open terrain (Exposure C). Spring gusts reach 40-50 mph, so anchor any gazebo to engineered footings and strap the tub cover.',
        '<b>Water.</b> A 7 x 7 tub holds about 340 gallons and is drained three or four times a year; an uncovered tub can lose over 2,000 gallons a year to evaporation. Keep it covered.',
    ]
    return f'''
<section class="wrap" id="rules"><div class="col stack">
  <p class="eyebrow">Before you build</p><h2>The rules that shape it</h2>
  <ul class="stack" style="padding-left:1.1em">{''.join(f'<li>{i}</li>' for i in items)}</ul>
</div></section>'''


def budget():
    tiers = [
        ('Lean', '$20,600 - $42,200', ['Hot tub: Hot Spring Freeflow Mini or Excursion, $5,499-8,999', 'Gazebo kit 12 x 14 to 12 x 16 ft, $2,599-4,340', '2-person barrel sauna, $4,485-4,899', 'Stock-tank plunge (no chiller) or Ice Barrel, $300-1,750', 'Outdoor shower and bench, warm platform with a heat mat (estimates), $1,600-4,500', 'Pads, wiring, permits, plants (estimates), $6,100-16,200']),
        ('Balanced', '$47,700 - $90,800', ['Hot tub: Hot Spring TX or Relay, $9,999-12,999', '16 x 16 ft timber-frame gazebo, coral screens and a west windbreak, $9,100-14,200', '2-4 person barrel sauna, installed, $5,184-7,799', 'Cold plunge with a chiller, $3,950-6,790', 'Tiled warm platform and wash station (estimates), $4,500-11,000', 'Slab, 125 A spa subpanel, permits, wind engineering, plants, lighting (estimates), $15,000-38,000']),
        ('Premium', '$109,700 - $274,400', ['Cedar tub or premium spa, $11,969-38,843 (a custom in-ground tub costs more)', 'Custom redwood pavilion with glass or polycarbonate walls and lattice (estimate), $25,000-70,000', 'Cabin or cube sauna with a Wi-Fi heater, $10,722-14,600', 'Turnkey cold plunge, $7,990-8,999', 'Clay or stone warm platform and tiled wet room (estimates), $16,000-40,000', 'Site work, 200 A service, design and permits, landscape, lighting (estimates), $38,000-102,000']),
    ]
    cards = ''.join(f'''<div><h4>{t}</h4><p class="figure">{rng}</p>{"<ul>" + "".join(f"<li>{x}</li>" for x in items) + "</ul>"}</div>''' for t, rng, items in tiers)
    return f'''
<section class="wrap" id="budget" style="background:var(--wash)"><div class="wide stack-lg">
  <div class="col stack"><p class="eyebrow">Money</p><h2>Three budget tiers</h2>
  <p>Totals add up list prices for the equipment and estimates for site work and labor. Get two or three local
  quotes before treating any estimate as real. Scheme E fits the lean tier, C the balanced tier, B the balanced
  to premium tier, and A and D the premium tier.</p></div>
  <div class="facts">{cards}</div>
</div></section>'''


def products():
    rows = [
        ('Gazebo', 'Yardistry 16 x 16 Timber Frame Gazebo', '$7,100', '12 ft 2.5 in clear between posts; fits a 6 x 6 or 7 x 7 tub', 'https://yardistrystructures.com/products/16-x-16-timber-frame-gazebo'),
        ('Gazebo', 'Yardistry 12 x 16 Meridian (cedar)', '$3,360', 'Smaller cedar kit for the starter plan', 'https://yardistrystructures.com/products/12-x-16-meridian-gazebo'),
        ('Gazebo', 'Forever Redwood pavilion kits', 'from $6,000', 'Custom-sized redwood kits, drawings approved before building', 'https://www.foreverredwood.com/'),
        ('Hot tub', 'Hot Spring Hot Spot TX', '$9,999', '2-seat lounge, 6 x 6 ft, 190 gal; 115 V or 240 V', 'https://www.hotspring.com/shop/hot-spot/tx'),
        ('Hot tub', 'Hot Spring Hot Spot Relay', '$12,999', '6 seats, 7 x 7 ft, 340 gal, 4,715 lb filled; 240 V / 50 A', 'https://www.hotspring.com/shop/hot-spot/relay'),
        ('Hot tub', 'Hot Spring Freeflow Mini', '$5,499', '2 seats, 6 x 4.4 ft, 125 gal; plug-in or 240 V', 'https://www.hotspring.com/shop/freeflow/mini'),
        ('Hot tub', 'Almost Heaven Sindri (wood-fired)', '$10,621', 'No electricity needed; mind fire weather', 'https://almostheaven.com/products/sindri'),
        ('Sauna', 'Almost Heaven Salem barrel (2 person)', '$4,485', '6 kW heater on 240 V / 30 A', 'https://www.almostheaven.com/products/salem-2-person-barrel-sauna'),
        ('Sauna', 'Almost Heaven Watoga barrel (2-4 person)', '$5,184', '78 x 59 in; installation from $1,400', 'https://www.almostheaven.com/products/watoga-2-4-person-barrel-sauna'),
        ('Sauna', 'Redwood Outdoors Duo (2 person cabin)', '$4,899', 'Small cube; 6 or 8 kW Harvia', 'https://www.redwoodoutdoors.com/products/duo-outdoor-sauna-2-person'),
        ('Cold', 'Ice Barrel 500', '$1,750', '94 gal; chiller sold separately', 'https://www.icebarrel.com/products/ice-barrel-500'),
        ('Cold', 'Penguin outdoor chiller', '$1,500-2,200', 'Adds summer cold to a barrel or stock tank', 'https://penguinchillers.com/collections/cold-therapy'),
        ('Cold', 'Plunge All-In', '$7,990', '105 gal, down to 37F, 120 V', 'https://www.plunge.com/products/plunge-all-in'),
        ('Warm floor', 'WarmlyYours TempZone mat', '$5-15 per sq ft', '15 W per sq ft under tile; a 6 x 8 ft platform is about 720 W', 'https://www.warmlyyours.com/en-US/floor-heating'),
    ]
    trs = ''.join(f'<tr><td>{a}</td><td><a href="{u}" target="_blank" rel="noopener">{b}</a></td><td class="num">{c}</td><td>{d}</td></tr>' for a, b, c, d, u in rows)
    return f'''
<section class="wrap" id="products"><div class="wide stack">
  <p class="eyebrow">Shopping list</p><h2>Products worth a look</h2>
  <p class="col">List prices checked in October 2026, before tax, delivery and installation.</p>
  <div class="scroll"><table><thead><tr><th>Part</th><th>Product</th><th class="num">Price</th><th>Notes</th></tr></thead><tbody>{trs}</tbody></table></div>
</div></section>'''


def actions():
    items = [
        ('@together', 'Pick the two plans you like best, and decide whether to start with the Starter Kit while you live in the trailer.'),
        ('@land', 'Walk the lot and pin every Joshua tree, yucca and big creosote ring; draw 50-ft circles and choose the bathhouse spot outside them.'),
        ('@phone', 'Call County Building and Safety, Joshua Tree office (open Wednesdays, 760-995-8140): does the trailer permit count as the main use for a gazebo, spa and sauna, or do we need a Temporary Use Permit?'),
        ('@computer', 'Run the ASCE 7 Hazard Tool for the lot\'s design wind speed, so the gazebo footings can be engineered for it.'),
        ('@phone', 'Ask an electrician for a load calculation and a quote on a spa subpanel: 50 A tub, 30-40 A sauna, 120 V circuits.'),
        ('@errand', 'Visit a Hot Spring dealer; sit in a TX and a Relay; confirm the cover is labeled ASTM F1346.'),
        ('@errand', 'Spend a weekday afternoon at The Spring and measure the pool house: post spacing, wall heights, how the slats vent.'),
        ('@computer', 'Check the parcel\'s fire hazard zone on the CAL FIRE map before choosing roof and wall materials.'),
        ('@errand', 'Buy coral and peach natives at the Mojave Desert Land Trust fall sale or nursery in Joshua Tree; fall is the best planting window.'),
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
    ]
    lis = ''.join(f'<li>{t}: <a href="{u}" target="_blank" rel="noopener">{u}</a></li>' for t, u in src)
    return f'''
<section class="wrap" id="sources"><div class="col stack sources"><p class="eyebrow">Sources</p><ol>{lis}</ol>
<p>Research and renders: October 2026. The 3D models, research files and build scripts live in the gazebo-spa folder of the repository.</p></div></section>
<footer class="wrap"><div class="col small muted">Style direction from kwonyin.global: blush, peach, coral and black, coral lattice, high-key black-and-white desert light.</div></footer>'''
