class_name BuildingFunctionalLightController
extends Node3D


const DEFAULT_LANTERN_ASSET := "res://assets/3d/quaternius/props/main_hall_lantern.glb"
const FORMAL_ROOT_PATH := NodePath("/root/Main/WorldRoot/FormalStationLayout")
const NPC_SYSTEM_PATH := NodePath("/root/Main/Systems/NPCSystem")

var _config: Dictionary = {}
var _records: Dictionary = {}
var _runtime_roots: Array[Node3D] = []
var _asset_scene_cache: Dictionary = {}
var _missing_hosts: Array[String] = []
var _missing_fixtures: Dictionary = {}
var _last_time := {"day": 1, "hour": 6, "minute": 0, "second": 0}
var _time_signal_connected := false
var _npc_signal_connected := false
var _building_signal_connected := false


func configure(config: Dictionary) -> void:
	_config = config.duplicate(true)
	if is_inside_tree():
		call_deferred("_rebuild")


func _ready() -> void:
	add_to_group("building_functional_light_controller")
	set_meta("presentation_only", true)
	set_meta("time_authority", false)
	_connect_signals()
	_sync_time_from_game_state()
	call_deferred("_rebuild")


func _exit_tree() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		var time_callback := Callable(self, "_on_time_changed")
		if event_bus.has_signal("time_changed") and event_bus.time_changed.is_connected(time_callback):
			event_bus.time_changed.disconnect(time_callback)
		var npc_callback := Callable(self, "_on_npc_state_changed")
		if event_bus.has_signal("npc_state_changed") and event_bus.npc_state_changed.is_connected(npc_callback):
			event_bus.npc_state_changed.disconnect(npc_callback)
		var building_callback := Callable(self, "_on_building_state_changed")
		if event_bus.has_signal("building_state_changed") and event_bus.building_state_changed.is_connected(building_callback):
			event_bus.building_state_changed.disconnect(building_callback)
	_time_signal_connected = false
	_npc_signal_connected = false
	_building_signal_connected = false


func debug_force_refresh() -> Dictionary:
	_sync_time_from_game_state()
	_refresh_all()
	return get_debug_snapshot()


func get_debug_snapshot() -> Dictionary:
	var building_states: Dictionary = {}
	var total_fixture_count := 0
	var total_emitter_count := 0
	var total_light_count := 0
	var active_light_count := 0
	var active_building_ids: Array[String] = []
	for building_id_variant in _records:
		var building_id := str(building_id_variant)
		var record := _records[building_id] as Dictionary
		var emitters := record.get("emitters", []) as Array
		var managed_lights := record.get("managed_lights", []) as Array
		var lit := bool(record.get("lit", false))
		var emitter_active_count := 0
		for raw_emitter in emitters:
			var emitter := raw_emitter as Dictionary
			var light := emitter.get("light") as OmniLight3D
			if is_instance_valid(light) and light.visible and light.light_energy > 0.001:
				emitter_active_count += 1
		for raw_managed in managed_lights:
			var managed := raw_managed as Dictionary
			var managed_light := managed.get("light") as Light3D
			if is_instance_valid(managed_light) and managed_light.visible and managed_light.light_energy > 0.001:
				emitter_active_count += 1
		var fixture_count := int(record.get("fixture_count", 0))
		var light_count := emitters.size() + managed_lights.size()
		var unlocked_fixture_count := 0
		var required_level_counts: Dictionary = {}
		var designed_energy_total := 0.0
		var maximum_range := 0.0
		for raw_emitter in emitters:
			var emitter := raw_emitter as Dictionary
			var required_level := int(emitter.get("required_level", 1))
			required_level_counts[required_level] = int(required_level_counts.get(required_level, 0)) + 1
			if _emitter_is_unlocked(emitter):
				unlocked_fixture_count += 1
			designed_energy_total += float(emitter.get("energy", 0.0))
			var emitter_light := emitter.get("light") as OmniLight3D
			if is_instance_valid(emitter_light):
				maximum_range = maxf(maximum_range, emitter_light.omni_range)
		for raw_managed in managed_lights:
			designed_energy_total += float((raw_managed as Dictionary).get("energy", 0.0))
		total_fixture_count += fixture_count
		total_emitter_count += emitters.size()
		total_light_count += light_count
		active_light_count += emitter_active_count
		if lit:
			active_building_ids.append(building_id)
		building_states[building_id] = {
			"mode": str(record.get("mode", "occupied_night")),
			"host_path": str(record.get("host_path", "")),
			"fixture_count": fixture_count,
			"existing_fixture_count": int(record.get("existing_fixture_count", 0)),
			"spawned_fixture_count": int(record.get("spawned_fixture_count", 0)),
			"emitter_count": emitters.size(),
			"managed_existing_light_count": managed_lights.size(),
			"light_count": light_count,
			"active_light_count": emitter_active_count,
			"unlocked_fixture_count": unlocked_fixture_count,
			"required_level_counts": required_level_counts,
			"designed_energy_total": designed_energy_total,
			"maximum_range": maximum_range,
			"occupant_count": int(record.get("occupant_count", 0)),
			"awake_occupant_count": int(record.get("awake_occupant_count", 0)),
			"lit": lit,
			"all_shadowed": _record_lights_are_shadowed(record),
			"fog_energy_zero": _record_lights_are_fog_neutral(record),
			"distance_fade_disabled": _record_lights_keep_far_visibility(record),
		}
	return {
		"configured_building_count": (_config.get("buildings", {}) as Dictionary).size(),
		"ready_building_count": _records.size(),
		"fixture_count": total_fixture_count,
		"emitter_count": total_emitter_count,
		"light_count": total_light_count,
		"active_light_count": active_light_count,
		"active_building_ids": active_building_ids,
		"is_night": _is_night_time(),
		"time": _last_time.duplicate(true),
		"night_start_time": (_config.get("night_start_time", [18, 0]) as Array).duplicate(),
		"night_end_time": (_config.get("night_end_time", [6, 0]) as Array).duplicate(),
		"building_states": building_states,
		"missing_hosts": _missing_hosts.duplicate(),
		"missing_fixtures": _missing_fixtures.duplicate(true),
		"time_signal_connected": _time_signal_connected,
		"npc_signal_connected": _npc_signal_connected,
		"building_signal_connected": _building_signal_connected,
		"maintains_second_clock": false,
		"authority_role": "presentation_only",
	}


func _connect_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	var time_callback := Callable(self, "_on_time_changed")
	if event_bus.has_signal("time_changed") and not event_bus.time_changed.is_connected(time_callback):
		event_bus.time_changed.connect(time_callback)
	_time_signal_connected = event_bus.has_signal("time_changed") and event_bus.time_changed.is_connected(time_callback)
	var npc_callback := Callable(self, "_on_npc_state_changed")
	if event_bus.has_signal("npc_state_changed") and not event_bus.npc_state_changed.is_connected(npc_callback):
		event_bus.npc_state_changed.connect(npc_callback)
	_npc_signal_connected = event_bus.has_signal("npc_state_changed") and event_bus.npc_state_changed.is_connected(npc_callback)
	var building_callback := Callable(self, "_on_building_state_changed")
	if event_bus.has_signal("building_state_changed") and not event_bus.building_state_changed.is_connected(building_callback):
		event_bus.building_state_changed.connect(building_callback)
	_building_signal_connected = event_bus.has_signal("building_state_changed") and event_bus.building_state_changed.is_connected(building_callback)


func _sync_time_from_game_state() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	_last_time = {
		"day": int(game_state.current_day),
		"hour": int(game_state.current_hour),
		"minute": int(game_state.current_minute),
		"second": int(game_state.current_second),
	}


func _on_time_changed(day: int, hour: int, minute: int, second: int) -> void:
	_last_time = {"day": day, "hour": hour, "minute": minute, "second": second}
	_refresh_all()


func _on_npc_state_changed(_npc_id: String) -> void:
	_refresh_all()


func _on_building_state_changed(_building_id: String) -> void:
	# BuildingArtView 同样消费这个信号；延后一帧，确保灯光读取的是升级后的灯具可见性。
	call_deferred("_refresh_all")


func _rebuild() -> void:
	_clear_runtime()
	if _config.is_empty():
		return
	_missing_hosts.clear()
	_missing_fixtures.clear()
	var building_configs := _config.get("buildings", {}) as Dictionary
	for building_id_variant in building_configs:
		var building_id := str(building_id_variant)
		var building_config := building_configs[building_id] as Dictionary
		var host := _find_formal_host(building_id)
		if host == null:
			_missing_hosts.append(building_id)
			continue
		_build_building_record(building_id, building_config, host)
	_refresh_all()


func _clear_runtime() -> void:
	for runtime_root in _runtime_roots:
		if is_instance_valid(runtime_root):
			runtime_root.queue_free()
	_runtime_roots.clear()
	_records.clear()


func _build_building_record(building_id: String, building_config: Dictionary, host: Node3D) -> void:
	var runtime_root := Node3D.new()
	runtime_root.name = "FunctionalLights_%s" % building_id.to_pascal_case()
	runtime_root.set_meta("presentation_only", true)
	runtime_root.set_meta("building_id", building_id)
	host.add_child(runtime_root)
	_runtime_roots.append(runtime_root)
	var record := {
		"mode": str(building_config.get("mode", "occupied_night")),
		"host_path": host.get_path(),
		"root": runtime_root,
		"host": host,
		"emitters": [],
		"managed_lights": [],
		"fixture_count": 0,
		"existing_fixture_count": 0,
		"spawned_fixture_count": 0,
		"occupant_count": 0,
		"awake_occupant_count": 0,
		"lit": false,
	}
	var missing_names: Array[String] = []
	for raw_name in building_config.get("existing_fixture_names", []):
		var fixture_name := str(raw_name)
		var matches := _find_descendants_named(host, fixture_name)
		if matches.is_empty():
			missing_names.append(fixture_name)
			continue
		for fixture in matches:
			var center_and_radius := _fixture_center_and_radius(fixture, host)
			_create_emitter(
				runtime_root,
				center_and_radius.get("center", host.to_local(fixture.global_position)) as Vector3,
				float(center_and_radius.get("radius", 0.11)),
				building_config,
				"existing_fixture",
				fixture
			)
			record.existing_fixture_count = int(record.existing_fixture_count) + 1
	for raw_placement in building_config.get("spawned_fixtures", []):
		if not raw_placement is Dictionary:
			continue
		var placement := raw_placement as Dictionary
		var fixture := _spawn_fixture(runtime_root, placement)
		if fixture == null:
			continue
		var center_and_radius := _fixture_center_and_radius(fixture, host)
		_create_emitter(
			runtime_root,
			center_and_radius.get("center", fixture.position) as Vector3,
			float(center_and_radius.get("radius", 0.11)),
			building_config,
			"spawned_fixture",
			fixture
		)
		record.spawned_fixture_count = int(record.spawned_fixture_count) + 1
	for raw_light_name in building_config.get("managed_existing_light_names", []):
		var light_name := str(raw_light_name)
		var matches := _find_descendants_named(host, light_name)
		if matches.is_empty():
			missing_names.append(light_name)
			continue
		for match in matches:
			var light := match as Light3D
			if light == null:
				continue
			light.shadow_enabled = true
			light.light_volumetric_fog_energy = 0.0
			light.distance_fade_enabled = false
			(record.managed_lights as Array).append({
				"light": light,
				"energy": float(light.light_energy),
			})
	record.fixture_count = int(record.existing_fixture_count) + int(record.spawned_fixture_count)
	if not missing_names.is_empty():
		_missing_fixtures[building_id] = missing_names
	_records[building_id] = record


func _spawn_fixture(parent: Node3D, placement: Dictionary) -> Node3D:
	var asset_path := str(placement.get("asset_path", _config.get("default_fixture_asset", DEFAULT_LANTERN_ASSET)))
	var scene := _load_scene(asset_path)
	if scene == null:
		return null
	var fixture_root := Node3D.new()
	fixture_root.name = str(placement.get("name", "LanternFixture"))
	fixture_root.position = _v3(placement.get("position", [0.0, 0.0, 0.0]))
	fixture_root.rotation_degrees = _v3(placement.get("rotation_degrees", [0.0, 0.0, 0.0]))
	fixture_root.set_meta("functional_light_fixture", true)
	fixture_root.set_meta("presentation_only", true)
	fixture_root.set_meta("functional_lantern_required_level", int(placement.get("required_level", 1)))
	parent.add_child(fixture_root)
	if str(placement.get("mount", "wall_bracket")) == "wall_bracket":
		_add_wall_bracket(fixture_root)
	var model := scene.instantiate() as Node3D
	if model == null:
		fixture_root.queue_free()
		return null
	model.name = "LanternModel"
	model.scale = _v3(placement.get("scale", [0.56, 0.56, 0.56]))
	fixture_root.add_child(model)
	_strip_gameplay_nodes(model)
	return fixture_root


func _create_emitter(parent: Node3D, position_value: Vector3, glow_radius: float, building_config: Dictionary, source_kind: String, source_fixture: Node3D) -> void:
	var emitter := Node3D.new()
	emitter.name = "FunctionalEmitter%02d" % (parent.get_child_count() + 1)
	emitter.position = position_value
	emitter.set_meta("functional_light_emitter", true)
	emitter.set_meta("source_kind", source_kind)
	emitter.set_meta("presentation_only", true)
	parent.add_child(emitter)
	var core := MeshInstance3D.new()
	core.name = "FlameGlowCore"
	var sphere := SphereMesh.new()
	sphere.radius = clampf(glow_radius, 0.065, 0.16)
	sphere.height = sphere.radius * 2.0
	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.albedo_color = _color(building_config.get("glow_color", _config.get("glow_color", "#ffd27a")), Color("#ffd27a"))
	glow_material.emission_enabled = true
	glow_material.emission = glow_material.albedo_color
	glow_material.emission_energy_multiplier = float(building_config.get("glow_energy", _config.get("glow_energy", 4.0)))
	sphere.material = glow_material
	core.mesh = sphere
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.visible = false
	emitter.add_child(core)
	var light := OmniLight3D.new()
	light.name = "FunctionalOmniLight"
	light.light_color = _color(building_config.get("color", _config.get("color", "#ffc06a")), Color("#ffc06a"))
	light.light_energy = 0.0
	light.omni_range = float(building_config.get("range", _config.get("range", 5.2)))
	light.omni_attenuation = float(building_config.get("attenuation", _config.get("attenuation", 1.35)))
	light.shadow_enabled = true
	light.shadow_blur = float(building_config.get("shadow_blur", _config.get("shadow_blur", 1.2)))
	light.light_volumetric_fog_energy = 0.0
	# 玩家拉远镜头时仍需看到夜间灯火；距离不再参与功能灯启停。
	light.distance_fade_enabled = false
	light.visible = false
	light.set_meta("functional_light", true)
	light.set_meta("presentation_only", true)
	emitter.add_child(light)
	var building_id := str(parent.get_meta("building_id", ""))
	if not _records.has(building_id):
		# Record construction stores emitters after all fixture nodes are resolved.
		pass
	var pending_emitters := parent.get_meta("pending_emitters", []) as Array
	pending_emitters.append({
		"light": light,
		"core": core,
		"energy": float(building_config.get("energy", _config.get("energy", 1.1))),
		"source_fixture": source_fixture,
		"required_level": int(source_fixture.get_meta("functional_lantern_required_level", 1)) if is_instance_valid(source_fixture) else 1,
	})
	parent.set_meta("pending_emitters", pending_emitters)


func _refresh_all() -> void:
	var is_night := _is_night_time()
	for building_id_variant in _records:
		var building_id := str(building_id_variant)
		var record := _records[building_id] as Dictionary
		if (record.get("emitters", []) as Array).is_empty():
			var root := record.get("root") as Node3D
			if is_instance_valid(root):
				record.emitters = (root.get_meta("pending_emitters", []) as Array).duplicate()
				root.remove_meta("pending_emitters")
		var occupancy := _building_occupancy(building_id)
		record.occupant_count = int(occupancy.get("occupant_count", 0))
		record.awake_occupant_count = int(occupancy.get("awake_occupant_count", 0))
		var mode := str(record.get("mode", "occupied_night"))
		var lit := false
		if is_night:
			match mode:
				"always_night":
					lit = true
				"awake_occupied_night":
					lit = int(record.awake_occupant_count) > 0
				_:
					lit = int(record.occupant_count) > 0
		record.lit = lit
		_apply_record_state(record, lit)
		_records[building_id] = record


func _apply_record_state(record: Dictionary, lit: bool) -> void:
	for raw_emitter in record.get("emitters", []):
		var emitter := raw_emitter as Dictionary
		var light := emitter.get("light") as OmniLight3D
		var core := emitter.get("core") as MeshInstance3D
		var active := lit and _emitter_is_unlocked(emitter)
		if is_instance_valid(light):
			light.light_energy = float(emitter.get("energy", 1.1)) if active else 0.0
			light.visible = active
		if is_instance_valid(core):
			core.visible = active
	for raw_managed in record.get("managed_lights", []):
		var managed := raw_managed as Dictionary
		var light := managed.get("light") as Light3D
		if is_instance_valid(light):
			light.light_energy = float(managed.get("energy", 1.0)) if lit else 0.0
			light.visible = lit


func _emitter_is_unlocked(emitter: Dictionary) -> bool:
	var source_fixture := emitter.get("source_fixture") as Node3D
	if source_fixture == null or not is_instance_valid(source_fixture):
		return int(emitter.get("required_level", 1)) <= 1
	return source_fixture.is_visible_in_tree()


func _building_occupancy(building_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids"):
		return {"occupant_count": 0, "awake_occupant_count": 0}
	var occupant_count := 0
	var awake_occupant_count := 0
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var state := npc_system.get_npc_state(npc_id) as Dictionary
		if str(state.get("current_location", "")) != building_id or bool(state.get("escaped", false)):
			continue
		occupant_count += 1
		if not npc_system.is_npc_sleeping(npc_id):
			awake_occupant_count += 1
	return {"occupant_count": occupant_count, "awake_occupant_count": awake_occupant_count}


func _is_night_time() -> bool:
	var start := _time_array_to_seconds(_config.get("night_start_time", [18, 0]) as Array)
	var finish := _time_array_to_seconds(_config.get("night_end_time", [6, 0]) as Array)
	var current := int(_last_time.get("hour", 0)) * 3600 + int(_last_time.get("minute", 0)) * 60 + int(_last_time.get("second", 0))
	if start == finish:
		return true
	if start < finish:
		return current >= start and current < finish
	return current >= start or current < finish


func _find_formal_host(building_id: String) -> Node3D:
	var best: Node3D
	var best_score := -1000000
	for raw_view in get_tree().get_nodes_in_group("building_art_view"):
		var view := raw_view as Node3D
		if view == null or str(view.get("building_id")) != building_id:
			continue
		var score := _host_priority(view)
		if score > best_score:
			best = view
			best_score = score
	if best != null:
		return best
	var formal_root := get_node_or_null(FORMAL_ROOT_PATH)
	if formal_root == null:
		return null
	for node in _all_descendants(formal_root):
		var candidate := node as Node3D
		if candidate == null or str(candidate.get_meta("building_id", "")) != building_id:
			continue
		var score := _host_priority(candidate)
		if candidate.has_method("debug_get_snapshot"):
			score += 250
		if str(candidate.get_path()).contains("/GateArt/"):
			score += 500
		if score > best_score:
			best = candidate
			best_score = score
	return best


func _host_priority(view: Node3D) -> int:
	var path := str(view.get_path())
	var score := 100 if view.is_visible_in_tree() else 0
	if path.contains("/FormalStationLayout/"):
		score += 1000
	elif path.contains("/WorldRoot/Station/"):
		score -= 100
	return score


func _find_descendants_named(parent: Node, exact_name: String) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in _all_descendants(parent):
		var node_3d := node as Node3D
		if node_3d != null and str(node.name).begins_with(exact_name) and not bool(node.get_meta("functional_light_emitter", false)):
			result.append(node_3d)
	return result


func _fixture_center_and_radius(fixture: Node3D, host: Node3D) -> Dictionary:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var found := false
	for node in _all_descendants(fixture):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var aabb := mesh_instance.get_aabb()
		for endpoint_index in range(8):
			var point := host.to_local(mesh_instance.to_global(aabb.get_endpoint(endpoint_index)))
			minimum.x = minf(minimum.x, point.x)
			minimum.y = minf(minimum.y, point.y)
			minimum.z = minf(minimum.z, point.z)
			maximum.x = maxf(maximum.x, point.x)
			maximum.y = maxf(maximum.y, point.y)
			maximum.z = maxf(maximum.z, point.z)
			found = true
	if not found:
		return {"center": host.to_local(fixture.global_position), "radius": 0.10}
	var size := maximum - minimum
	return {
		"center": (minimum + maximum) * 0.5,
		"radius": clampf(minf(size.x, minf(size.y, size.z)) * 0.16, 0.07, 0.14),
	}


func _add_wall_bracket(parent: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#34383c")
	material.roughness = 0.72
	var upright := MeshInstance3D.new()
	upright.name = "IronBracketUpright"
	var upright_mesh := CylinderMesh.new()
	upright_mesh.top_radius = 0.035
	upright_mesh.bottom_radius = 0.035
	upright_mesh.height = 0.62
	upright_mesh.material = material
	upright.mesh = upright_mesh
	upright.position = Vector3(0.0, 0.34, -0.24)
	parent.add_child(upright)
	var arm := MeshInstance3D.new()
	arm.name = "IronBracketArm"
	var arm_mesh := CylinderMesh.new()
	arm_mesh.top_radius = 0.035
	arm_mesh.bottom_radius = 0.035
	arm_mesh.height = 0.52
	arm_mesh.material = material
	arm.mesh = arm_mesh
	arm.position = Vector3(0.0, 0.62, 0.0)
	arm.rotation_degrees.x = 90.0
	parent.add_child(arm)


func _strip_gameplay_nodes(parent: Node) -> void:
	for child in parent.get_children(true):
		if child is CollisionObject3D or child is CollisionShape3D or child is NavigationRegion3D or child is NavigationLink3D:
			parent.remove_child(child)
			child.queue_free()
			continue
		_strip_gameplay_nodes(child)


func _record_lights_are_shadowed(record: Dictionary) -> bool:
	for raw_emitter in record.get("emitters", []):
		var light := (raw_emitter as Dictionary).get("light") as Light3D
		if is_instance_valid(light) and not light.shadow_enabled:
			return false
	for raw_managed in record.get("managed_lights", []):
		var light := (raw_managed as Dictionary).get("light") as Light3D
		if is_instance_valid(light) and not light.shadow_enabled:
			return false
	return true


func _record_lights_are_fog_neutral(record: Dictionary) -> bool:
	for raw_emitter in record.get("emitters", []):
		var light := (raw_emitter as Dictionary).get("light") as Light3D
		if is_instance_valid(light) and light.light_volumetric_fog_energy > 0.0001:
			return false
	for raw_managed in record.get("managed_lights", []):
		var light := (raw_managed as Dictionary).get("light") as Light3D
		if is_instance_valid(light) and light.light_volumetric_fog_energy > 0.0001:
			return false
	return true


func _record_lights_keep_far_visibility(record: Dictionary) -> bool:
	for raw_emitter in record.get("emitters", []):
		var light := (raw_emitter as Dictionary).get("light") as Light3D
		if is_instance_valid(light) and light.distance_fade_enabled:
			return false
	for raw_managed in record.get("managed_lights", []):
		var light := (raw_managed as Dictionary).get("light") as Light3D
		if is_instance_valid(light) and light.distance_fade_enabled:
			return false
	return true


func _load_scene(path: String) -> PackedScene:
	if _asset_scene_cache.has(path):
		return _asset_scene_cache[path] as PackedScene
	var scene := load(path) as PackedScene
	if scene != null:
		_asset_scene_cache[path] = scene
	return scene


func _all_descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in parent.get_children(true):
		result.append(child)
		result.append_array(_all_descendants(child))
	return result


func _time_array_to_seconds(value: Array) -> int:
	if value.size() < 2:
		return 0
	return clampi(int(value[0]), 0, 23) * 3600 + clampi(int(value[1]), 0, 59) * 60


func _v3(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _color(value: Variant, fallback: Color) -> Color:
	if value is String and Color.html_is_valid(str(value)):
		return Color(str(value))
	if value is Color:
		return value
	return fallback
