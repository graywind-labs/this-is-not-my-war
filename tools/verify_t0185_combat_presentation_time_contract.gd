extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "stableman_01"
const WEAPONS := ["sword_shield", "polearm", "bow", "crossbow"]
const RESOURCE_BY_WEAPON := {
	"sword_shield": "item_sword_shield",
	"polearm": "item_polearm",
	"bow": "item_bow",
	"crossbow": "item_crossbow",
}

var _failures: PackedStringArray = []
var _sequence := 1800


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(4):
		await process_frame
		await physics_frame

	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	_check(time_system != null and combat_system != null and npc_system != null and equipment_system != null and resource_system != null, "T0185 systems missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(false)
	time_system.set_time_scale(4.0)
	_check(is_equal_approx(float(time_system.get_game_delta_seconds(1.0)), 240.0), "T0185 out-of-combat x4 game clock changed")
	_check(is_equal_approx(float(time_system.get_combat_frame_delta_seconds(1.0)), 1.0), "T0185 combat frame bridge accelerated with out-of-combat x4")

	npc_system.set_npc_recruited(NPC_ID, true)
	for weapon_id in WEAPONS:
		resource_system.add_resource(str(RESOURCE_BY_WEAPON[weapon_id]), 3)
	var spawned: Dictionary = combat_system.debug_spawn_wave(1, true)
	_check(bool(spawned.get("ok", false)), "T0185 could not spawn combat fixture: %s" % spawned)
	_check(absf(float(time_system.get_effective_time_scale()) - (1.0 / 60.0)) <= 0.000001, "T0185 enemy presence did not establish 1:1 time")
	_check(is_equal_approx(float(time_system.get_game_delta_seconds(1.0)), 1.0), "T0185 game second is not real-time during combat")
	_check(is_equal_approx(float(time_system.get_combat_frame_delta_seconds(1.0)), 1.0), "T0185 combat frame bridge reapplied the raw 1/60 multiplier")

	for weapon_id in WEAPONS:
		_check(_equip_weapon(npc_system, equipment_system, weapon_id), "T0185 could not equip %s" % weapon_id)
		var context: Dictionary = combat_system._calculate_npc_attack_context(NPC_ID, npc_system.get_npc(NPC_ID), npc_system.get_npc_state(NPC_ID))
		var timing: Dictionary = context.get("animation_timing", {})
		for mounted in [false, true]:
			_sequence += 1
			npc_system.update_npc_state(NPC_ID, {
				"behavior_mode": "combat",
				"combat_mode": "combat",
				"combat_mounted": mounted,
				"current_action": "winding_up_t0185_target",
				"combat_attack_sequence": _sequence,
				"combat_attack_phase": "windup",
				"combat_attack_elapsed_seconds": float(timing.get("cycle_seconds", 1.0)) * 0.2,
				"combat_attack_cycle_seconds": float(timing.get("cycle_seconds", 1.0)),
				"combat_attack_impact_seconds": float(timing.get("impact_seconds", 0.0)),
				"combat_attack_playback_multiplier": float(timing.get("playback_multiplier", 1.0)),
				"combat_attack_impact_committed": false,
			})
			# NPCSystem publishes the authoritative state synchronously. Inspect it
			# before the live CombatSystem advances this synthetic fixture toward a
			# real target on the next frame.
			var art: Dictionary = npc_system.debug_get_npc_character_art_snapshot(NPC_ID)
			var expected_state := "mounted_attack" if mounted else "attack"
			var expected_speed := float(timing.get("playback_multiplier", 1.0))
			_check(str(art.get("current_state", "")) == expected_state, "T0185 %s %s did not enter attack animation" % [weapon_id, expected_state])
			_check(absf(float(art.get("combat_attack_animation_speed_scale", 0.0)) - expected_speed) <= 0.02, "T0185 %s %s animation did not use authored combat speed: expected=%.4f actual=%.4f" % [weapon_id, expected_state, expected_speed, float(art.get("combat_attack_animation_speed_scale", 0.0))])

	# Physical projectiles are advanced from physics real delta through the same
	# bridge. A one-second step must travel about ten metres, not 1/60 of that.
	combat_system._clear_combat_projectiles("t0185_fixture_reset")
	var projectile_id := "t0185_projectile"
	combat_system._active_projectiles[projectile_id] = {
		"id": projectile_id,
		"position": Vector3(0.0, 200.0, 0.0),
		"release_position": Vector3(0.0, 200.0, 0.0),
		"velocity": Vector3(10.0, 0.0, 0.0),
		"gravity": 0.01,
		"max_range": 1000.0,
		"max_lifetime": 10.0,
		"age": 0.0,
		"excluded_rids": [],
		"view": null,
	}
	combat_system._advance_combat_projectiles(1.0)
	var projectile: Dictionary = combat_system._active_projectiles.get(projectile_id, {})
	var moved_position: Vector3 = projectile.get("position", Vector3.ZERO)
	_check(moved_position.x >= 9.9, "T0185 projectile still uses raw 1/60 multiplier: %s" % moved_position)

	time_system.set_paused(true)
	_check(is_zero_approx(float(time_system.get_combat_frame_delta_seconds(1.0))), "T0185 paused combat frame delta is not zero")
	# `process_frame` is emitted before Node._process callbacks. Two emissions let
	# the pilot consume the pause on the intervening rendered frame.
	await process_frame
	await process_frame
	var paused_art: Dictionary = npc_system.debug_get_npc_character_art_snapshot(NPC_ID)
	_check(is_zero_approx(float(paused_art.get("combat_attack_animation_speed_scale", -1.0))), "T0185 paused attack animation did not freeze")
	combat_system._advance_combat_projectiles(1.0)
	var paused_position: Vector3 = (combat_system._active_projectiles.get(projectile_id, {}) as Dictionary).get("position", Vector3.ZERO)
	_check(paused_position.is_equal_approx(moved_position), "T0185 paused projectile moved: before=%s after=%s" % [moved_position, paused_position])

	time_system.set_paused(false)
	await process_frame
	await process_frame
	var resumed_art: Dictionary = npc_system.debug_get_npc_character_art_snapshot(NPC_ID)
	_check(float(resumed_art.get("combat_attack_animation_speed_scale", 0.0)) > 0.1, "T0185 attack animation did not resume")

	# The same pilot owns non-attack combat clips. Lock their explicit contract so
	# future time-system work cannot fix attacks while leaving hit/fall/revive on
	# a different clock.
	var npc_actor := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Stableman01")
	var pilot: Node = null
	if npc_actor != null:
		for candidate in npc_actor.find_children("*", "", true, false):
			if candidate.has_method("debug_force_animation_state") and candidate.has_method("debug_get_snapshot"):
				pilot = candidate
				break
	_check(pilot != null, "T0185 could not locate the production character pilot")
	if pilot != null:
		var response_states := ["hit_react", "unconscious", "get_up", "mounted_hit_react", "mounted_fall"]
		time_system.set_paused(true)
		await process_frame
		await process_frame
		for response_state in response_states:
			var paused_response: Dictionary = pilot.debug_force_animation_state(response_state)
			_check(bool(paused_response.get("ready", false)), "T0185 could not preview paused %s" % response_state)
			_check(is_zero_approx(float(paused_response.get("combat_attack_animation_speed_scale", -1.0))), "T0185 paused %s clip did not freeze" % response_state)
		time_system.set_paused(false)
		await process_frame
		await process_frame
		for response_state in response_states:
			var active_response: Dictionary = pilot.debug_force_animation_state(response_state)
			_check(bool(active_response.get("ready", false)), "T0185 could not preview active %s" % response_state)
			_check(float(active_response.get("combat_attack_animation_speed_scale", 0.0)) > 0.1, "T0185 active %s clip remained frozen" % response_state)

	combat_system._clear_combat_projectiles("t0185_complete")
	combat_system.clear_spawned_enemies()
	_check(is_equal_approx(float(time_system.get_combat_frame_delta_seconds(1.0)), 1.0), "T0185 post-combat frame cap did not remain authored x1")
	_finish()


func _equip_weapon(npc_system: Node, equipment_system: Node, weapon_id: String) -> bool:
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "verify_t0185_equip", {"request_plan_reevaluation": false})
	npc_system.stop_npc_movement_with_state(NPC_ID, {"current_action": "idle", "combat_mounted": false})
	var current: Dictionary = equipment_system.get_unit_type_snapshot(NPC_ID)
	if str(current.get("main_weapon_id", "")) == weapon_id:
		return true
	return bool(equipment_system.equip_npc_main_weapon(NPC_ID, weapon_id, "private").get("ok", false))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0185_COMBAT_PRESENTATION_TIME_CONTRACT_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
