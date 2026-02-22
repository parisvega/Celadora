extends Panel

@onready var title_label: Label = $VBox/Title
@onready var entries_list: ItemList = $VBox/EntryList
@onready var body_label: RichTextLabel = $VBox/EntryBody

var _entry_ids: Array = []

func _ready() -> void:
	title_label.text = "Lore Journal"
	entries_list.item_selected.connect(_on_selected)
	GameServices.lore_journal_service.entry_unlocked.connect(_on_unlocked)
	refresh()

func refresh() -> void:
	entries_list.clear()
	_entry_ids.clear()
	var entries: Array = GameServices.lore_journal_service.get_unlocked_entries()
	if entries.is_empty():
		body_label.text = "No entries yet. Explore Celadora's markers to unlock lore."
		return

	for entry in entries:
		_entry_ids.append(entry.get("id", ""))
		entries_list.add_item(str(entry.get("journal_title", entry.get("name", "Unknown"))))

	entries_list.select(0)
	_update_body(0)

func _on_selected(index: int) -> void:
	_update_body(index)

func _update_body(index: int) -> void:
	if index < 0 or index >= _entry_ids.size():
		return
	var location_id: String = _entry_ids[index]
	var entry: Dictionary = GameServices.data_service.get_location(location_id)
	body_label.text = "%s\n\n%s" % [
		entry.get("journal_title", entry.get("name", location_id)),
		entry.get("journal_text", "")
	]

func _on_unlocked(_location_id: String) -> void:
	refresh()
