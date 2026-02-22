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
	{"id": "craft_moonblade", "title": "Craft Moonblade (Prototype)"}
]

func _ready() -> void:
	title_label.text = "Objective Checklist"
	GameServices.inventory_service.inventory_changed.connect(refresh)
	GameServices.lore_journal_service.entry_unlocked.connect(_on_lore_unlock)
	GameServices.crafting_service.crafted.connect(_on_crafted)
	refresh()

func refresh() -> void:
	var lines: Array[String] = []
	var completed: int = 0
	for entry in OBJECTIVES:
		var objective_id: String = str(entry.get("id", ""))
		var done: bool = _is_complete(objective_id)
		if done:
			completed += 1
		var marker: String = "[x]" if done else "[ ]"
		lines.append("%s %s" % [marker, str(entry.get("title", objective_id))])

	status_label.text = "Progress: %d/%d" % [completed, OBJECTIVES.size()]
	if completed >= OBJECTIVES.size():
		lines.append("")
		lines.append("All objectives complete. Proceed to expansion milestones.")
	content_label.text = _join_lines(lines)

func _is_complete(objective_id: String) -> bool:
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
		_:
			return false

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

func _join_lines(lines: Array[String]) -> String:
	if lines.is_empty():
		return ""
	var joined: String = lines[0]
	for i in range(1, lines.size()):
		joined += "\n" + lines[i]
	return joined
