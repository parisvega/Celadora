extends Panel

@onready var title_label: Label = $VBox/Title
@onready var status_label: Label = $VBox/Status
@onready var content_label: RichTextLabel = $VBox/Checklist

const OBJECTIVES = [
	{"id": "collect_dust", "title": "Collect any Moon Dust fragment"},
	{"id": "collect_energy", "title": "Collect an Energy Crystal"},
	{"id": "salvage_bot", "title": "Salvage Greegion Bot Scrap"},
	{"id": "forge_alloy", "title": "Craft Celadora Alloy"},
	{"id": "unlock_lore", "title": "Unlock all 3 lore markers"},
	{"id": "acquire_dream_seed", "title": "Acquire a Dream Seed at night"},
	{"id": "craft_moonblade", "title": "Craft Moonblade (Prototype)"},
	{"id": "prime_ruins_terminal", "title": "Prime the Greegion Ruins terminal"}
]

func _ready() -> void:
	title_label.text = "Objective Checklist"
	GameServices.inventory_service.inventory_changed.connect(refresh)
	GameServices.lore_journal_service.entry_unlocked.connect(_on_lore_unlock)
	GameServices.crafting_service.crafted.connect(_on_crafted)
	GameServices.world_state_changed.connect(_on_world_state_changed)
	GameServices.world_state_reloaded.connect(_on_world_state_reloaded)
	refresh()

func refresh() -> void:
	var lines: Array[String] = []
	var completed: int = 0
	var next_hint: String = ""
	for entry in OBJECTIVES:
		var objective_id: String = str(entry.get("id", ""))
		var done: bool = _is_complete(objective_id)
		if done:
			completed += 1
		elif next_hint.is_empty():
			next_hint = _objective_hint(objective_id)
		var marker: String = "[x]" if done else "[ ]"
		var progress_text: String = _objective_progress_text(objective_id)
		var suffix: String = " [%s]" % progress_text if not progress_text.is_empty() else ""
		lines.append("%s %s%s" % [marker, str(entry.get("title", objective_id)), suffix])

	status_label.text = "Progress: %d/%d" % [completed, OBJECTIVES.size()]
	if completed >= OBJECTIVES.size():
		lines.append("")
		lines.append("All objectives complete. Proceed to expansion milestones.")
	elif not next_hint.is_empty():
		lines.append("")
		lines.append("Next Step: %s" % next_hint)
	content_label.text = _join_lines(lines)

func _is_complete(objective_id: String) -> bool:
	var flag_key: String = _objective_flag_key(objective_id)
	if GameServices.get_world_flag(flag_key, false):
		return true

	var runtime_complete: bool = _is_runtime_complete(objective_id)
	if runtime_complete:
		GameServices.set_world_flag(flag_key, true)
	return runtime_complete

func _is_runtime_complete(objective_id: String) -> bool:
	match objective_id:
		"collect_dust":
			return _count_items_with_tag("dust") >= 1
		"collect_energy":
			return GameServices.inventory_service.get_quantity("energy_crystal") >= 1
		"salvage_bot":
			return GameServices.inventory_service.get_quantity("bot_scrap") >= 1
		"forge_alloy":
			return GameServices.inventory_service.get_quantity("alloy") >= 1
		"unlock_lore":
			return GameServices.lore_journal_service.get_unlocked_ids().size() >= 3
		"acquire_dream_seed":
			return GameServices.inventory_service.get_quantity("dream_seed") >= 1
		"craft_moonblade":
			return GameServices.inventory_service.get_quantity("moonblade_prototype") >= 1
		"prime_ruins_terminal":
			return GameServices.get_world_flag("ruins_terminal_primed", false)
		_:
			return false

func _objective_flag_key(objective_id: String) -> String:
	return "objective_%s_complete" % objective_id

func _objective_progress_text(objective_id: String) -> String:
	match objective_id:
		"collect_dust":
			return "%d/1" % min(_count_items_with_tag("dust"), 1)
		"collect_energy":
			return "%d/1" % min(GameServices.inventory_service.get_quantity("energy_crystal"), 1)
		"salvage_bot":
			return "%d/1" % min(GameServices.inventory_service.get_quantity("bot_scrap"), 1)
		"forge_alloy":
			return "%d/1" % min(GameServices.inventory_service.get_quantity("alloy"), 1)
		"unlock_lore":
			return "%d/3" % min(GameServices.lore_journal_service.get_unlocked_ids().size(), 3)
		"acquire_dream_seed":
			return "%d/1" % min(GameServices.inventory_service.get_quantity("dream_seed"), 1)
		"craft_moonblade":
			return "%d/1" % min(GameServices.inventory_service.get_quantity("moonblade_prototype"), 1)
		"prime_ruins_terminal":
			var missing_count: int = _ruins_requirements_missing_count()
			return "ready" if missing_count == 0 else ("%d req missing" % missing_count)
		_:
			return ""

func _objective_hint(objective_id: String) -> String:
	match objective_id:
		"collect_dust":
			return "Mine nearby moon-dust nodes around spawn."
		"collect_energy":
			return "Mine an energy crystal node (cyan prism deposits)."
		"salvage_bot":
			return "Defeat a Greegion Miner Bot and collect its scrap."
		"forge_alloy":
			return "Open Crafting (C) and craft Celadora Alloy."
		"unlock_lore":
			return "Reach Enok Ridge, Makuna Shore, and Greegion Ruins beacons."
		"acquire_dream_seed":
			return "Wait for night or press F8, then find a Dream Keeper."
		"craft_moonblade":
			return "Craft Moonblade (Prototype) after gathering alloy, crystal, and Dream Seed."
		"prime_ruins_terminal":
			return "Interact with the ruins terminal after crafting Moonblade and unlocking lore."
		_:
			return ""

func _ruins_requirements_missing_count() -> int:
	var terminal: Node = get_tree().get_root().get_node_or_null("Main/World/GreegionRuins/Terminal")
	if terminal != null and terminal.has_method("get_interaction_status"):
		var status: Dictionary = terminal.get_interaction_status()
		return int(status.get("requirements_missing", 0))
	var missing: int = 0
	if GameServices.inventory_service.get_quantity("moonblade_prototype") < 1:
		missing += 1
	if GameServices.lore_journal_service.get_unlocked_ids().size() < 3:
		missing += 1
	return missing

func _count_items_with_tag(tag: String) -> int:
	var total: int = 0
	for row in GameServices.inventory_service.get_item_display_rows():
		var item_id: String = str(row.get("id", ""))
		var item_def: Dictionary = GameServices.data_service.get_item(item_id)
		var tags: Array = item_def.get("tags", [])
		if tags.has(tag):
			total += int(row.get("quantity", 0))
	return total

func _on_lore_unlock(_location_id: String) -> void:
	refresh()

func _on_crafted(_recipe_id: String, _outputs: Dictionary) -> void:
	refresh()

func _on_world_state_changed(_key: String, _value: Variant) -> void:
	refresh()

func _on_world_state_reloaded(_state: Dictionary) -> void:
	refresh()

func _join_lines(lines: Array[String]) -> String:
	if lines.is_empty():
		return ""
	var joined: String = lines[0]
	for i in range(1, lines.size()):
		joined += "\n" + lines[i]
	return joined
