extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Could not load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var game_state := root.get_node_or_null("/root/GameState")
	var hud := root.get_node_or_null("Main/UI/HUD")
	if game_state == null or hud == null:
		_fail("Required T0387 roundtrip nodes are missing")
		return
	# The real main-hall failure path supplies no settlement payload. The fact
	# compiler must still capture live resource/building state for the model.
	game_state.set_game_over("failure", "main_hall_destroyed")
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
		var state: Dictionary = game_state.settlement_snapshot.get("epilogue", {})
		if str(state.get("status", "")) != "pending" and not state.is_empty():
			break
	var final_state: Dictionary = game_state.settlement_snapshot.get("epilogue", {})
	if str(final_state.get("status", "")) != "llm":
		_fail("Mock backend roundtrip did not finish as LLM source: %s" % JSON.stringify(final_state))
		return
	if str(final_state.get("model_provider", "")) != "mock" or bool(final_state.get("fallback_used", true)):
		_fail("Roundtrip provider metadata is incorrect")
		return
	var fact_snapshot: Dictionary = game_state.settlement_snapshot.get("epilogue_fact_snapshot", {})
	var station_summary: Dictionary = fact_snapshot.get("station_summary", {})
	var resources: Dictionary = station_summary.get("resources", {})
	var buildings: Dictionary = station_summary.get("buildings", {})
	if not resources.get("items", []) is Array or (resources.get("items", []) as Array).is_empty():
		_fail("Failure path did not capture live resource facts")
		return
	if not buildings.get("items", []) is Array or (buildings.get("items", []) as Array).is_empty():
		_fail("Failure path did not capture live building facts")
		return
	var npc_data: Dictionary = game_state.settlement_snapshot.get("npcs", {})
	var items: Array = npc_data.get("items", [])
	if items.size() != 8:
		_fail("Roundtrip did not return all eight NPC endings")
		return
	for raw_item in items:
		var item: Dictionary = raw_item
		if not bool(item.get("escaped", false)) or bool(item.get("unconscious", false)):
			_fail("Failure roundtrip did not preserve the all-escaped settlement contract for %s" % str(item.get("id", "")))
			return
		if str(item.get("escape_circumstance", "")) != "after_fall_forced":
			_fail("Failure roundtrip lost the forced evacuation circumstance for %s" % str(item.get("id", "")))
			return
		if str(item.get("fate_summary", "")).length() < 140 or str(item.get("ending_title", "")).is_empty():
			_fail("Roundtrip ending contract failed for %s" % str(item.get("id", "")))
			return
	var fact_npcs: Array = fact_snapshot.get("npcs", []) if fact_snapshot.get("npcs", []) is Array else []
	for raw_fact_npc in fact_npcs:
		var fact_npc: Dictionary = raw_fact_npc if raw_fact_npc is Dictionary else {}
		if str(fact_npc.get("opening_status", "")) != "escaped":
			_fail("LLM failure payload must mark every NPC as escaped: %s" % JSON.stringify(fact_npc))
			return
		if str(fact_npc.get("escape_circumstance", "")) != "after_fall_forced":
			_fail("LLM failure payload lost the forced evacuation distinction: %s" % JSON.stringify(fact_npc))
			return
	var panel := hud.get_node_or_null("GameOverPanel")
	var cards := panel.find_children("NPCEndingCard_*", "PanelContainer", true, false) if panel != null else []
	var first_name := cards[0].find_child("NPCNameLabel", true, false) as Label if not cards.is_empty() else null
	if cards.size() != 8 or first_name == null or not first_name.text.contains("《"):
		_fail("HUD did not render generated ending titles as NPC cards")
		return
	print("T0387_EPILOGUE_MOCK_ROUNDTRIP_OK")
	main.queue_free()
	await process_frame
	quit(0)


func _find_label(node: Node, target_name: String) -> Label:
	if node.name == target_name and node is Label:
		return node as Label
	for child in node.get_children():
		var found := _find_label(child, target_name)
		if found != null:
			return found
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
