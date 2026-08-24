extends SceneTree


const NPC_SCENE_PATH := "res://scenes/npc/NPC.tscn"
func _init() -> void:
	var npc_scene := load(NPC_SCENE_PATH) as PackedScene
	if npc_scene == null:
		_fail("Failed to load NPC scene")
		return
	var glen := npc_scene.instantiate()
	root.add_child(glen)
	glen.setup(_make_profile())
	await process_frame
	await process_frame

	var initial: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(str(initial.get("retarget_mode", "")).begins_with("Godot_4_6_RealtimeRetarget"), "Synty/KayKit retarget mode is missing"):
		return
	if not _expect(absf(float(initial.get("source_facing_correction_degrees", 0.0))) > 179.0, "Synty +Z model-forward correction is missing"):
		return

	# The visible wrapper forward must converge on two independent world movement directions.
	glen.move_to_location("east", Vector3(8.0, 0.0, 0.0))
	await create_timer(0.55).timeout
	var east: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(_facing_dot(east, Vector3.RIGHT) > 0.95, "Visible character is not facing east while moving east: %s" % JSON.stringify(east)):
		return
	glen.stop_movement()
	glen.move_to_location("north", glen.global_position + Vector3(0.0, 0.0, -8.0))
	await create_timer(0.55).timeout
	var north: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(_facing_dot(north, Vector3.FORWARD) > 0.95, "Visible character is not facing north while moving north: %s" % JSON.stringify(north)):
		return
	glen.stop_movement()

	var profile := _make_profile()
	profile.states.current_action = "work_blacksmith"
	glen.update_profile(profile)
	await create_timer(0.15).timeout
	var working: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(int(working.get("work_clip_loop_mode", -1)) == Animation.LOOP_LINEAR, "Farm_Harvest instance is not configured as a real looping Animation"):
		return
	if not _expect(float(working.get("work_cycle_length", 0.0)) > 0.5, "Unexpected work clip length"):
		return

	var previous_position := float(working.get("work_cycle_position", -1.0))
	var wrap_count := 0
	for _sample in range(9):
		await create_timer(0.65).timeout
		var sample: Dictionary = glen.debug_get_character_art_snapshot()
		if not _expect(str(sample.get("current_state", "")) == "work", "Work state stopped before authority changed"):
			return
		if not _expect(str(sample.get("hammer_parent", "")) == "RightHand", "Hammer left RightHand during repeated work"):
			return
		var cycle_position := float(sample.get("work_cycle_position", -1.0))
		if cycle_position + 0.25 < previous_position:
			wrap_count += 1
		previous_position = cycle_position
	if not _expect(wrap_count >= 2, "Work animation did not visibly wrap for multiple cycles"):
		return

	print("T0128A character facing and work loop verification passed: wraps=%d" % wrap_count)
	quit(0)


func _facing_dot(snapshot: Dictionary, expected: Vector3) -> float:
	var visual_forward: Vector3 = snapshot.get("visual_forward", Vector3.ZERO)
	return visual_forward.normalized().dot(expected.normalized())


func _make_profile() -> Dictionary:
	return {
		"id": "blacksmith_01",
		"name": "格伦",
		"recruited": false,
		"states": {
			"hp": 125,
			"max_hp": 125,
			"current_action": "idle",
			"behavior_mode": "work",
			"unconscious": false,
			"escaped": false,
			"morale_boost": {},
			"escape_intent": {}
		},
		"equipment": {}
	}


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
