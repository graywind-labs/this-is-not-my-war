extends SceneTree
var scene
var time
var combat
var cam
var output := "res://artifacts/t1704_promo_v2/captures_towers/"
func _initialize() -> void:
	set_meta("main_launch_request", {"startup_mode": 0})
	call_deferred("run_capture")
func shot(label: String) -> void:
	root.mode = Window.MODE_FULLSCREEN
	for alert in root.find_children("*", "AcceptDialog", true, false):
		alert.hide()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + label + ".png")
	var f = FileAccess.open(output + label + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(combat.get_wave_hud_snapshot(), "\t"))
	f.close()
	print("SHOT ", label, " size=", root.size, " mode=", root.mode, " state=", JSON.stringify(combat.get_wave_hud_snapshot()))
func run_capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	change_scene_to_file("res://scenes/main/Main.tscn")
	await create_timer(8.0).timeout
	scene = current_scene
	time = scene.get_node("Systems/TimeSystem")
	combat = scene.get_node("Systems/CombatSystem")
	time.set_current_time(1, 12, 0, 0)
	cam = scene.get_node("CameraRig")
	cam.set_zoom_distance(44.0)
	cam.focus_world_position_at_screen_center(Vector3(0, 0, 78))
	root.mode = Window.MODE_FULLSCREEN
	print("LOADOUT ", JSON.stringify(scene.get_node("Systems/EquipmentSystem").debug_apply_combat_loadout_preset()))
	var buildings = scene.get_node("Systems/BuildingSystem")
	var resources = scene.get_node("Systems/ResourceSystem")
	for building_id in ["wall", "front_gate", "main_hall", "workshop"]:
		for step in range(5 if building_id != "workshop" else 1):
			var effect: Dictionary = buildings.get_upgrade_level_effect(building_id)
			resources.add_resources(effect.get("cost", {}))
			if not buildings.upgrade_building(building_id):
				break
			buildings._on_logical_time_tick(float(buildings.get_upgrade_status(building_id).get("remaining_seconds", 0.0)) + 1.0, 1.0)
			print("UPGRADE ", building_id, " ", JSON.stringify(buildings.get_building(building_id)))
	resources.add_resources({"item_wall_arrow_tower": 8, "item_wall_ballista": 8})
	var devices = scene.get_node("Systems/DefenseDeviceSystem")
	for building_id in ["wall", "main_hall"]:
		for slot in devices.get_slots_for_building(building_id, false):
			var device_id := "wall_arrow_tower" if building_id == "wall" else "wall_ballista"
			print("TOWER ", JSON.stringify(devices.debug_deploy_device(device_id, str(slot.get("id", "")))))
	scene.get_node("Systems/ResourceSystem").add_resources({"item_iron_helmet": 8, "item_mail_chest": 8, "item_iron_bracers": 8, "item_iron_greaves": 8})
	for id in scene.get_node("Systems/NPCSystem").get_npc_ids():
		for slot in ["helmet", "chest", "bracers", "greaves"]:
			print("ARMOR ", id, " ", slot, " ", JSON.stringify(scene.get_node("Systems/EquipmentSystem").debug_equip_armor(id, slot)))
	scene.get_node("Systems/ResourceSystem").add_resources({"item_polearm": 8})
	for id in ["cook_01", "priest_01", "doctor_01", "engineer_01"]:
		print("DEFENSE_WEAPON ", JSON.stringify(scene.get_node("Systems/EquipmentSystem").debug_equip_weapon(id, "polearm")))
	print("RALLY ", JSON.stringify(combat.trigger_combat_alarm("gm")))
	time.set_paused(false)
	await create_timer(10.0).timeout
	await shot("00_rally")
	print("SPAWN ", JSON.stringify(combat.debug_spawn_wave(4, true, true)))
	for i in range(120):
		await create_timer(5.0).timeout
		if i < 14 or i % 6 == 0:
			await shot("battle_%03d" % i)
		print("PROGRESS ", i, " ", combat.get_active_enemy_count())
		if combat.get_active_enemy_count() == 0:
			await create_timer(2.0).timeout
			await shot("99_wave4_cleared")
			var f = FileAccess.open(output + "result.json", FileAccess.WRITE)
			f.store_string(JSON.stringify(combat.debug_get_combat_snapshot(), "\t"))
			f.close()
			print("WAVE4_CLEARED")
			quit()
			return
	await shot("98_timeout")
	print("CAPTURE_TIMEOUT")
	quit()
