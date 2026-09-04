extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const TARGET := Vector3(100.0, 0.0, 100.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	for _index in range(8):
		await process_frame

	var controller := main.get_node_or_null("Presentation/AbilityAudioController")
	var audio_manager := root.get_node_or_null("AudioManager")
	var piety_system := main.get_node_or_null("Systems/PietySystem")
	var time_system := main.get_node_or_null("Systems/TimeSystem")
	var event_bus := root.get_node_or_null("EventBus")
	if [controller, audio_manager, piety_system, time_system, event_bus].has(null):
		_fail("P10H required Main nodes are missing")
		return

	var initial: Dictionary = controller.get_debug_snapshot()
	_assert(bool(initial.get("initialized", false)), "ability audio controller did not initialize")
	_assert(str(initial.get("schema_version", "")) == "ability_audio_v1", "wrong ability audio schema")
	_assert(bool(initial.get("cast_signal_connected", false)), "meteor cast signal is not connected")
	_assert(bool(initial.get("impact_signal_connected", false)), "meteor impact signal is not connected")
	_assert(audio_manager.has_asset("sfx_meteor_fall_one_shot"), "meteor fall asset is unavailable")
	_assert(audio_manager.has_asset("sfx_meteor_impact_one_shot"), "meteor impact asset is unavailable")

	time_system.set_paused(false)
	piety_system.debug_fill_piety()
	var cast: Dictionary = piety_system.request_meteor_cast(TARGET)
	_assert(bool(cast.get("ok", false)), "formal meteor cast failed")
	var cast_id := str(cast.get("cast_id", ""))
	await process_frame
	var after_cast: Dictionary = controller.get_debug_snapshot()
	_assert_phase(after_cast, cast_id, "fall", "sfx_meteor_fall_one_shot", 5.964)
	var fall: Dictionary = (after_cast.get("active_casts", {}) as Dictionary).get(cast_id, {}).get("fall", {})
	_assert(str(fall.get("source_path", "")).contains("PietyMeteor") and str(fall.get("source_path", "")).ends_with("Visual"), "fall audio did not attach to the actual meteor visual")
	var initial_source_position: Vector3 = fall.get("source_position", Vector3.ZERO)
	_assert(initial_source_position.y > TARGET.y + 20.0, "fall source did not begin above the target")

	var pending_before_pause: Dictionary = _pending_meteor(piety_system, cast_id)
	time_system.set_paused(true)
	await process_frame
	await process_frame
	var paused: Dictionary = controller.get_debug_snapshot()
	var paused_fall: Dictionary = (paused.get("active_casts", {}) as Dictionary).get(cast_id, {}).get("fall", {})
	_assert(bool(paused_fall.get("stream_paused", false)), "meteor fall sound did not pause with gameplay")
	var pending_after_pause: Dictionary = _pending_meteor(piety_system, cast_id)
	_assert(is_equal_approx(float(pending_before_pause.get("elapsed_seconds", -1.0)), float(pending_after_pause.get("elapsed_seconds", -2.0))), "meteor advanced while gameplay was paused")
	time_system.set_paused(false)
	await process_frame

	var duration := float(pending_after_pause.get("fall_duration_seconds", 2.8))
	piety_system.debug_advance_effects(duration * 0.5)
	await process_frame
	var midway: Dictionary = controller.get_debug_snapshot()
	var midway_fall: Dictionary = (midway.get("active_casts", {}) as Dictionary).get(cast_id, {}).get("fall", {})
	var midway_position: Vector3 = midway_fall.get("source_position", Vector3.ZERO)
	_assert(midway_position.distance_to(initial_source_position) > 1.0, "fall audio source did not follow the moving meteor")
	var visual := _find_meteor_visual(main, cast_id)
	_assert(visual != null and midway_position.is_equal_approx(visual.global_position), "fall audio source diverged from the actual meteor visual")

	piety_system.debug_advance_effects(duration * 0.5)
	await process_frame
	var after_impact: Dictionary = controller.get_debug_snapshot()
	_assert_phase(after_impact, cast_id, "impact", "sfx_meteor_impact_one_shot", 12.048)
	var active_cast: Dictionary = (after_impact.get("active_casts", {}) as Dictionary).get(cast_id, {})
	_assert(active_cast.has("fall"), "full fall one-shot was cut off at impact")
	var impact: Dictionary = active_cast.get("impact", {})
	_assert((impact.get("source_position", Vector3.ZERO) as Vector3).is_equal_approx(TARGET), "impact sound did not originate at the formal landing point")
	_assert(str(impact.get("bus", "")) == "World", "meteor impact did not route through World")
	var history_before_duplicate: Array = after_impact.get("recent_history", [])
	_assert(history_before_duplicate.size() == 2, "formal meteor timeline did not produce exactly fall plus impact audio")
	var authority_before_duplicate: Dictionary = piety_system.get_piety_snapshot().get("last_impact_result", {}).duplicate(true)
	event_bus.emit_signal("meteor_impacted", cast_id, authority_before_duplicate.duplicate(true))
	await process_frame
	var after_duplicate: Dictionary = controller.get_debug_snapshot()
	_assert((after_duplicate.get("recent_history", []) as Array).size() == history_before_duplicate.size(), "duplicate impact replayed the explosion")
	_assert(piety_system.get_piety_snapshot().get("last_impact_result", {}) == authority_before_duplicate, "audio handling changed PietySystem authority")

	audio_manager.stop_all_one_shots()
	main.queue_free()
	await process_frame
	await process_frame
	print("T0135_P10H_METEOR_AUDIO_PASS assets=2 signals=pass follow=pass pause=pass impact=pass authority=pass")
	quit(0)


func _assert_phase(snapshot: Dictionary, cast_id: String, phase: String, asset_id: String, expected_length: float) -> void:
	var active_casts: Dictionary = snapshot.get("active_casts", {})
	var cast: Dictionary = active_casts.get(cast_id, {})
	var phase_snapshot: Dictionary = cast.get(phase, {})
	_assert(not phase_snapshot.is_empty(), "%s audio phase is missing" % phase)
	_assert(str(phase_snapshot.get("asset_id", "")) == asset_id, "%s used the wrong asset" % phase)
	_assert(str(phase_snapshot.get("bus", "")) == "World", "%s did not route through World" % phase)
	_assert(bool(phase_snapshot.get("playing", false)), "%s asset is not playing as a full one-shot" % phase)
	_assert(absf(float(phase_snapshot.get("stream_length_seconds", 0.0)) - expected_length) < 0.02, "%s stream was clipped or replaced" % phase)


func _pending_meteor(piety_system: Node, cast_id: String) -> Dictionary:
	for raw_state in piety_system.get_piety_snapshot().get("pending_meteors", []):
		var state := raw_state as Dictionary
		if str(state.get("cast_id", "")) == cast_id:
			return state
	return {}


func _find_meteor_visual(main: Node, cast_id: String) -> Node3D:
	var effects := main.get_node_or_null("WorldRoot/Station/Effects")
	if effects == null:
		return null
	for child in effects.get_children():
		if child is Node3D and str(child.get_meta("cast_id", "")) == cast_id:
			return child as Node3D
	return null


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
