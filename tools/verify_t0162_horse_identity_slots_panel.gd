extends SceneTree


const INITIAL_EXPECTED := {
	"horse_chestnut_wind": {"name": "栗风", "template_id": "chestnut_wind", "coat_name": "栗褐"},
	"horse_gray_mane": {"name": "灰鬃", "template_id": "gray_mane", "coat_name": "暖烟灰"},
}
const RIDER_ID := "veteran_deputy_01"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	root.add_child(packed.instantiate())
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	for _index in range(8):
		await physics_frame
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var horse_panel := root.get_node_or_null("Main/UI/HorsePanel")
	var stable_art := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Stable/StableArt")
	if horse_system == null or npc_system == null or combat_system == null or horse_panel == null or stable_art == null:
		_fail("T0162 runtime dependencies are missing")
		return
	horse_panel.debug_set_layout_viewport_override(Vector2(1280, 720))
	if horse_system.get_stable_slot_ids(1).size() != 7 or horse_system.get_stable_slot_ids(3).size() != 8 or not horse_system.get_stable_slot_ids(3).has("stall_03"):
		_fail("Stable level capacity contract must remain 7/7/8 with stall_03 unlocked at level 3")
		return

	var used_slots := {}
	var used_names := {}
	for horse_id in INITIAL_EXPECTED.keys():
		var horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
		var expected: Dictionary = INITIAL_EXPECTED[horse_id]
		if str(horse.get("name", "")) != str(expected.get("name", "")) or str(horse.get("template_id", "")) != str(expected.get("template_id", "")) or str(horse.get("coat_name", "")) != str(expected.get("coat_name", "")):
			_fail("Initial horse identity mismatch: %s" % JSON.stringify(horse))
			return
		var coat_color := str(horse.get("coat_color", ""))
		if not Color.html_is_valid(coat_color):
			_fail("Initial horse coat color is invalid: %s" % JSON.stringify(horse))
			return
		var slot_id := str(horse.get("stable_slot_id", ""))
		if slot_id.is_empty() or used_slots.has(slot_id):
			_fail("Initial horse slot is empty or duplicated: %s" % JSON.stringify(horse))
			return
		used_slots[slot_id] = horse_id
		used_names[str(horse.get("name", ""))] = horse_id

	var art_snapshot: Dictionary = stable_art.get_art_slice_snapshot()
	for horse_id in INITIAL_EXPECTED.keys():
		var horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
		var visual: Dictionary = (art_snapshot.get("horse_visuals", {}) as Dictionary).get(horse_id, {})
		if not bool(visual.get("visible", false)) or not bool(visual.get("name_visible", false)) or not bool(visual.get("click_enabled", false)):
			_fail("World horse must expose a visible name and click area: %s" % JSON.stringify(visual))
			return
		if str(visual.get("anchor_id", "")) != str(horse.get("stable_slot_id", "")) or str(visual.get("name", "")) != str(horse.get("name", "")) or str(visual.get("coat_color", "")) != str(horse.get("coat_color", "")):
			_fail("World horse projection drifted from authority: %s / %s" % [JSON.stringify(horse), JSON.stringify(visual)])
			return

	var gray_view := _find_horse_view(stable_art, "horse_gray_mane")
	if gray_view == null or not gray_view.has_method("debug_click"):
		_fail("Gray horse world view is not interactable")
		return
	gray_view.debug_click()
	await process_frame
	await process_frame
	var panel_snapshot: Dictionary = horse_panel.debug_get_snapshot()
	var portrait: Dictionary = panel_snapshot.get("portrait", {})
	if not bool(panel_snapshot.get("visible", false)) or str(panel_snapshot.get("horse_id", "")) != "horse_gray_mane":
		_fail("Clicking a horse did not open its own panel: %s" % JSON.stringify(panel_snapshot))
		return
	var portrait_rect: Rect2 = portrait.get("frame_global_rect", Rect2())
	var horse_panel_rect: Rect2 = panel_snapshot.get("rect", Rect2())
	if (
		portrait_rect.size.x < 190.0
		or portrait_rect.size.x > 210.0
		or portrait_rect.size.y < 300.0
		or portrait_rect.size.y > 420.0
		or portrait_rect.size.y >= horse_panel_rect.size.y - 40.0
		or absf(portrait_rect.position.y - horse_panel_rect.position.y) > 1.0
		or not bool(portrait.get("shares_main_world", false))
		or not bool(portrait.get("rendering_enabled", false))
	):
		_fail("Horse portrait does not match the NPC live-world viewport contract: portrait=%s panel=%s root=%s" % [JSON.stringify(portrait), horse_panel_rect, root.size])
		return
	var portrait_target: Dictionary = portrait.get("target_snapshot", {})
	if str(portrait_target.get("horse_id", "")) != "horse_gray_mane" or str(portrait_target.get("coat_color", "")) != str(horse_system.get_horse_snapshot("horse_gray_mane").get("coat_color", "")):
		_fail("Horse portrait is not following the selected world horse: %s" % JSON.stringify(portrait))
		return

	var first_foal_id := ""
	var capacity := int(horse_system.get_stable_capacity())
	while int(horse_system.get_horse_count()) < capacity:
		var birth: Dictionary = horse_system.debug_force_birth()
		if not bool(birth.get("ok", false)):
			_fail("Birth failed before stable capacity: %s" % JSON.stringify(birth))
			return
		var foal: Dictionary = birth.get("horse", {})
		if first_foal_id.is_empty():
			first_foal_id = str(foal.get("horse_id", ""))
		var horse_name := str(foal.get("name", ""))
		var slot_id := str(foal.get("stable_slot_id", ""))
		if horse_name.is_empty() or used_names.has(horse_name) or slot_id.is_empty() or used_slots.has(slot_id):
			_fail("Born horse identity or stable slot is not unique: %s" % JSON.stringify(foal))
			return
		used_names[horse_name] = true
		used_slots[slot_id] = true
	if used_names.size() != capacity or used_slots.size() != capacity:
		_fail("Stable did not fill with unique names and slots")
		return
	var full_birth: Dictionary = horse_system.debug_force_birth()
	if bool(full_birth.get("ok", false)) or str(full_birth.get("reason", "")) != "stable_full" or int(horse_system.get_horse_count()) != capacity:
		_fail("Full stable did not stop births: %s" % JSON.stringify(full_birth))
		return
	var parent_before: Dictionary = horse_system._horses["horse_chestnut_wind"].duplicate(true)
	parent_before["breeding_probability"] = 0.25
	horse_system._horses["horse_chestnut_wind"] = parent_before
	var changed := {}
	horse_system._roll_births_for_minute({"skill": 100.0, "level_factor": 1.0}, changed)
	if not is_equal_approx(float(horse_system.get_horse_snapshot("horse_chestnut_wind").get("breeding_probability", 0.0)), 0.25):
		_fail("Full stable should pause breeding-probability accumulation")
		return

	var foal_before: Dictionary = horse_system.get_horse_snapshot(first_foal_id)
	var matured: Dictionary = horse_system.debug_set_horse_growth(first_foal_id, 1.0)
	var foal_after: Dictionary = matured.get("horse", {})
	for key in ["template_id", "name", "coat_name", "coat_color", "stable_slot_id"]:
		if foal_before.get(key) != foal_after.get(key):
			_fail("Horse identity changed during maturation for %s" % key)
			return
	if not bool(foal_after.get("is_adult", false)):
		_fail("Debug maturation did not produce an adult horse")
		return

	npc_system.set_npc_behavior_mode(RIDER_ID, "work", "t0162_reset", {"force_idle": true})
	var assigned: Dictionary = horse_system.assign_horse_to_npc(RIDER_ID, "horse_gray_mane", "private")
	if not bool(assigned.get("ok", false)):
		_fail("Could not assign gray horse to rider: %s" % JSON.stringify(assigned))
		return
	var gray_presentation: Dictionary = horse_system.get_horse_presentation_snapshot("horse_gray_mane")
	var alarm: Dictionary = combat_system.trigger_combat_alarm("t0162_exact_horse_pickup")
	if not bool(alarm.get("ok", false)):
		_fail("Could not trigger exact-horse pickup alarm")
		return
	await physics_frame
	var pickup: Dictionary = horse_system.get_horse_snapshot("horse_gray_mane")
	var movement: Dictionary = pickup.get("movement_state", {})
	var pickup_target: Vector3 = movement.get("target_position", Vector3.ZERO)
	var gray_position: Vector3 = gray_presentation.get("world_position", Vector3.ZERO)
	if str(movement.get("npc_id", "")) != RIDER_ID or pickup_target.distance_to(gray_position) > 4.0:
		_fail("Rider did not target the assigned gray horse entity: %s" % JSON.stringify(pickup))
		return
	var completed: Dictionary = horse_system.debug_complete_horse_transition("horse_gray_mane")
	if not bool(completed.get("ok", false)):
		_fail("Could not complete assigned-horse rendezvous: %s" % JSON.stringify(completed))
		return
	for _index in range(3):
		await process_frame
	var art: Dictionary = npc_system.debug_get_npc_character_art_snapshot(RIDER_ID)
	var assigned_horse: Dictionary = horse_system.get_horse_snapshot("horse_gray_mane")
	if not bool(art.get("combat_mount_visual_visible", false)) or str(art.get("combat_mount_horse_id", "")) != "horse_gray_mane" or str(art.get("combat_mount_template_id", "")) != str(assigned_horse.get("template_id", "")) or str(art.get("combat_mount_coat_color", "")) != str(assigned_horse.get("coat_color", "")):
		_fail("Mounted presentation does not preserve assigned horse identity: %s" % JSON.stringify(art))
		return

	print("T0162 horse identity, stable-slot, panel and exact pickup verification passed.")
	quit(0)


func _find_horse_view(stable_art: Node, horse_id: String) -> Node:
	var root_node := stable_art.get_node_or_null("HorsePresentation")
	if root_node == null:
		return null
	for child in root_node.get_children():
		if str(child.get_meta("horse_id", "")) == horse_id:
			return child
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
