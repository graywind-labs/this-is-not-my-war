extends SceneTree


# T0242 intentionally supersedes T0212's escape-speed contract. Keep this
# historical regression filename to prove configured enemy movement speed can
# no longer move a horse after mounted defeat.
const LAB_SCENE := preload("res://scenes/debug/NPCDevLab.tscn")
const SAMPLE_SECONDS := 1.0
const POSITION_TOLERANCE := 0.001


func _init() -> void:
	root.add_child(LAB_SCENE.instantiate())
	await process_frame
	await process_frame
	var lab := root.get_node_or_null("NPCDevLab")
	if lab == null:
		_fail("NPCDevLab root is missing")
		return
	if not await _verify_unit_stays_at_defeat(lab, "enemy:raider_cavalry"):
		return
	if not await _verify_unit_stays_at_defeat(lab, "enemy:raider_mounted_archer"):
		return
	print("T0212 supersession by T0242 mounted defeat stillness verification passed.")
	quit(0)


func _verify_unit_stays_at_defeat(lab: Node, unit_id: String) -> bool:
	lab.debug_select_unit(unit_id)
	await process_frame
	lab.debug_trigger_action("mounted_shared_defeat")
	await process_frame
	var snapshot: Dictionary = lab.debug_get_snapshot()
	var mounted: Dictionary = snapshot.get("character", {})
	var root_origin := Vector3(mounted.get("root_world_position", Vector3.ZERO))
	var horse_origin := Vector3(mounted.get("horse_world_position", Vector3.ZERO))
	if mounted.has("escape_speed_mps") or mounted.has("escape_target"):
		_fail("%s still exposes retired horse escape authority: %s" % [unit_id, str(mounted)])
		return false
	lab.debug_advance_enemy_mounted_defeat(SAMPLE_SECONDS)
	snapshot = lab.debug_get_snapshot()
	mounted = snapshot.get("character", {})
	if Vector3(mounted.get("root_world_position", Vector3.ZERO)).distance_to(root_origin) > POSITION_TOLERANCE:
		_fail("%s rider root moved after defeat: %s" % [unit_id, str(mounted)])
		return false
	if Vector3(mounted.get("horse_world_position", Vector3.ZERO)).distance_to(horse_origin) > POSITION_TOLERANCE:
		_fail("%s horse moved after defeat: %s" % [unit_id, str(mounted)])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
