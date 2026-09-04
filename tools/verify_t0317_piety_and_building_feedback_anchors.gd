extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame in 3:
		await process_frame
		await physics_frame

	var piety_system := root.get_node_or_null("Main/Systems/PietySystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var presenter := root.get_node_or_null("Main/UI/WorldFeedbackPresenter")
	if [piety_system, building_system, presenter].has(null):
		_fail("T0317 required systems or presenter not found")
		return

	if not _verify_piety_feedback(piety_system, presenter):
		return
	if not _verify_building_feedback_anchors(building_system, presenter):
		return

	main.queue_free()
	for _frame in 3:
		await process_frame
	print("T0317 piety and building feedback anchor verification passed.")
	quit(0)


func _verify_piety_feedback(piety_system: Node, presenter: Node) -> bool:
	var priest_id := "priest_01"
	var half_point: Dictionary = piety_system.add_prayer_progress(
		priest_id,
		"pray_at_chapel",
		720.0,
		"personal_prayer"
	)
	if not is_equal_approx(float(half_point.get("added", 0.0)), 0.5):
		return _fail("Prepared half-point prayer did not add the configured actual piety")
	if not presenter.debug_get_snapshot().is_empty():
		return _fail("Sub-integer piety fabricated a decimal world feedback")

	var completed_point: Dictionary = piety_system.add_prayer_progress(
		priest_id,
		"pray_at_chapel",
		720.0,
		"personal_prayer"
	)
	if not is_equal_approx(float(completed_point.get("added", 0.0)), 0.5):
		return _fail("Second half-point prayer did not add actual piety")
	var priest_group := _find_group(presenter, "npc:%s" % priest_id, "piety")
	if not _has_piety_entry(priest_group, 1):
		return _fail("Prayer did not render gold-role '虔诚 +1' at the contributor")

	presenter.debug_advance_feedback(2.1)
	var participant_id := "doctor_01"
	piety_system.add_prayer_progress(priest_id, "lead_mass", 720.0, "mass_leader")
	piety_system.add_prayer_progress(participant_id, "pray_at_chapel", 720.0, "mass_attendance")
	if not _has_piety_entry(_find_group(presenter, "npc:%s" % priest_id, "piety"), 1):
		return _fail("Mass leader did not receive their own piety feedback")
	if not _has_piety_entry(_find_group(presenter, "npc:%s" % participant_id, "piety"), 1):
		return _fail("Mass participant piety was not anchored to that participant")
	if _count_groups(presenter.debug_get_snapshot(), "piety") != 2:
		return _fail("Mass piety feedback did not remain one group per contributor")

	presenter.debug_advance_feedback(2.1)
	piety_system.debug_fill_piety()
	piety_system.add_prayer_progress(priest_id, "pray_at_chapel", 1200.0, "solo")
	if not presenter.debug_get_snapshot().is_empty():
		return _fail("Full piety fabricated a zero-effective gain feedback")

	piety_system.debug_set_piety(0.0)
	piety_system.add_prayer_progress(priest_id, "pray_at_chapel", 600.0, "solo")
	piety_system.debug_fill_piety()
	var cast_result: Dictionary = piety_system.request_meteor_cast(Vector3(100.0, 0.0, 100.0))
	if not bool(cast_result.get("ok", false)):
		return _fail("Prepared meteor cast failed while checking piety feedback remainder reset")
	piety_system.add_prayer_progress(priest_id, "pray_at_chapel", 600.0, "solo")
	if not presenter.debug_get_snapshot().is_empty():
		return _fail("Pre-cast fractional piety feedback leaked into the next charge")
	return true


func _verify_building_feedback_anchors(building_system: Node, presenter: Node) -> bool:
	var expected_centers := {
		"front_gate": Vector2(5.0, 54.0),
		"warehouse": Vector2(35.0, 20.0),
		"main_hall": Vector2(0.0, -8.0)
	}
	for raw_building_id in expected_centers.keys():
		var building_id := str(raw_building_id)
		var anchor: Variant = building_system.get_building_feedback_anchor_position(building_id)
		if not anchor is Vector3:
			return _fail("Formal feedback anchor missing for %s" % building_id)
		var center: Vector2 = expected_centers[building_id]
		if Vector2(anchor.x, anchor.z).distance_to(center) > 0.25 or anchor.y <= 5.0:
			return _fail("Formal feedback anchor is not above the correct %s entity" % building_id)

		var first_hit := Vector3(-90.0, 1.0, -90.0)
		var first: Dictionary = building_system.apply_damage_to_building(
			building_id,
			1,
			"verify_t0317",
			"private",
			{"hit_world_position": first_hit}
		)
		if int(first.get("hp_before", 0)) - int(first.get("hp_after", 0)) != 1:
			return _fail("Prepared building damage did not commit for %s" % building_id)
		var group := _find_group(presenter, "building:%s" % building_id, "damage")
		if not _same_position(group.get("fallback_world_position", null), anchor):
			return _fail("%s damage still used the supplied wall/legacy position" % building_id)
		if not bool(group.get("prefer_fallback_position", false)) or not is_zero_approx(float(group.get("anchor_height", -1.0))):
			return _fail("%s feedback did not use its complete formal anchor position" % building_id)

		var second_hit := Vector3(90.0, 3.0, 90.0)
		building_system.apply_damage_to_building(
			building_id,
			1,
			"verify_t0317",
			"private",
			{"hit_world_position": second_hit}
		)
		if _count_anchor_channel(presenter.debug_get_snapshot(), "building:%s" % building_id, "damage") != 1:
			return _fail("A new %s hit did not replace the prior damage group" % building_id)
		group = _find_group(presenter, "building:%s" % building_id, "damage")
		if not _same_position(group.get("fallback_world_position", null), anchor):
			return _fail("%s changed feedback position between different hit points" % building_id)

		presenter.debug_advance_feedback(2.1)
		if not building_system.restore_building_hp(building_id, 2):
			return _fail("Prepared building restoration failed for %s" % building_id)
		var healing_group := _find_group(presenter, "building:%s" % building_id, "healing")
		if not _same_position(healing_group.get("fallback_world_position", null), anchor):
			return _fail("%s healing did not reuse the same formal anchor" % building_id)
		presenter.debug_advance_feedback(2.1)
	return true


func _has_piety_entry(group: Dictionary, amount: int) -> bool:
	for raw_entry in group.get("entries", []):
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		if (
			str(entry.get("display_name", "")) == "虔诚"
			and str(entry.get("color_role", "")) == "piety"
			and int(entry.get("amount", 0)) == amount
			and str(entry.get("text", "")) == "虔诚 +%d" % amount
		):
			return true
	return false


func _find_group(presenter: Node, anchor_key: String, channel: String) -> Dictionary:
	for raw_group in presenter.debug_get_snapshot():
		if raw_group is Dictionary and str(raw_group.get("anchor_key", "")) == anchor_key and str(raw_group.get("channel", "")) == channel:
			return raw_group
	return {}


func _count_groups(groups: Array, channel: String) -> int:
	var count := 0
	for raw_group in groups:
		if raw_group is Dictionary and str(raw_group.get("channel", "")) == channel:
			count += 1
	return count


func _count_anchor_channel(groups: Array, anchor_key: String, channel: String) -> int:
	var count := 0
	for raw_group in groups:
		if raw_group is Dictionary and str(raw_group.get("anchor_key", "")) == anchor_key and str(raw_group.get("channel", "")) == channel:
			count += 1
	return count


func _same_position(left: Variant, right: Variant) -> bool:
	return left is Vector3 and right is Vector3 and (left as Vector3).distance_to(right as Vector3) <= 0.001


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
