# Armor Craft

Design full suits of plate armor and sculpt your own helmet. Built in Godot 4.4 (Compatibility renderer, so it runs in the browser on integrated graphics).

![Suit](docs/suit.png)
![Helmet designer](docs/helmet.png)

## v0.1 – what's in

**Suit tab**
- Armor stand mannequin with toggleable plates: gorget, cuirass, faulds, pauldrons, arms, gauntlets, legs, sabatons
- Metal finishes: polished steel, blackened steel, brass, gilded, rusted iron
- Cloth layer: surcoat, belt, cape, with a colour picker
- Forge Random Suit

**Helmet tab**
- Procedural helmet shell you can stretch and morph: width, depth, height, dome, taper, brim flare, snout
- Visor styles: horizontal slits, split eyes, T-visor, grille, with count / width / thickness / height sliders
- Presets: Great Helm, Hounskull, Barbute, Sallet, Grilled Bascinet
- Plume and rolled rim extras
- Forge Random Helmet

Drag to orbit, scroll to zoom, tick **Turntable** for a slow spin (good for clips).

## Play in the browser

Every push to `main` builds the web version and deploys it to GitHub Pages
(Settings → Pages → Source: **GitHub Actions**).

## Layout

```
project.godot
scenes/main.tscn          # single root node, everything built in code
scripts/main.gd           # mannequin, armor pieces, camera, UI
scripts/helmet_builder.gd # procedural helmet shell + visor slits
.github/workflows/        # web export + Pages deploy
```

## Roadmap ideas

- Real visor cutting (holes in the mesh) and breaths/vent holes
- Plate articulation: overlapping lames that flex at elbow and knee
- Heraldry painter for surcoat and shield
- Customer commissions and a test yard (joust, arrows, mace strikes that dent weak designs)
