class_name WorldHealthBar3D
extends Node3D

const HEALTHY_COLOR := Color("#71865a")
const DANGER_COLOR := Color("#a7433b")
const TRACK_COLOR := Color(0.10, 0.09, 0.08, 0.92)
const DANGER_THRESHOLD := 0.30

var _bar_width := 1.2
var _bar_height := 0.10
var _track: MeshInstance3D
var _fill: MeshInstance3D
var _fill_material: StandardMaterial3D
var _ratio := 1.0
var _is_danger := false
var _healthy_color := HEALTHY_COLOR
var _danger_color := DANGER_COLOR


func _ready() -> void:
	_ensure_visuals()


func configure_size(width: float, height: float) -> void:
	_bar_width = maxf(0.1, width)
	_bar_height = maxf(0.02, height)
	_ensure_visuals()
	_apply_mesh_sizes()
	_apply_ratio()


func configure_fill_colors(healthy_color: Color, danger_color: Color) -> void:
	_healthy_color = healthy_color
	_danger_color = danger_color
	_ensure_visuals()
	_fill_material.albedo_color = _danger_color if _is_danger else _healthy_color


func set_health(hp: int, max_hp: int, should_show: bool) -> void:
	var safe_max := maxi(1, max_hp)
	_ratio = clampf(float(hp) / float(safe_max), 0.0, 1.0)
	_is_danger = _ratio < DANGER_THRESHOLD
	_ensure_visuals()
	visible = should_show
	_fill_material.albedo_color = _danger_color if _is_danger else _healthy_color
	_apply_ratio()


func get_debug_snapshot() -> Dictionary:
	return {
		"visible": visible and is_visible_in_tree(),
		"local_visible": visible,
		"ratio": _ratio,
		"danger": _is_danger,
		"color": _fill_material.albedo_color if _fill_material != null else Color.TRANSPARENT,
		"width": _bar_width,
		"height": _bar_height,
		"fill_width": _get_fill_mesh_width() if _fill != null and _fill.visible else 0.0,
		"fill_mesh_width": _get_fill_mesh_width(),
		"fill_visible": _fill.visible if _fill != null else false,
		"fill_scale": _fill.scale if _fill != null else Vector3.ZERO,
		"fill_position": _fill.position if _fill != null else Vector3.ZERO,
		"fill_center_offset": _get_fill_center_offset(),
		"track_position": _track.position if _track != null else Vector3.ZERO,
		"position": position,
	}


func _ensure_visuals() -> void:
	if _track != null and _fill != null:
		return
	_track = MeshInstance3D.new()
	_track.name = "Track"
	_track.mesh = QuadMesh.new()
	_track.material_override = _make_material(TRACK_COLOR, 0)
	add_child(_track)

	_fill = MeshInstance3D.new()
	_fill.name = "Fill"
	_fill.mesh = QuadMesh.new()
	_fill_material = _make_material(_healthy_color, 1)
	_fill.material_override = _fill_material
	add_child(_fill)
	_apply_mesh_sizes()


func _apply_mesh_sizes() -> void:
	if _track == null or _fill == null:
		return
	(_track.mesh as QuadMesh).size = Vector2(_bar_width, _bar_height)
	(_fill.mesh as QuadMesh).size = Vector2(maxf(0.0001, _bar_width * _ratio), _bar_height * 0.68)


func _apply_ratio() -> void:
	if _fill == null:
		return
	# Billboard materials do not reliably preserve a MeshInstance3D's inherited
	# horizontal scale or a child node's parent-rotated horizontal offset. Keep
	# Track and Fill on the same billboard origin, then resize and left-align the
	# fill inside its own camera-facing mesh space.
	_fill.scale = Vector3.ONE
	_fill.position = Vector3.ZERO
	var fill_mesh := _fill.mesh as QuadMesh
	fill_mesh.size.x = maxf(0.0001, _bar_width * _ratio)
	fill_mesh.center_offset = Vector3(-_bar_width * (1.0 - _ratio) * 0.5, 0.0, 0.0)
	_fill.visible = _ratio > 0.0


func _get_fill_mesh_width() -> float:
	if _fill == null or not _fill.mesh is QuadMesh:
		return 0.0
	return (_fill.mesh as QuadMesh).size.x


func _get_fill_center_offset() -> Vector3:
	if _fill == null or not _fill.mesh is QuadMesh:
		return Vector3.ZERO
	return (_fill.mesh as QuadMesh).center_offset


func _make_material(color: Color, priority: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = priority
	return material
