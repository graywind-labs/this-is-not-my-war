extends SceneTree

const TutorialOverlayClass = preload("res://scripts/ui/TutorialOverlay.gd")


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("T1505 could not load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var startup := root.get_node_or_null("Main/Systems/GameStartupSystem")
	var tutorial := root.get_node_or_null("Main/Systems/TutorialDirector")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var defense_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var combat_audio := root.get_node_or_null("Main/Presentation/CombatAudioController")
	var world_audio := root.get_node_or_null("Main/Presentation/WorldAudioController")
	var audio_manager := root.get_node_or_null("AudioManager")
	var overlay := root.get_node_or_null("Main/UI/TutorialOverlay")
	var pause_menu := root.get_node_or_null("Main/UI/PauseMenu")
	var hud := root.get_node_or_null("Main/UI/HUD")
	var game_state := root.get_node_or_null("GameState")
	var config_loader := root.get_node_or_null("ConfigLoader")
	if [startup, tutorial, time_system, resource_system, building_system, npc_system, memory_system, equipment_system, defense_system, combat_system, daily_plan_system, combat_audio, world_audio, audio_manager, overlay, pause_menu, hud, game_state, config_loader].has(null):
		_fail("T1505 required runtime nodes are missing")
		return
	var tutorial_config: Dictionary = config_loader.load_data_file("tutorial_config.json", {})
	var ui_copy: Dictionary = tutorial_config.get("ui_copy", {}) as Dictionary
	var step_copy: Dictionary = tutorial_config.get("step_copy", {}) as Dictionary
	var required_step_copy := [
		"battlefield_explain", "select_slot", "select_device", "camera_controls", "wait_tower", "tower_destroyed",
		"select_ada", "equipment_button", "main_weapon", "sword_shield", "equip_showcase",
		"alarm", "battle", "battle_health", "ada_return",
	]
	if ui_copy.is_empty() or step_copy.is_empty():
		_fail("T1505 tutorial copy must be centralized in tutorial_config.json")
		return
	for step_copy_id: String in required_step_copy:
		if not step_copy.has(step_copy_id) or (step_copy.get(step_copy_id, {}) as Dictionary).is_empty():
			_fail("T1505 tutorial_config.json is missing step_copy.%s" % step_copy_id)
			return
	if int(startup.startup_mode) != 2:
		_fail("T1505 Main.tscn must default to tutorial startup mode")
		return
	var initial_prologue_diary := _find_prologue_diary(
		npc_system.get_npc("veteran_deputy_01").get("diary", []) as Array
	)
	if initial_prologue_diary.is_empty():
		_fail("T1505 Ada's prologue diary must exist before the tutorial starts")
		return

	var start_result: Dictionary = startup.debug_apply_startup_mode(2, true, false)
	await process_frame
	if not bool(start_result.get("tutorial_requested", false)):
		_fail("T1505 tutorial startup was not requested")
		return
	var tutorial_snapshot: Dictionary = tutorial.get_tutorial_snapshot()
	if str(tutorial_snapshot.get("step_id", "")) != "intro":
		_fail("T1505 tutorial did not enter intro: %s" % str(tutorial_snapshot))
		return
	if str(tutorial_snapshot.get("tutorial_music_cue", "")) != "tutorial_intro" or audio_manager.get_current_music_asset_id() != "music_tutorial_intro":
		_fail("T1505 intro did not start the selected pre-warning music: %s / %s" % [str(tutorial_snapshot), audio_manager.get_current_music_asset_id()])
		return
	if not bool(audio_manager.debug_get_snapshot().get("current_music_looping", false)) or not bool(world_audio.get_debug_snapshot().get("tutorial_music_signal_connected", false)):
		_fail("T1505 tutorial music is not a connected looping Music presentation")
		return
	if not bool(time_system.is_paused) or game_state.current_day != 1 or game_state.current_hour != 1:
		_fail("T1505 tutorial clock must remain paused at D1 01:00")
		return
	if resource_system.get_resource("item_wall_arrow_tower") != 1 or resource_system.get_resource("item_sword_shield") != 1:
		_fail("T1505 temporary tutorial inventory mismatch: %s" % str(resource_system.get_resource_snapshot()))
		return
	var staged_equipment: Dictionary = equipment_system.get_equipment_snapshot("veteran_deputy_01")
	if not (staged_equipment.get("main_weapon", {}) as Dictionary).is_empty():
		_fail("T1505 Ada should begin the tutorial without a main weapon")
		return
	if not bool(overlay.is_static_frame_input_locked()):
		_fail("T1505 intro static frame did not lock conflicting shortcuts")
		return
	var startup_guard_snapshot: Dictionary = overlay.get_debug_snapshot()
	if not bool(startup_guard_snapshot.get("startup_input_guard_active", false)):
		_fail("T1505 intro did not start with a buffered-input guard")
		return
	var queued_click := InputEventMouseButton.new()
	queued_click.button_index = MOUSE_BUTTON_LEFT
	queued_click.pressed = true
	if not bool(overlay.call("_consume_startup_input_guard", queued_click)):
		_fail("T1505 startup guard did not consume a queued loading click")
		return
	overlay.call("_on_blocker_gui_input", queued_click)
	if int(tutorial.get_tutorial_snapshot().get("intro_index", -1)) != 0:
		_fail("T1505 queued loading click advanced the intro")
		return
	queued_click.pressed = false
	overlay.call("_consume_startup_input_guard", queued_click)
	overlay.set("_startup_input_guard_until_msec", Time.get_ticks_msec() - 1)
	overlay.call("_process", 0.0)
	if bool((overlay.get_debug_snapshot() as Dictionary).get("startup_input_guard_active", true)):
		_fail("T1505 startup guard did not open after queued input was released")
		return
	var intro_before_shortcuts := int(tutorial_snapshot.get("intro_index", -1))
	var player_scale_before_shortcuts := float(time_system.get_time_scale_snapshot().get("player_scale", -1.0))
	var escape_event := _make_key_event(KEY_ESCAPE)
	if not bool(overlay.call("_consume_static_frame_shortcut", escape_event)):
		_fail("T1505 intro did not consume Escape")
		return
	pause_menu.call("_unhandled_key_input", escape_event)
	pause_menu.open_menu()
	var speed_event := _make_key_event(KEY_3)
	hud.call("_input", speed_event)
	if not bool(overlay.call("_consume_static_frame_shortcut", speed_event)):
		_fail("T1505 intro did not consume HUD speed shortcut")
		return
	if (
		pause_menu.visible
		or int(tutorial.get_tutorial_snapshot().get("intro_index", -2)) != intro_before_shortcuts
		or not is_equal_approx(float(time_system.get_time_scale_snapshot().get("player_scale", -2.0)), player_scale_before_shortcuts)
		or not bool((overlay.get_debug_snapshot() as Dictionary).get("full_screen_continue_enabled", false))
	):
		_fail("T1505 intro shortcut lock allowed an obscured menu, HUD shortcut, or disabled click-to-continue")
		return
	if combat_system.get_active_enemy_count() != 5 or not defense_system.get_deployments().is_empty():
		_fail("T1505 tutorial raid preparation mismatch")
		return
	for raw_npc_id in npc_system.get_npc_ids():
		var initial_memory: Dictionary = memory_system.get_npc_short_term_memory_snapshot(str(raw_npc_id))
		if int(initial_memory.get("event_count", -1)) != 0 or int(initial_memory.get("witness_count", -1)) != 0:
			_fail("T1505 tutorial NPC began with staged short-term memory: %s" % str(initial_memory))
			return
	var combat_audio_snapshot: Dictionary = combat_audio.get_debug_snapshot()
	for record: Dictionary in combat_audio_snapshot.get("recent_history", []):
		if str(record.get("event_type", "")) == "battle_started":
			_fail("T1505 tutorial raid played the formal enemy-entry stinger")
			return
	var tutorial_start_silenced := false
	for record: Dictionary in combat_audio_snapshot.get("skipped_events", []):
		if (
			str(record.get("event_type", "")) == "battle_started"
			and str(record.get("reason", "")) == "tutorial_battle_started"
		):
			tutorial_start_silenced = true
			break
	if not tutorial_start_silenced:
		_fail("T1505 tutorial raid did not carry tutorial scope into the audio presentation event")
		return
	var front_gate_before: Dictionary = building_system.get_building("front_gate")
	combat_audio.debug_reset_history()
	var tutorial_gate_hit: Dictionary = combat_system.call(
		"_apply_enemy_attack_to_building",
		{"id": "tutorial_gate_audio_probe", "name": "教程正门音频测试敌人"},
		"front_gate",
		7,
		{"hit_world_position": Vector3(0.0, 1.0, 24.0)}
	)
	var front_gate_after: Dictionary = building_system.get_building("front_gate")
	if (
		int(front_gate_after.get("hp", -1)) != int(front_gate_before.get("hp", -2))
		or int(tutorial_gate_hit.get("damage", -1)) != 0
		or not bool((tutorial_gate_hit.get("result", {}) as Dictionary).get("tutorial_scope", false))
	):
		_fail("T1505 tutorial front gate audio feedback changed authoritative HP: %s" % str(tutorial_gate_hit))
		return
	var gate_hit_audio_found := false
	for record: Dictionary in (combat_audio.get_debug_snapshot().get("recent_history", []) as Array):
		if (
			str(record.get("event_type", "")) == "structure_damaged"
			and str(record.get("target_id", "")) == "front_gate"
			and str(record.get("asset_id", "")).begins_with("sfx_combat_wood_damage_")
		):
			gate_hit_audio_found = true
			break
	if not gate_hit_audio_found:
		_fail("T1505 tutorial invulnerable front gate did not reuse formal structure-hit audio")
		return

	for _page in range(2):
		tutorial.debug_continue()
	if audio_manager.get_current_music_asset_id() != "music_tutorial_intro":
		_fail("T1505 pre-warning pages switched away from intro music")
		return
	tutorial.debug_continue()
	await process_frame
	if str(tutorial.get_tutorial_snapshot().get("tutorial_music_cue", "")) != "tutorial_battle" or audio_manager.get_current_music_asset_id() != "music_tutorial_battle":
		_fail("T1505 intro_ada_warning did not switch to the selected battle tutorial music")
		return
	for _page in range(5):
		tutorial.debug_continue()
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "battlefield_explain" or audio_manager.get_current_music_asset_id() != "music_tutorial_battle":
		_fail("T1505 battle tutorial music restarted or changed across the comic-to-3D boundary")
		return
	tutorial.debug_continue()
	await process_frame
	await process_frame
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "select_slot":
		_fail("T1505 intro did not lead to slot selection")
		return
	var slot_overlay: Dictionary = tutorial.get_tutorial_snapshot().get("overlay", {})
	if str(slot_overlay.get("target_id", "")) != "slot:wall_slot_01" or not bool(slot_overlay.get("target_visible", false)):
		_fail("T1505 wall slot highlight is not visible: %s" % str(slot_overlay))
		return
	var configured_slot_copy: Dictionary = step_copy.get("select_slot", {}) as Dictionary
	if str(slot_overlay.get("dialogue_text", "")) != ">%s<" % str(configured_slot_copy.get("text", "")) or str(slot_overlay.get("top_hint", "")) != str(configured_slot_copy.get("top_hint", "")):
		_fail("T1505 slot instruction is not sourced from tutorial_config.json: %s" % str(slot_overlay))
		return
	tutorial.debug_press_current_target()
	await process_frame
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "select_device":
		_fail("T1505 slot interaction did not open device selection")
		return
	var device_overlay: Dictionary = tutorial.get_tutorial_snapshot().get("overlay", {})
	if str(device_overlay.get("target_id", "")) != "device:wall_arrow_tower" or not bool(device_overlay.get("target_visible", false)):
		_fail("T1505 arrow tower picker highlight is not visible: %s" % str(device_overlay))
		return
	tutorial.debug_press_current_target()
	await process_frame
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "camera_controls" or defense_system.get_deployments().size() != 1:
		_fail("T1505 arrow tower was not deployed through the guided UI proxy")
		return
	var camera_overlay: Dictionary = tutorial.get_tutorial_snapshot().get("overlay", {})
	var configured_camera_copy: Dictionary = step_copy.get("camera_controls", {}) as Dictionary
	if (
		str(camera_overlay.get("dialogue_text", "")) != ">%s<" % str(configured_camera_copy.get("text", ""))
		or not bool(camera_overlay.get("continue_enabled", false))
		or not bool(camera_overlay.get("world_mouse_input_passthrough", false))
	):
		_fail("T0431 camera controls page is not configured for bottom-click continuation and camera input: %s" % str(camera_overlay))
		return
	tutorial.debug_continue()
	await process_frame
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "wait_tower" or bool((tutorial.get_tutorial_snapshot().get("overlay", {}) as Dictionary).get("world_mouse_input_passthrough", true)):
		_fail("T0431 camera controls page did not continue to the guarded tower observation step")
		return
	defense_system.debug_destroy_first_device()
	await process_frame
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "tower_destroyed":
		_fail("T1505 tower destruction did not advance the tutorial")
		return

	tutorial.debug_continue()
	for _target in range(4):
		tutorial.debug_press_current_target()
		await process_frame
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "equip_showcase":
		_fail("T1505 guided equipment sequence did not finish")
		return
	tutorial.call("_process", 1.1)
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "alarm":
		_fail("T1505 equipment showcase did not lead to the alarm")
		return
	tutorial.debug_press_current_target()
	await process_frame
	if not str(tutorial.get_tutorial_snapshot().get("step_id", "")).begins_with("battle"):
		_fail("T1505 alarm did not start Ada's battle")
		return
	var battle_overlay: Dictionary = tutorial.get_tutorial_snapshot().get("overlay", {})
	if int(battle_overlay.get("inspection_target_count", 0)) < 1:
		_fail("T1505 battle did not expose any read-only inspection target: %s" % str(battle_overlay))
		return
	tutorial.debug_finish_tutorial_battle()
	await process_frame
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "victory":
		_fail("T1505 battle completion did not open the tutorial victory panel")
		return
	if audio_manager.get_current_music_asset_id() != "music_tutorial_battle":
		_fail("T1505 battle tutorial music did not persist through tutorial victory")
		return
	if (
		not bool(tutorial.get_tutorial_snapshot().get("detached_simulation_running", false))
		or bool(time_system.is_gameplay_paused())
		or not bool(time_system.is_paused)
		or game_state.current_day != 1
		or game_state.current_hour != 1
	):
		_fail("T1505 victory should keep presentation time running while the formal D1 01:00 calendar stays frozen")
		return
	var victory_overlay: Dictionary = tutorial.get_tutorial_snapshot().get("overlay", {})
	var victory_copy: Dictionary = ui_copy.get("victory", {}) as Dictionary
	if (
		str(victory_overlay.get("victory_control_class", "")) != "AcceptDialog"
		or str(victory_overlay.get("victory_title", "")) != str(victory_copy.get("title", ""))
		or str(victory_overlay.get("victory_dialog_text", "")) != str(victory_copy.get("message", ""))
		or str(victory_overlay.get("victory_ok_button_text", "")) != str(victory_copy.get("confirm", ""))
		or Vector2i(victory_overlay.get("victory_configured_size", Vector2i.ZERO)) != Vector2i(520, 160)
		or not bool(victory_overlay.get("victory_exclusive", false))
		or not bool(victory_overlay.get("victory_unresizable", false))
	):
		_fail("T1505 victory prompt does not match the formal wave-cleared dialog: %s" % str(victory_overlay))
		return
	var victory_dialog := root.get_node_or_null("Main/UI/TutorialOverlay/TutorialVictoryDialog") as AcceptDialog
	if victory_dialog == null:
		_fail("T1505 formal-style victory dialog node is missing")
		return
	victory_dialog.get_ok_button().pressed.emit()
	await process_frame
	if victory_dialog.visible:
		_fail("T1505 victory dialog did not close through its real OK button")
		return
	if (
		str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "post_battle"
		or not bool(tutorial.get_tutorial_snapshot().get("detached_simulation_running", false))
		or bool(time_system.is_gameplay_paused())
		or not bool(time_system.is_paused)
		or game_state.current_day != 1
		or game_state.current_hour != 1
	):
		_fail("T1505 post-battle dialogue paused presentation time or advanced the formal calendar")
		return
	var ada_dialogue_overlay: Dictionary = tutorial.get_tutorial_snapshot().get("overlay", {})
	var ada_portrait: Dictionary = ada_dialogue_overlay.get("portrait_snapshot", {})
	var ada_portrait_rect: Rect2 = ada_dialogue_overlay.get("portrait_rect", Rect2())
	var ada_speaker_rect: Rect2 = ada_dialogue_overlay.get("speaker_rect", Rect2())
	if (
		not bool(ada_dialogue_overlay.get("portrait_visible", false))
		or not bool(ada_portrait.get("active", false))
		or not bool(ada_portrait.get("rendering_enabled", false))
		or not bool(ada_portrait.get("shares_main_world", false))
		or not bool(ada_portrait.get("headshot_mode", false))
		or str(ada_portrait.get("target_npc_id", "")) != "veteran_deputy_01"
		or absf(ada_portrait_rect.size.x - ada_portrait_rect.size.y) > 1.0
		or ada_portrait_rect.end.y > ada_speaker_rect.position.y
	):
		_fail("T1505 Ada post-battle dialogue headshot is missing or not square/above her name: %s" % str(ada_dialogue_overlay))
		return
	tutorial.debug_continue()
	await process_frame
	var player_dialogue_overlay: Dictionary = tutorial.get_tutorial_snapshot().get("overlay", {})
	if bool(player_dialogue_overlay.get("portrait_visible", true)):
		_fail("T1505 player post-battle dialogue should hide Ada's headshot")
		return
	tutorial.debug_continue()
	await process_frame
	var resumed_ada_overlay: Dictionary = tutorial.get_tutorial_snapshot().get("overlay", {})
	if not bool(resumed_ada_overlay.get("portrait_visible", false)):
		_fail("T1505 Ada headshot did not return on her next post-battle line")
		return
	for _page in range(3):
		tutorial.debug_continue()
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "ada_return":
		_fail("T1505 post-battle dialogue did not send Ada back to the dormitory")
		return
	tutorial.set("_step_started_msec", Time.get_ticks_msec() - 8100)
	tutorial.call("_process", 0.0)
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "handoff_card":
		_fail("T1505 Ada return wall-clock watchdog did not lead to the handoff card")
		return
	var handoff_overlay: Dictionary = tutorial.get_tutorial_snapshot().get("overlay", {})
	if (
		str(handoff_overlay.get("handoff_text", "")) != str(ui_copy.get("handoff_card", ""))
		or not bool(handoff_overlay.get("handoff_visible", false))
		or int(handoff_overlay.get("handoff_z_index", 0)) != 4095
		or bool(handoff_overlay.get("handoff_z_as_relative", true))
	):
		_fail("T1505 handoff card is not sourced from tutorial_config.json: %s" % str(handoff_overlay))
		return
	var handoff_duration := float(tutorial.get_tutorial_snapshot().get("handoff_card_duration_seconds", 0.0))
	if not is_equal_approx(handoff_duration, 5.0):
		_fail("T1505 handoff card duration should be 5 seconds, got %.2f" % handoff_duration)
		return
	tutorial.call("_process", handoff_duration - 0.2)
	if str(tutorial.get_tutorial_snapshot().get("step_id", "")) != "handoff_card":
		_fail("T1505 handoff card completed before its five-second hold elapsed")
		return
	tutorial.call("_process", 0.21)
	await process_frame
	var handoff: Dictionary = tutorial.get_tutorial_snapshot().get("handoff", {})
	if not bool(handoff.get("ok", false)) or bool(handoff.get("skipped", true)):
		_fail("T1505 normal tutorial handoff failed: %s" % str(handoff))
		return
	var handoff_world_audio: Dictionary = world_audio.get_debug_snapshot()
	if audio_manager.get_current_music_asset_id() not in (handoff_world_audio.get("day_playlist", []) as Array) or not str(handoff_world_audio.get("tutorial_music_cue", "")).is_empty():
		_fail("T1505 handoff did not release tutorial music back to the formal daytime playlist: current=%s world=%s" % [audio_manager.get_current_music_asset_id(), JSON.stringify(handoff_world_audio)])
		return

	var startup_snapshot: Dictionary = startup.debug_get_startup_snapshot()
	if not bool(startup_snapshot.get("formal_loop_started", false)) or str(startup_snapshot.get("tutorial_status", "")) != "completed":
		_fail("T1505 startup did not enter the formal loop after tutorial handoff: %s" % str(startup_snapshot))
		return
	if bool(time_system.is_paused) or not bool(daily_plan_system.auto_execution_enabled) or game_state.current_day != 1 or game_state.current_hour != 6:
		_fail("T1505 formal handoff must resume at D1 06:00")
		return
	for raw_npc_id in npc_system.get_npc_ids():
		var board_npc_id := str(raw_npc_id)
		var notice_count := 0
		var schedule_count := 0
		for event in memory_system.get_npc_witness_events(board_npc_id):
			if str(event.get("payload", {}).get("reason", "")) != "initial_notice_board_state":
				continue
			match str(event.get("type", "")):
				"plaza_notice_changed":
					notice_count += 1
				"plaza_schedule_changed":
					schedule_count += 1
		if notice_count != 1 or schedule_count != 1:
			_fail("T1505 formal-loop notice board was not broadcast exactly once to %s: notice=%d schedule=%d" % [board_npc_id, notice_count, schedule_count])
			return
	if not defense_system.get_deployments().is_empty() or resource_system.get_resource("item_wall_arrow_tower") != 0 or resource_system.get_resource("item_sword_shield") != 0:
		_fail("T1505 temporary tutorial resources leaked into formal gameplay: %s" % str(resource_system.get_resource_snapshot()))
		return
	var ada_state: Dictionary = npc_system.get_npc_state("veteran_deputy_01")
	var ada_equipment: Dictionary = equipment_system.get_equipment_snapshot("veteran_deputy_01")
	if int(ada_state.get("hp", 0)) != int(ada_state.get("max_hp", -1)) or str((ada_equipment.get("main_weapon", {}) as Dictionary).get("id", "")) != "sword_shield":
		_fail("T1505 Ada's formal HP or story equipment baseline was not restored")
		return
	var expected_beds := {
		"veteran_deputy_01": "dormitory_bed_01",
		"stableman_01": "dormitory_bed_02",
		"cook_01": "dormitory_bed_03",
		"gardener_01": "dormitory_bed_04",
		"blacksmith_01": "dormitory_bed_05",
		"engineer_01": "dormitory_bed_06",
		"priest_01": "dormitory_bed_07",
		"doctor_01": "dormitory_bed_08"
	}
	var formal_start_beds: Dictionary = handoff.get("formal_start_beds", {})
	var bed_items: Dictionary = formal_start_beds.get("items", {})
	var formal_start_positions: Dictionary = handoff.get("formal_start_positions", {})
	var position_items: Dictionary = formal_start_positions.get("items", {})
	if (
		not bool(formal_start_beds.get("ok", false))
		or not bool(formal_start_positions.get("ok", false))
		or bed_items.size() != expected_beds.size()
		or position_items.size() != expected_beds.size()
	):
		_fail("T1505 formal start did not stage all eight assigned beds: %s" % str(formal_start_beds))
		return
	for raw_npc_id in expected_beds.keys():
		var npc_id := str(raw_npc_id)
		var bed_item: Dictionary = bed_items.get(npc_id, {})
		var position_item: Dictionary = position_items.get(npc_id, {})
		var staged_position: Vector3 = position_item.get("world_position", Vector3.INF)
		var current_position: Vector3 = npc_system.get_npc_world_position(npc_id)
		if (
			str(bed_item.get("workstation_id", "")) != str(expected_beds[npc_id])
			or staged_position == Vector3.INF
			or current_position.distance_to(staged_position) > 2.5
		):
			_fail("T1505 formal start position did not originate at %s's assigned bed: %s / %s / current=%s" % [npc_id, str(bed_item), str(position_item), str(current_position)])
			return
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var plan: Array = daily_plan_system.get_npc_daily_plan(npc_id)
		if plan.size() != 24:
			_fail("T1505 formal preset plan is incomplete for %s" % npc_id)
			return
		for raw_item in plan:
			if str((raw_item as Dictionary).get("source", "")) != "tutorial_day1_preset":
				_fail("T1505 formal preset plan source drifted for %s" % npc_id)
				return
		for hour in range(19, 22):
			var evening_item: Dictionary = plan[hour]
			var evening_action_id := str(evening_item.get("action_id", ""))
			if evening_action_id == "idle":
				_fail("T1505 formal preset still contains evening idle for %s at %d:00" % [npc_id, hour])
				return
			if evening_action_id in ["talk_to_npc", "visit_location"]:
				var target: Dictionary = evening_item.get("target", {}) if evening_item.get("target", {}) is Dictionary else {}
				if str(target.get("target_id", "")).is_empty():
					_fail("T1505 targeted evening action lost its target for %s at %d:00" % [npc_id, hour])
					return
	var priest_plan: Array = daily_plan_system.get_npc_daily_plan("priest_01")
	for work_hour in [7, 8, 9, 10, 11, 13, 14, 15, 16]:
		if str((priest_plan[work_hour] as Dictionary).get("action_id", "")) != "work_tavern":
			_fail("T1505 Marcel did not brew during the expected first-day work hour %d" % work_hour)
			return
	if str((priest_plan[19] as Dictionary).get("action_id", "")) != "lead_mass":
		_fail("T1505 Marcel did not lead the 19:00 mass")
		return
	var diary: Array = (npc_system.get_npc("veteran_deputy_01").get("diary", []) as Array)
	var tutorial_diary := _find_prologue_diary(diary)
	if tutorial_diary.is_empty():
		_fail("T1505 Ada's tutorial diary seed is missing")
		return
	if (
		int(tutorial_diary.get("day", -1)) != 0
		or str(tutorial_diary.get("time", "")) != "02:00:00"
		or str(tutorial_diary.get("record_label", "")) != "接到守备命令的前一天"
	):
		_fail("T1505 Ada's tutorial diary chronology drifted: %s" % str(tutorial_diary))
		return
	var diary_count_before_repeat := diary.size()
	var repeat_handoff: Dictionary = tutorial.debug_skip_tutorial()
	if not bool(repeat_handoff.get("ok", false)) or (npc_system.get_npc("veteran_deputy_01").get("diary", []) as Array).size() != diary_count_before_repeat:
		_fail("T1505 repeated handoff was not idempotent: %s" % str(repeat_handoff))
		return
	for event in memory_system.get_all_events():
		if str(event.get("type", "")) in ["defense_device_deployed", "defense_device_triggered", "equipment_changed", "equipment_given", "combat_started", "combat_ended"]:
			_fail("T1505 temporary tutorial event leaked into the formal archive: %s" % str(event))
			return
	if not await _verify_overlay_resolutions():
		return

	print("T1505 tutorial full-flow verification passed.")
	quit(0)


func _verify_overlay_resolutions() -> bool:
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var overlay := TutorialOverlayClass.new()
	viewport.add_child(overlay)
	await process_frame
	var continue_probe := {"count": 0}
	overlay.continue_requested.connect(func() -> void: continue_probe["count"] = int(continue_probe["count"]) + 1)
	for viewport_size in [Vector2i(1024, 768), Vector2i(1280, 800), Vector2i(1920, 800), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		viewport.size = viewport_size
		overlay.begin()
		overlay.show_page({"speaker": "ada", "speaker_name": "艾达", "text": "多分辨率布局校验"}, true)
		overlay.set("_startup_input_guard_until_msec", Time.get_ticks_msec() - 1)
		overlay.call("_process", 0.0)
		overlay.set_top_hint("短提示")
		await process_frame
		var snapshot: Dictionary = overlay.get_debug_snapshot()
		var conversation := snapshot.get("conversation_rect", Rect2()) as Rect2
		var speaker := snapshot.get("speaker_rect", Rect2()) as Rect2
		var skip := snapshot.get("skip_rect", Rect2()) as Rect2
		if not _rect_inside_viewport(conversation, viewport_size) or not _rect_inside_viewport(skip, viewport_size):
			_fail("T1505 overlay escaped viewport at %s: %s" % [str(viewport_size), str(snapshot)])
			return false
		if int(snapshot.get("skip_z_index", 0)) != 4096 or bool(snapshot.get("skip_z_as_relative", true)) or not bool(snapshot.get("skip_is_front_child", false)):
			_fail("T1505 skip button is not on the top interaction layer at %s: %s" % [str(viewport_size), str(snapshot)])
			return false
		if bool(snapshot.get("top_hint_visible", true)):
			_fail("T1505 removed top hint became visible at %s: %s" % [str(viewport_size), str(snapshot)])
			return false
		if bool(snapshot.get("portrait_visible", false)) or bool(snapshot.get("player_emblem_visible", false)):
			_fail("T1505 removed dialogue artwork became visible at %s" % str(viewport_size))
			return false
		if str(snapshot.get("speaker_text", "")) != "艾达" or str(snapshot.get("dialogue_text", "")) != "“多分辨率布局校验”":
			_fail("T1505 Ada dialogue format is incorrect at %s: %s" % [str(viewport_size), str(snapshot)])
			return false
		if speaker.position.x > conversation.position.x + conversation.size.x * 0.04:
			_fail("T1505 Ada text is not left aligned at %s" % str(viewport_size))
			return false
		if not is_zero_approx(float(snapshot.get("conversation_alpha", 1.0))):
			_fail("T1505 removed conversation panel is still visible at %s" % str(viewport_size))
			return false
		var expected_scale := clampf(float(viewport_size.y) / 900.0, 1.0, 1.5)
		if not is_equal_approx(float(snapshot.get("responsive_font_scale", 0.0)), expected_scale):
			_fail("T1505 responsive font scale is incorrect at %s: %s" % [str(viewport_size), str(snapshot)])
			return false
		if viewport_size == Vector2i(1920, 1080):
			var dialogue_font_size := int(snapshot.get("dialogue_font_size", 0))
			if dialogue_font_size < 25 or dialogue_font_size > 27:
				_fail("T1505 maximized 1080p dialogue did not use the reduced size: %s" % str(snapshot))
				return false
		var continue_rect := snapshot.get("continue_rect", Rect2()) as Rect2
		if (
			str(snapshot.get("continue_text", "")) != "点击继续"
			or not str(snapshot.get("blocker_tooltip", "x")).is_empty()
			or not bool(snapshot.get("full_screen_continue_enabled", false))
			or continue_rect.end.x < conversation.end.x - conversation.size.x * 0.02
			or continue_rect.end.y < conversation.end.y - conversation.size.y * 0.02
		):
			_fail("T1505 comic continue affordance is incorrect at %s: %s" % [str(viewport_size), str(snapshot)])
			return false
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		var count_before_click := int(continue_probe["count"])
		overlay.call("_on_blocker_gui_input", click)
		if int(continue_probe["count"]) != count_before_click + 1:
			_fail("T1505 comic full-screen click did not request continue at %s" % str(viewport_size))
			return false
		overlay.show_page({"speaker": "player", "speaker_name": "守备官", "text": "多分辨率布局校验"}, false)
		await process_frame
		snapshot = overlay.get_debug_snapshot()
		var count_before_non_comic_click := int(continue_probe["count"])
		overlay.call("_on_blocker_gui_input", click)
		if (
			int(continue_probe["count"]) != count_before_non_comic_click + 1
			or not bool(snapshot.get("full_screen_continue_enabled", false))
			or not str(snapshot.get("blocker_tooltip", "x")).is_empty()
		):
			_fail("T1505 3D continue page did not accept a full-screen click at %s: %s" % [str(viewport_size), str(snapshot)])
			return false
		speaker = snapshot.get("speaker_rect", Rect2()) as Rect2
		if str(snapshot.get("speaker_text", "")) != "守备官" or str(snapshot.get("dialogue_text", "")) != "“多分辨率布局校验”":
			_fail("T1505 player dialogue format is incorrect at %s: %s" % [str(viewport_size), str(snapshot)])
			return false
		if speaker.end.x < conversation.end.x - conversation.size.x * 0.04:
			_fail("T1505 player text is not right aligned at %s: %s" % [str(viewport_size), str(snapshot)])
			return false
		overlay.show_instruction("必须完成指定操作", "强制操作")
		await process_frame
		snapshot = overlay.get_debug_snapshot()
		var count_before_instruction_click := int(continue_probe["count"])
		overlay.call("_on_blocker_gui_input", click)
		if (
			int(continue_probe["count"]) != count_before_instruction_click
			or bool(snapshot.get("full_screen_continue_enabled", true))
			or not str(snapshot.get("blocker_tooltip", "x")).is_empty()
		):
			_fail("T1505 forced 3D instruction accepted a background click at %s: %s" % [str(viewport_size), str(snapshot)])
			return false
		overlay.show_page({"speaker": "system", "speaker_name": "系统", "text": "系统提示"}, false)
		await process_frame
		snapshot = overlay.get_debug_snapshot()
		if bool(snapshot.get("speaker_visible", true)) or str(snapshot.get("speaker_text", "x")) != "" or str(snapshot.get("dialogue_text", "")) != ">系统提示<":
			_fail("T1505 system message format is incorrect at %s: %s" % [str(viewport_size), str(snapshot)])
			return false
		if int(snapshot.get("dialogue_alignment", -1)) != HORIZONTAL_ALIGNMENT_CENTER:
			_fail("T1505 system message is not centered at %s" % str(viewport_size))
			return false
	viewport.queue_free()
	await process_frame
	return true


func _rect_inside_viewport(rect: Rect2, viewport_size: Vector2i) -> bool:
	return (
		rect.size.x > 0.0 and rect.size.y > 0.0
		and rect.position.x >= -0.5 and rect.position.y >= -0.5
		and rect.end.x <= float(viewport_size.x) + 0.5
		and rect.end.y <= float(viewport_size.y) + 0.5
	)


func _find_prologue_diary(diary: Array) -> Dictionary:
	for raw_record in diary:
		if (
			raw_record is Dictionary
			and str((raw_record as Dictionary).get("source", "")) == "initial_long_memory"
			and str((raw_record as Dictionary).get("record_label", "")) == "接到守备命令的前一天"
			and str((raw_record as Dictionary).get("time", "")) == "02:00:00"
		):
			return (raw_record as Dictionary).duplicate(true)
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _make_key_event(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	return event
