extends SceneTree


const EXPECTED_RESIDENTS := {
	"stableman_01": {"name": "托马", "identity": "马夫"},
	"cook_01": {"name": "布鲁诺", "identity": "厨子"},
	"gardener_01": {"name": "伊沃", "identity": "园丁"},
	"blacksmith_01": {"name": "格伦", "identity": "铁匠"},
	"veteran_deputy_01": {"name": "艾达", "identity": "老兵副官"},
	"priest_01": {"name": "马塞尔", "identity": "神父"},
	"doctor_01": {"name": "莉娜", "identity": "医生"},
	"engineer_01": {"name": "欧文", "identity": "工程师"}
}
const REQUIRED_RULE_DETAILS := [
	"工作和生活",
	"建筑开始升级",
	"协助",
	"加快升级进度",
	"应征入伍",
	"主武器",
	"躲避敌人",
	"士气低落",
	"临阵脱逃",
	"更加危险"
]


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	if npc_system == null or llm_bridge == null or building_system == null or action_system == null or resource_system == null:
		_fail("Dynamic station context verification required nodes not found")
		return
	for required_method in [
		"build_npc_dialogue_payload",
		"build_dialogue_plan_revision_judgement_payload",
		"build_npc_daily_plan_payload",
		"build_npc_plan_revision_payload",
		"build_npc_battle_judgement_payload",
		"build_npc_daily_reflection_payload"
	]:
		if not llm_bridge.has_method(required_method):
			_fail("LLMBridge failed to load required method: %s" % required_method)
			return

	var initial_payloads := _build_all_payloads(llm_bridge)
	var initial_public_resources := _public_resource_amounts(resource_system)
	for call_type in initial_payloads.keys():
		if not _verify_payload(
			str(call_type),
			initial_payloads[call_type],
			EXPECTED_RESIDENTS,
			building_system,
			action_system,
			initial_public_resources
		):
			return

	resource_system.add_resource("grain", 7)
	resource_system.add_resource("money", 11)
	resource_system.add_resource("wine", 3)
	if not npc_system.update_npc_state("engineer_01", {
		"escaped": true,
		"behavior_mode": "escaped",
		"current_location": "outside_station",
		"current_location_name": "驿站外"
	}):
		_fail("Failed to mark engineer as having left the station")
		return

	var remaining_residents := EXPECTED_RESIDENTS.duplicate(true)
	remaining_residents.erase("engineer_01")
	var updated_payloads := _build_all_payloads(llm_bridge)
	var updated_public_resources := _public_resource_amounts(resource_system)
	if int(updated_public_resources.get("grain", 0)) != int(initial_public_resources.get("grain", 0)) + 7:
		_fail("Public grain fixture did not change before rebuilding LLM payloads")
		return
	for call_type in updated_payloads.keys():
		if not _verify_payload(
			str(call_type),
			updated_payloads[call_type],
			remaining_residents,
			building_system,
			action_system,
			updated_public_resources
		):
			return

	print("T0058 station context public resources and upgrade-rule verification passed.")
	quit(0)


func _build_all_payloads(llm_bridge: Node) -> Dictionary:
	return {
		"dialogue": llm_bridge.build_npc_dialogue_payload("doctor_01", "今天情况如何？", {
			"speaker_kind": "npc",
			"speaker_npc_id": "priest_01"
		}),
		"plan_day": llm_bridge.build_npc_daily_plan_payload("doctor_01"),
		"plan_revision_judgement": llm_bridge.build_dialogue_plan_revision_judgement_payload("doctor_01", {
			"current_plan": _build_idle_plan(),
			"dialogue_history": [{
				"speaker_id": "guard_officer",
				"speaker_name": "守备官",
				"listener_id": "doctor_01",
				"listener_name": "莉娜",
				"text": "今天照常坐诊。",
				"visibility": "private"
			}]
		}),
		"revise_plan": llm_bridge.build_npc_plan_revision_payload("doctor_01"),
		"battle_judgement": llm_bridge.build_npc_battle_judgement_payload("doctor_01", {
			"allowed_decisions": ["avoid_battle", "escape_station"]
		}),
		"daily_reflection": llm_bridge.build_npc_daily_reflection_payload("doctor_01", {"day": 1})
	}


func _build_idle_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	for hour in range(24):
		plan.append({
			"hour": hour,
			"action_kind": "idle",
			"action_id": "idle",
			"location_id": null,
			"target_id": null,
			"priority": 20,
			"reason": "等待",
			"dialogue_goal": ""
		})
	return plan


func _verify_payload(
	call_type: String,
	payload: Dictionary,
	expected_residents: Dictionary,
	building_system: Node,
	action_system: Node,
	expected_public_resources: Dictionary
) -> bool:
	if payload.is_empty():
		_fail("%s payload was empty" % call_type)
		return false
	if _count_dictionary_key(payload, "station_context") != 1:
		_fail("%s payload must contain exactly one request-level station_context" % call_type)
		return false
	if not payload.has("station_context"):
		_fail("%s station_context must be a top-level request field" % call_type)
		return false
	if call_type in ["plan_day", "plan_revision_judgement", "revise_plan", "battle_judgement", "daily_reflection"]:
		var npc_context: Dictionary = payload.get("npc", {})
		for required_npc_field in [
			"identity",
			"state",
			"current_order",
			"short_term_memory",
			"long_term_memory",
			"location_context"
		]:
			if not npc_context.has(required_npc_field):
				_fail("%s payload lost NPC context '%s'" % [call_type, required_npc_field])
				return false

	var station_context: Dictionary = payload.get("station_context", {})
	var summary := str(station_context.get("setting_summary", ""))
	if not summary.contains("小型边境驿站"):
		_fail("%s setting_summary did not identify the small border relay station" % call_type)
		return false
	var serialized_context := JSON.stringify(station_context)
	for required_text in REQUIRED_RULE_DETAILS:
		if not serialized_context.contains(str(required_text)):
			_fail("%s station_context lost required station rule detail: %s" % [call_type, required_text])
			return false

	var roster: Array = station_context.get("resident_roster", [])
	if roster.size() != expected_residents.size():
		_fail("%s roster size mismatch: %d" % [call_type, roster.size()])
		return false
	var actual_by_id := {}
	for raw_resident in roster:
		if not raw_resident is Dictionary:
			_fail("%s roster contained a non-dictionary resident" % call_type)
			return false
		var resident: Dictionary = raw_resident
		var npc_id := str(resident.get("npc_id", ""))
		actual_by_id[npc_id] = resident
	for npc_id_value in expected_residents.keys():
		var npc_id := str(npc_id_value)
		var expected: Dictionary = expected_residents[npc_id]
		var actual: Dictionary = actual_by_id.get(npc_id, {})
		if (
			actual.is_empty()
			or str(actual.get("name", "")) != str(expected.get("name", ""))
			or str(actual.get("identity", "")) != str(expected.get("identity", ""))
		):
			_fail("%s roster identity mismatch for %s: %s" % [call_type, npc_id, str(actual)])
			return false
	if actual_by_id.has("engineer_01") and not expected_residents.has("engineer_01"):
		_fail("%s roster retained an NPC who already left the station" % call_type)
		return false

	var building_roster: Array = station_context.get("building_roster", [])
	var expected_building_ids: Array = building_system.get_building_ids()
	if building_roster.size() != expected_building_ids.size():
		_fail("%s building roster size mismatch: %d != %d" % [call_type, building_roster.size(), expected_building_ids.size()])
		return false
	var actual_buildings := {}
	for raw_building in building_roster:
		if not raw_building is Dictionary:
			_fail("%s building roster contained a non-dictionary item" % call_type)
			return false
		var building: Dictionary = raw_building
		actual_buildings[str(building.get("building_id", ""))] = building
	for raw_building_id in expected_building_ids:
		var building_id := str(raw_building_id)
		var expected_building: Dictionary = building_system.get_building(building_id)
		var actual_building: Dictionary = actual_buildings.get(building_id, {})
		if actual_building.is_empty() or str(actual_building.get("name", "")) != str(expected_building.get("name", "")):
			_fail("%s building roster mismatch for %s" % [call_type, building_id])
			return false
	for non_building_id in ["plaza", "notice_board"]:
		if actual_buildings.has(non_building_id):
			_fail("%s station context incorrectly classified %s as a building" % [call_type, non_building_id])
			return false

	var expected_action_ids: Array[String] = []
	for raw_action_id in action_system.get_action_ids():
		var action_id := str(raw_action_id)
		var action: Dictionary = action_system.get_action(action_id)
		if not bool(action.get("plan_selectable", true)):
			continue
		if str(action.get("type", "")) == "system" and action_id != "escaping_station":
			continue
		expected_action_ids.append(action_id)
	var work_mode_actions: Array = station_context.get("work_mode_actions", [])
	if work_mode_actions.size() != expected_action_ids.size():
		_fail("%s work-mode action count mismatch: %d != %d" % [call_type, work_mode_actions.size(), expected_action_ids.size()])
		return false
	var actual_action_ids: Array[String] = []
	for raw_action in work_mode_actions:
		if not raw_action is Dictionary:
			_fail("%s work-mode action catalog contained a non-dictionary item" % call_type)
			return false
		var action: Dictionary = raw_action
		var action_id := str(action.get("action_id", ""))
		if action_id.is_empty() or str(action.get("name", "")).is_empty() or str(action.get("action_kind", "")).is_empty():
			_fail("%s work-mode action catalog contained an incomplete item: %s" % [call_type, str(action)])
			return false
		actual_action_ids.append(action_id)
	for expected_action_id in expected_action_ids:
		if not actual_action_ids.has(expected_action_id):
			_fail("%s work-mode action catalog lost %s" % [call_type, expected_action_id])
			return false
	for non_work_mode_action in ["escape_intervention_dialogue", "talk_to_guard_officer"]:
		if actual_action_ids.has(non_work_mode_action):
			_fail("%s work-mode action catalog included runtime-only action %s" % [call_type, non_work_mode_action])
			return false

	var basic_resources: Array = station_context.get("basic_resource_reserves", [])
	var expected_resource_ids := ["grain", "meal", "wood", "stone", "iron"]
	if basic_resources.size() != expected_resource_ids.size():
		_fail("%s public resource count mismatch: %d" % [call_type, basic_resources.size()])
		return false
	for index in range(expected_resource_ids.size()):
		var resource_id := str(expected_resource_ids[index])
		var reserve: Dictionary = basic_resources[index] if basic_resources[index] is Dictionary else {}
		if (
			str(reserve.get("resource_id", "")) != resource_id
			or str(reserve.get("name", "")).is_empty()
			or int(reserve.get("amount", -1)) != int(expected_public_resources.get(resource_id, -2))
		):
			_fail("%s public resource mismatch for %s: %s" % [call_type, resource_id, str(reserve)])
			return false
	var serialized_resources := JSON.stringify(basic_resources)
	for hidden_resource_id in ["money", "wine", "weapons", "armor", "defense_devices", "horse_readiness", "item_sword_shield"]:
		if serialized_resources.contains('"%s"' % hidden_resource_id):
			_fail("%s leaked hidden resource %s into station context" % [call_type, hidden_resource_id])
			return false
	if payload.has("current_resource_states"):
		var current_resource_states: Dictionary = payload.get("current_resource_states", {})
		if current_resource_states.size() != expected_resource_ids.size():
			_fail("%s current_resource_states must contain only five public resources" % call_type)
			return false
		for resource_id_value in expected_resource_ids:
			var resource_id := str(resource_id_value)
			if (
				not current_resource_states.has(resource_id)
				or int(current_resource_states.get(resource_id, -1)) != int(expected_public_resources.get(resource_id, -2))
			):
				_fail("%s current_resource_states mismatch for %s" % [call_type, resource_id])
				return false

	var station_rules: Array = station_context.get("station_rules", [])
	if station_rules.size() != 6:
		_fail("%s station rule count mismatch: %d" % [call_type, station_rules.size()])
		return false
	var has_activity_cycle_rule := false
	var has_upgrade_assistance_rule := false
	for raw_rule in station_rules:
		var rule := str(raw_rule)
		if "持续参与" in rule and "完成相应周期" in rule and "自行继续产出" in rule:
			has_activity_cycle_rule = true
		if "建筑开始升级" in rule and "协助" in rule and "加快升级进度" in rule:
			has_upgrade_assistance_rule = true
	if not has_activity_cycle_rule:
		_fail("%s station rules lost the continuous activity-cycle production boundary" % call_type)
		return false
	if not has_upgrade_assistance_rule:
		_fail("%s station rules lost the building-upgrade assistance guidance" % call_type)
		return false
	return true


func _public_resource_amounts(resource_system: Node) -> Dictionary:
	var result := {}
	for resource_id in ["grain", "meal", "wood", "stone", "iron"]:
		result[resource_id] = int(resource_system.get_resource(resource_id))
	return result


func _count_dictionary_key(value: Variant, target_key: String) -> int:
	var count := 0
	if value is Dictionary:
		for raw_key in (value as Dictionary).keys():
			if str(raw_key) == target_key:
				count += 1
			count += _count_dictionary_key((value as Dictionary)[raw_key], target_key)
	elif value is Array:
		for item in value as Array:
			count += _count_dictionary_key(item, target_key)
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
