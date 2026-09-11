extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const NPC_SCENE_PATH := "res://scenes/npc/NPC.tscn"


func _init() -> void:
	var main_scene := load(MAIN_SCENE_PATH) as PackedScene
	var npc_scene := load(NPC_SCENE_PATH) as PackedScene
	if main_scene == null or npc_scene == null:
		_fail("T0223 could not load Main or NPC scene")
		return

	var main := main_scene.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup.set("_startup_running", true)
	root.add_child(main)
	await process_frame
	await physics_frame

	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var slot_presenter := root.get_node_or_null("Main/UI/DefenseSlotPresenter")
	if [building_system, device_system, slot_presenter].has(null):
		_fail("T0223 required defense-device runtime nodes are missing")
		return

	for level in range(1, 7):
		_set_building_level(building_system, "main_hall", level)
		for raw_slot in device_system.get_slots_for_building("main_hall", true):
			var slot: Dictionary = raw_slot
			var multiplier := float(
				(slot.get("effect_modifiers", {}) as Dictionary).get("range_multiplier", 0.0)
			)
			if not is_equal_approx(multiplier, 1.0):
				_fail("T0223 main-hall slot retained a range bonus at Lv.%d: %s" % [level, slot])
				return

	_set_building_level(building_system, "main_hall", 1)
	slot_presenter._refresh_all()
	await process_frame
	if not slot_presenter.debug_open_slot("main_hall_slot_03"):
		_fail("T0223 could not open the main-hall deployment popup")
		return
	await process_frame
	await process_frame
	var popup: Dictionary = slot_presenter.debug_get_popup_snapshot()
	if bool(popup.get("bonus_visible", true)) or str(popup.get("bonus_text", "")).contains("高台加成"):
		_fail("T0223 main-hall popup still describes a range bonus: %s" % popup)
		return

	var npc := npc_scene.instantiate()
	root.add_child(npc)
	var profile := {
		"id": "blacksmith_01",
		"name": "格伦",
		"recruited": false,
		"states": {
			"hp": 100,
			"max_hp": 100,
			"current_action": "idle",
			"behavior_mode": "work",
			"unconscious": false,
			"escaped": false
		},
		"equipment": {}
	}
	npc.setup(profile)
	await process_frame
	await process_frame
	profile.states.hp = 0
	profile.states.unconscious = true
	profile.states.current_action = "unconscious"
	npc.update_profile(profile)
	await create_timer(1.8).timeout
	var settled: Dictionary = npc.debug_get_character_art_snapshot()
	var settled_position := float(settled.get("current_animation_position", 0.0))
	var settled_length := float(settled.get("current_animation_length", 0.0))
	if (
		str(settled.get("desired_state", "")) != "unconscious"
		or bool(settled.get("current_animation_playing", true))
		or settled_length <= 0.0
		or settled_position < settled_length - 0.05
	):
		_fail("T0223 unconscious animation did not settle on the final pose: %s" % settled)
		return

	for _refresh in range(3):
		npc.update_profile(profile)
		await process_frame
	var refreshed: Dictionary = npc.debug_get_character_art_snapshot()
	if (
		str(refreshed.get("desired_state", "")) != "unconscious"
		or bool(refreshed.get("current_animation_playing", true))
		or not is_equal_approx(
			float(refreshed.get("current_animation_position", -1.0)),
			settled_position
		)
	):
		_fail("T0223 unconscious profile refresh replayed Death_A: %s" % refreshed)
		return

	profile.states.hp = 30
	profile.states.unconscious = false
	profile.states.current_action = "idle"
	npc.update_profile(profile)
	await process_frame
	var revived: Dictionary = npc.debug_get_character_art_snapshot()
	if str(revived.get("desired_state", "")) != "get_up" or str(revived.get("current_clip", "")) != "Lie_StandUp":
		_fail("T0223 authoritative revive edge did not start Lie_StandUp: %s" % revived)
		return

	print("T0223_MAIN_HALL_RANGE_AND_UNCONSCIOUS_POSE_OK %s" % JSON.stringify({
		"main_hall_range_multiplier": 1.0,
		"main_hall_bonus_visible": bool(popup.get("bonus_visible", true)),
		"unconscious_final_position": settled_position,
		"unconscious_clip_length": settled_length,
		"revive_clip": str(revived.get("current_clip", ""))
	}))
	quit(0)


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var buildings: Dictionary = building_system.get("_buildings")
	var building: Dictionary = buildings.get(building_id, {})
	building["level"] = level
	building["hp"] = maxi(1, int(building.get("max_hp", 1)))
	buildings[building_id] = building
	building_system.set("_buildings", buildings)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
