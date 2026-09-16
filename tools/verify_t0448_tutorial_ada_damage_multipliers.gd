extends SceneTree


const ADA_ID := "veteran_deputy_01"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("T0448 could not load Main.tscn")
		return
	root.add_child(packed.instantiate())
	await process_frame
	await process_frame
	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var npcs := root.get_node_or_null("Main/Systems/NPCSystem")
	if combat == null or npcs == null:
		_fail("T0448 combat dependencies are missing")
		return
	var spawn: Dictionary = combat.debug_spawn_wave(1, true)
	if not bool(spawn.get("ok", false)):
		_fail("T0448 could not spawn a target enemy")
		return
	var enemy_ids: Array = combat.get_active_enemy_ids()
	var enemy: Dictionary = combat.get_enemy(str(enemy_ids[0]))
	combat._tutorial_raid_active = true
	combat._tutorial_raid_snapshot = {
		"ada_npc_id": ADA_ID,
		"ada_min_hp_ratio": 0.40
	}

	var attack_context: Dictionary = combat._calculate_npc_attack_context(
		ADA_ID,
		npcs.get_npc(ADA_ID),
		npcs.get_npc_state(ADA_ID)
	)
	var expected_attack: Dictionary = combat.calculate_friendly_npc_damage_resolution(
		float(attack_context.get("raw_attack_power", 1.0)),
		float(enemy.get("defense", 0.0)),
		float(attack_context.get("penetration", 0.0)),
		true
	)
	var applied_attack: Dictionary = combat._apply_npc_attack_to_enemy(
		ADA_ID,
		npcs.get_npc(ADA_ID),
		enemy,
		attack_context
	)
	if (
		int(applied_attack.get("damage", 0)) != int(expected_attack.get("damage", -1))
		or not is_equal_approx(float(applied_attack.get("friendly_npc_damage_multiplier", 0.0)), 2.4)
	):
		_fail("T0448 Ada outgoing tutorial damage mismatch: %s" % JSON.stringify(applied_attack))
		return

	var ada_hit: Dictionary = combat._apply_enemy_attack_to_npc(
		enemy,
		ADA_ID,
		5,
		6.0,
		3.0,
		0.0,
		3.0
	)
	if (
		int(ada_hit.get("damage_before_tutorial_ada_multiplier", 0)) != 5
		or not is_equal_approx(float(ada_hit.get("tutorial_ada_damage_multiplier", 0.0)), 0.5)
		or int(ada_hit.get("damage", 0)) != 3
	):
		_fail("T0448 Ada incoming tutorial damage mismatch: %s" % JSON.stringify(ada_hit))
		return

	var non_ada_hit: Dictionary = combat._apply_enemy_attack_to_npc(
		enemy,
		"stableman_01",
		5,
		6.0,
		3.0,
		0.0,
		3.0
	)
	if (
		int(non_ada_hit.get("damage", 0)) != 5
		or not is_equal_approx(float(non_ada_hit.get("tutorial_ada_damage_multiplier", 0.0)), 1.0)
	):
		_fail("T0448 non-Ada incoming damage was changed: %s" % JSON.stringify(non_ada_hit))
		return

	print("T0448 tutorial Ada damage multipliers verified: incoming 0.5, outgoing 2.4")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
