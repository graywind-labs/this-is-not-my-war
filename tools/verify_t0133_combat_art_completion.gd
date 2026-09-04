extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const ENEMY_SCENE := preload("res://scenes/characters/EnemySwordShieldChibiPilot.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	for _index in 5:
		await process_frame
	var controller := main.get_node_or_null("Presentation/CombatVFXController")
	var combat_system := main.get_node_or_null("Systems/CombatSystem")
	_check(combat_system != null, "CombatSystem is missing from Main")
	if combat_system != null:
		_check(
			is_equal_approx(float(combat_system.ENEMY_CORPSE_LINGER_SECONDS), 8.0),
			"enemy corpse linger duration is not 8 seconds"
		)
	_check(controller != null, "CombatVFXController is missing from Main")
	if controller != null:
		controller.debug_clear_effects()
		controller.debug_handle_event({"event_type": "attack_swing", "world_position": Vector3.ZERO})
		controller.debug_handle_event({"event_type": "projectile_hit", "world_position": Vector3.ZERO})
		controller.debug_handle_event({"event_type": "actor_damaged", "world_position": Vector3.ZERO})
		controller.debug_handle_event({"event_type": "structure_damaged", "world_position": Vector3.ZERO, "target_type": "building"})
		var vfx_snapshot: Dictionary = controller.get_debug_snapshot()
		_check(bool(vfx_snapshot.get("initialized", false)), "VFX controller did not initialize")
		_check(str(vfx_snapshot.get("schema_version", "")) == "combat_vfx_v1", "VFX schema mismatch")
		_check(int((vfx_snapshot.get("spawn_counts", {}) as Dictionary).get("trail", 0)) >= 1, "attack trail was not spawned")
		_check(int((vfx_snapshot.get("spawn_counts", {}) as Dictionary).get("impact", 0)) >= 2, "impact flashes were not spawned")
		_check(int((vfx_snapshot.get("spawn_counts", {}) as Dictionary).get("blood_decal", 0)) >= 1, "blood decal was not spawned")
		_check(int(vfx_snapshot.get("active_transients", 0)) <= 28, "transient VFX active budget was exceeded")

		var settings := root.get_node_or_null("ClientSettings")
		if settings != null:
			var original: Dictionary = settings.get_snapshot()
			var disabled := original.duplicate(true)
			disabled["blood_enabled"] = false
			settings.apply_settings(disabled, false)
			await process_frame
			controller.debug_handle_event({"event_type": "actor_damaged", "world_position": Vector3.ONE})
			var disabled_snapshot: Dictionary = controller.get_debug_snapshot()
			_check(not bool(disabled_snapshot.get("blood_enabled", true)), "blood setting did not reach VFX controller")
			_check(int(disabled_snapshot.get("active_blood_decals", -1)) == 0, "blood decals remained visible after disabling blood")
			settings.apply_settings(original, false)

	main.queue_free()
	await process_frame
	await _verify_ragdoll_budget_and_recovery()
	if _failures.is_empty():
		print("T0133_COMBAT_ART PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("T0133_COMBAT_ART FAIL count=%d" % _failures.size())
		quit(1)


func _verify_ragdoll_budget_and_recovery() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var pilots: Array[Node] = []
	for index in 7:
		var enemy := ENEMY_SCENE.instantiate()
		enemy.position = Vector3(float(index) * 1.5, 0.0, 0.0)
		stage.add_child(enemy)
		pilots.append(enemy)
	await process_frame
	await process_frame
	for pilot in pilots:
		pilot.call("_start_ragdoll")
	_check(get_nodes_in_group("combat_ragdoll_active").size() == 6, "ragdoll active budget is not capped at six")
	var first_snapshot: Dictionary = pilots[0].call("debug_get_snapshot")
	var last_snapshot: Dictionary = pilots[6].call("debug_get_snapshot")
	_check(int(first_snapshot.get("ragdoll_bone_count", 0)) == 12, "runtime physical bone chain was not built")
	_check(int(last_snapshot.get("ragdoll_budget_skip_count", 0)) == 1, "seventh ragdoll did not use animated budget fallback")
	for _index in 120:
		await process_frame
	var frozen_snapshot: Dictionary = pilots[0].call("debug_get_snapshot")
	_check(bool(frozen_snapshot.get("ragdoll_frozen", false)), "ragdoll pose did not freeze after settling")
	_check(not bool(frozen_snapshot.get("ragdoll_active", true)), "settled ragdoll kept physics simulation active")
	pilots[0].call("_begin_ragdoll_recovery")
	for _index in 30:
		await process_frame
	var recovered_snapshot: Dictionary = pilots[0].call("debug_get_snapshot")
	_check(not bool(recovered_snapshot.get("ragdoll_recovering", true)), "ragdoll pose did not blend back to animation")
	stage.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
