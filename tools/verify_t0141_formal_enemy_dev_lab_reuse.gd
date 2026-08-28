extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const EXPECTED_ENEMIES := {
	"raider_sword": {"weapon": "sword_shield", "mounted": false},
	"raider_polearm": {"weapon": "polearm", "mounted": false},
	"raider_archer": {"weapon": "bow", "mounted": false},
	"raider_crossbow": {"weapon": "crossbow", "mounted": false},
	"raider_cavalry": {"weapon": "sword_shield", "mounted": true},
	"raider_sword_veteran": {"weapon": "sword_shield", "mounted": false},
	"raider_mounted_archer": {"weapon": "bow", "mounted": true},
}
const REPRESENTATIVE_WAVES := [3, 4, 5]
const WEAPON_VISIBILITY_KEYS := {
	"sword_shield": "sword_visible",
	"polearm": "polearm_visible",
	"bow": "bow_visible",
	"crossbow": "crossbow_visible",
}

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	_check(combat_system != null, "CombatSystem is missing from Main")
	if combat_system == null:
		_finish()
		return

	var seen_enemy_types: Dictionary = {}
	for wave_number in REPRESENTATIVE_WAVES:
		var spawn_result: Dictionary = combat_system.spawn_wave(wave_number, true, "t0141_formal_enemy_art", "front_gate")
		_check(bool(spawn_result.get("ok", false)), "Wave %d could not spawn: %s" % [wave_number, JSON.stringify(spawn_result)])
		if not bool(spawn_result.get("ok", false)):
			continue
		for _frame in 12:
			await process_frame
			await physics_frame
		var snapshots: Array[Dictionary] = combat_system.debug_get_enemy_art_snapshots()
		_check(snapshots.size() == int(spawn_result.get("spawned_count", -1)), "Wave %d art snapshot count does not match spawned enemies" % wave_number)
		for entry in snapshots:
			_validate_enemy_entry(combat_system, entry)
			seen_enemy_types[str(entry.get("enemy_type_id", ""))] = true

	for enemy_type_id in EXPECTED_ENEMIES.keys():
		_check(seen_enemy_types.has(enemy_type_id), "Representative waves did not expose enemy type %s" % enemy_type_id)

	combat_system.debug_clear_enemies()
	await process_frame
	await process_frame
	_finish()


func _validate_enemy_entry(combat_system: Node, entry: Dictionary) -> void:
	var enemy_type_id := str(entry.get("enemy_type_id", ""))
	_check(EXPECTED_ENEMIES.has(enemy_type_id), "Unexpected enemy type in formal snapshot: %s" % enemy_type_id)
	if not EXPECTED_ENEMIES.has(enemy_type_id):
		return
	var expected: Dictionary = EXPECTED_ENEMIES[enemy_type_id]
	var expected_weapon := str(expected.get("weapon", ""))
	var mounted := bool(expected.get("mounted", false))
	var expected_family := "synty_mounted_chibi" if mounted else "synty_chibi"
	var art: Dictionary = entry.get("art", {}) if entry.get("art", {}) is Dictionary else {}

	_check(str(entry.get("weapon_type", "")) == expected_weapon, "%s fixed weapon does not match enemy_waves.json" % enemy_type_id)
	_check(str(entry.get("art_family", "")) == expected_family, "%s did not use the shared production chibi family" % enemy_type_id)
	_check(bool(art.get("ready", false)), "%s shared character wrapper is not ready" % enemy_type_id)
	_check(str(art.get("authority_main_weapon_id", "")) == expected_weapon, "%s did not receive its fixed weapon through apply_profile" % enemy_type_id)
	_check(not bool(art.get("debug_equipment_preview_active", true)), "%s production path leaked NPCDevLab debug equipment state" % enemy_type_id)
	_check(bool(art.get(str(WEAPON_VISIBILITY_KEYS.get(expected_weapon, "")), false)), "%s fixed weapon is not visible" % enemy_type_id)
	for weapon_id in WEAPON_VISIBILITY_KEYS.keys():
		if str(weapon_id) == expected_weapon:
			continue
		_check(not bool(art.get(str(WEAPON_VISIBILITY_KEYS[weapon_id]), false)), "%s displays an extra %s weapon" % [enemy_type_id, weapon_id])
	_check(bool(art.get("shield_visible", false)) == (expected_weapon == "sword_shield"), "%s shield visibility does not match its fixed weapon" % enemy_type_id)
	_check(bool(art.get("mounted_enemy_wrapper", false)) == mounted, "%s mounted wrapper state is wrong" % enemy_type_id)
	_check(bool(art.get("horse_visible", false)) == mounted, "%s horse visibility is wrong" % enemy_type_id)

	var enemy_paths: Dictionary = combat_system.get("_enemy_nodes")
	var enemy_id := str(entry.get("enemy_id", ""))
	var actor := combat_system.get_node_or_null(enemy_paths.get(enemy_id, NodePath("")))
	_check(actor != null, "%s formal actor is missing" % enemy_type_id)
	if actor == null:
		return
	var body_collision := actor.get_node_or_null("BodyCollision") as CollisionShape3D
	var legacy_mesh := actor.get_node_or_null("ActorMesh") as MeshInstance3D
	_check(body_collision != null and not body_collision.disabled, "%s gameplay collision was replaced by presentation" % enemy_type_id)
	_check(legacy_mesh != null and not legacy_mesh.visible, "%s legacy capsule mesh is still visible" % enemy_type_id)
	_check(actor.find_child("SelectionArea", true, false) == null, "%s presentation added duplicate selection authority" % enemy_type_id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0141_FORMAL_ENEMY_DEV_LAB_REUSE PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0141_FORMAL_ENEMY_DEV_LAB_REUSE FAIL count=%d" % _failures.size())
	quit(1)
