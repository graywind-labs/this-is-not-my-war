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
	var original: Dictionary = client_settings.get_snapshot()
	var apply_count := int(client_settings.debug_get_snapshot().get("display_settings_apply_count", -1))

	client_settings.apply_settings(original, false)
	if int(client_settings.debug_get_snapshot().get("display_settings_apply_count", -1)) != apply_count:
		_fail("Submitting an unchanged settings draft reapplied native display settings")
		return

	var non_display_draft := original.duplicate(true)
	non_display_draft["blood_enabled"] = not bool(original.get("blood_enabled", true))
	non_display_draft["ai_mode"] = "custom" if str(original.get("ai_mode", "trial")) == "trial" else "trial"
	client_settings.apply_settings(non_display_draft, false)
	if int(client_settings.debug_get_snapshot().get("display_settings_apply_count", -1)) != apply_count:
		_fail("Submitting non-display settings reapplied native display settings")
		return

	var display_draft := non_display_draft.duplicate(true)
	display_draft["max_fps"] = 120 if int(original.get("max_fps", 60)) != 120 else 60
	client_settings.apply_settings(display_draft, false)
	if int(client_settings.debug_get_snapshot().get("display_settings_apply_count", -1)) != apply_count + 1:
		_fail("A real display setting change did not apply native display settings exactly once")
		return

	client_settings.apply_settings(original, false)
	print("T0354_R1_AUDIO_APPLY_PRESERVES_WINDOW_PASS unchanged=preserved non_display=preserved display_change=applied")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
