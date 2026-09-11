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
	var bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var epilogue_system := root.get_node_or_null("Main/Systems/EpilogueSystem")
	var game_state := root.get_node_or_null("/root/GameState")
	var hud := root.get_node_or_null("Main/UI/HUD")
	if bridge == null or epilogue_system == null or game_state == null or hud == null:
		_fail("Required T0387 nodes are missing")
		return
	bridge.set_backend_base_url("http://127.0.0.1:5999")
	game_state.set_game_over("victory", "five_waves_survived", {
		"resources": {"items": []},
		"buildings": {"station_operational": true, "damaged_buildings": [], "destroyed_buildings": []}
	})
	await process_frame
	var pending: Dictionary = game_state.settlement_snapshot.get("epilogue", {})
	if str(pending.get("status", "")) != "pending":
		_fail("Epilogue did not enter pending state: %s" % JSON.stringify(pending))
		return
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
		var state: Dictionary = game_state.settlement_snapshot.get("epilogue", {})
		if str(state.get("status", "")) == "template_fallback":
			break
	var final_state: Dictionary = game_state.settlement_snapshot.get("epilogue", {})
	if str(final_state.get("status", "")) != "template_fallback":
		_fail("Unavailable backend did not produce explicit template fallback: %s" % JSON.stringify(final_state))
		return
	var npc_data: Dictionary = game_state.settlement_snapshot.get("npcs", {})
	var items: Array = npc_data.get("items", [])
	if items.size() != 8:
		_fail("Epilogue did not preserve all eight NPCs")
		return
	for raw_item in items:
		var item: Dictionary = raw_item
		var story := str(item.get("fate_summary", ""))
		if story.length() < 140 or story.contains("Mock：") or story.contains("阵亡") or story.contains("死亡"):
			_fail("Fallback story contract failed for %s" % str(item.get("id", "")))
			return
	var panel := hud.get_node_or_null("GameOverPanel")
	var cards := panel.find_children("NPCEndingCard_*", "PanelContainer", true, false) if panel != null else []
	var first_name := cards[0].find_child("NPCNameLabel", true, false) as Label if not cards.is_empty() else null
	if cards.size() != 8 or first_name == null or not first_name.text.contains("《"):
		_fail("HUD did not render fallback stories as eight titled NPC cards")
		return
	print("T0387_EPILOGUE_FALLBACK_OK")
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
