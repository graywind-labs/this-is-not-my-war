extends SceneTree

const MAIN_MENU_SCENE := preload("res://scenes/frontend/MainMenu.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var watchdog := create_timer(5.0, true, false, true)
	watchdog.timeout.connect(func() -> void: _fail("Main menu exit confirmation did not terminate the SceneTree"))
	var menu := MAIN_MENU_SCENE.instantiate()
	root.add_child(menu)
	for _index in range(4):
		await process_frame
	var exit_button := menu.find_child("ExitButton", true, false) as Button
	var exit_dialog := menu.get_node_or_null("ExitConfirmationDialog") as ConfirmationDialog
	if exit_button == null or exit_dialog == null:
		_fail("Main menu exit controls are missing")
		return
	exit_button.pressed.emit()
	await process_frame
	if not exit_dialog.visible:
		_fail("Main menu exit button did not open its confirmation dialog")
		return
	print("T1703_MAIN_MENU_EXIT_CONFIRMATION_READY")
	exit_dialog.confirmed.emit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
