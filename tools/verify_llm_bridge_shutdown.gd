extends SceneTree

const LLM_BRIDGE_SCRIPT := preload("res://scripts/systems/LLMBridge.gd")
const REQUEST_WAIT_MSEC := 2000
const SHUTDOWN_BUDGET_MSEC := 1000

var _last_async_response: Dictionary = {}


func _init() -> void:
	var shutdown_server := TCPServer.new()
	if shutdown_server.listen(0, "127.0.0.1") != OK:
		_fail("Could not start the shutdown verification server")
		return
	var shutdown_bridge := LLM_BRIDGE_SCRIPT.new()
	shutdown_bridge.backend_base_url = "http://127.0.0.1:%d" % shutdown_server.get_local_port()
	shutdown_bridge.request_timeout_seconds = 30.0
	root.add_child(shutdown_bridge)
	await process_frame

	var shutdown_request: Dictionary = shutdown_bridge.request_llm_usage_async()
	if not bool(shutdown_request.get("ok", false)):
		_fail("Could not start the pending shutdown request: %s" % JSON.stringify(shutdown_request))
		return
	var shutdown_peer := await _take_pending_connection(shutdown_server)
	if shutdown_peer == null:
		_fail("Shutdown verification request never reached the local server")
		return

	var shutdown_started_at := Time.get_ticks_msec()
	var shutdown_result: Dictionary = shutdown_bridge.call(
		"_shutdown_async_requests",
		"verify_scene_exit"
	)
	var shutdown_elapsed := Time.get_ticks_msec() - shutdown_started_at
	var shutdown_snapshot: Dictionary = shutdown_bridge.debug_get_llm_runtime_snapshot()
	if (
		not bool(shutdown_result.get("ok", false))
		or int(shutdown_result.get("cancelled_request_count", 0)) != 1
		or int(shutdown_result.get("joined_thread_count", 0)) != 1
		or shutdown_elapsed > SHUTDOWN_BUDGET_MSEC
		or int(shutdown_snapshot.get("async_request_count", -1)) != 0
		or int(shutdown_snapshot.get("pending_slowdown_count", -1)) != 0
		or not bool(shutdown_snapshot.get("transport_shutdown_requested", false))
	):
		_fail(
			"LLMBridge did not cancel and join its pending thread before shutdown: %s / %s"
			% [JSON.stringify(shutdown_result), JSON.stringify(shutdown_snapshot)]
		)
		return
	var rejected_after_shutdown: Dictionary = shutdown_bridge.request_llm_usage_async()
	if (
		bool(rejected_after_shutdown.get("ok", false))
		or str(rejected_after_shutdown.get("error_code", "")) != "llm_bridge_shutting_down"
	):
		_fail("LLMBridge accepted a new async request after shutdown")
		return
	shutdown_bridge.queue_free()
	shutdown_server.stop()
	shutdown_peer.disconnect_from_host()
	await process_frame

	var cancel_server := TCPServer.new()
	if cancel_server.listen(0, "127.0.0.1") != OK:
		_fail("Could not start the explicit-cancel verification server")
		return
	var cancel_bridge := LLM_BRIDGE_SCRIPT.new()
	cancel_bridge.backend_base_url = "http://127.0.0.1:%d" % cancel_server.get_local_port()
	cancel_bridge.request_timeout_seconds = 30.0
	cancel_bridge.llm_usage_response_received.connect(_on_async_response)
	root.add_child(cancel_bridge)
	await process_frame

	var cancel_request: Dictionary = cancel_bridge.request_llm_usage_async()
	var cancel_request_id := str(cancel_request.get("request_id", ""))
	if not bool(cancel_request.get("ok", false)) or cancel_request_id.is_empty():
		_fail("Could not start the explicit-cancel request")
		return
	var cancel_peer := await _take_pending_connection(cancel_server)
	if cancel_peer == null:
		_fail("Explicit-cancel request never reached the local server")
		return
	var cancel_result: Dictionary = cancel_bridge.cancel_llm_request(
		cancel_request_id,
		"verify_explicit_cancel"
	)
	if not bool(cancel_result.get("cancelled", false)):
		_fail("Explicit cancellation was not accepted: %s" % JSON.stringify(cancel_result))
		return
	if not await _wait_for_async_response():
		_fail("Explicit cancellation did not complete its worker callback")
		return
	var cancel_snapshot: Dictionary = cancel_bridge.debug_get_llm_runtime_snapshot()
	if (
		str(_last_async_response.get("error_code", "")) != "request_cancelled"
		or not bool(_last_async_response.get("cancelled", false))
		or int(cancel_snapshot.get("async_request_count", -1)) != 0
		or int(cancel_snapshot.get("pending_slowdown_count", -1)) != 0
	):
		_fail(
			"Explicit cancellation left an invalid response or live request: %s / %s"
			% [JSON.stringify(_last_async_response), JSON.stringify(cancel_snapshot)]
		)
		return

	cancel_bridge.queue_free()
	cancel_server.stop()
	cancel_peer.disconnect_from_host()
	await process_frame
	print(
		"T0109 LLMBridge shutdown verification passed: "
		+ "pending transports cancel cooperatively, threads join before node release."
	)
	quit(0)


func _take_pending_connection(server: TCPServer) -> StreamPeerTCP:
	var deadline := Time.get_ticks_msec() + REQUEST_WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		if server.is_connection_available():
			return server.take_connection()
		await create_timer(0.01).timeout
	return null


func _wait_for_async_response() -> bool:
	var deadline := Time.get_ticks_msec() + REQUEST_WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		if not _last_async_response.is_empty():
			return true
		await create_timer(0.01).timeout
	return false


func _on_async_response(result: Dictionary) -> void:
	_last_async_response = result.duplicate(true)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
