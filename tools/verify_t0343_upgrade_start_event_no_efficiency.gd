extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const BUILDING_ID := "dining_hall"
const PLAZA_WITNESS_ID := "priest_01"

var _failures: PackedStringArray = []


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

	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(
		building_system != null
		and memory_system != null
		and npc_system != null
		and resource_system != null
		and time_system != null,
		"T0343 required systems missing"
	)
	if not _failures.is_empty():
		_finish(main)
		return

	time_system.set_time_scale(0.0)
	npc_system.debug_enter_location_immediately(PLAZA_WITNESS_ID, "plaza")
	resource_system.add_resource("stone", 20)
	var event_count_before: int = memory_system.get_all_events().size()
	var witness_count_before: int = memory_system.get_npc_witness_events(PLAZA_WITNESS_ID).size()

	_check(building_system.upgrade_building(BUILDING_ID), "Could not start dining hall upgrade")
	await process_frame

	_check(
		is_zero_approx(building_system.get_building_operational_efficiency(BUILDING_ID)),
		"Upgrade start should still set authoritative building efficiency to zero"
	)
	var matching_events: Array[Dictionary] = []
	var all_events: Array[Dictionary] = memory_system.get_all_events()
	for index in range(event_count_before, all_events.size()):
		var event: Dictionary = all_events[index]
		var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
		if (
			str(payload.get("reason", "")) == "building_external_state_changed"
			and str(payload.get("building_id", "")) == BUILDING_ID
		):
			matching_events.append(event)

	_check(matching_events.size() >= 2, "Upgrade start did not create plaza and building-location state events")
	var saw_plaza_event := false
	var saw_location_event := false
	for event in matching_events:
		var payload: Dictionary = event.get("payload", {})
		var changed_fields: Dictionary = payload.get("changed_fields", {}) if payload.get("changed_fields", {}) is Dictionary else {}
		_check(
			str(changed_fields.get("condition", "")) == "upgrading",
			"Upgrade start event lost condition=upgrading: %s" % JSON.stringify(event)
		)
		_check(
			not changed_fields.has("operational_efficiency"),
			"Upgrade start event still carried operational_efficiency: %s" % JSON.stringify(event)
		)
		_check(
			not str(event.get("summary", "")).contains("运作效率"),
			"Upgrade start summary still mentioned operational efficiency: %s" % str(event.get("summary", ""))
		)
		if str(event.get("type", "")) == "plaza_status_changed":
			saw_plaza_event = true
		elif str(event.get("type", "")) == "location_status_changed":
			saw_location_event = true
	_check(saw_plaza_event, "Upgrade start plaza event missing")
	_check(saw_location_event, "Upgrade start building-location event missing")

	var witness_events: Array[Dictionary] = memory_system.get_npc_witness_events(PLAZA_WITNESS_ID)
	var saw_clean_witness := false
	for index in range(witness_count_before, witness_events.size()):
		var witness: Dictionary = witness_events[index]
		var payload: Dictionary = witness.get("payload", {}) if witness.get("payload", {}) is Dictionary else {}
		if str(payload.get("building_id", "")) != BUILDING_ID:
			continue
		var changed_fields: Dictionary = payload.get("changed_fields", {}) if payload.get("changed_fields", {}) is Dictionary else {}
		if str(changed_fields.get("condition", "")) != "upgrading":
			continue
		saw_clean_witness = (
			not changed_fields.has("operational_efficiency")
			and not str(witness.get("summary", "")).contains("运作效率")
		)
	_check(saw_clean_witness, "Plaza witness did not receive the cleaned upgrade-start event")

	_finish(main)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish(main: Node) -> void:
	if is_instance_valid(main):
		main.queue_free()
	if _failures.is_empty():
		print("T0343 upgrade-start event efficiency filtering verification passed.")
		quit(0)
	else:
		quit(1)
