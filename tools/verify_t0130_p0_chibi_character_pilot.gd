extends SceneTree


const GLEN_SCENE := preload("res://scenes/characters/GlenChibiPilot.tscn")
const ENEMY_SCENE := preload("res://scenes/characters/EnemySwordShieldChibiPilot.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("run_verification")


func run_verification() -> void:
	var test_root := Node3D.new()
	root.add_child(test_root)
	var glen := GLEN_SCENE.instantiate()
	var enemy := ENEMY_SCENE.instantiate()
	test_root.add_child(glen)
	test_root.add_child(enemy)
	await process_frame
	await process_frame

	verify_character(glen, "work", "Hammering", "Glen")
	verify_character(enemy, "attack", "Melee_1H_Attack_Slice_Horizontal", "Enemy")
	await create_timer(0.45).timeout
	verify_pose_delivery(glen, "Glen")
	verify_pose_delivery(enemy, "Enemy")
	var glen_work_pose := get_target_arm_pose(glen)
	var enemy_attack_pose := get_target_arm_pose(enemy)
	glen.call("debug_force_animation_state", "idle")
	enemy.call("debug_force_animation_state", "idle")
	await create_timer(0.45).timeout
	var glen_pose_change := glen_work_pose.angle_to(get_target_arm_pose(glen))
	var enemy_pose_change := enemy_attack_pose.angle_to(get_target_arm_pose(enemy))
	print("pose_change Glen=%.4f Enemy=%.4f" % [glen_pose_change, enemy_pose_change])
	check(glen_pose_change > 0.05, "Glen target rig stays in one pose across work and idle")
	check(enemy_pose_change > 0.05, "Enemy target rig stays in one pose across attack and idle")

	if _failures.is_empty():
		print("T0130_P0_VERIFY PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("T0130_P0_VERIFY FAIL count=%d" % _failures.size())
		quit(1)


func verify_character(character: Node, state_name: String, expected_clip: String, label: String) -> void:
	var snapshot: Dictionary = character.call("debug_get_snapshot")
	check(bool(snapshot.get("ready", false)), "%s pilot did not become ready" % label)
	check(int(snapshot.get("available_clip_count", 0)) >= 100, "%s animation library is incomplete: %s" % [label, snapshot])
	var state_result: Dictionary = character.call("debug_force_animation_state", state_name)
	check(bool(state_result.get("ok", true)), "%s rejected state %s: %s" % [label, state_name, state_result])
	check(String(state_result.get("current_clip", "")) == expected_clip, "%s selected the wrong clip: %s" % [label, state_result])
	var collision_shape := character.get_node_or_null("SelectionArea/CollisionShape3D") as CollisionShape3D
	check(collision_shape != null and collision_shape.shape != null and not collision_shape.disabled, "%s selection collision is missing" % label)
	var target_skeleton := character.find_child("TargetSkeleton", true, false) as Skeleton3D
	check(target_skeleton != null and target_skeleton.get_bone_count() == 44, "%s target skeleton contract failed" % label)
	var expected_sockets := 6
	var sockets := 0
	if target_skeleton != null:
		for child in target_skeleton.get_children():
			if child is BoneAttachment3D:
				sockets += 1
	check(sockets == expected_sockets, "%s equipment socket count is %d, expected %d" % [label, sockets, expected_sockets])
	if target_skeleton != null:
		if label == "Glen":
			check(target_skeleton.find_child("Hammer", true, false) != null, "Glen hammer equipment is missing")
		else:
			check(target_skeleton.find_child("Sword", true, false) != null, "Enemy sword equipment is missing")
			check(target_skeleton.find_child("Shield", true, false) != null, "Enemy shield equipment is missing")


func verify_pose_delivery(character: Node, label: String) -> void:
	var source := character.get_node_or_null("SourceRig/Rig_Medium/Skeleton3D") as Skeleton3D
	var target := character.find_child("TargetSkeleton", true, false) as Skeleton3D
	var player := character.get_node_or_null("PilotAnimationPlayer") as AnimationPlayer
	check(source != null and target != null and player != null, "%s pose nodes are missing" % label)
	if source == null or target == null or player == null:
		return
	var source_arm := source.find_bone("RightUpperArm")
	var target_arm := target.find_bone("RightUpperArm")
	var source_delta := source.get_bone_pose_rotation(source_arm).angle_to(Quaternion.IDENTITY) if source_arm >= 0 else 0.0
	var target_delta := target.get_bone_pose_rotation(target_arm).angle_to(Quaternion.IDENTITY) if target_arm >= 0 else 0.0
	print("%s animation=%s position=%.3f source_arm_delta=%.4f target_arm_delta=%.4f" % [
		label,
		player.current_animation,
		player.current_animation_position,
		source_delta,
		target_delta,
	])
	check(player.is_playing(), "%s AnimationPlayer is not playing" % label)
	check(source_delta > 0.01, "%s source rig did not receive animation pose" % label)
	check(target_delta > 0.01, "%s target rig did not receive retargeted pose" % label)


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func get_target_arm_pose(character: Node) -> Quaternion:
	var target := character.find_child("TargetSkeleton", true, false) as Skeleton3D
	if target == null:
		return Quaternion.IDENTITY
	var arm_index := target.find_bone("RightUpperArm")
	return target.get_bone_pose_rotation(arm_index) if arm_index >= 0 else Quaternion.IDENTITY
