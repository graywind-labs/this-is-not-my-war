extends SceneTree
var scene
var time
var panel
var cam
var dest := "res://artifacts/t1704_ppt/screenshots_extra/"
func _initialize() -> void:
	call_deferred("capture")
func shot(label: String) -> void:
	root.mode = Window.MODE_FULLSCREEN
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dest + label + ".png")
	print("CAPTURED ", label, " ", root.size, " mode=", root.mode)
func capture() -> void:
	root.mode = Window.MODE_FULLSCREEN
	change_scene_to_file("res://scenes/main/Main.tscn")
	await create_timer(4.0).timeout
	scene = current_scene
	scene.find_child("TutorialDirector", true, false).debug_skip_tutorial()
	await create_timer(25.0).timeout
	time = scene.get_node("Systems/TimeSystem")
	time.set_paused(true)
	time.set_current_time(1, 12, 0, 0)
	cam = scene.get_node("CameraRig")
	cam.set_zoom_distance(60.0)
	cam.focus_world_position_at_screen_center(Vector3(0, 0, 35))
	panel = scene.get_node("UI/NPCPanel")
	var board = scene.get_node("UI/NoticeBoardPanel")
	board.show_notice_board()
	board.notice_text_edit.text = "敌袭前请优先保障粮食和武器生产。布鲁诺负责餐食，格伦检查武器，艾达协调训练；疲劳的成员先休息，警铃响起后集合。"
	board._on_publish_pressed()
	await shot("01_notice")
	board.close_panel()
	panel.show_npc("cook_01")
	panel.debug_open_memory_detail("witness_log")
	await shot("02_witness")
	panel._close_memory_detail_popup()
	panel.debug_open_memory_detail("event_log")
	await shot("03_events")
	panel._close_memory_detail_popup()
	panel.hide()
	panel.show_npc("veteran_deputy_01")
	panel.debug_toggle_equipment_window()
	await shot("04_equipment")
	panel._hide_equipment_window()
	panel.hide()
	# Existing GM setup only prepares a battle; it is not evidence of AI recruitment.
	scene.get_node("Systems/EquipmentSystem").debug_apply_combat_loadout_preset()
	var combat = scene.get_node("Systems/CombatSystem")
	combat.debug_spawn_wave(3, true, true)
	combat.trigger_combat_alarm("hud")
	time.set_paused(false)
	cam.set_zoom_distance(62.0)
	cam.focus_world_position_at_screen_center(Vector3(0, 0, 52))
	await create_timer(10.0).timeout
	await shot("05_battle_approach")
	await create_timer(5.0).timeout
	await shot("06_battle")
	cam.set_zoom_distance(38.0)
	cam.focus_world_position_at_screen_center(Vector3(0, 0, 53))
	await shot("07_battle_detail")
	quit()
