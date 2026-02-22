extends Panel

@onready var title_label: Label = $VBox/Title
@onready var listing_list: ItemList = $VBox/Listings
@onready var status_label: Label = $VBox/Status
@onready var buy_qty: SpinBox = $VBox/BuyControls/BuyQty
@onready var buy_button: Button = $VBox/BuyControls/BuyButton
@onready var refresh_button: Button = $VBox/BuyControls/RefreshButton
@onready var sell_item_option: OptionButton = $VBox/SellControls/SellItemOption
@onready var sell_qty: SpinBox = $VBox/SellControls/SellQty
@onready var sell_price: SpinBox = $VBox/SellControls/SellPrice
@onready var sell_button: Button = $VBox/SellControls/SellButton

var _listing_ids: Array = []

func _ready() -> void:
	title_label.text = "Marketplace"
	buy_button.pressed.connect(_on_buy_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	GameServices.marketplace_service.listings_updated.connect(refresh)
	GameServices.inventory_service.inventory_changed.connect(_populate_sell_options)
	GameServices.inventory_service.credits_changed.connect(_on_credits_changed)
	refresh()

func refresh() -> void:
	_listing_ids.clear()
	listing_list.clear()

	var listings = GameServices.marketplace_service.listings()
	for listing in listings:
		var item_id = str(listing.get("item_id", ""))
		var item_def = GameServices.data_service.get_item(item_id)
		var item_name = item_def.get("name", item_id)
		var line = "%s | qty %d | %d CR | seller %s" % [
			item_name,
			int(listing.get("quantity", 0)),
			int(listing.get("unit_price", 0)),
			str(listing.get("seller", "Unknown"))
		]
		listing_list.add_item(line)
		_listing_ids.append(str(listing.get("id", "")))

	if listing_list.item_count > 0:
		listing_list.select(0)
	status_label.text = "Credits: %d" % GameServices.inventory_service.credits
	_populate_sell_options()

func _populate_sell_options() -> void:
	sell_item_option.clear()
	for row in GameServices.inventory_service.get_item_display_rows():
		if int(row["quantity"]) <= 0:
			continue
		sell_item_option.add_item("%s (x%d)" % [row["name"], int(row["quantity"])])
		sell_item_option.set_item_metadata(sell_item_option.item_count - 1, row["id"])

func _on_buy_pressed() -> void:
	var selected = listing_list.get_selected_items()
	if selected.is_empty():
		status_label.text = "Select a listing first."
		return
	var listing_id = _listing_ids[selected[0]]
	var result = GameServices.marketplace_service.buy(listing_id, int(buy_qty.value))
	status_label.text = str(result.get("reason", "Buy failed."))
	refresh()

func _on_sell_pressed() -> void:
	if sell_item_option.item_count == 0:
		status_label.text = "No inventory items to list."
		return
	var idx = sell_item_option.selected
	if idx < 0:
		status_label.text = "Select an item to list."
		return
	var item_id = str(sell_item_option.get_item_metadata(idx))
	var result = GameServices.marketplace_service.sell(item_id, int(sell_qty.value), int(sell_price.value))
	status_label.text = str(result.get("reason", "Sell failed."))
	refresh()

func _on_refresh_pressed() -> void:
	GameServices.marketplace_service.refresh()
	status_label.text = "Listings refreshed."
	refresh()

func _on_credits_changed(_total: int) -> void:
	status_label.text = "Credits: %d" % GameServices.inventory_service.credits
