"""Build the voice-capture field guide page.

Reads ../data/catalog.json, ../data/recommendation.json, ../data/stats.json and the two
Apple Watch research briefs (../data/watch-*.md), then writes site/index.html.

usage: python3 build.py
"""
import html, json, os, re

import markdown  # pip install markdown

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, '..', 'data')
E = html.escape
TODAY = '16 November 2026'

FEATURES = {
    'always_on_capture': 'Always-on capture',
    'tap_or_push_to_talk': 'Tap or push-to-talk',
    'meeting_or_call_capture': 'Meeting and call capture',
    'on_device_transcription': 'On-device transcription',
    'cloud_transcription': 'Cloud transcription',
    'speaker_diarization': 'Speaker labels',
    'live_translation': 'Live translation',
    'auto_summaries': 'Automatic summaries',
    'action_items_tasks': 'Action items and tasks',
    'searchable_memory': 'Searchable memory',
    'ask_ai_over_history': 'Ask AI about your history',
    'custom_prompts_templates': 'Custom prompts and templates',
    'proactive_suggestions_or_reminders': 'Proactive nudges and recaps',
    'agentic_actions': 'Takes actions for you',
    'third_party_integrations': 'Third-party integrations',
    'camera_or_visual_context': 'Camera or visual context',
    'sensor_or_location_context': 'Sensor or location context',
    'offline_capture': 'Offline capture',
    'local_only_or_e2e_privacy': 'Local-only or end-to-end privacy',
    'recording_consent_controls': 'Consent and recording controls',
    'apple_watch_app': 'Apple Watch app',
    'haptic_or_glanceable_output': 'Haptic or glanceable output',
    'export_or_api': 'Export or API',
}
CATEGORIES = ['AI wearable (pendant/pin/clip)', 'AI voice recorder', 'Smart glasses', 'Ring / watch / earbuds',
              'Meeting & call notetaker', 'Voice notes & journaling app', 'Dictation & voice-to-prompt',
              'Voice AI assistant', 'Apple Watch app', 'Ambient professional scribe',
              'Lifelogging & context-memory platform']
CAT_SHORT = {
    'AI wearable (pendant/pin/clip)': 'Wearable pendant or pin',
    'AI voice recorder': 'AI voice recorder',
    'Smart glasses': 'Smart glasses',
    'Ring / watch / earbuds': 'Ring, watch or earbuds',
    'Meeting & call notetaker': 'Meeting notetaker',
    'Voice notes & journaling app': 'Voice notes app',
    'Dictation & voice-to-prompt': 'Dictation and prompts',
    'Voice AI assistant': 'Voice assistant',
    'Apple Watch app': 'Apple Watch app',
    'Ambient professional scribe': 'Professional scribe',
    'Lifelogging & context-memory platform': 'Lifelogging platform',
}
STATUS = [  # (value, label, glyph)
    ('shipping', 'Shipping', '●'),
    ('beta/early-access', 'Beta or early access', '◐'),
    ('announced-upcoming', 'Announced, upcoming', '◆'),
    ('rumored', 'Rumored', '◇'),
    ('discontinued', 'Discontinued', '×'),
]
STATUS_LABEL = {s: l for s, l, _ in STATUS}
STATUS_GLYPH = {s: g for s, _, g in STATUS}
CONF_LABEL = {'high': 'Verified, high confidence', 'medium': 'Verified, medium confidence',
              'low': 'Verified, low confidence', 'unchecked': 'Sourced once, not re-checked'}
TIER_COPY = {
    'Core': 'Table stakes. Users expect these on day one.',
    'Differentiator': 'Where a new product can beat the field.',
    'Later': 'Worth building once the core is reliable.',
}


def phrase(k):
    label = FEATURES[k]
    return label if label.startswith('Apple') else label[0].lower() + label[1:]


KEY_RE = re.compile(r'\b(' + '|'.join(sorted(FEATURES, key=len, reverse=True)) + r')\b')


def humanize(obj):
    """Swap internal feature keys (cloud_transcription) for their labels in every string."""
    if isinstance(obj, str):
        return KEY_RE.sub(lambda m: phrase(m.group(1)), obj)
    if isinstance(obj, list):
        return [humanize(x) for x in obj]
    if isinstance(obj, dict):
        return {k: humanize(v) for k, v in obj.items()}
    return obj


def load(name):
    with open(os.path.join(DATA, name)) as f:
        return json.load(f)


LIST_RE = re.compile(r'^( *)([-*]|\d+\.) ')


def md_prep(text):
    out, prev_list = [], False
    for line in (text or '').split('\n'):
        m = LIST_RE.match(line)
        if m:
            line = ' ' * ((len(m.group(1)) // 2) * 4) + line.lstrip(' ')
            if out and out[-1].strip() and not prev_list:
                out.append('')
            prev_list = True
        elif line.strip() and prev_list and not line.startswith(' '):
            out.append('')
            prev_list = False
        elif not line.strip():
            prev_list = False
        out.append(line)
    return '\n'.join(out)


def md(text):
    text = md_prep((text or '').replace('<', '&lt;').replace('>', '&gt;'))
    out = markdown.markdown(text, extensions=['tables', 'sane_lists'])
    # make bare URLs clickable
    out = re.sub(r'(?<!["=>])(https?://[^\s<)\]]+)', r'<a href="\1">\1</a>', out)
    return out


def slug(s):
    return re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')


def host(u):
    m = re.match(r'https?://(?:www\.)?([^/]+)', u or '')
    return m.group(1) if m else u


def status_chip(s):
    return (f'<span class="chip st-{slug(s)}"><span class="glyph" aria-hidden="true">{STATUS_GLYPH.get(s, "•")}</span>'
            f'{E(STATUS_LABEL.get(s, s))}</span>')


# ---------------------------------------------------------------- sections

def masthead(final, stats, products):
    upcoming = sum(1 for p in products if p['status'] in ('announced-upcoming', 'rumored'))
    watch = sum(1 for p in products if p['features'].get('apple_watch_app'))
    cats = len([c for c in CATEGORIES if stats['byCategory'].get(c)])
    checked = sum(1 for p in products if p.get('verify_confidence') in ('high', 'medium', 'low'))
    lead, opening, risks, _ = split_summary(final['executive_summary'])
    short = ''
    if opening or risks:
        short = f'''
    <div class="short">
      {f'<div><h2 class="mini">Where the opening is</h2><div class="prose flush">{md(opening)}</div></div>' if opening else ''}
      {f'<div><h2 class="mini">What could sink it</h2><div class="prose flush">{md(risks)}</div></div>' if risks else ''}
    </div>'''
    return f'''
<header class="masthead">
  <div class="wrap">
    <p class="eyebrow">Research brief · {TODAY}</p>
    <h1>Voice Capture Field Guide</h1>
    <p class="lead">{E(lead)}</p>
    <p class="facts"><b>{len(products)}</b> products in <b>{cats}</b> categories · <b>{checked}</b> fact-checked twice · <b>{upcoming}</b> upcoming or rumored · <b>{watch}</b> with an Apple Watch app</p>
    {short}
    <nav class="toc" aria-label="Sections">
      <a href="#watch-app">Minimal Watch app</a><a href="#earshot">Against Earshot</a><a href="#feature-set">Best feature set</a><a href="#market">Market</a><a href="#upcoming">Coming soon</a><a href="#catalog">Catalog</a><a href="#watchos">Building on watchOS</a><a href="#method">Method</a>
    </nav>
  </div>
</header>'''


def watch_mock():
    return '''
<figure class="watch" aria-label="Illustration of the minimal app's recording screen">
  <div class="bezel"><div class="screen">
    <div class="w-top"><span class="w-rec"><span class="dot" aria-hidden="true"></span>REC 3:42</span><span class="w-sync">On iPhone</span></div>
    <div class="w-big">10:09</div>
    <div class="w-sub">Session until 6:00 PM · about 7 h left</div>
    <div class="w-btns"><span class="w-btn pause">Pause</span><span class="w-btn mark">Mark</span></div>
  </div></div>
  <figcaption>Illustration of the recording screen. It stands in for the watch face, so the time is large and the state is small, and Pause is the biggest button.</figcaption>
</figure>'''


def watch_section(final):
    items = ''
    for it in final['minimal_watch_set']:
        title, cut = minimal_title(it['feature'])
        items += f'''
    <li class="{'optional' if cut else ''}">
      <div class="mvp-head"><h3>{E(title)}</h3>{'<span class="stage cut">Cut first if time is short</span>' if cut else ''}</div>
      <div class="prose flush">{md(it["description"])}</div>
      <p class="why"><span class="lbl">Why it's in</span>{E(it["why_essential"])}</p>
      <details class="impl"><summary>How to build it on watchOS</summary><div class="prose flush">{md(it["watchos_implementation"])}</div></details>
    </li>'''
    cuts = ''.join(f'<li><b>{E(c["feature"])}</b><span>{E(c["reason"])}</span></li>' for c in final['explicitly_excluded_from_minimal'])
    arch_labels = [('capture_strategy', 'Capture'), ('transcription_and_ai', 'Transcription and AI'),
                   ('sync_and_storage', 'Sync and storage'), ('battery_budget', 'Battery budget'),
                   ('inputs_and_ui', 'Inputs and UI'), ('privacy_and_consent', 'Privacy and consent')]
    arch = ''.join(f'<details class="arch-item"><summary>{lbl}</summary><div class="prose flush">{md(final["watch_architecture"][k])}</div></details>' for k, lbl in arch_labels)
    n_core = sum(1 for it in final['minimal_watch_set'] if not minimal_title(it['feature'])[1])
    n_cut = len(final['minimal_watch_set']) - n_core
    return f'''
<section id="watch-app" class="band">
  <div class="wrap">
    <p class="eyebrow">Recommendation 1</p>
    <h2>The minimal always-on Apple Watch app</h2>
    <p class="sub">{n_core} parts make a recorder worth wearing all day{f", plus {n_cut} that are the first to go if time runs short" if n_cut else ""}. They are in build order. Each says what it does, why it made the cut, and how to build it with the APIs watchOS offers today. Marks such as [H], [M] and [L] give the research's confidence (high, medium, low) in a platform claim.</p>
    <div class="watch-grid">
      <ol class="mvp">{items}</ol>
      <aside class="watch-side">{watch_mock()}</aside>
    </div>
    <div class="cut">
      <h3>Left out of the minimal app on purpose</h3>
      <ul>{cuts}</ul>
    </div>
    <div class="arch-wrap">
      <h3>How it fits together</h3>
      <div class="arch">{arch}</div>
    </div>
  </div>
</section>'''


def feature_set_section(final, names):
    blocks = ''
    for tier in ('Core', 'Differentiator', 'Later'):
        feats = [f for f in final['best_feature_set'] if f['tier'] == tier]
        if not feats:
            continue
        cards = ''
        for f in feats:
            title, stage = feat_title(f['feature'])
            ex = ''.join(f'<span class="ex">{E(x)}</span>' for x in f.get('exemplars', [])[:6])
            cards += f'''
        <article class="feat">
          <header><h4>{E(title)}</h4>{f'<span class="stage">{E(stage)}</span>' if stage else ''}</header>
          <div class="prose flush">{md(f["description"])}</div>
          {f'<p class="exs"><span class="lbl">Seen in</span>{ex}</p>' if ex else ''}
          <details><summary>Why</summary><p class="why">{E(f["rationale"])}</p></details>
        </article>'''
        blocks += f'''
      <div class="tier tier-{slug(tier)}">
        <header><h3>{E(tier)}</h3><p>{E(TIER_COPY[tier])}</p><span class="count">{len(feats)} features</span></header>
        <div class="feat-grid">{cards}</div>
      </div>'''
    return f'''
<section id="feature-set">
  <div class="wrap">
    <p class="eyebrow">Recommendation 2</p>
    <h2>The best overall feature set</h2>
    <p class="sub">For a full product across Watch, iPhone and, later, the Mac. Core features carry a release stage: v1 ships first, v1.x follows.</p>
    <div class="tiers">{blocks}</div>
  </div>
</section>'''


def bar_rows(rows, total, cls=''):
    """rows: list of (label, count, examples[list], key)."""
    mx = max([c for _, c, _, _ in rows] + [1])
    ticks = [t for t in range(0, mx + 1, max(1, (mx // 4) // 5 * 5 or 5))][:6]
    out = ''
    for label, count, examples, key in rows:
        pct = round(100 * count / total) if total else 0
        w = 100 * count / mx
        ex = E(', '.join(examples[:6]))
        out += (f'<div class="bar-row" tabindex="0" data-tip="{E(label)}|{count} of {total} products ({pct}%)|{ex}">'
                f'<span class="bar-lbl">{E(label)}</span>'
                f'<span class="bar-track"><span class="bar" style="width:{w:.2f}%"></span>'
                f'<span class="bar-val" style="left:{w:.2f}%">{count}</span></span></div>')
    axis = ''.join(f'<span style="left:{100 * t / mx:.2f}%">{t}</span>' for t in ticks)
    grid = ''.join(f'<i style="left:{100 * t / mx:.2f}%"></i>' for t in ticks)
    return f'<div class="bars {cls}"><div class="bar-grid" aria-hidden="true">{grid}</div>{out}<div class="bar-axis" aria-hidden="true">{axis}</div></div>'


def market_section(final, stats, products):
    total = len(products)
    frows = []
    for key, label in FEATURES.items():
        has = [p['name'] for p in products if p['features'].get(key)]
        frows.append((label, len(has), has, key))
    frows.sort(key=lambda r: -r[1])
    crows = []
    for c in CATEGORIES:
        has = [p['name'] for p in products if p['category'] == c]
        if has:
            crows.append((CAT_SHORT[c], len(has), has, c))
    crows.sort(key=lambda r: -r[1])
    # status segmented bar
    segs = ''
    legend = ''
    for s, label, glyph in STATUS:
        n = sum(1 for p in products if p['status'] == s)
        if not n:
            continue
        share = 100 * n / total
        segs += (f'<span class="seg st-{slug(s)}" style="flex:{n}" tabindex="0" data-tip="{E(label)}|{n} of {total} products ({round(share)}%)|">'
                 f'{f"<b>{n}</b>" if share >= 6 else ""}</span>')
        legend += f'<li><span class="sw st-{slug(s)}" aria-hidden="true"></span>{E(label)} <span class="muted">{n}</span></li>'
    patterns = ''.join(f'<li>{E(x)}</li>' for x in final['market_patterns'])
    gaps = ''.join(f'<li>{E(x)}</li>' for x in final['market_gaps'])
    table_rows = ''.join(f'<tr><td>{E(l)}</td><td class="num">{c}</td><td class="num">{round(100 * c / total)}%</td></tr>' for l, c, _, _ in frows)
    return f'''
<section id="market">
  <div class="wrap">
    <p class="eyebrow">The evidence</p>
    <h2>What the market already does</h2>
    <div class="two">
      <div>
        <h3>Patterns across {total} products</h3>
        <ul class="ticks">{patterns}</ul>
      </div>
      <div>
        <h3>Gaps nobody fills well</h3>
        <ul class="ticks gaps">{gaps}</ul>
      </div>
    </div>
    <figure class="chart">
      <figcaption><h3>How many products offer each feature</h3><p>Out of {total} products, how many have the feature confirmed by a source. A feature without a source counts as missing, so these are lower bounds.</p></figcaption>
      {bar_rows(frows, total)}
      <details class="tbl"><summary>Show as a table</summary>
        <table><thead><tr><th>Feature</th><th class="num">Products</th><th class="num">Share</th></tr></thead><tbody>{table_rows}</tbody></table>
      </details>
    </figure>
    <div class="two">
      <figure class="chart">
        <figcaption><h3>Products by category</h3></figcaption>
        {bar_rows(crows, total, 'compact')}
      </figure>
      <figure class="chart">
        <figcaption><h3>Where each product stands today</h3></figcaption>
        <div class="segbar" role="img" aria-label="Status breakdown">{segs}</div>
        <ul class="seg-legend">{legend}</ul>
      </figure>
    </div>
  </div>
</section>'''


def upcoming_section(products):
    ups = [p for p in products if p['status'] in ('announced-upcoming', 'rumored')]
    ups.sort(key=lambda p: (p['status'] != 'announced-upcoming', p['name'].lower()))
    rows = ''.join(f'''
      <li>
        <div class="u-head"><b>{E(p["name"])}</b><span class="muted">{E(p["company"])}</span>{status_chip(p["status"])}</div>
        <p class="u-when">{E(p["release_timing"])}</p>
        <p>{E(p["differentiator"])}</p>
      </li>''' for p in ups)
    return f'''
<section id="upcoming" class="band">
  <div class="wrap">
    <p class="eyebrow">December 2026 to spring 2027</p>
    <h2>Coming in the next few months</h2>
    <p class="sub">Announced products first, then rumors. Each one went through a second check that tried to disprove its status and timing. Dates are the latest reported and can slip.</p>
    <ul class="upcoming">{rows}</ul>
  </div>
</section>'''


def catalog_section(products):
    cat_opts = ''.join(f'<option value="{E(c)}">{E(CAT_SHORT[c])}</option>' for c in CATEGORIES if any(p['category'] == c for p in products))
    st_opts = ''.join(f'<option value="{E(s)}">{E(l)}</option>' for s, l, _ in STATUS if any(p['status'] == s for p in products))
    feat_opts = ''.join(f'<option value="{k}">{E(v)}</option>' for k, v in FEATURES.items())
    rows = ''
    for i, p in enumerate(sorted(products, key=lambda p: (CATEGORIES.index(p['category']) if p['category'] in CATEGORIES else 99, p['name'].lower()))):
        flags = [k for k in FEATURES if p['features'].get(k)]
        chips = ''.join(f'<span class="fchip">{E(FEATURES[k])}</span>' for k in flags)
        srcs = ''.join(f'<a href="{E(u)}">{E(host(u))}</a>' for u in p.get('sources', [])[:4])
        conf = p.get('verify_confidence', '')
        rows += f'''
      <tr data-cat="{E(p["category"])}" data-status="{E(p["status"])}" data-checked="{"no" if conf == "unchecked" else "yes"}" data-flags="{" ".join(flags)}" data-name="{E(p["name"].lower())}" data-text="{E((p["name"] + " " + p["company"] + " " + p["differentiator"] + " " + p["form_factor"]).lower())}">
        <td class="c-name"><b>{E(p["name"])}</b><span class="muted">{E(p["company"])}</span></td>
        <td class="c-cat">{E(CAT_SHORT.get(p["category"], p["category"]))}<span class="muted">{E(p["form_factor"])}</span></td>
        <td class="c-st">{status_chip(p["status"])}<span class="muted">{E(p["release_timing"])}</span></td>
        <td class="c-price">{E(p["price"])}</td>
        <td class="c-what">
          <p>{E(p["differentiator"])}</p>
          <details><summary>{len(flags)} features · details</summary>
            <div class="fchips">{chips}</div>
            <p><span class="lbl">Limits</span>{E(p.get("limitations", ""))}</p>
            <p><span class="lbl">Platforms</span>{E(p["platforms"])}</p>
            <p><span class="lbl">Checked</span><span class="conf conf-{E(conf)}">{E(CONF_LABEL.get(conf, conf))}</span> {E("" if conf == "unchecked" else p.get("verify_notes", ""))}</p>
            <p class="srcs"><span class="lbl">Sources</span>{srcs}</p>
          </details>
        </td>
      </tr>'''
    return f'''
<section id="catalog">
  <div class="wrap">
    <p class="eyebrow">All {len(products)} products</p>
    <h2>The catalog</h2>
    <form class="filters" id="filters" role="search" aria-label="Filter the catalog">
      <label class="f-search"><span>Search</span><input id="f-q" type="search" placeholder="Name, company or feature" autocomplete="off"></label>
      <label><span>Category</span><select id="f-cat"><option value="">All categories</option>{cat_opts}</select></label>
      <label><span>Status</span><select id="f-st"><option value="">Any status</option>{st_opts}</select></label>
      <label><span>Has feature</span><select id="f-feat"><option value="">Any feature</option>{feat_opts}</select></label>
      <label><span>Fact-check</span><select id="f-chk"><option value="">All entries</option><option value="yes">Checked twice</option><option value="no">Sourced once</option></select></label>
      <p class="f-count" id="f-count" aria-live="polite">{len(products)} shown</p>
    </form>
    <div class="tbl-wrap">
      <table class="catalog" id="catalog-table">
        <thead><tr><th>Product</th><th>Category</th><th>Status</th><th>Price</th><th>What stands out</th></tr></thead>
        <tbody>{rows}</tbody>
      </table>
      <p class="empty" id="f-empty" hidden>Nothing matches these filters. Clear one to see more.</p>
      <button type="button" class="more" id="f-more" hidden>Show more</button>
    </div>
  </div>
</section>'''


def watchos_section(tech, apps):
    return f'''
<section id="watchos" class="band">
  <div class="wrap">
    <p class="eyebrow">Research notes</p>
    <h2>Building on watchOS</h2>
    <p class="sub">The two briefs the recommendations are based on: what watchOS lets a third-party app do, and what existing Watch voice apps do and what their users say.</p>
    <details class="brief"><summary>What watchOS allows: background audio, battery, speech, inputs, privacy</summary><div class="prose">{md(tech)}</div></details>
    <details class="brief"><summary>Watch voice apps today, and what users praise and complain about</summary><div class="prose">{md(apps)}</div></details>
  </div>
</section>'''


def risks_section(final):
    risks = ''.join(f'<li>{E(x)}</li>' for x in final['risks_and_open_questions'])
    return f'''
<section id="risks">
  <div class="wrap">
    <h2>Risks and open questions</h2>
    <ul class="ticks">{risks}</ul>
  </div>
</section>'''


def method_section(products, curation, final):
    conf = {k: sum(1 for p in products if p.get('verify_confidence') == k) for k in ('high', 'medium', 'low', 'unchecked')}
    return f'''
<section id="method">
  <div class="wrap">
    <h2>How this was put together</h2>
    <div class="prose narrow">
      <p>Twelve research agents each searched the live web for one part of the market: pendants and pins, recorders, glasses, rings and earbuds, meeting notetakers, voice-note apps, dictation tools, voice assistants, Apple Watch apps, professional scribes, lifelogging platforms, and launches due in the next few months. That produced {curation.get("rawCount", "?")} raw records. Duplicates and off-topic entries were removed, gaps were filled, and records were fact-checked in batches of ten against current sources. Products listed as upcoming, rumored or in beta got one more check that tried to disprove the claimed status and date.</p>
      <p>Of the {len(products)} products, {conf["high"] + conf["medium"] + conf["low"]} were fact-checked a second time: <b>{conf["high"]}</b> with high confidence, <b>{conf["medium"]}</b> medium and <b>{conf["low"]}</b> low. The second check covered every pendant, recorder, ring, watch and earbud, every Apple Watch app, every lifelogging platform, and everything upcoming, rumored, in beta or discontinued. The remaining <b>{conf["unchecked"]}</b> are shipping software (meeting notetakers, scribes, dictation tools, assistants, voice-note apps and glasses) that the research sweep found and sourced but that were not re-checked, because the run reached the account's usage limit. Each catalog entry says which group it is in. {len(curation.get("notFound", []))} records were dropped because they could not be confirmed.</p>
      <p>A feature counts only when a source confirms it, so a missing feature can mean "not documented" as well as "not offered". Prices and dates change often. Check the linked sources before relying on a specific figure.</p>
      <p>Three reviewers drafted the feature sets independently, one focused on user value, one on watchOS feasibility and battery, one on privacy and market position. A fourth merged them, and a final reviewer checked the merged version against the research and fixed what did not hold up.</p>
    </div>
    {review_notes(final)}
  </div>
</section>'''



def review_notes(final):
    notes = split_summary(final['executive_summary'])[3]
    if not notes:
        return ''
    return f'<details class="brief"><summary>Review notes: what changed after critique, and how source conflicts were settled</summary><div class="prose">{"".join(md(n) for n in notes)}</div></details>'


def split_summary(text):
    paras = [p.strip() for p in (text or '').split('\n\n') if p.strip()]
    lead = paras[0] if paras else ''
    opening = next((p for p in paras if p.startswith('The catalog shows')), '')
    risks = next((p for p in paras if p.startswith('The biggest risks')), '')
    review = [p for p in paras if p.startswith('Changes made after review') or p.startswith('Where sources conflicted')]
    return lead, opening, risks, review


def minimal_title(f):
    t = re.sub(r'^\d+\.\s*', '', f)
    cut = 'cut first' in t.lower()
    t = re.sub(r':\s*v1[^:]*cut first\s*$', '', t, flags=re.I).strip()
    return t, cut


def earshot_section():
    path = os.path.join(DATA, 'earshot-comparison.json')
    if not os.path.exists(path):
        return ''
    cmp = json.load(open(path))
    label = {'built': 'Built', 'partly': 'Partly', 'missing': 'Missing'}
    rows = ''.join(f'''
      <tr>
        <td class="e-item">{E(it["minimal"])}</td>
        <td class="e-st"><span class="es es-{it["status"]}"><span class="glyph" aria-hidden="true">{ {"built": "●", "partly": "◐", "missing": "○"}[it["status"]] }</span>{label[it["status"]]}</span></td>
        <td>{E(it["earshot"])}</td>
        <td>{E(it["change"])}</td>
      </tr>''' for it in cmp['items'])
    counts = {k: sum(1 for it in cmp['items'] if it['status'] == k) for k in label}
    beyond = ''.join(f'<li>{E(x)}</li>' for x in cmp['beyond'])
    return f'''
<section id="earshot">
  <div class="wrap">
    <p class="eyebrow">Your build</p>
    <h2>The minimal set against Earshot</h2>
    <p class="sub">Earshot, the always-listening Watch recorder in this repository (PR #3), already does a lot. Checked against its watch code: <b>{counts["built"]}</b> of the {len(cmp["items"])} minimal items are built, <b>{counts["partly"]}</b> are partly there and <b>{counts["missing"]}</b> is missing.</p>
    <div class="tbl-wrap">
      <table class="etable">
        <thead><tr><th>Minimal item</th><th>Earshot</th><th>What it does today</th><th>What to change</th></tr></thead>
        <tbody>{rows}</tbody>
      </table>
    </div>
    <h3>Where Earshot and the recommendation part ways</h3>
    <ul class="ticks">{beyond}</ul>
    <p class="muted small">{E(cmp["source"])}.</p>
  </div>
</section>'''


def feat_title(f):
    m = re.match(r'^(v1[^:]{0,70}):\s*(.+)$', f)
    if m:
        return m.group(2), m.group(1)
    return f, ''

def main():
    products = humanize(load('catalog.json'))
    final = humanize(load('recommendation.json'))
    stats = load('stats.json')
    curation = load('curation.json') if os.path.exists(os.path.join(DATA, 'curation.json')) else {}
    tech = humanize(open(os.path.join(DATA, 'watch-technical.md')).read())
    apps = humanize(open(os.path.join(DATA, 'watch-apps.md')).read())
    names = {p['name'] for p in products}
    body = (masthead(final, stats, products) + '<main>' + watch_section(final) + earshot_section() + feature_set_section(final, names)
            + market_section(final, stats, products) + upcoming_section(products) + catalog_section(products)
            + watchos_section(tech, apps) + risks_section(final) + method_section(products, curation, final) + '</main>')
    tpl = open(os.path.join(HERE, 'template.html')).read()
    out = tpl.replace('<!--BODY-->', body)
    with open(os.path.join(HERE, 'index.html'), 'w') as f:
        f.write(out)
    print('wrote index.html', len(out) // 1024, 'KB,', len(products), 'products')


if __name__ == '__main__':
    main()
