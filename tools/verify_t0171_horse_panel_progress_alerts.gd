extends SceneTree


const NORMAL_FILL := "71865aff"
const DANGER_FILL := "a7433bff"
const DANGER_LABEL := "dc6157ff"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	root.add_child(packed.instantiate())
	for _index in range(8):
		await physics_frame
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var horse_panel := root.get_node_or_null("Main/UI/HorsePanel")
	if horse_system == null or horse_panel == null:
		_fail("T0171 runtime dependencies are missing")
		return
	horse_panel.debug_set_layout_viewport_override(Vector2(1280, 720))
	horse_panel.show_horse("horse_gray_mane")
	var horse: Dictionary = horse_system.get_horse_snapshot("horse_gray_mane")
	if horse.is_empty():
		_fail("Gray horse snapshot is missing")
		return

	var normal := horse.duplicate(true)
	normal["base_hp"] = 100.0
	normal["natural_max_hp"] = 100.0
	normal["extra_hp"] = 0.0
	normal["extra_hp_cap"] = 20.0
	normal["satiety"] = 100.0
	normal["max_satiety"] = 100.0
	normal["growth"] = 0.0
	normal["breeding_probability"] = 0.0
	horse_panel._refresh(normal)
	if not _verify_rows(horse_panel.debug_get_snapshot(), false, false, "normal"):
		return

	var boundary := normal.duplicate(true)
	boundary["base_hp"] = 30.0
	boundary["satiety"] = 20.0
	horse_panel._refresh(boundary)
	if not _verify_rows(horse_panel.debug_get_snapshot(), false, false, "boundary"):
		return

	var low := normal.duplicate(true)
	low["base_hp"] = 29.0
	low["satiety"] = 19.0
	horse_panel._refresh(low)
	if not _verify_rows(horse_panel.debug_get_snapshot(), true, true, "low"):
		return

	horse_panel._refresh(boundary)
	if not _verify_rows(horse_panel.debug_get_snapshot(), false, false, "recovered"):
		return

	print("T0171_HORSE_PANEL_PROGRESS_ALERTS PASS")
	quit(0)


func _verify_rows(snapshot: Dictionary, hp_danger: bool, satiety_danger: bool, phase: String) -> bool:
	var rows: Dictionary = snapshot.get("progress_rows", {})
	for row_id in ["base_hp", "extra_hp", "satiety", "growth", "breeding"]:
		var row: Dictionary = rows.get(row_id, {})
		if not bool(row.get("label_before_progress", false)):
			_fail("%s label is not immediately above its progress bar during %s: %s" % [row_id, phase, JSON.stringify(row)])
			return false
	var expected_danger := {
		"base_hp": hp_danger,
		"extra_hp": false,
		"satiety": satiety_danger,
		"growth": false,
		"breeding": false,
	}
	for row_id in expected_danger.keys():
		var row: Dictionary = rows.get(row_id, {})
		var danger: bool = bool(expected_danger[row_id])
		if bool(row.get("danger", false)) != danger:
			_fail("%s danger state mismatch during %s: %s" % [row_id, phase, JSON.stringify(row)])
			return false
		var expected_fill := DANGER_FILL if danger else NORMAL_FILL
		if str(row.get("fill_color", "")) != expected_fill:
			_fail("%s fill mismatch during %s: %s" % [row_id, phase, JSON.stringify(row)])
			return false
		var label_color := str(row.get("label_color", ""))
		if danger and label_color != DANGER_LABEL:
			_fail("%s danger label mismatch during %s: %s" % [row_id, phase, JSON.stringify(row)])
			return false
		if not danger and label_color == DANGER_LABEL:
			_fail("%s label stayed red during %s: %s" % [row_id, phase, JSON.stringify(row)])
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
