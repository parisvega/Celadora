extends Panel

@onready var title_label: Label = $VBox/Title
@onready var recipes_list: ItemList = $VBox/RecipesList
@onready var detail_label: RichTextLabel = $VBox/DetailLabel
@onready var craft_button: Button = $VBox/Controls/CraftButton
@onready var result_label: Label = $VBox/Controls/ResultLabel

var _recipe_ids: Array = []

func _ready() -> void:
	title_label.text = "Crafting"
	recipes_list.item_selected.connect(_on_recipe_selected)
	craft_button.pressed.connect(_on_craft_pressed)
	GameServices.inventory_service.inventory_changed.connect(_on_inventory_changed)
	refresh()

func refresh() -> void:
	_recipe_ids.clear()
	recipes_list.clear()

	var recipes: Array = GameServices.crafting_service.get_recipes()
	recipes.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))
	for recipe in recipes:
		_recipe_ids.append(recipe.get("id", ""))
		recipes_list.add_item(str(recipe.get("name", recipe.get("id", "Recipe"))))

	if recipes_list.item_count > 0:
		recipes_list.select(0)
		_update_detail(0)
	else:
		detail_label.text = "No recipes available."

func _on_recipe_selected(index: int) -> void:
	_update_detail(index)

func _update_detail(index: int) -> void:
	if index < 0 or index >= _recipe_ids.size():
		detail_label.text = ""
		return
	var recipe_id: String = _recipe_ids[index]
	var recipe: Dictionary = GameServices.data_service.get_recipe(recipe_id)
	var lines: Array[String] = []
	lines.append("%s" % recipe.get("name", recipe_id))
	lines.append("Ingredients:")

	var ingredients: Dictionary = recipe.get("ingredients", {})
	for ingredient_id in ingredients.keys():
		var amount = int(ingredients[ingredient_id])
		var item_def = GameServices.data_service.get_item(ingredient_id)
		var item_name = item_def.get("name", ingredient_id)
		var have = GameServices.inventory_service.get_quantity(ingredient_id)
		lines.append("- %s x%d (have %d)" % [item_name, amount, have])

	var special: Dictionary = recipe.get("special", {})
	if int(special.get("distinct_dust_count", 0)) > 0:
		lines.append("- Distinct Moon Dust types: %d" % int(special.get("distinct_dust_count", 0)))

	lines.append("Outputs:")
	var outputs: Dictionary = recipe.get("outputs", {})
	for out_id in outputs.keys():
		var out_item = GameServices.data_service.get_item(out_id)
		var out_name = out_item.get("name", out_id)
		lines.append("- %s x%d" % [out_name, int(outputs[out_id])])

	var can = GameServices.crafting_service.can_craft(recipe_id)
	lines.append("")
	lines.append("Status: %s" % ("Ready" if can.get("ok", false) else can.get("reason", "Not ready")))
	detail_label.text = "\n".join(lines)

func _on_craft_pressed() -> void:
	var selected = recipes_list.get_selected_items()
	if selected.is_empty():
		result_label.text = "Select a recipe first."
		return
	var recipe_id: String = _recipe_ids[selected[0]]
	var result = GameServices.crafting_service.craft(recipe_id)
	result_label.text = str(result.get("reason", "Craft failed."))
	_update_detail(selected[0])

func _on_inventory_changed() -> void:
	var selected = recipes_list.get_selected_items()
	if selected.is_empty():
		return
	_update_detail(selected[0])
