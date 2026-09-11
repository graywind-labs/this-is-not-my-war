extends SceneTree


const NPC_ID := "veteran_deputy_01"
const ACTION_ID := "friendly_mounted_unconscious"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/debug/NPCDevLab.tscn") as PackedScene
	if packed == null:
		_fail("NPCDevLab.tscn failed to load")
		return
	var lab := packed.instantiate()
	root.add_child(lab)
	for _frame in 8:
		await process_frame

	var snapshot: Dictionary = lab.debug_select_unit(NPC_ID)
	_assert((snapshot.get("disabled_actions", []) as Array).has(ACTION_ID), "friendly mounted fall should require an equipped preview horse")
	snapshot = lab.debug_equip("mount", "horse_chestnut_wind")
	_assert((snapshot.get("usable_actions", []) as Array).has(ACTION_ID), "equipping a friendly preview horse should enable mounted unconsciousness")

	snapshot = lab.debug_trigger_action(ACTION_ID)
	var character := snapshot.get("character", {}) as Dictionary
	_assert(str(snapshot.get("selected_action_id", "")) == ACTION_ID, "mounted unconscious action should be selected")
	_assert(bool(snapshot.get("mount_visible", false)), "the inspection horse should remain visible as the fall's spatial reference")
	_assert(str(snapshot.get("horse_animation", "")) == "Gallop", "the horse should use its departure animation while the rider falls")
	_assert(str(character.get("desired_state", "")) == "mounted_fall", "formal mounted-to-unconscious transition should select mounted_fall")
	_assert(str(character.get("current_clip", "")) == "Death_A", "friendly mounted fall should reuse Death_A")
	_assert(bool(character.get("mounted_fall_active", false)), "friendly mounted fall arc should be active")
	_assert(str(character.get("mounted_fall_phase", "")) == "airborne", "friendly mounted fall should begin airborne")
	var first_trigger_count := int(character.get("mounted_fall_trigger_count", 0))
	_assert(first_trigger_count >= 1, "friendly mounted fall transition should be edge-triggered")

	await create_timer(0.46).timeout
	snapshot = lab.debug_get_snapshot()
	character = snapshot.get("character", {}) as Dictionary
	var progress := float(character.get("mounted_fall_progress", 0.0))
	var offset := Vector3(character.get("presentation_pose_offset", Vector3.ZERO))
	_assert(progress > 0.30 and progress < 0.80, "friendly rider should pass through the formal middle fall phase")
	_assert(absf(offset.x) > 0.10 and offset.y > 0.20, "friendly rider should visibly leave the saddle along the formal sideways arc")

	snapshot = lab.debug_trigger_action(ACTION_ID)
	character = snapshot.get("character", {}) as Dictionary
	_assert(int(character.get("mounted_fall_trigger_count", 0)) == first_trigger_count + 1, "replaying the action should retrigger the formal fall edge")
	_assert(float(character.get("mounted_fall_progress", 1.0)) < 0.15, "replaying should restart near the beginning of the fall")

	snapshot = lab.debug_trigger_action("idle")
	character = snapshot.get("character", {}) as Dictionary
	_assert(str(character.get("current_state", "")) == "vehicle_seated", "leaving the fall action should rebuild a clean mounted idle preview")
	_assert(not bool(character.get("mounted_fall_active", true)), "leaving the fall action should clear its local preview state")

	snapshot = lab.debug_select_unit("enemy:raider_cavalry")
	_assert(not (snapshot.get("usable_actions", []) as Array).has(ACTION_ID), "enemy cavalry should not expose the friendly unconsciousness action")

	if _failures.is_empty():
		print("T0139-D2 NPCDevLab friendly mounted fall verification passed.")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


var _failures: Array[String] = []


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
