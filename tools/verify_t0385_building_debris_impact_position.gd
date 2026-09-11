extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const DEBRIS_VERTICAL_OFFSET := Vector3(0.0, 0.8, 0.0)

var _combat_events: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	for _frame in 5:
		await process_frame

	var building_system := main.get_node_or_null("Systems/BuildingSystem")
	var feedback_presenter := main.get_node_or_null("UI/WorldFeedbackPresenter")
	var vfx_controller := main.get_node_or_null("Presentation/CombatVFXController")
	var event_bus := root.get_node_or_null("EventBus")
	if [building_system, feedback_presenter, vfx_controller, event_bus].has(null):
		_fail("T0385 required runtime nodes are missing")
		return
	if not event_bus.combat_audio_event.is_connected(_on_combat_event):
		event_bus.combat_audio_event.connect(_on_combat_event)

	var hit_positions := {
		"front_gate": Vector3(4.6, 0.0, 52.3),
		"warehouse": Vector3(29.4, 0.0, 20.0),
		"main_hall": Vector3(0.0, 0.0, 0.7),
	}
	for raw_building_id in hit_positions.keys():
		var building_id := str(raw_building_id)
		var hit_position: Vector3 = hit_positions[building_id]
		_combat_events.clear()
		vfx_controller.debug_clear_effects()
		await process_frame

		var damage_result: Dictionary = building_system.apply_damage_to_building(
			building_id,
			1,
			"verify_t0385",
			"private",
			{"hit_world_position": hit_position}
		)
		if int(damage_result.get("hp_before", 0)) - int(damage_result.get("hp_after", 0)) != 1:
			_fail("T0385 could not commit prepared damage for %s" % building_id)
			return

		var event := _find_structure_event(building_id)
		if event.is_empty() or not _same_position(event.get("impact_world_position", null), hit_position):
			_fail("%s structure event did not preserve its real hit position" % building_id)
			return

		var feedback_anchor: Variant = building_system.get_building_feedback_anchor_position(building_id)
		var feedback_group := _find_feedback_group(
			feedback_presenter.debug_get_snapshot(),
			"building:%s" % building_id,
			"damage"
		)
		if not feedback_anchor is Vector3 or not _same_position(
			feedback_group.get("fallback_world_position", null),
			feedback_anchor
		):
			_fail("%s HP feedback no longer uses the existing readable top anchor" % building_id)
			return
		if not _same_position(event.get("world_position", null), feedback_anchor):
			_fail("%s legacy feedback/audio position changed while splitting the debris hit point" % building_id)
			return

		var debris := _find_debris_particles(main)
		if debris == null or debris.global_position.distance_to(hit_position + DEBRIS_VERTICAL_OFFSET) > 0.001:
			_fail("%s debris particles were not spawned at the hit point" % building_id)
			return

	_combat_events.clear()
	await process_frame
	var fallback_position: Variant = building_system.get_building_entry_position("main_hall")
	building_system.apply_damage_to_building("main_hall", 1, "verify_t0385", "private")
	var fallback_event := _find_structure_event("main_hall")
	if not fallback_position is Vector3 or not _same_position(
		fallback_event.get("impact_world_position", null),
		fallback_position
	):
		_fail("Building damage without a collision point did not fall back to the ground-level entry")
		return
	var main_hall_feedback_anchor: Variant = building_system.get_building_feedback_anchor_position("main_hall")
	if (
		main_hall_feedback_anchor is Vector3
		and _same_position(fallback_event.get("impact_world_position", null), main_hall_feedback_anchor)
	):
		_fail("Building debris fallback reused the top HP feedback anchor")
		return

	if event_bus.combat_audio_event.is_connected(_on_combat_event):
		event_bus.combat_audio_event.disconnect(_on_combat_event)
	main.queue_free()
	await process_frame
	print("T0385_BUILDING_DEBRIS_IMPACT_POSITION PASS")
	quit(0)


func _on_combat_event(event: Dictionary) -> void:
	_combat_events.append(event.duplicate(true))


func _find_structure_event(building_id: String) -> Dictionary:
	for index in range(_combat_events.size() - 1, -1, -1):
		var event: Dictionary = _combat_events[index]
		if (
			str(event.get("event_type", "")) == "structure_damaged"
			and str(event.get("target_type", "")) == "building"
			and str(event.get("target_id", "")) == building_id
		):
			return event
	return {}


func _find_feedback_group(groups: Array, anchor_key: String, channel: String) -> Dictionary:
	for raw_group in groups:
		if not raw_group is Dictionary:
			continue
		var group: Dictionary = raw_group
		if str(group.get("anchor_key", "")) == anchor_key and str(group.get("channel", "")) == channel:
			return group
	return {}


func _find_debris_particles(main: Node) -> GPUParticles3D:
	var effect_root := main.get_node_or_null("WorldRoot/FormalStationLayout/CombatVFX")
	if effect_root == null:
		return null
	for raw_child in effect_root.get_children():
		if raw_child is GPUParticles3D and str(raw_child.name) == "DebrisParticles":
			return raw_child as GPUParticles3D
	return null


func _same_position(raw_position: Variant, expected: Vector3) -> bool:
	return raw_position is Vector3 and (raw_position as Vector3).distance_to(expected) <= 0.001


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
