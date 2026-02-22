extends Panel

@onready var title_label: Label = $VBox/Title
@onready var content: RichTextLabel = $VBox/Content

func _ready() -> void:
	title_label.text = "Inventory"
	GameServices.inventory_service.inventory_changed.connect(refresh)
	GameServices.inventory_service.credits_changed.connect(_on_credits_changed)
	refresh()

func refresh() -> void:
	var lines: Array[String] = []
	lines.append("Celador Credits: %d" % GameServices.inventory_service.credits)
	lines.append("-----------------------------")

	var rows = GameServices.inventory_service.get_item_display_rows()
	if rows.is_empty():
		lines.append("No items collected yet.")
	else:
		for row in rows:
			lines.append("%s x%d" % [row["name"], int(row["quantity"])])

	lines.append("")
	lines.append("Active Dust Modifiers")
	lines.append("-----------------------------")
	var modifiers: Dictionary = GameServices.inventory_service.get_active_modifiers()
	if modifiers.is_empty():
		lines.append("None")
	else:
		for stat in modifiers.keys():
			lines.append("%s: %+0.2f" % [stat, float(modifiers[stat])])

	content.text = "\n".join(lines)

func _on_credits_changed(_total: int) -> void:
	refresh()
