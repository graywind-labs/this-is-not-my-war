extends "res://scripts/ui/MainMenu.gd"
## Independent A/B review; the production menu and its assets remain untouched.

const CANDIDATE_SCENE := preload("res://scenes/art/MenuCoverCandidate.tscn")
const ORIGINAL_SCENE := preload("res://scenes/art/MenuCoverPreview.tscn")
var _original_fog: ShaderMaterial
var _candidate_fog: ShaderMaterial
var candidate_enabled := false
var _comparison_label: Label

func _ready() -> void:
	super._ready()
	_original_fog = MenuEdgeFogClass.create_original_material()
	_candidate_fog = MenuEdgeFogClass.create_approved_material()
	var bar := HBoxContainer.new()
	bar.name = "ComparisonControls"
	bar.position = Vector2(26, 8)
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	for entry in [["A  原版", false], ["B  新版", true]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(set_candidate.bind(entry[1]))
		bar.add_child(button)
	_comparison_label = Label.new()
	_comparison_label.add_theme_font_size_override("font_size", 14)
	bar.add_child(_comparison_label)
	set_candidate.call_deferred(true)

func set_candidate(enabled: bool) -> void:
	if _cover_scene == null:
		return
	# Skeleton callbacks can still run this frame: retire in-tree until queue_free.
	_cover_scene.name = "RetiringCover"
	_cover_scene.queue_free()
	_cover_scene = (CANDIDATE_SCENE if enabled else ORIGINAL_SCENE).instantiate() as Node3D
	_cover_scene.name = "AnimatedMenuCover"
	_cover_viewport.add_child(_cover_scene)
	# A uses the exact production scene; neither side creates Main or NPC authority.
	_cover_scene.configure_runtime_cover()
	candidate_enabled = enabled
	var fog := find_child("MenuEdgeFog", true, false) as ColorRect
	fog.material = _candidate_fog if enabled else _original_fog
	if enabled:
		_candidate_fog.set_shader_parameter("fog_color", _cover_scene.get_edge_fog_color())
	_comparison_label.text = ("新版 · 当前正式封面" if enabled else "原版 · 保留对照") + "    [1 / 2 切换 · H 隐藏界面]"

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1 or event.keycode == KEY_2:
			set_candidate(event.keycode == KEY_2)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_H:
			for path in ["TitleBlock", "MenuPanel", "VersionLabel", "ComparisonControls"]:
				var control := get_node(path) as Control
				control.visible = not control.visible
			get_viewport().set_input_as_handled()
			return
	super._unhandled_key_input(event)

func _on_start_pressed() -> void:
	# Keep the familiar composition, but do not launch gameplay from an art review.
	_comparison_label.text = "美术对比样片 · 正式游戏请运行 MainMenu.tscn"

func get_trial_snapshot() -> Dictionary:
	return {"candidate": candidate_enabled, "cover": _cover_scene.get_preview_snapshot(),
		"has_main": get_tree().root.get_node_or_null("Main") != null}
