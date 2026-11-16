# Bright cartoon town — v1.42

## Visual target

Use the supplied mobile-game screenshot as a **style and colour reference**, not
as a request to change the roadside-business game into a railway game. Keep the
eight existing facilities, portrait play, Persian/English UI, progression and
validated vehicle routes. No assets are taken from the reference screenshot.

The target is a clean, cheerful, low-poly miniature, not a gritty desert diorama:

| Element | Base sRGB colour | Treatment |
| --- | --- | --- |
| Lawn | `#CCE34F` / `#D2E753` | broad, flat lime islands |
| Road | `#8999A8` | cool grey, very low texture contrast |
| Kerbs / markings | `#FFFDF8` | crisp white outlines and crossings |
| Roof | `#F56B13` / `#DF550C` | true pitched geometry, broad tile bands |
| Building plinth | `#53697C` | blue-grey grounding edge |
| Window frame | `#FFE2AD` | chunky warm cream borders |
| Header | `#FF9B38` | flat warm orange |
| Primary / progress | `#139EDB` | clear cyan-blue, no purple branding |
| UI keyline / text | `#29333E` | charcoal outlines and high-contrast labels |

`CartoonPalette` is the shared source for world colours. Six territories retain
small planted-colour variations, without reverting to a brown or purple ground.
Business equipment and signs retain identifying accents.

## Implementation

- `CartoonBuildings` builds gabled roofs, triangular gable walls, thick eaves,
  window frames and blue-grey foundations. Visible building shells remain inside
  the **unchanged 3.4 × 3.2 solid footprint** and 3.9-unit collider height.
- Lawns and white pedestrian strips break up the forecourt. Their upper edge
  stops behind the parking lanes. Props never move the stable bay coordinates.
- Low-poly cottages and trees replace the former canyon wall. They are scenery
  outside the highway, inbound/outbound spines and turning envelopes.
- Neutral daylight with explicit GL Compatibility exposure headroom and matte Lambert materials avoid ochre colour multiplication,
  mirror-like highlights, bloom and expensive screen-space effects.
- Surface maps are deterministic 256 px neutral masks with only faint grain.
  They are generated offline by `tools/build_surface_textures.py`.
- The camera is **orthographic** with a 45° pitch and yaw. Pinch/wheel zoom changes
  `Camera3D.size`; width-preserving projection shows more town vertically on tall phones instead of cropping the gas office. Panning uses the viewport width.
- `UiTheme` uses light cards with dark keylines. Modal labels, disabled states,
  floating badges, cash, quests and manager rarity text are retinted together.
- Five original SVG pictograms in `assets/ui/` replace the tiny emoji-only
  navigation. Buttons keep their existing gameplay actions and touch targets.

## Regression checks

`test_cartoon_style.gd` checks palette families, light-panel text contrast,
physical shell bounds at multiple renovation stages, real gables, material/map
budgets, night-window registration, orthographic zoom and the navigation assets.
The rendered walkthrough asserts that navigation touch targets stay on-screen
and do not overlap in both portrait aspect ratios. It also samples known lawn and road points in the rendered daylight frame, rejecting clipped yellow lawns and washed-out cyan tarmac.

Before shipping, also run the unchanged six-minute physical traffic scenario and
review the rendered day/night, Persian/English and 720 × 1600 device captures.
Unit tests and screenshot rendering are not a substitute for phone GPU testing.
