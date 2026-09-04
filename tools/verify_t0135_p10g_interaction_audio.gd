extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const EXPECTED_ASSETS := [
	"sfx_ui_button_primary",
	"sfx_ui_toggle",
	"sfx_ui_interaction_success_resource_collect",
	"sfx_world_door_open",
	"sfx_world_door_close",
	"sfx_merchant_cart_arrival_departure",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	for _index in range(8):
		await process_frame

	var controller := main.get_node_or_null("Presentation/InteractionAudioController")
	var audio_manager := root.get_node_or_null("AudioManager")
	var ui_root := main.get_node_or_null("UI")
	var settings_panel := main.get_node_or_null("UI/PauseMenu/SettingsPanel")
	var dialog_panel := main.get_node_or_null("UI/DialogPanel")
	var harvest_dialog := main.get_node_or_null("UI/CraftingHarvestDialog")
	var crafting_system := main.get_node_or_null("Systems/CraftingSystem")
	var resource_system := main.get_node_or_null("Systems/ResourceSystem")
	var merchant_system := main.get_node_or_null("Systems/MerchantSystem")
	if [controller, audio_manager, ui_root, settings_panel, dialog_panel, harvest_dialog, crafting_system, resource_system, merchant_system].has(null):
		_fail("P10G required Main nodes are missing")
		return

	var snapshot: Dictionary = controller.get_debug_snapshot()
	_assert(bool(snapshot.get("initialized", false)), "interaction controller did not initialize")
	_assert(str(snapshot.get("schema_version", "")) == "interaction_audio_v1", "wrong interaction schema")
	_assert(int(snapshot.get("connected_button_count", 0)) >= 30, "formal and dynamic UI buttons were not connected")
	_assert(not bool(snapshot.get("panel_visibility_audio_enabled", true)), "panel visibility audio must be disabled")
	_assert_assets_and_config(controller, audio_manager)

	await _assert_dynamic_button_audio(controller, ui_root)
	await _assert_panel_buttons_use_immediate_click(controller, settings_panel)
	await _assert_special_success_and_close(controller, dialog_panel)
	await _assert_real_harvest_success(controller, harvest_dialog, crafting_system, resource_system)
	_assert_semantic_priority(controller)
	_assert_ordinary_door_registration(controller)
	_assert_door_edges(controller, main)
	_assert_merchant_motion(controller, audio_manager, merchant_system)
	_assert_bus_routes()

	audio_manager.stop_all_one_shots()
	main.queue_free()
	await process_frame
	await process_frame
	var loops: Dictionary = audio_manager.get_loop_snapshot()
	_assert(not loops.has("interaction_merchant_cart_travel"), "merchant loop survived Main teardown")
	print("T0135_P10G_INTERACTION_AUDIO_PASS assets=6 ui=immediate panels=wood_only success=pass doors=pass merchant=pass")
	quit(0)


func _assert_assets_and_config(controller: Node, audio_manager: Node) -> void:
	var config: Dictionary = controller.get("_config")
	var ui: Dictionary = config.get("ui", {})
	var world: Dictionary = config.get("world", {})
	var unique := {}
	for raw_asset_id in (ui.get("semantic_assets", {}) as Dictionary).values():
		unique[str(raw_asset_id)] = true
	for key in ["door_open_asset", "door_close_asset", "merchant_loop_asset"]:
		unique[str(world.get(key, ""))] = true
	_assert(unique.size() == 6, "P10G must map exactly six active interaction assets")
	for asset_id in EXPECTED_ASSETS:
		_assert(unique.has(asset_id), "P10G mapping is missing %s" % asset_id)
		_assert(audio_manager.has_asset(asset_id), "audio manifest is missing %s" % asset_id)
	_assert(bool(ui.get("hover_silent", false)), "hover must remain silent")
	_assert(bool(ui.get("invalid_feedback_silent", false)), "invalid-operation feedback must remain silent")
	_assert(bool(ui.get("scroll_silent", false)), "scrolling must remain silent")


func _assert_dynamic_button_audio(controller: Node, ui_root: Node) -> void:
	var button := Button.new()
	button.name = "P10GDynamicButton"
	button.text = "动态按钮"
	ui_root.add_child(button)
	await process_frame
	controller.debug_clear_history()
	button.pressed.emit()
	_assert_last_ui(controller, "primary", "sfx_ui_button_primary")

	var toggle := CheckButton.new()
	toggle.name = "P10GDynamicToggle"
	toggle.text = "动态 Toggle"
	ui_root.add_child(toggle)
	await process_frame
	controller.debug_clear_history()
	toggle.pressed.emit()
	_assert_last_ui(controller, "toggle", "sfx_ui_toggle")
	button.queue_free()
	toggle.queue_free()


func _assert_panel_buttons_use_immediate_click(controller: Node, settings_panel: Node) -> void:
	if bool(settings_panel.visible):
		settings_panel.close_panel()
		await process_frame
	controller.debug_clear_history()
	settings_panel.open_panel()
	await process_frame
	_assert((controller.get_debug_snapshot().get("recent_history", []) as Array).is_empty(), "programmatic panel open played a page sound")
	var close_button := settings_panel.find_child("CloseButton", true, false) as Button
	_assert(close_button != null, "audio settings close button is missing")
	if close_button == null:
		return
	controller.debug_clear_history()
	close_button.pressed.emit()
	_assert(not bool(settings_panel.visible), "close button did not close the panel in its pressed dispatch")
	_assert_last_ui(controller, "primary", "sfx_ui_button_primary")
	await process_frame
	_assert((controller.get_debug_snapshot().get("recent_history", []) as Array).size() == 1, "panel close appended a delayed page sound")


func _assert_special_success_and_close(controller: Node, dialog_panel: Node) -> void:
	controller.debug_clear_history()
	dialog_panel.call("_on_special_interaction_result", {
		"success": true,
		"special_type": "work_encouragement",
		"npc_name": "诺拉",
	})
	await process_frame
	await process_frame
	_assert_last_ui(controller, "success", "sfx_ui_interaction_success_resource_collect")
	var success_dialog := dialog_panel.get_node("DialogSpecialSuccessDialog") as AcceptDialog
	_assert(success_dialog.visible, "special success popup did not become visible")
	controller.debug_clear_history()
	success_dialog.get_ok_button().pressed.emit()
	await process_frame
	await process_frame
	_assert_last_ui(controller, "primary", "sfx_ui_button_primary")


func _assert_real_harvest_success(
	controller: Node,
	harvest_dialog: Node,
	crafting_system: Node,
	resource_system: Node
) -> void:
	var item_id := "item_iron_helmet"
	var before := int(resource_system.get_resource(item_id))
	var selected: Dictionary = crafting_system.set_target("blacksmith", "craft_iron_helmet", true)
	_assert(bool(selected.get("ok", false)), "could not select harvest fixture recipe")
	var recipe: Dictionary = crafting_system.get_recipe("craft_iron_helmet")
	for _stage_index in range((recipe.get("stages", []) as Array).size()):
		var project: Dictionary = crafting_system.get_project_snapshot("blacksmith")
		_ensure_resources(resource_system, project.get("current_stage_cost", {}))
		var result: Dictionary = crafting_system.complete_stage(
			"blacksmith",
			int(project.get("project_revision", -1)),
			""
		)
		_assert(bool(result.get("ok", false)), "harvest fixture stage failed")
	_assert(int(crafting_system.get_pending_outputs("blacksmith").get(item_id, 0)) == 1, "fixture did not create one pending output")
	harvest_dialog.debug_open_for_building("blacksmith")
	await process_frame
	controller.debug_clear_history()
	var collection: Dictionary = harvest_dialog.debug_collect_all()
	await process_frame
	_assert(bool(collection.get("ok", false)), "formal harvest collection failed")
	_assert(int(resource_system.get_resource(item_id)) == before + 1, "successful harvest did not transfer inventory")
	_assert_last_ui(controller, "success", "sfx_ui_interaction_success_resource_collect")


func _assert_semantic_priority(controller: Node) -> void:
	controller.debug_clear_history()
	controller.debug_queue_ui_semantic("primary")
	controller.debug_queue_ui_semantic("success")
	controller.debug_flush_ui_semantic()
	var history: Array = controller.get_debug_snapshot().get("recent_history", [])
	_assert(history.size() == 1, "one-frame UI semantics produced overlapping sounds")
	_assert_last_ui(controller, "success", "sfx_ui_interaction_success_resource_collect")


func _assert_ordinary_door_registration(controller: Node) -> void:
	var ordinary_doors := get_nodes_in_group("building_auto_door")
	_assert(ordinary_doors.size() == 9, "all nine ordinary building doors must expose their live motion state")
	var door_states: Dictionary = controller.get_debug_snapshot().get("door_states", {})
	for raw_door in ordinary_doors:
		var door := raw_door as Node3D
		_assert(door != null and door.has_method("debug_get_snapshot"), "ordinary building door has no presentation snapshot")
		var snapshot: Dictionary = door.call("debug_get_snapshot")
		var building_id := str(snapshot.get("building_id", ""))
		_assert(not building_id.is_empty(), "ordinary building door did not resolve its owning building")
		_assert(door_states.has("building_door:%s" % building_id), "interaction controller did not prime %s ordinary door" % building_id)


func _assert_door_edges(controller: Node, main: Node) -> void:
	var source := Node3D.new()
	source.name = "P10GTestDoorSource"
	main.get_node("WorldRoot").add_child(source)
	source.global_position = Vector3(7.0, 0.0, -3.0)
	controller.debug_sample_door(source, "p10g_test_gate", 0.0, false)
	controller.debug_clear_history()
	controller.debug_sample_door(source, "p10g_test_gate", 0.2, false)
	_assert_last_world(controller, "door_open", "sfx_world_door_open", "p10g_test_gate", source.global_position)
	var count_after_open := (controller.get_debug_snapshot().get("recent_history", []) as Array).size()
	controller.debug_sample_door(source, "p10g_test_gate", 0.2, false)
	_assert((controller.get_debug_snapshot().get("recent_history", []) as Array).size() == count_after_open, "unchanged render sample reset the door direction")
	controller.debug_sample_door(source, "p10g_test_gate", 0.4, false)
	_assert((controller.get_debug_snapshot().get("recent_history", []) as Array).size() == count_after_open, "one opening motion replayed door audio every sample")
	controller.debug_sample_door(source, "p10g_test_gate", 0.2, false)
	_assert_last_world(controller, "door_close", "sfx_world_door_close", "p10g_test_gate", source.global_position)
	var count_before_destroyed := (controller.get_debug_snapshot().get("recent_history", []) as Array).size()
	controller.debug_sample_door(source, "p10g_test_gate", 0.0, true)
	_assert((controller.get_debug_snapshot().get("recent_history", []) as Array).size() == count_before_destroyed, "destroyed door collapse incorrectly played close audio")
	source.queue_free()


func _assert_merchant_motion(controller: Node, audio_manager: Node, merchant_system: Node) -> void:
	var merchant_before: Dictionary = merchant_system.get_market_snapshot()
	controller.debug_clear_history()
	controller.debug_sample_merchant({
		"wagon_state": "arriving",
		"wagon": {
			"active": true,
			"paused": false,
			"actual_speed": 2.0,
			"world_position": Vector3(-8.0, 0.0, -20.0),
		}
	})
	var snapshot: Dictionary = controller.get_debug_snapshot()
	_assert(bool(snapshot.get("merchant_loop_active", false)), "moving merchant wagon did not start its loop")
	_assert((snapshot.get("merchant_source_position", Vector3.ZERO) as Vector3).is_equal_approx(Vector3(-8.0, 0.35, -20.0)), "merchant loop source did not follow wagon position")
	var loop: Dictionary = audio_manager.get_loop_snapshot().get("interaction_merchant_cart_travel", {})
	_assert(str(loop.get("asset_id", "")) == "sfx_merchant_cart_arrival_departure", "merchant loop used the wrong asset")
	_assert(str(loop.get("bus", "")) == "World", "merchant loop did not route through World")
	controller.debug_sample_merchant({
		"wagon_state": "parked",
		"wagon": {
			"active": false,
			"paused": false,
			"actual_speed": 0.0,
			"world_position": Vector3(-4.0, 0.0, -15.0),
		}
	})
	_assert(not bool(controller.get_debug_snapshot().get("merchant_loop_active", true)), "parked merchant wagon did not stop immediately")
	_assert(not audio_manager.get_loop_snapshot().has("interaction_merchant_cart_travel"), "merchant loop player survived stop")
	_assert(merchant_system.get_market_snapshot() == merchant_before, "audio debug sampling changed MerchantSystem authority")


func _assert_bus_routes() -> void:
	var ui_index := AudioServer.get_bus_index(&"UI")
	var world_index := AudioServer.get_bus_index(&"World")
	_assert(ui_index >= 0 and AudioServer.get_bus_send(ui_index) == &"Master", "UI bus must be independent from SFX")
	_assert(world_index >= 0 and AudioServer.get_bus_send(world_index) == &"SFX", "World bus does not send to SFX")


func _assert_last_ui(controller: Node, semantic: String, asset_id: String) -> void:
	var history: Array = controller.get_debug_snapshot().get("recent_history", [])
	_assert(not history.is_empty(), "missing UI audio history for %s" % semantic)
	if history.is_empty():
		return
	var entry: Dictionary = history.back()
	_assert(str(entry.get("kind", "")) == "ui", "%s did not create a UI sound" % semantic)
	_assert(str(entry.get("semantic", "")) == semantic, "wrong UI semantic for %s" % semantic)
	_assert(str(entry.get("asset_id", "")) == asset_id, "wrong UI asset for %s" % semantic)
	_assert(str(entry.get("player_type", "")) == "AudioStreamPlayer", "%s is not 2D" % semantic)
	_assert(str(entry.get("bus", "")) == "UI", "%s did not route through UI" % semantic)


func _assert_last_world(
	controller: Node,
	semantic: String,
	asset_id: String,
	source_id: String,
	expected_position: Vector3
) -> void:
	var history: Array = controller.get_debug_snapshot().get("recent_history", [])
	_assert(not history.is_empty(), "missing world audio history for %s" % semantic)
	if history.is_empty():
		return
	var entry: Dictionary = history.back()
	_assert(str(entry.get("kind", "")) == "world_one_shot", "%s did not create a world one-shot" % semantic)
	_assert(str(entry.get("semantic", "")) == semantic, "wrong world semantic")
	_assert(str(entry.get("asset_id", "")) == asset_id, "wrong world asset for %s" % semantic)
	_assert(str(entry.get("source_id", "")) == source_id, "wrong world source id")
	_assert(str(entry.get("player_type", "")) == "AudioStreamPlayer3D", "%s is not positional" % semantic)
	_assert(str(entry.get("bus", "")) == "World", "%s did not route through World" % semantic)
	_assert((entry.get("world_position", Vector3.ZERO) as Vector3).is_equal_approx(expected_position), "%s used the wrong source position" % semantic)


func _ensure_resources(resource_system: Node, raw_cost: Variant) -> void:
	var cost: Dictionary = raw_cost if raw_cost is Dictionary else {}
	var additions := {}
	for raw_id in cost.keys():
		var resource_id := str(raw_id)
		var missing := maxi(0, int(cost.get(raw_id, 0)) - int(resource_system.get_resource(resource_id)))
		if missing > 0:
			additions[resource_id] = missing
	if not additions.is_empty():
		_assert(bool(resource_system.add_resources(additions)), "could not fund harvest fixture")


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_fail(message)


func _fail(message: String) -> bool:
	push_error("T0135 P10G verification failed: %s" % message)
	quit(1)
	return false
