extends Node3D
## Sparse visual props; the existing gate-light controller owns night switching.
const CONFIG_PATH := "res://data/presentation/station_ground_decor.json"
var _fires: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _phase := 0.0
var _lit := false
var grass_removed := 0

func _ready() -> void:
	set_meta("presentation_only", true)
	add_to_group("station_ground_decor")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	for p: Array in config.torches:
		_build_torch(Vector3(p[0], 0.03, p[1]), config)
	for entry: Dictionary in config.stumps:
		_build_stump(entry)
	call_deferred("_sync_lights")

func _sync_lights() -> void:
	var controller := get_tree().get_first_node_in_group("building_functional_light_controller")
	set_night_enabled(controller != null and bool(controller.call("is_night_time")))

func set_night_enabled(enabled: bool) -> void:
	_lit = enabled
	for fire in _fires:
		fire.visible = enabled
	for light in _lights:
		light.visible = enabled
	set_process(enabled)

func _process(delta: float) -> void:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	if time_system != null and time_system.is_gameplay_paused():
		return
	_phase += delta
	for i in _fires.size():
		var wave := sin(_phase * 9.0 + float(i) * 2.1)
		_fires[i].scale = Vector3(1.0 + wave * 0.08, 1.0 + wave * 0.16, 1.0 - wave * 0.06)
		_fires[i].rotation.z = sin(_phase * 6.0 + i) * 0.075

func _material(color: String, emission := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 1.0
	if emission:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = Color(color)
		material.emission_energy_multiplier = 2.0
	return material

func _cylinder(parent: Node3D, bottom: float, top: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 7
	mesh.material = material
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	parent.add_child(view)
	return view

func _build_torch(at: Vector3, config: Dictionary) -> void:
	var prop := Node3D.new()
	prop.name = "RoadTorch%02d" % (_fires.size() + 1)
	prop.position = at
	prop.scale = Vector3.ONE * float(config.get("torch_scale", 1.0))
	add_child(prop)
	var wood := _material("#554331")
	var iron := _material("#343331")
	var height := float(config.torch_height)
	_cylinder(prop, 0.15, 0.11, height, Vector3.UP * height * 0.5, wood)
	_cylinder(prop, 0.27, 0.21, 0.16, Vector3.UP * 0.08, _material("#696454"))
	for y in [0.22, height - 0.30, height - 0.05]:
		_cylinder(prop, 0.16, 0.16, 0.10, Vector3.UP * y, iron)
	_cylinder(prop, 0.17, 0.29, 0.28, Vector3.UP * height, iron)
	for i in 6:
		var angle := i * TAU / 6.0
		_cylinder(prop, 0.035, 0.025, 0.38, Vector3(cos(angle)*0.25, height+0.16, sin(angle)*0.25), iron)
	var fire := Node3D.new()
	fire.name = "Flame"
	fire.position.y = height + 0.14
	prop.add_child(fire)
	_cylinder(fire, 0.23, 0.0, 0.75, Vector3.UP * 0.29, _material("#ff651b", true))
	_cylinder(fire, 0.15, 0.0, 0.48, Vector3(0.025, 0.20, 0.055), _material("#ffd16c", true))
	_cylinder(fire, 0.11, 0.0, 0.45, Vector3(-0.16, 0.23, 0.0), _material("#ffad37", true))
	_fires.append(fire)
	var light := OmniLight3D.new()
	light.position.y = height + 0.45
	light.light_color = Color("#ffb35d")
	light.light_energy = float(config.light_energy)
	light.omni_range = float(config.light_range)
	light.light_volumetric_fog_energy = 0.0
	light.shadow_enabled = true
	prop.add_child(light)
	_lights.append(light)
	# The tiny basket surrounds its own light; suppress its oversized radial shadows.
	# The light still casts shadows from buildings and other world geometry.
	for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_stump(entry: Dictionary) -> void:
	var prop := Node3D.new()
	prop.name = "LawnStump%02d" % (get_child_count() + 1)
	prop.position = Vector3(entry.position[0], 0.03, entry.position[1])
	prop.rotation_degrees.y = float(entry.rotation)
	add_child(prop)
	var radius := float(entry.radius)
	var height := float(entry.height)
	var bark := _material("#554331")
	_cylinder(prop, radius * 1.18, radius, height, Vector3.UP * height * 0.5, bark)
	_cylinder(prop, radius * 0.89, radius * 0.89, 0.018, Vector3.UP * (height + 0.002), _material("#b39a68"))
	for fraction in [0.38, 0.68]:
		var ring := TorusMesh.new()
		ring.inner_radius = radius * fraction - 0.009
		ring.outer_radius = radius * fraction + 0.009
		ring.rings = 12
		ring.ring_segments = 4
		ring.material = _material("#826947")
		var view := MeshInstance3D.new()
		view.mesh = ring
		view.position.y = height + 0.013
		prop.add_child(view)
	for i in 5:
		var angle := i * TAU / 5.0
		var root := _cylinder(prop, radius * 0.24, radius * 0.07, radius * 1.15, Vector3(cos(angle)*radius*0.85, 0.10, sin(angle)*radius*0.85), bark)
		root.rotation = Vector3(0.0, -angle, 1.03)

func thin_grass(ground: Node3D) -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	var view := ground.get_node("SolidLowPolyGrass") as MultiMeshInstance3D
	var old := view.multimesh
	var retained: Array[int] = []
	for i in old.instance_count:
		var p: Vector3 = ground.grass_transforms[i].origin
		var remove := false
		for at: Array in config.torches:
			remove = remove or Vector2(p.x, p.z).distance_to(Vector2(at[0], at[1])) < float(config.torch_clearance)
		for entry: Dictionary in config.stumps:
			remove = remove or Vector2(p.x, p.z).distance_to(Vector2(entry.position[0], entry.position[1])) < float(config.stump_clearance)
		if not remove:
			retained.append(i)
	var replacement := MultiMesh.new()
	replacement.transform_format = MultiMesh.TRANSFORM_3D
	replacement.use_colors = true
	replacement.mesh = old.mesh
	replacement.instance_count = retained.size()
	for i in retained.size():
		replacement.set_instance_transform(i, ground.grass_transforms[retained[i]])
		replacement.set_instance_color(i, ground.grass_colors[retained[i]])
	grass_removed = old.instance_count - retained.size()
	view.multimesh = replacement
	ground.set("_tuft_count", int(ground.get("_tuft_count")) - grass_removed)
	var density: Dictionary = ground.get("_density_counts")
	density.inside -= grass_removed
	set_meta("grass_removed", grass_removed)
