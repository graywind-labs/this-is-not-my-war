extends SceneTree


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("T0315 could not load Main.tscn")
		return
	root.add_child(packed.instantiate())
	for _index in range(8):
		await process_frame

	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var presenter := root.get_node_or_null("Main/UI/MilestoneAlertPresenter")
	var building_dialog := root.get_node_or_null("Main/UI/MilestoneAlertPresenter/BuildingCompletionDialog") as AcceptDialog
	var horse_dialog := root.get_node_or_null("Main/UI/MilestoneAlertPresenter/HorseBirthNamingDialog") as AcceptDialog
	var name_input := root.get_node_or_null("Main/UI/MilestoneAlertPresenter/HorseBirthNamingDialog/HorseBirthContent/Content/HorseNameInput") as LineEdit
	var horse_panel := root.get_node_or_null("Main/UI/HorsePanel")
	if building_system == null or horse_system == null or memory_system == null or presenter == null or building_dialog == null or horse_dialog == null or name_input == null or horse_panel == null:
		_fail("T0315 runtime dependencies are missing")
		return

	if not building_system.debug_damage_building("wall", 20) or not building_system.repair_building("wall"):
		_fail("T0315 could not start a real wall repair")
		return
	building_system._on_logical_time_tick(999999.0, 1.0)
	await process_frame
	var snapshot: Dictionary = presenter.debug_get_snapshot()
	if not bool(snapshot.get("building_dialog_visible", false)) or str(snapshot.get("building_dialog_text", "")) != "围墙修复完成。" or str(snapshot.get("building_button_text", "")) != "确认":
		_fail("Real repair completion did not show the requested confirmation: %s" % JSON.stringify(snapshot))
		return

	if not building_system.upgrade_building("wall"):
		_fail("T0315 could not start a real wall upgrade after repair")
		return
	building_system._on_logical_time_tick(999999.0, 1.0)
	await process_frame
	snapshot = presenter.debug_get_snapshot()
	if str(snapshot.get("building_dialog_text", "")) != "围墙修复完成。" or int(snapshot.get("queued_count", 0)) != 1:
		_fail("Upgrade completion did not queue behind the visible repair result: %s" % JSON.stringify(snapshot))
		return
	building_dialog.get_ok_button().pressed.emit()
	await process_frame
	await process_frame
	snapshot = presenter.debug_get_snapshot()
	if not bool(snapshot.get("building_dialog_visible", false)) or str(snapshot.get("building_dialog_text", "")) != "围墙升级完成。":
		_fail("Queued upgrade completion did not advance through the 确认 button: %s" % JSON.stringify(snapshot))
		return

	var initial_count := int(horse_system.get_horse_count())
	var events_before := int(memory_system.get_event_count())
	var birth_request: Dictionary = horse_system.debug_force_birth()
	if not bool(birth_request.get("ok", false)) or not bool(birth_request.get("pending_naming", false)):
		_fail("GM force birth did not enter the formal naming flow: %s" % JSON.stringify(birth_request))
		return
	if int(horse_system.get_horse_count()) != initial_count or not horse_system.get_horse_snapshot(str(birth_request.get("horse_id", ""))).is_empty():
		_fail("Pending foal entered the official horse registry before naming")
		return
	if int(memory_system.get_event_count()) != events_before:
		_fail("Pending foal recorded an event before naming confirmation")
		return
	snapshot = presenter.debug_get_snapshot()
	if str(snapshot.get("current_kind", "")) != "building" or int(snapshot.get("queued_count", 0)) != 1:
		_fail("Foal naming did not queue behind the visible building completion: %s" % JSON.stringify(snapshot))
		return
	building_dialog.get_ok_button().pressed.emit()
	await process_frame
	await process_frame
	snapshot = presenter.debug_get_snapshot()
	if (
		not bool(snapshot.get("horse_dialog_visible", false))
		or str(snapshot.get("horse_dialog_text", "")) != "在精心照料下，一匹小马出生了！你给他命名为"
		or str(snapshot.get("horse_name", "")) != str(birth_request.get("default_name", ""))
		or int(snapshot.get("horse_name_max_length", 0)) != 5
	):
		_fail("Foal naming dialog text, preset, or five-character limit is wrong: %s" % JSON.stringify(snapshot))
		return

	var too_long: Dictionary = horse_system.confirm_pending_foal_name(str(birth_request.get("request_id", "")), "一二三四五六")
	if bool(too_long.get("ok", false)) or str(too_long.get("reason", "")) != "name_too_long" or int(horse_system.get_horse_count()) != initial_count:
		_fail("HorseSystem did not enforce the authoritative five-character limit: %s" % JSON.stringify(too_long))
		return
	name_input.text = "   "
	horse_dialog.get_ok_button().pressed.emit()
	await process_frame
	snapshot = presenter.debug_get_snapshot()
	if not bool(snapshot.get("horse_dialog_visible", false)) or str(snapshot.get("horse_validation_text", "")).is_empty() or int(horse_system.get_horse_count()) != initial_count:
		_fail("Empty horse name was not blocked in the visible dialog: %s" % JSON.stringify(snapshot))
		return

	var custom_name := "新月"
	name_input.text = custom_name
	horse_dialog.get_ok_button().pressed.emit()
	for _index in range(6):
		await process_frame
	var horse_id := str(birth_request.get("horse_id", ""))
	var named_horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
	if int(horse_system.get_horse_count()) != initial_count + 1 or str(named_horse.get("name", "")) != custom_name or not horse_system.get_pending_birth_snapshot().is_empty() or horse_dialog.visible:
		_fail("Custom name did not become the official horse identity: %s" % JSON.stringify(named_horse))
		return
	var birth_events: Array[Dictionary] = []
	for event in memory_system.get_all_events():
		if str(event.get("type", "")) == "horse_born" and str((event.get("payload", {}) as Dictionary).get("horse_id", "")) == horse_id:
			birth_events.append(event)
	if birth_events.size() != 1 or str(birth_events[0].get("summary", "")) != "一匹小马出生了，守备官给它取名为%s。" % custom_name:
		_fail("Named birth event was not recorded exactly once after official insertion: %s" % JSON.stringify(birth_events))
		return

	var presentation: Dictionary = horse_system.get_horse_presentation_snapshot(horse_id)
	if str(presentation.get("name", "")) != custom_name:
		_fail("World horse name did not read the official custom name: %s" % JSON.stringify(presentation))
		return
	horse_panel.show_horse(horse_id)
	await process_frame
	var panel_snapshot: Dictionary = horse_panel.debug_get_snapshot()
	if str(panel_snapshot.get("name", "")) != custom_name and not JSON.stringify(panel_snapshot).contains(custom_name):
		_fail("HorsePanel did not show the official custom name: %s" % JSON.stringify(panel_snapshot))
		return

	var default_request: Dictionary = horse_system.debug_force_birth()
	await process_frame
	if not bool(default_request.get("ok", false)) or name_input.text != str(default_request.get("default_name", "")):
		_fail("Second birth did not preload its matching template name: %s" % JSON.stringify(default_request))
		return
	horse_dialog.get_ok_button().pressed.emit()
	for _index in range(4):
		await process_frame
	var default_horse: Dictionary = horse_system.get_horse_snapshot(str(default_request.get("horse_id", "")))
	if str(default_horse.get("name", "")) != str(default_request.get("default_name", "")):
		_fail("Confirming without edits did not preserve the template name: %s" % JSON.stringify(default_horse))
		return

	print("T0315_MILESTONE_AND_FOAL_NAMING_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
