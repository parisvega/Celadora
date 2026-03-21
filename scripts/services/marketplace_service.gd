extends Node

signal listings_updated
signal transaction_completed(result: Dictionary)

var _inventory_service: Node = null
var _data_service: Node = null
var _network_service: Node = null
var _authority_service: Node = null
var _listings: Array = []
var _next_listing_id: int = 1

func setup(inventory_service: Node, data_service: Node, network_service: Node) -> void:
	_inventory_service = inventory_service
	_data_service = data_service
	_network_service = network_service
	_seed_default_listings()

func set_authority_service(authority_service: Node) -> void:
	_authority_service = authority_service

func listings() -> Array:
	return _listings.duplicate(true)

func refresh() -> Array:
	if _authority_service != null and _authority_service.has_method("refresh_market"):
		var result: Dictionary = _authority_service.refresh_market()
		if not result.get("ok", false):
			transaction_completed.emit(result)
		return listings()

	var response: Dictionary = _network_service.fetch_market_listings()
	if response.get("ok", false):
		var payload: Variant = response.get("data", [])
		if typeof(payload) == TYPE_DICTIONARY:
			var listings_payload: Variant = (payload as Dictionary).get("listings", [])
			if typeof(listings_payload) == TYPE_ARRAY:
				_listings = (listings_payload as Array).duplicate(true)
				listings_updated.emit()
		elif typeof(payload) == TYPE_ARRAY and (payload as Array).size() > 0:
			_listings = (payload as Array).duplicate(true)
			listings_updated.emit()
	return listings()

func buy(listing_id: String, quantity: int) -> Dictionary:
	if _authority_service != null and _authority_service.has_method("buy_listing"):
		var authority_result: Dictionary = _authority_service.buy_listing(listing_id, quantity)
		transaction_completed.emit(authority_result)
		return authority_result

	if quantity <= 0:
		return _fail("Quantity must be at least 1.")

	for i in range(_listings.size()):
		var listing: Dictionary = _listings[i]
		if str(listing.get("id", "")) != listing_id:
			continue
		var available = int(listing.get("quantity", 0))
		if available < quantity:
			return _fail("Listing does not have enough stock.")
		var unit_price = int(listing.get("unit_price", 0))
		var total = unit_price * quantity
		if not _inventory_service.spend_credits(total):
			return _fail("Not enough Celador Credits.")

		var item_id = str(listing.get("item_id", ""))
		_inventory_service.add_item(item_id, quantity)

		listing["quantity"] = available - quantity
		if int(listing["quantity"]) <= 0:
			_listings.remove_at(i)
		else:
			_listings[i] = listing
		var buy_event: Dictionary = _network_service.wrap_client_event("market.buy", {
			"listing_id": listing_id,
			"item_id": item_id,
			"quantity": quantity,
			"unit_price": unit_price,
			"total": total
		})
		_network_service.submit_market_order(buy_event)
		GameServices.log_event("market.buy", {
			"listing_id": listing_id,
			"item_id": item_id,
			"quantity": quantity,
			"unit_price": unit_price,
			"total": total
		})
		listings_updated.emit()
		var result = {"ok": true, "reason": "Purchased %d x %s" % [quantity, item_id]}
		transaction_completed.emit(result)
		return result

	return _fail("Listing not found.")

func sell(item_id: String, quantity: int, unit_price: int) -> Dictionary:
	if _authority_service != null and _authority_service.has_method("sell_item"):
		var authority_result: Dictionary = _authority_service.sell_item(item_id, quantity, unit_price)
		transaction_completed.emit(authority_result)
		return authority_result

	if quantity <= 0:
		return _fail("Quantity must be at least 1.")
	if unit_price <= 0:
		return _fail("Unit price must be positive.")
	if _data_service.get_item(item_id).is_empty():
		return _fail("Unknown item ID.")
	if not _inventory_service.remove_item(item_id, quantity):
		return _fail("You do not have enough of this item.")

	var listing = {
		"id": _next_id(),
		"item_id": item_id,
		"quantity": quantity,
		"unit_price": unit_price,
		"seller": "Player"
	}
	_listings.append(listing)
	var sell_event: Dictionary = _network_service.wrap_client_event("market.sell", {
		"listing_id": listing["id"],
		"item_id": item_id,
		"quantity": quantity,
		"unit_price": unit_price
	})
	_network_service.submit_market_order(sell_event)
	GameServices.log_event("market.sell", {
		"listing_id": listing["id"],
		"item_id": item_id,
		"quantity": quantity,
		"unit_price": unit_price
	})
	listings_updated.emit()
	var result = {"ok": true, "reason": "Listed %d x %s" % [quantity, item_id], "listing": listing}
	transaction_completed.emit(result)
	return result

func serialize_state() -> Dictionary:
	return {
		"listings": _listings.duplicate(true),
		"next_listing_id": _next_listing_id
	}

func load_state(state: Dictionary) -> void:
	_listings = state.get("listings", []).duplicate(true)
	_next_listing_id = int(state.get("next_listing_id", max(_next_listing_id, 1)))
	if _listings.is_empty():
		_seed_default_listings()
	else:
		listings_updated.emit()

func apply_authoritative_state(state: Dictionary) -> void:
	if typeof(state) != TYPE_DICTIONARY:
		return
	_listings = state.get("listings", []).duplicate(true)
	_next_listing_id = max(1, int(state.get("next_listing_id", 1)))
	listings_updated.emit()

func _seed_default_listings() -> void:
	if not _listings.is_empty():
		return
	_listings = [
		{"id": _next_id(), "item_id": "dust_blue", "quantity": 12, "unit_price": 7, "seller": "Frontier Guild"},
		{"id": _next_id(), "item_id": "energy_crystal", "quantity": 6, "unit_price": 20, "seller": "Makuna Exchange"},
		{"id": _next_id(), "item_id": "alloy", "quantity": 3, "unit_price": 50, "seller": "Ridge Smithy"}
	]
	listings_updated.emit()

func _next_id() -> String:
	var id = "listing_%d" % _next_listing_id
	_next_listing_id += 1
	return id

func _fail(reason: String) -> Dictionary:
	var result = {"ok": false, "reason": reason}
	transaction_completed.emit(result)
	return result
