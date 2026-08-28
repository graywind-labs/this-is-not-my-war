extends Node3D

const SECONDS_PER_DAY := 86400.0
const DEFAULT_TWILIGHT_START_DEGREES := -6.0
const DEFAULT_FULL_LIGHT_DEGREES := 10.0
const DEFAULT_DIRECTION_UPDATE_INTERVAL_GAME_SECONDS := 0.0
const BUILDING_FUNCTIONAL_LIGHT_CONTROLLER_SCRIPT := preload("res://scripts/presentation/environment/BuildingFunctionalLightController.gd")

var _config: Dictionary = {}
var _sun_light: DirectionalLight3D
var _moon_light: DirectionalLight3D
var _sun_state: Dictionary = {}
var _moon_state: Dictionary = {}
var _last_time: Dictionary = {
	"day": 1,
	"hour": 6,
	"minute": 0,
	"second": 0,
}
var _shadow_owner := "none"
var _legacy_light_retired_count := 0
var _time_signal_connected := false
var _world_environment: WorldEnvironment
var _environment_resource: Environment
var _sky_resource: Sky
var _sky_material: ProceduralSkyMaterial
var _environment_state: Dictionary = {}
var _roof_visibility_controller: Node
var _roof_signal_connected := false
var _interior_lights_by_building: Dictionary = {}
var _interior_reveal_by_building: Dictionary = {}
var _interior_energy_by_building: Dictionary = {}
var _interior_color_by_building: Dictionary = {}
var _interior_reveal_weight := 0.0
var _active_interior_light_count := 0
var _interior_time_scale := 1.0
var _interior_daylight_weight := 0.0
var _interior_lighting_phase := "night_base"
var _interior_daylight_color := Color("#dbe8e4")
var _building_functional_light_controller: Node3D
var _last_direction_update_bucket := -1
var _direction_update_count := 0
var _applied_light_ray_directions := {
	"sun": Vector3.ZERO,
	"moon": Vector3.ZERO,
}


func configure(environment_config: Dictionary) -> void:
	_config = (environment_config.get("celestial_cycle", {}) as Dictionary).duplicate(true)
	_last_direction_update_bucket = -1
	_direction_update_count = 0
	_applied_light_ray_directions = {
		"sun": Vector3.ZERO,
		"moon": Vector3.ZERO,
	}
	if is_inside_tree():
		_ensure_lights()
		_ensure_world_environment()
		_connect_time_signal()
		_connect_roof_visibility_signal()
		_ensure_building_functional_light_controller()
		_retire_legacy_lights()
		sync_from_game_state()
		call_deferred("_sync_roof_visibility_from_controller")


func _ready() -> void:
	_ensure_lights()
	_ensure_world_environment()
	_connect_time_signal()
	_connect_roof_visibility_signal()
	_ensure_building_functional_light_controller()
	_retire_legacy_lights()
	sync_from_game_state()
	call_deferred("_sync_roof_visibility_from_controller")
	set_meta("presentation_only", true)
	set_meta("time_authority", false)


func _exit_tree() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("time_changed"):
		var callback := Callable(self, "_on_time_changed")
		if event_bus.time_changed.is_connected(callback):
			event_bus.time_changed.disconnect(callback)
	_time_signal_connected = false
	if is_instance_valid(_roof_visibility_controller) and _roof_visibility_controller.has_signal("roof_visibility_changed"):
		var roof_callback := Callable(self, "_on_roof_visibility_changed")
		if _roof_visibility_controller.is_connected("roof_visibility_changed", roof_callback):
			_roof_visibility_controller.disconnect("roof_visibility_changed", roof_callback)
	_roof_signal_connected = false


func sync_from_game_state() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		_apply_time(
			int(_last_time.get("day", 1)),
			int(_last_time.get("hour", 6)),
			int(_last_time.get("minute", 0)),
			int(_last_time.get("second", 0))
		)
		return
	_apply_time(
		int(game_state.current_day),
		int(game_state.current_hour),
		int(game_state.current_minute),
		int(game_state.current_second)
	)


func get_debug_snapshot() -> Dictionary:
	return {
		"enabled": not _config.is_empty(),
		"time": _last_time.duplicate(true),
		"normalized_day_time": _seconds_from_time(
			int(_last_time.get("hour", 0)),
			int(_last_time.get("minute", 0)),
			int(_last_time.get("second", 0))
		) / SECONDS_PER_DAY,
		"sun": _sun_state.duplicate(true),
		"moon": _moon_state.duplicate(true),
		"shadow_owner": _shadow_owner,
		"active_shadow_count": int(_sun_light != null and _sun_light.shadow_enabled) + int(_moon_light != null and _moon_light.shadow_enabled),
		"directional_shadow": _get_directional_shadow_snapshot(),
		"sun_light_present": is_instance_valid(_sun_light),
		"moon_light_present": is_instance_valid(_moon_light),
		"world_environment_present": is_instance_valid(_world_environment),
		"procedural_sky_present": is_instance_valid(_sky_material),
		"environment": _environment_state.duplicate(true),
		"interior_fill": {
			"configured_building_count": (_config.get("interior_fill", {}) as Dictionary).get("buildings", {}).size(),
			"light_count": _count_interior_lights(),
			"active_light_count": _active_interior_light_count,
			"revealed_building_count": _count_revealed_buildings(),
			"maximum_reveal": _interior_reveal_weight,
			"reveal_by_building": _interior_reveal_by_building.duplicate(true),
			"energy_by_building": _interior_energy_by_building.duplicate(true),
			"color_by_building": _interior_color_by_building.duplicate(true),
			"time_scale": _interior_time_scale,
			"daylight_weight": _interior_daylight_weight,
			"lighting_phase": _interior_lighting_phase,
			"daylight_color": _interior_daylight_color,
			"roof_signal_connected": _roof_signal_connected,
		},
		"functional_lights": (
			_building_functional_light_controller.call("get_debug_snapshot")
			if is_instance_valid(_building_functional_light_controller)
			else {}
		),
		"time_signal_connected": _time_signal_connected,
		"legacy_light_retired_count": _legacy_light_retired_count,
		"maintains_second_clock": false,
		"authority_role": "presentation_only",
	}


func _ensure_building_functional_light_controller() -> void:
	if is_instance_valid(_building_functional_light_controller):
		_building_functional_light_controller.call("configure", _config.get("functional_lights", {}) as Dictionary)
		return
	var controller := BUILDING_FUNCTIONAL_LIGHT_CONTROLLER_SCRIPT.new() as Node3D
	if controller == null:
		return
	controller.name = "BuildingFunctionalLightController"
	controller.call("configure", _config.get("functional_lights", {}) as Dictionary)
	add_child(controller)
	_building_functional_light_controller = controller


func _on_time_changed(day: int, hour: int, minute: int, second: int) -> void:
	_apply_time(day, hour, minute, second)


func _apply_time(day: int, hour: int, minute: int, second: int) -> void:
	if _config.is_empty():
		return
	_last_time = {
		"day": max(day, 1),
		"hour": clampi(hour, 0, 23),
		"minute": clampi(minute, 0, 59),
		"second": clampi(second, 0, 59),
	}
	var seconds_into_day := _seconds_from_time(
		int(_last_time.hour),
		int(_last_time.minute),
		int(_last_time.second)
	)
	_sun_state = _calculate_body_state("sun", _config.get("sun", {}) as Dictionary, seconds_into_day)
	_moon_state = _calculate_body_state("moon", _config.get("moon", {}) as Dictionary, seconds_into_day)
	_resolve_shadow_owner()
	var update_light_directions := _consume_direction_update_due(int(_last_time.day), seconds_into_day)
	_apply_state_to_light(_sun_light, _sun_state, _shadow_owner == "sun", update_light_directions)
	_apply_state_to_light(_moon_light, _moon_state, _shadow_owner == "moon", update_light_directions)
	_apply_environment_state()
	_update_interior_lights()


func _apply_environment_state() -> void:
	if not is_instance_valid(_environment_resource) or not is_instance_valid(_sky_material):
		return
	var environment_config := _config.get("environment", {}) as Dictionary
	if environment_config.is_empty():
		return
	var altitude := float(_sun_state.get("altitude_degrees", -42.0))
	var night_state := environment_config.get("night", {}) as Dictionary
	var golden_state := environment_config.get("golden", {}) as Dictionary
	var day_state := environment_config.get("day", {}) as Dictionary
	var state: Dictionary
	var phase := "night"
	var blend := 0.0
	if altitude < -6.0:
		state = night_state.duplicate(true)
	elif altitude < 0.0:
		blend = smoothstep(-6.0, 0.0, altitude)
		state = _blend_environment_states(night_state, golden_state, blend)
		phase = "twilight"
	elif altitude < 10.0:
		blend = smoothstep(0.0, 10.0, altitude)
		state = _blend_environment_states(golden_state, day_state, blend)
		phase = "golden"
	else:
		state = day_state.duplicate(true)
		phase = "day"

	var fog_reveal_multiplier := float(environment_config.get("fog_reveal_multiplier", 0.28))
	var fog_density := float(state.get("fog_density", 0.0006)) * lerpf(1.0, fog_reveal_multiplier, _interior_reveal_weight)
	_sky_material.sky_top_color = _color(state.get("sky_top_color", "#4b7895"), Color("#4b7895"))
	_sky_material.sky_horizon_color = _color(state.get("sky_horizon_color", "#b4ced2"), Color("#b4ced2"))
	_sky_material.ground_bottom_color = _color(state.get("ground_bottom_color", "#354841"), Color("#354841"))
	_sky_material.ground_horizon_color = _color(state.get("ground_horizon_color", "#7f9a88"), Color("#7f9a88"))
	_sky_material.sky_energy_multiplier = float(state.get("sky_energy", 1.0))
	_sky_material.ground_energy_multiplier = float(state.get("ground_energy", 0.7))
	_environment_resource.background_energy_multiplier = float(state.get("background_energy", 1.0))
	_environment_resource.ambient_light_color = _color(state.get("ambient_color", "#b7c9c4"), Color("#b7c9c4"))
	_environment_resource.ambient_light_energy = float(state.get("ambient_energy", 0.82))
	_environment_resource.fog_light_color = _color(state.get("fog_color", "#8ca9a8"), Color("#8ca9a8"))
	_environment_resource.fog_light_energy = float(state.get("fog_energy", 0.75))
	_environment_resource.fog_density = fog_density
	_environment_resource.fog_sun_scatter = float(state.get("fog_sun_scatter", 0.08))
	_environment_resource.fog_sky_affect = float(state.get("fog_sky_affect", 0.22))
	_environment_resource.tonemap_exposure = float(state.get("exposure", 1.08))
	_environment_state = state.duplicate(true)
	_environment_state["phase"] = phase
	_environment_state["phase_blend"] = blend
	_environment_state["sun_altitude_degrees"] = altitude
	_environment_state["fog_density_base"] = float(state.get("fog_density", 0.0006))
	_environment_state["fog_density"] = fog_density
	_environment_state["fog_reveal_multiplier"] = fog_reveal_multiplier
	_environment_state["interior_reveal_weight"] = _interior_reveal_weight


func _blend_environment_states(from_state: Dictionary, to_state: Dictionary, weight: float) -> Dictionary:
	var result: Dictionary = {}
	var color_keys := [
		"sky_top_color", "sky_horizon_color", "ground_bottom_color", "ground_horizon_color",
		"ambient_color", "fog_color",
	]
	var number_keys := [
		"sky_energy", "ground_energy", "background_energy", "ambient_energy", "fog_energy",
		"fog_density", "fog_sun_scatter", "fog_sky_affect", "exposure",
	]
	for key in color_keys:
		var from_color := _color(from_state.get(key, "#ffffff"), Color.WHITE)
		var to_color := _color(to_state.get(key, from_color), from_color)
		result[key] = from_color.lerp(to_color, weight)
	for key in number_keys:
		var from_value := float(from_state.get(key, 0.0))
		result[key] = lerpf(from_value, float(to_state.get(key, from_value)), weight)
	return result


func _calculate_body_state(kind: String, body_config: Dictionary, seconds_into_day: float) -> Dictionary:
	var defaults := _body_defaults(kind)
	var rise_seconds := _configured_time_seconds(body_config.get("rise_time", defaults.rise_time), defaults.rise_time)
	var transit_seconds := _configured_time_seconds(body_config.get("transit_time", defaults.transit_time), defaults.transit_time)
	var set_seconds := _configured_time_seconds(body_config.get("set_time", defaults.set_time), defaults.set_time)
	var transit_elapsed := fposmod(transit_seconds - rise_seconds, SECONDS_PER_DAY)
	var set_elapsed := fposmod(set_seconds - rise_seconds, SECONDS_PER_DAY)
	if transit_elapsed <= 0.0 or set_elapsed <= transit_elapsed:
		transit_elapsed = set_elapsed * 0.5
	var elapsed := fposmod(seconds_into_day - rise_seconds, SECONDS_PER_DAY)
	var visible_arc := elapsed <= set_elapsed
	var arc_progress := 0.0
	var altitude_degrees := 0.0
	var maximum_altitude := float(body_config.get("max_altitude_degrees", defaults.max_altitude_degrees))
	var below_horizon_depth := float(body_config.get("below_horizon_depth_degrees", defaults.below_horizon_depth_degrees))
	if visible_arc:
		if elapsed <= transit_elapsed:
			arc_progress = 0.5 * elapsed / maxf(transit_elapsed, 0.001)
		else:
			arc_progress = 0.5 + 0.5 * (elapsed - transit_elapsed) / maxf(set_elapsed - transit_elapsed, 0.001)
		altitude_degrees = maximum_altitude * sin(PI * arc_progress)
	else:
		var below_progress := (elapsed - set_elapsed) / maxf(SECONDS_PER_DAY - set_elapsed, 0.001)
		arc_progress = 1.0 + below_progress
		altitude_degrees = -below_horizon_depth * sin(PI * below_progress)

	var horizontal_angle := PI * arc_progress
	var horizontal_direction := Vector3(cos(horizontal_angle), 0.0, -sin(horizontal_angle)).normalized()
	var altitude_radians := deg_to_rad(altitude_degrees)
	var sky_direction := (
		horizontal_direction * cos(altitude_radians)
		+ Vector3.UP * sin(altitude_radians)
	).normalized()
	var twilight_start := float(_config.get("twilight_start_altitude_degrees", DEFAULT_TWILIGHT_START_DEGREES))
	var full_light_altitude := float(_config.get("full_light_altitude_degrees", DEFAULT_FULL_LIGHT_DEGREES))
	var direct_factor := smoothstep(twilight_start, full_light_altitude, altitude_degrees)
	var peak_sine := maxf(sin(deg_to_rad(maximum_altitude)), 0.001)
	var height_factor := clampf(sin(deg_to_rad(maxf(altitude_degrees, 0.0))) / peak_sine, 0.0, 1.0)
	var maximum_energy := float(body_config.get("max_energy", defaults.max_energy))
	var energy := maximum_energy * direct_factor * lerpf(0.82, 1.0, height_factor)
	if altitude_degrees <= twilight_start:
		energy = 0.0
	var color_blend := smoothstep(0.0, 18.0, altitude_degrees)
	var horizon_color := _color(body_config.get("horizon_color", defaults.horizon_color), defaults.horizon_color)
	var zenith_color := _color(body_config.get("zenith_color", defaults.zenith_color), defaults.zenith_color)
	var light_color := horizon_color.lerp(zenith_color, color_blend)
	return {
		"kind": kind,
		"rise_seconds": rise_seconds,
		"transit_seconds": transit_seconds,
		"set_seconds": set_seconds,
		"rise_time": _format_seconds(rise_seconds),
		"transit_time": _format_seconds(transit_seconds),
		"set_time": _format_seconds(set_seconds),
		"visible_arc": visible_arc,
		"arc_progress": arc_progress,
		"altitude_degrees": altitude_degrees,
		"azimuth_degrees": rad_to_deg(atan2(sky_direction.x, -sky_direction.z)),
		"sky_direction": sky_direction,
		"light_ray_direction": -sky_direction,
		"direct_factor": direct_factor,
		"energy": maxf(energy, 0.0),
		"color": light_color,
		"casts_shadow": false,
	}


func _resolve_shadow_owner() -> void:
	var minimum_energy := float(_config.get("shadow_min_energy", 0.03))
	var sun_energy := float(_sun_state.get("energy", 0.0))
	var moon_energy := float(_moon_state.get("energy", 0.0))
	_shadow_owner = "none"
	if maxf(sun_energy, moon_energy) >= minimum_energy:
		_shadow_owner = "sun" if sun_energy >= moon_energy else "moon"
	_sun_state["casts_shadow"] = _shadow_owner == "sun"
	_moon_state["casts_shadow"] = _shadow_owner == "moon"


func _apply_state_to_light(
	light_node: DirectionalLight3D,
	state: Dictionary,
	casts_shadow: bool,
	update_direction: bool
) -> void:
	if not is_instance_valid(light_node) or state.is_empty():
		return
	var ray_direction: Vector3 = state.get("light_ray_direction", Vector3(0.0, -1.0, 0.0))
	if update_direction and ray_direction.length_squared() > 0.0001:
		light_node.basis = Basis.looking_at(ray_direction.normalized(), Vector3.UP)
		_applied_light_ray_directions[str(state.get("kind", ""))] = ray_direction.normalized()
	light_node.light_color = state.get("color", Color.WHITE)
	light_node.light_energy = float(state.get("energy", 0.0))
	light_node.shadow_enabled = casts_shadow


func _consume_direction_update_due(day: int, seconds_into_day: float) -> bool:
	var interval := float(_config.get(
		"directional_transform_update_interval_game_seconds",
		DEFAULT_DIRECTION_UPDATE_INTERVAL_GAME_SECONDS
	))
	if interval <= 0.0:
		_last_direction_update_bucket = -1
		_direction_update_count += 1
		return true
	var absolute_game_seconds := float(maxi(day - 1, 0)) * SECONDS_PER_DAY + seconds_into_day
	var bucket := floori(absolute_game_seconds / interval)
	if bucket == _last_direction_update_bucket:
		return false
	_last_direction_update_bucket = bucket
	_direction_update_count += 1
	return true


func _ensure_lights() -> void:
	if not is_instance_valid(_sun_light):
		_sun_light = DirectionalLight3D.new()
		_sun_light.name = "SunDirectionalLight"
		add_child(_sun_light)
		_configure_light(_sun_light, "sun")
	if not is_instance_valid(_moon_light):
		_moon_light = DirectionalLight3D.new()
		_moon_light.name = "MoonDirectionalLight"
		add_child(_moon_light)
		_configure_light(_moon_light, "moon")


func _ensure_world_environment() -> void:
	if is_instance_valid(_world_environment):
		return
	_world_environment = WorldEnvironment.new()
	_world_environment.name = "DynamicWorldEnvironment"
	_environment_resource = Environment.new()
	_sky_resource = Sky.new()
	_sky_material = ProceduralSkyMaterial.new()
	_sky_resource.sky_material = _sky_material
	_environment_resource.background_mode = Environment.BG_SKY
	_environment_resource.sky = _sky_resource
	_environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment_resource.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment_resource.tonemap_mode = Environment.TONE_MAPPER_ACES
	_environment_resource.fog_enabled = true
	_environment_resource.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_environment_resource.fog_height_density = 0.0
	_environment_resource.fog_depth_begin = 52.0
	_environment_resource.fog_depth_end = 360.0
	_environment_resource.fog_depth_curve = 1.0
	_environment_resource.adjustment_enabled = true
	var environment_config := _config.get("environment", {}) as Dictionary
	_environment_resource.adjustment_brightness = float(environment_config.get("adjustment_brightness", 1.02))
	_environment_resource.adjustment_contrast = float(environment_config.get("adjustment_contrast", 0.98))
	_environment_resource.adjustment_saturation = float(environment_config.get("adjustment_saturation", 1.05))
	_sky_material.sky_curve = 0.12
	_sky_material.ground_curve = 0.10
	_sky_material.sun_angle_max = 5.0
	_sky_material.sun_curve = 0.08
	_world_environment.environment = _environment_resource
	_world_environment.set_meta("presentation_only", true)
	_world_environment.set_meta("dynamic_time_environment", true)
	add_child(_world_environment)


func _configure_light(light_node: DirectionalLight3D, kind: String) -> void:
	light_node.light_energy = 0.0
	light_node.shadow_enabled = false
	light_node.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	light_node.directional_shadow_max_distance = float(_config.get("directional_shadow_max_distance", 120.0))
	light_node.directional_shadow_fade_start = float(_config.get("directional_shadow_fade_start", 0.86))
	light_node.directional_shadow_blend_splits = bool(_config.get("directional_shadow_blend_splits", true))
	light_node.directional_shadow_split_1 = float(_config.get("directional_shadow_split_1", 0.12))
	light_node.directional_shadow_split_2 = float(_config.get("directional_shadow_split_2", 0.30))
	light_node.directional_shadow_split_3 = float(_config.get("directional_shadow_split_3", 0.60))
	light_node.shadow_blur = float(_config.get("shadow_blur", 1.25))
	light_node.set_meta("celestial_body", kind)
	light_node.set_meta("presentation_only", true)


func _get_directional_shadow_snapshot() -> Dictionary:
	if not is_instance_valid(_sun_light) or not is_instance_valid(_moon_light):
		return {}
	return {
		"mode": int(_sun_light.directional_shadow_mode),
		"max_distance": _sun_light.directional_shadow_max_distance,
		"fade_start": _sun_light.directional_shadow_fade_start,
		"blend_splits": _sun_light.directional_shadow_blend_splits,
		"split_1": _sun_light.directional_shadow_split_1,
		"split_2": _sun_light.directional_shadow_split_2,
		"split_3": _sun_light.directional_shadow_split_3,
		"transform_update_interval_game_seconds": float(_config.get(
			"directional_transform_update_interval_game_seconds",
			DEFAULT_DIRECTION_UPDATE_INTERVAL_GAME_SECONDS
		)),
		"transform_update_bucket": _last_direction_update_bucket,
		"transform_update_count": _direction_update_count,
		"sun_applied_light_ray_direction": _applied_light_ray_directions.get("sun", Vector3.ZERO),
		"moon_applied_light_ray_direction": _applied_light_ray_directions.get("moon", Vector3.ZERO),
		"sun_moon_match": (
			is_equal_approx(_sun_light.directional_shadow_max_distance, _moon_light.directional_shadow_max_distance)
			and is_equal_approx(_sun_light.directional_shadow_fade_start, _moon_light.directional_shadow_fade_start)
			and _sun_light.directional_shadow_blend_splits == _moon_light.directional_shadow_blend_splits
			and is_equal_approx(_sun_light.directional_shadow_split_1, _moon_light.directional_shadow_split_1)
			and is_equal_approx(_sun_light.directional_shadow_split_2, _moon_light.directional_shadow_split_2)
			and is_equal_approx(_sun_light.directional_shadow_split_3, _moon_light.directional_shadow_split_3)
		),
	}


func _connect_time_signal() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null or not event_bus.has_signal("time_changed"):
		_time_signal_connected = false
		return
	var callback := Callable(self, "_on_time_changed")
	if not event_bus.time_changed.is_connected(callback):
		event_bus.time_changed.connect(callback)
	_time_signal_connected = event_bus.time_changed.is_connected(callback)


func _connect_roof_visibility_signal() -> void:
	_roof_visibility_controller = get_tree().get_first_node_in_group("roof_visibility_controller")
	if not is_instance_valid(_roof_visibility_controller) or not _roof_visibility_controller.has_signal("roof_visibility_changed"):
		_roof_signal_connected = false
		return
	var callback := Callable(self, "_on_roof_visibility_changed")
	if not _roof_visibility_controller.is_connected("roof_visibility_changed", callback):
		_roof_visibility_controller.connect("roof_visibility_changed", callback)
	_roof_signal_connected = _roof_visibility_controller.is_connected("roof_visibility_changed", callback)


func _sync_roof_visibility_from_controller() -> void:
	if not is_instance_valid(_roof_visibility_controller):
		_connect_roof_visibility_signal()
	if not is_instance_valid(_roof_visibility_controller) or not _roof_visibility_controller.has_method("debug_get_snapshot"):
		return
	var snapshot := _roof_visibility_controller.call("debug_get_snapshot") as Dictionary
	_on_roof_visibility_changed(
		float(snapshot.get("camera_distance", 70.0)),
		float(snapshot.get("zoom_normalized", 1.0)),
		snapshot.get("views", []) as Array
	)


func _on_roof_visibility_changed(_camera_distance: float, _zoom_normalized: float, view_snapshots: Array) -> void:
	_ensure_interior_fill_lights()
	var interior_config := _config.get("interior_fill", {}) as Dictionary
	var building_configs := interior_config.get("buildings", {}) as Dictionary
	var reveal_threshold := float(interior_config.get("reveal_threshold", 0.72))
	_interior_reveal_by_building.clear()
	_interior_reveal_weight = 0.0
	for raw_view in view_snapshots:
		var view := raw_view as Dictionary
		var building_id := str(view.get("building_id", ""))
		if not building_configs.has(building_id):
			continue
		var reveal := 0.0
		if bool(view.get("interior_revealed_for_selection", false)):
			var shell_opacity := maxf(float(view.get("roof_opacity", 1.0)), float(view.get("exterior_opacity", 1.0)))
			var minimum_opacity := float(view.get("minimum_roof_opacity", 0.06))
			reveal = clampf(inverse_lerp(reveal_threshold, minimum_opacity, shell_opacity), 0.0, 1.0)
		_interior_reveal_by_building[building_id] = reveal
		_interior_reveal_weight = maxf(_interior_reveal_weight, reveal)
	_apply_environment_state()
	_update_interior_lights()


func _ensure_interior_fill_lights() -> void:
	var interior_config := _config.get("interior_fill", {}) as Dictionary
	var building_configs := interior_config.get("buildings", {}) as Dictionary
	var area_fill_config := interior_config.get("soft_area_fill", {}) as Dictionary
	if building_configs.is_empty():
		return
	var candidate_by_building: Dictionary = {}
	var candidate_score_by_building: Dictionary = {}
	for raw_view in get_tree().get_nodes_in_group("building_art_view"):
		var view := raw_view as Node3D
		if view == null:
			continue
		var building_id := str(view.get("building_id"))
		if not building_configs.has(building_id):
			continue
		var score := _interior_view_priority(view)
		if not candidate_by_building.has(building_id) or score > int(candidate_score_by_building.get(building_id, -1000000)):
			candidate_by_building[building_id] = view
			candidate_score_by_building[building_id] = score
	for building_id_variant in candidate_by_building:
		var building_id := str(building_id_variant)
		if _interior_lights_by_building.has(building_id):
			continue
		var view := candidate_by_building[building_id] as Node3D
		var building_config := building_configs.get(building_id, {}) as Dictionary
		var light_root := Node3D.new()
		light_root.name = "InteriorFillLights"
		light_root.set_meta("presentation_only", true)
		light_root.set_meta("building_id", building_id)
		view.add_child(light_root)
		var lights: Array[SpotLight3D] = []
		var positions := building_config.get("positions", []) as Array
		for index in positions.size():
			var fill_light := SpotLight3D.new()
			fill_light.name = "InteriorFill%02d" % (index + 1)
			fill_light.position = _v3(positions[index])
			fill_light.rotation_degrees.x = -90.0
			fill_light.light_color = _color(building_config.get("color", "#ffd49b"), Color("#ffd49b"))
			fill_light.light_energy = 0.0
			fill_light.light_volumetric_fog_energy = 0.0
			fill_light.shadow_enabled = bool(area_fill_config.get("shadow_enabled", true))
			fill_light.shadow_blur = float(area_fill_config.get("shadow_blur", 1.4))
			fill_light.spot_range = float(building_config.get("range", area_fill_config.get("range", 18.0)))
			fill_light.spot_angle = float(building_config.get("angle", area_fill_config.get("angle", 88.0)))
			fill_light.spot_attenuation = float(building_config.get("attenuation", area_fill_config.get("distance_attenuation", 0.12)))
			fill_light.spot_angle_attenuation = float(building_config.get("angle_attenuation", area_fill_config.get("edge_attenuation", 0.08)))
			fill_light.visible = false
			fill_light.set_meta("presentation_only", true)
			fill_light.set_meta("interior_fill", true)
			fill_light.set_meta("building_id", building_id)
			light_root.add_child(fill_light)
			lights.append(fill_light)
		_interior_lights_by_building[building_id] = lights


func _interior_view_priority(view: Node3D) -> int:
	var path := str(view.get_path())
	var score := 100 if view.is_visible_in_tree() else 0
	if path.contains("/FormalStationLayout/"):
		score += 1000
	elif path.contains("/WorldRoot/Station/"):
		score -= 100
	return score


func _update_interior_lights() -> void:
	var interior_config := _config.get("interior_fill", {}) as Dictionary
	var building_configs := interior_config.get("buildings", {}) as Dictionary
	var area_fill_config := interior_config.get("soft_area_fill", {}) as Dictionary
	var time_curve := _calculate_interior_time_curve(interior_config)
	_interior_time_scale = float(time_curve.get("scale", 1.0))
	_interior_daylight_weight = float(time_curve.get("daylight_weight", 0.0))
	_interior_lighting_phase = str(time_curve.get("phase", "night_base"))
	_interior_daylight_color = _calculate_interior_daylight_color(interior_config)
	var per_light_energy_scale := clampf(float(area_fill_config.get("per_light_energy_scale", 0.58)), 0.05, 1.0)
	_active_interior_light_count = 0
	_interior_energy_by_building.clear()
	_interior_color_by_building.clear()
	for building_id_variant in _interior_lights_by_building:
		var building_id := str(building_id_variant)
		var building_config := building_configs.get(building_id, {}) as Dictionary
		var reveal := float(_interior_reveal_by_building.get(building_id, 0.0))
		var energy := float(building_config.get("max_energy", 1.8)) * _interior_time_scale * reveal * per_light_energy_scale
		var night_color := _color(building_config.get("color", "#ffd49b"), Color("#ffd49b"))
		var light_color := night_color.lerp(_interior_daylight_color, _interior_daylight_weight)
		_interior_energy_by_building[building_id] = energy
		_interior_color_by_building[building_id] = light_color
		for raw_light in _interior_lights_by_building[building_id] as Array:
			var fill_light := raw_light as SpotLight3D
			if not is_instance_valid(fill_light):
				continue
			fill_light.light_energy = energy
			fill_light.light_color = light_color
			fill_light.visible = energy > 0.01
			if fill_light.visible:
				_active_interior_light_count += 1


func _calculate_interior_time_curve(interior_config: Dictionary) -> Dictionary:
	var current_seconds := _seconds_from_time(
		int(_last_time.get("hour", 0)),
		int(_last_time.get("minute", 0)),
		int(_last_time.get("second", 0))
	)
	var start_seconds := _configured_time_seconds(interior_config.get("daylight_start_time", [6, 0]), [6, 0])
	var peak_seconds := _configured_time_seconds(interior_config.get("daylight_peak_time", [12, 0]), [12, 0])
	var end_seconds := _configured_time_seconds(interior_config.get("daylight_end_time", [18, 0]), [18, 0])
	var base_scale := maxf(float(interior_config.get("night_base_scale", 1.0)), 0.0)
	var peak_scale := maxf(float(interior_config.get("day_peak_scale", 1.30)), base_scale)
	var curve_power := maxf(float(interior_config.get("daylight_curve_power", 0.72)), 0.01)
	var daylight_weight := 0.0
	var phase := "night_base"
	if start_seconds < peak_seconds and peak_seconds < end_seconds and current_seconds >= start_seconds and current_seconds <= end_seconds:
		if is_equal_approx(current_seconds, peak_seconds):
			daylight_weight = 1.0
			phase = "day_peak"
		elif current_seconds < peak_seconds:
			var rise_progress := inverse_lerp(start_seconds, peak_seconds, current_seconds)
			daylight_weight = pow(sin(rise_progress * PI * 0.5), curve_power)
			phase = "morning_rise"
		else:
			var fall_progress := inverse_lerp(peak_seconds, end_seconds, current_seconds)
			daylight_weight = pow(cos(fall_progress * PI * 0.5), curve_power)
			phase = "afternoon_fall"
	return {
		"scale": lerpf(base_scale, peak_scale, clampf(daylight_weight, 0.0, 1.0)),
		"daylight_weight": clampf(daylight_weight, 0.0, 1.0),
		"phase": phase,
	}


func _calculate_interior_daylight_color(interior_config: Dictionary) -> Color:
	var sun_color := _color(_sun_state.get("color", "#dce8f6"), Color("#dce8f6"))
	var ambient_color := _color(_environment_state.get("ambient_color", "#b7c9c4"), Color("#b7c9c4"))
	var sun_mix := clampf(float(interior_config.get("daylight_sun_mix", 0.62)), 0.0, 1.0)
	var neutral_mix := clampf(float(interior_config.get("daylight_neutral_mix", 0.10)), 0.0, 1.0)
	var neutral_color := _color(interior_config.get("daylight_neutral_color", "#dbe8e4"), Color("#dbe8e4"))
	return ambient_color.lerp(sun_color, sun_mix).lerp(neutral_color, neutral_mix)


func _count_interior_lights() -> int:
	var result := 0
	for lights in _interior_lights_by_building.values():
		result += (lights as Array).size()
	return result


func _count_revealed_buildings() -> int:
	var result := 0
	for reveal in _interior_reveal_by_building.values():
		if float(reveal) > 0.01:
			result += 1
	return result


func _retire_legacy_lights() -> void:
	_legacy_light_retired_count = 0
	for raw_path in _config.get("legacy_light_paths", []):
		var legacy_light := get_node_or_null(NodePath(str(raw_path))) as DirectionalLight3D
		if legacy_light == null or legacy_light == _sun_light or legacy_light == _moon_light:
			continue
		legacy_light.light_energy = 0.0
		legacy_light.shadow_enabled = false
		legacy_light.visible = false
		legacy_light.set_meta("retired_by_celestial_cycle", true)
		_legacy_light_retired_count += 1


func _body_defaults(kind: String) -> Dictionary:
	if kind == "moon":
		return {
			"rise_time": [18, 30],
			"transit_time": [0, 30],
			"set_time": [6, 30],
			"max_altitude_degrees": 42.0,
			"below_horizon_depth_degrees": 38.0,
			"max_energy": 0.40,
			"horizon_color": Color("#8798b5"),
			"zenith_color": Color("#c2d3ec"),
		}
	return {
		"rise_time": [5, 30],
		"transit_time": [12, 30],
		"set_time": [19, 30],
		"max_altitude_degrees": 52.0,
		"below_horizon_depth_degrees": 42.0,
		"max_energy": 1.65,
		"horizon_color": Color("#efa36c"),
		"zenith_color": Color("#dce8f6"),
	}


func _configured_time_seconds(value: Variant, fallback: Array) -> float:
	var raw_time := value as Array if value is Array else fallback
	if raw_time.size() < 2:
		raw_time = fallback
	return float(clampi(int(raw_time[0]), 0, 23) * 3600 + clampi(int(raw_time[1]), 0, 59) * 60)


func _seconds_from_time(hour: int, minute: int, second: int) -> float:
	return float(clampi(hour, 0, 23) * 3600 + clampi(minute, 0, 59) * 60 + clampi(second, 0, 59))


func _format_seconds(seconds_value: float) -> String:
	var wrapped := int(fposmod(seconds_value, SECONDS_PER_DAY))
	return "%02d:%02d" % [wrapped / 3600, (wrapped % 3600) / 60]


func _color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	return Color.from_string(str(value), fallback)


func _v3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO
