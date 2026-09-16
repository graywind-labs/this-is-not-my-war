extends SceneTree

const CONTROLLER_SCRIPT := preload("res://scripts/presentation/audio/InteractionAudioController.gd")
const ASSET_ID := "sfx_defense_device_deploy_wood_thud"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := Node.new()
	main.name = "Main"
	root.add_child(main)
	var ui := Control.new()
	ui.name = "UI"
	main.add_child(ui)
	var world_root := Node3D.new()
	world_root.name = "WorldRoot"
	main.add_child(world_root)
	var formal_root := Node3D.new()
	formal_root.name = "FormalStationLayout"
	world_root.add_child(formal_root)
	var presentation := Node.new()
	presentation.name = "Presentation"
	main.add_child(presentation)
	var controller := Node.new()
	controller.name = "InteractionAudioController"
	controller.set_script(CONTROLLER_SCRIPT)
	presentation.add_child(controller)
	for _index in range(4):
		await process_frame

	var audio_manager := root.get_node_or_null("AudioManager")
	var event_bus := root.get_node_or_null("EventBus")
	_assert(audio_manager != null, "AudioManager autoload is missing")
	_assert(event_bus != null and event_bus.has_signal("defense_device_deployed"), "deployment success signal is missing")
	_assert(bool(controller.get_debug_snapshot().get("initialized", false)), "interaction controller did not initialize")
	_assert(audio_manager.has_asset(ASSET_ID), "confirmed deployment asset is missing")
	var asset_info: Dictionary = audio_manager.get_asset_info(ASSET_ID)
	_assert(str(asset_info.get("relative_path", "")) == "assets/audio/ui/sfx_defense_device_deploy_wood_thud_v01.wav", "runtime path mismatch")

	controller.debug_clear_history()
	var expected_position := Vector3(-2.5, 1.72, 11.35)
	event_bus.defense_device_deployed.emit("deployed_wall_slot_01", {
		"slot_id": "wall_slot_01",
		"position": {"x": expected_position.x, "y": expected_position.y, "z": expected_position.z},
	})
	await process_frame
	var history: Array = controller.get_debug_snapshot().get("recent_history", [])
	_assert(history.size() == 1, "one successful deployment must play exactly one sound")
	if not history.is_empty():
		var entry := history.back() as Dictionary
		_assert(str(entry.get("semantic", "")) == "defense_device_deployed", "wrong deployment semantic")
		_assert(str(entry.get("asset_id", "")) == ASSET_ID, "wrong deployment asset")
		_assert(str(entry.get("player_type", "")) == "AudioStreamPlayer", "deployment sound is not global 2D")
		_assert(str(entry.get("bus", "")) == "UI", "deployment sound does not follow click volume")
		_assert(absf(float(entry.get("gain_db", 0.0)) - 3.0) < 0.001, "deployment sound did not receive +3 dB gain")
		_assert(str(entry.get("slot_id", "")) == "wall_slot_01", "deployment sound lost slot identity")
		_assert(not entry.has("world_position"), "global deployment sound must not depend on camera or world position")

	controller.debug_clear_history()
	event_bus.defense_device_state_changed.emit({})
	await process_frame
	_assert((controller.get_debug_snapshot().get("recent_history", []) as Array).is_empty(), "state refresh or restore path replayed deployment audio")

	audio_manager.stop_all_one_shots()
	main.queue_free()
	await process_frame
	await process_frame
	print("T0420_DEFENSE_DEPLOY_AUDIO_PASS asset=01 signal=success_only spatial=global_2d bus=UI gain_db=3")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("T0420 verification failed: %s" % message)
	quit(1)
