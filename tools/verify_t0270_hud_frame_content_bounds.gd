extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const EXPECTED_PADDING := 12.0
const PADDING_EPSILON := 0.1


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(3):
		await process_frame

	var hud := root.get_node_or_null("Main/UI/HUD")
	if hud == null or not hud.has_method("debug_get_hud_frame_layout_snapshot"):
		_fail("HUD frame layout snapshot is unavailable")
		return

	var snapshot: Dictionary = hud.debug_get_hud_frame_layout_snapshot()
	if not bool(snapshot.get("contains_content", false)):
		_fail("HUD frame does not contain its permanent content: %s" % snapshot)
		return
	if absf(float(snapshot.get("right_padding", 0.0)) - EXPECTED_PADDING) > PADDING_EPSILON:
		_fail("HUD frame right padding is not stable: %s" % snapshot)
		return
	if absf(float(snapshot.get("bottom_padding", 0.0)) - EXPECTED_PADDING) > PADDING_EPSILON:
		_fail("HUD frame bottom padding is not stable: %s" % snapshot)
		return

	var resource_strip := hud.get_node_or_null("ResourceStrip") as HBoxContainer
	var frame := hud.get_node_or_null("HUDFrame") as Panel
	var piety_button := hud.get_node_or_null("PietyAbilityButton") as Control
	if resource_strip == null or frame == null or piety_button == null:
		_fail("HUD permanent controls are missing")
		return
	var devices_button := resource_strip.get_node_or_null("DevicesDetailButton") as Button
	if devices_button == null:
		_fail("HUD devices detail button is missing")
		return
	var frame_end := frame.position + frame.size
	if devices_button.global_position.x + devices_button.size.x > frame_end.x + 0.01:
		_fail("Devices button still overflows the HUD frame")
		return
	if piety_button.global_position.y + piety_button.size.y > frame_end.y + 0.01:
		_fail("Piety button still overflows the HUD frame")
		return

	print("T0270_HUD_FRAME_LAYOUT=%s" % JSON.stringify(snapshot))
	print("T0270 HUD frame content bounds verification passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
