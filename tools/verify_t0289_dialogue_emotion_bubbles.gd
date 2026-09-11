extends SceneTree

const DialogueEmotionCatalog = preload("res://scripts/core/DialogueEmotionCatalog.gd")


func _init() -> void:
	var presentations := DialogueEmotionCatalog.get_all_presentations()
	if presentations.size() != 9:
		_fail("Dialogue emotion catalog must expose exactly 9 balanced options")
		return
	var ids: Array[String] = []
	var emojis: Array[String] = []
	var unique_ids := {}
	for presentation in presentations:
		var emotion_id := str(presentation.get("emotion_id", ""))
		ids.append(emotion_id)
		unique_ids[emotion_id] = true
		emojis.append(str(presentation.get("emoji", "")))
	if unique_ids.size() != ids.size() or ids.has("") or emojis.has(""):
		_fail("Dialogue emotion catalog contains empty values")
		return
	if str(DialogueEmotionCatalog.get_presentation("谨慎").get("emotion_id", "")) != "none":
		_fail("Legacy dialogue emotion alias did not normalize to none")
		return

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel") as Control
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel") as Control
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel") as Control
	var npc_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Cook01")
	if npc_system == null or dialog_system == null or time_system == null or gm_panel == null or npc_panel == null or dialog_panel == null or npc_node == null:
		_fail("T0289 required runtime nodes not found")
		return

	for presentation in presentations:
		var button_name := "DialogueEmotion%sPreviewButton" % str(presentation.get("emotion_id", "")).capitalize()
		if gm_panel.find_child(button_name, true, false) == null:
			_fail("Missing GM emotion preview button: %s" % button_name)
			return
	if gm_panel.find_child("DialogueEmotionSequencePreviewButton", true, false) == null:
		_fail("Missing GM rapid replacement preview button")
		return

	if not npc_system.debug_select_npc("cook_01"):
		_fail("Failed to open selected NPC portrait")
		return
	await process_frame
	var portrait := npc_panel.find_child("NPCPortraitView", true, false)
	if portrait == null:
		_fail("NPC portrait view not found")
		return
	var gm_npc_select := gm_panel.find_child("AINpcSelect", true, false) as OptionButton
	if gm_npc_select == null:
		_fail("GM common NPC select not found")
		return
	for item_index in range(gm_npc_select.get_item_count()):
		if str(gm_npc_select.get_item_metadata(item_index)) == "cook_01":
			gm_npc_select.select(item_index)
			break

	npc_panel.visible = false
	await process_frame
	var happy_button := gm_panel.find_child("DialogueEmotionHappyPreviewButton", true, false) as Button
	if happy_button == null:
		_fail("GM happy emotion preview button not found")
		return
	happy_button.pressed.emit()
	await process_frame
	if not npc_panel.visible:
		_fail("GM emotion preview did not open the selected NPC portrait")
		return
	var world_snapshot: Dictionary = npc_node.debug_get_dialogue_emotion_bubble_snapshot()
	var portrait_snapshot: Dictionary = portrait.debug_get_snapshot()
	var portrait_bubble: Dictionary = portrait_snapshot.get("emotion_bubble", {})
	if not bool(world_snapshot.get("visible", false)) or str(world_snapshot.get("emoji", "")) != "😊":
		_fail("Main-world emotion bubble did not show happy emoji: %s" % JSON.stringify(world_snapshot))
		return
	var world_emotion_root := npc_node.find_child("DialogueEmotionBubble", true, false)
	if (
		str(world_snapshot.get("emoji_renderer", "")) != "subviewport_color_sprite"
		or Vector2i(world_snapshot.get("emoji_viewport_size", Vector2i.ZERO)) != Vector2i(128, 96)
		or npc_node.find_child("EmojiSprite", true, false) == null
		or not bool(world_snapshot.get("direct_emoji_only", false))
		or bool(world_snapshot.get("background_mesh_present", true))
		or world_emotion_root == null
		or world_emotion_root.find_child("BubbleBody", true, false) != null
	):
		_fail("Main-world emotion presentation is not a direct, background-free color Emoji Sprite3D")
		return
	if int(world_snapshot.get("visual_layer", 0)) != 20:
		_fail("Main-world emotion bubble is not excluded from the portrait camera")
		return
	if not bool(portrait_bubble.get("visible", false)) or str(portrait_bubble.get("emoji", "")) != "😊":
		_fail("Second-person emotion bubble did not independently show happy emoji")
		return
	var portrait_bubble_position := Vector2(portrait_bubble.get("root_position", Vector2.ZERO))
	var portrait_tail_origin := Vector2(portrait_bubble.get("tail_origin", Vector2.ZERO))
	var portrait_tail_tip := Vector2(portrait_bubble.get("tail_tip", Vector2.ZERO))
	var portrait_tail_span := Vector2(portrait_bubble.get("tail_span", Vector2.ZERO))
	if (
		str(portrait_bubble.get("layout", "")) != "upper_left_comic_pointer"
		or portrait_bubble_position.x > 16.0
		or portrait_bubble_position.y > 28.0
		or not bool(portrait_bubble.get("tail_points_down_right", false))
		or not bool(portrait_bubble.get("tail_compact", false))
		or not bool(portrait_bubble.get("tail_origin_bottom_center", false))
		or not bool(portrait_bubble.get("tail_leaves_head_gap", false))
		or absf(portrait_tail_origin.x - 40.0) > 1.0
		or portrait_tail_origin.y < 55.0
		or portrait_tail_origin.y > 60.0
		or portrait_tail_tip.x < 52.0
		or portrait_tail_tip.x > 58.0
		or portrait_tail_tip.y < 67.0
		or portrait_tail_tip.y > 72.0
		or portrait_tail_span.x > 22.0
		or portrait_tail_span.y > 14.0
	):
		_fail("Second-person bubble tail is not a small bottom-center pointer with a visible head gap")
		return
	var happy_action: Dictionary = world_snapshot.get("emotion_action_result", {})
	var happy_character: Dictionary = world_snapshot.get("character", {})
	var happy_action_sequence := int(world_snapshot.get("emotion_action_sequence", 0))
	if (
		not bool(happy_action.get("active", false))
		or str(happy_action.get("action_id", "")) != "emotion_happy"
		or str(happy_action.get("presentation_state", "")) != "happy"
		or str(happy_character.get("current_clip", "")) != "Cheering"
	):
		_fail("Happy emoji did not synchronously trigger one cheering action: %s" % JSON.stringify(world_snapshot))
		return
	var happy_position_before_pause := float(happy_character.get("current_animation_position", 0.0))
	var happy_remaining_before_pause := float(happy_character.get("temporary_presentation_remaining_seconds", 0.0))
	var game_seconds_before_pause := float(time_system.get("_seconds_into_day"))
	time_system.set_paused(true)
	await create_timer(0.18).timeout
	world_snapshot = npc_node.debug_get_dialogue_emotion_bubble_snapshot()
	portrait_bubble = (portrait.debug_get_snapshot() as Dictionary).get("emotion_bubble", {})
	happy_character = world_snapshot.get("character", {})
	if (
		not bool(happy_character.get("gameplay_paused", false))
		or bool(happy_character.get("animation_paused", true))
		or not bool(happy_character.get("pause_exempt_dialogue_emotion_action", false))
		or float(happy_character.get("combat_attack_animation_speed_scale", 0.0)) <= 0.0
		or float(happy_character.get("current_animation_position", 0.0)) <= happy_position_before_pause + 0.05
		or float(happy_character.get("temporary_presentation_remaining_seconds", happy_remaining_before_pause)) >= happy_remaining_before_pause - 0.05
		or float(world_snapshot.get("elapsed_seconds", 0.0)) <= 0.05
		or float(portrait_bubble.get("elapsed_seconds", 0.0)) <= 0.05
		or not is_equal_approx(float(time_system.get("_seconds_into_day")), game_seconds_before_pause)
	):
		_fail("Happy action or Emoji did not continue in real time while gameplay authority stayed paused: %s" % JSON.stringify(world_snapshot))
		return
	var authority_action_before_angry := str(npc_system.get_npc_state("cook_01").get("current_action", ""))

	var replace_result: Dictionary = dialog_system.debug_present_npc_dialogue_emotion("cook_01", "angry")
	await process_frame
	world_snapshot = npc_node.debug_get_dialogue_emotion_bubble_snapshot()
	portrait_bubble = (portrait.debug_get_snapshot() as Dictionary).get("emotion_bubble", {})
	if not bool(replace_result.get("ok", false)) or str(world_snapshot.get("emoji", "")) != "😠" or str(portrait_bubble.get("emoji", "")) != "😠":
		_fail("New emotion did not immediately replace both independent bubbles")
		return
	var angry_action: Dictionary = world_snapshot.get("emotion_action_result", {})
	var angry_character: Dictionary = world_snapshot.get("character", {})
	if (
		int(world_snapshot.get("emotion_action_sequence", 0)) != happy_action_sequence + 1
		or not bool(angry_action.get("active", false))
		or str(angry_action.get("action_id", "")) != "emotion_angry"
		or str(angry_action.get("presentation_state", "")) != "angry"
		or str(angry_character.get("current_clip", "")) != "Melee_1H_Attack_Slice_Horizontal"
	):
		_fail("Angry emoji did not synchronously trigger exactly one sword-shield slice action: %s" % JSON.stringify(world_snapshot))
		return
	if str(npc_system.get_npc_state("cook_01").get("current_action", "")) != authority_action_before_angry:
		_fail("Emotion presentation action changed the NPC authority action")
		return
	if float(world_snapshot.get("elapsed_seconds", -1.0)) > 0.1 or float(portrait_bubble.get("elapsed_seconds", -1.0)) > 0.1:
		_fail("Replacement did not reset the presentation timers")
		return
	var angry_position_while_paused := float(angry_character.get("current_animation_position", 0.0))
	var angry_remaining_while_paused := float(angry_character.get("temporary_presentation_remaining_seconds", 0.0))
	await create_timer(0.18).timeout
	world_snapshot = npc_node.debug_get_dialogue_emotion_bubble_snapshot()
	angry_character = world_snapshot.get("character", {})
	if (
		bool(angry_character.get("animation_paused", true))
		or not bool(angry_character.get("pause_exempt_dialogue_emotion_action", false))
		or float(angry_character.get("current_animation_position", 0.0)) <= angry_position_while_paused + 0.05
		or float(angry_character.get("temporary_presentation_remaining_seconds", angry_remaining_while_paused)) >= angry_remaining_while_paused - 0.05
		or not is_equal_approx(float(time_system.get("_seconds_into_day")), game_seconds_before_pause)
	):
		_fail("Angry action triggered during pause did not advance while game time remained frozen: %s" % JSON.stringify(world_snapshot))
		return
	var character_art_view := npc_node.find_child("*ChibiArtView", true, false)
	if character_art_view == null or not character_art_view.has_method("_advance_temporary_presentation"):
		_fail("Formal character art does not expose the temporary presentation timer for pause-boundary verification")
		return
	character_art_view.call(
		"_advance_temporary_presentation",
		float(angry_character.get("temporary_presentation_remaining_seconds", 0.0)) + 0.1
	)
	angry_character = (npc_node.debug_get_dialogue_emotion_bubble_snapshot() as Dictionary).get("character", {})
	if (
		not str(angry_character.get("temporary_presentation_state", "")).is_empty()
		or not bool(angry_character.get("animation_paused", false))
		or not is_zero_approx(float(angry_character.get("combat_attack_animation_speed_scale", -1.0)))
		or not is_equal_approx(float(time_system.get("_seconds_into_day")), game_seconds_before_pause)
	):
		_fail("Finishing a pause-exempt emotion did not restore the frozen authority animation: %s" % JSON.stringify(angry_character))
		return
	time_system.set_paused(false)

	npc_node.call("_advance_dialogue_emotion_bubble", 5.2)
	portrait.call("_advance_emotion_bubble", 5.2)
	world_snapshot = npc_node.debug_get_dialogue_emotion_bubble_snapshot()
	portrait_bubble = (portrait.debug_get_snapshot() as Dictionary).get("emotion_bubble", {})
	if not bool(world_snapshot.get("visible", false)) or not bool(portrait_bubble.get("visible", false)):
		_fail("Emotion bubbles disappeared before completing the fade")
		return
	npc_node.call("_advance_dialogue_emotion_bubble", 1.0)
	portrait.call("_advance_emotion_bubble", 1.0)
	if bool(npc_node.debug_get_dialogue_emotion_bubble_snapshot().get("visible", true)):
		_fail("Main-world emotion bubble did not disappear after hold plus fade")
		return
	if bool(((portrait.debug_get_snapshot() as Dictionary).get("emotion_bubble", {}) as Dictionary).get("visible", true)):
		_fail("Second-person emotion bubble did not disappear after hold plus fade")
		return

	var special_result: Dictionary = dialog_system.debug_preview_special_interaction_result(
		"cook_01", "recruitment", "none", "private"
	)
	await process_frame
	var history_text := dialog_panel.find_child("DialogHistoryText", true, false) as RichTextLabel
	if not bool(special_result.get("ok", false)) or history_text == null or not history_text.text.contains("(无明显情绪)"):
		_fail("NPC dialogue tail did not display the parsed Chinese emotion label")
		return
	var state: Dictionary = dialog_system.get_dialogue_state()
	var history: Array = state.get("history", [])
	var last_turn: Dictionary = history.back() if not history.is_empty() and history.back() is Dictionary else {}
	if str(last_turn.get("text", "")).contains("无明显情绪") or str(last_turn.get("emotion_id", "")) != "none":
		_fail("Emotion display suffix polluted raw dialogue text or lost its structured marker")
		return
	world_snapshot = npc_node.debug_get_dialogue_emotion_bubble_snapshot()
	if (
		int(world_snapshot.get("emotion_action_sequence", 0)) != happy_action_sequence + 1
		or bool((world_snapshot.get("emotion_action_result", {}) as Dictionary).get("active", true))
	):
		_fail("An emotion without an action mapping incorrectly triggered a character action")
		return

	print("T0289_DIALOGUE_EMOTION_BUBBLES_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
