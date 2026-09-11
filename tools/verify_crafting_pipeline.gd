extends SceneTree

const EXPECTED_RECIPES := {
	"craft_iron_helmet": ["blacksmith", "item_iron_helmet", 3],
	"craft_iron_bracers": ["blacksmith", "item_iron_bracers", 3],
	"craft_polearm": ["blacksmith", "item_polearm", 4],
	"craft_iron_greaves": ["blacksmith", "item_iron_greaves", 4],
	"craft_sword_shield": ["blacksmith", "item_sword_shield", 5],
	"craft_mail_chest": ["blacksmith", "item_mail_chest", 8],
	"craft_bow": ["workshop", "item_bow", 3],
	"craft_crossbow": ["workshop", "item_crossbow", 5],
	"craft_wall_ballista": ["workshop", "item_wall_ballista", 9],
	"craft_wall_arrow_tower": ["workshop", "item_wall_arrow_tower", 12]
}
const PRODUCTION_INFO_FIELDS := [
	"target_item_id",
	"target_name",
	"completed_stages",
	"total_stages",
	"current_stage_index",
	"current_stage_name"
]
const FORBIDDEN_PRODUCTION_RUNTIME_FIELDS := ["partial_progress", "active_workers"]


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	root.add_child(main_scene.instantiate())
	await process_frame
	await physics_frame

	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel")
	if crafting_system == null or action_system == null or resource_system == null or building_system == null or npc_system == null or memory_system == null or time_system == null or building_panel == null:
		_fail("Required crafting integration nodes are missing")
		return
	time_system.set_paused(false)
	_set_debug_move_speed("blacksmith_01", 40.0)
	_set_debug_move_speed("engineer_01", 40.0)

	if not _verify_catalog(crafting_system):
		return
	if not _verify_crafting_failure_facts(
		crafting_system,
		action_system,
		resource_system,
		npc_system,
		memory_system
	):
		return

	resource_system.add_resource("iron", 30)
	resource_system.add_resource("wood", 30)
	if not await _verify_production_info_propagation(
		crafting_system,
		action_system,
		npc_system,
		memory_system
	):
		return
	if not await _verify_parallel_blacksmith_cycles_after_upgrade(
		crafting_system,
		action_system,
		resource_system,
		building_system,
		npc_system
	):
		return
	var worker_id := "blacksmith_01"
	npc_system.debug_enter_location_immediately(worker_id, "blacksmith")
	action_system.interrupt_npc_action(worker_id, "crafting_verification_reset")

	var selected: Dictionary = crafting_system.set_target("blacksmith", "craft_iron_helmet", false)
	if not bool(selected.get("ok", false)):
		_fail("Could not select iron helmet target: %s" % JSON.stringify(selected))
		return
	var iron_before_interrupt := int(resource_system.get_resource("iron"))
	if not action_system.debug_assign_work(worker_id, "blacksmith"):
		_fail("Crafting work did not start after selecting a target")
		return
	if not await _wait_until_current_action(npc_system, worker_id, "work_blacksmith"):
		_fail("Blacksmith never entered active work: state=%s spatial=%s runtime=%s" % [
			JSON.stringify(npc_system.get_npc_state(worker_id)),
			JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(worker_id)),
			JSON.stringify(action_system.get_runtime_action_snapshot(worker_id))
		])
		return
	var cycles: Array = action_system.get_active_work_cycle_snapshots("blacksmith", ["work_blacksmith"])
	if cycles.is_empty():
		_fail("Active crafting cycle snapshot is missing")
		return
	var duration := float((cycles[0] as Dictionary).get("duration_seconds", 3600.0))
	action_system._on_logical_time_tick(duration * 0.4, 1.0)
	var partial: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	if float(partial.get("partial_progress", 0.0)) <= 0.0 or int(partial.get("completed_stages", -1)) != 0:
		_fail("Partial work should expose fractional progress without completing a stage: %s" % JSON.stringify(partial))
		return
	action_system.interrupt_npc_action(worker_id, "crafting_verification_interrupt")
	var interrupted: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	if float(interrupted.get("partial_progress", -1.0)) != 0.0 or int(interrupted.get("completed_stages", -1)) != 0:
		_fail("Interrupted current stage did not roll back to its completed-stage boundary: %s" % JSON.stringify(interrupted))
		return
	if int(resource_system.get_resource("iron")) != iron_before_interrupt:
		_fail("Interrupted stage must not consume material")
		return

	if not action_system.debug_assign_work(worker_id, "blacksmith"):
		_fail("Could not restart blacksmith work")
		return
	if not await _wait_until_current_action(npc_system, worker_id, "work_blacksmith"):
		_fail("Restarted blacksmith work never became active")
		return
	cycles = action_system.get_active_work_cycle_snapshots("blacksmith", ["work_blacksmith"])
	duration = float((cycles[0] as Dictionary).get("duration_seconds", 3600.0))
	action_system._on_logical_time_tick(duration + 1.0, 1.0)
	await process_frame
	var one_stage: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	if int(one_stage.get("completed_stages", -1)) != 1 or int(resource_system.get_resource("iron")) != iron_before_interrupt - 1:
		_fail("One work cycle must atomically complete exactly one stage: %s" % JSON.stringify(one_stage))
		return

	var needs_confirm: Dictionary = crafting_system.set_target("blacksmith", "craft_sword_shield", false)
	if bool(needs_confirm.get("ok", true)) or not bool(needs_confirm.get("confirmation_required", false)):
		_fail("Changing a non-zero project must require confirmation: %s" % JSON.stringify(needs_confirm))
		return
	var changed: Dictionary = crafting_system.set_target("blacksmith", "craft_sword_shield", true)
	if not bool(changed.get("ok", false)):
		_fail("Confirmed target change failed: %s" % JSON.stringify(changed))
		return
	var reset_project: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	if int(reset_project.get("completed_stages", -1)) != 0 or str(reset_project.get("target_item_id", "")) != "item_sword_shield":
		_fail("Confirmed target change did not discard all project stages")
		return

	crafting_system.set_target("blacksmith", "craft_iron_helmet", true)
	var item_before := int(resource_system.get_resource("item_iron_helmet"))
	var project: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	for _stage in range(3):
		var stage_result: Dictionary = crafting_system.complete_stage("blacksmith", int(project.get("project_revision", -1)), "")
		if not bool(stage_result.get("ok", false)):
			_fail("Direct stage completion failed: %s" % JSON.stringify(stage_result))
			return
		project = crafting_system.get_project_snapshot("blacksmith")
	if int(resource_system.get_resource("item_iron_helmet")) != item_before:
		_fail("Finished recipe entered formal inventory before manual collection")
		return
	if int(crafting_system.get_pending_outputs("blacksmith").get("item_iron_helmet", 0)) != 1:
		_fail("Finished recipe did not enter the blacksmith pending-output store")
		return
	var collection: Dictionary = crafting_system.collect_pending_outputs("blacksmith")
	if not bool(collection.get("ok", false)) or int(resource_system.get_resource("item_iron_helmet")) != item_before + 1:
		_fail("Manual collection did not atomically transfer the exact item_iron_helmet inventory")
		return
	if int(project.get("completed_stages", -1)) != 0 or str(project.get("target_recipe_id", "")) != "craft_iron_helmet":
		_fail("Completed product should reset stages while retaining the selected target")
		return

	var production_state: Dictionary = building_system.get_building_special_state_section("blacksmith", "production")
	for key in ["target_item_id", "target_name", "completed_stages", "total_stages", "current_stage_index", "current_stage_name"]:
		if not production_state.has(key):
			_fail("Building production special state is missing %s: %s" % [key, JSON.stringify(production_state)])
			return
	if production_state.has("partial_progress") or production_state.has("active_workers"):
		_fail("Building special state must not leak fractional/UI-only crafting runtime")
		return

	building_panel.show_building("blacksmith")
	await process_frame
	var panel_snapshot: Dictionary = building_panel.debug_get_crafting_panel_snapshot()
	if not bool(panel_snapshot.get("visible", false)) or str(panel_snapshot.get("selected_recipe_id", "")) != "craft_iron_helmet":
		_fail("Blacksmith building panel did not expose the selected recipe")
		return
	if not await _verify_crafting_panel_target_confirmation(crafting_system, building_panel):
		return

	print("T0035 crafting pipeline verification passed.")
	quit(0)


func _verify_catalog(crafting_system: Node) -> bool:
	var found := 0
	for recipe_id in EXPECTED_RECIPES.keys():
		var expected: Array = EXPECTED_RECIPES[recipe_id]
		var recipe: Dictionary = crafting_system.get_recipe(str(recipe_id))
		if str(recipe.get("building_id", "")) != str(expected[0]) or str(recipe.get("output_item_id", "")) != str(expected[1]) or (recipe.get("stages", []) as Array).size() != int(expected[2]):
			_fail("Crafting catalog mismatch for %s: %s" % [recipe_id, JSON.stringify(recipe)])
			return false
		found += 1
	if found != 10:
		_fail("Expected exactly 10 frozen crafting recipes")
		return false
	return true


func _verify_crafting_failure_facts(
	crafting_system: Node,
	action_system: Node,
	resource_system: Node,
	npc_system: Node,
	memory_system: Node
) -> bool:
	crafting_system.set_target("blacksmith", "", true)
	var worker_id := "blacksmith_01"
	action_system.interrupt_npc_action(worker_id, "crafting_verification_reset")
	npc_system.debug_enter_location_immediately(worker_id, "blacksmith")
	npc_system.update_npc_state(worker_id, {"last_action_result": "", "satiety": 90, "fatigue": 0})
	if action_system.debug_assign_work(worker_id, "blacksmith"):
		_fail("Blacksmith work must not start without a selected target")
		return false
	if str(npc_system.get_npc_state(worker_id).get("last_action_result", "")) != "work_failed_crafting_target_missing":
		_fail("Missing target did not expose the expected action failure")
		return false
	var selected: Dictionary = crafting_system.set_target(
		"blacksmith",
		"craft_iron_helmet",
		true
	)
	if not bool(selected.get("ok", false)):
		_fail("Could not select resource-failure crafting target")
		return false
	var iron_before := int(resource_system.get_resource("iron"))
	if iron_before > 0 and not resource_system.debug_spend_resources(
		{"iron": iron_before}
	):
		_fail("Could not clear iron for crafting failure fact verification")
		return false
	var event_count: int = memory_system.get_npc_daily_events(worker_id).size()
	if action_system.debug_assign_work(worker_id, "blacksmith"):
		_fail("Blacksmith work must not start without the current stage material")
		return false
	var events: Array = memory_system.get_npc_daily_events(worker_id)
	if events.size() <= event_count:
		_fail("Insufficient stage resources did not write work_failed memory")
		return false
	var event: Dictionary = events[events.size() - 1]
	var payload: Dictionary = (
		event.get("payload", {})
		if event.get("payload", {}) is Dictionary
		else {}
	)
	var crafting_project: Dictionary = (
		payload.get("crafting_project", {})
		if payload.get("crafting_project", {}) is Dictionary
		else {}
	)
	if (
		str(event.get("type", "")) != "work_failed"
		or str(payload.get("crafting_error", ""))
			!= "insufficient_stage_resources"
		or str(payload.get("reason", "")) != "当前制造阶段材料不足"
		or int(payload.get("required_resources", {}).get("iron", 0)) != 1
		or str(crafting_project.get("target_item_id", ""))
			!= "item_iron_helmet"
		or int(crafting_project.get("current_stage_index", 0)) != 1
		or str(crafting_project.get("current_stage_name", "")).is_empty()
		or int(crafting_project.get("current_stage_cost", {}).get("iron", 0))
			!= 1
	):
		_fail(
			"Crafting failure memory lost authoritative stage facts: %s"
			% JSON.stringify(event)
		)
		return false
	if iron_before > 0:
		resource_system.add_resource("iron", iron_before)
	return true


func _verify_crafting_panel_target_confirmation(crafting_system: Node, building_panel: Node) -> bool:
	var reset: Dictionary = crafting_system.set_target("blacksmith", "", true)
	if not bool(reset.get("ok", false)):
		_fail("Could not reset the building-panel confirmation fixture: %s" % JSON.stringify(reset))
		return false
	building_panel.show_building("blacksmith")
	await process_frame
	var recipe_label := building_panel.find_child("CraftingRecipeLabel", true, false) as Label
	var status_label := building_panel.find_child("CraftingStatusLabel", true, false) as Label
	if recipe_label == null or status_label == null:
		_fail("Building panel is missing its crafting detail labels")
		return false
	if recipe_label.visible or status_label.visible or not recipe_label.text.is_empty() or not status_label.text.is_empty():
		_fail("An unselected crafting target should not show redundant explanatory copy")
		return false
	var selected: Dictionary = crafting_system.set_target("blacksmith", "craft_iron_helmet", false)
	if not bool(selected.get("ok", false)):
		_fail("Could not select the building-panel confirmation fixture: %s" % JSON.stringify(selected))
		return false
	building_panel.show_building("blacksmith")
	await process_frame
	if status_label.visible or not status_label.text.is_empty():
		_fail("A selected crafting target should not show the redundant target-change warning")
		return false

	var target_select := building_panel.find_child("CraftingTargetSelect", true, false) as OptionButton
	var confirmation := building_panel.find_child("CraftingTargetConfirmation", true, false) as ConfirmationDialog
	if target_select == null or confirmation == null:
		_fail("Building panel is missing its real crafting target selector or confirmation dialog")
		return false
	var sword_index := _find_option_index_by_metadata(target_select, "craft_sword_shield")
	var helmet_index := _find_option_index_by_metadata(target_select, "craft_iron_helmet")
	if sword_index < 0 or helmet_index < 0:
		_fail("Building panel target selector is missing an exact blacksmith recipe option")
		return false

	var helmet_project: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	var partial_result: Dictionary = crafting_system.set_work_cycle_progress(
		"blacksmith",
		int(helmet_project.get("project_revision", -1)),
		"blacksmith_01",
		0.35
	)
	if not bool(partial_result.get("ok", false)):
		_fail("Could not create partial panel progress: %s" % JSON.stringify(partial_result))
		return false
	await process_frame
	var partial_before_cancel: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	var panel_before_cancel: Dictionary = building_panel.debug_get_crafting_panel_snapshot()
	if float(panel_before_cancel.get("progress", 0.0)) <= 0.0:
		_fail("Crafting panel progress bar did not expose the non-zero partial cycle")
		return false

	target_select.select(sword_index)
	target_select.item_selected.emit(sword_index)
	await process_frame
	var partial_prompt: Dictionary = building_panel.debug_get_crafting_panel_snapshot()
	if (
		not bool(partial_prompt.get("confirmation_visible", false))
		or str(partial_prompt.get("pending_recipe_id", "")) != "craft_sword_shield"
		or str(partial_prompt.get("selected_recipe_id", "")) != "craft_iron_helmet"
	):
		_fail("Partial progress did not open a pending target-change confirmation while retaining the old selection: %s" % JSON.stringify(partial_prompt))
		return false
	if not confirmation.dialog_text.contains(str(partial_before_cancel.get("current_stage_name", ""))) or not confirmation.dialog_text.contains("整件进度"):
		_fail("Target-change confirmation must identify the current stage and visible overall progress")
		return false
	confirmation.get_cancel_button().pressed.emit()
	await process_frame
	var partial_after_cancel: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	var panel_after_cancel: Dictionary = building_panel.debug_get_crafting_panel_snapshot()
	if (
		str(partial_after_cancel.get("target_recipe_id", "")) != "craft_iron_helmet"
		or int(partial_after_cancel.get("completed_stages", -1)) != int(partial_before_cancel.get("completed_stages", -1))
		or not is_equal_approx(float(partial_after_cancel.get("partial_progress", -1.0)), float(partial_before_cancel.get("partial_progress", -2.0)))
		or str(panel_after_cancel.get("selected_recipe_id", "")) != "craft_iron_helmet"
		or bool(panel_after_cancel.get("confirmation_visible", true))
		or not str(panel_after_cancel.get("pending_recipe_id", "")).is_empty()
	):
		_fail("Canceling the partial-progress target change did not preserve target/progress: project=%s panel=%s" % [JSON.stringify(partial_after_cancel), JSON.stringify(panel_after_cancel)])
		return false

	target_select.select(sword_index)
	target_select.item_selected.emit(sword_index)
	await process_frame
	if not bool(building_panel.debug_get_crafting_panel_snapshot().get("confirmation_visible", false)):
		_fail("Re-selecting a target with partial progress did not reopen confirmation")
		return false
	confirmation.get_ok_button().pressed.emit()
	await process_frame
	var partial_after_confirm: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	var panel_after_confirm: Dictionary = building_panel.debug_get_crafting_panel_snapshot()
	if (
		str(partial_after_confirm.get("target_recipe_id", "")) != "craft_sword_shield"
		or int(partial_after_confirm.get("completed_stages", -1)) != 0
		or float(partial_after_confirm.get("partial_progress", -1.0)) != 0.0
		or not (partial_after_confirm.get("active_workers", []) as Array).is_empty()
		or str(panel_after_confirm.get("selected_recipe_id", "")) != "craft_sword_shield"
		or float(panel_after_confirm.get("progress", -1.0)) != 0.0
		or bool(panel_after_confirm.get("confirmation_visible", true))
	):
		_fail("Confirming the partial-progress target change did not switch and reset the project: project=%s panel=%s" % [JSON.stringify(partial_after_confirm), JSON.stringify(panel_after_confirm)])
		return false

	var stage_result: Dictionary = crafting_system.complete_stage(
		"blacksmith",
		int(partial_after_confirm.get("project_revision", -1)),
		""
	)
	if not bool(stage_result.get("ok", false)):
		_fail("Could not create an integer-stage panel confirmation fixture: %s" % JSON.stringify(stage_result))
		return false
	await process_frame
	var integer_before_cancel: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	var integer_panel_before: Dictionary = building_panel.debug_get_crafting_panel_snapshot()
	if int(integer_before_cancel.get("completed_stages", -1)) != 1 or float(integer_panel_before.get("progress", 0.0)) <= 0.0:
		_fail("Crafting panel did not expose its committed integer-stage progress")
		return false

	target_select.select(helmet_index)
	target_select.item_selected.emit(helmet_index)
	await process_frame
	var integer_prompt: Dictionary = building_panel.debug_get_crafting_panel_snapshot()
	if (
		not bool(integer_prompt.get("confirmation_visible", false))
		or str(integer_prompt.get("pending_recipe_id", "")) != "craft_iron_helmet"
		or str(integer_prompt.get("selected_recipe_id", "")) != "craft_sword_shield"
	):
		_fail("Committed-stage progress did not open a pending target-change confirmation: %s" % JSON.stringify(integer_prompt))
		return false
	confirmation.get_cancel_button().pressed.emit()
	await process_frame
	var integer_after_cancel: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	var integer_panel_after_cancel: Dictionary = building_panel.debug_get_crafting_panel_snapshot()
	if (
		str(integer_after_cancel.get("target_recipe_id", "")) != "craft_sword_shield"
		or int(integer_after_cancel.get("completed_stages", -1)) != 1
		or not is_equal_approx(float(integer_after_cancel.get("progress", -1.0)), float(integer_before_cancel.get("progress", -2.0)))
		or str(integer_panel_after_cancel.get("selected_recipe_id", "")) != "craft_sword_shield"
		or bool(integer_panel_after_cancel.get("confirmation_visible", true))
	):
		_fail("Canceling the committed-stage target change did not preserve target/progress: project=%s panel=%s" % [JSON.stringify(integer_after_cancel), JSON.stringify(integer_panel_after_cancel)])
		return false

	target_select.select(helmet_index)
	target_select.item_selected.emit(helmet_index)
	await process_frame
	if not bool(building_panel.debug_get_crafting_panel_snapshot().get("confirmation_visible", false)):
		_fail("Re-selecting a target with committed-stage progress did not reopen confirmation")
		return false
	confirmation.get_ok_button().pressed.emit()
	await process_frame
	var integer_after_confirm: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	var integer_panel_after_confirm: Dictionary = building_panel.debug_get_crafting_panel_snapshot()
	if (
		str(integer_after_confirm.get("target_recipe_id", "")) != "craft_iron_helmet"
		or int(integer_after_confirm.get("completed_stages", -1)) != 0
		or float(integer_after_confirm.get("progress", -1.0)) != 0.0
		or str(integer_panel_after_confirm.get("selected_recipe_id", "")) != "craft_iron_helmet"
		or float(integer_panel_after_confirm.get("progress", -1.0)) != 0.0
		or bool(integer_panel_after_confirm.get("confirmation_visible", true))
	):
		_fail("Confirming the committed-stage target change did not switch and reset the project: project=%s panel=%s" % [JSON.stringify(integer_after_confirm), JSON.stringify(integer_panel_after_confirm)])
		return false
	return true


func _verify_production_info_propagation(
	crafting_system: Node,
	action_system: Node,
	npc_system: Node,
	memory_system: Node
) -> bool:
	var recipient_id := "blacksmith_01"
	var outside_id := "priest_01"
	action_system.interrupt_npc_action(recipient_id, "crafting_info_verification_reset")
	action_system.interrupt_npc_action(outside_id, "crafting_info_verification_reset")
	npc_system.update_npc_state(recipient_id, {
		"unconscious": false,
		"current_action": "idle",
		"satiety": 90,
		"fatigue": 0
	})
	npc_system.update_npc_state(outside_id, {
		"unconscious": false,
		"current_action": "idle"
	})
	if not npc_system.debug_enter_location_immediately(recipient_id, "plaza"):
		_fail("Could not place the production-info recipient outside the blacksmith")
		return false
	if not npc_system.debug_enter_location_immediately(outside_id, "chapel"):
		_fail("Could not place the production-info outside observer away from the blacksmith")
		return false

	var cleared: Dictionary = crafting_system.set_target("blacksmith", "", true)
	if not bool(cleared.get("ok", false)):
		_fail("Could not reset blacksmith target before production-info verification: %s" % JSON.stringify(cleared))
		return false
	var outside_before_initial_target: int = memory_system.get_npc_witness_events(outside_id).size()
	var selected: Dictionary = crafting_system.set_target("blacksmith", "craft_iron_helmet", false)
	if not bool(selected.get("ok", false)):
		_fail("Could not select the production-info fixture target: %s" % JSON.stringify(selected))
		return false
	await process_frame
	if memory_system.get_npc_witness_events(outside_id).size() != outside_before_initial_target:
		_fail("An NPC outside the blacksmith received its target-state change")
		return false

	var helmet_project: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	var synthetic_progress: Dictionary = crafting_system.set_work_cycle_progress(
		"blacksmith",
		int(helmet_project.get("project_revision", -1)),
		recipient_id,
		0.35
	)
	if not bool(synthetic_progress.get("ok", false)):
		_fail("Could not create active fractional crafting runtime for snapshot filtering: %s" % JSON.stringify(synthetic_progress))
		return false
	var runtime_project: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	if float(runtime_project.get("partial_progress", 0.0)) <= 0.0 or (runtime_project.get("active_workers", []) as Array).is_empty():
		_fail("Production-info fixture did not contain real fractional/worker runtime: %s" % JSON.stringify(runtime_project))
		return false

	var recipient_before_entry: int = memory_system.get_npc_witness_events(recipient_id).size()
	if not npc_system.debug_enter_location_immediately(recipient_id, "blacksmith"):
		_fail("Could not move the production-info recipient into the blacksmith")
		return false
	var entry_events := _events_after(
		memory_system.get_npc_witness_events(recipient_id),
		recipient_before_entry
	)
	var entry_event := _find_location_state_event(entry_events, "location_entry_snapshot")
	if entry_event.is_empty():
		_fail("Blacksmith entry did not create a location_entry_snapshot witness")
		return false
	var location_snapshot: Dictionary = entry_event.get("payload", {}).get("location_snapshot", {})
	var special_state: Dictionary = location_snapshot.get("special_state", {}) if location_snapshot.get("special_state", {}) is Dictionary else {}
	var production: Dictionary = special_state.get("production", {}) if special_state.get("production", {}) is Dictionary else {}
	if not _has_exact_fields(production, PRODUCTION_INFO_FIELDS):
		_fail("Blacksmith entry snapshot did not expose exactly the production whitelist: %s" % JSON.stringify(production))
		return false
	if str(production.get("target_item_id", "")) != "item_iron_helmet" or int(production.get("completed_stages", -1)) != 0:
		_fail("Blacksmith entry snapshot contained the wrong current production state: %s" % JSON.stringify(production))
		return false
	if _contains_forbidden_production_runtime(location_snapshot):
		_fail("Blacksmith entry snapshot leaked partial_progress or active_workers: %s" % JSON.stringify(location_snapshot))
		return false

	var recipient_before_target_delta: int = memory_system.get_npc_witness_events(recipient_id).size()
	var outside_before_target_delta: int = memory_system.get_npc_witness_events(outside_id).size()
	var changed_target: Dictionary = crafting_system.set_target("blacksmith", "craft_sword_shield", true)
	if not bool(changed_target.get("ok", false)):
		_fail("Could not change target for production-info delta verification: %s" % JSON.stringify(changed_target))
		return false
	await process_frame
	var target_delta_events := _events_after(
		memory_system.get_npc_witness_events(recipient_id),
		recipient_before_target_delta
	)
	var target_delta_event := _find_location_state_event(
		target_delta_events,
		"building_internal_special_state_changed"
	)
	if target_delta_event.is_empty():
		_fail("Present receivable NPC did not receive the crafting-target special-state delta")
		return false
	var target_delta: Dictionary = target_delta_event.get("payload", {}).get("changed_special_state", {})
	var target_production_delta: Dictionary = target_delta.get("production", {}) if target_delta.get("production", {}) is Dictionary else {}
	var expected_target_delta_fields := ["target_item_id", "target_name", "total_stages", "current_stage_name"]
	if not _has_exact_fields(target_production_delta, expected_target_delta_fields):
		_fail("Crafting target change did not expose a field-only production delta: %s" % JSON.stringify(target_delta))
		return false
	if str(target_production_delta.get("target_item_id", "")) != "item_sword_shield":
		_fail("Crafting target delta contained the wrong exact target item: %s" % JSON.stringify(target_delta))
		return false
	if _contains_forbidden_production_runtime(target_delta):
		_fail("Crafting target delta leaked partial_progress or active_workers: %s" % JSON.stringify(target_delta))
		return false
	if memory_system.get_npc_witness_events(outside_id).size() != outside_before_target_delta:
		_fail("An NPC outside the blacksmith received the crafting-target special-state delta")
		return false

	var sword_project: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	var recipient_before_fractional: int = memory_system.get_npc_witness_events(recipient_id).size()
	var partial_result: Dictionary = crafting_system.set_work_cycle_progress(
		"blacksmith",
		int(sword_project.get("project_revision", -1)),
		recipient_id,
		0.4
	)
	if not bool(partial_result.get("ok", false)):
		_fail("Could not create fractional crafting progress for delta filtering: %s" % JSON.stringify(partial_result))
		return false
	var fractional_project: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	if float(fractional_project.get("partial_progress", 0.0)) <= 0.0 or (fractional_project.get("active_workers", []) as Array).is_empty():
		_fail("Fractional crafting delta fixture did not expose its runtime internally")
		return false
	await process_frame
	var fractional_events := _events_after(
		memory_system.get_npc_witness_events(recipient_id),
		recipient_before_fractional
	)
	if not _find_location_state_event(fractional_events, "building_internal_special_state_changed").is_empty():
		_fail("Fractional crafting progress incorrectly emitted an internal special-state delta")
		return false

	var recipient_before_stage_delta: int = memory_system.get_npc_witness_events(recipient_id).size()
	var outside_before_stage_delta: int = memory_system.get_npc_witness_events(outside_id).size()
	var stage_result: Dictionary = crafting_system.complete_stage(
		"blacksmith",
		int(sword_project.get("project_revision", -1)),
		recipient_id
	)
	if not bool(stage_result.get("ok", false)):
		_fail("Could not complete a stage for production-info delta verification: %s" % JSON.stringify(stage_result))
		return false
	await process_frame
	var stage_delta_events := _events_after(
		memory_system.get_npc_witness_events(recipient_id),
		recipient_before_stage_delta
	)
	var stage_delta_event := _find_location_state_event(
		stage_delta_events,
		"building_internal_special_state_changed"
	)
	if stage_delta_event.is_empty():
		_fail("Present receivable NPC did not receive the integer-stage special-state delta")
		return false
	var stage_delta: Dictionary = stage_delta_event.get("payload", {}).get("changed_special_state", {})
	var stage_production_delta: Dictionary = stage_delta.get("production", {}) if stage_delta.get("production", {}) is Dictionary else {}
	var expected_stage_delta_fields := ["completed_stages", "current_stage_index", "current_stage_name"]
	if not _has_exact_fields(stage_production_delta, expected_stage_delta_fields):
		_fail("Integer-stage change did not expose only changed production fields: %s" % JSON.stringify(stage_delta))
		return false
	if int(stage_production_delta.get("completed_stages", -1)) != 1 or int(stage_production_delta.get("current_stage_index", -1)) != 2:
		_fail("Integer-stage delta contained the wrong committed stage: %s" % JSON.stringify(stage_delta))
		return false
	if _contains_forbidden_production_runtime(stage_delta):
		_fail("Integer-stage delta leaked partial_progress or active_workers: %s" % JSON.stringify(stage_delta))
		return false
	if memory_system.get_npc_witness_events(outside_id).size() != outside_before_stage_delta:
		_fail("An NPC outside the blacksmith received the integer-stage special-state delta")
		return false

	var final_reset: Dictionary = crafting_system.set_target("blacksmith", "", true)
	if not bool(final_reset.get("ok", false)):
		_fail("Could not clear the production-info verification fixture: %s" % JSON.stringify(final_reset))
		return false
	return true


func _verify_parallel_blacksmith_cycles_after_upgrade(
	crafting_system: Node,
	action_system: Node,
	resource_system: Node,
	building_system: Node,
	npc_system: Node
) -> bool:
	var blacksmith_before: Dictionary = building_system.get_building("blacksmith")
	var workstations_before: Array = blacksmith_before.get("workstations", [])
	if int(blacksmith_before.get("level", 0)) != 1 or workstations_before.size() != 2:
		_fail("Parallel crafting verification requires a level-1 blacksmith with two workstations")
		return false
	if not building_system.upgrade_building("blacksmith"):
		_fail("Could not start the real blacksmith upgrade")
		return false
	var upgrade_status: Dictionary = building_system.get_upgrade_status("blacksmith")
	var upgrade_duration := float(upgrade_status.get("duration_seconds", 0.0))
	if upgrade_duration <= 0.0:
		_fail("Blacksmith upgrade did not expose a real duration: %s" % JSON.stringify(upgrade_status))
		return false
	building_system._on_logical_time_tick(upgrade_duration + 1.0, 1.0)
	var blacksmith_after: Dictionary = building_system.get_building("blacksmith")
	var upgraded_workstations: Array = blacksmith_after.get("workstations", [])
	if int(blacksmith_after.get("level", 0)) != 2 or upgraded_workstations.size() != 2:
		_fail("Level-two blacksmith upgrade should retain two workstations: %s" % JSON.stringify(blacksmith_after))
		return false

	var selected: Dictionary = crafting_system.set_target("blacksmith", "craft_sword_shield", true)
	if not bool(selected.get("ok", false)):
		_fail("Could not select the shared sword-and-shield project: %s" % JSON.stringify(selected))
		return false
	var project_before: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	var shared_revision := int(project_before.get("project_revision", -1))
	var iron_before := int(resource_system.get_resource("iron"))
	var wood_before := int(resource_system.get_resource("wood"))
	var item_before := int(resource_system.get_resource("item_sword_shield"))
	var worker_ids := ["blacksmith_01", "engineer_01"]
	for worker_id in worker_ids:
		action_system.interrupt_npc_action(worker_id, "parallel_crafting_verification_reset")
		npc_system.debug_enter_location_immediately(worker_id, "blacksmith")
		npc_system.update_npc_state(worker_id, {
			"satiety": 90,
			"fatigue": 0,
			"last_action_result": "",
			"behavior_mode": "work"
		})
		if not action_system.debug_assign_work(worker_id, "blacksmith"):
			_fail("Could not start parallel blacksmith work for %s" % worker_id)
			return false
		if not await _wait_until_current_action(npc_system, worker_id, "work_blacksmith"):
			_fail("Parallel worker never entered blacksmith work: %s state=%s spatial=%s runtime=%s" % [
				worker_id,
				JSON.stringify(npc_system.get_npc_state(worker_id)),
				JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(worker_id)),
				JSON.stringify(action_system.get_runtime_action_snapshot(worker_id))
			])
			return false

	var cycles: Array = action_system.get_active_work_cycle_snapshots("blacksmith", ["work_blacksmith"])
	if cycles.size() != 2:
		_fail("Blacksmith should expose two simultaneous work cycles: %s" % JSON.stringify(cycles))
		return false
	var cycle_by_worker := {}
	var occupied_workstations: Array[String] = []
	var first_duration := INF
	for raw_cycle in cycles:
		var cycle: Dictionary = raw_cycle
		var worker_id := str(cycle.get("npc_id", ""))
		cycle_by_worker[worker_id] = cycle
		var workstation_id := str(cycle.get("workstation_id", ""))
		if workstation_id.is_empty() or occupied_workstations.has(workstation_id):
			_fail("Parallel workers did not occupy two distinct real workstations: %s" % JSON.stringify(cycles))
			return false
		occupied_workstations.append(workstation_id)
		if int(cycle.get("project_revision", -1)) != shared_revision or str(cycle.get("recipe_id", "")) != "craft_sword_shield":
			_fail("Parallel workers did not share the same crafting project: %s" % JSON.stringify(cycles))
			return false
		first_duration = minf(first_duration, float(cycle.get("duration_seconds", 0.0)))
	if not cycle_by_worker.has("blacksmith_01") or not cycle_by_worker.has("engineer_01"):
		_fail("Parallel cycle snapshots are missing one of the required workers: %s" % JSON.stringify(cycles))
		return false

	action_system._on_logical_time_tick(first_duration + 0.01, 1.0)
	await process_frame
	var after_first_commit: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	if int(after_first_commit.get("completed_stages", -1)) != 1:
		_fail("The first parallel cycle did not serialize as project stage 1: %s" % JSON.stringify(after_first_commit))
		return false
	if int(resource_system.get_resource("iron")) != iron_before - 1 or int(resource_system.get_resource("wood")) != wood_before:
		_fail("Sword-and-shield stage 1 must spend exactly one iron and no wood")
		return false
	var remaining_cycles: Array = action_system.get_active_work_cycle_snapshots("blacksmith", ["work_blacksmith"])
	if remaining_cycles.size() != 1:
		_fail("Exactly one overlapping cycle should remain after the faster worker commits: %s" % JSON.stringify(remaining_cycles))
		return false
	var remaining_cycle: Dictionary = remaining_cycles[0]
	var remaining_seconds := (
		float(remaining_cycle.get("duration_seconds", 0.0))
		- float(remaining_cycle.get("elapsed_seconds", 0.0))
	)
	if remaining_seconds <= 0.0:
		_fail("The slower parallel cycle did not retain unfinished work")
		return false

	action_system._on_logical_time_tick(remaining_seconds + 0.01, 1.0)
	await process_frame
	var after_second_commit: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	if int(after_second_commit.get("completed_stages", -1)) != 2:
		_fail("The second parallel cycle did not serialize as consecutive project stage 2: %s" % JSON.stringify(after_second_commit))
		return false
	if int(resource_system.get_resource("iron")) != iron_before - 1 or int(resource_system.get_resource("wood")) != wood_before - 1:
		_fail("Sword-and-shield stage 2 must spend exactly one wood without spending more iron")
		return false
	if int(resource_system.get_resource("item_sword_shield")) != item_before:
		_fail("Two of four sword-and-shield stages must not create a finished item")
		return false
	if not action_system.get_active_work_cycle_snapshots("blacksmith", ["work_blacksmith"]).is_empty():
		_fail("Both parallel blacksmith cycles should be complete")
		return false

	var cleared: Dictionary = crafting_system.set_target("blacksmith", "", true)
	if not bool(cleared.get("ok", false)):
		_fail("Could not clear the parallel crafting fixture: %s" % JSON.stringify(cleared))
		return false
	return true


func _find_location_state_event(events: Array, reason: String) -> Dictionary:
	for raw_event in events:
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		if str(event.get("type", "")) != "location_status_changed":
			continue
		if str(event.get("payload", {}).get("reason", "")) == reason:
			return event
	return {}


func _events_after(events: Array, start_index: int) -> Array:
	var result: Array = []
	for index in range(start_index, events.size()):
		result.append(events[index])
	return result


func _has_exact_fields(value: Dictionary, expected_fields: Array) -> bool:
	if value.size() != expected_fields.size():
		return false
	for raw_field in expected_fields:
		if not value.has(str(raw_field)):
			return false
	return true


func _find_option_index_by_metadata(option: OptionButton, metadata: String) -> int:
	for index in range(option.item_count):
		if str(option.get_item_metadata(index)) == metadata:
			return index
	return -1


func _set_debug_move_speed(npc_id: String, speed: float) -> void:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return
	for npc_node in npc_root.get_children():
		if str(npc_node.get_meta("npc_id", "")) == npc_id and "move_speed" in npc_node:
			npc_node.move_speed = speed
			return


func _contains_forbidden_production_runtime(value: Variant) -> bool:
	if value is Dictionary:
		for raw_key in value.keys():
			if FORBIDDEN_PRODUCTION_RUNTIME_FIELDS.has(str(raw_key)):
				return true
			if _contains_forbidden_production_runtime(value.get(raw_key)):
				return true
	elif value is Array:
		for item in value:
			if _contains_forbidden_production_runtime(item):
				return true
	return false


func _wait_until_current_action(npc_system: Node, npc_id: String, expected_action: String) -> bool:
	for _frame in range(600):
		# Formal workstation actions advance through CharacterBody3D physics;
		# a short real timer prevents a tight signal loop from exhausting all
		# retries inside only a handful of rendered/physics frames.
		await create_timer(0.02).timeout
		if str(npc_system.get_npc_state(npc_id).get("current_action", "")) == expected_action:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
