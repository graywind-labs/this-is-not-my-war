class_name FormalMerchantWagonArtView
extends Node3D


const HORSE_SCENE := preload("res://assets/3d/quaternius/animals/merchant_horse.glb")
const DRIVER_SCENE := preload("res://scenes/characters/MerchantChibiArtView.tscn")
const CRATE_SCENE := preload("res://assets/3d/quaternius/props/crate_wooden.glb")
const BARREL_SCENE := preload("res://assets/3d/quaternius/props/barrel.glb")
const BAG_SCENE := preload("res://assets/3d/quaternius/props/warehouse_bag.glb")
const CHEST_SCENE := preload("res://assets/3d/quaternius/props/warehouse_chest.glb")
const HARVEST_CRATE_SCENE := preload("res://assets/3d/quaternius/props/garden_harvest_crate.glb")
const APPLE_BARREL_SCENE := preload("res://assets/3d/quaternius/props/warehouse_apple_barrel.glb")

const HORSE_X := 0.82
const HORSE_Z := -4.45
const WHEEL_RADIUS := 0.66
const WHEEL_Z := [-0.25, 1.92]
const REIN_TARGETS := [Vector3(-HORSE_X, 1.18, -5.03), Vector3(HORSE_X, 1.18, -5.03)]
const CANOPY_HALF_WIDTH := 1.22
const CANOPY_EDGE_Y := 2.18
const CANOPY_RISE := 1.07
const CANOPY_FRONT_Z := -2.12
const CANOPY_CARGO_FRONT_Z := -0.84
const CANOPY_REAR_Z := 2.78
const CANOPY_ARC_SEGMENTS := 8

var _horse_animation_players: Array[AnimationPlayer] = []
var _horse_motion_clips: Array[String] = []
var _horse_idle_clips: Array[String] = []
var _wheel_roots: Array[Node3D] = []
var _rein_segments: Array[MeshInstance3D] = []
var _driver_art: Node3D
var _cargo_count := 0
var _last_moving := false


func _ready() -> void:
	_build_art()
	set_process(true)


func _process(_delta: float) -> void:
	_update_reins()


func get_driver_art() -> Node3D:
	return _driver_art


func set_travel_state(moving: bool, speed: float, delta: float) -> void:
	_last_moving = moving
	for index in _horse_animation_players.size():
		var player := _horse_animation_players[index]
		var clip := _horse_motion_clips[index] if moving else _horse_idle_clips[index]
		if clip.is_empty():
			if not moving:
				player.pause()
			continue
		if player.current_animation != clip or not player.is_playing():
			player.play(clip)
	var roll_delta := speed * delta / WHEEL_RADIUS
	for wheel in _wheel_roots:
		wheel.rotation.x -= roll_delta


func debug_get_art_snapshot() -> Dictionary:
	var driver_snapshot: Dictionary = _driver_art.call("debug_get_snapshot") if _driver_art != null and _driver_art.has_method("debug_get_snapshot") else {}
	return {
		"art_revision": "t0132_p7r",
		"visual_identity": "dual_horse_loaded_covered_trade_cart",
		"horse_count": get_node("Horses").get_child_count(),
		"wheel_count": _wheel_roots.size(),
		"axle_count": get_node("Chassis/Axles").get_child_count(),
		"cargo_item_count": _cargo_count,
		"rein_segment_count": _rein_segments.size(),
		"driver_appearance_id": str(driver_snapshot.get("appearance_id", "")),
		"driver_state": str(driver_snapshot.get("current_state", "")),
		"driver_source_ready": bool(driver_snapshot.get("ready", false)),
		"left_hand_to_rein_distance": _get_hand_rein_distance("LeftHand", 0),
		"right_hand_to_rein_distance": _get_hand_rein_distance("RightHand", 2),
		"horse_spacing": HORSE_X * 2.0,
		"horse_forward_z": -1.0,
		"bed_sideboard_count": get_node("Chassis/CargoBed/Sideboards").get_child_count(),
		"canopy_surface_count": get_node("Canopy/Canvas").get_child_count(),
		"canopy_rib_count": get_node("Canopy/BowFrames").get_child_count(),
		"canopy_support_post_count": get_node("Canopy/SupportPosts").get_child_count(),
		"canopy_front_brace_count": get_node("Canopy/DriverAwningBraces").get_child_count(),
		"canopy_half_width": CANOPY_HALF_WIDTH,
		"canopy_peak_y": CANOPY_EDGE_Y + CANOPY_RISE,
		"canopy_front_z": CANOPY_FRONT_Z,
		"canopy_cargo_front_z": CANOPY_CARGO_FRONT_Z,
		"canopy_rear_z": CANOPY_REAR_Z,
		"driver_canopy_extension": CANOPY_CARGO_FRONT_Z - CANOPY_FRONT_Z,
		"canopy_has_collision": false,
		"imported_complete_wagon_count": 0,
		"presentation_inventory_authority": false,
		"moving": _last_moving,
	}


func _build_art() -> void:
	_build_chassis()
	_build_wheels()
	_build_hitch()
	_build_horses()
	_build_driver()
	_build_cargo()
	_build_canopy()
	_build_reins()


func _build_chassis() -> void:
	var chassis := _node("Chassis", self)
	var frame := _node("Frame", chassis)
	_make_box("LeftRail", frame, Vector3(0.16, 0.20, 3.85), Vector3(-0.91, 0.66, 0.82), _wood_dark())
	_make_box("RightRail", frame, Vector3(0.16, 0.20, 3.85), Vector3(0.91, 0.66, 0.82), _wood_dark())
	for z in [-0.82, 0.02, 0.86, 1.70, 2.54]:
		_make_box("CrossBeam_%s" % str(z), frame, Vector3(2.02, 0.15, 0.15), Vector3(0.0, 0.72, z), _wood_dark())
	var bed := _node("CargoBed", chassis)
	_make_box("Deck", bed, Vector3(2.24, 0.18, 3.55), Vector3(0.0, 0.86, 0.88), _wood_warm())
	var boards := _node("Sideboards", bed)
	_make_box("LeftBoard", boards, Vector3(0.13, 0.72, 3.46), Vector3(-1.11, 1.19, 0.88), _wood_warm())
	_make_box("RightBoard", boards, Vector3(0.13, 0.72, 3.46), Vector3(1.11, 1.19, 0.88), _wood_warm())
	_make_box("FrontBoard", boards, Vector3(2.08, 0.72, 0.13), Vector3(0.0, 1.19, -0.84), _wood_warm())
	_make_box("RearBoard", boards, Vector3(2.08, 0.72, 0.13), Vector3(0.0, 1.19, 2.60), _wood_warm())
	for x in [-1.16, 1.16]:
		for z in [-0.84, 0.88, 2.60]:
			_make_box("Post_%s_%s" % [str(x), str(z)], boards, Vector3(0.14, 1.02, 0.14), Vector3(x, 1.34, z), _wood_dark())


func _build_wheels() -> void:
	var axles := _node("Axles", get_node("Chassis"))
	for axle_index in WHEEL_Z.size():
		var z: float = WHEEL_Z[axle_index]
		_make_cylinder("%sAxle" % ("Front" if axle_index == 0 else "Rear"), axles, 0.07, 2.78, Vector3(0.0, 0.63, z), Vector3(0.0, 0.0, PI * 0.5), _iron())
	var wheels := _node("Wheels", self)
	for axle_index in WHEEL_Z.size():
		for side in [-1.0, 1.0]:
			var wheel_name := "%s%sWheel" % ["Left" if side < 0.0 else "Right", "Front" if axle_index == 0 else "Rear"]
			var wheel := _node(wheel_name, wheels)
			wheel.position = Vector3(side * 1.31, WHEEL_RADIUS, WHEEL_Z[axle_index])
			_build_wheel(wheel)
			_wheel_roots.append(wheel)


func _build_wheel(wheel: Node3D) -> void:
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = WHEEL_RADIUS - 0.10
	rim_mesh.outer_radius = WHEEL_RADIUS
	rim_mesh.rings = 18
	rim_mesh.ring_segments = 8
	rim_mesh.material = _iron()
	var rim := MeshInstance3D.new()
	rim.name = "IronRim"
	rim.mesh = rim_mesh
	rim.rotation.z = PI * 0.5
	wheel.add_child(rim)
	_make_cylinder("Hub", wheel, 0.14, 0.30, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), _wood_dark())
	for angle_index in 8:
		var spoke := _make_box("Spoke%02d" % angle_index, wheel, Vector3(0.07, WHEEL_RADIUS * 1.72, 0.07), Vector3.ZERO, _wood_warm())
		spoke.rotation.x = float(angle_index) * PI / 4.0


func _build_hitch() -> void:
	var hitch := _node("Hitch", self)
	_make_beam("LeftShaft", hitch, Vector3(-0.72, 0.72, -0.70), Vector3(-0.72, 0.84, -3.70), 0.055, _wood_warm())
	_make_beam("RightShaft", hitch, Vector3(0.72, 0.72, -0.70), Vector3(0.72, 0.84, -3.70), 0.055, _wood_warm())
	_make_beam("Yoke", hitch, Vector3(-1.32, 0.93, -3.68), Vector3(1.32, 0.93, -3.68), 0.07, _wood_dark())
	for x in [-HORSE_X, HORSE_X]:
		_make_torus("Collar_%s" % str(x), hitch, 0.24, 0.30, Vector3(x, 1.11, -4.42), Vector3(PI * 0.5, 0.0, 0.0), _leather())
		_make_beam("Trace_%s" % str(x), hitch, Vector3(x, 0.95, -3.70), Vector3(x, 0.91, -4.18), 0.025, _leather())


func _build_horses() -> void:
	var horses := _node("Horses", self)
	for index in 2:
		var horse := HORSE_SCENE.instantiate() as Node3D
		horse.name = "LeftHorse" if index == 0 else "RightHorse"
		horse.position = Vector3(-HORSE_X if index == 0 else HORSE_X, 0.01, HORSE_Z)
		horse.rotation.y = PI
		horse.scale = Vector3(0.46, 0.36, 0.42)
		horses.add_child(horse)
		var player := horse.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player != null:
			_horse_animation_players.append(player)
			_horse_motion_clips.append(_find_clip(player, "Walk"))
			_horse_idle_clips.append(_find_clip(player, "Idle"))


func _build_driver() -> void:
	var driver_bench := _node("DriverBench", self)
	_make_box("Seat", driver_bench, Vector3(1.72, 0.17, 0.55), Vector3(0.0, 1.09, -1.48), _wood_warm())
	_make_box("BackRest", driver_bench, Vector3(1.72, 0.34, 0.13), Vector3(0.0, 1.31, -1.17), _wood_dark())
	_make_box("FootBoard", driver_bench, Vector3(1.55, 0.12, 0.48), Vector3(0.0, 0.70, -2.00), _wood_warm()).rotation.x = -0.16
	var seat := _node("DriverSeat", self)
	# The retargeted seated clip keeps the hands low relative to its standing origin.
	# This calibrated root places the pelvis on the bench and both hands above the
	# footboard so the reins read as held instead of emerging below the vehicle.
	seat.position = Vector3(0.0, 1.0, -1.48)
	seat.scale = Vector3(0.92, 0.92, 0.92)
	_driver_art = DRIVER_SCENE.instantiate() as Node3D
	_driver_art.name = "MerchantChibiArtView"
	seat.add_child(_driver_art)


func _build_cargo() -> void:
	var cargo := _node("LoadedCargoBed", self)
	var entries := [
		[CRATE_SCENE, Vector3(-0.62, 1.13, -0.30), Vector3(0.62, 0.62, 0.62), -0.08],
		[CRATE_SCENE, Vector3(0.48, 1.12, -0.20), Vector3(0.70, 0.64, 0.66), 0.06],
		[BARREL_SCENE, Vector3(-0.67, 1.18, 0.65), Vector3(0.57, 0.57, 0.57), 0.0],
		[APPLE_BARREL_SCENE, Vector3(0.58, 1.17, 0.62), Vector3(0.54, 0.54, 0.54), 0.0],
		[CHEST_SCENE, Vector3(-0.50, 1.12, 1.66), Vector3(0.57, 0.57, 0.57), -0.05],
		[CRATE_SCENE, Vector3(0.50, 1.12, 1.65), Vector3(0.64, 0.64, 0.64), 0.05],
		[BAG_SCENE, Vector3(-0.63, 1.27, 2.27), Vector3(0.58, 0.58, 0.58), -0.12],
		[BAG_SCENE, Vector3(0.57, 1.27, 2.27), Vector3(0.62, 0.62, 0.62), 0.13],
		[HARVEST_CRATE_SCENE, Vector3(-0.10, 1.76, 0.03), Vector3(0.47, 0.47, 0.47), 0.04],
		[BAG_SCENE, Vector3(-0.50, 1.73, 0.88), Vector3(0.52, 0.52, 0.52), -0.18],
		[BAG_SCENE, Vector3(0.45, 1.72, 0.91), Vector3(0.55, 0.55, 0.55), 0.16],
		[CRATE_SCENE, Vector3(0.07, 1.73, 1.71), Vector3(0.50, 0.50, 0.50), -0.04],
		[BAG_SCENE, Vector3(-0.42, 2.03, 1.42), Vector3(0.43, 0.43, 0.43), -0.10],
		[BAG_SCENE, Vector3(0.43, 2.04, 1.40), Vector3(0.45, 0.45, 0.45), 0.11],
	]
	for index in entries.size():
		var entry: Array = entries[index]
		var item := (entry[0] as PackedScene).instantiate() as Node3D
		item.name = "Cargo%02d" % index
		item.position = entry[1]
		item.scale = entry[2]
		item.rotation.y = entry[3]
		cargo.add_child(item)
		_cargo_count += 1
	for index in 3:
		var roll := _make_cylinder("ClothRoll%02d" % index, cargo, 0.17, 0.78, Vector3(-0.44 + index * 0.43, 2.05, 2.03), Vector3(0.0, 0.0, PI * 0.5), _cloth(index))
		roll.rotation.y = -0.06 + index * 0.06
		_cargo_count += 1
	for index in 2:
		var bundle := _make_box("TiedBundle%02d" % index, cargo, Vector3(0.55, 0.30, 0.75), Vector3(-0.35 + index * 0.72, 2.22, 0.70), _cloth(index + 1))
		bundle.rotation.y = -0.10 if index == 0 else 0.09
		_make_beam("BundleRope%02d" % index, cargo, bundle.position + Vector3(-0.30, 0.02, 0.0), bundle.position + Vector3(0.30, 0.02, 0.0), 0.018, _rope())
		_cargo_count += 1


func _build_canopy() -> void:
	var canopy := _node("Canopy", self)
	var canvas := _node("Canvas", canopy)
	_make_canopy_surface("CargoCanvas", canvas, CANOPY_CARGO_FRONT_Z, CANOPY_REAR_Z, _canopy_canvas())
	_make_canopy_surface("DriverAwning", canvas, CANOPY_FRONT_Z, CANOPY_CARGO_FRONT_Z, _canopy_canvas())

	# Five bows make the canvas load path legible. Their side posts remain below
	# the cloth edge so the wagon stays open rather than becoming a box body.
	var bow_frames := _node("BowFrames", canopy)
	var support_posts := _node("SupportPosts", canopy)
	var bow_positions := [CANOPY_FRONT_Z, CANOPY_CARGO_FRONT_Z, 0.42, 1.62, CANOPY_REAR_Z]
	for bow_index in bow_positions.size():
		var z: float = bow_positions[bow_index]
		var bow := _node("Bow%02d" % bow_index, bow_frames)
		_make_canopy_arch(bow, z, -0.045, _wood_dark(), 0.032)
		if bow_index > 0:
			for side in [-1.0, 1.0]:
				_make_beam(
					"%sPost%02d" % ["Left" if side < 0.0 else "Right", bow_index],
					support_posts,
					Vector3(side * CANOPY_HALF_WIDTH, 1.48, z),
					Vector3(side * CANOPY_HALF_WIDTH, CANOPY_EDGE_Y - 0.02, z),
					0.035,
					_wood_dark()
				)
	var awning_braces := _node("DriverAwningBraces", canopy)
	for side in [-1.0, 1.0]:
		_make_beam(
			"%sCantileverBrace" % ("Left" if side < 0.0 else "Right"),
			awning_braces,
			Vector3(side * 0.79, 0.80, -1.78),
			Vector3(side * CANOPY_HALF_WIDTH, CANOPY_EDGE_Y - 0.04, CANOPY_FRONT_Z),
			0.032,
			_wood_dark()
		)

	var rails := _node("LongitudinalRails", canopy)
	_make_beam("LeftEaveRail", rails, Vector3(-CANOPY_HALF_WIDTH, CANOPY_EDGE_Y - 0.04, CANOPY_FRONT_Z), Vector3(-CANOPY_HALF_WIDTH, CANOPY_EDGE_Y - 0.04, CANOPY_REAR_Z), 0.038, _wood_dark())
	_make_beam("RightEaveRail", rails, Vector3(CANOPY_HALF_WIDTH, CANOPY_EDGE_Y - 0.04, CANOPY_FRONT_Z), Vector3(CANOPY_HALF_WIDTH, CANOPY_EDGE_Y - 0.04, CANOPY_REAR_Z), 0.038, _wood_dark())
	_make_beam("RidgeRail", rails, Vector3(0.0, CANOPY_EDGE_Y + CANOPY_RISE - 0.05, CANOPY_FRONT_Z), Vector3(0.0, CANOPY_EDGE_Y + CANOPY_RISE - 0.05, CANOPY_REAR_Z), 0.032, _wood_dark())

	# External ties show how the cloth is fixed to the bows without making the
	# entire roof visually heavy. They sit just above the canvas to avoid z-fight.
	var straps := _node("CanvasTieBands", canopy)
	for strap_index in 4:
		var z := lerpf(CANOPY_FRONT_Z, CANOPY_REAR_Z, float(strap_index) / 3.0)
		var strap := _node("TieBand%02d" % strap_index, straps)
		_make_canopy_arch(strap, z, 0.025, _leather(), 0.014)


func _make_canopy_surface(node_name: String, parent: Node, front_z: float, rear_z: float, material: Material) -> MeshInstance3D:
	var point_count := CANOPY_ARC_SEGMENTS + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in 2:
		var z := front_z if row == 0 else rear_z
		for arc_index in point_count:
			var ratio := float(arc_index) / float(CANOPY_ARC_SEGMENTS)
			var angle := lerpf(-PI * 0.5, PI * 0.5, ratio)
			vertices.append(Vector3(CANOPY_HALF_WIDTH * sin(angle), CANOPY_EDGE_Y + CANOPY_RISE * cos(angle), z))
			normals.append(Vector3(sin(angle), cos(angle), 0.0).normalized())
			uvs.append(Vector2(ratio, float(row)))
	for arc_index in CANOPY_ARC_SEGMENTS:
		var front_a := arc_index
		var front_b := arc_index + 1
		var rear_a := point_count + arc_index
		var rear_b := rear_a + 1
		indices.append_array(PackedInt32Array([front_a, rear_b, front_b, front_a, rear_a, rear_b]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _make_canopy_arch(parent: Node, z: float, radial_offset: float, material: Material, radius: float) -> void:
	var previous := Vector3.ZERO
	for arc_index in CANOPY_ARC_SEGMENTS + 1:
		var ratio := float(arc_index) / float(CANOPY_ARC_SEGMENTS)
		var angle := lerpf(-PI * 0.5, PI * 0.5, ratio)
		var normal := Vector3(sin(angle), cos(angle), 0.0)
		var point := Vector3(CANOPY_HALF_WIDTH * sin(angle), CANOPY_EDGE_Y + CANOPY_RISE * cos(angle), z) + normal * radial_offset
		if arc_index > 0:
			_make_beam("Arc%02d" % (arc_index - 1), parent, previous, point, radius, material)
		previous = point


func _build_reins() -> void:
	var reins := _node("Reins", self)
	for index in 4:
		var segment := _make_cylinder("ReinSegment%02d" % index, reins, 0.014, 1.0, Vector3.ZERO, Vector3.ZERO, _leather())
		_rein_segments.append(segment)
	_update_reins()


func _update_reins() -> void:
	if _driver_art == null or _rein_segments.size() != 4:
		return
	var hand_names := ["LeftHand", "RightHand"]
	var guides := [Vector3(-0.34, 1.26, -2.42), Vector3(0.34, 1.26, -2.42)]
	for index in 2:
		var hand_global: Vector3 = _driver_art.call("get_attachment_global_position", hand_names[index]) if _driver_art.has_method("get_attachment_global_position") else _driver_art.global_position
		var hand_local := to_local(hand_global)
		_set_beam(_rein_segments[index * 2], hand_local, guides[index], 0.014)
		_set_beam(_rein_segments[index * 2 + 1], guides[index], REIN_TARGETS[index], 0.014)


func _get_hand_rein_distance(socket_name: String, segment_index: int) -> float:
	if _driver_art == null or not _driver_art.has_method("get_attachment_global_position") or segment_index >= _rein_segments.size():
		return -1.0
	var hand_global: Vector3 = _driver_art.call("get_attachment_global_position", socket_name)
	var hand_local: Vector3 = to_local(hand_global)
	var segment := _rein_segments[segment_index]
	var mesh := segment.mesh as CylinderMesh
	var start := segment.position - segment.basis.y.normalized() * (mesh.height * 0.5)
	return hand_local.distance_to(start)


func _find_clip(player: AnimationPlayer, suffix: String) -> String:
	for raw_clip in player.get_animation_list():
		var clip := str(raw_clip)
		if clip == suffix or clip.ends_with("|" + suffix) or clip.ends_with("/" + suffix):
			return clip
	return ""


func _node(node_name: String, parent: Node) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	parent.add_child(node)
	return node


func _make_box(node_name: String, parent: Node, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)
	return instance


func _make_cylinder(node_name: String, parent: Node, radius: float, height: float, position: Vector3, rotation: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation
	parent.add_child(instance)
	return instance


func _make_torus(node_name: String, parent: Node, inner_radius: float, outer_radius: float, position: Vector3, rotation: Vector3, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 14
	mesh.ring_segments = 8
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation
	parent.add_child(instance)
	return instance


func _make_beam(node_name: String, parent: Node, from: Vector3, to: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var beam := _make_cylinder(node_name, parent, radius, from.distance_to(to), (from + to) * 0.5, Vector3.ZERO, material)
	_set_beam(beam, from, to, radius)
	return beam


func _set_beam(beam: MeshInstance3D, from: Vector3, to: Vector3, radius: float) -> void:
	var direction := to - from
	if direction.length_squared() < 0.000001:
		return
	var mesh := beam.mesh as CylinderMesh
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = direction.length()
	beam.position = (from + to) * 0.5
	var y_axis := direction.normalized()
	var x_axis := Vector3.RIGHT
	if absf(y_axis.dot(x_axis)) > 0.96:
		x_axis = Vector3.FORWARD
	var z_axis := x_axis.cross(y_axis).normalized()
	x_axis = y_axis.cross(z_axis).normalized()
	beam.basis = Basis(x_axis, y_axis, z_axis)


func _material(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _wood_dark() -> Material:
	return _material(Color("392116"), 0.88)


func _wood_warm() -> Material:
	return _material(Color("704122"), 0.84)


func _iron() -> Material:
	return _material(Color("34383a"), 0.56, 0.52)


func _leather() -> Material:
	return _material(Color("2b160c"), 0.80)


func _rope() -> Material:
	return _material(Color("9d7b49"), 0.94)


func _cloth(index: int) -> Material:
	var colors := [Color("435c66"), Color("7a573d"), Color("6b6651")]
	return _material(colors[index % colors.size()], 0.96)


func _canopy_canvas() -> Material:
	var material := _material(Color("858b87"), 0.97)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
