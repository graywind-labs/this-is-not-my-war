extends SceneTree


const MAIN_MENU_SCENE := preload("res://scenes/frontend/MainMenu.tscn")
const EXPECTED_SCREEN_DIRECTIONS := {
	# T0360 applies the user's correction that this authored cover's named left/right
	# directions are mirrored relative to Camera3D projection space.
	"blacksmith_01": Vector2(0.70710678, 0.70710678),
	"cook_01": Vector2(-0.70710678, 0.70710678),
	"gardener_01": Vector2(1.0, 0.0),
	"priest_01": Vector2(-1.0, 0.0),
	"doctor_01": Vector2(-0.70710678, -0.70710678),
	"engineer_01": Vector2(0.70710678, -0.70710678),
}
const EXPECTED_POSITIONS := {
	"veteran_deputy_01": Vector3(7.0, 0.0, 6.0),
	"blacksmith_01": Vector3(10.7, 0.0, 5.45),
	"stableman_01": Vector3(15.15, 0.0, 6.65),
	"cook_01": Vector3(4.15, 0.0, 6.18),
	"gardener_01": Vector3(13.4, 0.0, 3.58),
	"priest_01": Vector3(3.55, 0.0, 3.62),
	"doctor_01": Vector3(6.0, 0.5, 1.07),
	"engineer_01": Vector3(11.0, 0.0, 1.48),
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var menu := MAIN_MENU_SCENE.instantiate() as Control
	root.add_child(menu)
	for _frame in range(100):
		await process_frame
	var cover := menu.find_child("AnimatedMenuCover", true, false) as Node3D
	if cover == null:
		_fail("Formal MainMenu did not instantiate the cover")
		return
	var camera := cover.get_node("Camera3D") as Camera3D
	var set_root := cover.get_node("Set") as Node3D
	var characters := set_root.get_node("Characters") as Node3D
	var cover_snapshot := cover.call("get_preview_snapshot") as Dictionary
	var bindings := cover_snapshot.get("workstation_bindings", {}) as Dictionary
	for npc_id in EXPECTED_SCREEN_DIRECTIONS:
		var character := characters.get_node(npc_id) as Node3D
		var character_snapshot := character.call("debug_get_snapshot") as Dictionary
		var facing: Vector3 = character_snapshot.get("visual_forward", Vector3.ZERO)
		var screen_origin := camera.unproject_position(character.global_position)
		var screen_forward := camera.unproject_position(character.global_position + facing)
		var screen_direction := (screen_forward - screen_origin).normalized()
		var expected: Vector2 = EXPECTED_SCREEN_DIRECTIONS[npc_id]
		if screen_direction.dot(expected) < 0.80:
			_fail("%s screen direction is wrong: actual=%s expected=%s" % [npc_id, screen_direction, expected])
			return
		var target_local: Vector3 = (bindings[npc_id] as Dictionary).get("target", Vector3.ZERO)
		var to_workstation := set_root.to_global(target_local) - character.global_position
		to_workstation.y = 0.0
		facing.y = 0.0
		if to_workstation.normalized().dot(facing.normalized()) < 0.98:
			_fail("%s workstation is not in front after the facing revision" % npc_id)
			return

	for npc_id in EXPECTED_POSITIONS:
		var character := characters.get_node(npc_id) as Node3D
		var expected: Vector3 = EXPECTED_POSITIONS[npc_id]
		if Vector2(character.position.x, character.position.z).distance_to(Vector2(expected.x, expected.z)) > 0.001:
			_fail("%s staging position moved: %s" % [npc_id, character.position])
			return

	var ada := characters.get_node("veteran_deputy_01") as Node3D
	if absf(ada.rotation_degrees.y - 168.0) > 0.01:
		_fail("Ada facing changed unexpectedly")
		return
	var toma := characters.get_node("stableman_01") as Node3D
	var toma_snapshot := toma.call("debug_get_snapshot") as Dictionary
	var toma_facing: Vector3 = toma_snapshot.get("target_facing_direction", Vector3.ZERO)
	var horse := set_root.get_node("StableHorse") as Node3D
	var to_horse := horse.global_position - toma.global_position
	to_horse.y = 0.0
	toma_facing.y = 0.0
	if to_horse.normalized().dot(toma_facing.normalized()) < 0.98:
		_fail("Toma no longer faces the existing horse target")
		return

	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("stop_music"):
		audio_manager.call("stop_music", 0.0)
	menu.queue_free()
	for _frame in range(20):
		await process_frame
	print("T0360_MENU_COVER_OUTWARD_FACING_PASS six=screen_relative ada=unchanged toma=unchanged")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
