class_name FormalFortificationArtView
extends BuildingArtView


const FORMAL_GATE_ART_VIEW_SCRIPT := preload("res://scripts/presentation/buildings/FormalGateArtView.gd")
const ROCK_BASE_COLOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RockTrim_BaseColor.png"
const ROCK_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RockTrim_Normal.png"
const ROCK_ORM := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_RockTrim_ORM.png"
const BRICK_BASE_COLOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_UnevenBrick_BaseColor.png"
const BRICK_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_UnevenBrick_Normal.png"
const BRICK_ROUGHNESS := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_UnevenBrick_Roughness.png"
const WOOD_BASE_COLOR := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_BaseColor.png"
const WOOD_NORMAL := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_Normal.png"
const WOOD_ROUGHNESS := "res://assets/3d/quaternius/buildings/wall_plaster_door_round_T_WoodTrim_Roughness.png"

const PLATFORM_REQUIRED_LEVELS := {
	"wall_slot_01": 1,
	"wall_slot_02": 2,
	"wall_slot_03": 4,
	"wall_slot_04": 6
}
const PLATFORM_LATERAL_OFFSETS := {
	"wall_slot_01": -7.6,
	"wall_slot_02": 7.6,
	"wall_slot_03": -13.0,
	"wall_slot_04": 13.0
}
const PLATFORM_SIZE := Vector2(3.6, 3.4)

var _station: Dictionary = {}
var _material_cache: Dictionary = {}
var _level_roots: Dictionary = {}
var _platform_roots: Dictionary = {}
var _gate_views: Dictionary = {}
var _damage_ratio := 1.0


func configure(station_config: Dictionary) -> void:
	_station = station_config.duplicate(true)


func _ready() -> void:
	_building_level = 1
	_build_formal_fortifications()
	super._ready()


func apply_roof_camera_distance(camera_distance: float, zoom_normalized: float) -> void:
	_camera_distance = camera_distance
	_zoom_normalized = zoom_normalized
	_set_roof_opacity(1.0)
	_set_exterior_opacity(1.0)


func is_interior_revealed_for_selection() -> bool:
	return false


func debug_force_visual_level(level: int) -> Dictionary:
	_apply_visual_level(clampi(level, 1, 6), false)
	return get_art_slice_snapshot()


func get_art_slice_snapshot() -> Dictionary:
	var platform_states := {}
	var active_count := 0
	for slot_id in PLATFORM_REQUIRED_LEVELS.keys():
		var root := _platform_roots.get(slot_id) as Node3D
		var visible := root != null and root.visible
		if visible:
			active_count += 1
		platform_states[slot_id] = {
			"required_level": int(PLATFORM_REQUIRED_LEVELS[slot_id]),
			"visible": visible,
			"global_position": (
				root.to_global(Vector3(0.0, float(root.get_meta("device_anchor_y", 0.0)), 0.0))
				if root != null
				else Vector3.ZERO
			),
			"platform_size": PLATFORM_SIZE,
			"host_structure": "front_wall",
			"lateral_offset_from_gate": float(PLATFORM_LATERAL_OFFSETS[slot_id]),
			"wall_segment_id": str(root.get_meta("wall_segment_id", "")) if root != null else "",
			"rotation_y_degrees": root.rotation_degrees.y if root != null else 0.0
		}
	var gate_states := {}
	for gate_id in _gate_views.keys():
		var gate_view := _gate_views.get(gate_id) as Node
		gate_states[gate_id] = gate_view.call("debug_get_snapshot") if gate_view != null else {}
	return {
		"building_id": building_id,
		"building_level": _building_level,
		"maximum_level": 6,
		"wall_segment_count": (_station.get("wall_segments", []) as Array).size(),
		"wall_height": 3.20,
		"fortification_material_language": "timber_border_stockade",
		"stone_role": "low_damp_proof_footing_only",
		"crenellated": true,
		"patrol_walkway": true,
		"platform_capacity_profile": [1, 2, 2, 3, 3, 4],
		"platform_required_levels": PLATFORM_REQUIRED_LEVELS.duplicate(true),
		"active_platform_count": active_count,
		"platforms": platform_states,
		"range_visual_stage": 2 if _building_level >= 5 else (1 if _building_level >= 3 else 0),
		"range_authority": "BuildingSystem_and_DefenseDeviceSystem",
		"damage_ratio": _damage_ratio,
		"gates": gate_states,
		"authority_role": "presentation_only"
	}


func get_gate_snapshot(gate_id: String) -> Dictionary:
	var gate_view := _gate_views.get(gate_id) as Node
	return gate_view.call("debug_get_snapshot") if gate_view != null else {}


func _build_formal_fortifications() -> void:
	building_id = "wall"
	roof_path = NodePath("NonexistentRoof")
	exterior_path = NodePath("BaseVisuals")
	interaction_bounds_size = Vector3.ZERO
	set_meta("art_revision", "t0132_p3r4_segment_aligned_attachments")
	set_meta("fortification_material_language", "timber_border_stockade")
	set_meta("slot_capacity_profile", [1, 2, 2, 3, 3, 4])
	set_meta("enemy_gate_trigger", false)

	var base := Node3D.new()
	base.name = "BaseVisuals"
	add_child(base)
	_build_wall_segments(base)
	_build_platforms(base)
	_build_gate_views()
	_build_upgrade_visuals()
	_build_damage_visuals()
	_apply_visual_level(1, false)
	_apply_damage_ratio(1.0)


func _build_wall_segments(parent: Node3D) -> void:
	var walls := Node3D.new()
	walls.name = "TexturedWallSegments"
	parent.add_child(walls)
	for raw_segment in _station.get("wall_segments", []):
		if not raw_segment is Dictionary:
			continue
		var segment := raw_segment as Dictionary
		var from_point := _v2(segment.get("from", [0.0, 0.0]))
		var to_point := _v2(segment.get("to", [0.0, 0.0]))
		var delta := to_point - from_point
		var length := delta.length()
		if length <= 0.01:
			continue
		var root := Node3D.new()
		root.name = "Wall_%s" % str(segment.get("id", "segment"))
		var middle := (from_point + to_point) * 0.5
		root.position = Vector3(middle.x, 0.0, middle.y)
		root.rotation.y = atan2(delta.x, delta.y)
		root.set_meta("wall_segment_id", str(segment.get("id", "")))
		walls.add_child(root)
		_add_textured_box(root, "LowStoneFooting", Vector3(0.0, 0.12, 0.0), Vector3(1.38, 0.24, length + 0.08), "rock", Color("#686a66"), 0.68)
		_add_textured_box(root, "TimberCurtain", Vector3(0.0, 1.62, 0.0), Vector3(1.02, 2.78, length), "wood", Color("#6c503b"), 0.88)
		_add_textured_box(root, "UpperTimberCap", Vector3(0.0, 3.05, 0.0), Vector3(1.30, 0.22, length + 0.04), "wood", Color("#4d382d"), 0.92)
		_add_textured_box(root, "TimberPatrolDeck", Vector3(-0.67, 2.92, 0.0), Vector3(1.68, 0.18, maxf(0.2, length - 0.18)), "wood", Color("#71553e"), 0.82)
		var post_count := maxi(2, int(ceil(length / 2.65)) + 1)
		var post_spacing := length / float(post_count - 1)
		for post_index in post_count:
			var post_z := -length * 0.5 + float(post_index) * post_spacing
			for face_x in [-0.60, 0.60]:
				_add_textured_box(root, "StockadePost", Vector3(face_x, 1.65, post_z), Vector3(0.24, 3.06, 0.28), "wood", Color("#4f392d"), 1.0)
		for rail_y in [0.82, 2.10]:
			for face_x in [-0.64, 0.64]:
				_add_textured_box(root, "HorizontalBindingBeam", Vector3(face_x, rail_y, 0.0), Vector3(0.20, 0.22, length + 0.04), "wood", Color("#49342a"), 0.94)
		for support_index in range(maxi(1, int(floor(length / 5.0)))):
			var support_z := -length * 0.5 + (float(support_index) + 0.5) * 5.0
			if support_z > length * 0.5 - 0.25:
				continue
			var brace := _add_textured_box(root, "WalkwayBrace", Vector3(-1.05, 2.46, support_z), Vector3(0.15, 1.05, 0.16), "wood", Color("#584335"), 0.82)
			brace.rotation_degrees.z = -31.0
		_build_segment_crenellations(root, length)


func _build_segment_crenellations(parent: Node3D, length: float) -> void:
	var count := maxi(1, int(floor(length / 2.45)))
	var spacing := length / float(count)
	for index in count:
		var z := -length * 0.5 + (float(index) + 0.5) * spacing
		for x in [-0.55, 0.55]:
			_add_textured_box(parent, "TimberMerlon", Vector3(x, 3.48, z), Vector3(0.42, 0.62, minf(1.26, spacing * 0.58)), "wood", Color("#58402f"), 0.94)


func _build_platforms(parent: Node3D) -> void:
	var platforms := Node3D.new()
	platforms.name = "DefensePlatforms"
	parent.add_child(platforms)
	var gate := _station.get("front_gate", {}) as Dictionary
	for slot_id in PLATFORM_REQUIRED_LEVELS.keys():
		var root := Node3D.new()
		root.name = "%sPlatform" % str(slot_id).to_pascal_case()
		var pose := _get_front_wall_attachment_pose(float(PLATFORM_LATERAL_OFFSETS[slot_id]), gate)
		root.position = pose.get("position", Vector3.ZERO) as Vector3
		root.rotation_degrees.y = float(pose.get("rotation_y_degrees", 0.0))
		root.set_meta("building_id", "wall")
		root.set_meta("host_structure", "front_wall")
		root.set_meta("wall_segment_id", str(pose.get("wall_segment_id", "")))
		root.set_meta("slot_id", slot_id)
		root.set_meta("required_level", int(PLATFORM_REQUIRED_LEVELS[slot_id]))
		root.set_meta("device_anchor_y", float(gate.get("height", 3.2)) + 0.35)
		platforms.add_child(root)
		_platform_roots[slot_id] = root
		_add_textured_box(root, "TimberCorbelFrame", Vector3(0.0, 3.15, 0.0), Vector3(PLATFORM_SIZE.x, 0.50, PLATFORM_SIZE.y), "wood", Color("#503a2d"), 0.92)
		_add_textured_box(root, "TimberDeck", Vector3(0.0, 3.47, 0.0), Vector3(PLATFORM_SIZE.x - 0.18, 0.16, PLATFORM_SIZE.y - 0.18), "wood", Color("#644c3b"), 0.78)
		for x in [-1.56, 1.56]:
			_add_textured_box(root, "TimberSideParapet", Vector3(x, 3.78, 0.0), Vector3(0.28, 0.62, PLATFORM_SIZE.y), "wood", Color("#58402f"), 0.94)
		for x in [-1.42, -0.48, 0.48, 1.42]:
			_add_textured_box(root, "TimberFrontMerlon", Vector3(x, 3.80, 1.53), Vector3(0.48, 0.66, 0.30), "wood", Color("#58402f"), 0.94)
		for x in [-1.40, 1.40]:
			_add_textured_box(root, "PlatformSupportPost", Vector3(x, 1.62, -0.72), Vector3(0.26, 3.05, 0.28), "wood", Color("#49342a"), 1.0)
		for x in [-1.42, 1.42]:
			var brace := _add_textured_box(root, "PlatformBrace", Vector3(x, 2.64, -0.72), Vector3(0.18, 1.42, 0.18), "wood", Color("#554034"), 0.80)
			brace.rotation_degrees.x = -24.0


func _build_gate_views() -> void:
	var gates := Node3D.new()
	gates.name = "GateArt"
	add_child(gates)
	for key in ["front_gate", "back_gate"]:
		var config := _station.get(key, {}) as Dictionary
		if config.is_empty():
			continue
		var gate_view := FORMAL_GATE_ART_VIEW_SCRIPT.new() as FormalGateArtView
		if gate_view == null:
			continue
		gate_view.configure(config)
		gate_view.name = "%sArt" % str(config.get("id", key)).to_pascal_case()
		var center := _v2(config.get("center", [0.0, 0.0]))
		gate_view.position = Vector3(center.x, 0.0, center.y)
		gate_view.rotation_degrees.y = float(config.get("rotation_degrees", 0.0))
		gates.add_child(gate_view)
		_gate_views[str(config.get("id", key))] = gate_view


func _build_upgrade_visuals() -> void:
	var upgrades := Node3D.new()
	upgrades.name = "UpgradeVisuals"
	add_child(upgrades)
	for level in range(2, 7):
		var root := Node3D.new()
		root.name = "Level%d" % level
		root.set_meta("required_level", level)
		upgrades.add_child(root)
		_level_roots[level] = root

	var front_gate := _station.get("front_gate", {}) as Dictionary
	var level_3 := _level_roots[3] as Node3D
	for lateral in [-5.3, 5.3]:
		var pose := _get_front_wall_attachment_pose(lateral, front_gate)
		var p := pose.get("position", Vector3.ZERO) as Vector3
		_add_cylinder(level_3, "RangeSurveyPost", p + Vector3(0.0, 4.28, 0.0), 0.065, 1.68, Color("#3d3028"))
		var crossbar := _add_box(level_3, "RangeSurveyCrossbar", p + Vector3(0.0, 4.78, 0.0), Vector3(0.68, 0.10, 0.10), Color("#a38755"))
		crossbar.rotation_degrees.y = float(pose.get("rotation_y_degrees", 0.0))
		crossbar.set_meta("wall_segment_id", str(pose.get("wall_segment_id", "")))
		crossbar.set_meta("wall_attachment_kind", "range_crossbar")

	var level_5 := _level_roots[5] as Node3D
	for lateral in [-18.5, -6.3, 6.3, 18.5]:
		var pose := _get_front_wall_attachment_pose(lateral, front_gate)
		var p := pose.get("position", Vector3.ZERO) as Vector3
		var attachment_basis := Basis(Vector3.UP, deg_to_rad(float(pose.get("rotation_y_degrees", 0.0))))
		_add_cylinder(level_5, "CalibratedRangeStake", p + Vector3(0.0, 4.30, 0.0), 0.055, 1.90, Color("#372d27"))
		var pennant := _add_box(level_5, "RangePennant", p + attachment_basis * Vector3(0.28, 4.72, 0.0), Vector3(0.52, 0.34, 0.045), Color("#765044"))
		pennant.rotation_degrees.y = float(pose.get("rotation_y_degrees", 0.0))
		pennant.set_meta("wall_segment_id", str(pose.get("wall_segment_id", "")))
		pennant.set_meta("wall_attachment_kind", "range_pennant")

func _build_damage_visuals() -> void:
	var damage := Node3D.new()
	damage.name = "DamageVisuals"
	add_child(damage)
	var mild := Node3D.new()
	mild.name = "Mild"
	damage.add_child(mild)
	var heavy := Node3D.new()
	heavy.name = "Heavy"
	damage.add_child(heavy)
	var front_gate := _station.get("front_gate", {}) as Dictionary
	var center := _v2(front_gate.get("center", [5.0, 54.0]))
	for x in [-10.5, 10.5]:
		var brace := _add_textured_box(mild, "EmergencyBrace", Vector3(center.x + x, 1.45, center.y - 0.72), Vector3(0.22, 2.80, 0.20), "wood", Color("#4d3b31"), 0.82)
		brace.rotation_degrees.z = 25.0 if x < 0.0 else -25.0
	for index in range(6):
		var fallen := _add_textured_box(heavy, "FallenTimber", Vector3(center.x - 6.0 + index * 2.35, 0.18, center.y - 1.35 - float(index % 2) * 0.34), Vector3(1.34, 0.26, 0.32), "wood", Color("#4b352a"), 1.0)
		fallen.rotation_degrees.y = -18.0 + float(index) * 7.0


func _refresh_building_state() -> void:
	super._refresh_building_state()
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building"):
		return
	var building: Dictionary = building_system.get_building("wall")
	if building.is_empty():
		return
	var maximum_hp := maxi(1, int(building.get("max_hp", 1)))
	_apply_damage_ratio(float(building.get("hp", maximum_hp)) / float(maximum_hp))


func _apply_visual_level(level: int, upgrade_in_progress: bool) -> void:
	_building_level = clampi(level, 1, 6)
	_upgrade_in_progress = upgrade_in_progress
	for required_level in _level_roots.keys():
		var root := _level_roots.get(required_level) as Node3D
		if root != null:
			root.visible = _building_level >= int(required_level)
	for slot_id in _platform_roots.keys():
		var platform := _platform_roots.get(slot_id) as Node3D
		if platform != null:
			platform.visible = _building_level >= int(PLATFORM_REQUIRED_LEVELS.get(slot_id, 99))


func _apply_damage_ratio(ratio: float) -> void:
	_damage_ratio = clampf(ratio, 0.0, 1.0)
	var mild := get_node_or_null("DamageVisuals/Mild") as Node3D
	var heavy := get_node_or_null("DamageVisuals/Heavy") as Node3D
	if mild != null:
		mild.visible = _damage_ratio < 0.72
	if heavy != null:
		heavy.visible = _damage_ratio < 0.38


func _v2(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _get_front_wall_attachment_pose(lateral_offset: float, gate: Dictionary) -> Dictionary:
	var gate_center := _v2(gate.get("center", [5.0, 54.0]))
	var segment_id := "north_west_a" if lateral_offset < 0.0 else "north_east"
	var segment := _find_wall_segment(segment_id)
	if segment.is_empty():
		var fallback_rotation := float(gate.get("rotation_degrees", -4.0))
		var fallback_basis := Basis(Vector3.UP, deg_to_rad(fallback_rotation))
		return {
			"position": Vector3(gate_center.x, 0.0, gate_center.y) + fallback_basis * Vector3(lateral_offset, 0.0, 0.0),
			"rotation_y_degrees": fallback_rotation,
			"wall_segment_id": "fallback_gate_axis"
		}
	var point_a := _v2(segment.get("from", [0.0, 0.0]))
	var point_b := _v2(segment.get("to", [0.0, 0.0]))
	var near_point := point_a if point_a.distance_to(gate_center) <= point_b.distance_to(gate_center) else point_b
	var far_point := point_b if near_point == point_a else point_a
	var outward_tangent := (far_point - near_point).normalized()
	var distance_from_gate_edge := maxf(0.0, absf(lateral_offset) - float(gate.get("clear_width", 6.0)) * 0.5)
	var point := near_point + outward_tangent * distance_from_gate_edge
	var low_x_point := point_a if point_a.x <= point_b.x else point_b
	var high_x_point := point_b if point_a.x <= point_b.x else point_a
	var positive_x_tangent := (high_x_point - low_x_point).normalized()
	return {
		"position": Vector3(point.x, 0.0, point.y),
		"rotation_y_degrees": rad_to_deg(atan2(-positive_x_tangent.y, positive_x_tangent.x)),
		"wall_segment_id": segment_id
	}


func _find_wall_segment(segment_id: String) -> Dictionary:
	for raw_segment in _station.get("wall_segments", []):
		if raw_segment is Dictionary and str(raw_segment.get("id", "")) == segment_id:
			return raw_segment as Dictionary
	return {}


func _add_textured_box(parent: Node3D, node_name: String, center: Vector3, size: Vector3, texture_kind: String, tint: Color, density: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _textured_material(texture_kind, tint, density)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_box(parent: Node3D, node_name: String, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, center: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var key := "flat:%s" % color.to_html(true)
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	_material_cache[key] = material
	return material


func _textured_material(kind: String, tint: Color, density: float) -> StandardMaterial3D:
	var key := "textured:%s:%s:%.2f" % [kind, tint.to_html(true), density]
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.88
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.texture_repeat = true
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * density
	var base_path := ROCK_BASE_COLOR
	var normal_path := ROCK_NORMAL
	var roughness_path := ""
	if kind == "brick":
		base_path = BRICK_BASE_COLOR
		normal_path = BRICK_NORMAL
		roughness_path = BRICK_ROUGHNESS
	elif kind == "wood":
		base_path = WOOD_BASE_COLOR
		normal_path = WOOD_NORMAL
		roughness_path = WOOD_ROUGHNESS
	if ResourceLoader.exists(base_path):
		material.albedo_texture = load(base_path) as Texture2D
	if ResourceLoader.exists(normal_path):
		material.normal_enabled = true
		material.normal_scale = 0.62
		material.normal_texture = load(normal_path) as Texture2D
	if kind == "rock" and ResourceLoader.exists(ROCK_ORM):
		material.orm_texture = load(ROCK_ORM) as Texture2D
	elif not roughness_path.is_empty() and ResourceLoader.exists(roughness_path):
		material.roughness_texture = load(roughness_path) as Texture2D
	_material_cache[key] = material
	return material
