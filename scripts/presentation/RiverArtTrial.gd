extends Node3D
## Isolated A/B review using the approved production river implementation.
const ENVIRONMENT := preload("res://scripts/presentation/environment/FormalGroundSurfaceArtView.gd")
const RIVER_ART := preload("res://scripts/presentation/environment/StylizedRiverArt.gd")
const OUTPUT := "res://artifacts/visual_qa/t0366/natural_shore_revision"
var _style: Dictionary = {}
var _environment: Node3D
var _art: Node3D
var _water_material: ShaderMaterial
var _camera := Camera3D.new()
var _label := Label.new()
var _candidate := true
var _night := false
var _motion := true
var _flow_time := 0.0

func _ready() -> void:
	_style = _read(RIVER_ART.CONFIG_PATH)
	var config := _read("res://data/presentation/environment_art.json")
	config["approved_river"] = {"enabled": false}
	_environment = ENVIRONMENT.new()
	_environment.name = "ReadOnlyEnvironment"
	_environment.configure(config, _read("res://data/station_layout.json"))
	add_child(_environment)
	_environment.get_node("StationLifeDetails").hide()
	_art = RIVER_ART.new()
	_art.name = "ReviewStylizedRiver"
	_environment.add_child(_art)
	_art.configure(_environment, _style)
	_art.set_process(false)
	_water_material = _art._water_material
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
	if "--capture-river-trial" in OS.get_cmdline_user_args():
		call_deferred("_capture")

func _process(delta: float) -> void:
	if _motion:
		_flow_time += delta
	_water_material.set_shader_parameter("flow_time", _flow_time)

func set_candidate(enabled: bool) -> void:
	_candidate = enabled
	_art.set_enabled(enabled)
	_label.text = "T0366  河流试验 / " + ("B · 纵向流痕、水岸石组与绕石白沫" if enabled else "A · 原版河流")

func _verify() -> Dictionary:
	var snapshot: Dictionary = _art.verify_geometry_contract()
	assert(get_node_or_null("/root/Main") == null)
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
	var motion_button := Button.new()
	motion_button.text = "水纹：流动"
	motion_button.pressed.connect(func():
		_motion = not _motion
		motion_button.text = "水纹：流动" if _motion else "水纹：暂停"
	)
	row.add_child(motion_button)




func _capture() -> void:
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	_motion = false
	_flow_time = 8.0
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
					push_error("River review capture failed: " + path)
					get_tree().quit(1)
					return
	var snapshot := _verify()
	set_view("close")
	set_night(false)
	set_candidate(true)
	for phase in [8.0, 10.0]:
		_flow_time = phase
		for frame in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		assert(is_equal_approx(float(_water_material.get_shader_parameter("flow_time")), phase))
		var result := get_viewport().get_texture().get_image().save_png("%s/flow_%02d.png" % [OUTPUT, int(phase)])
		assert(result == OK)
	snapshot["flow_phases"] = [8.0, 10.0]
	var file := FileAccess.open(OUTPUT + "/snapshot.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot, "  "))
	print("T0366_PASS ", JSON.stringify(snapshot))
	get_tree().quit()
