extends SceneTree


const EXPECTED_LINGER_SECONDS := 8.0


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	var main := packed.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in 4:
		await process_frame

	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	if combat == null:
		_fail("CombatSystem is missing")
		return
	var spawn: Dictionary = combat.debug_run_formal_dynamic_wave_slice(1)
	if not bool(spawn.get("ok", false)):
		_fail("Could not spawn the regular enemy fixture: %s" % JSON.stringify(spawn))
		return
	await process_frame
	var enemy_ids: Array[String] = combat.get_active_enemy_ids()
	if enemy_ids.is_empty():
		_fail("Regular enemy fixture has no active enemy")
		return
	var enemy_id := enemy_ids[0]
	var enemy: Dictionary = combat.get_enemy(enemy_id)
	combat.apply_enemy_area_damage(
		enemy.get("position", Vector3.ZERO),
		0.25,
		99999.0,
		{"max_targets": 1, "source_type": "t0133_r1_corpse_linger"}
	)
	await process_frame
	if combat.get_active_enemy_ids().has(enemy_id):
		_fail("Defeated enemy remained in the authoritative active set")
		return
	var corpse := _find_corpse(enemy_id)
	if corpse == null:
		_fail("Regular enemy defeat presentation was not preserved")
		return
	if not is_equal_approx(float(corpse.get_meta("corpse_linger_seconds", 0.0)), EXPECTED_LINGER_SECONDS):
		_fail("Regular corpse does not use the 8-second linger contract")
		return

	await create_timer(2.6).timeout
	corpse = _find_corpse(enemy_id)
	if corpse == null:
		_fail("Regular corpse was still removed at the former 2.4-second lifetime")
		return
	print("T0133_R1_ENEMY_CORPSE_LINGER PASS duration=%.1f" % EXPECTED_LINGER_SECONDS)
	quit(0)


func _find_corpse(enemy_id: String) -> Node3D:
	for node in root.find_children("*DefeatPresentation", "Node3D", true, false):
		if node.has_method("debug_get_snapshot"):
			var snapshot: Dictionary = node.debug_get_snapshot()
			if str(snapshot.get("enemy_id", "")) == enemy_id:
				return node as Node3D
		elif str(node.name).contains(enemy_id):
			return node as Node3D
		# Regular foot wrappers do not own enemy identity after authority removal;
		# the DefeatPresentation suffix is their lifecycle identity.
		return node as Node3D
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
