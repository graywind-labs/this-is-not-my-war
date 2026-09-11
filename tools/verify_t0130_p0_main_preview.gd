extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("run_verification")


func run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	for _frame in 6:
		await process_frame
	var controller := main.get_node_or_null("Presentation/ChibiCharacterPilotPreviewController")
	check(controller != null, "Main preview controller is missing")
	if controller == null:
		finish()
		return
	var before_npc_count := get_npc_count(main)
	var enabled_snapshot: Dictionary = controller.call("debug_set_preview_enabled", true)
	await process_frame
	await process_frame
	check(bool(enabled_snapshot.get("enabled", false)), "Main preview did not enable")
	var preview_root := main.get_node_or_null("WorldRoot/FormalStationLayout/T0130CharacterPilotPreview")
	check(preview_root != null, "Main preview root is not under FormalStationLayout")
	if preview_root != null:
		var glen := preview_root.get_node_or_null("GlenChibiPilot")
		var enemy := preview_root.get_node_or_null("EnemySwordShieldChibiPilot")
		check(glen != null and enemy != null, "Main preview pair is incomplete")
		if glen != null:
			var glen_snapshot: Dictionary = glen.call("debug_get_snapshot")
			check(bool(glen_snapshot.get("ready", false)), "Main Glen pilot is not ready")
		if enemy != null:
			var enemy_snapshot: Dictionary = enemy.call("debug_get_snapshot")
			check(bool(enemy_snapshot.get("ready", false)), "Main enemy pilot is not ready")
	var gm_panel := main.get_node_or_null("UI/GMPanel")
	check(gm_panel != null, "GMPanel is missing")
	if gm_panel != null:
		check(gm_panel.find_child("ChibiFormalGlenWorkButton", true, false) != null, "GM formal Glen button is missing")
		check(gm_panel.find_child("ChibiFormalSwordShieldWaveButton", true, false) != null, "GM formal sword-shield wave button is missing")
		check(gm_panel.find_child("ChibiCharacterSandboxButton", true, false) != null, "GM character sandbox button is missing")
	check(get_npc_count(main) == before_npc_count, "presentation preview changed authoritative NPC count")
	if OS.get_cmdline_user_args().has("--t0130-main-capture"):
		await create_timer(1.2).timeout
		var image := root.get_viewport().get_texture().get_image()
		var capture_path := OS.get_user_data_dir().path_join("t0130_p0_main_preview.png")
		var capture_error := image.save_png(capture_path)
		print("T0130_MAIN_CAPTURE=%s ERROR=%d" % [capture_path, capture_error])
		check(capture_error == OK, "Main preview capture failed")
	var disabled_snapshot: Dictionary = controller.call("debug_set_preview_enabled", false)
	await process_frame
	await process_frame
	check(not bool(disabled_snapshot.get("enabled", true)), "Main preview did not disable")
	check(main.get_node_or_null("WorldRoot/FormalStationLayout/T0130CharacterPilotPreview") == null, "Main preview root survived disable")
	finish()


func get_npc_count(main: Node) -> int:
	var npc_system := main.get_node_or_null("Systems/NPCSystem")
	if npc_system == null or not npc_system.has_method("get_all_npcs"):
		return -1
	var npcs: Variant = npc_system.call("get_all_npcs")
	return npcs.size() if npcs is Array else -1


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func finish() -> void:
	if _failures.is_empty():
		print("T0130_P0_MAIN_PREVIEW PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("T0130_P0_MAIN_PREVIEW FAIL count=%d" % _failures.size())
		quit(1)
