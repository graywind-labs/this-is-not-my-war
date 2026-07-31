extends SceneTree

const WORK_ACTION_IDS := [
	"work_garden",
	"work_dining_hall",
	"work_stable",
	"work_tavern",
	"work_blacksmith",
	"work_workshop",
	"work_training_instructor",
	"receive_weapon_training",
	"work_clinic_doctor",
	"assist_repair",
	"assist_upgrade",
	"assist_heal",
]
const REST_ACTION_IDS := [
	"drink_wine",
	"sleep_in_dormitory",
	"pray_at_chapel",
	"lead_mass",
	"receive_clinic_treatment",
]
const NO_EXPERIENCE_ACTION_IDS := [
	"talk_to_npc",
	"visit_location",
	"seek_guard_officer",
	"escaping_station",
	"escape_intervention_dialogue",
	"talk_to_guard_officer",
]


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var needs_system := root.get_node_or_null("Main/Systems/NPCNeedsSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	if action_system == null or needs_system == null or npc_system == null:
		_fail("Required systems not found")
		return
	if not action_system.get_action_definition_errors().is_empty():
		_fail("Action definitions have validation errors: %s" % action_system.get_action_definition_errors())
		return
	if not needs_system.get_definition_errors().is_empty():
		_fail("Needs definitions have validation errors: %s" % needs_system.get_definition_errors())
		return

	var action_ids: Array[String] = action_system.get_action_ids()
	if action_ids.size() != 24:
		_fail("Expected all 24 current action definitions, got %d" % action_ids.size())
		return
	var profile_ids: Array[String] = needs_system.get_profile_ids()
	for action_id in action_ids:
		var action: Dictionary = action_system.get_action(action_id)
		var profile_id := str(action.get("needs_profile", ""))
		if profile_id.is_empty() or not profile_ids.has(profile_id):
			_fail("Action %s does not resolve to exactly one valid needs profile" % action_id)
			return
		for legacy_key in ["satiety_delta", "fatigue_delta", "satiety_delta_per_hour", "fatigue_delta_per_hour"]:
			if action.has(legacy_key):
				_fail("Action %s still contains legacy needs field %s" % [action_id, legacy_key])
				return
		if not WORK_ACTION_IDS.has(action_id) and not (action.get("timed_experience", {}) as Dictionary).is_empty():
			_fail("Non-work action %s must not define timed work experience" % action_id)
			return

	for action_id in WORK_ACTION_IDS:
		if not action_ids.has(action_id):
			_fail("Work coverage list references missing action %s" % action_id)
			return
		var action: Dictionary = action_system.get_action(action_id)
		var action_type := str(action.get("type", ""))
		var profile: Dictionary = needs_system.get_profile(str(action.get("needs_profile", "")))
		if float(profile.get("satiety_per_hour", 0.0)) >= 0.0 or float(profile.get("fatigue_per_hour", 0.0)) <= 0.0:
			_fail("Work/training/assist action %s must consume satiety and add fatigue" % action_id)
			return
		if action_id.begins_with("assist_"):
			var timed_experience: Dictionary = action.get("timed_experience", {})
			if (
				timed_experience.is_empty()
				or str(timed_experience.get("skill", "")).is_empty()
				or float(timed_experience.get("interval_seconds", 0.0)) <= 0.0
				or int(timed_experience.get("amount", 0)) <= 0
			):
				_fail("Assist action %s must define time-based experience" % action_id)
				return
		elif action_type == "work":
			if str(action.get("skill", "")).is_empty():
				_fail("Profession work action %s must define its progression skill" % action_id)
				return
		elif action_type == "clinic_doctor":
			if (
				str(action.get("skill", "")).is_empty()
				or float(action.get("study_skill_interval_seconds", 0.0)) <= 0.0
				or float(action.get("treatment_skill_interval_seconds", 0.0)) <= 0.0
			):
				_fail("Clinic doctor action must define study and treatment progression")
				return
		elif action_type == "training_instructor":
			if (
				str(action.get("skill", "")).is_empty()
				or float(action.get("solo_skill_interval_seconds", 0.0)) <= 0.0
				or float(action.get("coaching_skill_interval_seconds", 0.0)) <= 0.0
			):
				_fail("Training instructor action must define solo and coaching progression")
				return
		elif action_type == "training_student":
			if float(action.get("student_skill_interval_seconds", 0.0)) <= 0.0:
				_fail("Training student action must define student progression")
				return
		else:
			_fail("Work coverage action %s has an unverified progression type %s" % [action_id, action_type])
			return

	for action_id in REST_ACTION_IDS:
		var action: Dictionary = action_system.get_action(action_id)
		var profile: Dictionary = needs_system.get_profile(str(action.get("needs_profile", "")))
		if float(profile.get("satiety_per_hour", 0.0)) >= 0.0 or float(profile.get("fatigue_per_hour", 0.0)) >= 0.0:
			_fail("Rest action %s must consume satiety and reduce fatigue" % action_id)
			return

	for action_id in NO_EXPERIENCE_ACTION_IDS:
		var action: Dictionary = action_system.get_action(action_id)
		if not (action.get("timed_experience", {}) as Dictionary).is_empty():
			_fail("Dialogue/movement/escape action %s must not grant work experience" % action_id)
			return

	var behavior_profiles: Dictionary = needs_system.get_behavior_mode_profiles()
	for mode in ["work", "rally", "combat", "avoid_combat", "unconscious", "escaped"]:
		if not behavior_profiles.has(mode):
			_fail("Behavior mode %s has no needs mapping" % mode)
			return
		if mode != "work" and not profile_ids.has(str(behavior_profiles.get(mode, ""))):
			_fail("Behavior mode %s maps to an unknown needs profile" % mode)
			return

	var light_work: Dictionary = needs_system.get_profile("light_work")
	var heavy_work: Dictionary = needs_system.get_profile("heavy_work")
	var idle: Dictionary = needs_system.get_profile("idle")
	var combat: Dictionary = needs_system.get_profile("combat")
	if float(light_work.get("satiety_per_hour", 0.0)) != -3.0 or float(light_work.get("fatigue_per_hour", 0.0)) != 6.0:
		_fail("Light-work baseline must remain -3 satiety / +6 fatigue per hour")
		return
	if float(heavy_work.get("satiety_per_hour", 0.0)) != -4.0 or float(heavy_work.get("fatigue_per_hour", 0.0)) != 8.0:
		_fail("Heavy-work baseline must remain -4 satiety / +8 fatigue per hour")
		return
	if (
		absf(float(idle.get("satiety_per_hour", 0.0))) >= absf(float(light_work.get("satiety_per_hour", 0.0)))
		or absf(float(idle.get("fatigue_per_hour", 0.0))) >= absf(float(light_work.get("fatigue_per_hour", 0.0)))
	):
		_fail("Idle must be the lower non-zero consumption tier")
		return
	if (
		absf(float(combat.get("satiety_per_hour", 0.0))) <= absf(float(heavy_work.get("satiety_per_hour", 0.0)))
		or float(combat.get("fatigue_per_hour", 0.0)) <= float(heavy_work.get("fatigue_per_hour", 0.0))
	):
		_fail("Combat must consume faster than heavy work")
		return

	needs_system.initialize()
	if not _assert_profile_delta(needs_system, npc_system, "gardener_01", "idle", 7200.0, 50, 50, 49, 51):
		return
	if not _assert_profile_delta(needs_system, npc_system, "engineer_01", "heavy_work", 3600.0, 50, 50, 46, 58):
		return
	if not _assert_profile_delta(needs_system, npc_system, "veteran_deputy_01", "sleep", 23400.0, 100, 100, 87, 0):
		return
	if not _assert_profile_delta(needs_system, npc_system, "cook_01", "drink_rest", 600.0, 50, 50, 49, 47):
		return
	if not _assert_profile_delta(needs_system, npc_system, "blacksmith_01", "combat", 3600.0, 50, 50, 42, 66):
		return
	if not _assert_profile_delta(needs_system, npc_system, "priest_01", "dialogue", 3600.0, 50, 50, 49, 51):
		return

	npc_system.update_npc_state("engineer_01", {
		"behavior_mode": "work",
		"current_action": "moving_to_workshop",
		"unconscious": false,
		"escaped": false,
	})
	if str(needs_system.get_npc_needs_snapshot("engineer_01").get("profile_id", "")) != "movement":
		_fail("moving_to_* state must resolve to movement")
		return
	npc_system.update_npc_state("engineer_01", {"behavior_mode": "combat", "current_action": "combat"})
	if str(needs_system.get_npc_needs_snapshot("engineer_01").get("profile_id", "")) != "combat":
		_fail("Combat behavior mode must override ordinary work activity")
		return
	npc_system.update_npc_state("engineer_01", {"behavior_mode": "work", "current_action": "work_garden"})
	if str(needs_system.get_npc_needs_snapshot("engineer_01").get("profile_id", "")) != "heavy_work":
		_fail("Direct action state must resolve through action_defs needs_profile")
		return

	main.queue_free()
	await process_frame
	print("T0081 exhaustive activity needs framework verification passed.")
	quit(0)


func _assert_profile_delta(
	needs_system: Node,
	npc_system: Node,
	npc_id: String,
	profile_id: String,
	game_seconds: float,
	satiety_before: int,
	fatigue_before: int,
	expected_satiety: int,
	expected_fatigue: int
) -> bool:
	npc_system.update_npc_state(npc_id, {
		"satiety": satiety_before,
		"fatigue": fatigue_before,
		"escaped": false,
		"unconscious": false,
	})
	var result: Dictionary = needs_system.debug_advance_profile(npc_id, profile_id, game_seconds)
	if result.is_empty():
		_fail("Failed to advance needs profile %s" % profile_id)
		return false
	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if int(state.get("satiety", -1)) != expected_satiety or int(state.get("fatigue", -1)) != expected_fatigue:
		_fail(
			"Profile %s result mismatch: expected %d/%d, got %d/%d"
			% [
				profile_id,
				expected_satiety,
				expected_fatigue,
				int(state.get("satiety", -1)),
				int(state.get("fatigue", -1)),
			]
		)
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
