extends SceneTree

const ALERT_TEXT := "驿站成员的虔诚感动了上苍，现在你可以请求一次天火摧毁敌军！"
const TEST_TARGET := Vector3(0.0, 0.0, 75.0)


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("T0380 could not load Main.tscn")
		return
	root.add_child(packed.instantiate())
	for _index in range(10):
		await process_frame

	var event_bus := root.get_node_or_null("EventBus")
	var audio_manager := root.get_node_or_null("AudioManager")
	var piety_system := root.get_node_or_null("Main/Systems/PietySystem")
	var presenter := root.get_node_or_null("Main/UI/MilestoneAlertPresenter")
	var building_dialog := root.get_node_or_null("Main/UI/MilestoneAlertPresenter/BuildingCompletionDialog") as AcceptDialog
	var piety_dialog := root.get_node_or_null("Main/UI/MilestoneAlertPresenter/PietyReadyDialog") as AcceptDialog
	if event_bus == null or audio_manager == null or piety_system == null or presenter == null or building_dialog == null or piety_dialog == null:
		_fail("T0380 runtime dependencies are missing")
		return
	var ready_events: Array[Dictionary] = []
	event_bus.piety_ready.connect(func(current: float, maximum: float, reason: String) -> void:
		ready_events.append({"current": current, "maximum": maximum, "reason": reason})
	)

	piety_system.debug_set_piety(0.0)
	event_bus.building_job_completed.emit("wall", "repair", {"building_name": "围墙"})
	await process_frame
	piety_system.debug_fill_piety()
	await process_frame
	var snapshot: Dictionary = presenter.debug_get_snapshot()
	if (
		ready_events.size() != 1
		or str(snapshot.get("current_kind", "")) != "building"
		or int(snapshot.get("queued_count", 0)) != 1
		or int(snapshot.get("piety_ready_sound_play_count", -1)) != 0
	):
		_fail("Piety-ready alert did not queue silently behind an existing milestone: %s" % JSON.stringify(snapshot))
		return

	building_dialog.get_ok_button().pressed.emit()
	await process_frame
	await process_frame
	snapshot = presenter.debug_get_snapshot()
	if (
		str(snapshot.get("current_kind", "")) != "piety_ready"
		or not bool(snapshot.get("piety_dialog_visible", false))
		or str(snapshot.get("piety_dialog_text", "")) != ALERT_TEXT
		or str(snapshot.get("piety_button_text", "")) != "太好了"
		or int(snapshot.get("piety_ready_sound_play_count", 0)) != 1
		or str(snapshot.get("last_piety_ready_sound_asset_id", "")) != "sfx_piety_ready_sacred_chant"
	):
		_fail("Piety-ready dialog or selected sacred chant is wrong: %s" % JSON.stringify(snapshot))
		return
	var sacred_player := audio_manager.find_child("Audio2D_sfx_piety_ready_sacred_chant", false, false) as AudioStreamPlayer
	if sacred_player == null or sacred_player.bus != &"Combat" or sacred_player.stream == null:
		_fail("Selected piety-ready sacred chant is not a global Combat one-shot")
		return
	if absf(sacred_player.stream.get_length() - 5.0) > 0.02:
		_fail("Selected piety-ready sacred chant did not keep the extended 5-second tail")
		return

	piety_system.debug_fill_piety()
	await process_frame
	if ready_events.size() != 1 or int(presenter.debug_get_snapshot().get("piety_ready_sound_play_count", 0)) != 1:
		_fail("Repeated full-value refresh replayed the piety-ready alert")
		return
	piety_dialog.get_ok_button().pressed.emit()
	await process_frame
	await process_frame
	if bool(presenter.debug_get_snapshot().get("piety_dialog_visible", true)):
		_fail("The 太好了 button did not close the piety-ready dialog")
		return

	var cast_result: Dictionary = piety_system.request_meteor_cast(TEST_TARGET)
	if not bool(cast_result.get("ok", false)) or not is_zero_approx(float(piety_system.get_current_piety())):
		_fail("Formal meteor cast did not consume full piety before the repeat-ready check")
		return
	piety_system.debug_fill_piety()
	await process_frame
	snapshot = presenter.debug_get_snapshot()
	if ready_events.size() != 2 or not bool(snapshot.get("piety_dialog_visible", false)) or int(snapshot.get("piety_ready_sound_play_count", 0)) != 2:
		_fail("A second real charge cycle did not show and sound the selected alert again: %s" % JSON.stringify(snapshot))
		return

	audio_manager.stop_all_one_shots()
	print("T0380_PIETY_READY_ALERT_PASS crossing=once queue=preserved repeat_cycle=pass selected_05=5s_fade")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
