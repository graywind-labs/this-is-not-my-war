extends Node

const RESOURCE_DEFS_FILE := "resource_defs.json"

var _definitions: Dictionary = {}
var _amounts: Dictionary = {}
var _resource_order: Array[String] = []

func initialize() -> void:
	_definitions.clear()
	_amounts.clear()
	_resource_order.clear()

	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		push_error("ResourceSystem requires ConfigLoader autoload.")
		return

	var loaded_defs: Variant = config_loader.load_data_file(RESOURCE_DEFS_FILE, [])
	if not loaded_defs is Array:
		push_error("Resource definitions must be a JSON array: %s" % RESOURCE_DEFS_FILE)
		return

	for raw_definition in loaded_defs:
		if not raw_definition is Dictionary:
			push_error("Skipped invalid resource definition because it is not a dictionary.")
			continue

		var definition: Dictionary = raw_definition
		var resource_id := str(definition.get("id", ""))
		if resource_id.is_empty():
			push_error("Skipped resource definition with empty id.")
			continue

		var min_amount: int = int(definition.get("min_amount", 0))
		var initial_amount: int = max(int(definition.get("initial_amount", 0)), min_amount)
		_definitions[resource_id] = definition.duplicate(true)
		_amounts[resource_id] = initial_amount
		_resource_order.append(resource_id)

	_resource_order.sort_custom(_compare_resource_order)
	_emit_all_resource_changed()


func _ready() -> void:
	initialize()


func get_resource(resource_id: String) -> int:
	if not _amounts.has(resource_id):
		push_warning("Unknown resource id: %s" % resource_id)
		return 0
	return int(_amounts[resource_id])


func get_resource_name(resource_id: String) -> String:
	if not _definitions.has(resource_id):
		return resource_id
	return str(_definitions[resource_id].get("name", resource_id))


func get_resource_definition(resource_id: String) -> Dictionary:
	if not _definitions.has(resource_id):
		return {}
	return _definitions[resource_id].duplicate(true)


func get_resource_ids() -> Array[String]:
	return _resource_order.duplicate()


func get_resource_snapshot() -> Dictionary:
	return _amounts.duplicate()


func add_resource(resource_id: String, amount: int) -> bool:
	if amount == 0:
		return true
	if not _amounts.has(resource_id):
		push_warning("Cannot add unknown resource: %s" % resource_id)
		return false

	var min_amount: int = _get_min_amount(resource_id)
	var next_amount: int = max(get_resource(resource_id) + amount, min_amount)
	if next_amount == get_resource(resource_id):
		return true

	_amounts[resource_id] = next_amount
	_emit_resource_changed(resource_id)
	return true


func can_afford(cost_dict: Dictionary) -> bool:
	for resource_id in cost_dict.keys():
		var required_amount := int(cost_dict[resource_id])
		if required_amount < 0:
			push_warning("Negative resource cost is not allowed: %s" % str(resource_id))
			return false
		if get_resource(str(resource_id)) < required_amount:
			return false
	return true


func spend_resources(cost_dict: Dictionary) -> bool:
	if not can_afford(cost_dict):
		return false

	for resource_id in cost_dict.keys():
		var resource_key := str(resource_id)
		var required_amount := int(cost_dict[resource_id])
		if required_amount == 0:
			continue
		_amounts[resource_key] = get_resource(resource_key) - required_amount
		_emit_resource_changed(resource_key)

	return true


func debug_add_resource(resource_id: String, amount: int) -> bool:
	return add_resource(resource_id, amount)


func debug_spend_resources(cost_dict: Dictionary) -> bool:
	return spend_resources(cost_dict)


func _get_min_amount(resource_id: String) -> int:
	if not _definitions.has(resource_id):
		return 0
	return int(_definitions[resource_id].get("min_amount", 0))


func _compare_resource_order(a: String, b: String) -> bool:
	var a_order := int(_definitions.get(a, {}).get("ui_order", 0))
	var b_order := int(_definitions.get(b, {}).get("ui_order", 0))
	if a_order == b_order:
		return a < b
	return a_order < b_order


func _emit_all_resource_changed() -> void:
	for resource_id in _resource_order:
		_emit_resource_changed(resource_id)


func _emit_resource_changed(resource_id: String) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.resource_changed.emit(resource_id, get_resource(resource_id))
