extends SceneTree

const SPECIFIC_ITEM_IDS := [
	"item_sword_shield",
	"item_polearm",
	"item_bow",
	"item_crossbow",
	"item_iron_helmet",
	"item_mail_chest",
	"item_iron_bracers",
	"item_iron_greaves",
	"item_arrow_bundle",
	"item_wall_ballista",
	"item_wall_arrow_tower"
]
const LEGACY_AGGREGATE_IDS := ["weapons", "armor", "defense_devices", "horse_readiness"]


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var gm_button := root.get_node_or_null("Main/UI/GMPanel/GMButton") as Button
	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as PanelContainer
	var llm_usage_summary_label := gm_window.find_child("LLMUsageSummaryLabel", true, false) as Label
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var daily_reflection_system := root.get_node_or_null("Main/Systems/DailyReflectionSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var piety_system := root.get_node_or_null("Main/Systems/PietySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var game_state := root.get_node_or_null("GameState")
	if (
		gm_panel == null
		or gm_button == null
		or gm_window == null
		or llm_usage_summary_label == null
		or resource_system == null
		or building_system == null
		or npc_system == null
		or action_system == null
		or memory_system == null
		or llm_bridge == null
		or equipment_system == null
		or daily_plan_system == null
		or daily_reflection_system == null
		or combat_system == null
		or crafting_system == null
		or horse_system == null
		or piety_system == null
		or time_system == null
		or game_state == null
	):
		push_error("GM verification required nodes not found")
		quit(1)
		return

	# Keep this broad UI/command regression offline and deterministic. The dedicated
	# real-provider suites own real LLM acceptance; an unsupported scheme makes any
	# accidental request fail synchronously into the explicit rule/template path.
	if llm_bridge.has_method("set_backend_base_url"):
		llm_bridge.set_backend_base_url("gm-verify-invalid://backend")
	llm_bridge.request_timeout_seconds = 0.2

	if not gm_panel.visible:
		push_error("GMPanel should be visible while GM_ENABLED is true")
		quit(1)
		return
	if gm_button.text != "GM":
		push_error("GM button was not created")
		quit(1)
		return
	if gm_window.visible:
		push_error("GM window should be hidden before the GM button is pressed")
		quit(1)
		return

	gm_button.pressed.emit()
	if not gm_window.visible:
		push_error("GM button did not open the GM window")
		quit(1)
		return
	gm_panel._on_llm_usage_response_received({
		"ok": true,
		"body": {
			"summary": {
				"provider_usage": {
					"session": {
						"input_tokens": 1234,
						"output_tokens": 56,
						"total_tokens": 1290,
						"estimated_cost_cny": 0.1234
					},
					"daily": {
						"estimated_cost_cny": 3.21
					},
					"daily_limit_cny": 20.0
				}
			}
		}
	})
	if (
		"1,290 tokens" not in llm_usage_summary_label.text
		or "今日：¥3.2100 / ¥20.00" not in llm_usage_summary_label.text
	):
		push_error("GM top usage summary did not render session tokens and daily CNY budget")
		quit(1)
		return
	if not _panel_inside_viewport(gm_window, gm_panel._get_usable_viewport_size()):
		push_error("GM window should stay inside the viewport after opening. panel=%s viewport=%s" % [
			str(gm_window.get_global_rect()),
			str(gm_panel._get_usable_viewport_size())
		])
		quit(1)
		return
	if not _panel_tracks_button(gm_window, gm_button):
		push_error("GM window should open near the GM button")
		quit(1)
		return
	var viewport_size: Vector2 = gm_panel._get_usable_viewport_size()
	gm_button.position = Vector2(
		maxf(0.0, viewport_size.x - gm_button.size.x - 4.0),
		maxf(0.0, viewport_size.y - gm_button.size.y - 4.0)
	)
	gm_panel._position_panel_near_button()
	await process_frame
	if not _panel_inside_viewport(gm_window, viewport_size):
		push_error("GM window should remain inside the viewport when the GM button is near the edge")
		quit(1)
		return
	var repair_building_select := gm_window.find_child("RepairBuildingSelect", true, false) as OptionButton
	var assist_repair_button := gm_window.find_child("AssistRepairButton", true, false) as Button
	if repair_building_select == null or assist_repair_button == null:
		push_error("GM assist repair controls should include a target building selector and button")
		quit(1)
		return
	var upgrade_building_select := gm_window.find_child("UpgradeBuildingSelect", true, false) as OptionButton
	var assist_upgrade_button := gm_window.find_child("AssistUpgradeButton", true, false) as Button
	if upgrade_building_select == null or assist_upgrade_button == null:
		push_error("GM assist upgrade controls should include a target building selector and button")
		quit(1)
		return
	var action_select := gm_window.find_child("ActionSelect", true, false) as OptionButton
	var assign_action_button := gm_window.find_child("AssignActionButton", true, false) as Button
	if action_select == null or assign_action_button == null:
		push_error("GM action controls should keep action selector and assign button")
		quit(1)
		return
	if _select_option_by_id(action_select, "attend_mass"):
		push_error("GM action selector should not expose removed attend_mass")
		quit(1)
		return
	if not _select_option_by_id(action_select, "pray_at_chapel"):
		push_error("GM action selector should expose merged pray_at_chapel")
		quit(1)
		return
	for redundant_text in ["工作", "当教官", "当受训者", "吃饭", "睡觉"]:
		if _has_button_text(gm_window, redundant_text):
			push_error("GM action section should not keep redundant '%s' button" % redundant_text)
			quit(1)
			return
	if not _select_option_by_id(repair_building_select, "wall"):
		push_error("GM repair target selector should include wall")
		quit(1)
		return
	if not _select_option_by_id(upgrade_building_select, "garden"):
		push_error("GM upgrade target selector should include garden")
		quit(1)
		return
	var equipment_weapon_select := gm_window.find_child("EquipmentWeaponSelect", true, false) as OptionButton
	var equipment_armor_slot_select := gm_window.find_child("EquipmentArmorSlotSelect", true, false) as OptionButton
	if equipment_weapon_select == null or equipment_armor_slot_select == null:
		push_error("GM equipment controls should include weapon and armor slot selectors")
		quit(1)
		return
	var resource_select := gm_window.find_child("ResourceSelect", true, false) as OptionButton
	var crafting_building_select := gm_window.find_child("CraftingBuildingSelect", true, false) as OptionButton
	var crafting_recipe_select := gm_window.find_child("CraftingRecipeSelect", true, false) as OptionButton
	var horse_select := gm_window.find_child("HorseSelect", true, false) as OptionButton
	if resource_select == null or crafting_building_select == null or crafting_recipe_select == null or horse_select == null:
		push_error("GM crafting/horse controls should expose resource, building, recipe and horse selectors")
		quit(1)
		return
	for item_id in SPECIFIC_ITEM_IDS:
		if not _select_option_by_id(resource_select, item_id):
			push_error("GM resource selector should include concrete item inventory: %s" % item_id)
			quit(1)
			return
	for aggregate_id in LEGACY_AGGREGATE_IDS:
		if _select_option_by_id(resource_select, aggregate_id):
			push_error("GM resource selector should hide deprecated aggregate inventory: %s" % aggregate_id)
			quit(1)
			return
	if not _select_option_by_id(crafting_building_select, "blacksmith"):
		push_error("GM crafting building selector should include blacksmith")
		quit(1)
		return
	gm_panel._fill_crafting_recipe_select()
	if not _select_option_by_id(crafting_recipe_select, "craft_iron_helmet"):
		push_error("GM crafting recipe selector should include blacksmith recipes")
		quit(1)
		return
	if not _select_option_by_id(horse_select, "horse_chestnut_wind"):
		push_error("GM horse selector should include the configured initial horses")
		quit(1)
		return
	if _has_button_text(gm_window, "装备坐骑"):
		push_error("GM panel should replace the deprecated generic mount button with horse assignment")
		quit(1)
		return
	var recruit_button := gm_window.find_child("RecruitNpcButton", true, false) as Button
	if recruit_button == null:
		push_error("GM NPC section should include a recruit button")
		quit(1)
		return
	var generate_plan_button := gm_window.find_child("GeneratePlanButton", true, false) as Button
	var execute_plan_button := gm_window.find_child("ExecutePlanButton", true, false) as Button
	var show_plan_button := gm_window.find_child("ShowPlanButton", true, false) as Button
	var revise_plan_button := gm_window.find_child("RevisePlanButton", true, false) as Button
	if generate_plan_button == null or execute_plan_button == null or show_plan_button == null or revise_plan_button == null:
		push_error("GM NPC section should include daily plan and reevaluation buttons")
		quit(1)
		return
	var reflect_npc_button := gm_window.find_child("ReflectNpcButton", true, false) as Button
	var long_memory_button := gm_window.find_child("LongMemoryButton", true, false) as Button
	var last_reflection_button := gm_window.find_child("LastReflectionButton", true, false) as Button
	if reflect_npc_button == null or long_memory_button == null or last_reflection_button == null:
		push_error("GM NPC section should include daily reflection buttons")
		quit(1)
		return
	if not _select_option_by_id(equipment_weapon_select, "bow"):
		push_error("GM weapon selector should include bow")
		quit(1)
		return
	if not _select_option_by_id(equipment_armor_slot_select, "chest"):
		push_error("GM armor selector should include chest")
		quit(1)
		return
	var combat_wave_select := gm_window.find_child("CombatWaveSelect", true, false) as OptionButton
	var spawn_first_wave_button := gm_window.find_child("SpawnFirstWaveButton", true, false) as Button
	var trigger_next_wave_button := gm_window.find_child("TriggerNextWaveButton", true, false) as Button
	var step_enemy_ai_button := gm_window.find_child("StepEnemyAIButton", true, false) as Button
	if combat_wave_select == null or spawn_first_wave_button == null or trigger_next_wave_button == null or step_enemy_ai_button == null:
		push_error("GM combat section should include wave selector, first-wave spawn button, next-wave button and enemy AI step button")
		quit(1)
		return
	if not _select_option_by_id(combat_wave_select, "1"):
		push_error("GM combat wave selector should include wave 1")
		quit(1)
		return
	var fill_piety_button := gm_window.find_child("FillPietyButton", true, false) as Button
	var piety_snapshot_button := gm_window.find_child("PietySnapshotButton", true, false) as Button
	if fill_piety_button == null or piety_snapshot_button == null:
		push_error("GM combat section should expose piety fill and meteor snapshot controls")
		quit(1)
		return
	fill_piety_button.pressed.emit()
	if not bool(piety_system.is_ready_to_cast()):
		push_error("GM fill-piety button did not charge the meteor ability")
		quit(1)
		return
	gm_panel._execute_command("piety_set 25")
	if not is_equal_approx(float(piety_system.get_current_piety()), 25.0):
		push_error("GM piety_set command failed")
		quit(1)
		return
	gm_panel._execute_command("piety_snapshot")
	if not str(gm_panel._help_text()).contains("piety_fill"):
		push_error("GM help should expose piety and meteor verification commands")
		quit(1)
		return

	var money_before := int(resource_system.get_resource("money"))
	gm_panel._execute_command("add_resource money 3")
	if int(resource_system.get_resource("money")) != money_before + 3:
		push_error("GM add_resource command failed")
		quit(1)
		return

	var helmet_stock_before := int(resource_system.get_resource("item_iron_helmet"))
	resource_system.add_resource("iron", 2)
	gm_panel._execute_command("craft_target blacksmith craft_iron_helmet")
	var blacksmith_project: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	if str(blacksmith_project.get("target_recipe_id", "")) != "craft_iron_helmet":
		push_error("GM craft_target command should set the blacksmith project")
		quit(1)
		return
	gm_panel._execute_command("craft_stage blacksmith gm_verify")
	blacksmith_project = crafting_system.get_project_snapshot("blacksmith")
	if int(blacksmith_project.get("completed_stages", 0)) != 1:
		push_error("GM craft_stage command should complete exactly one stage")
		quit(1)
		return
	gm_panel._execute_command("craft_snapshot blacksmith")
	var helmet_recipe: Dictionary = crafting_system.get_recipe("craft_iron_helmet")
	var helmet_stage_count := (helmet_recipe.get("stages", []) as Array).size()
	for _stage_index in range(1, helmet_stage_count):
		gm_panel._execute_command("craft_stage blacksmith gm_verify")
	if int(resource_system.get_resource("item_iron_helmet")) != helmet_stock_before + 1:
		push_error("GM craft_stage should add the concrete finished item after the final stage")
		quit(1)
		return
	blacksmith_project = crafting_system.get_project_snapshot("blacksmith")
	if int(blacksmith_project.get("completed_stages", -1)) != 0:
		push_error("Completed crafting product should retain the target and reset integer stages")
		quit(1)
		return

	var wall_before := int(building_system.get_building("wall").get("hp", 0))
	gm_panel._execute_command("damage_building wall 5")
	if int(building_system.get_building("wall").get("hp", 0)) != maxi(0, wall_before - 5):
		push_error("GM damage_building command failed")
		quit(1)
		return
	if not building_system.repair_building("wall"):
		push_error("Failed to start wall repair for GM assist test")
		quit(1)
		return
	if bool(npc_system.get_npc("priest_01").get("recruited", false)):
		push_error("Priest should start unrecruited for GM recruit test")
		quit(1)
		return
	if not _select_option_by_id(gm_panel._npc_select, "priest_01"):
		push_error("GM NPC selector should include priest_01")
		quit(1)
		return
	recruit_button.pressed.emit()
	await process_frame
	if not bool(npc_system.get_npc("priest_01").get("recruited", false)):
		push_error("GM recruit button should set selected NPC recruited")
		quit(1)
		return
	var priest_order: Dictionary = npc_system.debug_publish_npc_order("priest_01", "协助守备。")
	if not bool(priest_order.get("ok", false)):
		push_error("GM-recruited NPC should be able to receive orders")
		quit(1)
		return
	if not _select_option_by_id(gm_panel._npc_select, "engineer_01"):
		push_error("GM NPC selector should include engineer_01")
		quit(1)
		return
	if not npc_system.debug_enter_location_immediately("engineer_01", "plaza"):
		push_error("Failed to place engineer at plaza for GM assist test")
		quit(1)
		return
	assist_repair_button.pressed.emit()
	if not await _wait_until_action_result(npc_system, "engineer_01", "assist_repair_started_wall"):
		push_error("GM assist repair button did not use the selected repair target building")
		quit(1)
		return
	if not building_system.upgrade_building("garden"):
		push_error("Failed to start garden upgrade for GM assist test")
		quit(1)
		return
	if not _select_option_by_id(gm_panel._npc_select, "doctor_01"):
		push_error("GM NPC selector should include doctor_01")
		quit(1)
		return
	if not npc_system.debug_enter_location_immediately("doctor_01", "plaza"):
		push_error("Failed to place doctor at plaza for GM assist upgrade test")
		quit(1)
		return
	assist_upgrade_button.pressed.emit()
	if not await _wait_until_action_result(npc_system, "doctor_01", "assist_upgrade_started_garden"):
		push_error("GM assist upgrade button did not use the selected upgrade target building")
		quit(1)
		return

	gm_panel._execute_command("set_time 2 9 10 11")
	gm_panel._execute_command("time_snapshot")
	if (
		int(game_state.current_day) != 2
		or int(game_state.current_hour) != 9
		or int(game_state.current_minute) != 10
		or int(game_state.current_second) != 11
	):
		push_error("GM set_time command failed")
		quit(1)
		return

	gm_panel._execute_command("enter_location cook_01 dining_hall")
	var cook_state: Dictionary = npc_system.get_npc_state("cook_01")
	if str(cook_state.get("current_location", "")) != "dining_hall":
		push_error("GM enter_location command failed")
		quit(1)
		return

	var event_count_before := int(memory_system.get_event_count())
	gm_panel._execute_command("give_money cook_01 2 local_public")
	if int(memory_system.get_event_count()) <= event_count_before:
		push_error("GM give_money command did not write an event")
		quit(1)
		return

	gm_panel._execute_command("attack_npc stableman_01 150 local_public")
	var stableman_state: Dictionary = npc_system.get_npc_state("stableman_01")
	if int(stableman_state.get("hp", -1)) != 0 or not bool(stableman_state.get("unconscious", false)):
		push_error("GM attack_npc command should deduct HP and set unconscious")
		quit(1)
		return
	var stableman_revive_hp := int(ceil(float(stableman_state.get("max_hp", 100)) * 0.3))
	var stableman_recovery_seconds := int(ceil(float(stableman_revive_hp) * 3600.0 / 2.0))
	gm_panel._execute_command("recover_npc stableman_01 %d" % stableman_recovery_seconds)
	stableman_state = npc_system.get_npc_state("stableman_01")
	if int(stableman_state.get("hp", -1)) != stableman_revive_hp or bool(stableman_state.get("unconscious", true)):
		push_error("GM recover_npc command should advance natural recovery and revive NPC")
		quit(1)
		return

	gm_panel._execute_command("plaza_notice Verify GM panel")
	var plaza_snapshot: Dictionary = memory_system.debug_get_location_snapshot("plaza")
	if str(plaza_snapshot.get("current_notice", "")) != "Verify GM panel":
		push_error("GM plaza_notice command failed")
		quit(1)
		return

	gm_panel._execute_command("memory cook_01")
	gm_panel._execute_command("location plaza")
	gm_panel._execute_command("events")
	gm_panel._execute_command("publish_order veteran_deputy_01 Hold the gate")
	if str(npc_system.get_current_order("veteran_deputy_01").get("text", "")) != "Hold the gate":
		push_error("GM publish_order command failed")
		quit(1)
		return
	gm_panel._execute_command("order veteran_deputy_01")
	gm_panel._execute_command("plan_request")
	if not str(gm_panel._help_text()).contains("dialogue_carryover"):
		push_error("GM help should expose the daily-plan dialogue carryover snapshot")
		quit(1)
		return
	gm_panel._execute_command("dialogue_carryover")
	gm_panel._execute_command("plan_generate veteran_deputy_01")
	gm_panel._execute_command("plan_generate_rule veteran_deputy_01")
	if npc_system.get_npc_plan("veteran_deputy_01").size() != 24:
		push_error("GM plan_generate_rule command should write a deterministic 24-hour plan")
		quit(1)
		return
	gm_panel._execute_command("plan veteran_deputy_01")
	gm_panel._execute_command("plan_execute veteran_deputy_01")
	gm_panel._execute_command("plan_revise veteran_deputy_01 gm_manual")
	var plan_result: Dictionary = daily_plan_system.get_last_reevaluation_result()
	if str(plan_result.get("npc_id", "")) != "veteran_deputy_01":
		push_error("GM plan_revise command should update DailyPlanSystem reevaluation result")
		quit(1)
		return
	action_system.interrupt_npc_action("veteran_deputy_01", "gm_plan_verify_cleanup")
	llm_bridge.debug_build_npc_context("veteran_deputy_01", "gm_verify")
	gm_panel._execute_command("last_order_injection")
	var injection: Dictionary = llm_bridge.get_last_npc_context_injection()
	if str(injection.get("npc_id", "")) != "veteran_deputy_01" or str(injection.get("current_order", {}).get("text", "")) != "Hold the gate":
		push_error("GM last_order_injection command did not expose the latest current_order")
		quit(1)
		return
	gm_panel._execute_command("station_context")
	var station_context: Dictionary = llm_bridge.debug_build_station_context()
	if (
		(station_context.get("building_roster", []) as Array).is_empty()
		or (station_context.get("work_mode_actions", []) as Array).is_empty()
		or (station_context.get("basic_resource_reserves", []) as Array).size() != 5
		or (station_context.get("station_rules", []) as Array).is_empty()
	):
		push_error("GM station_context command did not expose the expanded station context")
		quit(1)
		return

	var cook_diary_count_before := (
		npc_system.get_npc_long_memory("cook_01").get("diary", []) as Array
	).size()
	gm_panel._execute_command("reflect_npc cook_01 force")
	if not await _wait_for_reflection(
		npc_system,
		llm_bridge,
		"cook_01",
		cook_diary_count_before + 1
	):
		quit(1)
		return
	var cook_long_memory: Dictionary = npc_system.get_npc_long_memory("cook_01")
	if (cook_long_memory.get("diary", []) as Array).is_empty():
		push_error("GM reflect_npc command should write a diary entry")
		quit(1)
		return
	gm_panel._execute_command("long_memory cook_01")
	var long_memory_output := str(gm_panel._result_text.text)
	if not long_memory_output.contains("\"confidence\"") or not long_memory_output.contains("\"time\""):
		push_error("GM long_memory must retain raw confidence/time metadata even when NPCPanel hides it")
		quit(1)
		return
	gm_panel._execute_command("reflection_result")
	var reflection_result: Dictionary = daily_reflection_system.get_last_reflection_result()
	if str(reflection_result.get("npc_id", "")) != "cook_01":
		push_error("GM reflection_result should expose the latest reflection result")
		quit(1)
		return

	resource_system.add_resource("item_bow", 2)
	resource_system.add_resource("item_mail_chest", 1)
	gm_panel._execute_command("equip_weapon veteran_deputy_01 bow local_public")
	if str(equipment_system.get_npc_unit_type("veteran_deputy_01")) != "archer":
		push_error("GM equip_weapon command should equip bow and classify archer")
		quit(1)
		return
	gm_panel._execute_command("equip_armor veteran_deputy_01 chest local_public")
	if str(npc_system.get_npc("veteran_deputy_01").get("equipment", {}).get("chest", {}).get("id", "")) != "mail_chest":
		push_error("GM equip_armor command should equip chest armor")
		quit(1)
		return
	var horse_id := "horse_chestnut_wind"
	var horse_before: Dictionary = horse_system.get_horse_snapshot(horse_id)
	gm_panel._execute_command("horse_snapshot %s" % horse_id)
	gm_panel._execute_command("horse_damage %s 5" % horse_id)
	var horse_after_damage: Dictionary = horse_system.get_horse_snapshot(horse_id)
	if float(horse_after_damage.get("hp", 0.0)) >= float(horse_before.get("hp", 0.0)):
		push_error("GM horse_damage command should apply damage through HorseSystem")
		quit(1)
		return
	var satiety_before_advance := float(horse_after_damage.get("satiety", 0.0))
	gm_panel._execute_command("horse_advance 60")
	if float(horse_system.get_horse_snapshot(horse_id).get("satiety", 0.0)) >= satiety_before_advance:
		push_error("GM horse_advance command should advance horse ecology")
		quit(1)
		return
	var horse_count_before_birth := int(horse_system.get_horse_count())
	gm_panel._execute_command("horse_birth")
	if int(horse_system.get_horse_count()) != horse_count_before_birth + 1:
		push_error("GM horse_birth command should call HorseSystem.debug_force_birth")
		quit(1)
		return
	gm_panel._execute_command("horse_assign veteran_deputy_01 %s local_public" % horse_id)
	if str(equipment_system.get_npc_unit_type("veteran_deputy_01")) != "mounted_ranged":
		push_error("GM horse_assign command should assign a concrete horse and update unit type")
		quit(1)
		return
	if str(horse_system.get_horse_snapshot(horse_id).get("assigned_npc_id", "")) != "veteran_deputy_01":
		push_error("GM horse_assign should update the HorseSystem assignment fact")
		quit(1)
		return
	gm_panel._execute_command("horse_unassign veteran_deputy_01 local_public")
	if not str(horse_system.get_horse_snapshot(horse_id).get("assigned_npc_id", "")).is_empty():
		push_error("GM horse_unassign should clear the concrete horse assignment")
		quit(1)
		return
	if str(equipment_system.get_npc_unit_type("veteran_deputy_01")) != "archer":
		push_error("GM horse_unassign should clear the NPC mount projection")
		quit(1)
		return
	gm_panel._execute_command("unit_type veteran_deputy_01")
	gm_panel._execute_command("clear_enemies")
	time_system.set_time_scale(4.0)
	gm_panel._execute_command("spawn_wave 1")
	if combat_system.get_active_enemy_count() <= 0:
		push_error("GM spawn_wave command should spawn enemies")
		quit(1)
		return
	if not time_system.has_time_scale_cap("combat_enemy_presence") or absf(float(time_system.get_effective_time_scale()) - 1.0) > 0.001:
		push_error("GM-spawned enemies should cap TimeSystem effective scale to x1")
		quit(1)
		return
	gm_panel._execute_command("enemies")
	gm_panel._execute_command("time_snapshot")
	gm_panel._execute_command("step_enemies 1")
	if (combat_system.debug_get_combat_snapshot().get("enemy_targets", []) as Array).is_empty():
		push_error("GM step_enemies command should expose enemy target state")
		quit(1)
		return
	gm_panel._execute_command("clear_enemies")
	if time_system.has_time_scale_cap("combat_enemy_presence") or absf(float(time_system.get_effective_time_scale()) - 4.0) > 0.001:
		push_error("GM clear_enemies should release combat time cap and restore player speed")
		quit(1)
		return
	time_system.set_time_scale(1.0)
	gm_panel._execute_command("escape_npc priest_01")
	var priest_escape: Dictionary = npc_system.get_npc_state("priest_01").get("escape_intent", {})
	if str(priest_escape.get("status", "")) != "escaping":
		push_error("GM escape_npc command should start station escape")
		quit(1)
		return

	if not await _wait_for_llm_cleanup(llm_bridge):
		quit(1)
		return
	# The startup/planning verification above may intentionally leave gameplay paused.
	# Unpause and clear startup-plan work before asserting that a GM-assigned runtime
	# action starts immediately. Startup LLM timing must not decide this assertion.
	time_system.set_paused(false)
	action_system.interrupt_npc_action("veteran_deputy_01", "gm_verify_training_setup")
	if not npc_system.debug_enter_location_immediately("veteran_deputy_01", "training_ground"):
		push_error("Failed to place veteran at training ground for GM training test")
		quit(1)
		return
	gm_panel._execute_command("train_instructor veteran_deputy_01")
	if str(npc_system.get_npc_state("veteran_deputy_01").get("last_action_result", "")) != "started_work_training_instructor":
		push_error("GM train_instructor command should start instructor action")
		quit(1)
		return
	npc_system.set_npc_recruited("stableman_01", true)
	resource_system.add_resource("item_bow", 1)
	var stableman_weapon: Dictionary = equipment_system.equip_npc_main_weapon("stableman_01", "bow", "private")
	if not bool(stableman_weapon.get("ok", false)):
		push_error("Failed to equip stableman for GM training test")
		quit(1)
		return
	action_system.interrupt_npc_action("stableman_01", "gm_verify_training_setup")
	if not npc_system.debug_enter_location_immediately("stableman_01", "training_ground"):
		push_error("Failed to place stableman at training ground for GM training test")
		quit(1)
		return
	gm_panel._execute_command("train_student stableman_01")
	if str(npc_system.get_npc_state("stableman_01").get("last_action_result", "")) != "started_receive_weapon_training":
		push_error("GM train_student command should start student action")
		quit(1)
		return

	if action_system.get_action_ids().has("work_repair_wall"):
		push_error("GM action list should not expose fixed wall repair action")
		quit(1)
		return

	print("GM panel verification passed.")
	quit(0)


func _select_option_by_id(select: OptionButton, expected_id: String) -> bool:
	if select == null:
		return false
	for index in range(select.get_item_count()):
		if str(select.get_item_metadata(index)) == expected_id:
			select.select(index)
			return true
	return false


func _has_button_text(root_node: Node, text: String) -> bool:
	for child in root_node.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.text == text:
			return true
	return false


func _wait_until_action_result(npc_system: Node, npc_id: String, expected_result: String) -> bool:
	for frame in range(600):
		await process_frame
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("last_action_result", "")) == expected_result:
			return true
	return false


func _wait_for_reflection(
	npc_system: Node,
	llm_bridge: Node,
	npc_id: String,
	expected_diary_count: int
) -> bool:
	for _step in range(300):
		await create_timer(0.01).timeout
		var diary: Array = npc_system.get_npc_long_memory(npc_id).get("diary", [])
		var runtime: Dictionary = llm_bridge.debug_get_llm_runtime_snapshot()
		if diary.size() == expected_diary_count and int(runtime.get("async_request_count", 0)) == 0:
			return true
	push_error("Timed out waiting for GM async reflection")
	return false


func _wait_for_llm_cleanup(llm_bridge: Node) -> bool:
	for _step in range(300):
		await create_timer(0.01).timeout
		if int(llm_bridge.debug_get_llm_runtime_snapshot().get("async_request_count", 0)) == 0:
			return true
	push_error("Timed out waiting for GM LLM async cleanup")
	return false


func _panel_tracks_button(panel: Control, button: Control) -> bool:
	var panel_rect := panel.get_global_rect()
	var button_rect := button.get_global_rect()
	var expected_y := button_rect.position.y + button_rect.size.y
	return (
		absf(panel_rect.position.x - button_rect.position.x) <= 2.0
		and panel_rect.position.y >= expected_y
		and panel_rect.position.y <= expected_y + 16.0
	)


func _panel_inside_viewport(panel: Control, viewport_size: Vector2) -> bool:
	var panel_rect := panel.get_global_rect()
	return (
		panel_rect.position.x >= 0.0
		and panel_rect.position.y >= 0.0
		and panel_rect.position.x + panel_rect.size.x <= viewport_size.x + 1.0
		and panel_rect.position.y + panel_rect.size.y <= viewport_size.y + 1.0
	)
