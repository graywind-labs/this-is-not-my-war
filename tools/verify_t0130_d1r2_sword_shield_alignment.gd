extends SceneTree


const CASES := [
	{"label": "Glen developer preview", "path": "res://scenes/characters/GlenChibiArtView.tscn", "preview": true},
	{"label": "Ada", "path": "res://scenes/characters/AdaChibiArtView.tscn", "preview": false},
	{"label": "Owen", "path": "res://scenes/characters/OwenChibiArtView.tscn", "preview": true},
	{"label": "sword-shield enemy", "path": "res://scenes/characters/EnemySwordShieldChibiArtView.tscn", "preview": false},
]
const EXPECTED_SWORD_POSITION := Vector3(-0.069310, 0.079340, 0.019445)
const EXPECTED_SHIELD_ROTATION := Vector3(5.079137, 52.49611, 98.10695)


func _init() -> void:
	for case in CASES:
		await _verify_case(case)
	print("PASS: T0130-D1R7 shield hand recess alignment")
	quit(0)


func _verify_case(case: Dictionary) -> void:
	var packed := load(str(case.path)) as PackedScene
	_assert(packed != null, "%s scene should load" % case.label)
	var character := packed.instantiate()
	root.add_child(character)
	for _frame in 8:
		await process_frame
	if bool(case.preview):
		character.debug_set_equipment_preview("sword_shield", true)
	character.debug_force_animation_state("idle")
	for _frame in 8:
		await process_frame
	var snapshot: Dictionary = character.debug_get_snapshot()
	_assert(str(snapshot.get("sword_parent", "")) == "RightHand", "%s sword should follow RightHand" % case.label)
	_assert(str(snapshot.get("shield_parent", "")) == "LeftHand", "%s shield should follow LeftHand" % case.label)
	_assert(absf(float(snapshot.get("sword_grip_hand_distance", 1.0)) - Vector2(0.18, 0.10).length()) < 0.01, "%s sword grip should use the explicit world-down and inward visual correction" % case.label)
	_assert(float(snapshot.get("sword_forward_dot", -1.0)) > 0.98, "%s sword should point along the NPC forward axis" % case.label)
	_assert(absf(float(snapshot.get("sword_blade_up_dot", 1.0))) < 0.03, "%s visible sword blade axis must remain parallel to the ground" % case.label)
	_assert(absf(float(snapshot.get("sword_tip_above_grip", 1.0))) < 0.05, "%s real sword-tip endpoint must stay level with the grip within the mesh's authored depth offset" % case.label)
	_assert(float(snapshot.get("sword_tip_hand_distance", 0.0)) > 0.80, "%s sword blade should extend away from the hand" % case.label)
	_assert(_near_vector(snapshot.get("shield_local_rotation_degrees", Vector3.ZERO), EXPECTED_SHIELD_ROTATION), "%s shield rotation should stay calibrated" % case.label)
	var shield_back_distance := float(snapshot.get("shield_back_hand_distance", -1.0))
	var shield_back_clearance := float(snapshot.get("shield_back_hand_clearance", -1.0))
	var shield_vertical_offset := float(snapshot.get("shield_back_hand_vertical_offset", 1.0))
	_assert(shield_back_clearance > 0.090 and shield_back_clearance < 0.110, "%s left hand should remain safely recessed behind the further-forward shield face" % case.label)
	_assert(shield_vertical_offset < -0.020 and shield_vertical_offset > -0.045, "%s shield back center should sit slightly below the left hand" % case.label)
	_assert(shield_back_distance < 0.115, "%s shield should remain close enough to read as held rather than floating" % case.label)
	var shield_face: Vector3 = snapshot.get("shield_face_normal", Vector3.ZERO)
	var shield_up: Vector3 = snapshot.get("shield_up_axis", Vector3.ZERO)
	_assert(absf(shield_face.y) < 0.25, "%s shield face should be vertical, not horizontal" % case.label)
	_assert(shield_up.dot(Vector3.UP) > 0.95, "%s shield should remain upright" % case.label)
	_assert(float(snapshot.get("shield_face_forward_dot", -1.0)) > 0.98, "%s shield face should point toward the NPC front" % case.label)

	var idle_sword_position: Vector3 = snapshot.get("sword_global_position", Vector3.ZERO)
	var idle_hand_position: Vector3 = snapshot.get("right_hand_global_position", Vector3.ZERO)
	var idle_shield_local_position: Vector3 = snapshot.get("shield_local_position", Vector3.ZERO)
	character.debug_force_animation_state("attack")
	await create_timer(0.28).timeout
	snapshot = character.debug_get_snapshot()
	_assert(absf(float(snapshot.get("sword_grip_hand_distance", 1.0)) - Vector2(0.18, 0.10).length()) < 0.01, "%s attack must preserve the explicit world-down and inward sword correction" % case.label)
	var attack_sword_position: Vector3 = snapshot.get("sword_global_position", Vector3.ZERO)
	var attack_hand_position: Vector3 = snapshot.get("right_hand_global_position", Vector3.ZERO)
	var hand_travel := attack_hand_position - idle_hand_position
	var sword_travel := attack_sword_position - idle_sword_position
	_assert(hand_travel.length() > 0.12, "%s attack sample should contain a visible right-hand swing" % case.label)
	_assert(sword_travel.length() > 0.12, "%s sword must travel with the attacking right hand instead of remaining in the idle world pose" % case.label)
	_assert(sword_travel.normalized().dot(hand_travel.normalized()) > 0.75, "%s sword and right hand should move in the same direction during the swing" % case.label)
	_assert(_near_vector(snapshot.get("shield_local_position", Vector3.ZERO), idle_shield_local_position), "%s attack must keep the approved shield transform relative to LeftHand" % case.label)
	character.queue_free()
	await process_frame


func _near_vector(actual: Vector3, expected: Vector3, tolerance := 0.002) -> bool:
	return actual.distance_to(expected) <= tolerance


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("FAIL: %s" % message)
	quit(1)
	await process_frame
