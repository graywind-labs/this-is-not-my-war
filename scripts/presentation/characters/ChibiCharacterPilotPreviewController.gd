extends Node


const FORMAL_ROOT_PATH := "/root/Main/WorldRoot/FormalStationLayout"
const PREVIEW_ROOT_NAME := "T0130CharacterPilotPreview"
const GLEN_SCENE := preload("res://scenes/characters/GlenChibiPilot.tscn")
const ENEMY_SCENE := preload("res://scenes/characters/EnemySwordShieldChibiPilot.tscn")

var _preview_root: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func debug_set_preview_enabled(enabled: bool) -> Dictionary:
	if enabled:
		_build_preview()
	elif is_instance_valid(_preview_root):
		_preview_root.queue_free()
		_preview_root = null
	return debug_get_snapshot()


func debug_get_snapshot() -> Dictionary:
	var glen := _preview_root.get_node_or_null("GlenChibiPilot") if is_instance_valid(_preview_root) else null
	var enemy := _preview_root.get_node_or_null("EnemySwordShieldChibiPilot") if is_instance_valid(_preview_root) else null
	return {
		"enabled": is_instance_valid(_preview_root),
		"authority_role": "presentation_only",
		"formal_root_path": FORMAL_ROOT_PATH,
		"local_positions": {
			"glen": glen.position if glen is Node3D else Vector3.ZERO,
			"enemy": enemy.position if enemy is Node3D else Vector3.ZERO,
		},
		"glen": glen.call("debug_get_snapshot") if glen != null and glen.has_method("debug_get_snapshot") else {},
		"enemy": enemy.call("debug_get_snapshot") if enemy != null and enemy.has_method("debug_get_snapshot") else {},
	}


func _build_preview() -> void:
	if is_instance_valid(_preview_root):
		return
	var formal_root := get_node_or_null(FORMAL_ROOT_PATH) as Node3D
	if formal_root == null:
		push_error("T0130 Main preview could not find %s" % FORMAL_ROOT_PATH)
		return
	_preview_root = Node3D.new()
	_preview_root.name = PREVIEW_ROOT_NAME
	formal_root.add_child(_preview_root)
	var glen := GLEN_SCENE.instantiate() as Node3D
	glen.name = "GlenChibiPilot"
	glen.position = Vector3(-4.0, 0.14, 11.0)
	_preview_root.add_child(glen)
	var enemy := ENEMY_SCENE.instantiate() as Node3D
	enemy.name = "EnemySwordShieldChibiPilot"
	enemy.position = Vector3(4.0, 0.14, 11.0)
	_preview_root.add_child(enemy)
	glen.call_deferred("debug_force_animation_state", "work")
	enemy.call_deferred("debug_force_animation_state", "attack")
	_add_label(_preview_root, "GlenLabel", "T0130 格伦试片 · 循环打铁", Vector3(-4.0, 2.45, 11.0))
	_add_label(_preview_root, "EnemyLabel", "T0130 剑盾敌人试片 · 近战", Vector3(4.0, 2.45, 11.0))


func _add_label(parent: Node3D, node_name: String, text: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = position
	label.font_size = 42
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
