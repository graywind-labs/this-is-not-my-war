extends SceneTree


const SANDBOX_PATH := "res://scenes/art/ArtSandbox.tscn"
const BASELINE_PATH := "res://data/presentation/art_scale_baseline.json"
const SAMPLE_PATHS := [
	"res://assets/3d/quaternius/buildings/wall_plaster_door_round.glb",
	"res://assets/3d/quaternius/props/anvil.glb",
	"res://assets/3d/quaternius/characters/base_male.glb",
	"res://assets/3d/quaternius/characters/male_peasant_outfit.glb",
	"res://assets/3d/quaternius/animations/ual2_standard.glb",
	"res://assets/3d/quaternius/nature/common_tree_a.glb"
]


func _init() -> void:
	for resource_path in SAMPLE_PATHS:
		if load(resource_path) == null:
			_fail("Failed to load representative asset: %s" % resource_path)
			return

	var baseline := _load_json(BASELINE_PATH)
	if baseline.is_empty():
		_fail("Art scale baseline is missing or invalid")
		return
	if not is_equal_approx(float(baseline.world_units.godot_units_per_meter), 1.0):
		_fail("World unit baseline must remain one Godot unit per meter")
		return
	if not is_equal_approx(float(baseline.building.module_grid_m), 2.0):
		_fail("Quaternius building module grid must remain 2 meters")
		return

	var sandbox_scene := load(SANDBOX_PATH) as PackedScene
	if sandbox_scene == null:
		_fail("Failed to load ArtSandbox.tscn")
		return
	var sandbox := sandbox_scene.instantiate()
	root.add_child(sandbox)
	await process_frame
	await process_frame

	var snapshot: Dictionary = sandbox.get_validation_snapshot()
	if not bool(snapshot.get("baseline_loaded", false)):
		_fail("ArtSandbox did not load the presentation baseline")
		return
	if int(snapshot.get("mesh_count", 0)) < 5:
		_fail("Representative samples did not expose enough meshes")
		return
	if int(snapshot.get("skeleton_count", 0)) < 3:
		_fail("Base character, outfit, and animation skeletons were not imported")
		return
	if int(snapshot.get("animation_player_count", 0)) < 1:
		_fail("Universal Animation Library AnimationPlayer is missing")
		return
	if not str(snapshot.get("playing_animation", "")).ends_with("Farm_Harvest"):
		_fail("Representative work animation did not start: %s" % snapshot)
		return

	var character_bounds := _combined_mesh_bounds(sandbox.get_node("Samples/CharacterSample"))
	if character_bounds.size.y < 1.72 or character_bounds.size.y > 1.92:
		_fail("Base male height is outside the accepted range: %.3f" % character_bounds.size.y)
		return
	var building_bounds := _combined_mesh_bounds(sandbox.get_node("Samples/BuildingSample"))
	if building_bounds.size.x < 1.95 or building_bounds.size.x > 2.05:
		_fail("Building module width is not approximately 2 meters: %.3f" % building_bounds.size.x)
		return

	print("T0125 ArtSandbox verification passed: %s" % JSON.stringify(snapshot))
	quit(0)


func _combined_mesh_bounds(root_node: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	for raw_node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_to_root := root_node.global_transform.affine_inverse() * mesh_instance.global_transform
		var bounds := local_to_root * mesh_instance.mesh.get_aabb()
		if initialized:
			result = result.merge(bounds)
		else:
			result = bounds
			initialized = true
	return result


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
