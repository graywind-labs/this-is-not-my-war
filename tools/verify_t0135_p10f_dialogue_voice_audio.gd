extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const DialogueEmotionCatalog = preload("res://scripts/core/DialogueEmotionCatalog.gd")
const MALE_NPC_ID := "cook_01"
const FEMALE_NPC_ID := "doctor_01"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var controller := main.get_node("Presentation/DialogueVoiceAudioController")
	var dialog_system := main.get_node("Systems/DialogSystem")
	var npc_system := main.get_node("Systems/NPCSystem")
	var audio_manager := root.get_node("AudioManager")
	var config: Dictionary = controller.get("_config")
	var snapshot: Dictionary = controller.get_debug_snapshot()
	_assert(bool(snapshot.get("initialized", false)), "dialogue voice controller did not initialize")
	_assert(str(snapshot.get("schema_version", "")) == "dialogue_voice_audio_v1", "wrong dialogue voice schema")
	_assert(bool(snapshot.get("signal_connected", false)), "dialogue emotion signal is not connected")
	_assert(bool(snapshot.get("replace_active_voice_per_npc", false)), "same-NPC voice replacement is disabled")
	_assert_config_coverage(config, audio_manager)
	_assert(str(npc_system.get_npc(MALE_NPC_ID).get("gender", "")) == "male", "male fixture does not use formal male profile")
	_assert(str(npc_system.get_npc(FEMALE_NPC_ID).get("gender", "")) == "female", "female fixture does not use formal female profile")

	var male_state_before: Dictionary = npc_system.get_npc_state(MALE_NPC_ID)
	var female_state_before: Dictionary = npc_system.get_npc_state(FEMALE_NPC_ID)
	for emotion_id in DialogueEmotionCatalog.EMOTION_ORDER:
		_assert_dialogue_mapping(controller, dialog_system, config, MALE_NPC_ID, "male", emotion_id)
		_assert_dialogue_mapping(controller, dialog_system, config, FEMALE_NPC_ID, "female", emotion_id)
	_assert(npc_system.get_npc_state(MALE_NPC_ID) == male_state_before, "voice presentation changed male NPC authority state")
	_assert(npc_system.get_npc_state(FEMALE_NPC_ID) == female_state_before, "voice presentation changed female NPC authority state")

	_assert_male_none_random_pool(controller, dialog_system)
	_assert_same_npc_replacement(controller, dialog_system)
	_assert_independent_speakers(controller, dialog_system)
	_assert_global_playback(controller)
	_assert_invalid_input_fallback(controller)
	_assert_voice_bus_routes_to_sfx()

	audio_manager.stop_all_one_shots()
	main.queue_free()
	await process_frame
	await process_frame
	print("T0135_P10F_DIALOGUE_VOICE_AUDIO_PASS assets=19 genders=pass emotions=9 global_2d=pass replacement=pass")
	quit(0)


func _assert_config_coverage(config: Dictionary, audio_manager: Node) -> void:
	var voices: Dictionary = config.get("voices", {})
	var unique_assets := {}
	for gender in ["male", "female"]:
		var mapping: Dictionary = voices.get(gender, {})
		for emotion_id in DialogueEmotionCatalog.EMOTION_ORDER:
			_assert(mapping.has(emotion_id), "missing %s/%s voice mapping" % [gender, emotion_id])
			var variants: Array = mapping.get(emotion_id, [])
			_assert(not variants.is_empty(), "empty %s/%s voice mapping" % [gender, emotion_id])
			for raw_asset_id in variants:
				var asset_id := str(raw_asset_id)
				unique_assets[asset_id] = true
				_assert(audio_manager.has_asset(asset_id), "manifest is missing dialogue voice asset: %s" % asset_id)
	_assert(unique_assets.size() == 19, "dialogue voice inventory must contain 19 unique assets")
	_assert((voices.get("male", {}) as Dictionary).get("none", []).size() == 2, "male none must have two random variants")
	_assert((voices.get("female", {}) as Dictionary).get("none", []).size() == 1, "female none must have one confirmed variant")


func _assert_dialogue_mapping(
	controller: Node,
	dialog_system: Node,
	config: Dictionary,
	npc_id: String,
	gender: String,
	emotion_id: String
) -> void:
	controller.debug_reset_history()
	var result: Dictionary = dialog_system.debug_present_npc_dialogue_emotion(npc_id, emotion_id)
	_assert(bool(result.get("ok", false)), "DialogSystem rejected %s/%s emotion preview" % [gender, emotion_id])
	var history: Array = controller.get_debug_snapshot().get("recent_history", [])
	_assert(history.size() == 1, "emotion preview did not produce exactly one voice")
	if history.is_empty():
		return
	var record: Dictionary = history.back()
	var variants: Array = ((config.get("voices", {}) as Dictionary).get(gender, {}) as Dictionary).get(emotion_id, [])
	_assert(variants.has(str(record.get("asset_id", ""))), "wrong asset for %s/%s" % [gender, emotion_id])
	_assert(str(record.get("npc_id", "")) == npc_id, "voice record used wrong NPC")
	_assert(str(record.get("gender", "")) == gender, "voice record used wrong gender")
	_assert(str(record.get("emotion_id", "")) == emotion_id, "voice record used wrong emotion")
	_assert(str(record.get("player_type", "")) == "AudioStreamPlayer", "dialogue voice is not global 2D")
	_assert(str(record.get("bus", "")) == "Voice", "dialogue voice is not routed to Voice")
	_assert(str(record.get("spatial_mode", "")) == "global_2d", "dialogue voice still reports positional playback")


func _assert_male_none_random_pool(controller: Node, dialog_system: Node) -> void:
	controller.debug_set_rng_seed(13510)
	controller.debug_reset_history()
	for _index in range(24):
		dialog_system.debug_present_npc_dialogue_emotion(MALE_NPC_ID, "none")
	var selected := {}
	for raw_record in controller.get_debug_snapshot().get("recent_history", []):
		if raw_record is Dictionary:
			selected[str((raw_record as Dictionary).get("asset_id", ""))] = true
	_assert(selected.has("voice_emotion_none_male_01"), "male none random pool never selected variant 01")
	_assert(selected.has("voice_emotion_none_male_02"), "male none random pool never selected variant 02")


func _assert_same_npc_replacement(controller: Node, dialog_system: Node) -> void:
	dialog_system.debug_present_npc_dialogue_emotion(MALE_NPC_ID, "happy")
	var old_player := (controller.get("_active_players") as Dictionary).get(MALE_NPC_ID) as AudioStreamPlayer
	_assert(is_instance_valid(old_player), "first same-NPC voice did not start")
	dialog_system.debug_present_npc_dialogue_emotion(MALE_NPC_ID, "angry")
	var new_player := (controller.get("_active_players") as Dictionary).get(MALE_NPC_ID) as AudioStreamPlayer
	_assert(is_instance_valid(new_player) and new_player != old_player, "new same-NPC voice did not replace old player")
	_assert(old_player.is_queued_for_deletion(), "old same-NPC voice was left playing")


func _assert_independent_speakers(controller: Node, dialog_system: Node) -> void:
	dialog_system.debug_present_npc_dialogue_emotion(MALE_NPC_ID, "determined")
	dialog_system.debug_present_npc_dialogue_emotion(FEMALE_NPC_ID, "relieved")
	var active: Dictionary = controller.get_debug_snapshot().get("active_voices", {})
	_assert(active.has(MALE_NPC_ID) and active.has(FEMALE_NPC_ID), "different NPC voices incorrectly replaced each other")


func _assert_global_playback(controller: Node) -> void:
	var snapshot: Dictionary = controller.get_debug_snapshot()
	_assert(str(snapshot.get("playback_mode", "")) == "global_2d", "dialogue voice config is not global 2D")
	_assert(int(snapshot.get("source_count", -1)) == 0, "dialogue voice still creates positional sources")
	var active: Dictionary = snapshot.get("active_voices", {})
	for raw_entry in active.values():
		var entry := raw_entry as Dictionary
		_assert(str(entry.get("player_path", "")).begins_with("/root/AudioManager/"), "global voice player is not owned by AudioManager")


func _assert_invalid_input_fallback(controller: Node) -> void:
	controller.debug_reset_history()
	controller.debug_handle_dialogue_emotion(MALE_NPC_ID, {"emotion_id": "not_a_real_emotion"})
	var history: Array = controller.get_debug_snapshot().get("recent_history", [])
	_assert(history.size() == 1, "invalid emotion did not safely normalize")
	if not history.is_empty():
		_assert(str((history.back() as Dictionary).get("emotion_id", "")) == "none", "invalid emotion did not normalize to none")
	controller.debug_handle_dialogue_emotion("missing_npc", {"emotion_id": "happy"})
	var skipped: Array = controller.get_debug_snapshot().get("skipped_events", [])
	_assert(not skipped.is_empty() and str((skipped.back() as Dictionary).get("reason", "")) == "unknown_npc", "unknown NPC was not safely skipped")


func _assert_voice_bus_routes_to_sfx() -> void:
	var voice_index := AudioServer.get_bus_index(&"Voice")
	_assert(voice_index >= 0, "Voice bus is missing")
	_assert(AudioServer.get_bus_send(voice_index) == &"Master", "Voice bus must be independently controlled under Master")


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("T0135 P10F verification failed: %s" % message)
	quit(1)
