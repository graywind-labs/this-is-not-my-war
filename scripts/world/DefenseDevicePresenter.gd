extends Node3D

const DEFENSE_DEVICE_SYSTEM_PATH := "/root/Main/Systems/DefenseDeviceSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const DEVICE_VIEW_SCENE := preload("res://scenes/defense_devices/DefenseDeviceView.tscn")

var _views: Dictionary = {}
var _ruin_views: Dictionary = {}


func _ready() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		if event_bus.has_signal("defense_device_deployed"):
			event_bus.defense_device_deployed.connect(_on_device_deployed)
		if event_bus.has_signal("defense_device_state_changed"):
			event_bus.defense_device_state_changed.connect(_on_device_state_changed)
		if event_bus.has_signal("defense_device_action_phase"):
			event_bus.defense_device_action_phase.connect(_on_device_action_phase)
		if event_bus.has_signal("defense_device_action_resolved"):
			event_bus.defense_device_action_resolved.connect(_on_device_action_resolved)
		if event_bus.has_signal("building_state_changed"):
			event_bus.building_state_changed.connect(_on_building_state_changed)
	call_deferred("rebuild_from_system")


func rebuild_from_system() -> void:
	var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if device_system == null or not device_system.has_method("get_deployments"):
		return
	var active_ids: Array[String] = []
	for raw_deployment in device_system.get_deployments():
		if not raw_deployment is Dictionary:
			continue
		var deployment: Dictionary = raw_deployment
		var deployment_id := str(deployment.get("deployment_id", ""))
		if deployment_id.is_empty():
			continue
		active_ids.append(deployment_id)
		_sync_view(deployment)
	for raw_id in _views.keys():
		var deployment_id := str(raw_id)
		if active_ids.has(deployment_id):
			continue
		var stale_view: Node = _views.get(deployment_id)
		if is_instance_valid(stale_view):
			stale_view.queue_free()
		_views.erase(deployment_id)
	var active_ruin_slots: Array[String] = []
	if device_system.has_method("get_device_ruins"):
		for raw_ruin in device_system.get_device_ruins():
			if not raw_ruin is Dictionary:
				continue
			var ruin: Dictionary = raw_ruin
			var slot_id := str(ruin.get("slot_id", ""))
			if slot_id.is_empty():
				continue
			active_ruin_slots.append(slot_id)
			_sync_ruin_view(ruin)
	for raw_slot_id in _ruin_views.keys():
		var slot_id := str(raw_slot_id)
		if active_ruin_slots.has(slot_id):
			continue
		var stale_ruin: Node = _ruin_views.get(slot_id)
		if is_instance_valid(stale_ruin):
			stale_ruin.queue_free()
		_ruin_views.erase(slot_id)


func get_view_count() -> int:
	return _views.size()


func get_ruin_view_count() -> int:
	return _ruin_views.size()


func get_view_for_deployment(deployment_id: String) -> Node3D:
	var view: Variant = _views.get(deployment_id)
	return view as Node3D if is_instance_valid(view) else null


func get_ruin_view_for_slot(slot_id: String) -> Node3D:
	var view: Variant = _ruin_views.get(slot_id)
	return view as Node3D if is_instance_valid(view) else null


func get_projectile_release_snapshot(deployment_id: String, weapon_type: String) -> Dictionary:
	var view := get_view_for_deployment(deployment_id)
	if view == null or not view.has_method("get_combat_projectile_release_snapshot"):
		return {"ready": false, "reason": "defense_device_view_unavailable", "origin_source": "unavailable"}
	return view.get_combat_projectile_release_snapshot(weapon_type)


func _sync_view(deployment: Dictionary) -> void:
	var deployment_id := str(deployment.get("deployment_id", ""))
	var view: Node3D = get_view_for_deployment(deployment_id)
	if view == null:
		view = DEVICE_VIEW_SCENE.instantiate() as Node3D
		view.name = _make_node_name(deployment_id)
		add_child(view)
		_views[deployment_id] = view
	if view.has_method("configure_device"):
		view.configure_device(deployment)
	view.visible = _is_deployment_host_visible(deployment)


func _sync_ruin_view(ruin: Dictionary) -> void:
	var slot_id := str(ruin.get("slot_id", ""))
	var view := get_ruin_view_for_slot(slot_id)
	if view == null:
		view = DEVICE_VIEW_SCENE.instantiate() as Node3D
		view.name = "%sRuin" % _make_node_name(slot_id)
		add_child(view)
		_ruin_views[slot_id] = view
	if view.has_method("configure_device_ruin"):
		view.configure_device_ruin(ruin)


func _on_device_deployed(_deployment_id: String, deployment: Dictionary) -> void:
	_sync_view(deployment)


func _on_device_state_changed(_snapshot: Dictionary) -> void:
	rebuild_from_system()


func _on_device_action_resolved(deployment_id: String, action_result: Dictionary) -> void:
	var view := get_view_for_deployment(deployment_id)
	if view != null and view.has_method("show_device_action_result"):
		view.show_device_action_result(action_result)


func _on_device_action_phase(deployment_id: String, phase_snapshot: Dictionary) -> void:
	var view := get_view_for_deployment(deployment_id)
	if view != null and view.has_method("sync_device_attack_timeline"):
		view.sync_device_attack_timeline(phase_snapshot)


func _on_building_state_changed(building_id: String) -> void:
	if building_id == "wall" or building_id == "main_hall":
		rebuild_from_system()


func _is_deployment_host_visible(deployment: Dictionary) -> bool:
	var building_id := str(deployment.get("building_id", ""))
	if building_id.is_empty():
		return true
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building"):
		return true
	var building: Dictionary = building_system.get_building(building_id)
	return building.is_empty() or not bool(building.get("destruction_latched", false))


func _make_node_name(value: String) -> String:
	var parts := value.split("_", false)
	var result := ""
	for part in parts:
		if part.is_empty():
			continue
		result += part.substr(0, 1).to_upper() + part.substr(1)
	return result if not result.is_empty() else "DefenseDevice"
