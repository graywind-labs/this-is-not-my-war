extends SceneTree


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Could not load Main.tscn")
		return
	root.add_child(packed.instantiate())
	await process_frame
	await process_frame

	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as PanelContainer
	if gm_window == null:
		_fail("GMWindow is missing")
		return
	var quick_row := gm_window.find_child("GMQuickActions", true, false) as HBoxContainer
	var preset_button := gm_window.find_child("RecruitAndEquipAllButton", true, false) as Button
	if quick_row == null or preset_button == null or preset_button.get_parent() != quick_row:
		_fail("One-click recruit/equip is not in the fixed quick-actions row")
		return
	var cursor: Node = preset_button
	while cursor != null and cursor != gm_window:
		if cursor is ScrollContainer:
			_fail("One-click recruit/equip still requires scrolling")
			return
		cursor = cursor.get_parent()

	var tabs := gm_window.find_child("GMSectionTabs", true, false) as TabContainer
	if tabs == null or tabs.get_tab_count() != 5:
		_fail("GM panel does not contain the five organized tabs")
		return
	var expected_tabs := ["常用", "世界建筑", "制造马匹", "正式行动", "AI信息"]
	for index in range(expected_tabs.size()):
		if tabs.get_tab_title(index) != expected_tabs[index]:
			_fail("GM tab order/title mismatch at %d: %s" % [index, tabs.get_tab_title(index)])
			return
		var page := tabs.get_child(index)
		if not page is ScrollContainer:
			_fail("GM tab %s does not own an independent scroll container" % expected_tabs[index])
			return

	for obsolete_name in [
		"SpawnFirstWaveButton", "StationLayoutLegacyCompatibilityButton",
		"ChibiFormalGlenWorkButton", "ChibiFormalSwordShieldWaveButton",
		"GlenNavigationPilotButton", "ClinicDoctorNavigationPilotButton",
		"ClinicBedNavigationPilotButton", "DormitoryNavigationPilotButton",
		"DiningNavigationPilotButton", "ChapelNavigationPilotButton",
		"StableNavigationPilotButton"
	]:
		if gm_window.find_child(obsolete_name, true, false) != null:
			_fail("Superseded GM control remains visible: %s" % obsolete_name)
			return
	if gm_window.find_child("SpawnSelectedWaveButton", true, false) == null:
		_fail("Generic selected-wave spawn button is missing")
		return

	print("T0166_GM_PANEL_ORGANIZATION_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
