extends Node3D


const BASELINE_PATH := "res://data/presentation/art_scale_baseline.json"
const PREFERRED_ANIMATIONS := [
	"Farm_Harvest",
	"TreeChopping_Loop",
	"Sword_Regular_A",
	"Walk_Carry_Loop"
]

@export var orbit_target := Vector3(0.0, 1.8, 0.0)
@export_range(8.0, 40.0, 0.5) var camera_distance := 21.0
@export var character_rim: Material
@export var selection_outline: Material

@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var camera_rig: Node3D = $CameraRig
@onready var roof_controller: RoofVisibilityController = $RoofVisibilityController
@onready var status_label: Label = $UI/SafeArea/Panel/Margin/VBox/StatusLabel

var _yaw_degrees := 35.0
var _pitch_degrees := -24.0
var _playing_animation := ""


func _ready() -> void:
	_standardize_imported_materials($Samples)
	_apply_overlay($Samples/CharacterSample, character_rim)
	_apply_overlay($Samples/OutfitSample, character_rim)
	_apply_overlay($Samples/PropSample, selection_outline)
	_play_representative_animation()
	_update_camera()
	_update_status_label()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(8.0, camera_distance - 1.5)
			_update_camera()
			_update_status_label()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(40.0, camera_distance + 1.5)
			_update_camera()
			_update_status_label()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_yaw_degrees -= event.relative.x * 0.25
		_pitch_degrees = clampf(_pitch_degrees - event.relative.y * 0.2, -65.0, -12.0)
		_update_camera()


func get_validation_snapshot() -> Dictionary:
	return {
		"baseline_loaded": _load_baseline().is_empty() == false,
		"playing_animation": _playing_animation,
		"mesh_count": _count_nodes_of_type($Samples, "MeshInstance3D"),
		"skeleton_count": _count_nodes_of_type($Samples, "Skeleton3D"),
		"animation_player_count": _count_nodes_of_type($Samples, "AnimationPlayer"),
		"camera_distance": camera_distance,
		"roof_visibility": roof_controller.debug_get_snapshot()
	}


func debug_set_camera_distance(value: float) -> Dictionary:
	camera_distance = clampf(value, 8.0, 40.0)
	_update_camera()
	roof_controller.debug_apply_distance(camera_distance)
	_update_status_label()
	return roof_controller.debug_get_snapshot()


func _standardize_imported_materials(root_node: Node) -> void:
	for raw_node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.get_active_material(surface_index)
			if source_material is BaseMaterial3D:
				var material_copy := source_material.duplicate() as BaseMaterial3D
				material_copy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				material_copy.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				mesh_instance.set_surface_override_material(surface_index, material_copy)


func _apply_overlay(root_node: Node, overlay: Material) -> void:
	if overlay == null:
		return
	for raw_node in root_node.find_children("*", "MeshInstance3D", true, false):
		(raw_node as MeshInstance3D).material_overlay = overlay


func _play_representative_animation() -> void:
	var players := $Samples/AnimationSample.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var animation_player := players[0] as AnimationPlayer
	var available := animation_player.get_animation_list()
	for preferred in PREFERRED_ANIMATIONS:
		for candidate in available:
			if str(candidate).ends_with(preferred):
				_playing_animation = str(candidate)
				animation_player.play(candidate)
				return
	for candidate in available:
		if str(candidate) != "RESET":
			_playing_animation = str(candidate)
			animation_player.play(candidate)
			return


func _update_camera() -> void:
	var yaw := deg_to_rad(_yaw_degrees)
	var pitch := deg_to_rad(_pitch_degrees)
	var offset := Vector3(
		cos(pitch) * sin(yaw),
		-sin(pitch),
		cos(pitch) * cos(yaw)
	) * camera_distance
	camera_rig.global_position = orbit_target
	camera.position = offset
	camera.look_at(orbit_target, Vector3.UP)


func _update_status_label() -> void:
	var baseline := _load_baseline()
	var world_units: Dictionary = baseline.get("world_units", {})
	var building: Dictionary = baseline.get("building", {})
	var roof_snapshot := roof_controller.debug_get_snapshot()
	var roof_views: Array = roof_snapshot.get("views", [])
	var roof_summary := "waiting"
	if not roof_views.is_empty():
		roof_summary = "%.2f / %.2f" % [
			float(roof_views[0].get("roof_opacity", 1.0)),
			float(roof_views[1].get("roof_opacity", 1.0)) if roof_views.size() > 1 else 1.0
		]
	status_label.text = (
		"1 unit = %.1f m  |  grid %.1f m  |  storey %.3f m\nzoom %.1f m  |  roof alpha %s  |  animation: %s"
		% [
			float(world_units.get("godot_units_per_meter", 1.0)),
			float(building.get("module_grid_m", 2.0)),
			float(building.get("storey_height_m", 3.125)),
			camera_distance,
			roof_summary,
			_playing_animation if _playing_animation != "" else "not found"
		]
	)


func _load_baseline() -> Dictionary:
	var file := FileAccess.open(BASELINE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _count_nodes_of_type(root_node: Node, type_name: String) -> int:
	return root_node.find_children("*", type_name, true, false).size()
