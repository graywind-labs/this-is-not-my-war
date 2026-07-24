extends Node3D

const DEFENSE_DEVICE_SYSTEM_PATH := "/root/Main/Systems/DefenseDeviceSystem"
const DEVICE_VIEW_SCENE := preload("res://scenes/defense_devices/DefenseDeviceView.tscn")

var _views: Dictionary = {}


func _ready() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		if event_bus.has_signal("defense_device_deployed"):
			event_bus.defense_device_deployed.connect(_on_device_deployed)
		if event_bus.has_signal("defense_device_state_changed"):
			event_bus.defense_device_state_changed.connect(_on_device_state_changed)
		if event_bus.has_signal("defense_device_action_resolved"):
			event_bus.defense_device_action_resolved.connect(_on_device_action_resolved)
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


func get_view_count() -> int:
	return _views.size()


func get_view_for_deployment(deployment_id: String) -> Node3D:
	var view: Variant = _views.get(deployment_id)
	return view as Node3D if is_instance_valid(view) else null


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


func _on_device_deployed(_deployment_id: String, deployment: Dictionary) -> void:
	_sync_view(deployment)


func _on_device_state_changed(_snapshot: Dictionary) -> void:
	rebuild_from_system()


func _on_device_action_resolved(deployment_id: String, action_result: Dictionary) -> void:
	var view := get_view_for_deployment(deployment_id)
	if view != null and view.has_method("play_device_action"):
		view.play_device_action(action_result)


func _make_node_name(value: String) -> String:
	var parts := value.split("_", false)
	var result := ""
	for part in parts:
		if part.is_empty():
			continue
		result += part.substr(0, 1).to_upper() + part.substr(1)
	return result if not result.is_empty() else "DefenseDevice"
