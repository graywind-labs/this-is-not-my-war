extends SceneTree


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main scene failed to load")
		return
	root.add_child(packed.instantiate())
	await process_frame
	await process_frame

	var panel := root.get_node_or_null("Main/UI/BuildingPanel") as Control
	var phase_label := root.get_node_or_null("Main/UI/HUD/PhaseLabel") as Label
	if panel == null or phase_label == null:
		_fail("Required UI nodes are missing")
		return
	if phase_label.text.is_empty() or phase_label.text.begins_with("阶段："):
		_fail("HUD phase label still contains the redundant prefix: %s" % phase_label.text)
		return

	panel.show_building("main_hall")
	await process_frame
	var location_label := panel.find_child("BuildingLocationLabel", true, false) as Label
	if location_label == null:
		_fail("Building location label is missing")
		return
	if location_label.text.contains("建筑状态：") or location_label.text.contains("当前运行效率："):
		_fail("Building panel still exposes removed status fields: %s" % location_label.text)
		return

	panel.show_building("blacksmith")
	await process_frame
	var crafting_section := panel.find_child("CraftingSection", true, false) as VBoxContainer
	if crafting_section == null:
		_fail("Crafting section is missing")
		return
	var has_target_label := false
	for raw_label in crafting_section.find_children("*", "Label", true, false):
		var label := raw_label as Label
		if label.text == "制造项目":
			_fail("Crafting section still contains the removed title")
			return
		if label.text == "制造目标：":
			has_target_label = true
	if not has_target_label:
		_fail("Crafting target label was not renamed")
		return

	print("UI debug panel text cleanup verification passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
