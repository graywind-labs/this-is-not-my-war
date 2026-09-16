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
	camera_rig._clamp_position()
	var baseline_position := camera_rig.global_position
	var press_s := _make_key_event(KEY_S, true)
	var release_s := _make_key_event(KEY_S, false)
	camera_rig._input(press_s)
	camera_rig._process(0.25)
	var moved_position := camera_rig.global_position
	var normal_displacement := moved_position - baseline_position
	if normal_displacement.is_zero_approx():
		push_error("A received S press should move the camera.")
		quit(1)
		return
	if not is_equal_approx(camera_rig.keyboard_pan_speed, 28.0) or not is_equal_approx(normal_displacement.length(), 7.0):
		push_error("WASD should use the 28 m/s base speed: configured=%s displacement=%s." % [camera_rig.keyboard_pan_speed, normal_displacement.length()])
		quit(1)
		return

	camera_rig._input(release_s)
	camera_rig.global_position = baseline_position
	var press_shift := _make_key_event(KEY_SHIFT, true)
	var release_shift := _make_key_event(KEY_SHIFT, false)
	camera_rig._input(press_shift)
	camera_rig._input(_make_key_event(KEY_S, true, true))
	camera_rig._process(0.25)
	var boosted_position := camera_rig.global_position
	var boosted_displacement := boosted_position - baseline_position
	if not is_equal_approx(boosted_displacement.length(), 14.0) or not is_equal_approx(boosted_displacement.length(), normal_displacement.length() * 2.0):
		push_error("Shift + WASD should move the camera at exactly 2x speed: normal=%s boosted=%s multiplier_active=%s." % [moved_position, boosted_position, camera_rig._is_keyboard_pan_boost_active])
		quit(1)
		return
	camera_rig._input(_make_key_event(KEY_S, false, true))
	camera_rig._input(release_shift)
	camera_rig.global_position = moved_position

	camera_rig._input(release_s)
	camera_rig._process(0.25)
	if not camera_rig.global_position.is_equal_approx(moved_position):
		push_error("An S release should stop camera movement immediately.")
		quit(1)
		return

	if camera_rig.process_mode != Node.PROCESS_MODE_ALWAYS:
		push_error("CameraRig must keep receiving release events while SceneTree is paused.")
		quit(1)
		return
	camera_rig._input(_make_key_event(KEY_D, true))
	if not camera_rig._pressed_pan_keys.has(KEY_D):
		push_error("D should be cached before entering the pause menu.")
		quit(1)
		return
	paused = true
	camera_rig._process(0.25)
	camera_rig._input(_make_key_event(KEY_D, false))
	camera_rig._input(_make_key_event(KEY_A, true))
	var paused_zoom := float(camera_rig.get_zoom_distance())
	var paused_middle_press := InputEventMouseButton.new()
	paused_middle_press.button_index = MOUSE_BUTTON_MIDDLE
	paused_middle_press.pressed = true
	camera_rig._unhandled_input(paused_middle_press)
	var paused_wheel := InputEventMouseButton.new()
	paused_wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	paused_wheel.pressed = true
	camera_rig._unhandled_input(paused_wheel)
	var paused_position := camera_rig.global_position
	camera_rig._process(0.25)
	if not camera_rig.global_position.is_equal_approx(paused_position):
		push_error("Camera input must not move while SceneTree is paused.")
		paused = false
		quit(1)
		return
	if not camera_rig._pressed_pan_keys.is_empty():
		push_error("Pause-time releases or presses must leave no cached WASD state.")
		paused = false
		quit(1)
		return
	if camera_rig._is_middle_dragging or not is_equal_approx(float(camera_rig.get_zoom_distance()), paused_zoom):
		push_error("Pause-time middle drag and wheel input must not change camera state.")
		paused = false
		quit(1)
		return
	paused = false
	camera_rig._process(0.25)
	if not camera_rig.global_position.is_equal_approx(paused_position):
		push_error("Resuming after a pause-time D release must not continue panning.")
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

	var lock_result: Dictionary = camera_rig.request_camera_control_lock("verification")
	if not bool(lock_result.get("ok", false)) or not camera_rig.is_camera_control_locked():
		push_error("Camera control lock request should become active.")
		quit(1)
		return
	var locked_position := camera_rig.global_position
	var locked_zoom := float(camera_rig.get_zoom_distance())
	camera_rig._input(press_s)
	camera_rig._process(0.25)
	var wheel_event := InputEventMouseButton.new()
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_event.pressed = true
	camera_rig._unhandled_input(wheel_event)
	if not camera_rig.global_position.is_equal_approx(locked_position) or not is_equal_approx(float(camera_rig.get_zoom_distance()), locked_zoom):
		push_error("Camera control lock should silently block player pan and zoom input.")
		quit(1)
		return
	var unlock_result: Dictionary = camera_rig.release_camera_control_lock("verification")
	if not bool(unlock_result.get("ok", false)) or camera_rig.is_camera_control_locked():
		push_error("Camera control lock should release by request id.")
		quit(1)
		return

	main.queue_free()
	await process_frame
	print("T0045C camera input speed, pause release, and lifecycle verification passed.")
	quit(0)


func _make_key_event(key: Key, pressed: bool, shift_pressed: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	event.shift_pressed = shift_pressed
	return event
