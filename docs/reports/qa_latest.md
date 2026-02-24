# Celadora Headless QA Report

- Started: 2026-02-24T05:43:39
- Ended: 2026-02-24T05:43:40
- Result: PASS (23/23 passed)

## Checks

| Check | Status | Severity | Details |
|---|---|---|---|
| main_scene_loads | PASS | critical | {"path":"res://scenes/Main.tscn"} |
| main_nodes_present | PASS | critical | {"hud":true,"player":true,"world":true} |
| camera_and_viewmodel_present | PASS | critical | {"camera":true,"viewmodel":true} |
| camera_renders_viewmodel_layer | PASS | critical | {"cull_mask":3} |
| viewmodel_meshes_ready | PASS | critical | {"arm_left":true,"arm_right":true,"hand_left":true,"hand_right":true,"tool_mesh":true} |
| viewmodel_unshaded_material | PASS | critical | {"shading_mode":0} |
| viewmodel_has_active_tool | PASS | critical | {"active_tool":"miner"} |
| viewmodel_mine_action_animates | PASS | critical | {"before":[30.0000019073486,-14,-6],"delta":15.2180442810059,"during":[15.8167133331299,-8.48427772521973,-6]} |
| viewmodel_points_project_into_view | PASS | critical | {"left_visible":true,"probes":[{"in_bounds":true,"in_front":true,"name":"ArmLeftMesh","screen":[679,920]},{"in_bounds":true,"in_front":true,"name":"ArmRightMesh","screen":[1096,931]},{"in_bounds":true,"in_front":true,"name":"HandLeftMesh","screen":[664,839]},{"in_bounds":true,"in_front":true,"name":"HandRightMesh","screen":[933,875]},{"in_bounds":true,"in_front":true,"name":"ToolMesh","screen":[1067,903]}],"right_visible":true,"viewport":[1280,1280],"visible_points":5} |
| moon_system_spawns_8 | PASS | critical | {"moon_children":8} |
| required_items_loaded | PASS | critical | {} |
| viewmodel_config_loaded | PASS | critical | {} |
| dust_profiles_loaded | PASS | critical | {} |
| dust_colors_match_moons | PASS | critical | {} |
| dust_shapes_are_unique | PASS | critical | {} |
| dust_glow_spectrum_full_range | PASS | critical | {} |
| dust_rarity_exotic_scaling | PASS | critical | {} |
| dust_shape_library_builds | PASS | critical | {} |
| ruins_terminal_present | PASS | critical | {} |
| ruins_terminal_starts_locked | PASS | critical | {} |
| ruins_terminal_can_be_primed | PASS | critical | {} |
| save_load_world_flag_roundtrip | PASS | critical | {} |
| save_legacy_migration | PASS | critical | {} |