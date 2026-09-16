extends SceneTree

const SettingsPanelClass = preload("res://scripts/ui/SettingsPanel.gd")
const ErrorPresenterClass = preload("res://scripts/ui/AIServiceErrorPresenter.gd")
const LLMBridgeClass = preload("res://scripts/systems/LLMBridge.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var settings := SettingsPanelClass.new()
	root.add_child(settings)
	await process_frame
	settings.open_panel(2)
	await process_frame
	var snapshot: Dictionary = settings.debug_get_snapshot()
	if snapshot.get("tab_names", []) != ["音量", "画面", "AI"]:
		_fail("AI settings tab is missing")
		return
	var api_key := settings.find_child("ApiKeyInput", true, false) as LineEdit
	var test_button := settings.find_child("TestAiConnectionButton", true, false) as Button
	if api_key == null or not api_key.secret or test_button == null:
		_fail("AI credential controls are incomplete")
		return
	api_key.text = "T0410_UI_SECRET"
	settings.debug_press_apply()
	await process_frame
	var client_settings := root.get_node_or_null("ClientSettings")
	var config_text := ""
	var file := FileAccess.open("user://client_settings.cfg", FileAccess.READ)
	if file != null:
		config_text = file.get_as_text()
		file.close()
	if config_text.contains("T0410_UI_SECRET") or bool(client_settings.debug_get_snapshot().get("contains_api_key", true)):
		_fail("API Key leaked into Godot client settings")
		return

	var presenter := ErrorPresenterClass.new()
	presenter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(presenter)
	await process_frame
	var bridge := LLMBridgeClass.new()
	root.add_child(bridge)
	bridge.call("_report_ai_service_error", {
		"error_code": "provider_rate_limited",
		"message": "Insufficient Balance",
		"response_code": 503,
		"body": {"usage": {"http_status": 429}},
	}, "dialogue")
	await process_frame
	var banner: Dictionary = presenter.debug_get_snapshot()
	var banner_text := str(banner.get("message", ""))
	if not bool(banner.get("visible", false)) or not banner_text.contains("provider_rate_limited") or not banner_text.contains("429") or not banner_text.contains("Insufficient Balance"):
		_fail("Main-scene AI error banner did not preserve code/status/message: %s" % banner)
		return
	bridge.call("_report_ai_service_error", {
		"error_code": "provider_queue_timeout",
		"message": "internal provider timeout detail",
		"response_code": 504,
	}, "dialogue")
	await process_frame
	banner = presenter.debug_get_snapshot()
	banner_text = str(banner.get("message", ""))
	if (
		not bool(banner.get("visible", false))
		or not banner_text.contains("provider_queue_timeout")
		or not banner_text.contains("504")
		or not banner_text.contains("DeepSeek 模型排队超时，请稍后重试。")
		or banner_text.contains("internal provider timeout detail")
	):
		_fail("DeepSeek queue timeout banner was not normalized: %s" % banner)
		return

	settings.queue_free()
	presenter.queue_free()
	bridge.queue_free()
	await process_frame
	print("T0410_AI_SERVICE_UI_PASS key_leak=false banner=code_http_message queue_timeout_hint=true")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
