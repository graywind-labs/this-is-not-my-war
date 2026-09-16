extends SceneTree
var last_ended: Dictionary = {}
var scene
var dialog
var npc
var panel
var dp
var output := "res://artifacts/t1704_ppt/screenshots_ghi/"
func _initialize() -> void:
	set_meta("main_launch_request", {"startup_mode": 0})
	call_deferred("run_capture")
func shot(label: String) -> void:
	for alert in root.find_children("*", "AcceptDialog", true, false):
		alert.hide()
	root.mode = Window.MODE_FULLSCREEN
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + label + ".png")
	print("SHOT ", label, " ", root.size, " mode=", root.mode)
func talk(label: String, content: String, recruit := false) -> Dictionary:
	last_ended.clear()
	var sent: Dictionary = dialog.send_player_message(content, recruit, true)
	print("SEND ", label, " ", JSON.stringify(sent))
	if not sent.get("ok", false):
		return {}
	for i in range(120):
		await create_timer(1.0).timeout
		var state: Dictionary = dialog.get_display_dialogue_state()
		if state.is_empty() and not last_ended.is_empty():
			state = last_ended.duplicate(true)
		if not state.get("waiting", false):
			var f = FileAccess.open(output + label + ".json", FileAccess.WRITE)
			f.store_string(JSON.stringify(state, "\t"))
			f.close()
			print("RESPONSE ", label, " error=", state.get("last_error", ""), " recruitment=", state.get("deferred_recruitment_result", ""))
			await shot(label)
			return state
	print("TIMEOUT ", label)
	return {}
func close_dialogue() -> void:
	dialog.complete_displayed_dialogue()
	await create_timer(2.0).timeout
	if dp.special_success_dialog:
		dp.special_success_dialog.hide()
	panel.hide()
func run_capture() -> void:
	change_scene_to_file("res://scenes/main/Main.tscn")
	await create_timer(8.0).timeout
	scene = current_scene
	dialog = scene.get_node("Systems/DialogSystem")
	dialog.dialogue_ended.connect(func(state): last_ended = state.duplicate(true))
	npc = scene.get_node("Systems/NPCSystem")
	panel = scene.get_node("UI/NPCPanel")
	dp = scene.get_node("UI/DialogPanel")
	scene.get_node("Systems/TimeSystem").set_current_time(1, 12, 0, 0)
	root.mode = Window.MODE_FULLSCREEN
	var cam = scene.get_node("CameraRig")
	cam.set_zoom_distance(48.0)
	cam.focus_world_position_at_screen_center(Vector3(0, 0, 20))
	await create_timer(3.0).timeout
	panel.show_npc("cook_01")
	print("OPEN_H ", JSON.stringify(dialog.start_player_dialogue("cook_01")))
	var h: Dictionary = await talk("H_recruit", "布鲁诺，我征召你入伍，不是让你拿菜刀冲锋。食堂仍归你管，警铃响起就到内院支援，受伤的人还得吃你做的热饭。守不住这里，锅和粮食都会落进敌人手里。你愿意和我们一起把自己的食堂守住吗？", true)
	if h.get("deferred_recruitment_result", "") == "reject":
		await talk("H_recruit_2", "那就把条件说清：厨房和后勤由你负责，不把你派去城门正面冲锋；你发现有人断粮可以直接来找我。我需要的是能带大家活下来的厨子，不是多一具尸体。按这个分工，你愿意应征吗？", true)
	await close_dialogue()
	panel.show_npc("cook_01")
	await shot("H_result")
	panel.hide()
	# A real published management decision is broadcast before asking the NPC.
	var board = scene.get_node("UI/NoticeBoardPanel")
	board.show_notice_board()
	board.notice_text_edit.text = "备战安排：格伦上午锻造武器，下午协助升级城门，晚间继续锻造。暂不安排额外人手。"
	board._on_publish_pressed()
	await shot("G_decision")
	board.close_panel()
	panel.show_npc("blacksmith_01")
	print("OPEN_G ", JSON.stringify(dialog.start_player_dialogue("blacksmith_01")))
	await talk("G_response", "格伦，刚发布的安排你看到了：上午打武器，下午去修城门，晚上继续打铁，暂时没有帮手。你认为这个安排能撑到敌袭吗？如果不行，告诉我你要我改哪一项。")
	await close_dialogue()
	board.show_notice_board()
	board.notice_text_edit.text = "修订备战安排：格伦专心锻造武器，城门施工交给欧文协调。保留休息时段，避免频繁切换工序。"
	board._on_publish_pressed()
	await shot("G_revised_decision")
	board.close_panel()
	# Reproduce the escape state through the existing GM entry; the intervention answer remains a real LLM result.
	print("ESCAPE_SETUP ", JSON.stringify(scene.get_node("Systems/CombatSystem").debug_start_npc_escape("cook_01")))
	panel.show_npc("cook_01")
	for alert in root.find_children("*", "AcceptDialog", true, false):
		alert.hide()
	print("OPEN_I ", JSON.stringify(dialog.start_escape_intervention_dialogue("cook_01")))
	await talk("I_intervention", "布鲁诺，先停一下。你不想送命，我也不想。外面的路没有锅、粮食和医生。留下来，我让你回食堂照顾伤员，不站城门第一排；你在这里还有能保护的人和事。告诉我你最担心什么，我们现在就解决。")
	await close_dialogue()
	panel.show_npc("cook_01")
	await shot("I_result")
	panel.open_dialogue_history("cook_01")
	await shot("I_history")
	print("CAPTURE_GHI_DONE")
	quit()
