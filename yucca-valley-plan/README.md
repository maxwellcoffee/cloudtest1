# Yucca Valley land plan

Planning workbook for a 5-acre rural lot near Yucca Valley, CA: a solo planning hour and a couple's
meeting built on the GTD Natural Planning Model, verified research, a team list, four site schemes
and a small-house concept, all rendered in headless Blender.

- `site/` – the published page. `template.html` holds the planning sheets, styles and scripts;
  `build.py` + `extra.py` fill in the research digests and renders and write `index.html`.
- `blender/` – the 3D toolkit (`sitekit.py`), one script per site scheme, `house.py`, `floor.py`,
  and `annotate.py`, which adds the numbered, phase-coloured markers, north arrow, scale and key.
- `renders/` – annotated JPEGs and their legends.
- `data/` – the research behind the page: `research/` (one JSON report per topic), `digests/`
  (a second reviewer's claim checks), `edited/` (digests reconciled with `key_rules.md`).

Rebuild the page (copies the annotated renders into `site/img/` and writes `site/index.html`):

```sh
cd site && python3 build.py ../data/research ../data/digests ../renders ../data/edited
```

Re-render everything (Blender 4.2, Cycles on CPU, about 30 minutes on 4 cores):

```sh
blender/render_all.sh
```

Check that no scheme disturbs ground within 50 ft of a Joshua tree (San Bernardino County rule):

```sh
cd blender && YV_CHECK=1 blender -b --python scheme_a_cluster.py -- /tmp/check
```

The modeled lot is a stand-in (660 × 330 ft, ~30 ft of rise to the north, a wash, a knoll). Swap in
the real survey, tree census and perc location by editing `WASH`, `JOSHUA_TREES`, `BOULDERS` and
`base_height()` in `sitekit.py`.
