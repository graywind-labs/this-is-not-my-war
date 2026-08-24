class_name SmithyAmbientFX
extends Node3D


const BUILDING_ID := "blacksmith"
const WORK_ACTION_ID := "work_blacksmith"
const BUILDING_SYSTEM_PATH := NodePath("/root/Main/Systems/BuildingSystem")
const NPC_SYSTEM_PATH := NodePath("/root/Main/Systems/NPCSystem")

@export var base_light_energy := 3.4
@export var flicker_light_energy := 0.75
@export var flicker_speed := 7.0
@export var bellows_speed := 1.8

@onready var _fire_light := get_node_or_null("FireLight") as OmniLight3D
@onready var _fuel_glow := get_node_or_null("GlowingFuelBed") as MeshInstance3D
@onready var _flame_core := get_node_or_null("FlameCore") as MeshInstance3D
@onready var _flame_tip := get_node_or_null("FlameTip") as MeshInstance3D
@onready var _sparks := get_node_or_null("Sparks") as GPUParticles3D
@onready var _smoke := get_node_or_null("Smoke") as GPUParticles3D
@onready var _bellows_handle := get_node_or_null("../Bellows/Handle") as Node3D

var _elapsed := 0.0
var _forge_active := false
var _active_workstation_ids: Array[String] = []
var _active_npc_ids: Array[String] = []
var _building_signal_connected := false
var _npc_signal_connected := false
var _refresh_queued := false


func _ready() -> void:
	set_meta("presentation_only", true)
	set_meta("authority_role", "read_only_workstation_observer")
	_configure_particles()
	_connect_signals()
	_set_forge_active(false, [], [])
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
	if not _forge_active or _is_gameplay_paused():
		return
	_elapsed += delta
	var primary := sin(_elapsed * flicker_speed)
	var secondary := sin(_elapsed * flicker_speed * 2.37 + 1.2)
	var flicker := primary * 0.62 + secondary * 0.38
	if _fire_light != null:
		_fire_light.light_energy = base_light_energy + flicker * flicker_light_energy
	if _fuel_glow != null:
		_fuel_glow.scale.y = 0.26 + flicker * 0.025
	if _flame_core != null:
		_flame_core.scale.y = 0.88 + flicker * 0.08
	if _flame_tip != null:
		_flame_tip.position.y = 0.34 + flicker * 0.035
		_flame_tip.rotation.y = _elapsed * 0.7
	if _bellows_handle != null:
		_bellows_handle.rotation.x = deg_to_rad(-12.0 + sin(_elapsed * bellows_speed) * 9.0)


func debug_force_refresh() -> Dictionary:
	_refresh_work_state()
	return debug_get_snapshot()


func debug_get_snapshot() -> Dictionary:
	var heat_visuals := _find_station_heat_visuals()
	var active_heat_count := 0
	for heat_visual in heat_visuals:
		if heat_visual.visible:
			active_heat_count += 1
	return {
		"forge_active": _forge_active,
		"active_workstation_ids": _active_workstation_ids.duplicate(),
		"active_npc_ids": _active_npc_ids.duplicate(),
		"fire_light_ready": _fire_light != null,
		"fire_light_energy": _fire_light.light_energy if _fire_light != null else 0.0,
		"flame_core_ready": _flame_core != null,
		"fuel_glow_ready": _fuel_glow != null,
		"sparks_emitting": _sparks != null and _sparks.emitting,
		"smoke_emitting": _smoke != null and _smoke.emitting,
		"bellows_animated": _bellows_handle != null,
		"station_heat_visual_count": heat_visuals.size(),
		"active_station_heat_visual_count": active_heat_count,
		"building_signal_connected": _building_signal_connected,
		"npc_signal_connected": _npc_signal_connected,
		"activation_contract": "occupied_forge_and_work_blacksmith",
		"authority_role": "presentation_only"
	}


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


func _on_npc_state_changed(_npc_id: String) -> void:
	# State and occupancy can be emitted in either order. Deferred coalescing reads
	# the settled authoritative pair without polling every frame.
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
		_set_forge_active(false, [], [])
		return
	var building: Dictionary = building_system.call("get_building", BUILDING_ID)
	var workstation_ids: Array[String] = []
	var npc_ids: Array[String] = []
	for raw_workstation in building.get("workstations", []):
		if not raw_workstation is Dictionary:
			continue
		var workstation := raw_workstation as Dictionary
		if str(workstation.get("type", "")) != "forge":
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
			workstation_ids.append(str(workstation.get("id", "")))
			npc_ids.append(npc_id)
	_set_forge_active(not workstation_ids.is_empty(), workstation_ids, npc_ids)


func _set_forge_active(active: bool, workstation_ids: Array[String], npc_ids: Array[String]) -> void:
	_forge_active = active
	_active_workstation_ids = workstation_ids.duplicate()
	_active_npc_ids = npc_ids.duplicate()
	for glow in [_fuel_glow, _flame_core, _flame_tip]:
		if glow != null:
			glow.visible = active
	if _fire_light != null:
		_fire_light.visible = active
		_fire_light.light_energy = base_light_energy if active else 0.0
	if _sparks != null:
		_sparks.emitting = active
	if _smoke != null:
		_smoke.emitting = active
	if _bellows_handle != null and not active:
		_bellows_handle.rotation.x = deg_to_rad(-12.0)
	for heat_visual in _find_station_heat_visuals():
		heat_visual.visible = active and str(heat_visual.get_meta("workstation_id", "")) in workstation_ids


func _find_station_heat_visuals() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var building_root := _find_building_root()
	if building_root == null:
		return result
	for raw_node in building_root.find_children("*", "Node3D", true, false):
		var node := raw_node as Node3D
		if node != null and bool(node.get_meta("smithy_work_heat", false)):
			result.append(node)
	return result


func _find_building_root() -> Node:
	var cursor: Node = self
	while cursor != null:
		if cursor.get_node_or_null("FixtureLayout") != null:
			return cursor
		cursor = cursor.get_parent()
	return null


func _clean_nullable_id(value: Variant) -> String:
	if value == null:
		return ""
	var cleaned := str(value)
	return "" if cleaned in ["", "<null>", "null"] else cleaned


func _configure_particles() -> void:
	if _sparks != null:
		var sparks_process := ParticleProcessMaterial.new()
		sparks_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		sparks_process.emission_sphere_radius = 0.12
		sparks_process.direction = Vector3(0.0, 1.0, 0.0)
		sparks_process.spread = 38.0
		sparks_process.initial_velocity_min = 1.8
		sparks_process.initial_velocity_max = 3.4
		sparks_process.gravity = Vector3(0.0, -3.6, 0.0)
		sparks_process.scale_min = 0.55
		sparks_process.scale_max = 1.25
		_sparks.process_material = sparks_process
		var spark_mesh := SphereMesh.new()
		spark_mesh.radius = 0.025
		spark_mesh.height = 0.05
		var spark_material := StandardMaterial3D.new()
		spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark_material.albedo_color = Color(1.0, 0.46, 0.06, 1.0)
		spark_material.emission_enabled = true
		spark_material.emission = Color(1.0, 0.18, 0.015, 1.0)
		spark_material.emission_energy_multiplier = 5.0
		spark_mesh.material = spark_material
		_sparks.draw_pass_1 = spark_mesh
	if _smoke != null:
		var smoke_process := ParticleProcessMaterial.new()
		smoke_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		smoke_process.emission_sphere_radius = 0.18
		smoke_process.direction = Vector3(0.0, 1.0, 0.0)
		smoke_process.spread = 16.0
		smoke_process.initial_velocity_min = 0.45
		smoke_process.initial_velocity_max = 0.85
		smoke_process.gravity = Vector3(0.0, 0.08, 0.0)
		smoke_process.scale_min = 0.5
		smoke_process.scale_max = 1.45
		_smoke.process_material = smoke_process
		var smoke_mesh := SphereMesh.new()
		smoke_mesh.radius = 0.13
		smoke_mesh.height = 0.26
		var smoke_material := StandardMaterial3D.new()
		smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_material.albedo_color = Color(0.16, 0.13, 0.12, 0.34)
		smoke_material.roughness = 1.0
		smoke_mesh.material = smoke_material
		_smoke.draw_pass_1 = smoke_mesh


func _is_gameplay_paused() -> bool:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	return time_system != null and time_system.has_method("is_gameplay_paused") and time_system.is_gameplay_paused()
