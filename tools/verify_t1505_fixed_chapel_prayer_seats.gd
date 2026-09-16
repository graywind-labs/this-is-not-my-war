extends SceneTree

const BUILDING_ID := "chapel"
const WORKSTATION_TYPE := "chapel_prayer_seat"
const ASSIGNED_PRAYER_SEATS := {
	"stableman_01": "chapel_prayer_seat_01",
	"cook_01": "chapel_prayer_seat_02",
	"gardener_01": "chapel_prayer_seat_03",
	"blacksmith_01": "chapel_prayer_seat_04",
	"veteran_deputy_01": "chapel_prayer_seat_05",
	"priest_01": "chapel_prayer_seat_06",
	"doctor_01": "chapel_prayer_seat_07",
	"engineer_01": "chapel_prayer_seat_08",
}


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel")
	var event_bus := root.get_node_or_null("EventBus")
	if building_system == null or building_panel == null or event_bus == null:
		_fail("Required chapel assignment systems are missing")
		return
	var chapel: Dictionary = building_system.get_building(BUILDING_ID)
	var workstations: Array = chapel.get("workstations", [])
	if workstations.size() != 11:
		_fail("Chapel workstation count changed: %d" % workstations.size())
		return

	var by_id := {}
	for raw_workstation in workstations:
		if raw_workstation is Dictionary:
			by_id[str(raw_workstation.get("id", ""))] = raw_workstation
	for raw_npc_id in ASSIGNED_PRAYER_SEATS.keys():
		var npc_id := str(raw_npc_id)
		var workstation_id := str(ASSIGNED_PRAYER_SEATS[npc_id])
		var workstation: Dictionary = by_id.get(workstation_id, {})
		if str(workstation.get("assigned_npc_id", "")) != npc_id:
			_fail("Prayer seat assignment mismatch for %s: %s" % [npc_id, JSON.stringify(workstation)])
			return
	for workstation_id in ["chapel_prayer_seat_09", "chapel_prayer_seat_10"]:
		if not str((by_id.get(workstation_id, {}) as Dictionary).get("assigned_npc_id", "")).is_empty():
			_fail("Expansion prayer seat must remain unassigned: %s" % workstation_id)
			return
	if not str((by_id.get("chapel_altar_01", {}) as Dictionary).get("assigned_npc_id", "")).is_empty():
		_fail("Mass altar must not inherit prayer-seat assignment")
		return

	# BuildingPanel intentionally ignores assigned_npc_id; backend ownership must
	# not change the player-facing workstation list while every seat is empty.
	var unassigned_projection := workstations.duplicate(true)
	for raw_workstation in unassigned_projection:
		if raw_workstation is Dictionary:
			raw_workstation.erase("assigned_npc_id")
	var assigned_text := str(building_panel.call("_format_workstations", workstations))
	var unassigned_text := str(building_panel.call("_format_workstations", unassigned_projection))
	if assigned_text != unassigned_text:
		_fail("Backend prayer-seat assignment leaked into BuildingPanel: %s" % assigned_text)
		return

	for raw_npc_id in ASSIGNED_PRAYER_SEATS.keys():
		var npc_id := str(raw_npc_id)
		var expected_workstation_id := str(ASSIGNED_PRAYER_SEATS[npc_id])
		var reservation: Dictionary = building_system.reserve_workstation(BUILDING_ID, npc_id, WORKSTATION_TYPE)
		if not bool(reservation.get("ok", false)) or str(reservation.get("workstation_id", "")) != expected_workstation_id:
			_fail("NPC did not reserve the assigned prayer seat: %s / %s" % [npc_id, JSON.stringify(reservation)])
			return
		if not building_system.release_workstation_reservation(BUILDING_ID, npc_id, expected_workstation_id):
			_fail("Failed to release assigned prayer-seat reservation for %s" % npc_id)
			return

	var own_seat_excluded: Dictionary = building_system.reserve_workstation(
		BUILDING_ID,
		"gardener_01",
		WORKSTATION_TYPE,
		[ASSIGNED_PRAYER_SEATS["gardener_01"]]
	)
	if bool(own_seat_excluded.get("ok", false)):
		_fail("Assigned NPC incorrectly fell back to another prayer seat")
		return

	# The synthetic future id is intentionally absent from NPCSystem. Suppress the
	# unrelated location-state broadcast while exercising BuildingSystem directly.
	event_bus.set_block_signals(true)
	var future_reservation: Dictionary = building_system.reserve_workstation(BUILDING_ID, "future_npc_01", WORKSTATION_TYPE)
	if (
		not bool(future_reservation.get("ok", false))
		or str(future_reservation.get("workstation_id", "")) != "chapel_prayer_seat_09"
	):
		event_bus.set_block_signals(false)
		_fail("Unassigned future NPC did not use the first expansion seat: %s" % JSON.stringify(future_reservation))
		return
	building_system.release_workstation_reservation(BUILDING_ID, "future_npc_01", "chapel_prayer_seat_09")
	event_bus.set_block_signals(false)

	print("T1505-P6R50 fixed chapel prayer-seat verification passed")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
