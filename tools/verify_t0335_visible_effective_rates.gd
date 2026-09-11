extends SceneTree


const MAIN_SCENE := "res://scenes/main/Main.tscn"
const HORSE_ID := "horse_chestnut_wind"
const CARETAKER_ID := "stableman_01"
const WEAKER_CARETAKER_ID := "cook_01"
const TARGET_ID := "cook_01"
const HEALER_ID := "doctor_01"
const SECOND_HEALER_ID := "engineer_01"
const RATE_GREEN := "69c879ff"
const RateFormatter = preload("res://scripts/ui/RateDisplayFormatter.gd")

var _failures: Array[String] = []


func _init() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	check(packed != null, "Main.tscn could not be loaded")
	if packed == null:
		finish()
		return
	root.add_child(packed.instantiate())
	for _frame in 8:
		await physics_frame
		await process_frame

	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel") as Control
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel") as Control
	check(
		horse_system != null and npc_system != null and action_system != null and time_system != null
		and building_panel != null and npc_panel != null,
		"T0335 runtime dependencies are missing"
	)
	if not _failures.is_empty():
		finish()
		return
	time_system.set_paused(true)

	check(RateFormatter.format_positive_rate(0.02 / 60.0) == "+0.02/min", "Minute rate formatting mismatch")
	check(RateFormatter.format_positive_rate(0.005 / 60.0) == "+0.3/h", "Small rate did not switch to game hours")

	var no_care: Dictionary = horse_system.get_horse_care_rate_snapshot(HORSE_ID)
	check(not bool(no_care.get("active", false)), "Horse care rate appeared without an active caretaker")
	building_panel.show_building("stable")
	await process_frame
	check(building_panel.find_child("HorseGrowth_%sRateLabel" % HORSE_ID, true, false) == null, "Stable UI showed a care rate without a caretaker")

	_set_skill(npc_system, CARETAKER_ID, 80)
	_set_skill(npc_system, WEAKER_CARETAKER_ID, 10)
	npc_system.update_npc_state(CARETAKER_ID, {"current_location": "stable", "unconscious": false, "escaped": false, "behavior_mode": "work"})
	action_system._active_actions[CARETAKER_ID] = {"kind": "work_stable"}
	var care: Dictionary = horse_system.get_horse_care_rate_snapshot(HORSE_ID)
	var care_rates: Dictionary = care.get("rates_per_game_second", {})
	check(bool(care.get("active", false)), "Active stable caretaker did not expose care rates")
	for field in ["base_hp", "extra_hp", "growth", "breeding_probability"]:
		check(float(care_rates.get(field, 0.0)) > 0.0, "Missing active horse care rate: %s" % field)
	check(not care_rates.has("satiety"), "Horse care rate incorrectly included satiety")

	var rate_before_weaker := float(care_rates.get("growth", 0.0))
	npc_system.update_npc_state(WEAKER_CARETAKER_ID, {"current_location": "stable", "unconscious": false, "escaped": false, "behavior_mode": "work"})
	action_system._active_actions[WEAKER_CARETAKER_ID] = {"kind": "work_stable"}
	var with_weaker: Dictionary = horse_system.get_horse_care_rate_snapshot(HORSE_ID)
	check(
		is_equal_approx(float((with_weaker.get("rates_per_game_second", {}) as Dictionary).get("growth", 0.0)), rate_before_weaker),
		"Weaker caretaker incorrectly stacked on the highest-skill care rate"
	)

	building_panel.call("_refresh_horse_section")
	await process_frame
	for control_name in ["HorseBaseHP", "HorseExtraHP", "HorseGrowth", "HorseBreedingProbability"]:
		var rate_label := building_panel.find_child("%s_%sRateLabel" % [control_name, HORSE_ID], true, false) as Label
		check(rate_label != null and rate_label.text.begins_with("+") and rate_label.text.contains("/"), "Stable UI rate label missing: %s" % control_name)
		if rate_label != null:
			check(rate_label.get_theme_color("font_color").to_html(true) == RATE_GREEN, "Stable UI rate is not green: %s" % control_name)
	check(building_panel.find_child("HorseSatiety_%sRateLabel" % HORSE_ID, true, false) == null, "Stable UI incorrectly displayed a satiety care rate")

	var horses: Dictionary = horse_system._horses
	var horse: Dictionary = horses.get(HORSE_ID, {})
	horse["growth"] = 1.0
	horse["care_bonus_cap"] = 16.0
	horse["care_bonus_hp"] = 16.0
	horse["hp"] = 116.0
	horse["breeding_probability"] = 1.0
	var capped: Dictionary = horse_system.get_horse_care_rate_snapshot(HORSE_ID)
	check((capped.get("rates_per_game_second", {}) as Dictionary).is_empty(), "Capped horse fields still exposed care rates")
	building_panel.call("_refresh_horse_section")
	await process_frame
	check(building_panel.find_child("HorseGrowth_%sRateLabel" % HORSE_ID, true, false) == null, "Capped stable field still showed a rate")
	action_system._active_actions.erase(CARETAKER_ID)
	action_system._active_actions.erase(WEAKER_CARETAKER_ID)

	var damage: Dictionary = npc_system.debug_damage_npc(TARGET_ID, 999, "private")
	check(bool(damage.get("ok", false)) and bool(npc_system.get_npc_state(TARGET_ID).get("unconscious", false)), "Failed to create unconscious healing target")
	await process_frame
	await process_frame
	npc_system.debug_select_npc(TARGET_ID)
	await process_frame
	await process_frame
	var hp_rate_label := npc_panel.find_child("NPCHPRecoveryRateLabel", true, false) as Label
	check(hp_rate_label != null and not hp_rate_label.visible, "NPCPanel recovery rate appeared before assistance became active")

	action_system._healing_helpers_by_target[TARGET_ID] = [HEALER_ID]
	action_system._active_actions[HEALER_ID] = {"kind": "assist_heal", "target_npc_id": TARGET_ID, "medical_skill": 80}
	action_system._notify_healing_rate_changed(TARGET_ID)
	await process_frame
	var one_healer: Dictionary = action_system.get_healing_assist_rate_snapshot(TARGET_ID)
	check(bool(one_healer.get("active", false)) and float(one_healer.get("hp_per_game_hour", 0.0)) > 0.0, "One active healer did not expose recovery rate")
	check(hp_rate_label != null and hp_rate_label.visible, "NPCPanel did not refresh immediately when assistance became active")

	npc_system.debug_start_work_encouragement_boost(HEALER_ID)
	var boosted: Dictionary = action_system.get_healing_assist_rate_snapshot(TARGET_ID)
	check(float(boosted.get("hp_per_game_hour", 0.0)) > float(one_healer.get("hp_per_game_hour", 0.0)), "Current work multiplier did not affect healing rate")
	action_system._healing_helpers_by_target[TARGET_ID] = [HEALER_ID, SECOND_HEALER_ID]
	action_system._active_actions[SECOND_HEALER_ID] = {"kind": "assist_heal", "target_npc_id": TARGET_ID, "medical_skill": 25}
	action_system._notify_healing_rate_changed(TARGET_ID)
	await process_frame
	var two_healers: Dictionary = action_system.get_healing_assist_rate_snapshot(TARGET_ID)
	check(float(two_healers.get("hp_per_game_hour", 0.0)) > float(boosted.get("hp_per_game_hour", 0.0)), "Second active healer did not increase actual recovery rate")

	var visible_rate: Dictionary = action_system.get_healing_assist_rate_snapshot(TARGET_ID)
	check(
		hp_rate_label != null and hp_rate_label.visible and hp_rate_label.text.begins_with("+") and hp_rate_label.text.contains("/"),
		"NPCPanel HP recovery rate is missing: label=%s visible=%s text=%s rate=%s" % [
			str(hp_rate_label),
			str(hp_rate_label.visible if hp_rate_label != null else false),
			hp_rate_label.text if hp_rate_label != null else "<missing>",
			JSON.stringify({"before": two_healers, "after": visible_rate, "state": npc_system.get_npc_state(TARGET_ID)}),
		]
	)
	if hp_rate_label != null:
		check(hp_rate_label.get_theme_color("font_color").to_html(true) == RATE_GREEN, "NPCPanel HP recovery rate is not green")

	action_system._active_actions.erase(HEALER_ID)
	action_system._active_actions.erase(SECOND_HEALER_ID)
	action_system._notify_healing_rate_changed(TARGET_ID)
	await process_frame
	var stopped: Dictionary = action_system.get_healing_assist_rate_snapshot(TARGET_ID)
	check(not bool(stopped.get("active", false)), "Stopped or pending healers still contributed a recovery rate")
	check(hp_rate_label != null and not hp_rate_label.visible, "NPCPanel recovery rate did not hide immediately after assistance stopped")

	finish()


func _set_skill(npc_system: Node, npc_id: String, value: int) -> void:
	var profile: Dictionary = npc_system._profiles.get(npc_id, {})
	var skills: Dictionary = profile.get("skills", {}).duplicate(true)
	skills["养马"] = value
	profile["skills"] = skills
	npc_system._profiles[npc_id] = profile


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func finish() -> void:
	if _failures.is_empty():
		print("T0335_VISIBLE_EFFECTIVE_RATES PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0335_VISIBLE_EFFECTIVE_RATES FAIL count=%d" % _failures.size())
	quit(1)
