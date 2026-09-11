extends SceneTree


const DOCTOR_ID := "doctor_01"
const PATIENT_IDS: Array[String] = ["cook_01", "gardener_01"]


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	var plan_system := main.get_node_or_null("Systems/DailyPlanSystem")
	if plan_system != null:
		plan_system.set_auto_execution_enabled(false)
	root.add_child(main)
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var event_bus := root.get_node_or_null("EventBus")
	if action_system == null or npc_system == null or time_system == null or event_bus == null:
		_fail("clinic round dependencies unavailable")
		return
	time_system.set_current_time(1, 7, 2, 0)
	time_system.set_paused(false)

	if not _verify_bed_facing_contract():
		return
	_set_move_speed(npc_system, DOCTOR_ID, 8.0)
	for patient_id in PATIENT_IDS:
		_set_move_speed(npc_system, patient_id, 8.0)

	if not action_system.debug_assign_action(DOCTOR_ID, "work_clinic_doctor"):
		_fail("doctor duty rejected")
		return
	if not await _wait_for_active(action_system, DOCTOR_ID, "work_clinic_doctor"):
		_fail("doctor did not reach the clinic desk")
		return
	if not _verify_study_pose(npc_system):
		return

	for patient_id in PATIENT_IDS:
		npc_system.update_npc_state(patient_id, {
			"hp": 20,
			"max_hp": 100,
			"unconscious": false,
			"last_action_result": ""
		})
		if not action_system.debug_assign_action(patient_id, "receive_clinic_treatment"):
			_fail("patient route rejected: %s" % patient_id)
			return
		if not await _wait_for_active(action_system, patient_id, "receive_clinic_treatment"):
			_fail("patient did not occupy a clinic bed: %s" % patient_id)
			return

	var first_target := await _wait_for_treatment_target(npc_system)
	if first_target.is_empty() or not PATIENT_IDS.has(first_target):
		_fail("doctor never reached an occupied bedside: %s" % str({"state": npc_system.get_npc_state(DOCTOR_ID), "active": action_system.get("_active_actions").get(DOCTOR_ID, {})}))
		return
	var treatment_art: Dictionary = _get_npc_node(npc_system, DOCTOR_ID).debug_get_character_art_snapshot()
	if str(treatment_art.get("desired_state", "")) != "medical_treatment" or not bool(treatment_art.get("medical_bandage_visible", false)):
		_fail("bedside duty did not show the treatment animation and bandage: %s" % str({"desired": treatment_art.get("desired_state", ""), "current": treatment_art.get("current_state", ""), "moving": treatment_art.get("logical_moving", null), "bandage": treatment_art.get("medical_bandage_visible", null), "book": treatment_art.get("medical_book_visible", null), "pose": treatment_art.get("spatial_attachment_pose", "")}))
		return
	if not await _verify_treatment_pose(npc_system, first_target):
		return

	event_bus.logical_time_tick.emit(301.0, 1.0)
	await physics_frame
	if not _verify_doctor_detached_for_travel(npc_system):
		return
	var second_target := await _wait_for_treatment_target(npc_system, first_target)
	if second_target.is_empty() or second_target == first_target:
		_fail("doctor did not rotate between occupied beds")
		return
	if not await _verify_treatment_pose(npc_system, second_target):
		return

	for patient_id in PATIENT_IDS:
		action_system.interrupt_npc_action(patient_id, "t0130_p7r_cleanup", true)
	event_bus.logical_time_tick.emit(1.0, 1.0)
	if not await _wait_for_study_pose(npc_system):
		_fail("doctor did not return to the study chair after the beds became empty")
		return

	print("T0130-P7R clinic bed direction and doctor rounds verification passed.")
	quit(0)


func _verify_bed_facing_contract() -> bool:
	var file := FileAccess.open("res://data/building_fixture_layouts.json", FileAccess.READ)
	if file == null:
		_fail("building fixture layout unavailable")
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("building fixture layout invalid")
		return false
	var clinic: Dictionary = parsed.get("buildings", {}).get("clinic", {})
	var checked := 0
	for raw_fixture in clinic.get("fixtures", []):
		if not raw_fixture is Dictionary:
			continue
		var fixture: Dictionary = raw_fixture
		if str(fixture.get("kind", "")) != "clinic_bed":
			continue
		var anchor: Dictionary = fixture.get("occupant_anchor", {})
		if str(anchor.get("pose", "")) != "lying_supine" or not is_equal_approx(float(anchor.get("facing_degrees", 0.0)), 180.0):
			_fail("clinic bed head/feet facing was not corrected: %s" % str(fixture.get("id", "")))
			return false
		checked += 1
	if checked != 4:
		_fail("expected four audited clinic bed anchors, got %d" % checked)
		return false
	return true


func _verify_study_pose(npc_system: Node) -> bool:
	var npc_node := _get_npc_node(npc_system, DOCTOR_ID)
	var attachment: Dictionary = npc_node.debug_get_spatial_attachment_snapshot()
	var art: Dictionary = npc_node.debug_get_character_art_snapshot()
	if not bool(attachment.get("active", false)) or str(attachment.get("pose", "")) != "seated_study":
		_fail("empty-clinic doctor was not attached to the study chair")
		return false
	if str(art.get("desired_state", "")) != "seated_study" or str(art.get("current_clip", "")) != "Seated_Study_Idle" or not bool(art.get("medical_book_visible", false)) or bool(art.get("medical_bandage_visible", true)):
		_fail("empty-clinic doctor did not sit and read: %s" % str({"state": art.get("desired_state", ""), "book": art.get("medical_book_visible", null), "pose": art.get("spatial_attachment_pose", "")}))
		return false
	var book := npc_node.find_child("MedicalBook", true, false) as Node3D
	var table_forward := Vector3(art.get("target_facing_direction", Vector3.ZERO)).normalized()
	var book_offset: Vector3 = book.global_position - npc_node.global_position if book != null else Vector3.ZERO
	if book == null or book_offset.dot(table_forward) < 0.78 or book_offset.dot(table_forward) > 0.86 or book_offset.y < 0.12 or book_offset.y > 0.18:
		_fail("empty-clinic medical book is not resting on the desk: %s" % str({"book_offset": book_offset, "table_forward": table_forward}))
		return false
	var table_collision := _find_fixture_node("StaticCollision", "doctor_desk_01_table") as StaticBody3D
	var table_shape := table_collision.get_node_or_null("CollisionShape3D") as CollisionShape3D if table_collision != null else null
	if table_shape == null or not table_shape.shape is BoxShape3D:
		_fail("empty-clinic doctor desk collision is unavailable")
		return false
	var table_top_y := table_shape.global_position.y + (table_shape.shape as BoxShape3D).size.y * 0.5
	var book_table_horizontal_distance := Vector2(book.global_position.x, book.global_position.z).distance_to(Vector2(table_collision.global_position.x, table_collision.global_position.z))
	if book_table_horizontal_distance > 0.01 or absf(book.global_position.y - table_top_y) > 0.01:
		_fail("empty-clinic medical book must lie on the real desk surface: %s" % str({
			"horizontal_distance": book_table_horizontal_distance,
			"height_delta": absf(book.global_position.y - table_top_y)
		}))
		return false
	return true


func _find_fixture_node(branch_name: String, fixture_id: String) -> Node:
	var branch := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Clinic/FixtureLayout/%s" % branch_name)
	if branch == null:
		return null
	for child in branch.get_children():
		if str(child.get_meta("fixture_id", "")) == fixture_id:
			return child
	return null


func _verify_treatment_pose(npc_system: Node, patient_id: String) -> bool:
	var doctor_node := _get_npc_node(npc_system, DOCTOR_ID) as Node3D
	var patient_node := _get_npc_node(npc_system, patient_id) as Node3D
	var attachment: Dictionary = doctor_node.debug_get_spatial_attachment_snapshot()
	var horizontal_offset := doctor_node.global_position - patient_node.global_position
	horizontal_offset.y = 0.0
	var bed_side_separation := absf(horizontal_offset.x)
	var bed_longitudinal_offset := absf(horizontal_offset.z)
	var visible_clearance := bed_side_separation - 0.79 - 0.35
	if (
		not bool(attachment.get("active", false))
		or str(attachment.get("pose", "")) != "standing_treatment"
		or bool(attachment.get("body_collision_disabled", true))
		or not bool(attachment.get("interaction_enabled", false))
		or visible_clearance < 0.07
		or visible_clearance > 0.09
		or bed_longitudinal_offset < 0.34
		or bed_longitudinal_offset > 0.36
	):
		_fail("doctor did not attach beside the occupied bed with visible clearance: %s" % str({
			"patient_id": patient_id,
			"distance": horizontal_offset.length(),
			"bed_side_separation": bed_side_separation,
			"bed_longitudinal_offset": bed_longitudinal_offset,
			"visible_clearance": visible_clearance,
			"attachment": attachment
		}))
		return false
	return true


func _verify_doctor_detached_for_travel(npc_system: Node) -> bool:
	var doctor_node := _get_npc_node(npc_system, DOCTOR_ID)
	var attachment: Dictionary = doctor_node.debug_get_spatial_attachment_snapshot()
	if bool(attachment.get("active", false)) or bool(attachment.get("body_collision_disabled", false)):
		_fail("doctor did not restore body collision before changing beds: %s" % str(attachment))
		return false
	return true


func _wait_for_treatment_target(npc_system: Node, excluded_target: String = "", max_frames: int = 900) -> String:
	for _frame in range(max_frames):
		await physics_frame
		var state: Dictionary = npc_system.get_npc_state(DOCTOR_ID)
		var target_id := str(state.get("presentation_clinic_patient_id", ""))
		if (
			str(state.get("presentation_clinic_duty_mode", "")) == "treatment"
			and str(state.get("physical_location_phase", "")) == "clinic_bedside"
			and not target_id.is_empty()
			and target_id != excluded_target
		):
			return target_id
	return ""


func _wait_for_study_pose(npc_system: Node, max_frames: int = 2400) -> bool:
	for _frame in range(max_frames):
		await physics_frame
		var state: Dictionary = npc_system.get_npc_state(DOCTOR_ID)
		var attachment: Dictionary = _get_npc_node(npc_system, DOCTOR_ID).debug_get_spatial_attachment_snapshot()
		if (
			str(state.get("presentation_clinic_duty_mode", "")) == "study"
			and str(state.get("physical_location_phase", "")) == "occupant_anchor"
			and str(attachment.get("pose", "")) == "seated_study"
		):
			return true
	return false


func _wait_for_active(action_system: Node, npc_id: String, action_id: String, max_frames: int = 2400) -> bool:
	for _frame in range(max_frames):
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == action_id:
			return true
	return false


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath("")))


func _set_move_speed(npc_system: Node, npc_id: String, speed: float) -> void:
	var npc_node := _get_npc_node(npc_system, npc_id)
	if npc_node != null:
		npc_node.set("move_speed", speed)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
