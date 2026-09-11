extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	for _frame in 8:
		await process_frame
		await physics_frame

	var horse_panel := root.get_node_or_null("Main/UI/HorsePanel") as Control
	if horse_panel == null:
		_fail("HorsePanel is missing")
		return
	horse_panel.debug_set_layout_viewport_override(Vector2(1280, 720))
	horse_panel.show_horse("horse_chestnut_wind")
	await process_frame
	await process_frame

	var info_panel := horse_panel.find_child("HorseInfoPanel", true, false) as Control
	var breeding_progress := horse_panel.find_child("HorseBreedingProbability", true, false) as Control
	var panel_row := horse_panel.find_child("HorsePanelRow", true, false) as HBoxContainer
	var portrait := panel_row.get_child(0) as Control if panel_row != null and panel_row.get_child_count() > 0 else null
	if info_panel == null or breeding_progress == null or portrait == null:
		_fail("HorsePanel compact-layout controls are missing")
		return
	var panel_rect := horse_panel.get_global_rect()
	var info_rect := info_panel.get_global_rect()
	var breeding_rect := breeding_progress.get_global_rect()
	var bottom_gap := info_rect.end.y - breeding_rect.end.y
	if absf(panel_rect.size.x - 650.0) > 0.1 or absf(panel_rect.size.y - 440.0) > 0.1:
		_fail("HorsePanel should remain 650px wide and shrink to 440px high: %s" % panel_rect)
		return
	if bottom_gap < 12.0 or bottom_gap > 48.0:
		_fail("HorsePanel breeding-row bottom gap is still excessive or too tight: %.2f" % bottom_gap)
		return
	if portrait.size.x < 190.0 or portrait.size.x > 210.0 or portrait.size.y < 300.0:
		_fail("Horse portrait sizing changed while compacting the info panel: %s" % portrait.get_global_rect())
		return
	for control_name in ["HorseBaseHP", "HorseExtraHP", "HorseSatiety", "HorseGrowth", "HorseBreedingProbability"]:
		var progress := horse_panel.find_child(control_name, true, false) as Control
		if progress == null or not progress.is_visible_in_tree():
			_fail("Compact HorsePanel lost progress control %s" % control_name)
			return

	print("T0337_HORSE_PANEL_COMPACT_HEIGHT PASS gap=%.2f" % bottom_gap)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
