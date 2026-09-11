extends SceneTree


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("T0334 could not load Main.tscn")
		return
	root.add_child(packed.instantiate())
	for _index in range(8):
		await process_frame

	var main := root.get_node_or_null("Main")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var birth_button := root.find_child("FoalBirthNamingButton", true, false) as Button
	var horse_select := root.find_child("HorseSelect", true, false) as OptionButton
	var birth_dialog := root.get_node_or_null("Main/UI/MilestoneAlertPresenter/HorseBirthNamingDialog") as AcceptDialog
	var name_input := root.get_node_or_null("Main/UI/MilestoneAlertPresenter/HorseBirthNamingDialog/HorseBirthContent/Content/HorseNameInput") as LineEdit
	var horse_panel := root.get_node_or_null("Main/UI/HorsePanel")
	if main == null or horse_system == null or gm_panel == null or birth_button == null or horse_select == null or birth_dialog == null or name_input == null or horse_panel == null:
		_fail("T0334 runtime dependencies are missing")
		return
	if birth_button.text != "小马出生并命名" or birth_button.get_parent() == horse_select.get_parent():
		_fail("T0334 birth button is not the dedicated labeled GM row")
		return

	var initial_count := int(horse_system.get_horse_count())
	birth_button.pressed.emit()
	await process_frame
	var pending: Dictionary = horse_system.get_pending_birth_snapshot()
	if pending.is_empty() or not birth_dialog.visible or int(horse_system.get_horse_count()) != initial_count:
		_fail("T0334 GM button did not open formal naming before insertion")
		return
	if name_input.text != str(pending.get("default_name", "")) or name_input.max_length != 5:
		_fail("T0334 naming UI did not preload the template name or five-character limit")
		return

	var custom_name := "晓星"
	name_input.text = custom_name
	birth_dialog.get_ok_button().pressed.emit()
	for _index in range(6):
		await process_frame
	var horse_id := str(pending.get("horse_id", ""))
	var horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
	if int(horse_system.get_horse_count()) != initial_count + 1 or str(horse.get("name", "")) != custom_name or birth_dialog.visible:
		_fail("T0334 named foal was not inserted exactly once")
		return
	if horse_select.get_item_count() != int(horse_system.get_horse_count()) or not _select_contains_id(horse_select, horse_id):
		_fail("T0334 GM horse selector did not refresh after naming confirmation")
		return
	var presentation: Dictionary = horse_system.get_horse_presentation_snapshot(horse_id)
	if str(presentation.get("name", "")) != custom_name:
		_fail("T0334 world presentation did not use the official foal name")
		return
	horse_panel.show_horse(horse_id)
	await process_frame
	if not JSON.stringify(horse_panel.debug_get_snapshot()).contains(custom_name):
		_fail("T0334 HorsePanel did not show the official foal name")
		return

	print("T0334_GM_FOAL_BIRTH_BUTTON_OK")
	quit(0)


func _select_contains_id(select: OptionButton, expected_id: String) -> bool:
	for index in range(select.get_item_count()):
		if str(select.get_item_metadata(index)) == expected_id:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
