class_name DiningKitchenWorkFX
extends Node3D


const BUILDING_ID := "dining_hall"
const WORK_ACTION_ID := "work_dining_hall"
const BUILDING_SYSTEM_PATH := NodePath("/root/Main/Systems/BuildingSystem")
const NPC_SYSTEM_PATH := NodePath("/root/Main/Systems/NPCSystem")

@export var base_light_energy := 1.65
@export var flicker_light_energy := 0.38
@export var flicker_speed := 6.4

var _elapsed := 0.0
var _active_workstations: Dictionary = {}
var _building_signal_connected := false
var _npc_signal_connected := false
var _refresh_queued := false


func _ready() -> void:
	set_meta("presentation_only", true)
	set_meta("authority_role", "read_only_workstation_observer")
	set_meta("environment_fire_kind", "dining_hearth")
	add_to_group("environment_fire_audio_source")
	_connect_signals()
	_set_active_workstations({})
	_queue_work_state_refresh()


func _exit_tree() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		var building_callback := Callable(self, "_on_building_state_changed")
		if event_bus.has_signal("building_state_changed") and event_bus.building_state_changed.is_connected(building_callback):
			event_bus.building_state_changed.disconnect(building_callback)
		var npc_callback := Callable(self, "_on_npc_state_changed")
		if event_bus.has_signal("npc_state_changed") and event_bus.npc_state_changed.is_connected(npc_callback):
			event_bus.npc_state_changed.disconnect(npc_callback)
	_building_signal_connected = false
	_npc_signal_connected = false


func _process(delta: float) -> void:
	if _active_workstations.is_empty() or _is_gameplay_paused():
		return
	_elapsed += delta
	for raw_station in get_children():
		if not raw_station is Node3D:
			continue
		var station := raw_station as Node3D
		var workstation_id := str(station.get_meta("workstation_id", ""))
		if not _active_workstations.has(workstation_id):
			continue
		var phase := _elapsed * flicker_speed + float(station.get_index()) * 1.37
		var flicker := sin(phase) * 0.68 + sin(phase * 2.21 + 0.8) * 0.32
		var fire_light := station.get_node_or_null("FireLight") as OmniLight3D
		if fire_light != null:
			fire_light.light_energy = base_light_energy + flicker * flicker_light_energy
		var flame_core := station.get_node_or_null("FireVisuals/FlameCore") as Node3D
		var flame_left := station.get_node_or_null("FireVisuals/FlameLeft") as Node3D
		var flame_right := station.get_node_or_null("FireVisuals/FlameRight") as Node3D
		if flame_core != null:
			flame_core.scale.y = 1.0 + flicker * 0.09
		if flame_left != null:
			flame_left.rotation.y = phase * 0.09
		if flame_right != null:
			flame_right.rotation.y = -phase * 0.08
		var food_visuals := station.get_node_or_null("FoodVisuals") as Node3D
		if food_visuals != null:
			food_visuals.rotation.y = sin(_elapsed * 0.72 + float(station.get_index())) * 0.08


func debug_force_refresh() -> Dictionary:
	_refresh_work_state()
	return debug_get_snapshot()


func debug_get_snapshot() -> Dictionary:
	var stations: Dictionary = {}
	for raw_station in get_children():
		if not raw_station is Node3D:
			continue
		var station := raw_station as Node3D
		var workstation_id := str(station.get_meta("workstation_id", ""))
		if workstation_id.is_empty():
			continue
		var steam := station.get_node_or_null("PotSteam") as GPUParticles3D
		var chimney_smoke := station.get_node_or_null("ChimneySmoke") as GPUParticles3D
		var fire_light := station.get_node_or_null("FireLight") as OmniLight3D
		stations[workstation_id] = {
			"active": _active_workstations.has(workstation_id),
			"npc_id": str(_active_workstations.get(workstation_id, "")),
			"required_level": int(station.get_meta("required_level", 1)),
			"chimney_name": str(station.get_meta("chimney_name", "")),
			"fire_visible": _node_visible(station.get_node_or_null("FireVisuals")),
			"food_visible": _node_visible(station.get_node_or_null("FoodVisuals")),
			"steam_emitting": steam != null and steam.emitting,
			"chimney_smoke_emitting": chimney_smoke != null and chimney_smoke.emitting,
			"fire_light_energy": fire_light.light_energy if fire_light != null else 0.0,
			"chimney_smoke_position": chimney_smoke.position if chimney_smoke != null else Vector3.ZERO
		}
	return {
		"active_workstation_ids": _active_workstations.keys(),
		"active_station_count": _active_workstations.size(),
		"stations": stations,
		"building_signal_connected": _building_signal_connected,
		"npc_signal_connected": _npc_signal_connected,
		"activation_contract": "occupied_dining_kitchen_station_and_work_dining_hall",
		"meal_authority": false,
		"authority_role": "presentation_only"
	}


func get_active_fire_audio_sources() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if not is_visible_in_tree():
		return result
	for raw_station in get_children():
		if not raw_station is Node3D:
			continue
		var station := raw_station as Node3D
		var workstation_id := str(station.get_meta("workstation_id", ""))
		if _active_workstations.has(workstation_id):
			result.append(station)
	return result


func _connect_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	var building_callback := Callable(self, "_on_building_state_changed")
	if event_bus.has_signal("building_state_changed") and not event_bus.building_state_changed.is_connected(building_callback):
		event_bus.building_state_changed.connect(building_callback)
	_building_signal_connected = event_bus.has_signal("building_state_changed") and event_bus.building_state_changed.is_connected(building_callback)
	var npc_callback := Callable(self, "_on_npc_state_changed")
	if event_bus.has_signal("npc_state_changed") and not event_bus.npc_state_changed.is_connected(npc_callback):
		event_bus.npc_state_changed.connect(npc_callback)
	_npc_signal_connected = event_bus.has_signal("npc_state_changed") and event_bus.npc_state_changed.is_connected(npc_callback)


func _on_building_state_changed(building_id: String) -> void:
	if building_id == BUILDING_ID:
		_queue_work_state_refresh()


func _on_npc_state_changed(npc_id: String) -> void:
	# Occupancy and actor state can settle in either signal order. Deferred
	# coalescing reads the final authoritative pair once.
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if (
		npc_system != null
		and npc_system.has_method("is_active_npc_state_change_relevant")
		and not npc_system.is_active_npc_state_change_relevant(
			npc_id,
			["current_action", "current_location", "unconscious", "escaped"]
		)
	):
		return
	_queue_work_state_refresh()


func _queue_work_state_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_refresh_work_state")


func _refresh_work_state() -> void:
	_refresh_queued = false
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if building_system == null or npc_system == null or not building_system.has_method("get_building") or not npc_system.has_method("get_npc_state"):
		_set_active_workstations({})
		return
	var active: Dictionary = {}
	var building: Dictionary = building_system.call("get_building", BUILDING_ID)
	for raw_workstation in building.get("workstations", []):
		if not raw_workstation is Dictionary:
			continue
		var workstation := raw_workstation as Dictionary
		if str(workstation.get("type", "")) != "dining_kitchen_station":
			continue
		var npc_id := _clean_nullable_id(workstation.get("occupied_by", ""))
		if npc_id.is_empty():
			continue
		var npc_state: Dictionary = npc_system.call("get_npc_state", npc_id)
		if (
			str(npc_state.get("current_action", "")) == WORK_ACTION_ID
			and str(npc_state.get("current_location", "")) == BUILDING_ID
			and not bool(npc_state.get("escaped", false))
		):
			active[str(workstation.get("id", ""))] = npc_id
	_set_active_workstations(active)


func _set_active_workstations(active: Dictionary) -> void:
	_active_workstations = active.duplicate(true)
	for raw_station in get_children():
		if not raw_station is Node3D:
			continue
		var station := raw_station as Node3D
		var workstation_id := str(station.get_meta("workstation_id", ""))
		var is_active := active.has(workstation_id)
		var fire_visuals := station.get_node_or_null("FireVisuals") as Node3D
		var food_visuals := station.get_node_or_null("FoodVisuals") as Node3D
		if fire_visuals != null:
			fire_visuals.visible = is_active
		if food_visuals != null:
			food_visuals.visible = is_active
		for particle_name in ["PotSteam", "ChimneySmoke"]:
			var particles := station.get_node_or_null(particle_name) as GPUParticles3D
			if particles != null:
				particles.emitting = is_active
		var fire_light := station.get_node_or_null("FireLight") as OmniLight3D
		if fire_light != null:
			fire_light.visible = is_active
			fire_light.light_energy = base_light_energy if is_active else 0.0
	for heat_visual in _find_fixture_heat_visuals():
		var workstation_id := str(heat_visual.get_meta("workstation_id", ""))
		heat_visual.visible = active.has(workstation_id)


func _find_fixture_heat_visuals() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var building_root := _find_building_root()
	if building_root == null:
		return result
	for raw_node in building_root.find_children("*", "Node3D", true, false):
		var node := raw_node as Node3D
		if node != null and bool(node.get_meta("dining_work_heat", false)):
			result.append(node)
	return result


func _find_building_root() -> Node:
	var cursor: Node = self
	while cursor != null:
		if cursor.get_node_or_null("FixtureLayout") != null:
			return cursor
		cursor = cursor.get_parent()
	return null


func _node_visible(node: Node) -> bool:
	return node is Node3D and (node as Node3D).visible


func _clean_nullable_id(value: Variant) -> String:
	if value == null:
		return ""
	var cleaned := str(value)
	return "" if cleaned in ["", "<null>", "null"] else cleaned


func _is_gameplay_paused() -> bool:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	return time_system != null and time_system.has_method("is_gameplay_paused") and time_system.is_gameplay_paused()
