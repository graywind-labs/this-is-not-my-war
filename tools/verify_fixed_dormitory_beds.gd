extends SceneTree

const DORMITORY_ID := "dormitory"
const BED_TYPE := "dormitory_bed"
const EXPECTED_ASSIGNMENTS := {
	"veteran_deputy_01": "dormitory_bed_01",
	"stableman_01": "dormitory_bed_02",
	"cook_01": "dormitory_bed_03",
	"gardener_01": "dormitory_bed_04",
	"blacksmith_01": "dormitory_bed_05",
	"engineer_01": "dormitory_bed_06",
	"priest_01": "dormitory_bed_07",
	"doctor_01": "dormitory_bed_08"
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
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var panel := root.get_node_or_null("Main/UI/BuildingPanel")
	if building_system == null or npc_system == null or action_system == null or panel == null:
		_fail("Required fixed-bed verification systems are missing")
		return

	if not _verify_configured_assignments(building_system):
		return
	if not _verify_claims_are_stable(building_system):
		return
	if not await _verify_sleep_action_reuses_bed(building_system, npc_system, action_system):
		return
	if not _verify_panel_text(panel):
		return

	print("Fixed dormitory bed assignment verification passed.")
	quit(0)


func _verify_configured_assignments(building_system: Node) -> bool:
	var dormitory: Dictionary = building_system.get_building(DORMITORY_ID)
	var workstations: Array = dormitory.get("workstations", [])
	if workstations.size() != 10:
		_fail("Dormitory should keep exactly 10 beds")
		return false
	for npc_id in EXPECTED_ASSIGNMENTS:
		var expected_bed_id := str(EXPECTED_ASSIGNMENTS[npc_id])
		var bed := _find_workstation(workstations, expected_bed_id)
		if str(bed.get("assigned_npc_id", "")) != npc_id:
			_fail("Narrative arrival assignment mismatch for %s: %s" % [npc_id, bed])
			return false
	for bed_id in ["dormitory_bed_09", "dormitory_bed_10"]:
		var spare_bed := _find_workstation(workstations, bed_id)
		if not str(spare_bed.get("assigned_npc_id", "")).is_empty():
			_fail("Spare bed should not have a fixed NPC assignment: %s" % spare_bed)
			return false
	return true


func _verify_claims_are_stable(building_system: Node) -> bool:
	var out_of_order_ids := [
		"doctor_01",
		"cook_01",
		"veteran_deputy_01",
		"engineer_01",
		"stableman_01",
		"priest_01",
		"blacksmith_01",
		"gardener_01"
	]
	var claimed: Array[Dictionary] = []
	for npc_id in out_of_order_ids:
		var result: Dictionary = building_system.claim_workstation(DORMITORY_ID, npc_id, BED_TYPE)
		if not bool(result.get("ok", false)):
			_fail("Fixed NPC could not claim assigned bed: %s" % result)
			return false
		if str(result.get("workstation_id", "")) != str(EXPECTED_ASSIGNMENTS[npc_id]):
			_fail("Claim order changed fixed bed for %s: %s" % [npc_id, result])
			return false
		claimed.append(result)

	var event_bus := root.get_node_or_null("EventBus")
	if event_bus != null:
		event_bus.set_block_signals(true)
	var spare_result: Dictionary = building_system.claim_workstation(
		DORMITORY_ID,
		"future_resident_01",
		BED_TYPE
	)
	if event_bus != null:
		event_bus.set_block_signals(false)
	if not bool(spare_result.get("ok", false)) or str(spare_result.get("workstation_id", "")) != "dormitory_bed_09":
		_fail("Unassigned future NPC should use the first spare bed: %s" % spare_result)
		return false

	if event_bus != null:
		event_bus.set_block_signals(true)
	building_system.release_workstation(
		DORMITORY_ID,
		"future_resident_01",
		str(spare_result.get("workstation_id", ""))
	)
	if event_bus != null:
		event_bus.set_block_signals(false)
	for result in claimed:
		building_system.release_workstation(
			DORMITORY_ID,
			str(result.get("assigned_npc_id", "")),
			str(result.get("workstation_id", ""))
		)

	for npc_id in out_of_order_ids:
		var repeat_result: Dictionary = building_system.claim_workstation(DORMITORY_ID, npc_id, BED_TYPE)
		if (
			not bool(repeat_result.get("ok", false))
			or str(repeat_result.get("workstation_id", "")) != str(EXPECTED_ASSIGNMENTS[npc_id])
		):
			_fail("Repeated claim changed fixed bed for %s: %s" % [npc_id, repeat_result])
			return false
		building_system.release_workstation(
			DORMITORY_ID,
			npc_id,
			str(repeat_result.get("workstation_id", ""))
		)
	return true


func _verify_sleep_action_reuses_bed(
	building_system: Node,
	npc_system: Node,
	action_system: Node
) -> bool:
	var npc_id := "veteran_deputy_01"
	_set_debug_move_speed(npc_id, 80.0)
	for attempt in range(2):
		npc_system.update_npc_state(npc_id, {
			"fatigue": 70,
			"last_action_result": ""
		})
		if not action_system.debug_assign_sleep(npc_id):
			_fail("Sleep assignment failed on attempt %d" % (attempt + 1))
			return false
		if not await _wait_until_current_action(npc_system, npc_id, "sleep_in_dormitory"):
			_fail("Sleep action did not start on attempt %d" % (attempt + 1))
			return false
		var bed := _find_occupied_workstation(building_system, npc_id)
		if str(bed.get("id", "")) != "dormitory_bed_01":
			_fail("Sleep action did not use Ada's fixed bed on attempt %d: %s" % [
				attempt + 1,
				bed
			])
			return false
		if not action_system.interrupt_npc_action(npc_id, "verify_fixed_bed_repeat", true):
			_fail("Could not interrupt sleep between fixed-bed attempts")
			return false
	return true


func _verify_panel_text(panel: Node) -> bool:
	panel.show_building(DORMITORY_ID)
	var workstation_label := panel.get("workstation_label") as Label
	if workstation_label == null:
		_fail("BuildingPanel workstation label is missing")
		return false
	var expected_lines := [
		"床位1：空闲",
		"床位2：空闲",
		"床位3：空闲",
		"床位4：空闲",
		"床位5：空闲",
		"床位6：空闲",
		"床位7：空闲",
		"床位8：空闲",
		"床位9：空闲",
		"床位10：空闲"
	]
	if workstation_label.text != "\n".join(expected_lines):
		_fail("Dormitory panel should hide fixed ownership and show only live occupancy: %s" % workstation_label.text)
		return false
	if workstation_label.text.contains("专属") or workstation_label.text.contains("空余床位"):
		_fail("Dormitory panel leaked fixed assignment wording: %s" % workstation_label.text)
		return false
	var occupied_text := str(panel._format_workstations([{
		"id": "dormitory_bed_01",
		"type": BED_TYPE,
		"name": "床位1",
		"assigned_npc_id": "veteran_deputy_01",
		"occupied_by": "veteran_deputy_01"
	}]))
	if occupied_text != "床位1：艾达占用中":
		_fail("Occupied fixed bed should use the common live-occupancy wording: %s" % occupied_text)
		return false
	return true


func _find_workstation(workstations: Array, workstation_id: String) -> Dictionary:
	for raw_workstation in workstations:
		if (
			raw_workstation is Dictionary
			and str((raw_workstation as Dictionary).get("id", "")) == workstation_id
		):
			return (raw_workstation as Dictionary).duplicate(true)
	return {}


func _find_occupied_workstation(building_system: Node, npc_id: String) -> Dictionary:
	var dormitory: Dictionary = building_system.get_building(DORMITORY_ID)
	for raw_workstation in dormitory.get("workstations", []):
		if (
			raw_workstation is Dictionary
			and str((raw_workstation as Dictionary).get("occupied_by", "")) == npc_id
		):
			return (raw_workstation as Dictionary).duplicate(true)
	return {}


func _set_debug_move_speed(npc_id: String, speed: float) -> void:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return
	for npc_node in npc_root.get_children():
		if str(npc_node.get_meta("npc_id", "")) == npc_id and "move_speed" in npc_node:
			npc_node.move_speed = speed
			return


func _wait_until_current_action(
	npc_system: Node,
	npc_id: String,
	expected_action: String,
	max_frames: int = 240
) -> bool:
	for _frame in range(max_frames):
		if str(npc_system.get_npc_state(npc_id).get("current_action", "")) == expected_action:
			return true
		await physics_frame
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
