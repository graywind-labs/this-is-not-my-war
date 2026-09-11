extends Node3D
## Independent, static A/B study. Never attached to the production Main scene.

const CandidateHUD := preload("res://scripts/ui/HUDArtCandidate.gd")
var candidate: Control
var toolbar: PanelContainer
var original: Control
var candidate_active := true
var ready_for_review := false
var _comparison_buttons: Array[Button] = []
var context_mode := 0
var _context_selector: OptionButton
var _original_detail_z: Dictionary = {}

func _enter_tree() -> void:
	# Set before the inherited child's deferred startup: no plans or LLM requests.
	get_node("Systems/GameStartupSystem").startup_mode = 0

func _ready() -> void:
	call_deferred("_prepare_review")

func _prepare_review() -> void:
	await get_tree().process_frame
	original = get_node("UI/HUD")
	for path in ["NPCPanel", "BuildingPanel", "DialogPanel"]:
		_original_detail_z[path] = get_node("UI/" + path).z_index
	get_node("Systems/TimeSystem").set_current_time(1, 12, 0, 0)
	# Keep A's original styling and text; neither A nor B submits game actions.
	for control in original.find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.focus_mode = Control.FOCUS_NONE
	get_node("UI/GMPanel").hide()
	var rig := get_node("CameraRig") as Node3D
	rig.set_process(false)
	rig.set_process_input(false)
	rig.set_process_unhandled_input(false)
	rig.position = Vector3(0, 0, 10)
	var camera := rig.get_node("Camera3D") as Camera3D
	camera.position = Vector3(0, 74, 60)
	camera.look_at(rig.global_position)
	# Static study: block world selection and all gameplay keyboard shortcuts.
	for node in find_children("*", "Node", true, false):
		node.set_process_input(false)
		node.set_process_unhandled_input(false)
	var blocker := Control.new()
	blocker.name = "TrialInputShield"
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.z_index = -1
	get_node("UI").add_child(blocker)
	get_node("UI").move_child(blocker, 0)
	candidate = CandidateHUD.new()
	candidate.name = "CandidateHUD"
	candidate.source_hud = original
	candidate.z_index = 70
	get_node("UI").add_child(candidate)
	get_node("UI").move_child(candidate, original.get_index() + 1)
	_build_toolbar()
	get_viewport().size_changed.connect(_fit_dialogue_in_place)
	set_variant(true)
	ready_for_review = true

func _build_toolbar() -> void:
	toolbar = PanelContainer.new()
	toolbar.name = "HUDComparisonToolbar"
	toolbar.z_index = 125
	toolbar.theme = original.theme
	toolbar.add_theme_stylebox_override("panel", CandidateHUD.make_box(Color("#202725"), Color("#59635a"), 1))
	get_node("UI").add_child(toolbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	toolbar.add_child(row)
	var label := Label.new()
	label.text = "HUD 对比 · 静态样片"
	label.add_theme_font_size_override("font_size", 14)
	row.add_child(label)
	for i in 2:
		var button := Button.new()
		button.text = "1 原版" if i == 0 else "2 新版"
		button.custom_minimum_size = Vector2(76, 30)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(set_variant.bind(i == 1))
		row.add_child(button)
		_comparison_buttons.append(button)
	_context_selector = OptionButton.new()
	for title in ["仅 HUD", "NPC 面板", "建筑面板", "对话窗口"]:
		_context_selector.add_item(title)
	_context_selector.item_selected.connect(set_context)
	row.add_child(_context_selector)
	var hint := Label.new()
	hint.text = "H 隐藏"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color("#a6aaa0")
	row.add_child(hint)
	get_viewport().size_changed.connect(_position_toolbar)
	_position_toolbar()

func _position_toolbar() -> void:
	toolbar.reset_size()
	toolbar.position = Vector2(16, get_viewport().get_visible_rect().size.y - 60)

func set_variant(use_candidate: bool) -> void:
	candidate_active = use_candidate
	original.visible = not use_candidate
	candidate.visible = use_candidate
	for path in _original_detail_z:
		get_node("UI/" + path).z_index = (100 if path == "DialogPanel" else 80) if use_candidate else int(_original_detail_z[path])
	_fit_dialogue_in_place()
	for i in _comparison_buttons.size():
		_comparison_buttons[i].set_pressed_no_signal(use_candidate == (i == 1))

func set_context(mode: int) -> void:
	context_mode = mode
	_context_selector.select(mode)
	get_node("Systems/DialogSystem").cancel_displayed_dialogue()
	get_node("UI/DialogPanel").hide()
	get_node("UI/NPCPanel").show_npc("")
	get_node("UI/BuildingPanel").show_building("")
	if mode in [1, 3]:
		var ids: Array = get_node("Systems/NPCSystem").get_npc_ids()
		get_node("UI/NPCPanel").show_npc(str(ids[0]))
		if mode == 3:
			# Opening a draft is view-only; no text is submitted and no LLM runs.
			get_node("UI/DialogPanel").input_edit.focus_mode = Control.FOCUS_ALL
			get_node("Systems/DialogSystem").start_player_dialogue(str(ids[0]))
	elif mode == 2:
		get_node("UI/BuildingPanel").show_building("main_hall")
	await get_tree().process_frame
	await get_tree().process_frame
	for path in ["NPCPanel", "BuildingPanel", "DialogPanel"]:
		var branch := get_node("UI/" + path)
		for control in branch.find_children("*", "Control", true, false):
			if not (control is ScrollContainer or control is ScrollBar):
				control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			control.focus_mode = Control.FOCUS_NONE
		branch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	candidate._layout()
	_fit_dialogue_in_place()

func _fit_dialogue_in_place() -> void:
	# Retain the authored center and width; only fit its height on small windows.
	var dialogue := get_node("UI/DialogPanel") as Control
	var height := minf(540, get_viewport().get_visible_rect().size.y - 32) if candidate_active else 540.0
	dialogue.offset_top = -height * 0.5
	dialogue.offset_bottom = height * 0.5

func _input(event: InputEvent) -> void:
	if not ready_for_review:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: set_variant(false)
			KEY_2: set_variant(true)
			KEY_3: set_context((context_mode + 1) % 4)
			KEY_H: toolbar.visible = not toolbar.visible
		get_viewport().set_input_as_handled()

func debug_get_snapshot() -> Dictionary:
	return {
		"candidate": candidate_active,
		"context": context_mode,
		"startup": get_node("Systems/GameStartupSystem").get_startup_snapshot(),
		"camera": str(get_node("CameraRig/Camera3D").global_transform),
		"hud": candidate.debug_get_snapshot(),
		"original_frame": str(original.get_node("HUDFrame").get_global_rect()),
	}
