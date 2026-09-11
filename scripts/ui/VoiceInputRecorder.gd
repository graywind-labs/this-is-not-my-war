extends Node
class_name VoiceInputRecorder

signal state_changed(state: String, elapsed_seconds: float)
signal recording_ready(result: Dictionary)
signal recording_failed(error_code: String, message: String)

const STATE_IDLE := "idle"
const STATE_RECORDING := "recording"
const STATE_ANALYZING := "analyzing"
const MIC_BUS_NAME := &"MicRecord"
const TEMP_DIRECTORY := "user://voice_input"
const CONFIG_PATH := "res://data/dialogue_input_config.json"
const DEFAULT_MAX_SECONDS := 30.0

@onready var microphone_player: AudioStreamPlayer = $MicrophonePlayer
@onready var recording_limit_timer: Timer = $RecordingLimitTimer

var _state := STATE_IDLE
var _record_effect: AudioEffectRecord
var _max_seconds := DEFAULT_MAX_SECONDS
var _started_ticks_usec := 0
var _request_id := ""
var _dialogue_id := ""
var _temporary_wav_path := ""
var _debug_elapsed_override := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	recording_limit_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	recording_limit_timer.ignore_time_scale = true
	recording_limit_timer.one_shot = true
	recording_limit_timer.timeout.connect(_on_recording_limit_reached)
	_load_limits()
	_resolve_record_effect()
	_cleanup_stale_recordings()


func start_recording(dialogue_id: String) -> Dictionary:
	if _state != STATE_IDLE:
		return {"ok": false, "error_code": "voice_busy", "message": "语音输入正在处理中。"}
	if dialogue_id.strip_edges().is_empty():
		return {"ok": false, "error_code": "dialogue_unavailable", "message": "当前没有可用的玩家对话。"}
	if not is_microphone_available():
		return {"ok": false, "error_code": "microphone_unavailable", "message": "麦克风不可用，请检查设备或录音权限。"}

	_cleanup_stale_recordings()
	_request_id = "voice_%d" % Time.get_ticks_usec()
	_dialogue_id = dialogue_id.strip_edges()
	_temporary_wav_path = "%s/%s.wav" % [TEMP_DIRECTORY, _request_id]
	_started_ticks_usec = Time.get_ticks_usec()
	_debug_elapsed_override = -1.0
	microphone_player.play()
	_record_effect.set_recording_active(true)
	recording_limit_timer.start(_max_seconds)
	_set_state(STATE_RECORDING)
	return {
		"ok": true,
		"request_id": _request_id,
		"dialogue_id": _dialogue_id,
		"max_seconds": _max_seconds,
	}


func finish_recording(reason: String = "manual") -> Dictionary:
	if _state != STATE_RECORDING:
		return {"ok": false, "error_code": "recording_inactive", "message": "当前没有正在进行的录音。"}
	var elapsed_seconds := get_elapsed_seconds()
	recording_limit_timer.stop()
	_record_effect.set_recording_active(false)
	microphone_player.stop()
	var recording := _record_effect.get_recording()
	_trim_pcm_recording_to_limit(recording)
	if recording == null or recording.get_length() <= 0.0:
		return _fail("recording_empty", "没有录到有效声音，请检查麦克风后重试。")

	var absolute_directory := ProjectSettings.globalize_path(TEMP_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return _fail("audio_save_failed", "无法创建语音临时目录。")
	var save_base_path := _temporary_wav_path.trim_suffix(".wav")
	var save_error := recording.save_to_wav(save_base_path)
	if save_error != OK or not FileAccess.file_exists(_temporary_wav_path):
		return _fail("audio_save_failed", "无法保存本次录音。")

	_set_state(STATE_ANALYZING, elapsed_seconds)
	var result := {
		"ok": true,
		"request_id": _request_id,
		"dialogue_id": _dialogue_id,
		"wav_path": _temporary_wav_path,
		"duration_seconds": minf(recording.get_length(), _max_seconds),
		"finish_reason": reason,
	}
	recording_ready.emit(result.duplicate(true))
	return result


func complete_analysis(request_id: String) -> bool:
	if _state != STATE_ANALYZING or request_id != _request_id:
		return false
	_remove_temporary_wav()
	_clear_session()
	_set_state(STATE_IDLE)
	return true


func cancel(_reason: String = "cancelled") -> void:
	if _record_effect != null and _record_effect.is_recording_active():
		_record_effect.set_recording_active(false)
	if microphone_player != null:
		microphone_player.stop()
	if recording_limit_timer != null:
		recording_limit_timer.stop()
	_remove_temporary_wav()
	_clear_session()
	if _state != STATE_IDLE:
		_set_state(STATE_IDLE)


func is_microphone_available() -> bool:
	return (
		bool(ProjectSettings.get_setting("audio/driver/enable_input", false))
		and _record_effect != null
		and not AudioServer.get_input_device_list().is_empty()
	)


func get_state() -> String:
	return _state


func get_max_seconds() -> float:
	return _max_seconds


func get_elapsed_seconds() -> float:
	if _debug_elapsed_override >= 0.0:
		return minf(_debug_elapsed_override, _max_seconds)
	if _state != STATE_RECORDING or _started_ticks_usec <= 0:
		return 0.0
	return minf(float(Time.get_ticks_usec() - _started_ticks_usec) / 1_000_000.0, _max_seconds)


func get_snapshot() -> Dictionary:
	return {
		"state": _state,
		"request_id": _request_id,
		"dialogue_id": _dialogue_id,
		"temporary_wav_path": _temporary_wav_path,
		"elapsed_seconds": get_elapsed_seconds(),
		"max_seconds": _max_seconds,
		"microphone_available": is_microphone_available(),
	}


func debug_set_state_for_ui(state: String, elapsed_seconds: float = 0.0) -> bool:
	if not OS.has_feature("editor"):
		return false
	if not [STATE_IDLE, STATE_RECORDING, STATE_ANALYZING].has(state):
		return false
	_debug_elapsed_override = maxf(0.0, elapsed_seconds) if state == STATE_RECORDING else -1.0
	_state = state
	state_changed.emit(_state, get_elapsed_seconds())
	return true


func _on_recording_limit_reached() -> void:
	finish_recording("time_limit")


func _set_state(next_state: String, elapsed_seconds: float = -1.0) -> void:
	_state = next_state
	state_changed.emit(_state, get_elapsed_seconds() if elapsed_seconds < 0.0 else elapsed_seconds)


func _fail(error_code: String, message: String) -> Dictionary:
	_remove_temporary_wav()
	_clear_session()
	_set_state(STATE_IDLE)
	recording_failed.emit(error_code, message)
	return {"ok": false, "error_code": error_code, "message": message}


func _load_limits() -> void:
	var raw_config: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if raw_config is Dictionary:
		_max_seconds = maxf(1.0, float((raw_config as Dictionary).get("voice_recording_max_seconds", DEFAULT_MAX_SECONDS)))


func _resolve_record_effect() -> void:
	_record_effect = null
	var bus_index := AudioServer.get_bus_index(MIC_BUS_NAME)
	if bus_index < 0:
		return
	for effect_index in range(AudioServer.get_bus_effect_count(bus_index)):
		var effect := AudioServer.get_bus_effect(bus_index, effect_index)
		if effect is AudioEffectRecord:
			_record_effect = effect as AudioEffectRecord
			return


func _trim_pcm_recording_to_limit(recording: AudioStreamWAV) -> void:
	if recording == null or recording.format != AudioStreamWAV.FORMAT_16_BITS:
		return
	var channel_count := 2 if recording.stereo else 1
	var bytes_per_frame := 2 * channel_count
	var max_frame_count := int(floor(_max_seconds * float(recording.mix_rate)))
	var max_byte_count := max_frame_count * bytes_per_frame
	if recording.data.size() > max_byte_count:
		recording.data = recording.data.slice(0, max_byte_count)


func _cleanup_stale_recordings() -> void:
	var directory := DirAccess.open(TEMP_DIRECTORY)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.begins_with("voice_") and file_name.ends_with(".wav"):
			directory.remove(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()


func _remove_temporary_wav() -> void:
	if _temporary_wav_path.is_empty() or not FileAccess.file_exists(_temporary_wav_path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_temporary_wav_path))


func _clear_session() -> void:
	_started_ticks_usec = 0
	_request_id = ""
	_dialogue_id = ""
	_temporary_wav_path = ""
	_debug_elapsed_override = -1.0


func _exit_tree() -> void:
	cancel("scene_exit")
