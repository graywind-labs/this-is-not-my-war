extends SceneTree


const FORTIFICATION_PATH := "Main/WorldRoot/FormalStationLayout/WallsAndGates/FortificationArt"
const CLICK_CASES := [
	{"id": "front_gate", "path": "GateArt/FrontGateArt", "half_width": 5.2, "height": 5.5, "required_visible_samples": 2},
	{"id": "back_gate", "path": "GateArt/BackGateArt", "half_width": 4.0, "height": 4.0, "required_visible_samples": 0}
]
const GATE_SAMPLE_FACTORS := [
	Vector2(0.0, 0.45), Vector2(-0.75, 0.45), Vector2(0.75, 0.45),
	Vector2(-0.75, 0.8), Vector2(0.75, 0.8), Vector2(0.0, 0.8)
]


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main scene failed to load")
		return
	root.add_child(packed.instantiate())
	await process_frame
	await process_frame

	var fortification := root.get_node_or_null(FORTIFICATION_PATH) as Node3D
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if fortification == null or building_system == null or camera == null:
		_fail("Formal fortification click verification nodes are missing")
		return

	for click_case in CLICK_CASES:
		var target := fortification.get_node_or_null(str(click_case.get("path", ""))) as Node3D
		if target == null:
			_fail("Formal gate art is missing: %s" % str(click_case.get("id", "")))
			return
		var direct_hit: Dictionary = target.get_building_interaction_ray_hit(
			target.to_global(Vector3(0.0, 2.0, 10.0)),
			target.to_global(Vector3(0.0, 2.0, -10.0))
		)
		if str(direct_hit.get("building_id", "")) != str(click_case.get("id", "")):
			_fail("Formal gate has no interaction volume: %s" % str(click_case.get("id", "")))
			return
		var matching_samples := 0
		for factor in GATE_SAMPLE_FACTORS:
			var sample := Vector3(float(click_case.get("half_width", 1.0)) * factor.x, float(click_case.get("height", 1.0)) * factor.y, 0.0)
			var world_point := target.to_global(sample)
			if camera.is_position_behind(world_point):
				continue
			var hit: Dictionary = building_system._pick_building_art_view_at_screen_position(camera.unproject_position(world_point))
			if str(hit.get("building_id", "")) == str(click_case.get("id", "")):
				matching_samples += 1
		if matching_samples < int(click_case.get("required_visible_samples", 0)):
			_fail("Too little visible gate art resolves to its panel: gate=%s samples=%d" % [click_case.get("id", ""), matching_samples])
			return

	var wall_roots: Array[Node3D] = fortification._wall_segment_roots
	if wall_roots.is_empty():
		_fail("Formal wall interaction segments were not built")
		return
	var checked_walls := 0
	for wall_root in wall_roots:
		var length := float(wall_root.get_meta("interaction_length", 0.0))
		if length <= 0.0:
			continue
		var world_point := wall_root.to_global(Vector3(0.0, 1.8, 0.0))
		if camera.is_position_behind(world_point):
			continue
		var hit: Dictionary = building_system._pick_building_art_view_at_screen_position(camera.unproject_position(world_point))
		if str(hit.get("building_id", "")) == "wall":
			checked_walls += 1
	if checked_walls < 4:
		_fail("Too few formal wall segments were click-tested: %d" % checked_walls)
		return

	print("UI debug formal fortification click verification passed: %d wall segments and both gates." % checked_walls)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
