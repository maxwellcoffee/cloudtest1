# Build-years trailer

Where to get the RV or travel trailer to live in while the house is built (San Bernardino County's Temporary
Structure Permit), what the setup could look like on the lot, and used and new budgets.

- `blender/` – `rvkit.py` (an aluminum Airstream-style trailer, conventional travel trailers, a fiberglass trailer,
  RV cover, ramada, shade sail, deck, skirting, tanks, solar, shed and the house framing going up; it builds on
  `gazebo-spa/blender/spakit.py`), one script per setup plus a lineup, and `render_all.sh`.
- `renders/` – the finished JPEGs and plan legends.
- `data/research/` – the research behind the page (JSON, with sources).
- `site/` – `build.py` and `content.py` write `index.html` (styles shared with the bathhouse page).

```sh
rv-trailer/blender/render_all.sh
cd rv-trailer/site && python3 build.py ../renders
```

The trailer pad sits at lot coordinates (48, 40), south-east of the house site in land Scheme A.
