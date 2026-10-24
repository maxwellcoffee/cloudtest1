"""Text sections of the trailer page (numbers come from data/research and the fact-check)."""

TIERS = [
    dict(k='A', name='Lean, used', render='RA', trailer='A 2017-2019 travel trailer, about 28 ft, bought used for about $12,000-28,000. A 2017 Jayco Jay Flight or 2019 Grand Design Imagine is typical at this price; the four-season Northwoods found asked $29,000-35,000 plus transport from out of state, just above this tier.',
         gear=['Shade sail on posts over the door side (over 120 sq ft it likely needs a permit and wind engineering, not in this budget)', 'Vinyl skirting and frame tie-downs', 'Freestanding 8 x 8 ft deck and steps', '1,550-gal water tank and 12 V pump', 'Inverter generator parked about 18 ft from the trailer, plus six solar panels and a small battery', 'Starlink and a pump-out contract; the onboard propane cylinders (about 14 gal) last only a few cold nights, so lease a tank for winter or refill often', '10 x 12 ft storage shed (no building permit if one story, under 14 ft, no utilities, within setbacks; before the house exists it may need a Temporary Use Permit)'],
         upfront='$23k-58k', monthly='$1,150', resale='$10k-24k', net=47, nets='$31k / $47k / $62k'),
    dict(k='B', name='Balanced, new four-season', render='RB', trailer='A new or nearly new 30-ft four-season travel trailer, budgeted at $35,000-65,000. A new Grand Design Imagine 2600RB lists at $57,259-60,916; the low end leans on one dealer sale price that couldn\'t be re-checked, so expect closer to $50,000-61,000 unless you find a similar deal.',
         gear=['24 x 41 ft steel RV cover with 14-ft legs (needs a permit; the budget prices a 20 x 40 cover, so this size may cost more)', 'Skirting, tie-downs, a second A/C', 'Freestanding 8 x 12 ft deck with coral lattice privacy panels', 'About 6 kW of ground solar (14 panels) and a 10 kWh battery that can later serve the house, plus a backup generator', '1,550-gal water tank, 250-gal propane tank', 'Starlink; a temporary power pole only if grid power reaches the lot (about $1,700-4,500 plus a $450-750 hookup, not in this budget)', 'Storage shed'],
         upfront='$69k-130k', monthly='$1,085', resale='$25k-45k', net=63, nets='$46k / $63k / $79k'),
    dict(k='C', name='Premium, Airstream', render='RC', trailer='An Airstream Flying Cloud 25FB (26 ft 2 in overall) (2027 models from $115,900 list; leftover 2026 units are being discounted), or an Oliver Legacy Elite II fiberglass trailer from $85,000.',
         gear=['Black steel ramada, 39 x 23 ft, with a cedar-slat west end', '12 x 12 ft cedar deck, coral lattice screens, blush loungers, olive trees in pots, string lights', 'Outdoor shower', 'About 12 kW of solar (28 panels) and a 20 kWh battery that moves to the house', 'Water and propane tanks, Starlink', 'Storage shed'],
         upfront='$140k-263k', monthly='$1,180', resale='$66k-117k', net=92, nets='$70k / $92k / $113k'),
]


def intro():
    return '''
<header class="wrap hero">
  <div class="wide hero-grid">
    <div class="hero-text">
      <p class="eyebrow">Yucca Valley lot &middot; living on the land while you build &middot; October 2026</p>
      <h1>The Build-Years Trailer</h1>
      <p class="lede">Where to get the trailer you'll live in while the house goes up, what the setup could look like
      on the lot, and what it costs used and new.</p>
      <p class="muted">Every image is a Blender render of the real lot model; the view from above in Tier B also shows
      the house framing going up about 90 ft away. Prices are October 2026 listings or labeled estimates.</p>
    </div>
    <div class="lattice"><button class="zoom" type="button" data-full="img/RC_dusk.jpg" data-cap="The premium setup at dusk: Airstream under a black steel ramada">
      <img src="img/RC_dusk.jpg" alt="The premium setup at dusk: Airstream under a black steel ramada" width="1600" height="900"></button></div>
  </div>
</header>'''


def toc():
    return ('<nav class="toc wrap" aria-label="Sections"><ul>'
            '<li><a href="#rule">The rule</a></li><li><a href="#pod">The $20k pod</a></li><li><a href="#looks">Three setups</a></li>'
            '<li><a href="#which">Which trailer</a></li><li><a href="#where">Where to buy</a></li><li><a href="#how">How to buy</a></li>'
            '<li><a href="#timeline">Timeline</a></li><li><a href="#budget">Budgets</a></li><li><a href="#desert">Desert living</a></li><li><a href="#next">Next actions</a></li></ul></nav>')


def rule():
    return '''
<section class="wrap" id="rule"><div class="col stack">
  <p class="eyebrow">The rule that decides everything</p>
  <h2>You can live on the land in a registered trailer once the house permit, and then a trailer permit, are issued</h2>
  <p>San Bernardino County's Temporary Structure Permit lets the person building a house live on the same lot in "a
  recreational vehicle or travel trailer" while they build.</p>
  <div class="note"><ul>
    <li><b>Order:</b> the house building permit is issued first, then this permit, then the trailer moves in. Putting it on the lot earlier can bring penalty fees and enforcement.</li>
    <li><b>Term:</b> 12 months at a time. The County's 2025 checklist says renewals can continue up to 5 years from the first issue, but the Development Code text describes 12 months plus one 12-month extension, requested in writing at least 14 days before it expires. Get the County's answer in writing before planning a 3-year build. The permit lapses if no inspection is called within 180 days, ends if the house permit expires, and ends when the house is finished (the unit then has to be removed, within about 30 days).</li>
    <li><b>You submit:</b> a plot plan, the trailer's current California DMV registration, a sewage pumping contract if the trailer is self-contained, and will-serve letters from the water and sewer providers where they apply. The final inspection covers the power, gas, sewer and water hookups.</li>
    <li><b>Fees (from July 1, 2026):</b> budget about $570-830 for the first year: $301 to apply, possibly $261 more for a temporary RV site (ask whether both apply), $156 for the electrical permit for a temporary power pole, and $57 intake on each permit. Renewals are $257 a year. All rise by a few dollars on July 1, 2027.</li>
    <li><b>If the lot is inside the Town of Yucca Valley</b>, the Town's code applies instead: a "self-contained recreational vehicle" (its own fresh, gray and black tanks), 1 year plus 1-year extensions, 4 years at most, and it ends when the house is done. (Read from a third-party copy of the Town code; confirm with Town planning.)</li>
  </ul></div>
  <p>So buy something the DMV registers: a travel trailer or a fifth wheel. State law counts a park model as an RV,
  but the County hasn't said it qualifies for this permit, so get that in writing before buying one.</p>
</div></section>'''


def pod():
    return '''
<section class="wrap" id="pod" style="background:var(--wash)"><div class="col stack">
  <p class="eyebrow">Your question</p>
  <h2>Can a small prebuilt pod count as storage?</h2>
  <p><b>Yes, as storage only and under the same rules as a shed, but not right away.</b> On a lot with no house yet,
  the County allows an accessory building only with a Temporary Use Permit (a separate permit from the trailer's;
  ask whether the two can be combined). Once the house is up, a pod of 120 sq ft or less, one story, under 14 ft
  tall, with no utilities and meeting the setbacks from property lines needs no building permit; anything bigger
  needs an accessory-structure permit.</p>
  <ul>
    <li><b>Inside the Town of Yucca Valley</b>, a storage building before the house is allowed only with a bond to remove it if the house isn't finished within 2 years.</li>
    <li><b>Storage means storage.</b> Add wiring and it needs an electrical permit. Add a bed, insulation or A/C and an inspector treats it as a home, whatever the seller calls it. Only the permitted trailer may be slept in, and one complaint can bring an order to vacate. An imported capsule without a HUD or HCD label can never become a legal bedroom.</li>
    <li><b>Check the size.</b> Many prebuilt pods sold as tiny homes are bigger than 120 sq ft (10 x 12 ft), so they need a full permit even as storage.</li>
    <li><b>Shipping containers</b> count as accessory structures too. Their County permit is $156 for one to three units, plus $195 plan review and a $57 intake fee; the land research found conditions such as matching paint and placement behind the house.</li>
    <li><b>Heat.</b> An unpowered box in a desert summer gets far hotter than the air. Keep electronics, photos and anything that can melt in a climate-controlled unit in town (listed from about $84-131 a month), which is also the simplest legal storage before the house permit.</li>
    <li><b>Real cost.</b> Imported capsules listed around $19,000-24,000 come to about $25,000-37,000 after import duty, and roughly $35,000-65,000 once freight, crane, foundation and hookups are added (estimates; no specific pod was priced).</li>
  </ul>
  <div class="note"><p><b>Better use of the $20,000:</b> it buys a decent used trailer, the one interim home the County
  allows; the setup around it, from water tank and skirting to permits, adds roughly $11,000-30,000 (see Tier A).
  If the $20,000 is on top of the trailer budget, a 10 x 12 ft shed or a used container covers storage for a few
  thousand dollars. If you love a particular pod, buy one with an HCD factory-built insignia (an RVIA park-model seal
  makes it an RV, not a dwelling), and ask County Building and Safety in writing whether it could become a legal
  guest unit later.</p></div>
</div></section>'''


def looks(img, legend):
    cards = ''
    for t in TIERS:
        k, r = t['k'], t['render']
        shots = img(f'{r}_hero', f'Tier {k}: {t["name"]}', 'span2')
        if r == 'RB':
            shots += img('RB_bird', 'From above: the trailer, shed and solar, with the house framing behind', 'span2')
        if r == 'RC':
            shots += img('RC_hero', 'Afternoon under the ramada', 'span2')
        plan = (f'<div class="plan-row"><div class="lattice">{img(r + "_plan", "Plan, roofs lifted off, north up", w=2000, h=1300)}</div>'
                f'<div class="stack"><p class="eyebrow">Plan key</p>{legend(r + "_plan")}'
                '<p class="small muted">Marker colors: grey for the trailer and its shelter, blue for water, power, propane and internet, green for outdoor living, coral for storage.</p></div></div>')
        money = (f'<div class="money"><div><span>Up front, all in</span><b>{t["upfront"]}</b></div>'
                 f'<div><span>Monthly, with pump-out</span><b>{t["monthly"]}</b></div>'
                 f'<div><span>Resale after 2 years</span><b>{t["resale"]}</b></div>'
                 f'<div><span>Net cost after 1 / 2 / 3 years</span><b>{t["nets"]}</b></div></div>')
        cards += f'''
<article class="scheme tiers" id="tier-{k.lower()}">
  <div class="scheme-head"><span class="scheme-letter" aria-hidden="true">{k}</span><h3>{t["name"]}</h3><p class="small muted">{t["trailer"]}</p></div>
  <div class="shots">{shots}</div>
  {plan}
  <div class="facts"><div><h4>What's on the pad</h4><ul>{''.join(f"<li>{g}</li>" for g in t["gear"])}</ul></div><div><h4>Money (estimates)</h4>{money}</div></div>
</article>'''
    return f'''
<section class="wrap" id="looks"><div class="wide stack-lg">
  <div class="col stack"><p class="eyebrow">What it could look like</p><h2>Three setups on the lot</h2>
  <p>All three use the same spot: a level gravel pad south-east of the house site, the trailer's long side
  east-west with the narrow back end into the west wind, and the door, deck and shade on the south. The house
  framing is going up about 90 ft to the north-west.</p></div>
  {img('RL_lineup', 'Four kinds of trailer drawn to the same scale, side view: molded fiberglass, Oliver class (about 24 ft overall), aluminum Airstream (26 ft), new four-season (30 ft), older used (28 ft), with a 5 ft 9 in person for scale', 'span2', w=2400, h=505)}
  {cards}
</div></section>'''


def which():
    types = [
        ('Travel trailer, four-season, 24-32 ft', 'Best fit', 'DMV-registered; a dealer delivers it, so you don\'t need a truck. Look for dual-pane windows, heated and enclosed tanks, 50 A service and room for a second A/C.'),
        ('Airstream or molded fiberglass', 'Good, costs more', 'Aluminum or fiberglass shell with no rubber roof to fail in the sun, and the best resale value.'),
        ('Fifth wheel', 'Works if delivered', 'More room and height, but it needs a pickup with a bed hitch to move, so fewer delivery drivers can take it (and in California that pickup must be registered as a commercial vehicle). Over 40 ft or 102 in wide cannot be registered in California.'),
        ('Destination trailer, about 40 ft', 'Roomy, rarely four-season', 'Three slides and 13.5 ft tall; needs a long pad and a tall shade cover.'),
        ('RVIA tiny house on wheels', 'Ask the County first', 'Closest to a modern house look (for example the Escape Vista Boho XL, from $62,710). Registered as a travel trailer, but confirm it counts.'),
        ('Park model', 'Avoid unless approved', 'Up to 400 sq ft and 14 ft wide, moved only with a highway permit. State law calls it an RV, but get the County\'s answer in writing before buying.'),
    ]
    picks = [
        ('Grand Design Imagine 2600RB', '29 ft 8 in', '7,850 lb: yes', 'R-40 roof, R-30 floor, four-season package, 50 A, ready for a 2nd A/C', '$57,259-60,916 list', '2019 Imagines: about $16k-29k asking', 'Best value new'),
        ('Northwood Arctic Fox NXT 22GT', '23 ft 10 in', '10,400 lb: no', 'Built in Oregon for four seasons: heated tanks, thermal-pane windows', 'no list price; dealer listings about $47k-74k (unverified)', 'Older Arctic Fox 25Y (2018): about $29k-35k asking', 'Compact four-season'),
        ('Northwood Arctic Fox NXT 27RK', '32 ft 3 in', '12,800 lb: no', 'Two slides, rear kitchen, 100-gal fresh tank, sleeps 2', 'dealer listings about $74k-75k (unverified)', 'n/a', 'Roomiest four-season for two'),
        ('Grand Design Reflection 317RSTS', '35 ft 5 in', '10,995 lb: no', 'R-40 roof, R-30 floor, rear living room, 2 slides', '$80,204-90,227 list', '297RSTS 2019-2024: about $28k-50k asking', 'Most living space'),
        ('Lance 2465', '29 ft 10 in', '8,900 lb: yes', 'King bed, thermopane windows, four-season package; built in Lancaster', 'no list price; listings about $64k-87k (unverified)', 'n/a', 'High-desert-built'),
        ('Oliver Legacy Elite II', '24 ft', '7,000 lb: yes', 'Double-hull fiberglass, heated tanks between the shells', 'from $85,000, sold direct', 'rare', 'Lasts, resells well'),
        ('Airstream Flying Cloud 25FB', '26 ft 2 in', '7,300 lb: yes', 'Aluminum shell, 15k BTU heat-pump A/C, heated underbelly', 'Flying Cloud line from $115,900 (2027); a 25FB lists higher', '2016-2019: about $49k-59k', 'The look; best resale'),
    ]
    t1 = ''.join(f'<tr><td>{a}</td><td><span class="pill">{b}</span></td><td>{c}</td></tr>' for a, b, c in types)
    t2 = ''.join(f'<tr><td>{a}</td><td class="num">{b}</td><td class="num">{g}</td><td>{c}</td><td>{d}</td><td>{e}</td><td>{f}</td></tr>' for a, b, g, c, d, e, f in picks)
    return f'''
<section class="wrap" id="which"><div class="wide stack">
  <p class="eyebrow">Which trailer</p><h2>What to buy for 1-3 years in the high desert</h2>
  <p class="col">For two adults through 100F+ summers and freezing nights, aim for a 24-32 ft four-season travel
  trailer. Rooftop A/C only cools the air passing through it by about 18-25F, and a single unit struggles above about 95F, so shade matters more than the trailer.</p>
  <div class="scroll"><table><thead><tr><th>Type</th><th>Verdict</th><th>Why</th></tr></thead><tbody>{t1}</tbody></table></div>
  <h3>Models worth seeing</h3>
  <div class="scroll"><table><thead><tr><th>Model</th><th class="num">Length</th><th class="num">Regular license can tow it? (max loaded weight)</th><th>Built for the weather</th><th>New</th><th>Used</th><th>Pick it for</th></tr></thead><tbody>{t2}</tbody></table></div>
  <p class="small muted">List prices are from the makers' sites in October 2026; dealer listings are snapshots that couldn't all be re-checked; used prices are asking prices. A regular California license tows a travel trailer rated under 10,000 lb GVWR (the maker's maximum loaded weight) if the tow vehicle weighs at least 4,000 lb empty and you aren't paid to tow it. A heavier travel trailer needs a noncommercial Class A license (a 10,000-15,000 lb fifth wheel needs an endorsement), or use dealer delivery. In one 2026 sample of 74 five-year-old trailers (RVBlogger), Airstreams averaged 76.6% of their original price, the highest of the 22 brands and lines sampled (a blog sample, not a guarantee).</p>
</div></section>'''


def where():
    dealers = [
        ('Blue Compass RV Palm Desert', 'Varner Rd, Palm Desert (confirm the address)', 'Closest full-line dealer, about 45 mi. Jayco, Forest River, Keystone, Grand Design; new and used.'),
        ('Mike Thompson\'s RV', '68318 E Palm Canyon Dr, Cathedral City; 902 RV Center Dr, Colton', 'New and used mainstream brands.'),
        ('Giant RV', '1300 E Santo Antonio Dr, Colton (also Montclair, Murrieta)', 'New and used; takes consignments of 2015-or-newer trailers.'),
        ('Camping World', '10717 Indiana Ave, Riverside', 'Large lot of new and used trailers.'),
        ('High Desert lots (I-15 RV and others)', 'Hesperia and Victorville', 'Mostly used; closest to the lot from the north.'),
        ('Airstream Inland Empire', '27969 Jefferson Ave, Temecula', 'Airstream dealer, about 95 mi. Ask for leftover 2026 units.'),
        ('Airstream Los Angeles', '1212 E Las Tunas Dr, San Gabriel', 'Airstream dealer with a large service department, about 125 mi.'),
        ('Cruise America sales center', 'Carson (Los Angeles)', 'Sells ex-rental units, mostly motorhomes.'),
    ]
    trs = ''.join(f'<tr><td>{a}</td><td>{b}</td><td>{c}</td></tr>' for a, b, c in dealers)
    return f'''
<section class="wrap" id="where" style="background:var(--wash)"><div class="wide stack">
  <p class="eyebrow">Where to get it</p><h2>Dealers, private sales and shows</h2>
  <div class="scroll"><table><thead><tr><th>Dealer</th><th>Where</th><th>Notes</th></tr></thead><tbody>{trs}</tbody></table></div>
  <div class="col stack">
    <p><b>Private sales:</b> RV Trader, RVT.com, RVUSA, RV Universe, Airstream Classifieds and Airforums, Facebook
    Marketplace, and the Inland Empire, Palm Springs and Los Angeles Craigslist sites. Never pay through an
    "escrow" or shipping service the seller picks, and only buy when the title is in the seller's name.</p>
    <p><b>Avoid</b> auctions and bank repossessions for a trailer you must live in: sold as-is, often with salvage titles.</p>
    <p><b>When:</b> as close to the house permit date as you can. If that falls this winter, dealers are
    discounting leftover 2026 trailers now, some by $12,000-20,000 on Airstreams. Buying earlier means paying for
    storage until the trailer permit is issued. The California RV Supershow in Pomona, March 19-21, 2027, is a good
    time to compare floor plans in one place.</p>
  </div>
</div></section>'''


def how():
    steps = [
        ('Shortlist', 'Agree on length, bed, budget cap and must-haves (dual-pane windows, heated tanks, 50 A, two A/Cs). Walk three or four floor plans at the Palm Desert dealer on a weekday.'),
        ('Inspect', 'Do your own walk-through for water damage first: press the floor at the door, bath and sink; sight down the walls for bubbles; check ceiling corners and roof seals. Then hire an NRVIA-certified inspector (find one on rvhelp.com; about $400-1,200 with travel; an estimate, so get quotes).'),
        ('Price it', 'Ask for an itemized out-the-door price: doc fee, prep, delivery, add-ons, tax and DMV. Sales tax is about 7.75% in unincorporated areas and 8.75% inside the Town of Yucca Valley, based on where the trailer will sit.'),
        ('Title and DMV', 'Any trailer over 16 ft is registered every year. On a $50,000 trailer expect roughly $650 the first year ($76 plus 0.65% of the price plus smaller fees), less as it ages; the DMV fee calculator gives the exact total from the VIN. Report the transfer within 10 days; the seller files a release within 5.'),
        ('Insure it', 'Ordinary trailer insurance relies on the tow vehicle\'s policy for liability, and you won\'t have a tow vehicle. Ask for a full-timer add-on (Progressive) or a stationary or full-timer trailer policy (Foremost writes these through agents; check it still does in California).'),
        ('Deliver it', 'Write dealer delivery and leveling into the deal, or book a tow-away driver (see the timeline below). Check that a truck and a 30-ft trailer can turn around on the lot.'),
    ]
    lis = ''.join(f'<li><span class="t">{a}</span><span>{b}</span></li>' for a, b in steps)
    return f'''
<section class="wrap" id="how"><div class="wide stack-lg">
  <div class="col stack"><p class="eyebrow">How to buy</p><h2>From shortlist to delivery</h2>
  <p>Paying cash or a short loan keeps you from owing more than the trailer is worth when you sell it. If you finance,
  RV lenders want 10-20% down; $50,000 over 15 years at 8.5% is about $492 a month and $38,600 in interest.</p></div>
  <ol class="round" style="grid-template-columns:repeat(3,minmax(0,1fr))">{lis}</ol>
</div></section>'''


def timeline():
    return '''
<section class="wrap" id="timeline"><div class="col stack">
  <p class="eyebrow">Timing and logistics</p><h2>From buying to selling</h2>
  <p><b>When to buy.</b> The trailer permit application needs the trailer's California registration in your name,
  so you own it before you apply. The order is: house permit issued, buy and register the trailer, apply for the
  trailer permit, then delivery once it is issued. Buy as close to the house permit date as you can. Buying early
  to catch a year-end discount is fine if the dealer will hold it for a deposit or you keep it at an RV storage
  lot; add those months of storage, insurance and registration to the cost.</p>
  <p><b>Getting it there with no truck.</b> Write delivery to the lot and leveling into the dealer's price, and ask
  how far they deliver. For a private sale or a move out of storage, book a licensed tow-away driver. At uShip's
  short-haul average of about $3.39 a mile, that is roughly $150-350 from the dealers listed, before minimum
  charges. Expect the driver to check the brakes, lights, breakaway battery and tire dates, and to want the title
  or registration on board. Drive the dirt road to the lot first: soft sand and wash crossings are where deliveries
  get stuck. If you store it first, budget for two moves.</p>
  <p><b>Keep three clocks running.</b> Renew the trailer permit before each expiry. Keep the house permit active
  with regular inspections, because the trailer permit dies if the building permit expires. Renew the DMV
  registration every year even though the trailer never moves; the permit asks for current registration.</p>
  <p><b>When the house is done.</b> The trailer has to leave within about 30 days of the final inspection. Start the
  sale two or three months ahead: sell privately or consign it (Giant RV takes 2015-or-newer units). If you'd rather
  keep it as a camper, ask whether it can stay parked, unoccupied, on your lot; it can't become a guest room or
  rental. The solar, battery, water tank and shade stay and serve the house.</p>
  <p><b>Why not a motorhome or a rental?</b> A motorhome also counts as an RV, and you could drive it to the lot
  yourselves, but you pay for an engine that sits unused and still ages, and you get less room for the money.
  Renting long term runs an estimated $3,000-6,000 a month, more than buying and reselling over 1-3 years.</p>
  <p><b>Inside.</b> For two people full time, look for a rear-living or rear-kitchen plan with a big back window, a
  bed you can walk around, a real dinette or desk for work, a large fridge and the biggest tanks you can find. Skip
  bunkhouse plans. Spend an hour sitting in each shortlisted plan at the dealer.</p>
</div></section>'''


def budget():
    vmax = 100
    rows = ''
    for t in TIERS:
        w = t['net'] / vmax * 100
        rows += (f'<div class="bar-row"><span>Tier {t["k"]}: {t["name"]}</span>'
                 f'<div class="bar-track bar-axis" data-tip="Tier {t["k"]}: about ${t["net"]}k after 2 years ({t["nets"]} after 1 / 2 / 3 years)">'
                 f'<div class="bar" style="width:{w:.1f}%"></div><span class="bar-val" style="left:{w:.1f}%">${t["net"]}k</span></div></div>')
    table = ''.join(f'<tr><td>Tier {t["k"]}: {t["name"]}</td><td class="num">{t["upfront"]}</td><td class="num">{t["monthly"]}</td><td class="num">{t["resale"]}</td><td class="num">{t["nets"]}</td></tr>' for t in TIERS)
    return f'''
<section class="wrap" id="budget"><div class="col stack">
  <p class="eyebrow">Money</p><h2>What two years really costs</h2>
  <p>Net cost is everything you spend (trailer, tax, setup, two years of running costs) minus what you get back:
  the trailer's resale and the solar, tanks and shade you reuse for the house. It uses the middle of each tier:
  about $40k, $93k and $193k up front, minus about $5k, $24k and $40k of equipment reused for the house.</p>
  <h3 style="font-size:1.1rem">Net cost after two years, pump-out scenario</h3>
  <div class="bars" role="img" aria-label="Net cost after two years: Tier A about 47 thousand dollars, Tier B about 63 thousand, Tier C about 92 thousand">{rows}</div>
  <div class="scroll"><table><thead><tr><th>Tier</th><th class="num">Up front</th><th class="num">Per month</th><th class="num">Resale, 2 yrs</th><th class="num">Net, 1 / 2 / 3 yrs</th></tr></thead><tbody>{table}</tbody></table></div>
  <ul>
    <li><b>The biggest monthly cost is sewage pump-out.</b> Two people send about 30 gallons a day into the gray and black tanks, so the trailer's 40-80-gallon tanks fill in a few days; plan an extra holding tank sized so the pumper comes every week or two. Putting the house's septic in first and connecting the trailer to it saves about $5,400 a year (2-year nets of about $36k, $52k and $81k), if the County allows it. Inside the Town of Yucca Valley, the Regional Water Board's 2011 septic prohibition may rule out a new septic system: check the parcel with Hi-Desert Water District (760-365-8333) before counting on this.</li>
    <li><b>The best upfront spend for comfort is shade.</b> A cover over the trailer cuts the A/C load; each rooftop unit draws about 1,500 W.</li>
    <li><b>Monthly running costs</b> with pump-out are about $1,085-1,180 in a typical month ($650-1,700 depending on tier and season): pump-out $250-700, hauled water $100-300, propane $20-250, generator fuel up to $400 in a Tier A summer, insurance $50-250, Starlink $55-130, plus renewals and repairs ($75-250). Tier A costs a little more per month because a generator runs its summer A/C.</li>
    <li><b>A middle path:</b> a 2016-2019 Flying Cloud (about $49k-59k asking) with the Tier B setup gives the Airstream look and strong resale for far less than Tier C.</li>
    <li>The 30% federal solar tax credit ended for systems placed in service after December 31, 2025.</li>
  </ul>
  <p class="small muted">Trailer prices come from listings; site work, insurance, inspection, delivery and resale values are estimates. The budgets assume the Town's 8.75% sales tax; on an unincorporated lot the tax is 7.75%, about $1,000 less per $100,000. Get quotes.</p>
</div></section>'''


def desert():
    items = [
        ('Heat', 'Shade over the roof and the west side first. Two A/Cs on anything over 25 ft, 50 A service, a white reflective roof coating. Plan heavy cooking and laundry for the morning.'),
        ('Cold', 'Skirting with a small heater behind it, heated tanks, heat tape on the water line, and a 250-gal propane tank (a furnace can burn 1-3 gallons on a cold night).'),
        ('Wind', 'Back end to the west wind, frame tie-downs with 48-in earth anchors, awning rolled up on windy days. Spring gusts reach 40-50 mph.'),
        ('Sun', 'UV cracks roof sealant and tires even when parked: reseal each season, cover the tires, and take the weight off them with jack stands.'),
        ('Dust and rodents', 'Seal every gap under the trailer with hardware cloth before the skirting goes on; check the wiring for chewing.'),
        ('Water', 'Two people use about 30-50 gallons a day, so a 1,550-gal tank lasts 30-50 days between deliveries.'),
        ('Smell', 'Black tanks smell in the heat: keep them closed until two-thirds full, then dump all at once, and use enzyme treatment.'),
    ]
    trs = ''.join(f'<tr><td><b>{a}</b></td><td>{b}</td></tr>' for a, b in items)
    return f'''
<section class="wrap" id="desert" style="background:var(--wash)"><div class="col stack">
  <p class="eyebrow">Living in it</p><h2>The desert checklist</h2>
  <div class="scroll"><table><tbody>{trs}</tbody></table></div>
</div></section>'''


def actions():
    items = [
        ('@together', 'Pick a tier and a trailer type; decide the budget cap and whether to finance.'),
        ('@phone', 'Ask County Land Use Services (909-387-8311), in writing, how long the trailer permit can run: up to 5 years as the checklist says, or 12 months plus one extension as the code text says.'),
        ('@phone', 'Ask the County whether a storage shed or container can go up during construction under the house permit, or needs its own Temporary Use Permit, and whether a park model or RVIA tiny house would count as the trailer.'),
        ('@computer', 'Look up the lot address on the state tax-rate lookup (7.75% or 8.75%) and confirm whether it is County or Town.'),
        ('@computer', 'Set saved searches on RV Trader, RVT.com, Airstream Classifieds and Facebook Marketplace for 24-32 ft four-season trailers.'),
        ('@phone', 'Call Blue Compass Palm Desert and Giant RV Colton: used 24-30 ft trailers 2016 or newer with dual-pane windows; which are consignment?'),
        ('@phone', 'Call Airstream Inland Empire: leftover 2026 Flying Cloud and Caravel, out-the-door price with delivery to Yucca Valley.'),
        ('@phone', 'Get two insurance quotes for a stationary travel trailer used as a temporary home on your own land during construction.'),
        ('@phone', 'Get a sewage pump-out contract quote (the permit requires one) and, if you buy early, an RV storage rate and two delivery quotes.'),
        ('@computer', 'Find two NRVIA inspectors on rvhelp.com and get quotes with travel to Palm Desert or Temecula.'),
        ('@land', 'Flag a level pad spot, drive the dirt road in, and check that a truck and a 30-ft trailer can get in and turn around.'),
    ]
    lis = ''.join(f'<li><input type="checkbox" id="rvact{i}" aria-label="Done"><label for="rvact{i}"><span class="ctx">{c}</span>{t}</label></li>' for i, (c, t) in enumerate(items))
    return f'''
<section class="wrap" id="next"><div class="col stack">
  <p class="eyebrow">Next actions</p><h2>What to do next</h2>
  <p class="small muted">Ticks are saved in this browser only.</p>
  <ul class="actions">{lis}</ul>
</div></section>'''


def sources():
    src = [
        ('County Temporary Structure Permit checklist (rev. 6/2025)', 'https://lus.sbcounty.gov/wp-content/uploads/sites/48/Temporary-Structure-Permit-Checklist-2025.pdf'),
        ('County FAQ: living on the property while building', 'https://lus.sbcounty.gov/faqs/while-building-a-new-home-can-i-put-a-temporary-mobile-home-on-my-property-to-live-in-while-my-house-is-under-construction'),
        ('Yucca Valley Zoning Code chapter 9.39 (third-party copy)', 'https://gocodebook.com/library/us/ca/yucca-valley-zoning/chapter-9.39-temporary-uses-and-structures'),
        ('California DMV: trailers', 'https://www.dmv.ca.gov/portal/vehicle-registration/trailers/'),
        ('CHP: license requirements for towing trailers', 'https://www.chp.ca.gov/CommercialVehicleSectionSite/Documents/IB%20California%20Driver%20License%20Requirements%20for%20Towing%20Trailers.pdf'),
        ('Airstream travel trailers and prices', 'https://www.airstream.com/travel-trailers/'),
        ('Airstream dealer locator', 'https://www.airstream.com/dealers/'),
        ('Blue Compass RV Palm Desert', 'https://www.bluecompassrv.com/locations/california/palm-desert/contact-us'),
        ('Grand Design Imagine', 'https://www.granddesignrv.com/travel-trailers/imagine'),
        ('Grand Design Reflection', 'https://www.granddesignrv.com/travel-trailers/reflection'),
        ('Northwood Arctic Fox NXT', 'https://northwoodmfg.com/arctic-fox-nxt/'),
        ('Oliver Legacy Elite II', 'https://www.olivertraveltrailers.com/legacy-elite-ii/'),
        ('Escape tiny houses (Vista Boho XL)', 'https://www.escapetraveler.net/vista-boho-xl'),
        ('NRVIA: find an inspector', 'https://nrvia.org/locate/'),
        ('Giant RV', 'https://giantrv.com/'), ('Camping World Riverside', 'https://rv.campingworld.com/dealer/riverside-ca'),
        ('Cruise America used RVs', 'https://www.cruiseamerica.com/buy-used-rvs'),
        ('Progressive: full-time RV insurance', 'https://www.progressive.com/rv/rv-insurance-coverages-full-timers/'),
        ('Foremost full-timer travel trailer sheet', 'https://www.foremostagent.com/assets/marketing/AgentMarketingMaterials/Casualty/pdf/Full-Timer-Travel-Trailer-Selling-Sheet.pdf'),
        ('CDTFA sales and use tax rates', 'https://www.cdtfa.ca.gov/taxes-and-fees/sales-use-tax-rates.htm'),
        ('RV Supershows', 'https://www.rvsupershows.com/'),
        ('uShip travel trailer transport', 'https://www.uship.com/trailer-transport'),
        ('Carport Central RV cover prices', 'https://www.carportcentral.com/metal-rv-carport-prices'),
    ]
    lis = ''.join(f'<li>{t}: <a href="{u}" target="_blank" rel="noopener">{u}</a></li>' for t, u in src)
    return f'''
<section class="wrap" id="sources" style="background:var(--wash)"><div class="col stack sources"><p class="eyebrow">Sources</p><ol>{lis}</ol>
<p>Research and renders: October 2026. The 3D models, research files and build scripts live in the rv-trailer folder of the repository.</p></div></section>'''
