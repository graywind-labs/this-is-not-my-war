extends Node3D
## Offline illustration set. No Main systems or gameplay state are instantiated.

const CONFIG_PATH := "res://data/presentation/tutorial_prologue_shots.json"
const GATE_SCRIPT := preload("res://scripts/presentation/buildings/FormalGateArtView.gd")
const WALL_SCRIPT := preload("res://scripts/presentation/buildings/FormalFortificationArtView.gd")
const TREE_MESHES := preload("res://scripts/presentation/environment/StylizedTreeMeshes.gd")
var config: Dictionary
var camera: Camera3D
var ada: Node3D
var door: Node3D
var held_order: Node3D
var desk_order: Node3D
var palette: Dictionary = {}
var actors: Array[Node3D] = []
var dormitory: Node3D
var dormitory_sleepers: Array[Node3D] = []


func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	for key in config.palette:
		palette[key] = _material(Color.html(config.palette[key]))
	_build_lighting()
	_build_room()
	_build_exterior()
	_build_actors()
	_build_dormitory()
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.near = 0.04
	camera.far = 160.0
	_build_held_order()
	set_shot(0)


func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.87
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material


func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node


func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, material: Material, top: float = -1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = 8
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node


func _light(at: Vector3, color: Color, energy: float, radius: float, shadows: bool = true) -> void:
	var light := OmniLight3D.new()
	add_child(light)
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = shadows
	light.omni_attenuation = 1.1


func _build_lighting() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("3e5b7a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8eacca")
	environment.ambient_light_energy = 0.22
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 0.5
	environment.ssao_intensity = 1.25
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	environment.fog_enabled = true
	environment.fog_light_color = Color("354b62")
	environment.fog_density = 0.002
	environment.fog_sky_affect = 0.0
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	add_child(moon)
	moon.rotation_degrees = Vector3(-38, -28, 0)
	moon.light_color = Color("91b3d5")
	moon.light_energy = 0.42
	moon.shadow_enabled = true
	_light(Vector3(-1.5, 1.65, 0.25), Color("ffc985"), 2.1, 6.0)
	_light(Vector3(1.0, 2.5, 1.0), Color("ffd9a0"), 0.42, 7.0, false)
	_light(Vector3(2.0, 2.7, -5.0), Color("8cbeff"), 1.0, 8.0, false)


func _build_room() -> void:
	var wood: Material = palette.timber
	var plaster: Material = palette.plaster
	_box(self, "Floor", Vector3(0, -0.14, 0), Vector3(8.4, 0.25, 8), palette.floor)
	_box(self, "Ceiling", Vector3(0, 3.67, 0), Vector3(8.4, 0.2, 8), wood)
	for z in [-2.1, 0.5, 2.9]:
		_box(self, "CeilingBeam", Vector3(0, 3.46, z), Vector3(8.2, 0.28, 0.23), wood)
	for index in range(17):
		_box(self, "FloorBoard", Vector3(-4.0 + index * 0.5, 0, 0), Vector3(0.485, 0.035, 8), _material(Color("655340").lightened(float(index % 3) * 0.018)))
	# One continuous back wall with an actual window and door aperture.
	for part in [
		[Vector3(-3.5, 1.8, -3.5), Vector3(1.0, 3.6, 0.25)],
		[Vector3(-1.7, 0.51, -3.5), Vector3(2.6, 1.02, 0.25)],
		[Vector3(-1.7, 3.28, -3.5), Vector3(2.6, 0.64, 0.25)],
		[Vector3(0.4, 1.8, -3.5), Vector3(1.6, 3.6, 0.25)],
		[Vector3(2.0, 3.23, -3.5), Vector3(1.7, 0.74, 0.25)],
		[Vector3(3.5, 1.8, -3.5), Vector3(1.3, 3.6, 0.25)],
		[Vector3(-4.1, 1.8, 0), Vector3(0.2, 3.6, 7.2)],
		[Vector3(4.1, 1.8, 0), Vector3(0.2, 3.6, 7.2)]
	]:
		_box(self, "Plaster", part[0], part[1], plaster)
	for x in [-3.1, -0.3, 1.1, 2.95]:
		_box(self, "Upright", Vector3(x, 1.8, -3.28), Vector3(0.17, 3.6, 0.22), wood)
	for y in [3.0, 3.52]:
		_box(self, "CrossBeam", Vector3(0, y, -3.26), Vector3(8.1, 0.17, 0.26), wood)
	_box(self, "WindowSill", Vector3(-1.7, 1.03, -3.25), Vector3(2.85, 0.16, 0.6), wood)
	_box(self, "WindowLintel", Vector3(-1.7, 2.94, -3.28), Vector3(2.85, 0.15, 0.3), wood)
	# Shutter folds against the wall, keeping the distant gate legible.
	_box(self, "OpenShutter", Vector3(-3.52, 2, -3.17), Vector3(0.7, 1.65, 0.12), wood)
	door = Node3D.new()
	add_child(door)
	door.position = Vector3(2.87, 0, -3.45)
	for board in range(6):
		_box(door, "DoorPlank", Vector3(-0.14 - board * 0.28, 1.39, 0), Vector3(0.269, 2.78, 0.14), wood)
	for y in [0.55, 2.15]:
		_box(door, "DoorBrace", Vector3(-0.85, y, 0.09), Vector3(1.65, 0.1, 0.08), _material(Color("272b30")))
	_cylinder(door, Vector3(-1.43, 1.25, 0.16), 0.07, 0.11, _material(Color("8f784d"))).rotation_degrees.x = 90
	# Low-detail timber furniture at the same scale as the production characters.
	_box(self, "Desk", Vector3(-0.45, 0.8, 0.25), Vector3(2.8, 0.14, 1.45), wood)
	for board in range(5):
		_box(self, "DeskTopPlank", Vector3(-0.45, 0.881, -0.33 + board * 0.29), Vector3(2.8, 0.024, 0.283), _material(Color("71523a").lightened(float(board % 3) * 0.025)))
	for x in [-1.65, 0.75]:
		for z in [-0.3, 0.8]:
			_box(self, "DeskLeg", Vector3(x, 0.4, z), Vector3(0.13, 0.8, 0.13), wood)
	_box(self, "BedFrame", Vector3(-3.18, 0.31, -0.9), Vector3(1.3, 0.38, 2.7), wood)
	_box(self, "BedMattress", Vector3(-3.18, 0.55, -0.9), Vector3(1.19, 0.22, 2.6), palette.paper)
	_box(self, "BedBlanket", Vector3(-3.18, 0.69, -0.5), Vector3(1.2, 0.09, 1.8), palette.cloth)
	_box(self, "Pillow", Vector3(-3.18, 0.73, -1.88), Vector3(0.92, 0.15, 0.49), palette.paper)
	_box(self, "BedHeadboard", Vector3(-3.18, 0.73, -2.28), Vector3(1.35, 1.22, 0.13), wood)
	_box(self, "WallShelf", Vector3(-3.85, 1.7, -0.55), Vector3(0.4, 0.12, 1.6), wood)
	_add_prop("tavern_mug", Vector3(-3.8, 1.78, -0.15), 0.8)
	_add_prop("chapel_book", Vector3(-3.8, 1.78, -0.72), 0.9)
	_box(self, "BedFoot", Vector3(-3.18, 0.3, 0.53), Vector3(1.4, 0.6, 0.12), wood)
	for z in [-0.5, 0.5]:
		_box(self, "BlanketStripe", Vector3(-3.18, 0.742, z), Vector3(1.21, 0.008, 0.08), _material(Color("707e7c")))
	_add_prop("warehouse_chest", Vector3(3.3, 0.03, -1.9), 0.85)
	_add_prop("tavern_mug", Vector3(0.46, 0.88, 0.05), 0.65)
	_add_prop("chapel_book", Vector3(-1.1, 0.89, -0.1), 0.7)
	desk_order = Node3D.new()
	add_child(desk_order)
	desk_order.position = Vector3(-0.4, 0.89, 0.52)
	desk_order.rotation_degrees = Vector3(-90, 0, -9)
	_make_letter(desk_order, 0.7)
	_candle(Vector3(-1.5, 0.89, 0.25))
	# A small plain cloth pennant supplies the station's blue accent, without invented heraldry.
	_box(self, "BluePennant", Vector3(0.46, 2.06, -3.09), Vector3(0.49, 1.1, 0.045), palette.cloth)
	_box(self, "PennantRod", Vector3(0.46, 2.64, -3.04), Vector3(0.72, 0.055, 0.065), wood)


func _add_prop(asset: String, at: Vector3, size: float) -> void:
	var scene := load("res://assets/3d/quaternius/props/%s.glb" % asset) as PackedScene
	var instance := scene.instantiate() as Node3D
	add_child(instance)
	instance.position = at
	instance.scale = Vector3.ONE * size


func _candle(at: Vector3) -> void:
	var brass := _material(Color("766044"))
	_cylinder(self, at + Vector3(0, 0.025, 0), 0.16, 0.05, brass)
	_cylinder(self, at + Vector3(0, 0.14, 0), 0.045, 0.22, brass)
	_cylinder(self, at + Vector3(0, 0.27, 0), 0.1, 0.05, brass)
	_cylinder(self, at + Vector3(0, 0.46, 0), 0.07, 0.36, palette.paper)
	_cylinder(self, at + Vector3(0, 0.72, 0), 0.07, 0.19, _material(Color("ffc366"), 3), 0)


func _make_letter(parent: Node3D, size: float) -> void:
	# Facing local +Z. No generated pseudo-writing: the legible order stays in the UI.
	_box(parent, "Paper", Vector3.ZERO, Vector3(size, size * 0.68, 0.013), palette.paper)
	_box(parent, "Fold", Vector3(0, 0, 0.008), Vector3(0.007, size * 0.66, 0.004), _material(Color("bbaa85")))
	var ink := _material(Color("817457"))
	for side in [-1.0, 1.0]:
		for line in range(6):
			var length := size * (0.28 if line % 3 != 2 else 0.22)
			_box(parent, "InkRule", Vector3(side * size * 0.205, size * (0.22 - line * 0.054), 0.01), Vector3(length, 0.004, 0.004), ink)
	var seal := _cylinder(parent, Vector3(size * 0.22, -size * 0.21, 0.035), size * 0.075, 0.038, palette.wax)
	seal.rotation_degrees.x = 90
	_box(parent, "SealRibbon", Vector3(size * 0.22, -size * 0.3, 0.015), Vector3(size * 0.065, size * 0.19, 0.014), palette.wax)


func _build_held_order() -> void:
	held_order = Node3D.new()
	camera.add_child(held_order)
	held_order.position = Vector3(0, 0.05, -1.18)
	held_order.rotation_degrees = Vector3(-7, -6, -3)
	_make_letter(held_order, 0.91)
	var reading_light := OmniLight3D.new()
	held_order.add_child(reading_light)
	reading_light.position = Vector3(-0.5, 0.3, 0.55)
	reading_light.light_color = Color("ffcc8a")
	reading_light.light_energy = 0.75
	reading_light.omni_range = 2.5
	# Faceted gloves leave the guard officer's identity and skin tone unspecified.
	var glove := _material(Color("6e5540"))
	for side in [-1.0, 1.0]:
		var palm := _cylinder(held_order, Vector3(side * 0.5, -0.2, 0.01), 0.093, 0.2, glove, 0.073)
		palm.scale.z = 0.7
		palm.rotation_degrees.z = -side * 15
		_box(held_order, "Thumb", Vector3(side * 0.422, -0.135, 0.061), Vector3(0.1, 0.068, 0.073), glove)
		var sleeve := _cylinder(held_order, Vector3(side * 0.58, -0.48, 0.08), 0.15, 0.45, palette.cloth, 0.108)
		sleeve.rotation_degrees.z = side * 19


func _build_exterior() -> void:
	var previous_children := get_children()
	_box(self, "Courtyard", Vector3(0, -0.2, -36), Vector3(130, 0.2, 68), _material(Color("344439")))
	_box(self, "Road", Vector3(-1.8, -0.08, -32), Vector3(4.7, 0.04, 59), _material(Color("665d49")))
	var gate := GATE_SCRIPT.new()
	gate.configure({"id": "front_gate", "clear_width": 5.0, "height": 2.8})
	gate.position = Vector3(-1.7, 0, -15)
	add_child(gate)
	gate.set_process(false)
	gate.set_physics_process(false)
	for body in gate.find_children("*", "AnimatableBody3D", true, false):
		body.sync_to_physics = false
	# The close low-angle view exposes the banner support that the overhead game camera omits.
	_box(gate, "StudioBannerMast", Vector3(0, 3.98, 0.45), Vector3(0.09, 2.45, 0.1), palette.timber)
	_box(gate, "StudioBannerRail", Vector3(0, 5.18, 0.8), Vector3(1.35, 0.08, 0.1), palette.timber)
	var wall := WALL_SCRIPT.new()
	wall.configure({"wall_segments": [
		{"id": "left", "from": [-24, -15], "to": [-5.6, -15]},
		{"id": "right", "from": [2.2, -15], "to": [24, -15]}
	]})
	add_child(wall)
	var tree_settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/forest_art_trial.json"))
	var builder := TREE_MESHES.new(tree_settings)
	var rng := RandomNumberGenerator.new()
	rng.seed = 150507
	for index in range(36):
		var tree := MeshInstance3D.new()
		tree.mesh = builder.meshes[index % builder.meshes.size()]
		add_child(tree)
		var side := -1.0 if index % 2 == 0 else 1.0
		tree.position = Vector3(side * rng.randf_range(5, 29), 0, rng.randf_range(-61, -22))
		tree.position.y = clampf((-tree.position.z - 15.0) * 0.236, 0, 8.5)
		tree.scale = Vector3.ONE * rng.randf_range(0.8, 1.5)
		tree.rotation.y = rng.randf_range(0, TAU)
	var uphill := _box(self, "Hillside", Vector3(-1.7, 4.15, -33), Vector3(78, 0.3, 37), _material(Color("354638")))
	uphill.rotation_degrees.x = 13.3
	var road := _box(self, "UphillRoad", Vector3(-1.7, 4.35, -33), Vector3(4.7, 0.05, 37), _material(Color("4c5143")))
	road.rotation_degrees.x = 13.3
	_box(self, "FarHillside", Vector3(0, 8.4, -74), Vector3(130, 0.2, 46), _material(Color("354638")))
	for x in [-5.0, 1.6]:
		_light(Vector3(x, 2.7, -13.9), Color("ffc077"), 1.8, 5, false)
	# Sparse polygonal horizon instead of a detailed fantasy castle.
	for index in range(7):
		_cylinder(self, Vector3(-42 + index * 14, 0, -73), 16, 19 + (index % 3) * 6, _material(Color("2a3e50")), 0)
	var moon_disc := MeshInstance3D.new()
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 1.8
	moon_mesh.height = 3.6
	moon_mesh.radial_segments = 12
	moon_mesh.rings = 6
	moon_disc.mesh = moon_mesh
	moon_disc.material_override = _material(Color("b7cbd6"), 0.5)
	add_child(moon_disc)
	moon_disc.position = Vector3(-17, 18.5, -65)
	# The guard's room overlooks the gate from above; all exterior objects share this offset.
	var exterior := Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	for child in get_children():
		if child != exterior and not previous_children.has(child):
			child.reparent(exterior, true)
	exterior.position = Vector3(-0.7, -2.8, 0)


func _build_actors() -> void:
	ada = (load(config.ada_scene) as PackedScene).instantiate() as Node3D
	ada.name = "FormalAda"
	add_child(ada)
	ada.position = Vector3(1.96, 0.02, -2.93)
	ada.rotation.y = PI - 0.12
	ada.call("debug_force_animation_state", "talk")
	actors.append(ada)


func freeze_actors() -> void:
	for actor in actors:
		actor.set_process(false)
		var player := actor.get_node_or_null("PilotAnimationPlayer") as AnimationPlayer
		if player != null:
			player.seek(0.38, true)
			player.pause()


func set_shot(index: int) -> void:
	var shot: Dictionary = config.shots[index]
	camera.position = Vector3(shot.camera[0], shot.camera[1], shot.camera[2])
	camera.look_at(Vector3(shot.target[0], shot.target[1], shot.target[2]))
	camera.fov = float(shot.fov)
	ada.visible = str(shot.id).begins_with("ada")
	if ada.visible:
		ada.call("debug_force_animation_state", str(shot.get("pose", "talk")))
		var player := ada.get_node_or_null("PilotAnimationPlayer") as AnimationPlayer
		if player != null:
			# Finish the production cross-fade before freezing this separate illustration.
			player.advance(0.2)
			player.seek(0.38, true)
			player.pause()
	door.rotation_degrees.y = 78 if ada.visible else 0
	held_order.visible = shot.id == "order"
	desk_order.visible = not held_order.visible
	dormitory.visible = shot.id == "dormitory"


func _build_dormitory() -> void:
	dormitory = Node3D.new()
	dormitory.name = "DormitoryIllustration"
	add_child(dormitory)
	var settings: Dictionary = config.dormitory
	dormitory.position = Vector3(settings.origin[0], settings.origin[1], settings.origin[2])
	var fixture_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(settings.fixtures))
	var appearances: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(settings.appearances)).characters
	var timber := _material(Color("47342f"))
	var plaster := _material(Color("8e8b82"))
	var linen := _material(Color("c7bda7"))
	var textile := _material(Color("677b88"))
	_box(dormitory, "Floor", Vector3(0, -0.14, -4.4), Vector3(13, 0.24, 18), timber)
	for plank in range(27):
		_box(dormitory, "FloorPlank", Vector3(-6.24 + plank * 0.48, -0.008, -4.4), Vector3(0.468, 0.035, 18), _material(Color("665447").lightened(float(plank % 3) * 0.02)))
	_box(dormitory, "BackWall", Vector3(0, 2.25, 4.3), Vector3(9.8, 4.5, 0.25), plaster)
	_box(dormitory, "Ceiling", Vector3(0, 4.5, -4.4), Vector3(9.8, 0.2, 18), timber)
	for z in [-7.0, -3.2, 0.6, 4.1]:
		_box(dormitory, "CeilingRafter", Vector3(0, 4.33, z), Vector3(9.6, 0.32, 0.28), timber)
	for side in [-1.0, 1.0]:
		_box(dormitory, "SideWall", Vector3(side * 4.8, 2.25, -4.4), Vector3(0.2, 4.5, 18), plaster)
		for z in [-5.1, -2.5, 0.1, 2.7]:
			_box(dormitory, "WallPost", Vector3(side * 4.61, 2.15, z), Vector3(0.22, 4.3, 0.19), timber)
		for z in [-3.8, 1.4]:
			_box(dormitory, "WindowFrame", Vector3(side * 4.65, 2.0, z), Vector3(0.1, 1.35, 1.5), timber)
			_box(dormitory, "MoonlitWindow", Vector3(side * 4.57, 2.0, z), Vector3(0.025, 1.1, 1.22), _material(Color("46718e"), 0.35))
			_box(dormitory, "WindowCross", Vector3(side * 4.53, 2.0, z), Vector3(0.08, 1.15, 0.07), timber)
			_box(dormitory, "WindowCross", Vector3(side * 4.53, 2.0, z), Vector3(0.08, 0.07, 1.25), timber)
			_dormitory_light(Vector3(side * 4.2, 2.6, z), Color("8bacdf"), 0.65, 6)
		_box(dormitory, "EaveBeam", Vector3(side * 4.56, 3.4, -1.6), Vector3(0.25, 0.25, 12.2), timber)
	_box(dormitory, "RearCrossBeam", Vector3(0, 3.35, 4.13), Vector3(9.6, 0.27, 0.24), timber)
	_build_dormitory_furnishings(timber)
	# A room-section photograph frames only the eight assigned bays; spare beds lie outside this set.
	var bed_count := 0
	for fixture in fixture_data.buildings.dormitory.fixtures:
		if fixture.get("kind", "") != "dormitory_bed":
			continue
		var npc_id := str(fixture.get("assigned_npc_id", ""))
		if npc_id.is_empty():
			continue
		bed_count += 1
		var bed := (load(fixture.asset_path) as PackedScene).instantiate() as Node3D
		bed.name = str(fixture.workstation_id)
		dormitory.add_child(bed)
		# Compress only this photographic set; preserve production bed identities and ordering.
		bed.position = Vector3(float(fixture.center[0]) * 0.74, 0, fixture.center[1])
		bed.scale = Vector3(fixture.visual_scale[0], fixture.visual_scale[1], fixture.visual_scale[2])
		bed.rotation_degrees.y = float(fixture.rotation_degrees)
		bed.set_meta("assigned_npc_id", npc_id)
		var empty: bool = npc_id == str(settings.empty_npc_id)
		# Read the name from the production appearance catalogue, not a parallel NPC definition.
		var plate := Label3D.new()
		plate.text = str(appearances[npc_id].display_name)
		plate.font_size = 42
		plate.pixel_size = 0.006
		plate.modulate = Color("ead5a8") if empty else Color("b8b7b0")
		plate.outline_size = 5
		plate.rotation_degrees.y = 180
		dormitory.add_child(plate)
		plate.position = bed.position + Vector3(0, 0.43, -1.09)
		_box(dormitory, "BedNamePlaque", bed.position + Vector3(0, 0.43, -1.065), Vector3(0.72, 0.22, 0.04), timber)
		_build_bed_belongings(bed.position, bed_count, timber)
		if empty:
			# Folded blue blanket makes the unoccupied mattress immediately readable.
			_box(dormitory, "AdaFoldedBlanket", bed.position + Vector3(0, 0.48, 0.61), Vector3(1.12, 0.09, 0.46), textile)
			_dormitory_light(bed.position + Vector3(-0.9, 2.3, -0.5), Color("efc68b"), 1.1, 4)
			continue
		var anchor: Dictionary = fixture.occupant_anchor
		var sleeper := (load(appearances[npc_id].scene) as PackedScene).instantiate() as Node3D
		sleeper.name = npc_id
		dormitory.add_child(sleeper)
		sleeper.position = Vector3(float(anchor.center[0]) * 0.74, float(anchor.y) - 0.18, float(anchor.center[1]) - 0.22)
		sleeper.call("snap_facing_direction", Vector3(0, 0, 1))
		sleeper.call("set_spatial_attachment_pose", anchor.pose)
		sleeper.call("debug_force_animation_state", "sleeping")
		actors.append(sleeper)
		dormitory_sleepers.append(sleeper)
		_dormitory_quilt(bed.position, bed_count)
	_box(dormitory, "RearLinenShelf", Vector3(0, 1.05, 3.95), Vector3(2.2, 0.09, 0.5), timber)
	for stack in range(3):
		_box(dormitory, "FoldedLinen", Vector3(-0.7 + stack * 0.7, 1.21, 3.93), Vector3(0.58, 0.22, 0.42), linen)
	_dormitory_light(Vector3(0, 2.7, 3.0), Color("ebbb7c"), 0.8, 7)
	_dormitory_light(Vector3(0, 4.1, -2), Color("96acd0"), 0.35, 10)
	assert(bed_count == 8 and dormitory_sleepers.size() == 7, "Dormitory illustration must contain eight assigned beds and seven sleepers")


func _dormitory_prop(asset: String, at: Vector3, height: float, yaw: float = 0.0) -> Node3D:
	var prop := (load("res://assets/3d/quaternius/props/%s.glb" % asset) as PackedScene).instantiate() as Node3D
	dormitory.add_child(prop)
	var bounds := AABB()
	var has_bounds := false
	for child in prop.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = (prop.global_transform.affine_inverse() * child.global_transform) * child.get_aabb()
		bounds = bounds.merge(part) if has_bounds else part
		has_bounds = true
	var factor := height / maxf(bounds.size.y, 0.01)
	prop.scale = Vector3.ONE * factor
	prop.rotation_degrees.y = yaw
	var center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	prop.position = at - prop.basis * center
	return prop


func _build_dormitory_furnishings(timber: Material) -> void:
	# A narrow woven runner and modest storage break up the aisle and blank rear wall.
	_box(dormitory, "RunnerBorder", Vector3(0, 0.02, -1.45), Vector3(2.4, 0.035, 9.6), _material(Color("625245")))
	_box(dormitory, "RunnerField", Vector3(0, 0.041, -1.45), Vector3(2.15, 0.008, 9.3), _material(Color("563e3b")))
	for z in [-5.8, 2.85]:
		for stripe in range(3):
			_box(dormitory, "WovenStripe", Vector3(0, 0.049, z + stripe * 0.1), Vector3(2.15, 0.004, 0.035), _material(Color("948369")))
	for side in [-1.0, 1.0]:
		_dormitory_prop("warehouse_chest", Vector3(side * 1.0, 0.03, 3.64), 0.68)
		_dormitory_prop("warehouse_bag", Vector3(side * 4.02, 0.02, 3.44), 0.56, side * 16)
		_dormitory_prop("barrel", Vector3(side * 4.08, 0.02, 2.53), 0.82)
		_dormitory_prop("main_hall_lantern", Vector3(side * 1.65, 2.22, 3.87), 0.5)
		_dormitory_light(Vector3(side * 1.65, 2.52, 3.42), Color("efc286"), 0.7, 5)
		_box(dormitory, "WallHookRail", Vector3(side * 4.57, 2.28, -1.0), Vector3(0.12, 0.15, 1.7), timber)
		for garment in range(2):
			var at := Vector3(side * 4.42, 1.58, -1.4 + garment * 0.65)
			var cloth := _material(Color("665d4a") if garment == 0 else Color("465b66"))
			var coat := _box(dormitory, "HangingCoat", at, Vector3(0.15, 1.1, 0.47), cloth)
			coat.rotation_degrees.x = -4 if garment == 0 else 5
			_box(dormitory, "CoatShoulders", at + Vector3(0, 0.41, 0), Vector3(0.22, 0.17, 0.68), cloth)
			_box(dormitory, "Peg", at + Vector3(0, 0.65, 0), Vector3(0.35, 0.055, 0.065), timber)
	# Low shelf, two folded blankets and household books above the rear storage chests.
	_box(dormitory, "RearUpperShelf", Vector3(0, 2.03, 4.01), Vector3(2.3, 0.1, 0.5), timber)
	for index in range(3):
		_box(dormitory, "StoredBlanket", Vector3(-0.65 + index * 0.65, 2.17, 4.0), Vector3(0.55, 0.18, 0.39), _material(Color("6b7475").lightened(index * 0.06)))
	_dormitory_prop("chapel_book", Vector3(1.0, 0.71, 3.57), 0.11, -12)


func _build_bed_belongings(at: Vector3, index: int, _timber: Material) -> void:
	var side := signf(at.x)
	var bedside := at + Vector3(side * 1.28, 0, -0.42)
	_dormitory_prop("warehouse_chest", bedside, 0.46, float(index % 3 - 1) * 5.0)
	var cloth := _material(Color("7d7662") if index % 2 == 0 else Color("536675"))
	_box(dormitory, "FoldedPersonalCloth", bedside + Vector3(0, 0.51, 0), Vector3(0.49, 0.1, 0.36), cloth)
	if index % 2 == 0:
		_dormitory_prop("tavern_mug", bedside + Vector3(0.25, 0.47, -0.18), 0.16)
	else:
		_dormitory_prop("warehouse_bag", bedside + Vector3(0.15, 0, 0.58), 0.32, index * 17)
	var leather := _material(Color("342e29"))
	for boot in range(2):
		var boot_at := at + Vector3(side * 0.86, 0, 0.1 + boot * 0.23)
		_box(dormitory, "BootToe", boot_at + Vector3(-side * 0.055, 0.07, 0), Vector3(0.3, 0.12, 0.16), leather)
		_box(dormitory, "BootShaft", boot_at + Vector3(side * 0.035, 0.18, 0), Vector3(0.16, 0.24, 0.16), leather)
	if index == 1:
		_dormitory_prop("main_hall_lantern", bedside + Vector3(0, 0.57, 0.1), 0.4)


func _dormitory_quilt(at: Vector3, index: int) -> void:
	# Faceted cloth rests over the torso and falls to mattress level at both sides and feet.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs := [-0.6, -0.43, 0.0, 0.43, 0.6]
	var ys := [0.36, 0.65, 0.71, 0.65, 0.36]
	var zs := [-0.12, 0.25, 0.72, 0.94]
	for row in range(4):
		for column in range(5):
			var y: float = lerpf(float(ys[column]), 0.41, float(row) / 3.0)
			surface.add_vertex(Vector3(xs[column], y, zs[row]))
	for row in range(3):
		for column in range(4):
			var a := row * 5 + column
			for vertex in [a, a + 5, a + 1, a + 1, a + 5, a + 6]:
				surface.add_index(vertex)
	surface.generate_normals()
	var quilt := MeshInstance3D.new()
	quilt.name = "SleepingQuilt"
	quilt.mesh = surface.commit()
	var colors := ["586970", "6d6555", "62634f", "685554"]
	var material := _material(Color(colors[index % colors.size()]))
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quilt.material_override = material
	dormitory.add_child(quilt)
	quilt.position = at


func _dormitory_light(at: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	dormitory.add_child(light)
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = true
