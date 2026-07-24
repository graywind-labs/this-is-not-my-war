extends SceneTree

const EPSILON := 0.0001


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	root.add_child(main_scene.instantiate())
	await process_frame
	await physics_frame

	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel")
	if horse_system == null or npc_system == null or action_system == null or building_panel == null:
		_fail("Required horse-care feedback nodes are missing")
		return

	var horse_ids: Array = horse_system.get_horse_ids()
	if horse_ids.size() != 2:
		_fail("A new game must start with exactly two horses")
		return
	var first_id := str(horse_ids[0])
	var second_id := str(horse_ids[1])
	var first: Dictionary = horse_system.get_horse_snapshot(first_id)
	var second: Dictionary = horse_system.get_horse_snapshot(second_id)
	for horse in [first, second]:
		if not bool(horse.get("is_adult", false)) or absf(float(horse.get("growth", -1.0)) - 0.6) > EPSILON:
			_fail("Initial horses must start exactly at the adult growth threshold")
			return
		if absf(float(horse.get("natural_max_hp", -1.0)) - 76.0) > EPSILON:
			_fail("A 60% grown horse must expose 76 natural max HP")
			return
		if absf(float(horse.get("base_hp", -1.0)) - 76.0) > EPSILON:
			_fail("Initial base HP must be split from care bonus HP")
			return
		if float(horse.get("extra_hp", -1.0)) != 0.0 or float(horse.get("extra_hp_cap", -1.0)) != 0.0:
			_fail("Initial care bonus HP must start at zero")
			return
		if float(horse.get("breeding_probability", -1.0)) != 0.0:
			_fail("Initial breeding probability must start at zero")
			return
		if bool(horse.get("breeding_cooldown_active", true)):
			_fail("Initial horses must not start in breeding cooldown")
			return

	building_panel.show_building("stable")
	await process_frame
	await process_frame
	if not _assert_horse_card_controls(building_panel, first_id, false):
		return

	var stableman_id := "stableman_01"
	npc_system.debug_enter_location_immediately(stableman_id, "stable")
	npc_system.update_npc_state(stableman_id, {"satiety": 90, "fatigue": 0})
	if not action_system.debug_assign_work(stableman_id, "stable"):
		_fail("Could not assign stable work")
		return
	if not await _wait_until_current_action(npc_system, stableman_id, "work_stable"):
		_fail("Stable caretaker never entered active work")
		return

	horse_system._rng.seed = 20260723
	var balance: Dictionary = horse_system.get_balance_snapshot()
	var caretaker_skill := float(npc_system.get_npc(stableman_id).get("skills", {}).get("养马", 0))
	var expected_probability_gain := (
		float(balance.get("birth_probability_gain_per_care_minute", 0.0))
		* caretaker_skill
		/ 100.0
	)
	horse_system.debug_advance(60.0)
	first = horse_system.get_horse_snapshot(first_id)
	second = horse_system.get_horse_snapshot(second_id)
	if absf(float(first.get("breeding_probability", 0.0)) - expected_probability_gain) > EPSILON:
		_fail("Breeding probability did not grow by one effective care minute")
		return
	if absf(float(second.get("breeding_probability", 0.0)) - expected_probability_gain) > EPSILON:
		_fail("Each eligible adult horse must accumulate its own breeding probability")
		return
	if float(first.get("growth", 0.0)) <= 0.6:
		_fail("Initial just-adult horses must visibly retain growth room")
		return
	if float(first.get("extra_hp", 0.0)) <= 0.0 or float(first.get("extra_hp_cap", 0.0)) <= 0.0:
		_fail("Active care must cultivate separate care bonus HP")
		return

	await process_frame
	await process_frame
	if not _assert_horse_card_controls(building_panel, first_id, false):
		return

	_set_horse_breeding_state(horse_system, first_id, 1.0, 0.0)
	_set_horse_breeding_state(horse_system, second_id, 1.0, 0.0)
	var count_before_birth := int(horse_system.get_horse_count())
	horse_system.debug_advance(60.0)
	if int(horse_system.get_horse_count()) != count_before_birth + 1:
		_fail("A guaranteed accumulated breeding probability must produce one foal")
		return

	first = horse_system.get_horse_snapshot(first_id)
	second = horse_system.get_horse_snapshot(second_id)
	var cooldown_seconds := float(balance.get("birth_cooldown_minutes", 0.0)) * 60.0
	for horse in [first, second]:
		if float(horse.get("breeding_probability", -1.0)) != 0.0:
			_fail("Successful breeding must reset participating horse probability")
			return
		if absf(float(horse.get("breeding_cooldown_remaining_seconds", 0.0)) - cooldown_seconds) > EPSILON:
			_fail("Successful breeding must start the configured cooldown")
			return

	horse_system.debug_advance(600.0)
	first = horse_system.get_horse_snapshot(first_id)
	if float(first.get("breeding_probability", -1.0)) != 0.0:
		_fail("Breeding probability must stay frozen during cooldown")
		return
	if absf(float(first.get("breeding_cooldown_remaining_seconds", 0.0)) - (cooldown_seconds - 600.0)) > EPSILON:
		_fail("Breeding cooldown must count down with logical time")
		return

	await process_frame
	await process_frame
	if not _assert_horse_card_controls(building_panel, first_id, true):
		return

	action_system.interrupt_npc_action(stableman_id, "horse_feedback_verification_complete")
	print("T0056 horse care feedback verification passed.")
	quit(0)


func _assert_horse_card_controls(building_panel: Node, horse_id: String, expect_cooldown: bool) -> bool:
	var base_hp_label := building_panel.find_child("HorseBaseHP_%sLabel" % horse_id, true, false) as Label
	var extra_hp_label := building_panel.find_child("HorseExtraHP_%sLabel" % horse_id, true, false) as Label
	var growth_label := building_panel.find_child("HorseGrowth_%sLabel" % horse_id, true, false) as Label
	var breeding_label := building_panel.find_child("HorseBreedingProbability_%sLabel" % horse_id, true, false) as Label
	if base_hp_label == null or extra_hp_label == null or growth_label == null or breeding_label == null:
		_fail("Horse card is missing split HP, growth, or breeding probability controls")
		return false
	if not base_hp_label.text.begins_with("基础 HP "):
		_fail("Horse card must label base HP separately")
		return false
	if not extra_hp_label.text.begins_with("照料额外 HP "):
		_fail("Horse card must label care bonus HP separately")
		return false
	if not growth_label.text.begins_with("成长 "):
		_fail("Horse card must keep the growth display")
		return false
	if not breeding_label.text.begins_with("繁育概率 "):
		_fail("Horse card must display accumulated breeding probability")
		return false
	if expect_cooldown != breeding_label.text.contains("冷却"):
		_fail("Horse card breeding cooldown copy does not match runtime state: %s" % breeding_label.text)
		return false
	return true


func _set_horse_breeding_state(
	horse_system: Node,
	horse_id: String,
	probability: float,
	cooldown_seconds: float
) -> void:
	var horse: Dictionary = horse_system._horses.get(horse_id, {}).duplicate(true)
	horse["breeding_probability"] = probability
	horse["breeding_cooldown_remaining_seconds"] = cooldown_seconds
	horse_system._horses[horse_id] = horse


func _wait_until_current_action(npc_system: Node, npc_id: String, expected_action: String) -> bool:
	for _frame in range(600):
		await process_frame
		if str(npc_system.get_npc_state(npc_id).get("current_action", "")) == expected_action:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
