extends SceneTree


func _init() -> void:
	if not bool(ProjectSettings.get_setting("audio/driver/enable_input", false)):
		_fail("Microphone input project setting is not enabled")
		return
	var mic_bus_index := AudioServer.get_bus_index(&"MicRecord")
	if mic_bus_index < 0 or not AudioServer.is_bus_mute(mic_bus_index):
		_fail("MicRecord bus must exist and remain muted")
		return
	if AudioServer.get_bus_effect_count(mic_bus_index) != 1:
		_fail("MicRecord bus must have exactly one recording effect")
		return
	var record_effect := AudioServer.get_bus_effect(mic_bus_index, 0)
	if not record_effect is AudioEffectRecord or (record_effect as AudioEffectRecord).format != AudioStreamWAV.FORMAT_16_BITS:
		_fail("MicRecord must use a 16-bit AudioEffectRecord")
		return

	var packed_main := load("res://scenes/main/Main.tscn") as PackedScene
	if packed_main == null:
		_fail("Failed to load Main.tscn")
		return
	var main := packed_main.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel")
	var recorder := dialog_panel.find_child("VoiceInputRecorder", true, false) as VoiceInputRecorder
	var microphone_player := dialog_panel.find_child("MicrophonePlayer", true, false) as AudioStreamPlayer
	var recording_timer := dialog_panel.find_child("RecordingLimitTimer", true, false) as Timer
	var input_row := dialog_panel.find_child("InputRow", true, false) as HBoxContainer
	var input_edit := dialog_panel.find_child("DialogInputEdit", true, false) as LineEdit
	var voice_button := dialog_panel.find_child("DialogVoiceButton", true, false) as Button
	var voice_icon := dialog_panel.find_child("DialogVoiceIcon", true, false) as TextureRect
	var send_button := dialog_panel.find_child("DialogSendButton", true, false) as Button
	var attack_button := dialog_panel.find_child("DialogAttackButton", true, false) as Button
	var overlay := dialog_panel.find_child("DialogRecordingOverlay", true, false) as Control
	var recording_icon := dialog_panel.find_child("DialogRecordingIcon", true, false) as TextureRect
	var recording_label := dialog_panel.find_child("DialogRecordingLabel", true, false) as Label
	var finish_button := dialog_panel.find_child("DialogRecordingFinishButton", true, false) as Button
	if null in [dialog_system, dialog_panel, recorder, microphone_player, recording_timer, input_row, input_edit, voice_button, voice_icon, send_button, attack_button, overlay, recording_icon, recording_label, finish_button]:
		_fail("T1601B required nodes are missing")
		return
	var input_child_names: Array[String] = []
	for child in input_row.get_children():
		input_child_names.append(child.name)
	if input_child_names != ["DialogInputEdit", "DialogVoiceButton", "DialogSendButton", "DialogAttackButton"]:
		_fail("Dialogue input row order mismatch: %s" % str(input_child_names))
		return
	if input_edit.max_length != 0:
		_fail("Dialogue draft must remain unlimited while recording UI is added")
		return
	if (
		voice_button.custom_minimum_size != Vector2(30.0, 30.0)
		or voice_button.size_flags_vertical != Control.SIZE_SHRINK_CENTER
		or voice_icon.texture == null
		or voice_icon.size != Vector2(24.0, 24.0)
		or voice_icon.mouse_filter != Control.MOUSE_FILTER_IGNORE
	):
		_fail("Voice button must contain an explicit centered 24px icon inside the compact 30px frame")
		return
	if recording_icon.texture == null or recording_icon.custom_minimum_size.x < 96.0:
		_fail("Recording overlay must use a large local microphone icon")
		return
	if microphone_player.bus != &"MicRecord" or not microphone_player.stream is AudioStreamMicrophone:
		_fail("Microphone player must feed the isolated MicRecord bus")
		return
	if not recording_timer.one_shot or not recording_timer.ignore_time_scale or not is_equal_approx(recording_timer.wait_time, 30.0):
		_fail("Recording limit timer must be one-shot, real-time and 30 seconds")
		return
	if not is_equal_approx(recorder.get_max_seconds(), 30.0):
		_fail("Recorder did not load the shared 30-second config")
		return

	var start_result: Dictionary = dialog_system.start_player_dialogue("cook_01")
	if not bool(start_result.get("ok", false)):
		_fail("Could not open player dialogue: %s" % str(start_result))
		return
	await process_frame
	input_edit.text = "已有草稿"
	if not dialog_panel.debug_set_voice_ui_state("recording", 7.4):
		_fail("Could not enter recording UI preview state")
		return
	await process_frame
	var snapshot: Dictionary = dialog_panel.debug_get_voice_ui_snapshot()
	if not bool(snapshot.get("overlay_visible", false)) or str(snapshot.get("label", "")) != "正在录音……7/30秒":
		_fail("Recording overlay or real-time label mismatch: %s" % str(snapshot))
		return
	if not bool(snapshot.get("finish_visible", false)) or bool(snapshot.get("input_editable", true)) or not bool(snapshot.get("send_disabled", false)) or not bool(snapshot.get("attack_disabled", false)):
		_fail("Recording state must disable draft/send/attack and show Finish")
		return
	if str(snapshot.get("draft", "")) != "已有草稿" or recording_icon.modulate.a < 0.35 or recording_icon.modulate.a > 1.0:
		_fail("Recording state changed the existing draft or invalidated icon pulse")
		return

	dialog_panel.debug_set_voice_ui_state("analyzing")
	await process_frame
	snapshot = dialog_panel.debug_get_voice_ui_snapshot()
	if str(snapshot.get("label", "")) != "正在识别语音与情绪……" or bool(snapshot.get("finish_visible", true)):
		_fail("Analyzing overlay must stop flashing text and hide Finish")
		return

	dialog_panel.debug_set_voice_ui_state("idle")
	await process_frame
	snapshot = dialog_panel.debug_get_voice_ui_snapshot()
	if bool(snapshot.get("overlay_visible", true)) or not bool(snapshot.get("input_editable", false)) or str(snapshot.get("draft", "")) != "已有草稿":
		_fail("Idle recovery must hide overlay and preserve editable draft")
		return

	var observer_state := {
		"dialogue_kind": "npc_npc",
		"dialogue_id": "observer_test",
		"participant_npc_ids": ["cook_01", "doctor_01"],
		"participant_names": {"cook_01": "布鲁诺", "doctor_01": "莉娜"},
		"waiting": false,
	}
	dialog_panel.set("_observer_mode", true)
	dialog_panel.call("_refresh", observer_state)
	await process_frame
	if voice_button.visible:
		_fail("NPC-NPC observer mode must hide the microphone button")
		return

	var recorder_source := FileAccess.get_file_as_string("res://scripts/ui/VoiceInputRecorder.gd")
	for required_text in ["finish_recording(\"time_limit\")", "user://voice_input", "DirAccess.remove_absolute", "Time.get_ticks_usec()"]:
		if not recorder_source.contains(required_text):
			_fail("Recorder source is missing lifecycle contract: %s" % required_text)
			return

	print("T1601B_VOICE_RECORDING_UI_OK")
	main.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
