extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(5):
		await process_frame
		await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var needs_system := root.get_node_or_null("Main/Systems/NPCNeedsSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(not [npc_system, needs_system, combat_system, time_system].has(null), "T0246 required systems missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(false)
	_check(needs_system.get_definition_errors().is_empty(), "T0246 needs config validation failed: %s" % [needs_system.get_definition_errors()])

	var actor := npc_system.get_node_or_null(npc_system._npc_nodes.get(NPC_ID, NodePath()))
	_check(actor != null, "T0246 NPC actor missing")
	if actor == null:
		_finish()
		return

	npc_system.update_npc_state(NPC_ID, {
		"satiety": 100,
		"behavior_mode": "combat",
		"combat_mounted": false,
		"unconscious": false,
		"escaped": false,
		"escape_intent": {}
	})
	_verify_actual_run_sampling(actor, npc_system, needs_system, combat_system)
	_verify_zero_satiety_walk_lock(actor, npc_system)

	combat_system._active_enemies.erase("t0246_enemy_presence_fixture")
	_finish()


func _verify_actual_run_sampling(actor: Node, npc_system: Node, needs_system: Node, combat_system: Node) -> void:
	var origin: Vector3 = actor.global_position
	actor._is_moving = true
	_simulate_actual_motion_sample(actor, 5.0, 1.0)
	var sampled: Dictionary = npc_system.get_npc_locomotion_needs_snapshot(NPC_ID)
	_check(is_equal_approx(float(sampled.get("pending_unmounted_actual_run_seconds", 0.0)), 1.0), "T0246 actual run frame was not sampled: %s" % sampled)
	needs_system._on_logical_time_tick(1.0, 1.0)
	_check(int(npc_system.get_npc_state(NPC_ID).get("satiety", -1)) == 100, "T0246 sprint drained without an enemy present")
	var no_enemy_sprint: Dictionary = needs_system.get_npc_needs_snapshot(NPC_ID).get("combat_sprint", {})
	_check(is_zero_approx(float(no_enemy_sprint.get("charged_game_seconds", -1.0))), "T0246 no-enemy run sample was charged: %s" % no_enemy_sprint)
	_check(is_equal_approx(float(no_enemy_sprint.get("discarded_sample_seconds", 0.0)), 1.0), "T0246 no-enemy sample was not discarded: %s" % no_enemy_sprint)

	combat_system._active_enemies["t0246_enemy_presence_fixture"] = {
		"id": "t0246_enemy_presence_fixture",
		"alive": true,
		"hp": 100,
		"max_hp": 100
	}
	for _second in range(10):
		_simulate_actual_motion_sample(actor, 5.0, 1.0)
	needs_system._on_logical_time_tick(10.0, 1.0)
	_check(int(npc_system.get_npc_state(NPC_ID).get("satiety", -1)) == 99, "T0246 ten run seconds did not consume exactly one satiety")
	var sprint: Dictionary = needs_system.get_npc_needs_snapshot(NPC_ID).get("combat_sprint", {})
	_check(is_equal_approx(float(sprint.get("charged_game_seconds", 0.0)), 10.0), "T0246 charged game seconds mismatch: %s" % sprint)
	_check(int(sprint.get("applied_satiety_delta", 0)) == -1, "T0246 sprint delta mismatch: %s" % sprint)

	var satiety_before_idle := int(npc_system.get_npc_state(NPC_ID).get("satiety", -1))
	_simulate_actual_motion_sample(actor, 0.0, 10.0)
	needs_system._on_logical_time_tick(10.0, 1.0)
	_check(int(npc_system.get_npc_state(NPC_ID).get("satiety", -1)) == satiety_before_idle, "T0246 blocked/idle sample consumed sprint satiety")

	npc_system.update_npc_state(NPC_ID, {"behavior_mode": "work"})
	_simulate_actual_motion_sample(actor, 3.2, 1.0)
	var walking_sample: Dictionary = npc_system.get_npc_locomotion_needs_snapshot(NPC_ID)
	_check(is_zero_approx(float(walking_sample.get("pending_unmounted_actual_run_seconds", -1.0))), "T0246 walking was counted as running: %s" % walking_sample)

	npc_system.update_npc_state(NPC_ID, {"behavior_mode": "combat", "combat_mounted": true})
	_simulate_actual_motion_sample(actor, 5.0, 1.0)
	var mounted_sample: Dictionary = npc_system.get_npc_locomotion_needs_snapshot(NPC_ID)
	_check(is_zero_approx(float(mounted_sample.get("pending_unmounted_actual_run_seconds", -1.0))), "T0246 mounted movement was charged to rider: %s" % mounted_sample)

	actor._is_moving = false
	actor.global_position = origin
	actor.velocity = Vector3.ZERO
	npc_system.update_npc_state(NPC_ID, {"behavior_mode": "combat", "combat_mounted": false})


func _verify_zero_satiety_walk_lock(actor: Node, npc_system: Node) -> void:
	for behavior_mode in ["rally", "combat", "avoid_combat", "escaped"]:
		npc_system.update_npc_state(NPC_ID, {
			"satiety": 0,
			"behavior_mode": behavior_mode,
			"combat_mounted": false,
			"escaped": false,
			"escape_intent": {}
		})
		var snapshot: Dictionary = actor.get_locomotion_needs_snapshot()
		_check(bool(snapshot.get("zero_satiety_walk_limited", false)), "T0246 zero-satiety lock missing for %s: %s" % [behavior_mode, snapshot])
		_check(str(snapshot.get("locomotion_state", "")) == "walk", "T0246 zero-satiety animation state was not walk for %s: %s" % [behavior_mode, snapshot])
		_check(float(snapshot.get("authoritative_move_speed", INF)) <= float(snapshot.get("walk_speed", 0.0)) + 0.001, "T0246 %s speed exceeded walking cap: %s" % [behavior_mode, snapshot])

	npc_system.update_npc_state(NPC_ID, {
		"satiety": 0,
		"behavior_mode": "combat",
		"combat_mounted": false,
		"escape_intent": {"active": true, "status": "escaping", "speed_multiplier": 3.0}
	})
	var escape_snapshot: Dictionary = actor.get_locomotion_needs_snapshot()
	_check(float(escape_snapshot.get("authoritative_move_speed", INF)) <= float(escape_snapshot.get("walk_speed", 0.0)) + 0.001, "T0246 escape multiplier bypassed zero-satiety walking cap: %s" % escape_snapshot)

	npc_system.update_npc_state(NPC_ID, {
		"satiety": 1,
		"behavior_mode": "combat",
		"combat_mounted": false,
		"escape_intent": {}
	})
	var restored: Dictionary = actor.get_locomotion_needs_snapshot()
	_check(not bool(restored.get("zero_satiety_walk_limited", true)), "T0246 positive satiety did not release walking cap: %s" % restored)
	_check(str(restored.get("locomotion_state", "")) == "run", "T0246 positive satiety did not restore run state: %s" % restored)
	_check(float(restored.get("authoritative_move_speed", 0.0)) > float(restored.get("walk_speed", INF)), "T0246 positive satiety did not restore run speed: %s" % restored)

	npc_system.update_npc_state(NPC_ID, {"satiety": 0, "combat_mounted": true})
	var mounted: Dictionary = actor.get_locomotion_needs_snapshot()
	_check(not bool(mounted.get("zero_satiety_walk_limited", true)), "T0246 rider satiety incorrectly capped horse movement: %s" % mounted)


func _simulate_actual_motion_sample(actor: Node, horizontal_speed: float, seconds: float) -> void:
	var position_before: Vector3 = actor.global_position
	actor.global_position += Vector3(maxf(0.0, horizontal_speed) * seconds, 0.0, 0.0)
	actor._update_actual_movement_presentation(position_before, seconds)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0246 combat sprint satiety verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
