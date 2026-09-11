extends "res://scripts/presentation/VegetationArtTrial.gd"
## Isolated local forest comparison, with approved ground and sparse vegetation in both views.

const FOREST_STYLE_PATH := "res://data/presentation/forest_art_trial.json"
const CANDIDATE_FOREST := preload("res://scripts/presentation/environment/TrialForestArtView.gd")
var _forest_a := CANDIDATE_FOREST.new()
var _forest_b := CANDIDATE_FOREST.new()
var _forest_style: Dictionary = {}

func _ready() -> void:
	super._ready()
	_forest_style = _read(FOREST_STYLE_PATH)
	# The forest camera is outside the original ground sample rectangle; share the
	# approved production material on existing plateau meshes as well as the sample plane.
	var ground_material: ShaderMaterial = _trial.make_surface_material()
	_old_ground.get_node("GroundSurface/StationDeepGrassVariation").material_override = ground_material
	for plateau in _old_ground.get_node("FullMapTerrainTopology/DisconnectedPlateaus").get_children():
		plateau.material_override = ground_material
	get_node("OriginalRoads").use_ground_surface_projection()
	var environment := _read("res://data/presentation/environment_art.json")
	environment["approved_forest"] = {"enabled":false}
	var forest: Dictionary = environment.get("terrain_topology",{}).get("forest",{})
	# T0364 compares trees only; use the accepted sparse decorative shrubs as context.
	forest["bushes_per_chunk"] = [0,0]
	_old_ground.get_node("FullMapDenseForest").hide()
	_forest_a.name = "OriginalForestSample"
	_forest_a.use_original_models = true
	_forest_a.style = _forest_style
	_forest_a.configure(environment,_layout)
	add_child(_forest_a)
	_forest_b.name = "CandidateForestSample"
	_forest_b.style = _forest_style
	_forest_b.configure(environment,_layout)
	add_child(_forest_b)
	for button in get_node("ReviewControls").find_children("*","Button",true,false):
		if button.text == "已认可 A":
			button.text = "原树 A"
		elif button.text == "植被试案 B":
			button.text = "新树 B"
		elif button.text == "整体":
			button.text = "林缘"
	var side_button := Button.new()
	side_button.text = "侧看"
	side_button.pressed.connect(func():set_forest_view("side"))
	_label.get_parent().get_child(1).add_child(side_button)
	var dense_button := Button.new()
	dense_button.text = "密林"
	dense_button.pressed.connect(func():set_forest_view("dense"))
	_label.get_parent().get_child(1).add_child(dense_button)
	set_candidate(true)
	set_forest_view("dense")
	if "--capture-forest-trial" in OS.get_cmdline_user_args():
		call_deferred("_capture_forest")

func set_candidate(enabled: bool) -> void:
	super.set_candidate(true)
	_candidate = enabled
	_forest_a.visible = not enabled
	_forest_b.visible = enabled
	_label.text = "T0364  林缘试验 / %s" % ("B · 阔叶、浅皮与针叶混合林" if enabled else "A · 原叠层圆锥树")

func set_review_view(close: bool) -> void:
	set_forest_view("close" if close else "edge")

func set_forest_view(view: String) -> void:
	if _forest_style.is_empty():
		super.set_review_view(false)
		return
	var settings: Dictionary = (_forest_style.get("views",{}) as Dictionary).get(view,{})
	var target_values: Array = settings.get("target",[8.0,0.0,105.0])
	var offset_values: Array = settings.get("offset",[28.0,48.0,57.0])
	var target := Vector3(target_values[0],target_values[1],target_values[2])
	_camera.position = target+Vector3(offset_values[0],offset_values[1],offset_values[2])
	_camera.look_at(target)

func _capture_forest() -> void:
	get_window().size = Vector2i(1280,720)
	var directory := "res://artifacts/visual_qa/t0364"
	DirAccess.make_dir_recursive_absolute(directory)
	for view in ["edge","close","side","dense"]:
		set_forest_view(view)
		for night in [false,true]:
			set_night(night)
			for candidate in [false,true]:
				set_candidate(candidate)
				for frame in 10:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/%s_%s_%s.png" % [directory,view,"night" if night else "day","B" if candidate else "A"])
	var snapshot := _forest_b.get_trial_snapshot()
	snapshot["original_tree_count"] = _forest_a.get_debug_snapshot().total_tree_count
	assert(snapshot.retained_points==snapshot.original_tree_count)
	# Compare actual original GPU instance positions, not just a matching total.
	var original_positions: Array[Vector2] = []
	for node in _forest_a.find_children("*TreePart00","MultiMeshInstance3D",true,false):
		for index in node.multimesh.instance_count:
			var point: Vector3 = _forest_a.to_local(node.to_global(node.multimesh.get_instance_transform(index).origin))
			original_positions.append(Vector2(point.x,point.z))
	assert(original_positions.size()==snapshot.retained_points)
	for point: Vector2 in _forest_b.retained_points:
		var found := false
		for original in original_positions:
			if point.distance_squared_to(original)<0.000001:
				found = true
				break
		assert(found,"Candidate must keep an original tree location")
	snapshot["original_positions_preserved"] = true
	assert(not snapshot.has_collision and not snapshot.has_navigation)
	assert(snapshot.retained_points>0 and snapshot.mesh_variants==6)
	var config: Dictionary = _forest_b._forest_config()
	for point: Vector2 in _forest_b.retained_points:
		assert(_forest_b.source_points.has(point))
		assert(_forest_b._is_forest_point_allowed("front",point,config,true))
	assert(get_node_or_null("/root/Main")==null)
	var file := FileAccess.open(directory+"/snapshot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot,"  "))
	print("T0364_PASS ",JSON.stringify(snapshot))
	get_tree().quit()
