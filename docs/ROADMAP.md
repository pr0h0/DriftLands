# Driftlands roadmap (deferred items)

Agreed with the player on 2026-10-29 after the design audit. The "Do next" batch
(landing marker, night readability, practice/challenge modes, beacon world reaction,
hidden fragments + secret islands, per-level challenges, bounce mushrooms, echo/growing
bridges, prism splitting, resonance bells, compass, button states) is being built now.

## Done since (2026-10-29)
- Photo mode, night-sky constellations, turning causeways + levers, chapter II (Frostveil,
  Sunken Sky, Glass Expanse) with snow/desert/crystal biomes and aurora, Windward Reach landmarks.

## Next up (agreed)
- Main character face/mask rework (in progress), then
- Home menu text readability pass: chapter list descriptions/locked entries are barely readable over the
  3D backdrop (needs stronger backing panel/contrast, larger type).

## Done since (2026-10-30)
- Chapter II expanded to 7 levels and Chapter III (7 levels) added, built with the route kit
  (scripts/levels/level_kit.gd): hops derived from glide physics, auto return vents, auto extras.
  Run `godot --headless -- --level=N --audit` to sanity-check any level.

## Done since (2026-10-30, later)
- Wardrobe (masks/scarves/robes), title island that grows with progress + roaming Wanderer,
  carrying stones and light orbs, beacon-beam ascent ending, collapsing chapter finales with an
  escape timer, lore stones + Journal, difficulty, Endless Flight and three time trials.

## Later: worth doing (real chunks of work)
- **Wind surfing**: curved/spiraling wind currents along splines that carry the glider. Top pick.
- **Tilting islands** (rotation is done as turning causeways; tilting not yet).
- **Charged storm clouds**: warning pulse -> lightning zone -> discharge updraft (storm levels).
- **Ghost replays** of personal-best runs (record sampled transforms); great fit for time trials.
- Gamepad support.
- **More chapter II/III levels**: Hanging Wilds (vertical forest, bounce flora), The First Beacon
  (finale). Vary layouts: not always east/north/west (chapter II still uses three spokes).
- Audit vertical-slice idea: polish Windward Reach to "excellent", then roll standards out.

## Ideas of our own (not yet scheduled)
- Glide reachability preview: faint landing ring while airborne (also a dev tool for level design).
- One landmark silhouette + accent color per major island.
- Visible wind streamlines around updrafts/gusts.
- Shard light trails showing the way back after collection.

## Skip / postpone (and why)
- The Hearth hub: huge for no gameplay. Cheaper version: title-screen island grows with progress.
- Rideable sky creatures: needs real animation. Alternative: creatures leaving updraft trails.
- Light tether / swinging: competes with the glider. Maybe a single-purpose pull anchor.
- Gravity pockets: break the glide-distance intuition.
- Fog islands lit by player light: overlaps day/night platforms.
- Save slots, save migrations, telemetry, browser test automation, data-driven level resources:
  premature at this size.
