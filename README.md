# Armor Craft

Design full suits of plate armor and sculpt your own helmet. Built in Godot 4.4 (Compatibility renderer, so it runs in the browser on integrated graphics).

![Suit](docs/suit.png)
![Helmet designer](docs/helmet.png)
![Back](docs/back.png)

**Proportions vs. reference** (left of each pair: reference, right: Armor Craft)

![Proportions](docs/proportions.png)

## v0.4 – modelled pieces

Armour is moving from one procedural suit to **separately modelled pieces** that snap onto the mannequin at sockets. The first is the **hounskull bascinet**, modelled in Blender:

- Pointed skull with the face opening actually cut out, 1.8 mm plate thickness, padded leather lining
- Pig-faced visor with a real eye slit (split by a centre bar) and 51 breath holes, rolled edges everywhere
- Hinge arms, rosette pivot bosses, lining rivets, and vervelles round the rim for the aventail
- Shape keys exported as morphs: **Width, Height, Apex, Snout** (sliders go negative too), plus **Visor Raised** on the hinge

The source is a script, `art/blender/build_helmet_bascinet.py`, so the model rebuilds from numbers; the `.blend` sits next to it for hand-tweaking in Blender. Export goes to `assets/pieces/helmet_bascinet.glb`, and `scripts/pieces/helmet_piece.gd` loads any piece, swaps in the game's steel shader, and drives its morphs.

![Bascinet](docs/bascinet_render.png)

## v0.3 – what's in

Body proportions are measured off the reference (about seven helmets tall, 1.86 m to the bascinet apex) and live as named landmarks at the top of `scripts/suit_builder.gd`: shoulder, elbow, wrist, waist, hem, knee, plus arm and leg centre-lines. Change one number and every piece follows.


**The harness** (modelled on an Italian-style harness, c. 1400–1420), every piece procedural:
- Hounskull bascinet: pointed apex, pig-faced visor with eye slit and breaths, rosette pivots, aventail vervelles
- Mail aventail cape, mail sleeves, mail skirt over a linen arming skirt, mail at the backs of the thighs
- Globose breastplate and backplate with rolled edges, side straps and buckles; two fauld lames
- Rerebraces, couters with fan wings, hinged vambraces, hourglass gauntlets with articulated fingers and thumb
- Cuisses strapped over mail, poleyns with fan wings, greaves with hinge lines, pointed laminated sabatons
- Waist and hip belts with brass buckles, rivets throughout
- Hammered-steel shader (patina, hammer marks) and a four-in-one chainmail shader

**Suit tab:** toggle every plate, mail and cloth group; six finishes (armour steel, polished, blackened, brass, gilded, rusted); optional surcoat and cape with colour picker; Forge Random Suit.

**Helmet tab:** sculpt width, depth, height, dome, apex, taper, brim flare, snout; slit styles (horizontal, split eyes, T-visor, grille) with count/width/thickness/height; pig-face visor, breaths, plume and rolled rim toggles; five presets; Forge Random Helmet.

Drag to orbit, scroll to zoom, tick **Turntable** for a slow spin (good for clips).

## Play in the browser

Every push to `main` builds the web version and deploys it to GitHub Pages
(Settings → Pages → Source: **GitHub Actions**).

## Layout

```
project.godot
scenes/main.tscn          # single root node, everything built in code
scripts/main.gd           # world, materials, camera, UI
scripts/suit_builder.gd   # the full harness, grouped for toggling
scripts/helmet_builder.gd # procedural helmet + hounskull visor
scripts/mesh_kit.gd       # parametric surfaces, rolled edges, rivets
scripts/pieces/           # loaders for modelled pieces (helmet_piece.gd)
assets/pieces/            # exported .glb pieces
art/blender/              # Blender build scripts, .blend sources, preview renderer
shaders/                  # hammered steel + chainmail
.github/workflows/        # web export + Pages deploy
```

## Roadmap ideas

- Plate articulation: overlapping lames that flex at elbow and knee
- Heraldry painter for surcoat and shield
- Customer commissions and a test yard (joust, arrows, mace strikes that dent weak designs)
