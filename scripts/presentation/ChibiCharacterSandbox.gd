extends Node3D


const STATE_PAIRS := [
	["idle", "idle", "idle", "idle", "idle", "idle", "idle", "idle", "idle", "待机"],
	["walk", "walk", "walk", "walk", "walk", "walk", "walk", "walk", "walk", "行走"],
	["run", "run", "run", "run", "run", "run", "run", "run", "run", "奔跑"],
	["work", "work", "work", "work", "work", "training_instructor", "work", "work", "idle", "格伦打铁 / 托马照料 / 布鲁诺烹饪 / 伊沃耕作 / 马塞尔酿酒 / 艾达指导 / 莉娜研读 / 欧文装配"],
	["talk", "talk", "talk", "talk", "talk", "talk", "talk", "talk", "attack", "交谈 / 敌人攻击"],
	["idle", "vehicle_seated", "seated_eating", "seated_prayer", "mass_leader", "sleeping", "medical_treatment", "training_practice", "idle", "托马驾车 / 布鲁诺进食 / 伊沃祈祷 / 马塞尔弥撒 / 艾达睡眠 / 莉娜治疗 / 欧文训练"],
	["hit_react", "hit_react", "hit_react", "hit_react", "hit_react", "hit_react", "hit_react", "hit_react", "hit_react", "受击"],
	["unconscious", "unconscious", "unconscious", "unconscious", "unconscious", "unconscious", "unconscious", "unconscious", "unconscious", "倒地 / 昏迷"],
]

@export var auto_cycle_seconds := 3.2

@onready var _glen: Node = $Characters/GlenChibiPilot
@onready var _toma: Node = $Characters/TomaChibiArtView
@onready var _bruno: Node = $Characters/BrunoChibiArtView
@onready var _ivo: Node = $Characters/IvoChibiArtView
@onready var _marcel: Node = $Characters/MarcelChibiArtView
@onready var _ada: Node = $Characters/AdaChibiArtView
@onready var _lina: Node = $Characters/LinaChibiArtView
@onready var _owen: Node = $Characters/OwenChibiArtView
@onready var _enemy: Node = $Characters/EnemySwordShieldChibiPilot
@onready var _camera: Camera3D = $Camera3D
@onready var _state_label: Label = $CanvasLayer/Panel/Margin/VBox/State
@onready var _detail_label: Label = $CanvasLayer/Panel/Margin/VBox/Detail

var _state_index := 0
var _cycle_remaining := 0.0
var _capture_requested := false
var _capture_state_index := 3
var _capture_delay_seconds := 0.65
var _capture_ada_face := false
var _capture_ivo_face := false
var _capture_marcel_head := false
var _capture_marcel_side := false
var _capture_lina := false
var _capture_owen := false


func _ready() -> void:
	_camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	_ada.call("apply_profile", {
		"equipment": {"main_weapon": {"id": "sword_shield"}},
		"states": {"hp": 120, "unconscious": false, "current_action": "idle"},
	})
	_owen.call("apply_profile", {
		"equipment": {},
		"states": {"hp": 94, "unconscious": false, "current_action": "idle"},
	})
	# The camera stands on +Z. Ask each pilot to face it so the sandbox shows
	# character fronts; production entities still receive their real path direction.
	for pilot in [_glen, _toma, _bruno, _ivo, _marcel, _ada, _lina, _owen, _enemy]:
		pilot.call("set_facing_direction", Vector3.BACK)
	for argument in OS.get_cmdline_user_args():
		if argument == "--t0130-capture":
			_capture_requested = true
		elif argument.begins_with("--t0130-capture-state="):
			_capture_requested = true
			_capture_state_index = clampi(int(argument.get_slice("=", 1)), 0, STATE_PAIRS.size() - 1)
		elif argument.begins_with("--t0130-capture-delay="):
			_capture_requested = true
			_capture_delay_seconds = clampf(float(argument.get_slice("=", 1)), 0.05, 3.0)
		elif argument == "--t0130-capture-ada-face":
			_capture_requested = true
			_capture_ada_face = true
			_capture_state_index = 0
		elif argument == "--t0130-capture-ivo-face":
			_capture_requested = true
			_capture_ivo_face = true
			_capture_state_index = 0
		elif argument == "--t0130-capture-marcel-head":
			_capture_requested = true
			_capture_marcel_head = true
		elif argument == "--t0130-capture-marcel-side":
			_capture_requested = true
			_capture_marcel_head = true
			_capture_marcel_side = true
		elif argument == "--t0130-capture-lina":
			_capture_requested = true
			_capture_lina = true
		elif argument == "--t0130-capture-owen":
			_capture_requested = true
			_capture_owen = true
	_configure_capture_view()
	_apply_state_pair(0)
	if _capture_requested:
		_capture_after_warmup()


func _process(delta: float) -> void:
	if _capture_requested:
		return
	_cycle_remaining -= delta
	if _cycle_remaining <= 0.0:
		_apply_state_pair((_state_index + 1) % STATE_PAIRS.size())


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE or event.keycode == KEY_RIGHT:
		_apply_state_pair((_state_index + 1) % STATE_PAIRS.size())
	elif event.keycode == KEY_LEFT:
		_apply_state_pair(posmod(_state_index - 1, STATE_PAIRS.size()))
	elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
		_apply_state_pair(int(event.keycode - KEY_1))


func _apply_state_pair(index: int) -> void:
	_state_index = clampi(index, 0, STATE_PAIRS.size() - 1)
	_cycle_remaining = auto_cycle_seconds
	var state_pair: Array = STATE_PAIRS[_state_index]
	var glen_result: Dictionary = _glen.call("debug_force_animation_state", String(state_pair[0]))
	var toma_result: Dictionary = _toma.call("debug_force_animation_state", String(state_pair[1]))
	var bruno_result: Dictionary = _bruno.call("debug_force_animation_state", String(state_pair[2]))
	var ivo_result: Dictionary = _ivo.call("debug_force_animation_state", String(state_pair[3]))
	var marcel_result: Dictionary = _marcel.call("debug_force_animation_state", String(state_pair[4]))
	var ada_result: Dictionary = _ada.call("debug_force_animation_state", String(state_pair[5]))
	var lina_result: Dictionary = _lina.call("debug_force_animation_state", String(state_pair[6]))
	var owen_result: Dictionary = _owen.call("debug_force_animation_state", String(state_pair[7]))
	var enemy_result: Dictionary = _enemy.call("debug_force_animation_state", String(state_pair[8]))
	_state_label.text = "%d/8  %s" % [_state_index + 1, String(state_pair[9])]
	_detail_label.text = "格伦：%s  |  托马：%s  |  布鲁诺：%s  |  伊沃：%s  |  马塞尔：%s  |  艾达：%s  |  莉娜：%s  |  欧文：%s  |  敌人：%s\nSpace / ← → / 数字 1–8 切换；每 %.1f 秒自动轮播" % [
		String(glen_result.get("current_clip", glen_result.get("error", "未就绪"))),
		String(toma_result.get("current_clip", toma_result.get("error", "未就绪"))),
		String(bruno_result.get("current_clip", bruno_result.get("error", "未就绪"))),
		String(ivo_result.get("current_clip", ivo_result.get("error", "未就绪"))),
		String(marcel_result.get("current_clip", marcel_result.get("error", "未就绪"))),
		String(ada_result.get("current_clip", ada_result.get("error", "未就绪"))),
		String(lina_result.get("current_clip", lina_result.get("error", "未就绪"))),
		String(owen_result.get("current_clip", owen_result.get("error", "未就绪"))),
		String(enemy_result.get("current_clip", enemy_result.get("error", "未就绪"))),
		auto_cycle_seconds,
	]


func _configure_capture_view() -> void:
	if not _capture_ada_face and not _capture_ivo_face and not _capture_marcel_head and not _capture_lina and not _capture_owen:
		return
	var visible_pilot := _owen if _capture_owen else (_lina if _capture_lina else (_marcel if _capture_marcel_head else (_ada if _capture_ada_face else _ivo)))
	var visible_plinth: MeshInstance3D = $OwenPlinth if _capture_owen else ($LinaPlinth if _capture_lina else ($MarcelPlinth if _capture_marcel_head else ($AdaPlinth if _capture_ada_face else $IvoPlinth)))
	for pilot in [_glen, _toma, _bruno, _ivo, _marcel, _ada, _lina, _owen, _enemy]:
		if pilot == visible_pilot:
			continue
		pilot.visible = false
	for child in get_children():
		if child is Label3D or (child is MeshInstance3D and child != visible_plinth):
			child.visible = false
	$CanvasLayer.visible = false
	var target_x := 6.6 if _capture_owen else (4.4 if _capture_lina else (0.0 if _capture_marcel_head else (2.2 if _capture_ada_face else -2.2)))
	var capture_distance := 3.65 if _capture_marcel_head or _capture_lina or _capture_owen else 2.45
	_camera.position = Vector3(target_x + (capture_distance if _capture_marcel_side else 0.0), 1.40, 0.0 if _capture_marcel_side else capture_distance)
	_camera.fov = 32.0 if _capture_marcel_head or _capture_lina or _capture_owen else 28.0
	_camera.look_at(Vector3(target_x, 1.08 if _capture_marcel_head or _capture_lina or _capture_owen else 1.38, 0.0), Vector3.UP)


func _capture_after_warmup() -> void:
	await get_tree().create_timer(1.0).timeout
	_apply_state_pair(_capture_state_index)
	await get_tree().create_timer(_capture_delay_seconds).timeout
	var image := get_viewport().get_texture().get_image()
	var capture_filename := "t0130_p8_owen_state_%d.png" % _capture_state_index if _capture_owen else ("t0130_p7_lina_state_%d.png" % _capture_state_index if _capture_lina else (("t0130_p6r_marcel_head_side_state_%d.png" if _capture_marcel_side else "t0130_p6r_marcel_head_front_state_%d.png") % _capture_state_index if _capture_marcel_head else (
		"t0130_p5r_ada_face_phase_%03d.png" % int(round(_capture_delay_seconds * 1000.0)) if _capture_ada_face else (
			"t0130_p4r2_ivo_face_phase_%03d.png" % int(round(_capture_delay_seconds * 1000.0)) if _capture_ivo_face else "t0130_p5_chibi_state_%d_phase_%03d.png" % [
			_capture_state_index,
			int(round(_capture_delay_seconds * 1000.0)),
		]
	))))
	var capture_path := OS.get_user_data_dir().path_join(capture_filename)
	var error := image.save_png(capture_path)
	print("T0130_CAPTURE=%s ERROR=%d" % [capture_path, error])
	get_tree().quit(0 if error == OK else 1)
