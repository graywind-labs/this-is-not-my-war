extends Node3D

const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const DEFENSE_DEVICE_SYSTEM_PATH := "/root/Main/Systems/DefenseDeviceSystem"
const RING_SEGMENTS := 128
const RING_GROUND_Y := 0.085
const RANGE_EPSILON := 0.001
const POSITION_EPSILON_SQUARED := 0.0001
const RING_COLOR := Color(0.36, 0.78, 1.0, 0.34)

var _selection_type := ""
var _selection_id := ""
var _latest_authority_snapshot: Dictionary = {}
var _displayed_range := 0.0
var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "RangeRingMesh"
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.visible = false
	add_child(_mesh_instance)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	if event_bus.has_signal("npc_clicked"):
		event_bus.npc_clicked.connect(_on_npc_clicked)
	if event_bus.has_signal("enemy_clicked"):
		event_bus.enemy_clicked.connect(_on_non_combat_world_selection)
	if event_bus.has_signal("defense_device_clicked"):
		event_bus.defense_device_clicked.connect(_on_defense_device_clicked)
	if event_bus.has_signal("world_selection_cleared"):
		event_bus.world_selection_cleared.connect(clear_selection)
	if event_bus.has_signal("building_clicked"):
		event_bus.building_clicked.connect(_on_non_combat_world_selection)
	if event_bus.has_signal("horse_clicked"):
		event_bus.horse_clicked.connect(_on_non_combat_world_selection)
	if event_bus.has_signal("notice_board_clicked"):
		event_bus.notice_board_clicked.connect(_on_simple_non_combat_selection)
	if event_bus.has_signal("merchant_clicked"):
		event_bus.merchant_clicked.connect(_on_simple_non_combat_selection)
	if event_bus.has_signal("npc_state_changed"):
		event_bus.npc_state_changed.connect(_on_npc_state_changed)
	if event_bus.has_signal("defense_device_state_changed"):
		event_bus.defense_device_state_changed.connect(_on_defense_device_state_changed)


func _process(_delta: float) -> void:
	if _selection_id.is_empty():
		return
	_refresh_from_authority(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clear_selection()


func clear_selection() -> void:
	_selection_type = ""
	_selection_id = ""
	_latest_authority_snapshot.clear()
	_displayed_range = 0.0
	if _mesh_instance != null:
		_mesh_instance.visible = false


func debug_select_npc(npc_id: String) -> Dictionary:
	_select("npc", npc_id)
	return get_debug_snapshot()


func debug_select_defense_device(deployment_id: String) -> Dictionary:
	_select("defense_device", deployment_id)
	return get_debug_snapshot()


func get_debug_snapshot() -> Dictionary:
	return {
		"selection_type": _selection_type,
		"selection_id": _selection_id,
		"visible": _mesh_instance != null and _mesh_instance.visible,
		"displayed_range": _displayed_range,
		"world_position": global_position,
		"has_collision": false,
		"ring_segments": RING_SEGMENTS,
		"color": RING_COLOR,
		"authority": _latest_authority_snapshot.duplicate(true)
	}


func _on_npc_clicked(npc_id: String) -> void:
	_select("npc", npc_id)


func _on_defense_device_clicked(deployment_id: String) -> void:
	_select("defense_device", deployment_id)


func _on_non_combat_world_selection(_id: String) -> void:
	clear_selection()


func _on_simple_non_combat_selection() -> void:
	clear_selection()


func _on_npc_state_changed(npc_id: String) -> void:
	if _selection_type == "npc" and _selection_id == npc_id:
		var npc_system := get_node_or_null("/root/Main/Systems/NPCSystem")
		if (
			npc_system != null
			and npc_system.has_method("is_active_npc_state_change_relevant")
			and not npc_system.is_active_npc_state_change_relevant(
				npc_id,
				["hp", "max_hp", "unconscious", "escaped", "behavior_mode", "combat_mode", "combat_mounted"]
			)
		):
			return
		_refresh_from_authority(true)


func _on_defense_device_state_changed(_snapshot: Dictionary) -> void:
	if _selection_type == "defense_device":
		_refresh_from_authority(true)


func _select(selection_type: String, selection_id: String) -> void:
	_selection_type = selection_type
	_selection_id = selection_id
	_latest_authority_snapshot.clear()
	_displayed_range = 0.0
	_refresh_from_authority(true)


func _refresh_from_authority(force_mesh_refresh: bool) -> void:
	var snapshot := _get_authority_snapshot()
	_latest_authority_snapshot = snapshot.duplicate(true)
	if not bool(snapshot.get("ready", false)):
		_displayed_range = 0.0
		_mesh_instance.visible = false
		return
	var effective_range := maxf(0.0, float(snapshot.get("effective_range", 0.0)))
	var world_position := snapshot.get("world_position", Vector3.ZERO) as Vector3
	if effective_range <= 0.0:
		_displayed_range = 0.0
		_mesh_instance.visible = false
		return
	var ring_position := Vector3(world_position.x, RING_GROUND_Y, world_position.z)
	if global_position.distance_squared_to(ring_position) > POSITION_EPSILON_SQUARED:
		global_position = ring_position
	if force_mesh_refresh or absf(effective_range - _displayed_range) > RANGE_EPSILON or _mesh_instance.mesh == null:
		_rebuild_ring_mesh(effective_range)
	_displayed_range = effective_range
	_mesh_instance.visible = true


func _get_authority_snapshot() -> Dictionary:
	if _selection_type == "npc":
		var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
		if combat_system != null and combat_system.has_method("get_npc_attack_range_indicator_snapshot"):
			return combat_system.get_npc_attack_range_indicator_snapshot(_selection_id)
		return {"ready": false, "reason": "combat_system_unavailable", "npc_id": _selection_id}
	if _selection_type == "defense_device":
		var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
		if device_system != null and device_system.has_method("get_attack_range_indicator_snapshot"):
			return device_system.get_attack_range_indicator_snapshot(_selection_id)
		return {"ready": false, "reason": "defense_device_system_unavailable", "deployment_id": _selection_id}
	return {"ready": false, "reason": "selection_unavailable"}


func _rebuild_ring_mesh(radius: float) -> void:
	var ring_width := clampf(radius * 0.012, 0.12, 0.38)
	var inner_radius := maxf(0.01, radius - ring_width)
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = RING_COLOR
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = false
	material.render_priority = 1
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material)
	for index in range(RING_SEGMENTS + 1):
		var angle := TAU * float(index) / float(RING_SEGMENTS)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		mesh.surface_set_normal(Vector3.UP)
		mesh.surface_set_color(RING_COLOR)
		mesh.surface_add_vertex(direction * inner_radius)
		mesh.surface_set_normal(Vector3.UP)
		mesh.surface_set_color(RING_COLOR)
		mesh.surface_add_vertex(direction * radius)
	mesh.surface_end()
	_mesh_instance.mesh = mesh
