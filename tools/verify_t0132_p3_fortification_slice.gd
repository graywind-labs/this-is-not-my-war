extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const EXPECTED_CAPACITY := [1, 2, 2, 3, 3, 4]
const REQUIRED_LEVELS := {
	"wall_slot_01": 1,
	"wall_slot_02": 2,
	"wall_slot_03": 4,
	"wall_slot_04": 6
}
const REQUIRED_LATERAL_OFFSETS := {
	"wall_slot_01": -7.6,
	"wall_slot_02": 7.6,
	"wall_slot_03": -13.0,
	"wall_slot_04": 13.0
}
const REQUIRED_WALL_SEGMENTS := {
	"wall_slot_01": "north_west_a",
	"wall_slot_02": "north_east",
	"wall_slot_03": "north_west_a",
	"wall_slot_04": "north_east"
}


func _init() -> void:
	var packed := load(MAIN_PATH) as PackedScene
	if packed == null:
		_fail("T0132-P3 Main scene unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _i in 7:
		await process_frame
		await physics_frame

	var art := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/WallsAndGates/FortificationArt")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var defense_device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	if art == null or controller == null or building_system == null or defense_device_system == null or gm_panel == null:
		_fail("T0132-P3 runtime hierarchy incomplete")
		return
	if str(art.get_meta("art_revision", "")) != "t0132_p3r4_segment_aligned_attachments" or bool(art.get_meta("enemy_gate_trigger", true)):
		_fail("T0132-P3 fortification metadata drifted")
		return

	var base_snapshot: Dictionary = art.call("get_art_slice_snapshot")
	if int(base_snapshot.get("wall_segment_count", 0)) != 14 or not bool(base_snapshot.get("crenellated", false)) or not bool(base_snapshot.get("patrol_walkway", false)):
		_fail("T0132-P3 wall structure contract drifted: %s" % base_snapshot)
		return
	if str(base_snapshot.get("fortification_material_language", "")) != "timber_border_stockade" or str(base_snapshot.get("stone_role", "")) != "low_damp_proof_footing_only":
		_fail("T0132-P3R timber material language drifted: %s" % base_snapshot)
		return
	if art.find_children("TimberCurtain", "MeshInstance3D", true, false).size() != 14 or art.find_children("LowStoneFooting", "MeshInstance3D", true, false).size() != 14:
		_fail("T0132-P3R timber curtain or subordinate footing count drifted")
		return
	for forbidden_name in ["MasonryWall", "StoneCoping", "StoneCorbel", "FallenStone", "FrontWallTimberButtress", "WallIronTie", "FinalIronCoping"]:
		if not art.find_children(forbidden_name, "", true, false).is_empty():
			_fail("T0132-P3R obsolete stone structure remains: %s" % forbidden_name)
			return
	var authoritative_before: Dictionary = building_system.get_building("wall")
	var observed_capacity: Array[int] = []
	for level in range(1, 7):
		var snapshot: Dictionary = art.call("debug_force_visual_level", level)
		var active_count := int(snapshot.get("active_platform_count", -1))
		observed_capacity.append(active_count)
		if active_count != EXPECTED_CAPACITY[level - 1]:
			_fail("T0132-P3 platform capacity drifted at Lv.%d: %s" % [level, snapshot])
			return
		if int(snapshot.get("range_visual_stage", -1)) != (2 if level >= 5 else (1 if level >= 3 else 0)):
			_fail("T0132-P3 range-only visual stage drifted at Lv.%d" % level)
			return
		var platforms: Dictionary = snapshot.get("platforms", {})
		for slot_id in REQUIRED_LEVELS.keys():
			var slot_state := platforms.get(slot_id, {}) as Dictionary
			if bool(slot_state.get("visible", false)) != (level >= int(REQUIRED_LEVELS[slot_id])):
				_fail("T0132-P3 slot visibility drifted: Lv.%d %s" % [level, slot_id])
				return
			var pose: Dictionary = controller.call("get_defense_device_slot_pose", "wall", slot_id)
			if (slot_state.get("global_position", Vector3.ZERO) as Vector3).distance_to(pose.get("position", Vector3.ZERO) as Vector3) > 0.02:
				_fail("T0132-P3 platform does not match deployed device anchor: %s" % slot_id)
				return
			var runtime_slot: Dictionary = defense_device_system.call("get_slot", slot_id)
			if _dict_to_vector3(runtime_slot.get("position", {})).distance_to(slot_state.get("global_position", Vector3.ZERO) as Vector3) > 0.02 or str(runtime_slot.get("building_id", "")) != "wall":
				_fail("T0132-P3R2 runtime device origin does not match wall platform: %s" % slot_id)
				return
			if str(slot_state.get("host_structure", "")) != "front_wall" or absf(float(slot_state.get("lateral_offset_from_gate", 0.0)) - float(REQUIRED_LATERAL_OFFSETS[slot_id])) > 0.01:
				_fail("T0132-P3R2 platform host or lateral offset drifted: %s %s" % [slot_id, slot_state])
				return
			var expected_segment := str(REQUIRED_WALL_SEGMENTS[slot_id])
			var platform_rotation := float(slot_state.get("rotation_y_degrees", 0.0))
			if str(slot_state.get("wall_segment_id", "")) != expected_segment or str(pose.get("wall_segment_id", "")) != expected_segment:
				_fail("T0132-P3R4 platform attached to wrong wall segment: %s %s" % [slot_id, slot_state])
				return
			if (expected_segment == "north_east" and not (platform_rotation > 4.5 and platform_rotation < 7.0)) or (expected_segment == "north_west_a" and not (platform_rotation < -3.5 and platform_rotation > -6.0)):
				_fail("T0132-P3R4 platform rotation does not follow wall tangent: %s %.3f" % [slot_id, platform_rotation])
				return
			if absf(float(runtime_slot.get("rotation_y_degrees", 0.0)) - platform_rotation) > 0.05:
				_fail("T0132-P3R4 runtime device facing does not match wall platform: %s" % slot_id)
				return
	if building_system.get_building("wall") != authoritative_before:
		_fail("T0132-P3 art preview mutated authoritative wall state")
		return
	var attachment_counts := {
		"range_crossbar:north_west_a": 0,
		"range_crossbar:north_east": 0,
		"range_pennant:north_west_a": 0,
		"range_pennant:north_east": 0
	}
	for raw_attachment in art.find_children("*", "MeshInstance3D", true, false):
		var attachment := raw_attachment as MeshInstance3D
		if not attachment.has_meta("wall_attachment_kind"):
			continue
		var kind := str(attachment.get_meta("wall_attachment_kind", ""))
		var segment_id := str(attachment.get_meta("wall_segment_id", ""))
		var key := "%s:%s" % [kind, segment_id]
		if not attachment_counts.has(key):
			_fail("T0132-P3R4 wall attachment has unknown segment: %s" % key)
			return
		var rotation := attachment.rotation_degrees.y
		if (segment_id == "north_east" and not (rotation > 4.5 and rotation < 7.0)) or (segment_id == "north_west_a" and not (rotation < -3.5 and rotation > -6.0)):
			_fail("T0132-P3R4 wall flag/crossbar rotation drifted: %s %.3f" % [key, rotation])
			return
		attachment_counts[key] = int(attachment_counts[key]) + 1
	if attachment_counts != {
	"range_crossbar:north_west_a": 1,
	"range_crossbar:north_east": 1,
	"range_pennant:north_west_a": 2,
	"range_pennant:north_east": 2
	}:
		_fail("T0132-P3R4 wall attachment counts drifted: %s" % attachment_counts)
		return

	var front: Dictionary = art.call("get_gate_snapshot", "front_gate")
	var rear: Dictionary = art.call("get_gate_snapshot", "back_gate")
	if str(front.get("architectural_material", "")) != "timber_gatehouse_with_low_stone_footings" or str(rear.get("stone_role", "")) != "foundation_only":
		_fail("T0132-P3R gatehouse material language drifted: %s / %s" % [front, rear])
		return
	if float(front.get("clear_width", 0.0)) <= float(rear.get("clear_width", 0.0)) or float(front.get("gatehouse_height", 0.0)) <= float(rear.get("gatehouse_height", 0.0)):
		_fail("T0132-P3 front gate is not visibly larger than rear gate: %s / %s" % [front, rear])
		return
	var gatehouse_outer_half_width := float(front.get("gatehouse_outer_half_width", 0.0))
	for slot_id in REQUIRED_LATERAL_OFFSETS.keys():
		var platform_inner_edge := absf(float(REQUIRED_LATERAL_OFFSETS[slot_id])) - 1.8
		if platform_inner_edge <= gatehouse_outer_half_width + 0.25:
			_fail("T0132-P3R2 wall platform intrudes into front gatehouse: %s" % slot_id)
			return
	if absf(float(REQUIRED_LATERAL_OFFSETS["wall_slot_03"]) - float(REQUIRED_LATERAL_OFFSETS["wall_slot_01"])) <= 3.6 or absf(float(REQUIRED_LATERAL_OFFSETS["wall_slot_04"]) - float(REQUIRED_LATERAL_OFFSETS["wall_slot_02"])) <= 3.6:
		_fail("T0132-P3R2 same-side wall platforms overlap")
		return
	if bool(front.get("enemy_can_trigger", true)) or not bool(front.get("blocking_collision", false)) or not bool(rear.get("blocking_collision", false)):
		_fail("T0132-P3 gate trigger or physical collision contract drifted")
		return
	var front_gate := art.get_node_or_null("GateArt/FrontGateArt") as Node3D
	var rear_gate := art.get_node_or_null("GateArt/BackGateArt") as Node3D
	if front_gate == null or rear_gate == null:
		_fail("T0132-P3 gate art nodes missing")
		return
	for gate_node in [front_gate, rear_gate]:
		if str(gate_node.get_meta("art_revision", "")) != "t0132_p3r_timber_stockade":
			_fail("T0132-P3R gate revision metadata drifted")
			return
		for forbidden_name in ["StoneGatePier", "StoneTower", "UpperGuardTower", "BrickTowerFace", "GateLintel"]:
			if not gate_node.find_children(forbidden_name, "", true, false).is_empty():
				_fail("T0132-P3R obsolete stone gate structure remains: %s" % forbidden_name)
				return
		if _count_meta(gate_node, "gate_structure_role", "low_stone_foundation_pad") != 2 or _count_meta(gate_node, "gate_structure_role", "timber_cross_brace") < 4:
			_fail("T0132-P3R timber gate frame incomplete")
			return
	if front_gate.find_children("*", "AnimatableBody3D", true, false).size() != 2 or rear_gate.find_children("*", "AnimatableBody3D", true, false).size() != 2:
		_fail("T0132-P3 physical double door leaves missing")
		return

	var friendly := _make_actor("FriendlyGateProbe", "npc_id")
	root.add_child(friendly)
	friendly.global_position = front_gate.global_position + Vector3(0.0, 0.1, -2.0)
	for _i in 16:
		await physics_frame
	front = art.call("get_gate_snapshot", "front_gate")
	if float(front.get("open_fraction", 0.0)) <= 0.15 or not bool(front.get("friendly_near", false)):
		_fail("T0132-P3 friendly NPC did not open front gate: %s" % front)
		return
	friendly.queue_free()
	await process_frame
	front_gate.call("debug_set_open_fraction", 0.0)
	var enemy := _make_actor("EnemyGateProbe", "enemy_id")
	root.add_child(enemy)
	enemy.global_position = front_gate.global_position + Vector3(0.0, 0.1, -2.0)
	for _i in 16:
		await physics_frame
	front = art.call("get_gate_snapshot", "front_gate")
	if float(front.get("open_fraction", 1.0)) > 0.01 or bool(front.get("friendly_near", true)):
		_fail("T0132-P3 enemy incorrectly triggered front gate: %s" % front)
		return
	enemy.queue_free()

	var walls_root := root.get_node("Main/WorldRoot/FormalStationLayout/WallsAndGates") as Node3D
	var wall_collision_count := 0
	var gate_post_count := 0
	for raw_body in walls_root.find_children("*", "StaticBody3D", true, false):
		var body := raw_body as StaticBody3D
		var category := str(body.get_meta("collision_category", ""))
		if category == "station_wall":
			wall_collision_count += 1
		elif category == "gate_post":
			gate_post_count += 1
	if wall_collision_count != 14 or gate_post_count != 4:
		_fail("T0132-P3 legacy collision baseline drifted: wall=%d gate=%d" % [wall_collision_count, gate_post_count])
		return
	for level in range(1, 7):
		if gm_panel.find_child("WallArtLevel%dButton" % level, true, false) == null:
			_fail("T0132-P3 GM wall preview button missing at Lv.%d" % level)
			return
	if gm_panel.find_child("GateArtSnapshotButton", true, false) == null:
		_fail("T0132-P3 GM gate snapshot button missing")
		return

	var result := {
		"wall_segments": wall_collision_count,
		"gate_posts": gate_post_count,
		"platform_capacity": observed_capacity,
		"front_gate_width": front.get("clear_width", 0.0),
		"rear_gate_width": rear.get("clear_width", 0.0),
		"enemy_trigger_rejected": true
	}
	main.queue_free()
	await process_frame
	print("T0132-P3 fortification slice verification passed: %s" % JSON.stringify(result))
	quit(0)


func _make_actor(node_name: String, identity_meta: String) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = node_name
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta(identity_meta, node_name)
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape_node.position.y = 0.9
	shape_node.shape = capsule
	body.add_child(shape_node)
	return body


func _count_meta(root_node: Node, key: String, expected: Variant) -> int:
	var count := 0
	for child in root_node.find_children("*", "", true, false):
		if child.has_meta(key) and child.get_meta(key) == expected:
			count += 1
	return count


func _dict_to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value as Vector3
	if value is Dictionary:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
