extends Node

const BUILDING_DEFS_FILE := "building_defs.json"
const BUILDING_ROOT_PATH := "/root/Main/WorldRoot/Station/Buildings"
const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const CLICK_AREA_NAME := "ClickArea"
const PICK_RAY_LENGTH := 1000.0
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"

var _buildings: Dictionary = {}
var _building_order: Array[String] = []
var _selected_building_id: String = ""
var _building_scene_nodes: Dictionary = {}


func initialize() -> void:
	_buildings.clear()
	_building_order.clear()
	_building_scene_nodes.clear()
	_selected_building_id = ""

	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		push_error("BuildingSystem requires ConfigLoader autoload.")
		return

	var loaded_defs: Variant = config_loader.load_data_file(BUILDING_DEFS_FILE, [])
	if not loaded_defs is Array:
		push_error("Building definitions must be a JSON array: %s" % BUILDING_DEFS_FILE)
		return

	for raw_definition in loaded_defs:
		if not raw_definition is Dictionary:
			push_error("Skipped invalid building definition because it is not a dictionary.")
			continue

		var definition: Dictionary = raw_definition
		var building_id := str(definition.get("id", ""))
		if building_id.is_empty():
			push_error("Skipped building definition with empty id.")
			continue

		var max_hp := int(definition.get("max_hp", definition.get("hp", 1)))
		var hp := clampi(int(definition.get("hp", max_hp)), 0, max_hp)
		definition["hp"] = hp
		definition["max_hp"] = max_hp
		definition["level"] = max(1, int(definition.get("level", 1)))

		_buildings[building_id] = definition.duplicate(true)
		_building_order.append(building_id)
		_bind_scene_nodes(building_id, definition)


func _ready() -> void:
	initialize()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var building_id := _pick_building_at_screen_position(event.position)
		if not building_id.is_empty():
			_select_building(building_id)
			get_viewport().set_input_as_handled()


func get_building(building_id: String) -> Dictionary:
	if not _buildings.has(building_id):
		push_warning("Unknown building id: %s" % building_id)
		return {}
	return _buildings[building_id].duplicate(true)


func get_building_ids() -> Array[String]:
	return _building_order.duplicate()


func get_building_snapshot() -> Dictionary:
	return _buildings.duplicate(true)


func get_selected_building_id() -> String:
	return _selected_building_id


func get_building_entry_position(building_id: String) -> Variant:
	if not _buildings.has(building_id):
		push_warning("Cannot get entry position for unknown building: %s" % building_id)
		return null
	if not _building_scene_nodes.has(building_id):
		push_warning("Building has no bound scene nodes: %s" % building_id)
		return null

	var node_paths: Array = _building_scene_nodes.get(building_id, [])
	for raw_path in node_paths:
		var building_node := get_node_or_null(NodePath(str(raw_path))) as Node3D
		if building_node == null:
			continue

		var entry_position := building_node.global_position
		var entry_offset := Vector3(0.0, 0.0, 1.2)
		if building_node is MeshInstance3D:
			var mesh_instance := building_node as MeshInstance3D
			if mesh_instance.mesh != null:
				var mesh_size := mesh_instance.mesh.get_aabb().size
				entry_offset.z = maxf(1.2, mesh_size.z * 0.5 + 0.8)
		entry_position += entry_offset
		entry_position.y = 0.0
		return entry_position

	return null


func get_building_location_context(building_id: String) -> Dictionary:
	var building := get_building(building_id)
	if building.is_empty():
		return {}

	var workstations: Array = building.get("workstations", [])
	return {
		"id": building_id,
		"name": str(building.get("name", building_id)),
		"level": int(building.get("level", 1)),
		"hp": int(building.get("hp", 0)),
		"max_hp": int(building.get("max_hp", 0)),
		"tags": building.get("tags", []),
		"workstation_count": workstations.size(),
		"recent_events": [],
		"public_notes": []
	}


func can_repair_building(building_id: String) -> bool:
	if not _buildings.has(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	if int(building.get("hp", 0)) >= int(building.get("max_hp", 0)):
		return false

	var repair_config: Dictionary = building.get("repair", {})
	var cost: Dictionary = repair_config.get("cost", {})
	if cost.is_empty():
		return false

	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	return resource_system != null and resource_system.can_afford(cost)


func repair_building(building_id: String) -> bool:
	if not can_repair_building(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	var repair_config: Dictionary = building.get("repair", {})
	var cost: Dictionary = repair_config.get("cost", {})
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null or not resource_system.spend_resources(cost):
		return false

	var max_hp := int(building.get("max_hp", 0))
	var restore_amount: int = maxi(1, int(repair_config.get("hp_restore", 1)))
	building["hp"] = mini(max_hp, int(building.get("hp", 0)) + restore_amount)
	_buildings[building_id] = building
	_refresh_bound_scene_nodes(building_id)
	_emit_building_clicked_if_selected(building_id)
	return true


func can_upgrade_building(building_id: String) -> bool:
	if not _buildings.has(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	var upgrade_config: Dictionary = building.get("upgrade", {})
	if upgrade_config.is_empty():
		return false

	var max_level := int(upgrade_config.get("max_level", int(building.get("level", 1))))
	if int(building.get("level", 1)) >= max_level:
		return false

	var cost: Dictionary = upgrade_config.get("cost", {})
	if cost.is_empty():
		return false

	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	return resource_system != null and resource_system.can_afford(cost)


func upgrade_building(building_id: String) -> bool:
	if not can_upgrade_building(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	var upgrade_config: Dictionary = building.get("upgrade", {})
	var cost: Dictionary = upgrade_config.get("cost", {})
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null or not resource_system.spend_resources(cost):
		return false

	var max_hp_bonus: int = maxi(0, int(upgrade_config.get("max_hp_bonus", 0)))
	building["level"] = int(building.get("level", 1)) + 1
	building["max_hp"] = int(building.get("max_hp", 0)) + max_hp_bonus
	building["hp"] = mini(int(building.get("max_hp", 0)), int(building.get("hp", 0)) + max_hp_bonus)
	_apply_workstation_upgrade(building, upgrade_config)
	_buildings[building_id] = building
	_refresh_bound_scene_nodes(building_id)
	_emit_building_clicked_if_selected(building_id)
	return true


func debug_damage_building(building_id: String, amount: int) -> bool:
	if amount <= 0 or not _buildings.has(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	building["hp"] = maxi(0, int(building.get("hp", 0)) - amount)
	_buildings[building_id] = building
	_refresh_bound_scene_nodes(building_id)
	_emit_building_clicked_if_selected(building_id)
	return true


func restore_building_hp(building_id: String, amount: int) -> bool:
	if amount <= 0 or not _buildings.has(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	var max_hp := int(building.get("max_hp", 0))
	var current_hp := int(building.get("hp", 0))
	if current_hp >= max_hp:
		return true

	building["hp"] = mini(max_hp, current_hp + amount)
	_buildings[building_id] = building
	_refresh_bound_scene_nodes(building_id)
	_emit_building_clicked_if_selected(building_id)
	return true


func debug_select_building(building_id: String) -> bool:
	if not _buildings.has(building_id):
		push_warning("Cannot select unknown building: %s" % building_id)
		return false
	_select_building(building_id)
	return true


func _bind_scene_nodes(building_id: String, definition: Dictionary) -> void:
	var root := get_node_or_null(BUILDING_ROOT_PATH)
	if root == null:
		push_error("Building root not found: %s" % BUILDING_ROOT_PATH)
		return

	var scene_nodes: Array = definition.get("scene_nodes", [])
	if scene_nodes.is_empty():
		push_warning("Building has no scene_nodes mapping: %s" % building_id)
		return

	for raw_node_name in scene_nodes:
		var node_name := str(raw_node_name)
		var building_node := root.get_node_or_null(node_name)
		if building_node == null:
			push_warning("Building scene node not found for %s: %s" % [building_id, node_name])
			continue

		building_node.set_meta("building_id", building_id)
		if not _building_scene_nodes.has(building_id):
			_building_scene_nodes[building_id] = []
		_building_scene_nodes[building_id].append(building_node.get_path())
		_update_debug_label(building_node, definition)
		_ensure_click_area(building_node, building_id)


func _update_debug_label(building_node: Node, definition: Dictionary) -> void:
	for child in building_node.get_children():
		if child is Label3D:
			child.text = "%s\nLv.%d HP %d/%d" % [
				str(definition.get("name", definition.get("id", ""))),
				int(definition.get("level", 1)),
				int(definition.get("hp", 0)),
				int(definition.get("max_hp", 0))
			]
			return


func _ensure_click_area(building_node: Node, building_id: String) -> void:
	if not building_node is MeshInstance3D:
		return

	var mesh_instance := building_node as MeshInstance3D
	if mesh_instance.mesh == null:
		return

	var click_area := mesh_instance.get_node_or_null(CLICK_AREA_NAME) as Area3D
	if click_area == null:
		click_area = Area3D.new()
		click_area.name = CLICK_AREA_NAME
		mesh_instance.add_child(click_area)

	var collision_shape := click_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		click_area.add_child(collision_shape)

	var shape := BoxShape3D.new()
	var mesh_size := mesh_instance.mesh.get_aabb().size
	shape.size = Vector3(mesh_size.x, max(mesh_size.y, 0.5), mesh_size.z)
	collision_shape.shape = shape
	click_area.set_meta("building_id", building_id)
	click_area.input_ray_pickable = true

	var input_callable := Callable(self, "_on_building_area_input_event").bind(click_area)
	if not click_area.input_event.is_connected(input_callable):
		click_area.input_event.connect(input_callable)


func _pick_building_at_screen_position(screen_position: Vector2) -> String:
	var camera := get_node_or_null(CAMERA_PATH) as Camera3D
	if camera == null:
		return ""

	var world_3d := get_viewport().world_3d
	if world_3d == null:
		return ""

	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * PICK_RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result := world_3d.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return ""

	var collider := result.get("collider") as Node
	while collider != null:
		var building_id := str(collider.get_meta("building_id", ""))
		if not building_id.is_empty():
			return building_id
		collider = collider.get_parent()

	return ""


func _on_building_area_input_event(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int,
	click_area: Area3D
) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var building_id := str(click_area.get_meta("building_id", ""))
		if not building_id.is_empty():
			_select_building(building_id)


func _select_building(building_id: String) -> void:
	_selected_building_id = building_id
	_emit_building_clicked_if_selected(building_id)


func _refresh_bound_scene_nodes(building_id: String) -> void:
	if not _buildings.has(building_id):
		return

	var building: Dictionary = _buildings[building_id]
	var node_paths: Array = _building_scene_nodes.get(building_id, [])
	for raw_path in node_paths:
		var building_node := get_node_or_null(NodePath(str(raw_path)))
		if building_node != null:
			_update_debug_label(building_node, building)


func _apply_workstation_upgrade(building: Dictionary, upgrade_config: Dictionary) -> void:
	var workstation_bonus: int = maxi(0, int(upgrade_config.get("workstation_bonus", 0)))
	if workstation_bonus <= 0:
		return

	var workstations: Array = building.get("workstations", [])
	var station_type := str(upgrade_config.get("workstation_type", "general"))
	for index in range(workstation_bonus):
		workstations.append({
			"id": "%s_upgrade_%02d" % [str(building.get("id", "building")), workstations.size() + index + 1],
			"type": station_type,
			"occupied_by": null
		})
	building["workstations"] = workstations


func _emit_building_clicked_if_selected(building_id: String) -> void:
	if building_id != _selected_building_id:
		return

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.building_clicked.emit(building_id)
