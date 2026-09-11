extends "res://scripts/presentation/GroundArtTrial.gd"
## T0363 candidate only. Approved T0362 remains the unchanged A comparison.

const VEGETATION_CONFIG := "res://data/presentation/vegetation_art_trial.json"
var _vegetation := Node3D.new()
var _vegetation_config: Dictionary = {}
var _cluster_count := 0
var _detail_count := 0
var _review_material := StandardMaterial3D.new()

func _ready() -> void:
	super._ready()
	_vegetation_config = _read(VEGETATION_CONFIG)
	_vegetation.name = "CandidateVegetation"
	_vegetation.set_meta("presentation_only",true)
	add_child(_vegetation)
	_review_material.vertex_color_use_as_albedo = true
	_review_material.vertex_color_is_srgb = true
	_review_material.roughness = 1.0
	_build_clusters()
	for button in get_node("ReviewControls").find_children("*","Button",true,false):
		if button.text == "原版 A":
			button.text = "已认可 A"
		elif button.text == "试案 B":
			button.text = "植被试案 B"
	set_candidate(true)
	set_review_view(true)
	if "--capture-vegetation-trial" in OS.get_cmdline_user_args():
		call_deferred("_capture_vegetation")

func set_candidate(enabled: bool) -> void:
	_candidate = enabled
	_trial.visible = true
	for node in _hidden_in_trial:
		node.visible = false
	_vegetation.visible = enabled
	_label.text = "T0363  低模植被  /  %s" % ("B · 草丛、矮灌木与碎石组合" if enabled else "A · 已认可地表与草簇")

func _build_clusters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_vegetation_config.seed)
	var bounds: Array = _vegetation_config.bounds
	var centers: Array[Vector2] = []
	var meshes: Array[ArrayMesh] = []
	for variant in 3:
		meshes.append(_make_shrub(variant))
	for variant in 3:
		meshes.append(_make_rock(variant))
	var placement_groups: Array = [[],[],[],[],[],[]]
	for attempt in int(_vegetation_config.cluster_attempts):
		if centers.size() >= int(_vegetation_config.get("cluster_limit",5)):
			break
		var point := Vector2(rng.randf_range(bounds[0],bounds[2]),rng.randf_range(bounds[1],bounds[3]))
		var road_distance: float = _trial._road_distance(point)
		if road_distance < float(_vegetation_config.road_clearance) or road_distance > float(_vegetation_config.maximum_road_distance) or _trial._in_lot(point):
			continue
		var crowded := false
		for center in centers:
			if point.distance_to(center) < float(_vegetation_config.cluster_min_spacing):
				crowded = true
		if crowded:
			continue
		centers.append(point)
		var shrub_variant := centers.size()%3
		var scale_value := rng.randf_range(0.78,1.12)
		placement_groups[shrub_variant].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value),Vector3(point.x,0.086,point.y)))
		for pebble in rng.randi_range(2,4):
			var position := point+Vector2(rng.randf_range(-0.8,0.8),rng.randf_range(-0.6,0.6))
			if _trial._road_distance(position)<0.65 or _trial._in_lot(position):
				continue
			var rock_scale := rng.randf_range(0.45,0.95)
			placement_groups[3+pebble%3].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rock_scale),Vector3(position.x,0.09,position.y)))
	_cluster_count = centers.size()
	for group_index in placement_groups.size():
		var placements: Array = placement_groups[group_index]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = meshes[group_index]
		multimesh.instance_count = placements.size()
		for index in placements.size():
			multimesh.set_instance_transform(index,placements[index])
		var node := MultiMeshInstance3D.new()
		node.name = ("Shrub" if group_index<3 else "Rock")+str(group_index%3+1)
		node.multimesh = multimesh
		_vegetation.add_child(node)
		_detail_count += placements.size()

func _make_shrub(variant: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var color := Color(_vegetation_config.shrub_colors[variant])
	# A broad, low mound with smaller side lobes; height stays below the characters' knees.
	_add_lobe(surface,Vector3(0,0.24,0),Vector3(0.44,0.33,0.36),color,variant+1)
	_add_lobe(surface,Vector3(-0.34,0.17,0.09),Vector3(0.31,0.23,0.29),color.darkened(0.07),variant+5)
	_add_lobe(surface,Vector3(0.31,0.14,-0.10),Vector3(0.28,0.20,0.25),color.lightened(0.04),variant+9)
	surface.set_material(_review_material)
	return surface.commit()

func _make_rock(variant: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_lobe(surface,Vector3(0,0.08,0),Vector3(0.32,0.21,0.25),Color(_vegetation_config.rock_colors[variant]),variant+19)
	surface.set_material(_review_material)
	return surface.commit()

func _add_lobe(surface: SurfaceTool, center: Vector3, size: Vector3, color: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rings: Array = []
	for level in 3:
		var ring: Array[Vector3] = []
		var y: float = [-0.65,0.10,0.75][level]
		var radius: float = [0.72,1.0,0.54][level]
		for index in 7:
			var angle := float(index)*TAU/7.0 + float(level)*0.17
			var wobble := rng.randf_range(0.90,1.10)
			ring.append(center+Vector3(cos(angle)*radius*size.x*wobble,y*size.y,sin(angle)*radius*size.z*wobble))
		rings.append(ring)
	for level in 2:
		for index in 7:
			var next := (index+1)%7
			_face(surface,rings[level][index],rings[level][next],rings[level+1][index],center,color)
			_face(surface,rings[level][next],rings[level+1][next],rings[level+1][index],center,color)
	for index in 7:
		_face(surface,rings[2][index],rings[2][(index+1)%7],center+Vector3.UP*size.y,center,color.lightened(0.035))
		_face(surface,rings[0][index],center-Vector3.UP*size.y*0.65,rings[0][(index+1)%7],center,color.darkened(0.10))

func _face(surface: SurfaceTool, a: Vector3,b: Vector3,c: Vector3,center: Vector3,color: Color) -> void:
	var normal := (c-a).cross(b-a).normalized()
	if normal.dot((a+b+c)/3.0-center)<0:
		var temporary := b
		b=c
		c=temporary
		normal = -normal
	for vertex in [a,b,c]:
		surface.set_color(color)
		surface.set_normal(normal)
		surface.add_vertex(vertex)

func get_vegetation_snapshot() -> Dictionary:
	return {"clusters":_cluster_count,"instances":_detail_count,"variants":6,"new_colliders":_vegetation.find_children("*","CollisionObject3D",true,false).size(),"new_navigation":_vegetation.find_children("*","NavigationRegion3D",true,false).size(),"production_enabled":false}

func _capture_vegetation() -> void:
	get_window().size = Vector2i(1280,720)
	var directory := "res://artifacts/visual_qa/t0363"
	DirAccess.make_dir_recursive_absolute(directory)
	for close in [false,true]:
		set_review_view(close)
		for night in [false,true]:
			set_night(night)
			for candidate in [false,true]:
				set_candidate(candidate)
				for frame in 8:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/%s_%s_%s.png" % [directory,"close" if close else "overview","night" if night else "day","B" if candidate else "A"])
	var snapshot := get_vegetation_snapshot()
	assert(snapshot.clusters>0 and snapshot.new_colliders==0 and snapshot.new_navigation==0)
	var file := FileAccess.open(directory+"/snapshot.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot,"  "))
	print("T0363_PASS ",JSON.stringify(snapshot))
	get_tree().quit()
