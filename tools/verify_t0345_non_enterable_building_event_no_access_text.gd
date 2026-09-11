extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const PLAZA_WITNESS_ID := "priest_01"

var _failures: PackedStringArray = []
var _building_system: Node
var _memory_system: Node


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(6):
		await process_frame
		await physics_frame

	_building_system = root.get_node_or_null("Main/Systems/BuildingSystem")
	_memory_system = root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(
		_building_system != null
		and _memory_system != null
		and npc_system != null
		and resource_system != null
		and time_system != null,
		"T0345 required systems missing"
	)
	if not _failures.is_empty():
		_finish(main)
		return

	time_system.set_time_scale(0.0)
	npc_system.debug_enter_location_immediately(PLAZA_WITNESS_ID, "plaza")
	for resource_id in ["stone", "wood", "iron"]:
		resource_system.add_resource(resource_id, resource_system.get_resource_remaining_capacity(resource_id))

	await _verify_non_enterable_operation("front_gate", "upgrade")
	await _verify_non_enterable_operation("warehouse", "repair")
	await _verify_non_enterable_operation("main_hall", "repair")
	await _verify_enterable_upgrade_control("dining_hall")
	_finish(main)


func _verify_non_enterable_operation(building_id: String, operation: String) -> void:
	var event_count_before: int = _memory_system.get_all_events().size()
	var witness_count_before: int = _memory_system.get_npc_witness_events(PLAZA_WITNESS_ID).size()
	# 即使历史缓存缺失，静态不可进入实体也不应生成“现在不可进入”的伪变化。
	_memory_system._last_plaza_external_states[building_id] = {}
	if operation == "repair":
		_check(_building_system.debug_damage_building(building_id, 20), "Could not damage %s" % building_id)
		event_count_before = _memory_system.get_all_events().size()
		witness_count_before = _memory_system.get_npc_witness_events(PLAZA_WITNESS_ID).size()
		_memory_system._last_plaza_external_states[building_id] = {}
		_check(_building_system.repair_building(building_id), "Could not start repair for %s" % building_id)
	else:
		_check(_building_system.upgrade_building(building_id), "Could not start upgrade for %s" % building_id)
	await process_frame

	var expected_condition := "repairing" if operation == "repair" else "upgrading"
	var events := _find_operation_events(
		_memory_system.get_all_events(),
		event_count_before,
		building_id,
		expected_condition
	)
	_check(not events.is_empty(), "%s %s start event missing" % [building_id, operation])
	for event in events:
		_assert_no_access_change(event, "%s %s event" % [building_id, operation])

	var witness_events := _find_operation_events(
		_memory_system.get_npc_witness_events(PLAZA_WITNESS_ID),
		witness_count_before,
		building_id,
		expected_condition
	)
	_check(not witness_events.is_empty(), "%s %s witness event missing" % [building_id, operation])
	for event in witness_events:
		_assert_no_access_change(event, "%s %s witness" % [building_id, operation])


func _verify_enterable_upgrade_control(building_id: String) -> void:
	var event_count_before: int = _memory_system.get_all_events().size()
	_check(_building_system.upgrade_building(building_id), "Could not start enterable-building upgrade control")
	await process_frame
	var events := _find_operation_events(
		_memory_system.get_all_events(),
		event_count_before,
		building_id,
		"upgrading"
	)
	_check(not events.is_empty(), "Enterable-building upgrade event missing")
	var saw_access_change := false
	for event in events:
		var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
		var changed_fields: Dictionary = payload.get("changed_fields", {}) if payload.get("changed_fields", {}) is Dictionary else {}
		if (
			changed_fields.has("is_enterable")
			and not bool(changed_fields.get("is_enterable", true))
			and str(event.get("summary", "")).contains("现在不可进入")
		):
			saw_access_change = true
	_check(saw_access_change, "Enterable building lost its upgrade-closure access event")


func _find_operation_events(
	events: Array[Dictionary],
	start_index: int,
	building_id: String,
	expected_condition: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(start_index, events.size()):
		var event: Dictionary = events[index]
		var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
		var changed_fields: Dictionary = payload.get("changed_fields", {}) if payload.get("changed_fields", {}) is Dictionary else {}
		if (
			str(payload.get("reason", "")) == "building_external_state_changed"
			and str(payload.get("building_id", "")) == building_id
			and str(changed_fields.get("condition", "")) == expected_condition
		):
			result.append(event)
	return result


func _assert_no_access_change(event: Dictionary, context: String) -> void:
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	var changed_fields: Dictionary = payload.get("changed_fields", {}) if payload.get("changed_fields", {}) is Dictionary else {}
	var summary := str(event.get("summary", ""))
	_check(not changed_fields.has("is_enterable"), "%s carried is_enterable: %s" % [context, JSON.stringify(event)])
	_check(
		not summary.contains("现在不可进入") and not summary.contains("现在可进入"),
		"%s mentioned access state: %s" % [context, summary]
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish(main: Node) -> void:
	if is_instance_valid(main):
		main.queue_free()
	if _failures.is_empty():
		print("T0345 non-enterable building event access filtering verification passed.")
		quit(0)
	else:
		quit(1)
