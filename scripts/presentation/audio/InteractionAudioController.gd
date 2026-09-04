class_name InteractionAudioController
extends Node

const CONFIG_PATH := "res://data/presentation/interaction_audio.json"
const EXPECTED_SCHEMA := "interaction_audio_v1"
const AUDIO_MANAGER_PATH := NodePath("/root/AudioManager")
const UI_ROOT_PATH := NodePath("/root/Main/UI")
const FORMAL_ROOT_PATH := NodePath("/root/Main/WorldRoot/FormalStationLayout")
const MERCHANT_SYSTEM_PATH := NodePath("/root/Main/Systems/MerchantSystem")

var _config: Dictionary = {}
var _ui_config: Dictionary = {}
var _world_config: Dictionary = {}
var _initialized := false
var _initialization_attempts := 0
var _connected_buttons: Dictionary = {}
var _selection_connections: Array[Dictionary] = []
var _special_success_popup: Window
var _harvest_dialog: Node
var _pending_ui_semantic := ""
var _pending_ui_priority := -1
var _ui_flush_queued := false
var _recent_history: Array[Dictionary] = []
var _door_states: Dictionary = {}
var _door_sources: Dictionary = {}
var _world_source_root: Node3D
var _merchant_source: Node3D
var _merchant_loop_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_meta("presentation_only", true)
	set_meta("authority_role", "read_only_ui_and_world_interaction_audio_projection")
	_config = _load_json_dictionary(CONFIG_PATH)
	_ui_config = _as_dictionary(_config.get("ui", {}))
	_world_config = _as_dictionary(_config.get("world", {}))
	call_deferred("_initialize")


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null and tree.node_added.is_connected(_on_tree_node_added):
		tree.node_added.disconnect(_on_tree_node_added)
	_disconnect_selection_signals()
	_disconnect_special_sources()
	_stop_merchant_loop()
	_connected_buttons.clear()
	_door_states.clear()
	_door_sources.clear()


func _process(_delta: float) -> void:
	if not _initialized:
		return
	_refresh_doors()
	_refresh_merchant()


func get_debug_snapshot() -> Dictionary:
	var door_states := {}
	for raw_key in _door_states.keys():
		door_states[str(raw_key)] = (_door_states.get(raw_key, {}) as Dictionary).duplicate(true)
	return {
		"initialized": _initialized,
		"schema_version": str(_config.get("schema_version", "")),
		"connected_button_count": _connected_buttons.size(),
		"panel_visibility_audio_enabled": false,
		"pending_ui_semantic": _pending_ui_semantic,
		"recent_history": _recent_history.duplicate(true),
		"door_states": door_states,
		"merchant_loop_active": _merchant_loop_active,
		"merchant_source_position": _merchant_source.global_position if is_instance_valid(_merchant_source) else Vector3.ZERO,
		"authority_role": "presentation_only",
	}


func debug_clear_history() -> void:
	_recent_history.clear()
	_pending_ui_semantic = ""
	_pending_ui_priority = -1
	_ui_flush_queued = false


func debug_queue_ui_semantic(semantic: String) -> void:
	_queue_ui_semantic(semantic)


func debug_flush_ui_semantic() -> void:
	_flush_ui_semantic()


func debug_sample_door(source: Node3D, gate_id: String, open_fraction: float, destroyed := false) -> void:
	_apply_door_sample(source, gate_id, open_fraction, destroyed)


func debug_sample_merchant(snapshot: Dictionary) -> void:
	_apply_merchant_snapshot(snapshot)


func _initialize() -> void:
	if _initialized:
		return
	_initialization_attempts += 1
	if str(_config.get("schema_version", "")) != EXPECTED_SCHEMA:
		push_error("InteractionAudioController invalid config schema")
		return
	var ui_root := get_node_or_null(UI_ROOT_PATH)
	var formal_root := get_node_or_null(FORMAL_ROOT_PATH) as Node3D
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if ui_root == null or formal_root == null or audio_manager == null:
		if _initialization_attempts < 12:
			call_deferred("_initialize")
		else:
			push_error("InteractionAudioController could not find UI, formal world, or AudioManager")
		return
	_world_source_root = Node3D.new()
	_world_source_root.name = "InteractionAudioSources"
	_world_source_root.set_meta("presentation_only", true)
	formal_root.add_child(_world_source_root)
	_connect_existing_ui(ui_root)
	var tree := get_tree()
	if tree != null and not tree.node_added.is_connected(_on_tree_node_added):
		tree.node_added.connect(_on_tree_node_added)
	_connect_selection_signals()
	_connect_special_sources()
	_prime_door_states()
	_initialized = true


func _connect_existing_ui(ui_root: Node) -> void:
	_connect_ui_node(ui_root)
	for node in ui_root.find_children("*", "", true, false):
		_connect_ui_node(node)


func _on_tree_node_added(node: Node) -> void:
	if not _is_under_ui(node):
		return
	# Passing a Node directly through the deferred queue can fail when a short-lived
	# popup is freed before the call is dispatched. Resolve the instance lazily so
	# transient frontend panels never leave Object-to-Object conversion errors.
	call_deferred("_connect_ui_node_by_id", node.get_instance_id())


func _connect_ui_node_by_id(instance_id: int) -> void:
	var node := instance_from_id(instance_id) as Node
	if node != null and _is_under_ui(node):
		_connect_ui_node(node)


func _connect_ui_node(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node as BaseButton)


func _connect_button(button: BaseButton) -> void:
	var instance_id := button.get_instance_id()
	if _connected_buttons.has(instance_id) or bool(button.get_meta("ui_audio_silent", false)):
		return
	var callback := Callable(self, "_on_button_pressed").bind(button)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)
	_connected_buttons[instance_id] = weakref(button)


func _on_button_pressed(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	if button is CheckButton or button is CheckBox:
		_queue_ui_semantic("toggle")
	else:
		_queue_ui_semantic("primary")
	# Button feedback must be audible in the same pressed dispatch. The queue still
	# resolves a success semantic emitted earlier in that dispatch over the click.
	_flush_ui_semantic()


func _connect_selection_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	for raw_signal_name in _ui_config.get("world_selection_signals", []):
		var signal_name := StringName(str(raw_signal_name))
		if not event_bus.has_signal(signal_name):
			continue
		var callback := Callable(self, "_on_world_selection").bind(str(signal_name))
		if not event_bus.is_connected(signal_name, callback):
			event_bus.connect(signal_name, callback)
		_selection_connections.append({"signal": signal_name, "callback": callback})


func _disconnect_selection_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		for connection in _selection_connections:
			var signal_name := connection.get("signal", &"") as StringName
			var callback := connection.get("callback", Callable()) as Callable
			if not signal_name.is_empty() and callback.is_valid() and event_bus.is_connected(signal_name, callback):
				event_bus.disconnect(signal_name, callback)
	_selection_connections.clear()


func _on_world_selection(_arg1: Variant = null, _arg2: Variant = null, _signal_name := "") -> void:
	_queue_ui_semantic("primary")


func _connect_special_sources() -> void:
	var success_path := NodePath(str(_ui_config.get("special_success_popup_path", "")))
	_special_success_popup = get_node_or_null(success_path) as Window
	if _special_success_popup != null and not _special_success_popup.about_to_popup.is_connected(_on_special_success_popup):
		_special_success_popup.about_to_popup.connect(_on_special_success_popup)
	var harvest_path := NodePath(str(_ui_config.get("harvest_dialog_path", "")))
	_harvest_dialog = get_node_or_null(harvest_path)
	if _harvest_dialog != null and _harvest_dialog.has_signal("harvest_completed"):
		var callback := Callable(self, "_on_harvest_completed")
		if not _harvest_dialog.is_connected("harvest_completed", callback):
			_harvest_dialog.connect("harvest_completed", callback)


func _disconnect_special_sources() -> void:
	if is_instance_valid(_special_success_popup) and _special_success_popup.about_to_popup.is_connected(_on_special_success_popup):
		_special_success_popup.about_to_popup.disconnect(_on_special_success_popup)
	if is_instance_valid(_harvest_dialog) and _harvest_dialog.has_signal("harvest_completed"):
		var callback := Callable(self, "_on_harvest_completed")
		if _harvest_dialog.is_connected("harvest_completed", callback):
			_harvest_dialog.disconnect("harvest_completed", callback)


func _on_special_success_popup() -> void:
	_queue_ui_semantic("success")


func _on_harvest_completed(_building_id: String, _collected_resources: Dictionary) -> void:
	_queue_ui_semantic("success")


func _queue_ui_semantic(semantic: String) -> void:
	var semantic_assets := _as_dictionary(_ui_config.get("semantic_assets", {}))
	if not semantic_assets.has(semantic):
		return
	var priorities := _as_dictionary(_ui_config.get("semantic_priority", {}))
	var priority := int(priorities.get(semantic, 0))
	if priority >= _pending_ui_priority:
		_pending_ui_semantic = semantic
		_pending_ui_priority = priority
	if not _ui_flush_queued:
		_ui_flush_queued = true
		call_deferred("_flush_ui_semantic")


func _flush_ui_semantic() -> void:
	_ui_flush_queued = false
	var semantic := _pending_ui_semantic
	_pending_ui_semantic = ""
	_pending_ui_priority = -1
	if semantic.is_empty():
		return
	var semantic_assets := _as_dictionary(_ui_config.get("semantic_assets", {}))
	var asset_id := str(semantic_assets.get(semantic, ""))
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if asset_id.is_empty() or audio_manager == null or not audio_manager.has_asset(asset_id):
		return
	var player: AudioStreamPlayer = audio_manager.play_2d(asset_id, &"UI")
	if player == null:
		return
	_record_history({
		"kind": "ui",
		"semantic": semantic,
		"asset_id": asset_id,
		"player_type": player.get_class(),
		"bus": str(player.bus),
	})


func _prime_door_states() -> void:
	for node in get_tree().get_nodes_in_group("building_art_view"):
		var source := node as Node3D
		if source == null or not source.has_method("debug_get_snapshot"):
			continue
		var snapshot: Dictionary = source.call("debug_get_snapshot")
		if not snapshot.has("gate_id") or not snapshot.has("open_fraction"):
			continue
		var gate_id := str(snapshot.get("gate_id", ""))
		_door_sources[gate_id] = source
		_door_states[gate_id] = {
			"open_fraction": clampf(float(snapshot.get("open_fraction", 0.0)), 0.0, 1.0),
			"direction": 0,
			"destroyed": bool(snapshot.get("destroyed", false)),
		}
	for node in get_tree().get_nodes_in_group("building_auto_door"):
		var source := node as Node3D
		if source == null or not source.has_method("debug_get_snapshot"):
			continue
		var snapshot: Dictionary = source.call("debug_get_snapshot")
		if not snapshot.has("open_fraction"):
			continue
		var source_id := _ordinary_door_source_id(source, snapshot)
		_door_sources[source_id] = source
		_door_states[source_id] = {
			"open_fraction": clampf(float(snapshot.get("open_fraction", 0.0)), 0.0, 1.0),
			"direction": 0,
			"destroyed": false,
		}


func _refresh_doors() -> void:
	for node in get_tree().get_nodes_in_group("building_art_view"):
		var source := node as Node3D
		if source == null or not source.has_method("debug_get_snapshot"):
			continue
		var snapshot: Dictionary = source.call("debug_get_snapshot")
		if not snapshot.has("gate_id") or not snapshot.has("open_fraction"):
			continue
		_apply_door_sample(
			source,
			str(snapshot.get("gate_id", "")),
			float(snapshot.get("open_fraction", 0.0)),
			bool(snapshot.get("destroyed", false))
		)
	for node in get_tree().get_nodes_in_group("building_auto_door"):
		var source := node as Node3D
		if source == null or not source.has_method("debug_get_snapshot"):
			continue
		var snapshot: Dictionary = source.call("debug_get_snapshot")
		if not snapshot.has("open_fraction"):
			continue
		_apply_door_sample(
			source,
			_ordinary_door_source_id(source, snapshot),
			float(snapshot.get("open_fraction", 0.0)),
			false
		)


func _ordinary_door_source_id(source: Node3D, snapshot: Dictionary) -> String:
	var building_id := str(snapshot.get("building_id", ""))
	if not building_id.is_empty():
		return "building_door:%s" % building_id
	return "building_door:%s" % str(source.get_path())


func _apply_door_sample(source: Node3D, gate_id: String, open_fraction: float, destroyed: bool) -> void:
	if source == null or gate_id.is_empty():
		return
	var fraction := clampf(open_fraction, 0.0, 1.0)
	var previous := _as_dictionary(_door_states.get(gate_id, {}))
	_door_sources[gate_id] = source
	if previous.is_empty():
		_door_states[gate_id] = {"open_fraction": fraction, "direction": 0, "destroyed": destroyed}
		return
	var epsilon := maxf(0.000001, float(_world_config.get("door_motion_epsilon", 0.0001)))
	var previous_fraction := float(previous.get("open_fraction", fraction))
	var previous_direction := int(previous.get("direction", 0))
	var direction := previous_direction
	if destroyed:
		direction = 0
	elif fraction > previous_fraction + epsilon:
		direction = 1
	elif fraction < previous_fraction - epsilon:
		direction = -1
	elif fraction <= epsilon or fraction >= 1.0 - epsilon:
		# Rendering can sample the same fraction between physics ticks. Preserve the
		# active direction mid-swing so the next physics update cannot replay it.
		direction = 0
	if direction != 0 and direction != previous_direction:
		_play_world_one_shot(
			str(_world_config.get("door_open_asset" if direction > 0 else "door_close_asset", "")),
			source,
			"door_open" if direction > 0 else "door_close",
			gate_id
		)
	_door_states[gate_id] = {
		"open_fraction": fraction,
		"direction": direction,
		"destroyed": destroyed,
	}


func _refresh_merchant() -> void:
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	if merchant_system == null or not merchant_system.has_method("get_market_snapshot"):
		_stop_merchant_loop()
		return
	_apply_merchant_snapshot(merchant_system.get_market_snapshot())


func _apply_merchant_snapshot(snapshot: Dictionary) -> void:
	var wagon_state := str(snapshot.get("wagon_state", "absent"))
	var wagon := _as_dictionary(snapshot.get("wagon", {}))
	var world_position: Variant = wagon.get("world_position", Vector3.ZERO)
	if world_position is Vector3:
		_ensure_merchant_source()
		if is_instance_valid(_merchant_source):
			_merchant_source.global_position = (world_position as Vector3) + Vector3.UP * float(
				_world_config.get("merchant_source_height_m", 0.35)
			)
	var actual_speed := float(wagon.get("actual_speed", 0.0))
	var moving := (
		["arriving", "departing"].has(wagon_state)
		and bool(wagon.get("active", false))
		and not bool(wagon.get("paused", false))
		and actual_speed > float(_world_config.get("merchant_minimum_actual_speed_mps", 0.05))
	)
	if moving:
		_start_merchant_loop()
	else:
		_stop_merchant_loop()


func _ensure_merchant_source() -> void:
	if is_instance_valid(_merchant_source) or not is_instance_valid(_world_source_root):
		return
	_merchant_source = Node3D.new()
	_merchant_source.name = "MerchantCartAudioSource"
	_merchant_source.set_meta("presentation_only", true)
	_world_source_root.add_child(_merchant_source)


func _start_merchant_loop() -> void:
	if _merchant_loop_active or not is_instance_valid(_merchant_source):
		return
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	var asset_id := str(_world_config.get("merchant_loop_asset", ""))
	var loop_key := str(_world_config.get("merchant_loop_key", "interaction_merchant_cart_travel"))
	if audio_manager == null or asset_id.is_empty() or not audio_manager.has_asset(asset_id):
		return
	var player: AudioStreamPlayer3D = audio_manager.start_loop_3d(loop_key, asset_id, _merchant_source, Vector3.ZERO, &"World")
	if player == null:
		return
	_merchant_loop_active = true
	_record_history({
		"kind": "world_loop_start",
		"semantic": "merchant_cart_travel",
		"asset_id": asset_id,
		"player_type": player.get_class(),
		"bus": str(player.bus),
		"world_position": _merchant_source.global_position,
	})


func _stop_merchant_loop() -> void:
	if not _merchant_loop_active:
		return
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	var loop_key := str(_world_config.get("merchant_loop_key", "interaction_merchant_cart_travel"))
	if audio_manager != null:
		audio_manager.stop_loop(loop_key, true)
	_merchant_loop_active = false
	_record_history({
		"kind": "world_loop_stop",
		"semantic": "merchant_cart_travel",
		"asset_id": str(_world_config.get("merchant_loop_asset", "")),
	})


func _play_world_one_shot(asset_id: String, source: Node3D, semantic: String, source_id: String) -> void:
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if audio_manager == null or asset_id.is_empty() or not audio_manager.has_asset(asset_id):
		return
	var player: AudioStreamPlayer3D = audio_manager.play_3d(asset_id, source, Vector3.ZERO, &"World")
	if player == null:
		return
	_record_history({
		"kind": "world_one_shot",
		"semantic": semantic,
		"source_id": source_id,
		"asset_id": asset_id,
		"player_type": player.get_class(),
		"bus": str(player.bus),
		"source_path": str(source.get_path()),
		"world_position": source.global_position,
	})


func _record_history(entry: Dictionary) -> void:
	_recent_history.append(entry.duplicate(true))
	var limit := maxi(1, int(_ui_config.get("recent_history_limit", 96)))
	while _recent_history.size() > limit:
		_recent_history.pop_front()


func _is_under_ui(node: Node) -> bool:
	var ui_root := get_node_or_null(UI_ROOT_PATH)
	return ui_root != null and (node == ui_root or ui_root.is_ancestor_of(node))


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("InteractionAudioController missing config: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}


func _as_dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
