extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn")
	if main_scene == null:
		push_error("Main scene failed to load.")
		quit(1)
		return

	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var camera_rig := root.get_node_or_null("Main/CameraRig") as Node3D
	var ui := root.get_node_or_null("Main/UI")
	if camera_rig == null or ui == null:
		push_error("CameraRig or UI root is missing.")
		quit(1)
		return

	camera_rig.set_process(false)
	camera_rig.global_position = Vector3.ZERO
	var press_s := _make_key_event(KEY_S, true)
	var release_s := _make_key_event(KEY_S, false)
	camera_rig._input(press_s)
	camera_rig._process(0.25)
	var moved_position := camera_rig.global_position
	if moved_position.is_equal_approx(Vector3.ZERO):
		push_error("A received S press should move the camera.")
		quit(1)
		return

	camera_rig._input(release_s)
	camera_rig._process(0.25)
	if not camera_rig.global_position.is_equal_approx(moved_position):
		push_error("An S release should stop camera movement immediately.")
		quit(1)
		return

	camera_rig._input(press_s)
	camera_rig._is_middle_dragging = true
	camera_rig.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var focus_loss_position := camera_rig.global_position
	camera_rig._process(0.25)
	if not camera_rig.global_position.is_equal_approx(focus_loss_position):
		push_error("Application focus loss should clear held camera keys.")
		quit(1)
		return
	if camera_rig._is_middle_dragging:
		push_error("Application focus loss should cancel middle-mouse dragging.")
		quit(1)
		return

	var text_input := LineEdit.new()
	ui.add_child(text_input)
	text_input.grab_focus()
	await process_frame
	camera_rig._input(press_s)
	var text_focus_position := camera_rig.global_position
	camera_rig._process(0.25)
	if not camera_rig.global_position.is_equal_approx(text_focus_position):
		push_error("WASD should not move the camera while a text input owns focus.")
		quit(1)
		return

	text_input.release_focus()
	camera_rig._input(press_s)
	camera_rig._process(0.25)
	if camera_rig.global_position.is_equal_approx(text_focus_position):
		push_error("Camera movement should resume after text input releases focus.")
		quit(1)
		return
	camera_rig._input(release_s)

	main.queue_free()
	await process_frame
	print("T0045 camera input lifecycle verification passed.")
	quit(0)


func _make_key_event(key: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	return event
