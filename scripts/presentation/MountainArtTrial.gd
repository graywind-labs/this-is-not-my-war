extends Node3D
## Independent A/B using the same approved cliff construction as production.
const ENVIRONMENT := preload("res://scripts/presentation/environment/FormalGroundSurfaceArtView.gd")
const MOUNTAIN_ART := preload("res://scripts/presentation/environment/StylizedMountainArt.gd")
const OUTPUT := "res://artifacts/visual_qa/t0365/shared_revision"
var _style: Dictionary = {}
var _environment: Node3D
var _art := MOUNTAIN_ART.new()
var _camera := Camera3D.new()
var _label := Label.new()
var _candidate := true
var _night := false

func _ready() -> void:
	_style = _read(MOUNTAIN_ART.CONFIG_PATH)
	var environment_config := _read("res://data/presentation/environment_art.json")
	environment_config["approved_mountain"] = {"enabled": false}
	_environment = ENVIRONMENT.new()
	_environment.name = "ReadOnlyEnvironment"
	_environment.configure(environment_config, _read("res://data/station_layout.json"))
	add_child(_environment)
	_environment.get_node("StationLifeDetails").hide()
	_art.name = "ApprovedMountainReview"
	_environment.add_child(_art)
	_art.configure(_environment, _style)
	_camera.name = "ReviewCamera"
	_camera.fov = 48.0
	_camera.far = 1200.0
	add_child(_camera)
	_camera.current = true
	_build_controls()
	set_view("overview")
	set_candidate(true)
	set_night(false)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_verify()
	if "--capture-mountain-trial" in OS.get_cmdline_user_args():
		call_deferred("_capture")

func set_candidate(enabled: bool) -> void:
	_candidate = enabled
	_art.set_enabled(enabled)
	_label.text = "T0365  山体试验 / " + ("B · 高岩壁与错落山脊" if enabled else "A · 当前山体")

func _verify() -> Dictionary:
	assert(get_node_or_null("/root/Main") == null)
	var snapshot := _art.verify_geometry_contract()
	snapshot["main_created"] = false
	snapshot["production_enabled"] = false
	return snapshot


func _read(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(value is Dictionary, "Invalid art configuration: " + path)
	return value


func set_view(view: String) -> void:
	var settings: Dictionary = _style.get("views", {}).get(view, {})
	var t: Array = settings.get("target", [158, 7, 112])
	var o: Array = settings.get("offset", [-92, 100, 105])
	var target := Vector3(t[0], t[1], t[2])
	_camera.position = target + Vector3(o[0], o[1], o[2])
	_camera.look_at(target)


func set_night(enabled: bool) -> void:
	_night = enabled
	_environment.get_node("CelestialCycleController").call("_apply_time", 1, 0 if enabled else 12, 30, 0)


func _build_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ReviewControls"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_label.add_theme_font_size_override("font_size", 20)
	column.add_child(_label)
	var row := HBoxContainer.new()
	column.add_child(row)
	for entry in [["原版 A", func(): set_candidate(false)], ["试案 B", func(): set_candidate(true)], ["整体", func(): set_view("overview")], ["近看", func(): set_view("close")], ["侧看", func(): set_view("side")], ["远看", func(): set_view("wide")], ["昼 / 夜", func(): set_night(not _night)]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		row.add_child(button)

# Sample the actual unchanged render triangles, never the coarse mountain profile.

func _capture() -> void:
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for view in ["overview", "close", "side", "wide"]:
		set_view(view)
		for night in [false, true]:
			set_night(night)
			for candidate in [false, true]:
				set_candidate(candidate)
				for frame in 10:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var path := "%s/%s_%s_%s.png" % [OUTPUT, view, "night" if night else "day", "B" if candidate else "A"]
				var result := get_viewport().get_texture().get_image().save_png(path)
				if result != OK:
					push_error("Mountain review capture failed: " + path)
					get_tree().quit(1)
					return
	var snapshot := _verify()
	var file := FileAccess.open(OUTPUT + "/snapshot.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot, "  "))
	print("T0365_PASS ", JSON.stringify(snapshot))
	get_tree().quit()
