class_name CombatVFXController
extends Node

const CONFIG_PATH := "res://data/presentation/combat_vfx.json"
const EXPECTED_SCHEMA := "combat_vfx_v1"
const FORMAL_ROOT_PATH := NodePath("/root/Main/WorldRoot/FormalStationLayout")
const NPC_SYSTEM_PATH := NodePath("/root/Main/Systems/NPCSystem")
const COMBAT_SYSTEM_PATH := NodePath("/root/Main/Systems/CombatSystem")
const BUILDING_SYSTEM_PATH := NodePath("/root/Main/Systems/BuildingSystem")
const DEFENSE_DEVICE_SYSTEM_PATH := NodePath("/root/Main/Systems/DefenseDeviceSystem")
const CLIENT_SETTINGS_PATH := NodePath("/root/ClientSettings")

var _config: Dictionary = {}
var _effect_root: Node3D
var _initialized := false
var _blood_enabled := true
var _active_transients: Array[Dictionary] = []
var _blood_decals: Array[Node3D] = []
var _all_decals: Array[Node3D] = []
var _dust_cooldowns: Dictionary = {}
var _budget_frame := -1
var _frame_total := 0
var _frame_groups: Dictionary = {}
var _spawn_counts: Dictionary = {}
var _skipped_counts: Dictionary = {}
var _blood_texture: ImageTexture


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_meta("presentation_only", true)
	set_meta("authority_role", "read_only_combat_vfx_projection")
	_config = _load_json_dictionary(CONFIG_PATH)
	_connect_signals()
	_apply_client_settings()
	call_deferred("_initialize_vfx")
	set_process(true)


func _exit_tree() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.combat_audio_event.is_connected(_on_combat_event):
		event_bus.combat_audio_event.disconnect(_on_combat_event)
	var settings := get_node_or_null(CLIENT_SETTINGS_PATH)
	if settings != null and settings.settings_changed.is_connected(_on_settings_changed):
		settings.settings_changed.disconnect(_on_settings_changed)


func _process(delta: float) -> void:
	if not _initialized:
		return
	_update_transients(maxf(0.0, delta))
	_update_foot_dust(maxf(0.0, delta))


func get_debug_snapshot() -> Dictionary:
	return {
		"initialized": _initialized,
		"schema_version": str(_config.get("schema_version", "")),
		"blood_enabled": _blood_enabled,
		"active_transients": _active_transients.size(),
		"active_blood_decals": _blood_decals.size(),
		"active_decals": _all_decals.size(),
		"spawn_counts": _spawn_counts.duplicate(true),
		"skipped_counts": _skipped_counts.duplicate(true),
		"frame_total": _frame_total,
		"frame_groups": _frame_groups.duplicate(true),
		"authority_role": "presentation_only"
	}


func debug_handle_event(event: Dictionary) -> Dictionary:
	if not _initialized:
		_initialize_vfx()
	_handle_event(event.duplicate(true))
	return get_debug_snapshot()


func debug_clear_effects() -> void:
	for record in _active_transients:
		_free_effect(record.get("node") as Node)
	for decal in _all_decals:
		_free_effect(decal)
	_active_transients.clear()
	_blood_decals.clear()
	_all_decals.clear()
	_dust_cooldowns.clear()


func _initialize_vfx() -> void:
	if _initialized:
		return
	if str(_config.get("schema_version", "")) != EXPECTED_SCHEMA:
		push_error("CombatVFXController invalid config schema")
		return
	var formal_root := get_node_or_null(FORMAL_ROOT_PATH) as Node3D
	if formal_root == null:
		call_deferred("_initialize_vfx")
		return
	_effect_root = Node3D.new()
	_effect_root.name = "CombatVFX"
	_effect_root.set_meta("presentation_only", true)
	formal_root.add_child(_effect_root)
	_initialized = true


func _connect_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and not event_bus.combat_audio_event.is_connected(_on_combat_event):
		event_bus.combat_audio_event.connect(_on_combat_event)
	var settings := get_node_or_null(CLIENT_SETTINGS_PATH)
	if settings != null and not settings.settings_changed.is_connected(_on_settings_changed):
		settings.settings_changed.connect(_on_settings_changed)


func _on_settings_changed(_snapshot: Dictionary) -> void:
	_apply_client_settings()


func _apply_client_settings() -> void:
	var settings := get_node_or_null(CLIENT_SETTINGS_PATH)
	var snapshot: Dictionary = settings.get_snapshot() if settings != null else {}
	_blood_enabled = bool(snapshot.get("blood_enabled", true))
	if not _blood_enabled:
		for decal in _blood_decals:
			_all_decals.erase(decal)
			_free_effect(decal)
		_blood_decals.clear()


func _on_combat_event(event: Dictionary) -> void:
	if not _initialized:
		call_deferred("_handle_event", event.duplicate(true))
		return
	_handle_event(event)


func _handle_event(event: Dictionary) -> void:
	match str(event.get("event_type", "")):
		"attack_swing":
			_spawn_attack_trail(event)
		"projectile_hit":
			_spawn_impact(event, Color(1.0, 0.62, 0.22, 1.0))
		"actor_damaged":
			_spawn_impact(event, Color(1.0, 0.2, 0.08, 1.0))
			if _blood_enabled:
				_spawn_blood_decal(_resolve_event_position(event))
		"structure_damaged":
			_spawn_structure_debris(event)


func _spawn_attack_trail(event: Dictionary) -> void:
	if not _consume_budget("trail"):
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "AttackTrail"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.72, 0.035, 0.16)
	mesh.material = _make_transparent_material(Color(1.0, 0.75, 0.3, 0.62), true)
	mesh_instance.mesh = mesh
	_effect_root.add_child(mesh_instance)
	mesh_instance.global_position = _resolve_event_position(event) + Vector3(0.0, 0.9, 0.0)
	mesh_instance.rotation.y = float(event.get("facing_yaw", 0.0)) + PI * 0.25
	_track_transient(mesh_instance, float((_config.get("lifetimes", {}) as Dictionary).get("trail_seconds", 0.16)), "trail")


func _spawn_impact(event: Dictionary, color: Color) -> void:
	if not _consume_budget("impact"):
		return
	var origin := _resolve_event_position(event) + Vector3(0.0, 0.75, 0.0)
	var flash := MeshInstance3D.new()
	flash.name = "ImpactFlash"
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	sphere.material = _make_transparent_material(color, true)
	flash.mesh = sphere
	_effect_root.add_child(flash)
	flash.global_position = origin
	_track_transient(flash, float((_config.get("lifetimes", {}) as Dictionary).get("impact_seconds", 0.22)), "impact")
	_spawn_particles(origin, color, 7, "impact")


func _spawn_structure_debris(event: Dictionary) -> void:
	if not _consume_budget("debris"):
		return
	var color := Color(0.38, 0.28, 0.18, 1.0) if str(event.get("target_type", "")) == "defense_device" else Color(0.48, 0.45, 0.39, 1.0)
	var impact_position: Variant = event.get("impact_world_position", null)
	var debris_position := impact_position as Vector3 if impact_position is Vector3 else _resolve_event_position(event)
	_spawn_particles(debris_position + Vector3(0.0, 0.8, 0.0), color, 10 if bool(event.get("destroyed", false)) else 6, "debris")


func _spawn_particles(position: Vector3, color: Color, amount: int, group: String) -> void:
	var active_limits: Dictionary = _config.get("active_limits", {})
	var particle_count := 0
	for record in _active_transients:
		if str(record.get("kind", "")) == "particles":
			particle_count += 1
	if particle_count >= int(active_limits.get("particles", 12)):
		_record_skip("particles_active_limit")
		return
	var particles := GPUParticles3D.new()
	particles.name = "%sParticles" % group.to_pascal_case()
	particles.amount = amount
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 0.95
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.08
	process_material.direction = Vector3(0.0, 0.8, 0.15)
	process_material.spread = 58.0
	process_material.initial_velocity_min = 0.7
	process_material.initial_velocity_max = 2.0
	process_material.gravity = Vector3(0.0, -4.8, 0.0)
	particles.process_material = process_material
	var chip := BoxMesh.new()
	chip.size = Vector3(0.035, 0.035, 0.035)
	chip.material = _make_transparent_material(color, false)
	particles.draw_pass_1 = chip
	_effect_root.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	_track_transient(particles, float((_config.get("lifetimes", {}) as Dictionary).get("particles_seconds", 0.7)), "particles")


func _spawn_blood_decal(position: Vector3) -> void:
	var limits: Dictionary = _config.get("active_limits", {})
	_trim_decal_array(_blood_decals, int(limits.get("blood_decals", 14)))
	_trim_decal_array(_all_decals, int(limits.get("all_decals", 22)))
	var decal := Decal.new()
	decal.name = "BloodDecal"
	decal.size = Vector3(0.55, 0.22, 0.55)
	decal.texture_albedo = _get_blood_texture()
	decal.modulate = Color(0.52, 0.035, 0.02, 0.82)
	decal.upper_fade = 0.08
	decal.lower_fade = 0.08
	_effect_root.add_child(decal)
	decal.global_position = Vector3(position.x, position.y + 0.055, position.z)
	decal.rotation.y = randf_range(-PI, PI)
	_blood_decals.append(decal)
	_all_decals.append(decal)
	_count_spawn("blood_decal")
	var lifetime := float((_config.get("lifetimes", {}) as Dictionary).get("blood_decal_seconds", 18.0))
	_track_transient(decal, lifetime, "decal")


func _update_foot_dust(delta: float) -> void:
	if _is_gameplay_paused():
		return
	for key in _dust_cooldowns.keys():
		_dust_cooldowns[key] = maxf(0.0, float(_dust_cooldowns[key]) - delta)
	var entries: Array[Dictionary] = []
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system != null and npc_system.has_method("get_npc_locomotion_needs_snapshot") and npc_system.has_method("get_npc_ids"):
		for raw_id in npc_system.get_npc_ids():
			var npc_id := str(raw_id)
			var snapshot: Dictionary = npc_system.get_npc_locomotion_needs_snapshot(npc_id)
			if bool(snapshot.get("movement_active", false)):
				entries.append({"key": "npc:%s" % npc_id, "position": npc_system.get_npc_world_position(npc_id)})
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system != null and combat_system.has_method("get_enemy_audio_motion_snapshots"):
		var enemy_limit := int(_config.get("max_enemy_dust_sources", 6))
		for raw_snapshot in combat_system.get_enemy_audio_motion_snapshots():
			if enemy_limit <= 0:
				break
			var snapshot: Dictionary = raw_snapshot
			if bool(snapshot.get("movement_active", false)):
				entries.append({"key": "enemy:%s" % str(snapshot.get("enemy_id", "")), "position": snapshot.get("world_position", Vector3.ZERO)})
				enemy_limit -= 1
	for entry in entries:
		var key := str(entry.get("key", ""))
		if float(_dust_cooldowns.get(key, 0.0)) > 0.0:
			continue
		if not _consume_budget("dust"):
			break
		var position: Variant = entry.get("position", Vector3.ZERO)
		if position is Vector3:
			_spawn_particles(position + Vector3(0.0, 0.08, 0.0), Color(0.58, 0.49, 0.36, 0.55), 4, "dust")
		_dust_cooldowns[key] = float((_config.get("lifetimes", {}) as Dictionary).get("dust_interval_seconds", 0.34))


func _update_transients(delta: float) -> void:
	for index in range(_active_transients.size() - 1, -1, -1):
		var record: Dictionary = _active_transients[index]
		var raw_node: Variant = record.get("node")
		if not is_instance_valid(raw_node):
			_active_transients.remove_at(index)
			continue
		var node := raw_node as Node3D
		var remaining := float(record.get("remaining", 0.0)) - delta
		if remaining <= 0.0:
			_blood_decals.erase(node)
			_all_decals.erase(node)
			_free_effect(node)
			_active_transients.remove_at(index)
		else:
			record["remaining"] = remaining
			_active_transients[index] = record


func _track_transient(node: Node3D, lifetime: float, kind: String) -> void:
	var limit := int((_config.get("active_limits", {}) as Dictionary).get("transient", 28))
	while _active_transients.size() >= limit and not _active_transients.is_empty():
		var removed: Dictionary = _active_transients.pop_front()
		var old_node := removed.get("node") as Node3D
		_blood_decals.erase(old_node)
		_all_decals.erase(old_node)
		_free_effect(old_node)
	_active_transients.append({"node": node, "remaining": maxf(0.05, lifetime), "kind": kind})
	_count_spawn(kind)


func _consume_budget(group: String) -> bool:
	var frame := Engine.get_process_frames()
	if frame != _budget_frame:
		_budget_frame = frame
		_frame_total = 0
		_frame_groups.clear()
	var limits: Dictionary = _config.get("frame_limits", {})
	if _frame_total >= int(limits.get("total", 10)) or int(_frame_groups.get(group, 0)) >= int(limits.get(group, 2)):
		_record_skip("%s_frame_budget" % group)
		return false
	_frame_total += 1
	_frame_groups[group] = int(_frame_groups.get(group, 0)) + 1
	return true


func _resolve_event_position(event: Dictionary) -> Vector3:
	var position: Variant = event.get("world_position", null)
	if position is Vector3:
		return position
	if position is Dictionary:
		return Vector3(float(position.get("x", 0.0)), float(position.get("y", 0.0)), float(position.get("z", 0.0)))
	var target_type := str(event.get("target_type", ""))
	var target_id := str(event.get("target_id", ""))
	if target_type == "npc":
		var system := get_node_or_null(NPC_SYSTEM_PATH)
		if system != null:
			return system.get_npc_world_position(target_id)
	elif target_type == "enemy":
		var system := get_node_or_null(COMBAT_SYSTEM_PATH)
		if system != null:
			return system.get_enemy_world_position(target_id)
	elif target_type == "building":
		var system := get_node_or_null(BUILDING_SYSTEM_PATH)
		if system != null:
			return system.get_building_entry_position(target_id)
	elif target_type == "defense_device":
		var system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
		if system != null:
			var deployment: Dictionary = system.get_deployment(target_id)
			var raw: Variant = deployment.get("position", {})
			if raw is Vector3:
				return raw
			if raw is Dictionary:
				return Vector3(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)), float(raw.get("z", 0.0)))
	return Vector3.ZERO


func _get_blood_texture() -> ImageTexture:
	if _blood_texture != null:
		return _blood_texture
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		for x in range(32):
			var uv := Vector2(float(x) / 31.0, float(y) / 31.0) * 2.0 - Vector2.ONE
			var distance := uv.length() * (0.82 + 0.12 * sin(float(x * 3 + y * 5)))
			var alpha := clampf((1.0 - distance) * 3.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_blood_texture = ImageTexture.create_from_image(image)
	return _blood_texture


func _make_transparent_material(color: Color, emission: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if emission else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.albedo_color = color
	if emission:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = 1.6
	return material


func _trim_decal_array(values: Array[Node3D], limit: int) -> void:
	while values.size() >= maxi(1, limit) and not values.is_empty():
		var node: Node3D = values.pop_front()
		_blood_decals.erase(node)
		_all_decals.erase(node)
		for index in range(_active_transients.size() - 1, -1, -1):
			if _active_transients[index].get("node") == node:
				_active_transients.remove_at(index)
		_free_effect(node)


func _free_effect(node: Node) -> void:
	if is_instance_valid(node) and not node.is_queued_for_deletion():
		node.queue_free()


func _count_spawn(kind: String) -> void:
	_spawn_counts[kind] = int(_spawn_counts.get(kind, 0)) + 1


func _record_skip(reason: String) -> void:
	_skipped_counts[reason] = int(_skipped_counts.get(reason, 0)) + 1


func _is_gameplay_paused() -> bool:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	return time_system != null and time_system.has_method("is_gameplay_paused") and bool(time_system.is_gameplay_paused())


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("CombatVFXController missing config: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	return parsed as Dictionary if parsed is Dictionary else {}
