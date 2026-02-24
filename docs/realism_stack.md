# Celadora Realism Stack (Open Source)

This document defines the recommended rendering/content toolchain to move Celadora from prototype visuals to production-grade look while staying permissive/open.

## Integrated in v0.1 now
- Procedural biome terrain shader:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/assets/shaders/terrain_biome.gdshader`
- Water surface shader:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/assets/shaders/celadora_water.gdshader`
- Sky dome shader:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/assets/shaders/celadora_skydome.gdshader`
- World visuals runtime controller:
  - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/world/world_visuals.gd`

## Recommended external OSS tools/libraries
1. [Material Maker](https://github.com/RodZill4/material-maker) (MIT)
   - Use for procedural PBR materials (rock, soil, alloys, ruins surfaces).
2. [Poly Haven](https://polyhaven.com/license) (CC0)
   - Use for HDRIs and high-quality texture packs.
3. [ambientCG](https://ambientcg.com/index.php) (CC0)
   - Use for broad coverage of PBR sets and decals.
4. [Sky3D](https://github.com/TokisanGames/Sky3D) (MIT)
   - Optional upgrade path for richer sky/weather simulation.
5. [Godot SSR Water](https://github.com/marcelb/GodotSSRWater) (MIT)
   - Optional water fidelity upgrade if renderer/perf budget allows.
6. [godot_spatial_gardener](https://github.com/dreadpon/godot_spatial_gardener) (MIT)
   - Optional biome vegetation scattering pipeline.
7. [Basis Universal](https://github.com/BinomialLLC/basis_universal) (Apache-2.0)
   - Optional texture compression pipeline for web/runtime performance.

## Integration strategy
- Keep current runtime procedural fallback as baseline (no external textures required).
- Add texture packs as optional layer under `/assets/textures/` when art direction matures.
- Keep `compatibility` renderer for web-first builds unless explicitly switching to desktop-first Forward+ profile.
- Gate all optional third-party plugin usage behind scene/script seams so removal does not break gameplay.

## DX checklist for visual upgrades
1. Add/modify material data and shader params.
2. Run:
   - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/dev/smoke_check.sh`
3. Export and preview:
   - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/dev/quick_preview.sh 8060`
4. Run objective/browser QA:
   - `/Users/parisvega/Desktop/2 Business/Vega Ventures (100)/Celadora/scripts/qa/run_browser_objective_qa.sh 8060`
