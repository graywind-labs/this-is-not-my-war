extends SceneTree


const ADA_ID := "veteran_deputy_01"
const OTHER_NPC_ID := "stableman_01"
const HIT_DAMAGE := 10


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn could not be loaded")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	if combat_system == null or npc_system == null:
		_fail("T0440 combat dependencies are unavailable")
		return

	var config := _load_tutorial_raid_config()
	if config.is_empty() or not is_equal_approx(float(config.get("ada_min_hp_ratio", -1.0)), 0.40):
		_fail("T0440 tutorial config must declare ada_min_hp_ratio=0.40: %s" % JSON.stringify(config))
		return
	var raid_result: Dictionary = combat_system.start_tutorial_raid(config)
	if not bool(raid_result.get("ok", false)):
		_fail("T0440 tutorial raid setup failed: %s" % JSON.stringify(raid_result))
		return

	var enemy := {"id": "t0440_enemy", "name": "T0440 诊断敌人"}
	var ada_max_hp := int(npc_system.get_npc_state(ADA_ID).get("max_hp", 0))
	var tutorial_floor := ceili(float(ada_max_hp) * 0.40)
	npc_system.update_npc_state(ADA_ID, {
		"hp": ada_max_hp,
		"unconscious": false,
		"escaped": false,
		"current_action": "idle",
	})
	for _hit_index in range(ada_max_hp / HIT_DAMAGE + 4):
		_apply_enemy_hit(combat_system, enemy, ADA_ID)
	var tutorial_ada_state: Dictionary = npc_system.get_npc_state(ADA_ID)
	if (
		int(tutorial_ada_state.get("hp", -1)) != tutorial_floor
		or bool(tutorial_ada_state.get("unconscious", true))
	):
		_fail("T0440 tutorial damage did not stop at the 40%% floor: %s" % JSON.stringify(tutorial_ada_state))
		return

	var end_result: Dictionary = combat_system.end_tutorial_raid("t0440_floor_verification")
	if not bool(end_result.get("ok", false)) or bool(combat_system.get_tutorial_raid_snapshot().get("active", true)):
		_fail("T0440 tutorial protection did not deactivate: %s" % JSON.stringify(end_result))
		return

	var formal_ada_state := _damage_formal_npc_to_zero(combat_system, npc_system, enemy, ADA_ID)
	if int(formal_ada_state.get("hp", -1)) != 0 or not bool(formal_ada_state.get("unconscious", false)):
		_fail("T0440 formal Ada damage inherited the tutorial floor: %s" % JSON.stringify(formal_ada_state))
		return
	var formal_other_state := _damage_formal_npc_to_zero(combat_system, npc_system, enemy, OTHER_NPC_ID)
	if int(formal_other_state.get("hp", -1)) != 0 or not bool(formal_other_state.get("unconscious", false)):
		_fail("T0440 formal NPC damage inherited the tutorial floor: %s" % JSON.stringify(formal_other_state))
		return

	print(
		"T0440 tutorial HP floor verification passed: Ada %d/%d in tutorial; Ada and %s reached 0 HP and became unconscious formally."
		% [tutorial_floor, ada_max_hp, OTHER_NPC_ID]
	)
	quit(0)


func _load_tutorial_raid_config() -> Dictionary:
	var file := FileAccess.open("res://data/tutorial_config.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	var tutorial_config := parsed as Dictionary
	return (tutorial_config.get("tutorial_raid", {}) as Dictionary).duplicate(true)


func _damage_formal_npc_to_zero(
	combat_system: Node,
	npc_system: Node,
	enemy: Dictionary,
	npc_id: String
) -> Dictionary:
	var max_hp := int(npc_system.get_npc_state(npc_id).get("max_hp", 0))
	npc_system.update_npc_state(npc_id, {
		"hp": max_hp,
		"unconscious": false,
		"escaped": false,
		"current_action": "idle",
	})
	for _hit_index in range(max_hp / HIT_DAMAGE + 2):
		_apply_enemy_hit(combat_system, enemy, npc_id)
	return npc_system.get_npc_state(npc_id)


func _apply_enemy_hit(combat_system: Node, enemy: Dictionary, npc_id: String) -> void:
	combat_system._apply_enemy_attack_to_npc(
		enemy,
		npc_id,
		HIT_DAMAGE,
		float(HIT_DAMAGE),
		0.0,
		0.0,
		0.0
	)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
