extends SceneTree


func _init() -> void:
	var combat_script := load("res://scripts/systems/CombatSystem.gd") as GDScript
	if combat_script == null:
		_fail("CombatSystem.gd could not be loaded")
		return
	var combat_system: Node = combat_script.new()
	root.add_child(combat_system)

	var cases := [
		{"attack": 20.0, "defense": 10.0, "penetration": 12.0, "expected_unscaled": 20, "expected_formal": 14, "expected_tutorial": 48},
		{"attack": 20.0, "defense": 10.0, "penetration": 4.0, "expected_unscaled": 15, "expected_formal": 11, "expected_tutorial": 37},
		{"attack": 3.0, "defense": 40.0, "penetration": 0.0, "expected_unscaled": 1, "expected_formal": 1, "expected_tutorial": 2}
	]
	for test_case in cases:
		var generic: Dictionary = combat_system.calculate_damage_resolution(
			float(test_case["attack"]),
			float(test_case["defense"]),
			float(test_case["penetration"])
		)
		var friendly: Dictionary = combat_system.calculate_friendly_npc_damage_resolution(
			float(test_case["attack"]),
			float(test_case["defense"]),
			float(test_case["penetration"])
		)
		var tutorial: Dictionary = combat_system.calculate_friendly_npc_damage_resolution(
			float(test_case["attack"]),
			float(test_case["defense"]),
			float(test_case["penetration"]),
			true
		)
		if (
			int(generic.get("damage", 0)) != int(test_case["expected_unscaled"])
			or int(friendly.get("unscaled_damage", 0)) != int(test_case["expected_unscaled"])
			or int(friendly.get("damage", 0)) != int(test_case["expected_formal"])
			or not is_equal_approx(float(friendly.get("friendly_npc_damage_multiplier", 0.0)), 0.7)
			or bool(friendly.get("tutorial_scope", true))
			or int(tutorial.get("damage", 0)) != int(test_case["expected_tutorial"])
			or not is_equal_approx(float(tutorial.get("friendly_npc_damage_multiplier", 0.0)), 2.4)
			or not bool(tutorial.get("tutorial_scope", false))
		):
			_fail("Damage multiplier case failed: generic=%s formal=%s tutorial=%s" % [JSON.stringify(generic), JSON.stringify(friendly), JSON.stringify(tutorial)])
			return

	combat_system.queue_free()
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn could not be loaded")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var live_combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	if live_combat == null or npc_system == null or resource_system == null or equipment_system == null:
		_fail("Main combat dependencies are unavailable")
		return
	npc_system.set_npc_recruited("stableman_01", true)
	resource_system.add_resource("item_sword_shield", 1)
	var equip_result: Dictionary = equipment_system.equip_npc_main_weapon("stableman_01", "sword_shield", "private")
	if not bool(equip_result.get("ok", false)):
		_fail("Stableman weapon setup failed: %s" % JSON.stringify(equip_result))
		return
	var spawn_result: Dictionary = live_combat.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		_fail("Enemy setup failed: %s" % JSON.stringify(spawn_result))
		return
	var enemy_ids: Array = live_combat.get_active_enemy_ids()
	if enemy_ids.is_empty():
		_fail("No enemy was spawned")
		return
	var enemy_id := str(enemy_ids[0])
	var enemy_before: Dictionary = live_combat.get_enemy(enemy_id)
	var attack_context: Dictionary = live_combat._calculate_npc_attack_context(
		"stableman_01",
		npc_system.get_npc("stableman_01"),
		npc_system.get_npc_state("stableman_01")
	)
	var expected: Dictionary = live_combat.calculate_friendly_npc_damage_resolution(
		float(attack_context.get("raw_attack_power", 1.0)),
		float(enemy_before.get("defense", 0.0)),
		float(attack_context.get("penetration", 0.0))
	)
	var applied: Dictionary = live_combat._apply_npc_attack_to_enemy(
		"stableman_01",
		npc_system.get_npc("stableman_01"),
		enemy_before,
		attack_context
	)
	if (
		int(applied.get("damage", 0)) != int(expected.get("damage", 0))
		or int(applied.get("unscaled_damage", 0)) != int(expected.get("unscaled_damage", 0))
		or not is_equal_approx(float(applied.get("friendly_npc_damage_multiplier", 0.0)), 0.7)
	):
		_fail("Live NPC hit did not use the friendly multiplier: expected=%s applied=%s" % [JSON.stringify(expected), JSON.stringify(applied)])
		return
	if enemy_ids.size() < 2:
		_fail("Tutorial-scope hit verification requires a second enemy")
		return
	live_combat._tutorial_raid_active = true
	var tutorial_enemy_id := str(enemy_ids[1])
	var tutorial_enemy: Dictionary = live_combat.get_enemy(tutorial_enemy_id)
	var tutorial_expected: Dictionary = live_combat.calculate_friendly_npc_damage_resolution(
		float(attack_context.get("raw_attack_power", 1.0)),
		float(tutorial_enemy.get("defense", 0.0)),
		float(attack_context.get("penetration", 0.0))
	)
	var tutorial_applied: Dictionary = live_combat._apply_npc_attack_to_enemy(
		"stableman_01",
		npc_system.get_npc("stableman_01"),
		tutorial_enemy,
		attack_context
	)
	live_combat._tutorial_raid_active = false
	if (
		int(tutorial_applied.get("damage", 0)) != int(tutorial_expected.get("damage", 0))
		or not is_equal_approx(float(tutorial_applied.get("friendly_npc_damage_multiplier", 0.0)), 0.7)
	):
		_fail("A non-Ada tutorial-scope NPC incorrectly received Ada's multiplier: expected=%s applied=%s" % [JSON.stringify(tutorial_expected), JSON.stringify(tutorial_applied)])
		return

	print("T0433-R1 formal/tutorial friendly NPC damage multiplier verification passed")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
