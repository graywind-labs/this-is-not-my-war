extends Node
class_name VoiceInputBridge

signal analysis_succeeded(result: Dictionary)
signal analysis_failed(result: Dictionary)

const LLM_BRIDGE_PATH := "/root/Main/Systems/LLMBridge"
const CONFIG_PATH := "res://data/dialogue_input_config.json"
const DEFAULT_BACKEND_URL := "http://127.0.0.1:5000"
const DEFAULT_TIMEOUT_SECONDS := 15.0
const DEFAULT_MAX_UPLOAD_BYTES := 6_291_456
const NATIVE_EMOTION_LABELS := {
	"neutral": "平静地",
	"happy": "愉快地",
	"sad": "悲伤地",
	"disgusted": "厌恶地",
	"angry": "愤怒地",
	"fearful": "恐惧地",
	"surprised": "惊讶地",
}

@export var request_timeout_seconds := DEFAULT_TIMEOUT_SECONDS

var _active_http_request: HTTPRequest
var _active_request_id := ""
var _active_dialogue_id := ""
var _backend_base_url_override := ""
var _max_upload_bytes := DEFAULT_MAX_UPLOAD_BYTES


func _ready() -> void:
	_load_limits()


func analyze_recording(recording: Dictionary, npc_id: String) -> Dictionary:
	if is_busy():
		return _failure("voice_busy", "语音输入正在处理中。")
	var request_id := str(recording.get("request_id", "")).strip_edges()
	var dialogue_id := str(recording.get("dialogue_id", "")).strip_edges()
	var wav_path := str(recording.get("wav_path", "")).strip_edges()
	var clean_npc_id := npc_id.strip_edges()
	if request_id.is_empty() or dialogue_id.is_empty() or clean_npc_id.is_empty():
		return _failure("voice_request_invalid", "当前语音请求缺少必要的对话信息。", request_id, dialogue_id)
	if wav_path.is_empty() or not FileAccess.file_exists(wav_path):
		return _failure("recording_empty", "本次录音文件不存在，请重新录音。", request_id, dialogue_id)
	var audio_bytes := FileAccess.get_file_as_bytes(wav_path)
	if audio_bytes.is_empty():
		return _failure("recording_empty", "没有录到有效声音，请检查麦克风后重试。", request_id, dialogue_id)
	if audio_bytes.size() > _max_upload_bytes:
		return _failure("audio_too_large", "本次录音超过上传大小限制，请缩短后重试。", request_id, dialogue_id)

	var boundary := "----------------GodotVoice%d" % Time.get_ticks_usec()
	var body := _build_multipart_body(boundary, request_id, dialogue_id, clean_npc_id, audio_bytes)
	var request := HTTPRequest.new()
	request.name = "VoiceAnalyzeHTTPRequest"
	request.timeout = maxf(0.1, request_timeout_seconds)
	request.body_size_limit = 1_048_576
	add_child(request)
	request.request_completed.connect(_on_request_completed.bind(request_id, dialogue_id, request))
	_active_http_request = request
	_active_request_id = request_id
	_active_dialogue_id = dialogue_id
	var headers := PackedStringArray([
		"Accept: application/json",
		"Content-Type: multipart/form-data; boundary=%s" % boundary,
	])
	var request_error := request.request_raw(
		_resolve_backend_base_url() + "/voice/analyze",
		headers,
		HTTPClient.METHOD_POST,
		body
	)
	if request_error != OK:
		_clear_active_request(request)
		return _failure(
			"voice_http_start_failed",
			"无法连接语音识别服务，请重试或继续手动输入。",
			request_id,
			dialogue_id,
			{"godot_error": request_error}
		)
	return {"ok": true, "request_id": request_id, "dialogue_id": dialogue_id}


func cancel(request_id: String = "") -> bool:
	if _active_http_request == null:
		return false
	if not request_id.is_empty() and request_id != _active_request_id:
		return false
	var request := _active_http_request
	_active_http_request = null
	_active_request_id = ""
	_active_dialogue_id = ""
	request.cancel_request()
	request.queue_free()
	return true


func is_busy() -> bool:
	return _active_http_request != null


func get_snapshot() -> Dictionary:
	return {
		"busy": is_busy(),
		"request_id": _active_request_id,
		"dialogue_id": _active_dialogue_id,
		"backend_base_url": _resolve_backend_base_url(),
		"max_upload_bytes": _max_upload_bytes,
	}


func build_recognized_segment(payload: Dictionary) -> Dictionary:
	var transcript := str(payload.get("transcript", "")).strip_edges()
	if transcript.is_empty():
		return _failure("voice_provider_invalid_response", "语音识别没有返回有效文字。")
	var segment := transcript
	var emotion := str(payload.get("emotion", "")).strip_edges().to_lower()
	var response_label := str(payload.get("emotion_label", "")).strip_edges()
	var expected_label := str(NATIVE_EMOTION_LABELS.get(emotion, ""))
	var emotion_applied := bool(payload.get("emotion_applied", false))
	if emotion_applied and not expected_label.is_empty() and response_label == expected_label:
		segment += "（%s）" % response_label
	return {
		"ok": true,
		"segment": segment,
		"transcript": transcript,
		"emotion": emotion if NATIVE_EMOTION_LABELS.has(emotion) else "none",
		"emotion_applied": segment != transcript,
	}


func debug_decode_response(
	result_code: int,
	http_status: int,
	body_text: String,
	request_id: String,
	dialogue_id: String
) -> Dictionary:
	if not OS.has_feature("editor"):
		return _failure("debug_unavailable", "仅编辑器环境可调用调试解析。")
	return _decode_response(result_code, http_status, body_text.to_utf8_buffer(), request_id, dialogue_id)


func set_backend_base_url_override(url: String) -> void:
	_backend_base_url_override = url.strip_edges().trim_suffix("/")


func _on_request_completed(
	result_code: int,
	http_status: int,
	_response_headers: PackedStringArray,
	body: PackedByteArray,
	request_id: String,
	dialogue_id: String,
	request: HTTPRequest
) -> void:
	if request != _active_http_request or request_id != _active_request_id or dialogue_id != _active_dialogue_id:
		if is_instance_valid(request):
			request.queue_free()
		return
	_clear_active_request(request)
	var result := _decode_response(result_code, http_status, body, request_id, dialogue_id)
	if bool(result.get("ok", false)):
		analysis_succeeded.emit(result)
	else:
		analysis_failed.emit(result)


func _decode_response(
	result_code: int,
	http_status: int,
	body: PackedByteArray,
	request_id: String,
	dialogue_id: String
) -> Dictionary:
	if result_code == HTTPRequest.RESULT_TIMEOUT:
		return _failure("voice_provider_timeout", "语音识别超时，请重试或继续手动输入。", request_id, dialogue_id)
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return _failure(
			"voice_http_error",
			"语音识别服务连接失败，请重试或继续手动输入。",
			request_id,
			dialogue_id,
			{"http_result": result_code}
		)
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK:
		return _failure("voice_provider_invalid_response", "语音识别服务返回了无效数据。", request_id, dialogue_id)
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return _failure("voice_provider_invalid_response", "语音识别服务返回了无效数据。", request_id, dialogue_id)
	var payload := parsed as Dictionary
	if http_status < 200 or http_status >= 300 or not bool(payload.get("ok", false)):
		var error_code := str(payload.get("error_code", "voice_provider_http_error"))
		return _failure(error_code, _localized_error_message(error_code), request_id, dialogue_id, {"http_status": http_status})
	if str(payload.get("request_id", "")) != request_id or str(payload.get("dialogue_id", "")) != dialogue_id:
		return _failure("voice_response_mismatch", "语音识别结果不属于当前对话，已忽略。", request_id, dialogue_id)
	if bool(payload.get("model_fallback_used", false)):
		return _failure("voice_provider_invalid_response", "语音识别返回了不允许的降级结果。", request_id, dialogue_id)
	var segment_result := build_recognized_segment(payload)
	if not bool(segment_result.get("ok", false)):
		segment_result["request_id"] = request_id
		segment_result["dialogue_id"] = dialogue_id
		return segment_result
	var result := payload.duplicate(true)
	result["ok"] = true
	result["request_id"] = request_id
	result["dialogue_id"] = dialogue_id
	result["recognized_segment"] = str(segment_result.get("segment", ""))
	result["emotion"] = str(segment_result.get("emotion", "none"))
	result["emotion_applied"] = bool(segment_result.get("emotion_applied", false))
	return result


func _build_multipart_body(
	boundary: String,
	request_id: String,
	dialogue_id: String,
	npc_id: String,
	audio_bytes: PackedByteArray
) -> PackedByteArray:
	var body := PackedByteArray()
	for field in [
		["request_id", request_id],
		["npc_id", npc_id],
		["dialogue_id", dialogue_id],
		["locale", "zh"],
	]:
		body.append_array((
			"--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n"
			% [boundary, str(field[0]), _sanitize_form_value(str(field[1]))]
		).to_utf8_buffer())
	var audio_header := (
		"--%s\r\nContent-Disposition: form-data; name=\"audio\"; filename=\"recording.wav\"\r\n"
		+ "Content-Type: audio/wav\r\n\r\n"
	) % boundary
	body.append_array(audio_header.to_utf8_buffer())
	body.append_array(audio_bytes)
	body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
	return body


func _resolve_backend_base_url() -> String:
	if not _backend_base_url_override.is_empty():
		return _backend_base_url_override
	var llm_bridge := get_node_or_null(LLM_BRIDGE_PATH)
	if llm_bridge != null and llm_bridge.has_method("get_backend_base_url"):
		var configured_url := str(llm_bridge.get_backend_base_url()).strip_edges().trim_suffix("/")
		if not configured_url.is_empty():
			return configured_url
	return DEFAULT_BACKEND_URL


func _clear_active_request(request: HTTPRequest) -> void:
	if request == _active_http_request:
		_active_http_request = null
		_active_request_id = ""
		_active_dialogue_id = ""
	if is_instance_valid(request):
		request.queue_free()


func _failure(
	error_code: String,
	message: String,
	request_id: String = "",
	dialogue_id: String = "",
	details: Dictionary = {}
) -> Dictionary:
	return {
		"ok": false,
		"request_id": request_id,
		"dialogue_id": dialogue_id,
		"error_code": error_code,
		"message": message,
		"details": details.duplicate(true),
	}


func _localized_error_message(error_code: String) -> String:
	match error_code:
		"recording_empty":
			return "没有录到有效声音，请检查麦克风后重试。"
		"audio_invalid":
			return "本次录音格式无效，请重新录音。"
		"audio_too_long":
			return "本次录音超过30秒，请缩短后重试。"
		"audio_too_large":
			return "本次录音超过上传大小限制，请缩短后重试。"
		"voice_provider_timeout":
			return "语音识别超时，请重试或继续手动输入。"
		"voice_budget_exceeded":
			return "语音识别预算已用尽，请继续手动输入。"
		_:
			return "语音识别失败，请重试或继续手动输入。"


func _sanitize_form_value(value: String) -> String:
	return value.replace("\r", "").replace("\n", "")


func _load_limits() -> void:
	var raw_config: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if raw_config is Dictionary:
		_max_upload_bytes = maxi(1, int((raw_config as Dictionary).get("voice_upload_max_bytes", DEFAULT_MAX_UPLOAD_BYTES)))


func _exit_tree() -> void:
	cancel()
