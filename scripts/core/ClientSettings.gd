extends Node

signal settings_changed(snapshot: Dictionary)

const SETTINGS_PATH := "user://client_settings.cfg"
const DEFAULT_DISPLAY_MODE := "windowed"
const DEFAULT_RESOLUTION := Vector2i(1280, 720)
const DEFAULT_VSYNC := true
const DEFAULT_MAX_FPS := 60
const DEFAULT_UI_SCALE := 1.0
const DEFAULT_BLOOD_ENABLED := true
const DEFAULT_AI_MODE := "trial"
const DEFAULT_AI_PROVIDER := "openai_compatible"
const DEFAULT_AI_MODEL := ""
const DEFAULT_AI_BASE_URL := ""

var _settings: Dictionary = {}


func _ready() -> void:
	_settings = get_default_snapshot()
	_load_settings()
	call_deferred("apply_display_settings")


func get_default_snapshot() -> Dictionary:
	return {
		"display_mode": DEFAULT_DISPLAY_MODE,
		"resolution": DEFAULT_RESOLUTION,
		"vsync": DEFAULT_VSYNC,
		"max_fps": DEFAULT_MAX_FPS,
		"ui_scale": DEFAULT_UI_SCALE,
		"blood_enabled": DEFAULT_BLOOD_ENABLED,
		"ai_mode": DEFAULT_AI_MODE,
		"ai_provider": DEFAULT_AI_PROVIDER,
		"ai_model": DEFAULT_AI_MODEL,
		"ai_base_url": DEFAULT_AI_BASE_URL,
	}


func get_snapshot() -> Dictionary:
	return _settings.duplicate(true)


func apply_settings(snapshot: Dictionary, persist := true) -> Dictionary:
	var defaults := get_default_snapshot()
	_settings = {
		"display_mode": _normalize_display_mode(str(snapshot.get("display_mode", defaults["display_mode"]))),
		"resolution": _normalize_resolution(snapshot.get("resolution", defaults["resolution"])),
		"vsync": bool(snapshot.get("vsync", defaults["vsync"])),
		"max_fps": clampi(int(snapshot.get("max_fps", defaults["max_fps"])), 0, 240),
		"ui_scale": clampf(float(snapshot.get("ui_scale", defaults["ui_scale"])), 0.8, 1.4),
		"blood_enabled": bool(snapshot.get("blood_enabled", defaults["blood_enabled"])),
		"ai_mode": "custom" if str(snapshot.get("ai_mode", defaults["ai_mode"])) == "custom" else "trial",
		"ai_provider": str(snapshot.get("ai_provider", defaults["ai_provider"])).strip_edges(),
		"ai_model": str(snapshot.get("ai_model", defaults["ai_model"])).strip_edges(),
		"ai_base_url": str(snapshot.get("ai_base_url", defaults["ai_base_url"])).strip_edges(),
	}
	apply_display_settings()
	var saved := true
	if persist:
		saved = save_settings()
	settings_changed.emit(get_snapshot())
	return {"ok": saved, "snapshot": get_snapshot(), "api_key_persisted": false}


func reset_to_defaults(persist := true) -> Dictionary:
	return apply_settings(get_default_snapshot(), persist)


func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value("display", "mode", str(_settings.get("display_mode", DEFAULT_DISPLAY_MODE)))
	var resolution: Vector2i = _settings.get("resolution", DEFAULT_RESOLUTION)
	config.set_value("display", "width", resolution.x)
	config.set_value("display", "height", resolution.y)
	config.set_value("display", "vsync", bool(_settings.get("vsync", DEFAULT_VSYNC)))
	config.set_value("display", "max_fps", int(_settings.get("max_fps", DEFAULT_MAX_FPS)))
	config.set_value("display", "ui_scale", float(_settings.get("ui_scale", DEFAULT_UI_SCALE)))
	config.set_value("graphics", "blood_enabled", bool(_settings.get("blood_enabled", DEFAULT_BLOOD_ENABLED)))
	config.set_value("ai", "mode", str(_settings.get("ai_mode", DEFAULT_AI_MODE)))
	config.set_value("ai", "provider", str(_settings.get("ai_provider", DEFAULT_AI_PROVIDER)))
	config.set_value("ai", "model", str(_settings.get("ai_model", DEFAULT_AI_MODEL)))
	config.set_value("ai", "base_url", str(_settings.get("ai_base_url", DEFAULT_AI_BASE_URL)))
	# API Key intentionally never enters this file.
	return config.save(SETTINGS_PATH) == OK


func apply_display_settings() -> void:
	Engine.max_fps = int(_settings.get("max_fps", DEFAULT_MAX_FPS))
	var root_window := get_tree().root
	if root_window != null:
		root_window.content_scale_factor = float(_settings.get("ui_scale", DEFAULT_UI_SCALE))
	if DisplayServer.get_name() == "headless":
		return
	var display_mode := str(_settings.get("display_mode", DEFAULT_DISPLAY_MODE))
	match display_mode:
		"fullscreen":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		_:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(_normalize_resolution(_settings.get("resolution", DEFAULT_RESOLUTION)))
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED
		if bool(_settings.get("vsync", DEFAULT_VSYNC))
		else DisplayServer.VSYNC_DISABLED
	)


func debug_get_snapshot() -> Dictionary:
	var snapshot := get_snapshot()
	snapshot["settings_path"] = SETTINGS_PATH
	snapshot["contains_api_key"] = false
	return snapshot


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var loaded := get_default_snapshot()
	loaded["display_mode"] = config.get_value("display", "mode", loaded["display_mode"])
	loaded["resolution"] = Vector2i(
		int(config.get_value("display", "width", DEFAULT_RESOLUTION.x)),
		int(config.get_value("display", "height", DEFAULT_RESOLUTION.y))
	)
	loaded["vsync"] = config.get_value("display", "vsync", loaded["vsync"])
	loaded["max_fps"] = config.get_value("display", "max_fps", loaded["max_fps"])
	loaded["ui_scale"] = config.get_value("display", "ui_scale", loaded["ui_scale"])
	loaded["blood_enabled"] = config.get_value("graphics", "blood_enabled", loaded["blood_enabled"])
	loaded["ai_mode"] = config.get_value("ai", "mode", loaded["ai_mode"])
	loaded["ai_provider"] = config.get_value("ai", "provider", loaded["ai_provider"])
	loaded["ai_model"] = config.get_value("ai", "model", loaded["ai_model"])
	loaded["ai_base_url"] = config.get_value("ai", "base_url", loaded["ai_base_url"])
	apply_settings(loaded, false)


func _normalize_display_mode(value: String) -> String:
	return value if value in ["windowed", "borderless", "fullscreen"] else DEFAULT_DISPLAY_MODE


func _normalize_resolution(value: Variant) -> Vector2i:
	var resolution := DEFAULT_RESOLUTION
	if value is Vector2i:
		resolution = value
	elif value is Vector2:
		resolution = Vector2i(roundi(value.x), roundi(value.y))
	elif value is Array and value.size() >= 2:
		resolution = Vector2i(int(value[0]), int(value[1]))
	return Vector2i(maxi(960, resolution.x), maxi(540, resolution.y))
