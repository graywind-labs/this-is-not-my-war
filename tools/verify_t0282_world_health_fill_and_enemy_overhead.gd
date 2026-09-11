extends SceneTree

const WORLD_HEALTH_BAR := preload("res://scripts/world/WorldHealthBar3D.gd")
const ENEMY_HEALTH_COLOR := Color("#c97832")


func _init() -> void:
	if not _verify_shared_bar_geometry():
		return

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn failed to load.")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	for _index in range(6):
		await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var layout_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if [combat_system, building_system, npc_system, layout_controller, npc_root].has(null):
		_fail("T0282 required runtime nodes are missing.")
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		_fail("Could not spawn enemies for T0282 verification: %s" % spawn_result)
		return
	for _index in range(5):
		await process_frame

	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	if enemy_ids.is_empty():
		_fail("T0282 enemy spawn produced no active enemy.")
		return
	var enemy_id := str(enemy_ids[0])
	if not _verify_enemy_overhead(combat_system, enemy_id, false):
		return
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	var enemy_target_hp := maxi(1, int(floor(float(enemy.get("max_hp", 1)) * 0.2)))
	combat_system._apply_damage_to_enemy(
		enemy_id,
		maxi(1, int(enemy.get("hp", 1)) - enemy_target_hp),
		"",
		{"source_type": "t0282_test"}
	)
	await process_frame
	if not _verify_enemy_overhead(combat_system, enemy_id, true):
		return

	var npc := _find_npc_view(npc_root)
	if npc == null or not npc.has_method("debug_get_overhead_ui_snapshot"):
		_fail("No NPC world view exposes an overhead snapshot.")
		return
	var npc_id := str(npc.get_meta("npc_id", ""))
	var npc_state: Dictionary = npc_system.get_npc_state(npc_id)
	var npc_hp := int(npc_state.get("hp", 1))
	var npc_max_hp := maxi(1, int(npc_state.get("max_hp", npc_hp)))
	var npc_target_hp := maxi(1, int(floor(float(npc_max_hp) * 0.42)))
	if npc_hp > npc_target_hp:
		npc_system.apply_damage_to_npc(npc_id, npc_hp - npc_target_hp)
	for _index in range(3):
		await process_frame
	var current_npc_state: Dictionary = npc_system.get_npc_state(npc_id)
	if not _verify_authority_width(
		npc.debug_get_overhead_ui_snapshot().get("health_bar", {}),
		int(current_npc_state.get("hp", 0)),
		int(current_npc_state.get("max_hp", 1)),
		"NPC"
	):
		return

	var warehouse: Dictionary = building_system.get_building("warehouse")
	building_system.apply_damage_to_building(
		"warehouse",
		maxi(1, int(warehouse.get("hp", 1))),
		"t0282_test"
	)
	for _index in range(3):
		await process_frame
	var warehouse_bar: Dictionary = layout_controller.debug_get_strategic_building_health_bar_snapshot().get("warehouse", {})
	if not _verify_authority_width(warehouse_bar, 0, int(warehouse.get("max_hp", 1)), "warehouse"):
		return
	if bool(warehouse_bar.get("fill_visible", true)):
		_fail("Zero-HP warehouse still has a visible world-bar fill: %s" % warehouse_bar)
		return

	combat_system.debug_clear_enemies()
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if llm_bridge != null and llm_bridge.has_method("_shutdown_async_requests"):
		llm_bridge._shutdown_async_requests()
		await process_frame
	print("T0282 world health fill and enemy overhead verification passed.")
	quit(0)


func _verify_shared_bar_geometry() -> bool:
	var bar := WORLD_HEALTH_BAR.new() as WorldHealthBar3D
	root.add_child(bar)
	bar.configure_size(2.0, 0.2)
	for sample in [[100, 100], [63, 100], [20, 100], [0, 100]]:
		bar.set_health(int(sample[0]), int(sample[1]), true)
		var snapshot: Dictionary = bar.get_debug_snapshot()
		if not _verify_authority_width(snapshot, int(sample[0]), int(sample[1]), "shared bar"):
			bar.queue_free()
			return false
		if not (snapshot.get("fill_scale", Vector3.ZERO) as Vector3).is_equal_approx(Vector3.ONE):
			bar.queue_free()
			return _fail("Shared bar still encodes fill ratio in Node3D scale: %s" % snapshot)
		if int(sample[0]) == 0 and bool(snapshot.get("fill_visible", true)):
			bar.queue_free()
			return _fail("Shared zero-HP bar fill is still visible: %s" % snapshot)
	bar.queue_free()
	return true


func _verify_enemy_overhead(combat_system: Node, enemy_id: String, expect_low_hp: bool) -> bool:
	var snapshot: Dictionary = combat_system.debug_get_enemy_overhead_snapshot(enemy_id)
	if snapshot.is_empty():
		return _fail("Enemy overhead snapshot is missing for %s." % enemy_id)
	var authority_name := str(snapshot.get("authority_name", ""))
	var name_text := str(snapshot.get("name_text", ""))
	if name_text != authority_name:
		return _fail("Enemy overhead is not the exact specific name: %s" % snapshot)
	if name_text.contains("\n") or name_text.contains("HP") or name_text.contains("步兵"):
		return _fail("Enemy overhead leaked textual HP or a generic class: %s" % snapshot)
	var bar: Dictionary = snapshot.get("health_bar", {})
	var name_y := float((snapshot.get("name_position", Vector3.ZERO) as Vector3).y)
	var bar_y := float((bar.get("position", Vector3.ZERO) as Vector3).y)
	if not is_equal_approx(name_y, 2.10) or not is_equal_approx(bar_y, 2.44):
		return _fail("Enemy name and health bar were not raised together: %s" % snapshot)
	if not bool(bar.get("local_visible", false)):
		return _fail("Enemy world health bar is not always visible: %s" % snapshot)
	if not (bar.get("color", Color.TRANSPARENT) as Color).is_equal_approx(ENEMY_HEALTH_COLOR):
		return _fail("Enemy world health bar is not orange: %s" % snapshot)
	if expect_low_hp and not bool(bar.get("danger", false)):
		return _fail("Enemy low-HP sample did not reach the shared danger ratio: %s" % snapshot)
	if bar_y <= name_y:
		return _fail("Enemy world health bar is not above the name: %s" % snapshot)
	return _verify_authority_width(
		bar,
		int(snapshot.get("authority_hp", 0)),
		int(snapshot.get("authority_max_hp", 1)),
		"enemy"
	)


func _verify_authority_width(raw: Variant, hp: int, max_hp: int, owner_name: String) -> bool:
	var bar: Dictionary = raw if raw is Dictionary else {}
	var expected_ratio := clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)
	var expected_width := float(bar.get("width", 0.0)) * expected_ratio
	if not is_equal_approx(float(bar.get("ratio", -1.0)), expected_ratio):
		return _fail("%s world-bar ratio does not match authority: %s" % [owner_name, bar])
	if not is_equal_approx(float(bar.get("fill_width", -1.0)), expected_width):
		return _fail("%s visible fill width does not match authority: %s" % [owner_name, bar])
	return true


func _find_npc_view(npc_root: Node) -> Node:
	for child in npc_root.get_children():
		if child.has_method("debug_get_overhead_ui_snapshot"):
			return child
	return null


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
