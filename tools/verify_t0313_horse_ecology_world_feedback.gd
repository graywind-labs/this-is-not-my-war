extends SceneTree

const EPSILON := 0.0001


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var presenter := root.get_node_or_null("Main/UI/WorldFeedbackPresenter")
	if [horse_system, resource_system, time_system, presenter].has(null):
		_fail("T0313 required systems or presenter not found")
		return
	var horse_ids: Array[String] = horse_system.get_horse_ids()
	if horse_ids.size() < 2:
		_fail("T0313 requires two independently anchored initial horses")
		return
	var first_id := horse_ids[0]
	var second_id := horse_ids[1]

	if not _verify_atomic_feeding(horse_system, resource_system, presenter, first_id, second_id):
		return
	if not _verify_natural_recovery_aggregation(horse_system, presenter, first_id, second_id):
		return
	if not _verify_care_and_multi_horse_aggregation(horse_system, presenter, first_id, second_id):
		return
	if not _verify_breeding_probability_aggregation(horse_system, presenter, first_id, second_id):
		return
	if not await _verify_pause_does_not_advance(time_system, horse_system, presenter, first_id):
		return

	for _frame in 8:
		await process_frame
	main.queue_free()
	for _frame in 3:
		await process_frame
		await physics_frame
	print("T0313 horse ecology world feedback verification passed.")
	quit(0)


func _verify_atomic_feeding(
	horse_system: Node,
	resource_system: Node,
	presenter: Node,
	first_id: String,
	second_id: String
) -> bool:
	presenter.debug_advance_feedback(2.1)
	horse_system._world_feedback_accumulators.clear()
	_set_horse_runtime(horse_system, first_id, {
		"location": "stable",
		"growth": 0.6,
		"hp": 76.0,
		"care_bonus_hp": 0.0,
		"satiety": 50.0,
		"feeding": {"active": true, "elapsed_seconds": 1140.0, "waiting_for_grain": false},
	})
	_set_horse_runtime(horse_system, second_id, {
		"location": "stable",
		"growth": 0.6,
		"hp": 76.0,
		"care_bonus_hp": 0.0,
		"satiety": 80.0,
		"feeding": {"active": false, "elapsed_seconds": 0.0, "waiting_for_grain": false},
	})
	var grain_before := int(resource_system.get_resource("grain"))
	if grain_before < 1:
		resource_system.add_resource("grain", 1)
		grain_before = int(resource_system.get_resource("grain"))
	horse_system.debug_advance(60.0)
	var fed_horse: Dictionary = horse_system.get_horse_snapshot(first_id)
	if int(resource_system.get_resource("grain")) != grain_before - 1:
		return _fail("Completed feeding did not atomically spend one grain")
	if absf(float(fed_horse.get("satiety", 0.0)) - 80.0) > EPSILON:
		return _fail("Completed feeding did not clamp satiety to the horse's actual maximum")
	var feeding_group := _find_group(presenter, "horse:%s" % first_id, "horse_feeding")
	if not _has_entry(feeding_group, "粮食", "consume", -1):
		return _fail("Feeding feedback did not include the gray grain spend")
	var restored_amount := _get_entry_amount(feeding_group, "饱食", "neutral")
	if restored_amount <= 30.0 or restored_amount > 35.0:
		return _fail("Feeding feedback did not report the clamped actual satiety gain")
	if not is_equal_approx(float(feeding_group.get("anchor_height", 0.0)), 2.75):
		return _fail("Horse feedback anchor does not clear the existing 2.15m name label")

	presenter.debug_advance_feedback(2.1)
	var remaining_grain := int(resource_system.get_resource("grain"))
	resource_system.add_resource("grain", -remaining_grain)
	_set_horse_runtime(horse_system, first_id, {
		"hp": 76.0,
		"satiety": 40.0,
		"feeding": {"active": false, "elapsed_seconds": 1200.0, "waiting_for_grain": true},
	})
	horse_system.debug_advance(60.0)
	if int(resource_system.get_resource("grain")) != 0:
		return _fail("Insufficient-grain feeding changed the inventory")
	if not _find_group(presenter, "horse:%s" % first_id, "horse_feeding").is_empty():
		return _fail("Insufficient-grain feeding fabricated a success feedback group")
	resource_system.add_resource("grain", grain_before)
	return true


func _verify_natural_recovery_aggregation(
	horse_system: Node,
	presenter: Node,
	first_id: String,
	second_id: String
) -> bool:
	presenter.debug_advance_feedback(2.1)
	horse_system._world_feedback_accumulators.clear()
	_set_horse_runtime(horse_system, first_id, {
		"location": "ridden",
		"growth": 0.6,
		"hp": 70.0,
		"care_bonus_hp": 0.0,
		"satiety": 60.0,
		"feeding": {"active": false, "elapsed_seconds": 0.0, "waiting_for_grain": false},
	})
	_set_horse_runtime(horse_system, second_id, {
		"location": "stable",
		"growth": 0.6,
		"hp": 76.0,
		"care_bonus_hp": 0.0,
		"satiety": 80.0,
	})
	horse_system.debug_advance(4.0 * 3600.0)
	if not _find_group(presenter, "horse:%s" % first_id, "horse_ecology").is_empty():
		return _fail("Fractional natural recovery below one visible HP unit spammed feedback")
	horse_system.debug_advance(3600.0)
	var group := _find_group(presenter, "horse:%s" % first_id, "horse_ecology")
	if not _has_entry(group, "HP", "heal", 1):
		return _fail("Natural recovery did not aggregate to one green actual HP unit")
	if _has_entry(group, "饱食", "neutral", -1):
		return _fail("Sub-unit natural-healing satiety cost was displayed too early")
	horse_system.debug_advance(5.0 * 3600.0)
	group = _find_group(presenter, "horse:%s" % first_id, "horse_ecology")
	if not _has_entry(group, "HP", "heal", 1) or not _has_entry(group, "饱食", "neutral", -1):
		return _fail("Natural recovery did not group actual HP and accumulated satiety cost")
	if _count_groups(presenter, "horse:%s" % first_id, "horse_ecology") != 1:
		return _fail("A high-speed ecology advance stacked duplicate groups for one horse")
	return true


func _verify_care_and_multi_horse_aggregation(
	horse_system: Node,
	presenter: Node,
	first_id: String,
	second_id: String
) -> bool:
	presenter.debug_advance_feedback(2.1)
	horse_system._world_feedback_accumulators.clear()
	for horse_id in [first_id, second_id]:
		_set_horse_runtime(horse_system, horse_id, {
			"location": "stable",
			"growth": 0.6,
			"hp": 76.0,
			"care_bonus_hp": 0.0,
			"care_bonus_cap": 0.0,
			"breeding_probability": 0.0,
			"breeding_cooldown_remaining_seconds": 0.0,
		})
	var changed := {}
	var caretaker := {"active": true, "skill": 100.0, "level_factor": 1.0}
	horse_system._advance_care(11.0 * 60.0, caretaker, changed)
	horse_system._flush_world_feedback_accumulators()
	for horse_id in [first_id, second_id]:
		var group := _find_group(presenter, "horse:%s" % horse_id, "horse_ecology")
		if not _has_entry(group, "成长", "neutral", 0.1):
			return _fail("Care growth did not aggregate independently to 0.1% for horse %s" % horse_id)
	if _count_channel_groups(presenter, "horse_ecology") != 2:
		return _fail("Two cared horses did not keep independent world anchors")

	presenter.debug_advance_feedback(2.1)
	horse_system._world_feedback_accumulators.clear()
	_set_horse_runtime(horse_system, first_id, {
		"location": "stable", "growth": 0.6, "hp": 76.0,
		"care_bonus_hp": 0.0, "care_bonus_cap": 0.0,
	})
	_set_horse_runtime(horse_system, second_id, {"location": "ridden"})
	changed.clear()
	horse_system._advance_care(504.0 * 60.0, caretaker, changed)
	horse_system._flush_world_feedback_accumulators()
	var care_group := _find_group(presenter, "horse:%s" % first_id, "horse_ecology")
	if not _has_entry(care_group, "HP", "heal", 3):
		return _fail("Growth-driven actual HP gain did not use green feedback")
	if not _has_entry(care_group, "额外HP", "heal", 1):
		return _fail("Care bonus HP did not aggregate to one green actual unit")
	if not _find_group(presenter, "horse:%s" % second_id, "horse_ecology").is_empty():
		return _fail("A horse outside the stable received care feedback")
	return true


func _verify_breeding_probability_aggregation(
	horse_system: Node,
	presenter: Node,
	first_id: String,
	second_id: String
) -> bool:
	presenter.debug_advance_feedback(2.1)
	horse_system._world_feedback_accumulators.clear()
	for horse_id in [first_id, second_id]:
		_set_horse_runtime(horse_system, horse_id, {
			"location": "stable",
			"growth": 0.6,
			"breeding_probability": 0.0,
			"breeding_cooldown_remaining_seconds": 0.0,
		})
	horse_system._rng.seed = 20260901
	var changed := {}
	var caretaker := {"active": true, "skill": 100.0, "level_factor": 1.0}
	for _minute in 20:
		horse_system._roll_births_for_minute(caretaker, changed)
	if int(horse_system.get_horse_count()) != 2:
		return _fail("Deterministic breeding aggregation setup unexpectedly produced a foal")
	horse_system._flush_world_feedback_accumulators()
	for horse_id in [first_id, second_id]:
		var group := _find_group(presenter, "horse:%s" % horse_id, "horse_ecology")
		if not _has_entry(group, "繁育概率", "neutral", 0.1):
			return _fail("Breeding probability did not aggregate independently to 0.1%")

	presenter.debug_advance_feedback(2.1)
	horse_system._world_feedback_accumulators.clear()
	horse_system._record_world_feedback_delta(first_id, "breeding_probability", 0.0009)
	var parent_ids: Array[String] = [first_id, second_id]
	horse_system._start_birth_cooldown(parent_ids, {})
	horse_system._flush_world_feedback_accumulators()
	if not _find_group(presenter, "horse:%s" % first_id, "horse_ecology").is_empty():
		return _fail("Breeding reset leaked stale pre-birth probability feedback")
	return true


func _verify_pause_does_not_advance(
	time_system: Node,
	horse_system: Node,
	presenter: Node,
	horse_id: String
) -> bool:
	presenter.debug_advance_feedback(2.1)
	horse_system._world_feedback_accumulators.clear()
	_set_horse_runtime(horse_system, horse_id, {
		"location": "ridden", "growth": 0.6, "hp": 70.0, "satiety": 60.0,
		"breeding_cooldown_remaining_seconds": 0.0,
	})
	time_system.set_paused(true)
	var before: Dictionary = horse_system.get_horse_snapshot(horse_id)
	for _frame in 12:
		await process_frame
	var after: Dictionary = horse_system.get_horse_snapshot(horse_id)
	if not is_equal_approx(float(before.get("hp", 0.0)), float(after.get("hp", 0.0))):
		return _fail("Paused gameplay advanced horse natural recovery")
	if not is_equal_approx(float(before.get("satiety", 0.0)), float(after.get("satiety", 0.0))):
		return _fail("Paused gameplay advanced horse satiety")
	if not presenter.debug_get_snapshot().is_empty():
		return _fail("Paused gameplay generated horse ecology feedback")
	return true


func _set_horse_runtime(horse_system: Node, horse_id: String, updates: Dictionary) -> void:
	var horse: Dictionary = horse_system._horses.get(horse_id, {}).duplicate(true)
	for key in updates.keys():
		horse[key] = updates[key]
	horse_system._horses[horse_id] = horse


func _find_group(presenter: Node, anchor_key: String, channel: String) -> Dictionary:
	for raw_group in presenter.debug_get_snapshot():
		if raw_group is Dictionary and str(raw_group.get("anchor_key", "")) == anchor_key and str(raw_group.get("channel", "")) == channel:
			return raw_group
	return {}


func _count_groups(presenter: Node, anchor_key: String, channel: String) -> int:
	var count := 0
	for raw_group in presenter.debug_get_snapshot():
		if raw_group is Dictionary and str(raw_group.get("anchor_key", "")) == anchor_key and str(raw_group.get("channel", "")) == channel:
			count += 1
	return count


func _count_channel_groups(presenter: Node, channel: String) -> int:
	var count := 0
	for raw_group in presenter.debug_get_snapshot():
		if raw_group is Dictionary and str(raw_group.get("channel", "")) == channel:
			count += 1
	return count


func _has_entry(group: Dictionary, display_name: String, color_role: String, amount: Variant) -> bool:
	return is_equal_approx(_get_entry_amount(group, display_name, color_role), float(amount))


func _get_entry_amount(group: Dictionary, display_name: String, color_role: String) -> float:
	for raw_entry in group.get("entries", []):
		if not raw_entry is Dictionary:
			continue
		if str(raw_entry.get("display_name", "")) == display_name and str(raw_entry.get("color_role", "")) == color_role:
			return float(raw_entry.get("amount", NAN))
	return NAN


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
