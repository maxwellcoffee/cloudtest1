"""Text sections of the trailer page (numbers come from data/research and the fact-check)."""

TIERS = [
    dict(k='A', name='Lean, used', render='RA', trailer='A 2017-2019 travel trailer, about 28 ft, bought used for about $12,000-28,000 (a four-season Northwood is the best find; a Jayco or Grand Design Imagine is more common).',
         gear=['Shade sail on posts over the west and door side', 'Vinyl skirting and frame tie-downs', 'Freestanding 8 x 8 ft deck and steps', '1,550-gal water tank and 12 V pump', 'Inverter generator plus a few solar panels and a battery', 'Starlink, propane cylinders, a pump-out contract', '10 x 12 ft storage shed (no permit needed if it has no power)'],
         upfront='$23k-58k', monthly='$1,150', resale='$10k-24k', net=47, nets='$31k / $47k / $62k'),
    dict(k='B', name='Balanced, new four-season', render='RB', trailer='A new 30-ft four-season travel trailer, such as a Grand Design Imagine 2600RB or Northwood Arctic Fox, for about $38,000-65,000.',
         gear=['24 x 41 ft steel RV cover with 14-ft legs (needs a permit)', 'Skirting, tie-downs, a second A/C', 'Freestanding 8 x 12 ft deck with coral lattice privacy panels', '6 kW ground solar and a 10 kWh battery that can later serve the house', '1,550-gal water tank, 250-gal propane tank', 'Temporary power pole with a 50 A RV outlet, Starlink', 'Storage shed'],
         upfront='$69k-130k', monthly='$1,085', resale='$25k-45k', net=63, nets='$46k / $63k / $79k'),
    dict(k='C', name='Premium, Airstream', render='RC', trailer='An Airstream Flying Cloud about 26 ft (new from about $95,000 for a leftover 2026 to $115,900 list for a 2027), or an Oliver Legacy Elite II fiberglass trailer from $85,000.',
         gear=['Black steel ramada, 39 x 23 ft, with a cedar-slat west end', '12 x 12 ft cedar deck, coral lattice screens, blush loungers, olive trees in pots, string lights', 'Outdoor shower', '12 kW solar and a 20 kWh battery that moves to the house', 'Water and propane tanks, Starlink', 'Storage shed'],
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
      <p class="muted">Every image is a Blender render of the real lot model, with the house framing going up behind
      the trailer. Prices are October 2026 listings or labeled estimates.</p>
    </div>
    <div class="lattice"><button class="zoom" type="button" data-full="img/RC_dusk.jpg" data-cap="The premium setup at dusk: Airstream under a black steel ramada">
      <img src="img/RC_dusk.jpg" alt="The premium setup at dusk: Airstream under a black steel ramada" width="1600" height="900"></button></div>
  </div>
</header>'''


def toc():
    return ('<nav class="toc wrap" aria-label="Sections"><ul>'
            '<li><a href="#rule">The rule</a></li><li><a href="#pod">The $20k pod</a></li><li><a href="#looks">Three setups</a></li>'
            '<li><a href="#which">Which trailer</a></li><li><a href="#where">Where to buy</a></li><li><a href="#how">How to buy</a></li>'
            '<li><a href="#budget">Budgets</a></li><li><a href="#desert">Desert living</a></li><li><a href="#next">Next actions</a></li></ul></nav>')


def rule():
    return '''
<section class="wrap" id="rule"><div class="col stack">
  <p class="eyebrow">The rule that decides everything</p>
  <h2>You can live on the land, in a registered trailer, once the house permit is issued</h2>
  <p>San Bernardino County's Temporary Structure Permit lets the person building a house live on the same lot in "a
  recreational vehicle or travel trailer" while they build.</p>
  <div class="note"><ul>
    <li><b>Order:</b> the house building permit is issued first, then this permit, then the trailer moves in. Putting it on the lot earlier can bring penalty fees and enforcement.</li>
    <li><b>Term:</b> 12 months, renewed 12 months at a time, never more than 5 years from the first issue. It lapses if no inspection is called within 180 days.</li>
    <li><b>You submit:</b> a plot plan, the trailer's current California DMV registration, and a sewage pumping contract if the trailer is self-contained. The final inspection covers the power, gas, sewer and water hookups.</li>
    <li><b>Fees (July 2026 schedule):</b> $301 to apply, $261 for the temporary RV site, $257 for each renewal; a temporary power pole is $156 plus a $57 intake fee.</li>
    <li><b>If the lot is inside the Town of Yucca Valley</b>, the Town's code applies instead: a self-contained RV, 1 year plus 1-year extensions, 4 years at most, and it ends when the house is done.</li>
  </ul></div>
  <p>So buy something the DMV registers: a travel trailer or a fifth wheel. Skip a park model unless the County says
  in writing that it counts. You can buy before the permit, but plan to keep the trailer at a storage lot or the
  dealer until the house permit is issued.</p>
</div></section>'''


def pod():
    return '''
<section class="wrap" id="pod" style="background:var(--wash)"><div class="col stack">
  <p class="eyebrow">Your question</p>
  <h2>Can a small prebuilt pod count as storage?</h2>
  <p><b>Yes, as storage only.</b> In the County a shed of 120 sq ft or less, under 14 ft tall and with no utilities,
  needs no building permit. Setbacks still apply, and anything larger needs an accessory-structure permit.</p>
  <ul>
    <li><b>Before the house permit exists</b>, any accessory structure on the lot also needs a Temporary Use Permit and a removal bond. Inside the Town of Yucca Valley, accessory structures are allowed only with an approved house.</li>
    <li><b>No sleeping in it.</b> A pod with a bed, insulation, windows and air conditioning reads as a dwelling to an inspector, and one complaint can bring an order to vacate. An imported capsule without a HUD, HCD or RVIA label can never become a legal bedroom or guest unit later.</li>
    <li><b>Real cost.</b> Capsules listed around $19,000-24,000 come to about $25,000-37,000 after import duty, and roughly $35,000-65,000 once freight, crane, foundation and hookups are added (estimates).</li>
  </ul>
  <div class="note"><p><b>Better use of the $20,000:</b> it buys a decent used trailer, the one interim home the County
  allows, and a 10 x 12 ft shed covers storage for a few thousand dollars more. If you love a particular pod, buy one
  with an HCD factory-built insignia or an RVIA park-model seal so it could become a legal guest unit later, and get
  that in writing from the seller.</p></div>
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
  {img('RL_lineup', 'Four kinds of trailer at the same scale: fiberglass double-hull (24 ft), aluminum Airstream (26 ft), new four-season (30 ft), older used (28 ft)', 'span2', w=2400, h=820)}
  {cards}
</div></section>'''


def which():
    types = [
        ('Travel trailer, four-season, 24-32 ft', 'Best fit', 'DMV-registered; a dealer delivers it, so you don\'t need a truck. Look for dual-pane windows, heated and enclosed tanks, 50 A service and room for a second A/C.'),
        ('Airstream or molded fiberglass', 'Good, costs more', 'Aluminum or fiberglass shell with no rubber roof to fail in the sun, and the best resale value.'),
        ('Fifth wheel', 'Works if delivered', 'More room and height, but you need a pickup to move it. Over 40 ft or 102 in wide cannot be registered in California.'),
        ('Destination trailer, about 40 ft', 'Roomy, rarely four-season', 'Three slides and 13.5 ft tall; needs a long pad and a tall shade cover.'),
        ('RVIA tiny house on wheels', 'Ask the County first', 'Closest to a modern house look (for example the Escape Vista Boho XL, from $62,710). Registered as a travel trailer, but confirm it counts.'),
        ('Park model', 'Avoid unless approved', 'Up to 400 sq ft and 14 ft wide, moved only by Caltrans permit. Get the County\'s answer in writing before buying.'),
    ]
    picks = [
        ('Grand Design Imagine 2600RB', '29 ft 8 in', 'R-40 roof, R-30 floor, four-season package, 50 A, ready for a 2nd A/C', '$38k-59k', '2019: about $16k-29k', 'Best value new'),
        ('Northwood Arctic Fox NXT 22GT', '24 ft', 'Built in Oregon for four seasons: heated tanks, thermal-pane windows', 'about $47k-74k on sale', '2018 25Y: about $29k-35k', 'Compact four-season'),
        ('Northwood Arctic Fox NXT 27RK', '32 ft 3 in', 'Two slides, rear kitchen, 100-gal fresh tank', 'about $74k-75k on sale', 'n/a', 'Roomiest four-season for two'),
        ('Grand Design Reflection 317RSTS', '35 ft 5 in', 'R-40 roof, R-30 floor, rear living room, 2 slides', '$80k-90k', '297RSTS 2019-2024: about $28k-50k', 'Most living space'),
        ('Lance 2465', '29 ft 10 in', 'King bed, thermopane windows, four-season package; built in Lancaster', '$64k-87k', 'n/a', 'High-desert-built'),
        ('Oliver Legacy Elite II', '24 ft', 'Double-hull fiberglass, heated tanks between the shells', '$85k-100k (no haggle)', 'rare', 'Lasts, resells well'),
        ('Airstream Flying Cloud 25FB', '26 ft 2 in', 'Aluminum shell, 15k BTU heat-pump A/C, heated underbelly', '2027 from $115,900; leftover 2026 from about $94,900', '2016-2019: about $49k-59k', 'The look; best resale'),
    ]
    t1 = ''.join(f'<tr><td>{a}</td><td><span class="pill">{b}</span></td><td>{c}</td></tr>' for a, b, c in types)
    t2 = ''.join(f'<tr><td>{a}</td><td class="num">{b}</td><td>{c}</td><td>{d}</td><td>{e}</td><td>{f}</td></tr>' for a, b, c, d, e, f in picks)
    return f'''
<section class="wrap" id="which"><div class="wide stack">
  <p class="eyebrow">Which trailer</p><h2>What to buy for 1-3 years in the high desert</h2>
  <p class="col">For two adults through 100F+ summers and freezing nights, aim for a 24-32 ft four-season travel
  trailer. Rooftop A/C only cools the air about 18-25F below outside, so shade matters more than the trailer.</p>
  <div class="scroll"><table><thead><tr><th>Type</th><th>Verdict</th><th>Why</th></tr></thead><tbody>{t1}</tbody></table></div>
  <h3>Models worth seeing</h3>
  <div class="scroll"><table><thead><tr><th>Model</th><th class="num">Length</th><th>Built for the weather</th><th>New</th><th>Used</th><th>Pick it for</th></tr></thead><tbody>{t2}</tbody></table></div>
  <p class="small muted">New prices are dealer sale prices or list prices seen in October 2026; used prices are asking prices. Listings change daily.</p>
</div></section>'''


def where():
    dealers = [
        ('Blue Compass RV Palm Desert', '77840 Varner Rd, Palm Desert', 'Closest full dealer, about 45 mi. Jayco, Forest River, Keystone, Grand Design; new and used.'),
        ('Mike Thompson\'s RV', 'Cathedral City and Colton', 'New and used mainstream brands.'),
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
    <p><b>When:</b> now through winter. With 2027 prices out, dealers are discounting leftover 2026 trailers, some by
    $12,000-20,000 on Airstreams. The California RV Supershow at the Pomona Fairplex in March is the other good
    time to compare floor plans in one place.</p>
  </div>
</div></section>'''


def how():
    steps = [
        ('Shortlist', 'Agree on length, bed, budget cap and must-haves (dual-pane windows, heated tanks, 50 A, two A/Cs). Walk three or four floor plans at the Palm Desert dealer on a weekday.'),
        ('Inspect', 'Do your own walk-through for water damage first: press the floor at the door, bath and sink; sight down the walls for bubbles; check ceiling corners and roof seals. Then hire an NRVIA-certified inspector (find one on rvhelp.com; about $400-1,200 with travel).'),
        ('Price it', 'Ask for an itemized out-the-door price: doc fee, prep, delivery, add-ons, tax and DMV. Sales tax is about 7.75% in unincorporated areas and 8.75% inside the Town of Yucca Valley, based on where the trailer will sit.'),
        ('Title and DMV', 'Trailers over 16 ft are trailer coaches with yearly registration: $76 plus a $34 CHP fee, a license fee of 0.65% of value, and a transportation fee by value. Register within 10 days; the seller files a release within 5.'),
        ('Insure it', 'Ask for a full-timer or stationary-trailer policy with liability. A normal travel-trailer policy leaves liability to the tow vehicle, and you won\'t have one.'),
        ('Deliver it', 'Write dealer delivery and leveling into the deal, or book a tow-away driver (uShip averages about $3.39 a mile under 100 miles). Check that a truck and a 30-ft trailer can turn around on the lot.'),
    ]
    lis = ''.join(f'<li><span class="t">{a}</span><span>{b}</span></li>' for a, b in steps)
    return f'''
<section class="wrap" id="how"><div class="wide stack-lg">
  <div class="col stack"><p class="eyebrow">How to buy</p><h2>From shortlist to delivery</h2>
  <p>Paying cash or a short loan keeps you from owing more than the trailer is worth when you sell it. If you finance,
  RV lenders want 10-20% down; $50,000 over 15 years at 8.5% is about $492 a month and $38,600 in interest.</p></div>
  <ol class="round" style="grid-template-columns:repeat(3,minmax(0,1fr))">{lis}</ol>
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
  the trailer's resale and the solar, tanks and shade you reuse for the house.</p>
  <h3 style="font-size:1.1rem">Net cost after two years, pump-out scenario</h3>
  <div class="bars" role="img" aria-label="Net cost after two years: Tier A about 47 thousand dollars, Tier B about 63 thousand, Tier C about 92 thousand">{rows}</div>
  <div class="scroll"><table><thead><tr><th>Tier</th><th class="num">Up front</th><th class="num">Per month</th><th class="num">Resale, 2 yrs</th><th class="num">Net, 1 / 2 / 3 yrs</th></tr></thead><tbody>{table}</tbody></table></div>
  <ul>
    <li><b>The biggest monthly cost is sewage pump-out</b> (trailer tanks hold only 40-80 gallons). Putting the house's septic in first and connecting the trailer to it saves about $5,400 a year, if the County allows it.</li>
    <li><b>The biggest upfront lever is shade.</b> A cover over the trailer cuts the A/C load; each rooftop unit draws about 1,500 W.</li>
    <li><b>Monthly running costs</b> with pump-out run about $650-1,700: pump-out $250-700, hauled water $100-300, propane $20-250, insurance $50-250, Starlink $55-130, plus renewals and repairs.</li>
    <li>The 30% federal solar tax credit ended for systems placed in service after December 31, 2025.</li>
  </ul>
  <p class="small muted">Trailer prices come from listings; site work, insurance, inspection, delivery and resale values are estimates. Get quotes.</p>
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
        ('@computer', 'Look up the lot address on the state tax-rate lookup (7.75% or 8.75%) and confirm whether it is County or Town.'),
        ('@computer', 'Set saved searches on RV Trader, RVT.com, Airstream Classifieds and Facebook Marketplace for 24-32 ft four-season trailers.'),
        ('@phone', 'Call Blue Compass Palm Desert and Giant RV Colton: used 24-30 ft trailers 2016 or newer with dual-pane windows; which are consignment?'),
        ('@phone', 'Call Airstream Inland Empire: leftover 2026 Flying Cloud and Caravel, out-the-door price with delivery to Yucca Valley.'),
        ('@phone', 'Get two insurance quotes for a stationary travel trailer used as a temporary home on your own land during construction.'),
        ('@computer', 'Find two NRVIA inspectors on rvhelp.com and get quotes with travel to Palm Desert or Temecula.'),
        ('@land', 'Flag a level pad spot and check that a truck and a 30-ft trailer can get in and turn around.'),
        ('@phone', 'Ask County Land Use Services (909-387-8311) whether a park model or RVIA tiny house would count, and whether the trailer can connect to the house septic once it is in.'),
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
        ('CHP: licence requirements for towing trailers', 'https://www.chp.ca.gov/CommercialVehicleSectionSite/Documents/IB%20California%20Driver%20License%20Requirements%20for%20Towing%20Trailers.pdf'),
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
