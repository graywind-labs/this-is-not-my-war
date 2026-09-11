extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_DEV_LAB_SCENE := preload("res://scenes/debug/NPCDevLab.tscn")
const MOUNTED_PRESENTATION_REFERENCE := preload("res://scripts/presentation/characters/MountedPresentationReference.gd")
const NPC_ID := "veteran_deputy_01"
const DIRECTIONS := [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT]

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in 8:
		await process_frame
		await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var npc := _get_npc_node(npc_system, NPC_ID)
	_check(npc_system != null and npc != null, "T0179 Main rider fixture is unavailable")
	if npc_system != null and npc != null:
		npc.stop_movement()
		npc_system.update_npc_state(NPC_ID, {
			"behavior_mode": "combat",
			"current_action": "combat_ready",
			"combat_mounted": true,
			"unconscious": false,
			"escaped": false,
		})
		await process_frame
		for direction in DIRECTIONS:
			npc.set_facing_direction(direction)
			for _frame in 90:
				await process_frame
			var snapshot: Dictionary = npc.debug_get_character_art_snapshot()
			_assert_main_alignment(snapshot, direction, "settled %s" % direction)

		# Sample every rendered frame during a 180-degree turn. The horse follows the
		# rider's visible facing, so the saddle translation must use that same facing
		# in the same frame instead of waiting for the final target yaw.
		npc.set_facing_direction(Vector3.BACK)
		for _frame in 90:
			await process_frame
		npc.set_facing_direction(Vector3.FORWARD)
		for frame in 36:
			await process_frame
			_assert_main_alignment(npc.debug_get_character_art_snapshot(), Vector3.ZERO, "turn frame %d" % frame)

	main.queue_free()
	for _frame in 3:
		await process_frame

	var lab := NPC_DEV_LAB_SCENE.instantiate()
	root.add_child(lab)
	for _frame in 5:
		await process_frame
	lab.debug_select_unit(NPC_ID)
	lab.debug_set_mode("combat")
	var lab_snapshot: Dictionary = lab.debug_equip("mount", "horse_chestnut_wind")
	_check(bool(lab_snapshot.get("mount_visible", false)), "T0179 NPCDevLab friendly mount fixture is unavailable")
	lab.debug_begin_rotation_drag()
	lab_snapshot = lab.debug_drag_rotation(90.0 / 0.38)
	lab.debug_end_rotation_drag()
	var lab_forward := Vector3(lab_snapshot.get("horse_visible_forward", Vector3.ZERO))
	var expected_lab_offset := MOUNTED_PRESENTATION_REFERENCE.get_friendly_rider_root_offset(lab_forward)
	var actual_lab_offset := Vector3(lab_snapshot.get("character_mount_position", Vector3.ZERO))
	_check(
		actual_lab_offset.distance_to(expected_lab_offset) <= 0.001,
		"T0179 NPCDevLab did not consume the shared direction-aware saddle offset: expected=%s actual=%s snapshot=%s" % [expected_lab_offset, actual_lab_offset, lab_snapshot]
	)

	if _failures.is_empty():
		print("T0179 friendly mounted saddle alignment verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _assert_main_alignment(snapshot: Dictionary, expected_direction: Vector3, label: String) -> void:
	var visible_forward := Vector3(snapshot.get("visual_forward", Vector3.ZERO))
	visible_forward.y = 0.0
	if visible_forward.length_squared() > 0.0001:
		visible_forward = visible_forward.normalized()
	var expected_root := MOUNTED_PRESENTATION_REFERENCE.get_friendly_rider_root_offset(visible_forward)
	var actual_root := Vector3(snapshot.get("formal_combat_mount_root_offset", Vector3.ZERO))
	var seated_offset := Vector3(snapshot.get("mounted_seated_pose_offset", Vector3.ZERO))
	var actual_visual_position := Vector3(snapshot.get("visual_root_local_position", Vector3.ZERO))
	_check(bool(snapshot.get("combat_mount_visual_visible", false)), "%s did not show the formal horse" % label)
	_check(float(snapshot.get("combat_mount_forward_dot", -1.0)) >= 0.999, "%s horse and rider facing diverged: %s" % [label, snapshot])
	_check(actual_root.distance_to(expected_root) <= 0.001, "%s kept the rider root on a fixed parent axis: expected=%s actual=%s" % [label, expected_root, actual_root])
	_check(actual_visual_position.distance_to(actual_root + seated_offset) <= 0.002, "%s did not rotate the complete mounted pose offset: root=%s seated=%s visual=%s" % [label, actual_root, seated_offset, actual_visual_position])
	if expected_direction.length_squared() > 0.5:
		_check(visible_forward.dot(expected_direction.normalized()) >= 0.99, "%s did not settle to the requested direction: visible=%s expected=%s" % [label, visible_forward, expected_direction])


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	if npc_system == null:
		return null
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath("")))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
