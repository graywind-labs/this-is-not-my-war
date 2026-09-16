extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	var client_settings := root.get_node_or_null("ClientSettings")
	if client_settings == null:
		_fail("ClientSettings autoload is missing")
		return
	if int(ProjectSettings.get_setting("display/window/size/mode", -1)) != Window.MODE_FULLSCREEN:
		_fail("Project window must be created in fullscreen mode before the first frame")
		return
	var defaults: Dictionary = client_settings.get_default_snapshot()
	if str(defaults.get("display_mode", "")) != "fullscreen":
		_fail("Fresh client settings must default to fullscreen")
		return

	var original: Dictionary = client_settings.get_snapshot()
	var explicit_windowed := defaults.duplicate(true)
	explicit_windowed["display_mode"] = "windowed"
	client_settings.apply_settings(explicit_windowed, false)
	if str(client_settings.get_snapshot().get("display_mode", "")) != "windowed":
		_fail("An explicit player windowed preference was not preserved")
		return
	client_settings.reset_to_defaults(false)
	if str(client_settings.get_snapshot().get("display_mode", "")) != "fullscreen":
		_fail("Reset to defaults did not restore fullscreen")
		return
	client_settings.apply_settings(original, false)
	print("T1703_P5_DEFAULT_FULLSCREEN_PASS project=fullscreen fresh=fullscreen explicit_windowed=preserved")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
