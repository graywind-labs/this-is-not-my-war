extends SceneTree

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const TARGET_NPC_ID := "cook_01"
const SPEAKER_NPC_ID := "stableman_01"


func _init() -> void:
	var main_scene := load(MAIN_SCENE) as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if llm_bridge == null:
		_fail("Dialogue action reference verification requires LLMBridge")
		return

	var daily_payload: Dictionary = llm_bridge.build_npc_daily_plan_payload(TARGET_NPC_ID, {
		"requires_time_slowdown": false,
	})
	var expected_signatures := _candidate_signatures(daily_payload.get("allowed_actions", []))
	if expected_signatures.is_empty():
		_fail("Daily plan candidate catalog must not be empty")
		return
	if not _has_action_id(daily_payload.get("allowed_actions", []), "work_dining_hall"):
		_fail("Expected work_dining_hall in the shared candidate catalog")
		return

	var contexts: Array[Dictionary] = [
		{
			"label": "player_npc_work",
			"text": "你现在能做什么，什么做不到？",
			"options": {"dialogue_kind": "player_npc", "interaction_context": "work"},
		},
		{
			"label": "player_npc_rally",
			"text": "集结时你现在能做什么？",
			"options": {"dialogue_kind": "player_npc", "interaction_context": "rally"},
		},
		{
			"label": "player_npc_combat",
			"text": "战斗时你现在能做什么？",
			"options": {"dialogue_kind": "player_npc", "interaction_context": "combat"},
		},
		{
			"label": "player_npc_avoid_combat",
			"text": "避战时你现在能做什么？",
			"options": {"dialogue_kind": "player_npc", "interaction_context": "avoid_combat"},
		},
		{
			"label": "escape_intervention",
			"text": "留下来以后你能做什么？",
			"options": {
				"dialogue_kind": "escape_intervention",
				"interaction_context": "escape_intervention",
				"escape_intervention_round": 1,
				"current_round": 1,
				"max_rounds": 5,
			},
		},
		{
			"label": "npc_npc_invitation",
			"text": "我想和你谈谈你能做的事。",
			"options": _npc_dialogue_options("invitation", 0),
		},
		{
			"label": "npc_npc_conversation",
			"text": "你能加工餐食，但能骑飞龙吗？",
			"options": _npc_dialogue_options("conversation", 1),
		},
	]

	for context in contexts:
		var payload: Dictionary = llm_bridge.build_npc_dialogue_payload(
			TARGET_NPC_ID,
			str(context.get("text", "")),
			context.get("options", {})
		)
		if payload.is_empty():
			_fail("Dialogue payload was empty for %s" % str(context.get("label", "unknown")))
			return
		var actions = payload.get("allowed_actions", [])
		if not actions is Array or actions.is_empty():
			_fail("Dialogue payload lacked allowed_actions for %s" % str(context.get("label", "unknown")))
			return
		if _candidate_signatures(actions) != expected_signatures:
			_fail("Dialogue and daily-plan candidates diverged for %s" % str(context.get("label", "unknown")))
			return

	var prompt_file := FileAccess.open("res://data/prompts/dialogue_system_prompt.txt", FileAccess.READ)
	if prompt_file == null:
		_fail("Failed to read dialogue_system_prompt.txt")
		return
	var prompt_text := prompt_file.get_as_text()
	for fragment in ["allowed_actions", "当前能力边界", "不是制定或修改计划", "列表外行动", "当前做不到"]:
		if not prompt_text.contains(fragment):
			_fail("Dialogue prompt lacked action-boundary fragment: %s" % fragment)
			return

	print("verify_dialogue_action_reference: ok contexts=%d candidates=%d" % [contexts.size(), expected_signatures.size()])
	quit(0)


func _npc_dialogue_options(phase: String, round_index: int) -> Dictionary:
	return {
		"dialogue_kind": "npc_npc",
		"dialogue_phase": phase,
		"speaker_kind": "npc",
		"speaker_npc_id": SPEAKER_NPC_ID,
		"speaker_name": "托马",
		"current_round": round_index,
		"max_rounds": 0,
		"soft_round_threshold": 5,
		"soft_round_guidance": "第六轮起若无紧急或必要事项，应自然告别并结束。",
	}


func _candidate_signatures(raw_actions) -> Array[String]:
	var signatures: Array[String] = []
	if not raw_actions is Array:
		return signatures
	for raw_action in raw_actions:
		if not raw_action is Dictionary:
			continue
		var action: Dictionary = raw_action
		signatures.append("%s|%s|%s|%s" % [
			str(action.get("action_id", "")),
			str(action.get("action_kind", "")),
			str(action.get("location_id", "")),
			str(action.get("target_id", "")),
		])
	signatures.sort()
	return signatures


func _has_action_id(raw_actions, expected_action_id: String) -> bool:
	if not raw_actions is Array:
		return false
	for raw_action in raw_actions:
		if raw_action is Dictionary and str((raw_action as Dictionary).get("action_id", "")) == expected_action_id:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
