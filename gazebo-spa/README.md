# Garden bathhouse plans

Five plans for a Korean-style bathhouse on the Yucca Valley lot: one hot tub under a roof with plants inside, a
cedar sauna a few steps away, a cold plunge, a wash and scrub station and a heated rest platform. The starting
point is the enclosed pool house at The Spring Resort & Spa in Desert Hot Springs; the look follows kwonyin.global
(blush, peach, coral and black, coral lattice).

| Plan | Idea |
|---|---|
| A Spring Glass House | Timber-and-glass pool house (knee wall, glass, slatted band, low roof) around an in-ground tub |
| B Jeongja Bathhouse | Hanok pavilion on a stone platform in three bays: wash, soak, warm ondol floor |
| C Octagon Garden Gazebo | Open 21-ft octagon with a cupola, lattice on the wind side, round tub |
| D Walled Garden Courtyard | Blush plaster walls around a 40 x 40 ft garden, pergola over a cedar tub |
| E Starter Kit | 12 x 12 ft gazebo kit, plug-and-play tub, barrel sauna; moves later |

- `blender/` – `spakit.py` (builders for pavilions, lattice, tubs, saunas, plants; it reuses the land plan's
  `sitekit.py` for the terrain, Joshua trees and sky), one script per plan, `post.py` (plan markers, JPEGs and
  black-and-white heroes) and `render_all.sh`.
- `renders/` – the finished JPEGs and plan legends.
- `data/research/` – the research behind the page (JSON, with sources).
- `site/` – `build.py`, `content.py` and `style.css` write `index.html` (the published page).

Re-render everything (about 1.5 hours on 4 cores), then rebuild the page:

```sh
gazebo-spa/blender/render_all.sh
cd gazebo-spa/site && python3 build.py ../renders
```

The spa sits at lot coordinates (50, 46), south-east of the house in land Scheme A and more than 50 ft from every
Joshua tree. Change `SPA_CENTER` to move it.
