extends SceneTree

const EXPECTED_SEGMENT := "我需要你保卫驿站。（愤怒地）"
const EMOTION_LABELS := {
	"neutral": "平静地",
	"happy": "愉快地",
	"sad": "悲伤地",
	"disgusted": "厌恶地",
	"angry": "愤怒地",
	"fearful": "恐惧地",
	"surprised": "惊讶地",
}


func _init() -> void:
	var packed_main := load("res://scenes/main/Main.tscn") as PackedScene
	if packed_main == null:
		_fail("Failed to load Main.tscn")
		return
	var main := packed_main.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var panel := root.get_node_or_null("Main/UI/DialogPanel")
	var recorder := panel.find_child("VoiceInputRecorder", true, false) as VoiceInputRecorder
	var bridge := panel.find_child("VoiceInputBridge", true, false) as VoiceInputBridge
	var input_edit := panel.find_child("DialogInputEdit", true, false) as LineEdit
	if null in [dialog_system, panel, recorder, bridge, input_edit]:
		_fail("T1601C required nodes are missing")
		return

	var start_result: Dictionary = dialog_system.start_player_dialogue("cook_01")
	if not bool(start_result.get("ok", false)):
		_fail("Could not open player dialogue: %s" % str(start_result))
		return
	await process_frame
	var dialogue_id := str(dialog_system.get_display_dialogue_state().get("dialogue_id", ""))
	if dialogue_id.is_empty():
		_fail("Player dialogue id is missing")
		return
	var initial_dialogue_state: Dictionary = dialog_system.get_display_dialogue_state()
	var initial_turn_count := (initial_dialogue_state.get("turns", []) as Array).size()

	for emotion in EMOTION_LABELS:
		var label := str(EMOTION_LABELS[emotion])
		var segment_result := bridge.build_recognized_segment({
			"transcript": "测试",
			"emotion": emotion,
			"emotion_label": label,
			"emotion_applied": true,
		})
		if str(segment_result.get("segment", "")) != "测试（%s）" % label:
			_fail("Native emotion mapping mismatch: %s" % emotion)
			return
	var unknown_result := bridge.build_recognized_segment({
		"transcript": "未知情绪仍保留文字",
		"emotion": "mock_unknown",
		"emotion_label": "不可信地",
		"emotion_applied": true,
	})
	if str(unknown_result.get("segment", "")) != "未知情绪仍保留文字" or str(unknown_result.get("emotion", "")) != "none":
		_fail("Unknown emotion must degrade to transcript only")
		return

	var timeout_result := bridge.debug_decode_response(
		HTTPRequest.RESULT_TIMEOUT, 0, "", "voice_timeout", dialogue_id
	)
	var invalid_json_result := bridge.debug_decode_response(
		HTTPRequest.RESULT_SUCCESS, 200, "not-json", "voice_json", dialogue_id
	)
	var http_error_result := bridge.debug_decode_response(
		HTTPRequest.RESULT_SUCCESS, 503,
		'{"ok":false,"error_code":"voice_provider_http_error"}',
		"voice_http", dialogue_id
	)
	var empty_transcript_result := bridge.debug_decode_response(
		HTTPRequest.RESULT_SUCCESS, 200,
		'{"ok":true,"request_id":"voice_empty","dialogue_id":"%s","transcript":"   ","emotion":"none","emotion_label":"","emotion_applied":false,"model_fallback_used":false}' % dialogue_id,
		"voice_empty", dialogue_id
	)
	for failure_result in [timeout_result, invalid_json_result, http_error_result, empty_transcript_result]:
		if bool(failure_result.get("ok", true)):
			_fail("Voice failure response was accepted: %s" % str(failure_result))
			return

	var cases := [
		{"draft": "", "expected": EXPECTED_SEGMENT},
		{"draft": "已有草稿", "expected": "已有草稿 %s" % EXPECTED_SEGMENT},
		{"draft": "已有空格 ", "expected": "已有空格 %s" % EXPECTED_SEGMENT},
	]
	for index in range(cases.size()):
		var request_id := "voice_t1601c_%d_%d" % [index, Time.get_ticks_usec()]
		var wav_path := "user://voice_input/%s.wav" % request_id
		if not _write_test_wav(wav_path):
			_fail("Could not write test WAV")
			return
		input_edit.text = str(cases[index]["draft"])
		recorder.set("_request_id", request_id)
		recorder.set("_dialogue_id", dialogue_id)
		recorder.set("_temporary_wav_path", wav_path)
		recorder.debug_set_state_for_ui("analyzing")
		var request_result := bridge.analyze_recording({
			"request_id": request_id,
			"dialogue_id": dialogue_id,
			"wav_path": wav_path,
		}, "cook_01")
		if not bool(request_result.get("ok", false)):
			_fail("Mock voice request did not start: %s" % str(request_result))
			return
		if not await _wait_for_idle(recorder, 10.0):
			_fail("Mock voice request timed out in test")
			return
		if input_edit.text != str(cases[index]["expected"]):
			_fail("Draft append mismatch: %s" % input_edit.text)
			return
		if input_edit.caret_column != input_edit.text.length():
			_fail("Caret was not restored to the end")
			return
		if FileAccess.file_exists(wav_path):
			_fail("Completed voice WAV was not cleaned up")
			return
	var unchanged_dialogue_state: Dictionary = dialog_system.get_display_dialogue_state()
	if (
		bool(unchanged_dialogue_state.get("waiting", false))
		or (unchanged_dialogue_state.get("turns", []) as Array).size() != initial_turn_count
	):
		_fail("Voice recognition must not automatically send an NPC dialogue message")
		return

	input_edit.text = "切换前草稿"
	var stale_request_id := "voice_stale"
	recorder.set("_request_id", stale_request_id)
	recorder.set("_dialogue_id", dialogue_id)
	recorder.debug_set_state_for_ui("analyzing")
	panel.call("_on_voice_analysis_succeeded", {
		"ok": true,
		"request_id": stale_request_id,
		"dialogue_id": "another_dialogue",
		"recognized_segment": "不应追加",
	})
	if input_edit.text != "切换前草稿":
		_fail("Late response entered another dialogue")
		return
	panel.call("_cancel_voice_pipeline", "test_cleanup")

	print("T1601C_VOICE_MOCK_ROUNDTRIP_OK")
	main.queue_free()
	await process_frame
	quit(0)


func _write_test_wav(path: String) -> bool:
	var absolute_directory := ProjectSettings.globalize_path("user://voice_input")
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return false
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 8000
	wav.stereo = false
	var pcm_data := PackedByteArray()
	pcm_data.resize(16_000)
	wav.data = pcm_data
	return wav.save_to_wav(path.trim_suffix(".wav")) == OK and FileAccess.file_exists(path)


func _wait_for_idle(recorder: VoiceInputRecorder, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if recorder.get_state() == "idle":
			return true
		await process_frame
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
