extends "res://scripts/presentation/environment/FormalForestArtView.gd"
## T0364 preview only. Formal placement rules and approved meshes are shared.
const TREE_MESHES := preload("res://scripts/presentation/environment/StylizedTreeMeshes.gd")

var style: Dictionary = {}
var use_original_models := false
var meshes: Array[ArrayMesh] = []
var counts := {"oak_mature":0,"oak_young":0,"birch_mature":0,"birch_young":0,"pine_mature":0,"pine_young":0}
var source_points: Array[Vector2] = []
var retained_points: Array[Vector2] = []
var near_count := 0
var dense_plain_count := 0
var _tree_art: RefCounted

func _build_conifer_variants() -> void:
	if use_original_models:
		super._build_conifer_variants()
		return
	_tree_art = TREE_MESHES.new(style)
	meshes = _tree_art.meshes

func _build_tree_multimeshes(chunk: Node3D, chunk_center: Vector2, side: String, points: Array[Vector2], rng: RandomNumberGenerator, config: Dictionary, chunk_size: float) -> void:
	# Keep the original full-map chunk origin and RNG. Crop whole chunks only,
	# so even the retained transforms consume exactly the original random draws.
	var bounds: Array = style.get("sample_bounds",[-72.0,94.0,54.0,384.0])
	var sample_rect := Rect2(Vector2(bounds[0],bounds[2]),Vector2(bounds[1]-bounds[0],bounds[3]-bounds[2]))
	if not sample_rect.has_point(chunk_center):
		return
	if use_original_models:
		super._build_tree_multimeshes(chunk,chunk_center,side,points,rng,config,chunk_size)
		return
	var groups: Array = [[],[],[],[],[],[]]
	var keys := counts.keys()
	var species_rng: RandomNumberGenerator = _tree_art.make_species_rng(chunk_center)
	var scale_range := _v2(config.get("tree_scale_range",[0.88,1.34]))
	for point in points:
		source_points.append(point)
		var variant: int = _tree_art.choose_variant(point,species_rng)
		var station_distance := _distance_to_station_polygon(point)
		# Keep the formal transform RNG sequence independent from tree-family choices.
		var scale_value := rng.randf_range(scale_range.x,scale_range.y)
		if _density_tier(station_distance)=="far":
			scale_value += float(config.get("far_tree_scale_bonus",0.16))
		if station_distance>100.0:
			dense_plain_count += 1
		elif station_distance<40.0:
			near_count += 1
		var non_uniform := Vector3(scale_value*rng.randf_range(0.88,1.12),scale_value*rng.randf_range(0.94,1.12),scale_value*rng.randf_range(0.88,1.12))
		var basis := Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(non_uniform)
		rng.randi_range(0,2) # Consume the original conifer-choice draw without changing placement.
		groups[variant].append(Transform3D(basis,Vector3(point.x-chunk_center.x,_terrain_height(point),point.y-chunk_center.y)))
		counts[keys[variant]] += 1
		retained_points.append(point)
	_tree_art.build_multimeshes(chunk,groups,GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

func get_trial_snapshot() -> Dictionary:
	return {"counts":counts,"source_points":source_points.size(),"retained_points":retained_points.size(),"near_station_trees":near_count,"deep_forest_trees":dense_plain_count,"mesh_variants":meshes.size(),"has_collision":not find_children("*","CollisionObject3D",true,false).is_empty(),"has_navigation":not find_children("*","NavigationRegion3D",true,false).is_empty(),"production_enabled":false}
