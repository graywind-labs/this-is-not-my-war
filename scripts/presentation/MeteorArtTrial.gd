extends Node3D
## Independent interactive visual review. No Main, PietySystem or damage authority.
const ORIGINAL := preload("res://scripts/presentation/combat/MeteorPresentation.gd")
const CANDIDATE := preload("res://scripts/presentation/combat/MeteorArtCandidate.gd")
const PIETY_BUTTON := preload("res://scripts/ui/PietyAbilityButton.gd")
const CAMERA_RIG := preload("res://scripts/camera/CameraRig.gd")
const ENVIRONMENT := preload("res://scripts/presentation/environment/FormalGroundSurfaceArtView.gd")
const CONFIG_PATH := "res://data/presentation/meteor_art_trial.json"
var _style: Dictionary
var _meteor_config: Dictionary
var _environment: Node3D
var _camera := Camera3D.new()
var _shake_rig: Node3D
var _camera_base := Vector3.ZERO
var _meteor: Node3D
var _button: Control
var _title := Label.new()
var _status := Label.new()
var _pause_button: Button
var _ring := MeshInstance3D.new()
var _ring_material := StandardMaterial3D.new()
var _candidate := true
var _paused := false
var _targeting := false
var _night := false
var _stage := "ready"
var _elapsed := 0.0
var _landed_age := 0.0
var _target := Vector3.ZERO
var _last_target := Vector3.ZERO
var _start := Vector3.ZERO
var _center := Vector3.ZERO
var _view := "overview"
var _cast_count := 0
var _impact_count := 0
var _panel: PanelContainer

func _ready() -> void:
	_style = _read(CONFIG_PATH)
	_meteor_config = _read("res://data/piety_ability.json").meteor.duplicate(true)
	var c: Array = _style.center
	_center = Vector3(c[0],c[1],c[2])
	_last_target = _center
	_environment = ENVIRONMENT.new()
	_environment.name = "ReadOnlyEnvironment"
	_environment.configure(_read("res://data/presentation/environment_art.json"),_read("res://data/station_layout.json"))
	add_child(_environment)
	_environment.get_node("StationLifeDetails").hide()
	_camera.name = "Camera3D"
	_camera.fov = 46.0
	_camera.far = 1000.0
	_camera.position = Vector3(0,30,40)
	_shake_rig = CAMERA_RIG.new()
	_shake_rig.name = "ReviewShakeRig"
	_shake_rig.add_child(_camera)
	add_child(_shake_rig)
	_shake_rig.set_process(false)
	_shake_rig.set_process_input(false)
	_shake_rig.set_process_unhandled_input(false)
	_camera.current = true
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_build_ring()
	_build_ui()
	set_view("overview")
	set_night(false)
	_refresh_ui()

func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary

func _build_ring() -> void:
	# Match HUD._ensure_meteor_target_preview without instantiating gameplay HUD.
	var disk := CylinderMesh.new()
	disk.top_radius = float(_meteor_config.radius)
	disk.bottom_radius = float(_meteor_config.radius)
	disk.height = 0.035
	disk.radial_segments = 64
	_ring.mesh = disk
	_ring.name = "TargetRadius"
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.albedo_color = Color(1.0,0.42,0.12,0.25)
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_material.emission_enabled = true
	_ring_material.emission = Color(1.0,0.22,0.04,1.0)
	_ring_material.emission_energy_multiplier = 1.35
	_ring.material_override = _ring_material
	add_child(_ring)
	_ring.hide()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ReviewControls"
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.position = Vector2(14,12)
	layer.add_child(_panel)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.055,0.06,0.06,0.94)
	box.border_color = Color("766347")
	box.set_border_width_all(1)
	box.set_content_margin_all(12)
	box.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel",box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",7)
	_panel.add_child(column)
	_title.add_theme_font_size_override("font_size",19)
	column.add_child(_title)
	var choices := HBoxContainer.new()
	column.add_child(choices)
	for entry in [["1 原版 A",func(): set_candidate(false)],["2 新版 B",func(): set_candidate(true)],["全景",func(): set_view("overview")],["近景",func(): set_view("close")],["侧看",func(): set_view("side")],["昼 / 夜",func(): set_night(not _night)]]:
		_add_button(choices,entry[0],entry[1])
	var action := HBoxContainer.new()
	column.add_child(action)
	_button = PIETY_BUTTON.new()
	_button.name = "ChargedMeteorButton"
	action.add_child(_button)
	_button.set_piety(100,100)
	_button.ability_requested.connect(begin_targeting)
	var help := Label.new()
	help.text = "点击十字架选落点 · 左键施放\n右键 / Esc 取消 · 滚轮调节远近"
	action.add_child(help)
	_pause_button = _add_button(action,"暂停",func(): set_paused(not _paused))
	_add_button(action,"重播落点",func(): replay())
	_add_button(action,"重置",func(): reset_review())
	column.add_child(_status)
	var note := Label.new()
	note.text = "美术试片 · 落地停留 8 秒 → 弹坑保留 4 秒 → 10 秒渐隐"
	note.add_theme_font_size_override("font_size",13)
	note.modulate = Color("b7ad99")
	column.add_child(note)

func _add_button(parent: Node, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _process(delta: float) -> void:
	if _targeting:
		_target = ground_at(get_viewport().get_mouse_position())
		_ring.position = _target+Vector3.UP*0.055
		_ring.visible = legal_target(_target)
	if not _paused: advance_review(delta)
	_refresh_ui()

func advance_review(delta: float) -> void:
	if not is_instance_valid(_meteor): return
	var visual_delta := delta
	if _stage == "falling":
		_elapsed = minf(_elapsed+delta,float(_meteor_config.fall_duration_seconds))
		if _elapsed+0.00001>=float(_meteor_config.fall_duration_seconds):
			_elapsed = float(_meteor_config.fall_duration_seconds)
		var p := clampf(_elapsed/float(_meteor_config.fall_duration_seconds),0,1)
		var endpoint := _last_target+Vector3.UP*(float(_meteor_config.body_radius)*0.58 if _candidate else 0.02)
		var position: Vector3 = _meteor.get_fall_world_position(_start,_last_target,p) if _candidate else _start.lerp(endpoint,pow(p,1.35))
		_meteor.set_fall_transform(position,p)
		if p>=1.0:
			_meteor.impact_at(_last_target)
			_stage = "body"
			_landed_age = 0.0
			_impact_count += 1
			visual_delta = 0.0
			_shake_rig.request_camera_shake(float(_meteor_config.impact_camera_shake_duration_seconds),float(_meteor_config.impact_camera_shake_amplitude),float(_meteor_config.impact_camera_shake_frequency))
	else:
		_landed_age += delta
		var body_hold := float(_style.body_hold_seconds)
		var fade_start := body_hold+float(_style.crater_hold_seconds)
		var end := fade_start+float(_style.crater_fade_seconds)
		if _stage == "body" and _landed_age>=body_hold:
			_meteor.remove_landed_body()
			_stage = "crater"
		if _landed_age>=fade_start:
			_stage = "fading"
			_meteor.set_crater_fade_progress(clampf((_landed_age-fade_start)/float(_style.crater_fade_seconds),0,1))
		if _landed_age>=end:
			_meteor.remove_crater()
			_meteor.queue_free()
			_meteor = null
			_stage = "ready"
			_button.set_piety(100,100)
	_shake_rig._camera_base_position = _camera_base
	_shake_rig._update_camera_shake(visual_delta)
	if is_instance_valid(_meteor): _meteor._process(visual_delta)

func ground_at(screen_position: Vector2) -> Vector3:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	var point: Variant = Plane(Vector3.UP,0).intersects_ray(origin,direction)
	return point if point is Vector3 else Vector3(10000,0,10000)

func legal_target(point: Vector3) -> bool:
	var half: Array = _style.target_area_half_size
	return point.is_finite() and absf(point.x-_center.x)<=float(half[0]) and absf(point.z-_center.z)<=float(half[1])

func begin_targeting() -> void:
	if _stage != "ready": return
	_targeting = true
	_button.set_targeting(true)
	_ring.show()

func cancel_targeting() -> void:
	_targeting = false
	_button.set_targeting(false)
	_ring.hide()

func cast_at(point: Vector3) -> bool:
	if _stage != "ready" or not legal_target(point): return false
	cancel_targeting()
	_button.set_piety(0,100)
	_last_target = point
	_meteor = CANDIDATE.new() if _candidate else ORIGINAL.new()
	_meteor.name = "CandidateMeteor" if _candidate else "OriginalMeteor"
	add_child(_meteor)
	_meteor.configure(_meteor_config)
	_meteor.set_process(false)
	var direction := -_camera.global_basis.z
	direction.y = 0
	direction = direction.normalized()
	_start = point+Vector3.UP*float(_meteor_config.start_height)+direction*float(_meteor_config.start_horizontal_offset)
	_meteor.set_fall_transform(_start,0.0)
	_elapsed = 0.0
	_landed_age = 0.0
	_stage = "falling"
	_cast_count += 1
	_shake_rig.request_camera_shake(float(_meteor_config.fall_duration_seconds),float(_meteor_config.descent_camera_shake_amplitude),float(_meteor_config.descent_camera_shake_frequency))
	set_paused(false)
	return true

func replay() -> void:
	reset_review()
	cast_at(_last_target)

func reset_review() -> void:
	if is_instance_valid(_meteor):
		_meteor.queue_free()
	_meteor = null
	_stage = "ready"
	cancel_targeting()
	_button.set_piety(100,100)
	_shake_rig._update_camera_shake(999.0)
	_camera.position = _camera_base
	set_paused(false)

func set_candidate(enabled: bool) -> void:
	reset_review()
	_candidate = enabled
	_refresh_ui()

func set_paused(enabled: bool) -> void:
	_paused = enabled
	_pause_button.text = "继续" if enabled else "暂停"
	if is_instance_valid(_meteor):
		for p in _meteor.find_children("*","GPUParticles3D",true,false): p.speed_scale = 0.0 if enabled else 1.0

func set_view(view: String) -> void:
	_view = view
	var values: Array = _style.views[view]
	_camera_base = _center+Vector3(values[0],values[1],values[2])
	_camera.position = _camera_base
	_camera.look_at(_center+Vector3.UP*(8.0 if view=="overview" else 3.0))
	_shake_rig._camera_base_position = _camera_base
	_shake_rig._update_camera_shake(0.0)

func set_night(enabled: bool) -> void:
	_night = enabled
	_environment.get_node("CelestialCycleController").call("_apply_time",1,0 if enabled else 12,30,0)

func _refresh_ui() -> void:
	_title.text = "陨石试片 / " + ("B · 裂岩与余烬" if _candidate else "A · 正式原版")
	if _targeting:
		_status.text = "左键选择橙红范围内的落点。" if legal_target(_target) else "请移回试片草地区域选择落点。"
	elif _stage == "ready":
		_status.text = "虔诚已满，可以施放。" if _cast_count==0 else "已清理完毕，虔诚重新充满。"
	elif _stage == "falling":
		_status.text = "陨石下落  %.1f / %.1f 秒"%[_elapsed,float(_meteor_config.fall_duration_seconds)]
	elif _stage == "body":
		_status.text = "撞击与余火 · 岩体 %.1f 秒后消失"%maxf(0,float(_style.body_hold_seconds)-_landed_age)
	elif _stage == "crater":
		_status.text = "岩体已消失 · 弹坑保留中"
	else:
		_status.text = "弹坑逐渐淡去  %d%%"%roundi(float(_meteor.get_presentation_snapshot().crater_fade_progress)*100)
	if _paused: _status.text += "  [已暂停]"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT: cancel_targeting()
		elif event.button_index == MOUSE_BUTTON_LEFT and _targeting: cast_at(ground_at(event.position))
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var target := _center+Vector3.UP*3.0
			var offset := (_camera_base-target)*(0.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1)
			_camera_base = target+offset.normalized()*clampf(offset.length(),19.0,90.0)
			_camera.position = _camera_base
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: cancel_targeting()
			KEY_1: set_candidate(false)
			KEY_2: set_candidate(true)
			KEY_SPACE: set_paused(not _paused)
			KEY_H: _panel.visible = not _panel.visible

func get_review_snapshot() -> Dictionary:
	return {"candidate":_candidate,"stage":_stage,"paused":_paused,"targeting":_targeting,"casts":_cast_count,"impacts":_impact_count,"fall_elapsed":_elapsed,"landed_age":_landed_age,"ready_button":_button.is_ready_to_cast(),"meteor":_meteor.get_presentation_snapshot() if is_instance_valid(_meteor) else {},"main_created":get_node_or_null("/root/Main")!=null,"formal_ability_modified":false}
