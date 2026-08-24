extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var hud := root.get_node_or_null("Main/UI/HUD")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var piety_system := root.get_node_or_null("Main/Systems/PietySystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if (
		action_system == null
		or building_system == null
		or combat_system == null
		or daily_plan_system == null
		or device_system == null
		or hud == null
		or memory_system == null
		or npc_system == null
		or piety_system == null
		or resource_system == null
		or time_system == null
	):
		_fail("Piety/meteor verification requires all main gameplay systems")
		return

	var piety_snapshot: Dictionary = piety_system.get_piety_snapshot()
	if (
		not is_equal_approx(float(piety_snapshot.get("max_piety", 0.0)), 100.0)
		or not is_equal_approx(float(piety_snapshot.get("piety_per_prayer_hour", 0.0)), 3.0)
	):
		_fail("Piety tuning must be 100 maximum and 3 piety per active prayer-hour")
		return
	var meteor_config: Dictionary = piety_system.get_meteor_config()
	if (
		not is_equal_approx(float(meteor_config.get("radius", 0.0)), 5.5)
		or not is_equal_approx(float(meteor_config.get("impact_damage", 0.0)), 48.0)
		or int(meteor_config.get("impact_max_targets", 0)) != 12
		or not is_equal_approx(float(meteor_config.get("burn_duration_seconds", 0.0)), 10.0)
		or not is_equal_approx(float(meteor_config.get("burn_damage", 0.0)), 1.0)
	):
		_fail("Meteor radius, 12-target impact cap, damage, or burn tuning contract regressed")
		return

	daily_plan_system.set_auto_execution_enabled(false)
	time_system.set_paused(false)
	for npc_id in ["priest_01", "gardener_01"]:
		action_system.interrupt_npc_action(npc_id, "piety_test_setup", true)
		if not npc_system.debug_enter_location_immediately(npc_id, "chapel"):
			_fail("Could not place %s in the chapel" % npc_id)
			return
		if not action_system.debug_assign_action(npc_id, "pray_at_chapel"):
			_fail("Could not assign chapel prayer to %s" % npc_id)
			return
		if not await _wait_for_active(action_system, time_system, npc_id, "pray_at_chapel"):
			_fail("%s did not physically reach a chapel prayer seat" % npc_id)
			return

	time_system.set_paused(true)
	piety_system.debug_set_piety(0.0)
	var generated_before_tick: Dictionary = piety_system.get_piety_snapshot().get("generated_by_npc", {})
	action_system._on_logical_time_tick(600.0, 1.0)
	if not is_zero_approx(float(piety_system.get_current_piety())):
		_fail("Paused prayer incorrectly generated piety")
		return
	time_system.set_paused(false)
	action_system._on_logical_time_tick(600.0, 1.0)
	if not is_equal_approx(float(piety_system.get_current_piety()), 1.0):
		_fail("Two simultaneous ten-minute prayers should generate exactly 1 shared piety")
		return
	var generated_by_npc: Dictionary = piety_system.get_piety_snapshot().get("generated_by_npc", {})
	if (
		not is_equal_approx(float(generated_by_npc.get("priest_01", 0.0)) - float(generated_before_tick.get("priest_01", 0.0)), 0.5)
		or not is_equal_approx(float(generated_by_npc.get("gardener_01", 0.0)) - float(generated_before_tick.get("gardener_01", 0.0)), 0.5)
	):
		_fail("Shared piety did not preserve per-NPC generation diagnostics")
		return

	var ability_button := hud.find_child("PietyAbilityButton", true, false)
	if ability_button == null:
		_fail("HUD piety charge button is missing")
		return
	var piety_glyph := ability_button.find_child("PietyGlyph", true, false) as Label
	if piety_glyph == null or piety_glyph.text != "虔":
		_fail("HUD piety charge glyph must display 虔")
		return
	if "NPC 在小教堂" in str(ability_button.tooltip_text):
		_fail("HUD piety charge tooltip should not include the prayer accumulation explanation")
		return
	piety_system.debug_fill_piety()
	await process_frame
	if not bool(ability_button.is_ready_to_cast()):
		_fail("HUD piety circle did not enter its ready state")
		return
	hud._begin_meteor_targeting()
	if not bool(hud.get("_meteor_targeting_active")):
		_fail("Ready HUD button could not enter ground-targeting mode")
		return
	hud._end_meteor_targeting()
	if (
		bool(hud.get("_meteor_targeting_active"))
		or not is_equal_approx(float(piety_system.get_current_piety()), 100.0)
	):
		_fail("Cancelling meteor targeting should preserve full piety")
		return

	var deployment_result := _deploy_friendly_device(resource_system, device_system)
	if not bool(deployment_result.get("ok", false)):
		_fail("Could not deploy a friendly device for no-friendly-fire verification: %s" % str(deployment_result))
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)) or combat_system.get_active_enemy_count() < 3:
		_fail("Could not spawn enough enemies for meteor verification")
		return
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_place_enemy(combat_system, enemy_ids[0], Vector3(0.0, 0.0, 0.0), 60)
	_place_enemy(combat_system, enemy_ids[1], Vector3(3.0, 0.0, 0.0), 40)
	_place_enemy(combat_system, enemy_ids[2], Vector3(8.0, 0.0, 0.0), 60)
	for index in range(3, enemy_ids.size()):
		_place_enemy(
			combat_system,
			enemy_ids[index],
			Vector3(18.0 + float(index), 0.0, 18.0),
			60
		)

	var friendly_before := _friendly_hp_snapshot(
		npc_system,
		building_system,
		device_system
	)
	var outside_hp_before := int(combat_system.get_enemy(enemy_ids[2]).get("hp", 0))
	var cast_result: Dictionary = piety_system.request_meteor_cast(Vector3.ZERO)
	if not bool(cast_result.get("ok", false)):
		_fail("Full piety meteor cast failed: %s" % str(cast_result))
		return
	if not is_zero_approx(float(piety_system.get_current_piety())):
		_fail("Successful meteor cast did not spend the full piety charge")
		return
	if piety_system.request_meteor_cast(Vector3.ZERO).get("error", "") != "piety_not_full":
		_fail("Meteor could be cast again without recharging")
		return

	piety_system.debug_advance_effects(120.0)
	if combat_system.get_enemy(enemy_ids[0]).is_empty():
		_fail("The 60 HP inner enemy should survive the 48 damage impact")
		return
	if not combat_system.get_enemy(enemy_ids[1]).is_empty():
		_fail("The 40 HP inner enemy should be defeated by the impact")
		return
	if int(combat_system.get_enemy(enemy_ids[2]).get("hp", 0)) != outside_hp_before:
		_fail("Enemy outside the 5.5 radius was damaged by the meteor impact")
		return
	if _friendly_hp_snapshot(npc_system, building_system, device_system) != friendly_before:
		_fail("Meteor impact damaged an NPC, building, or friendly defense device")
		return

	var outside_state: Dictionary = combat_system.get("_active_enemies").get(enemy_ids[2], {})
	outside_state["position"] = Vector3.ZERO
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	active_enemies[enemy_ids[2]] = outside_state
	combat_system.set("_active_enemies", active_enemies)
	combat_system._refresh_enemy_node(enemy_ids[2])
	var burn_hp_before := int(combat_system.get_enemy(enemy_ids[2]).get("hp", 0))
	piety_system.debug_advance_effects(60.0)
	if int(combat_system.get_enemy(enemy_ids[2]).get("hp", 0)) != burn_hp_before - 1:
		_fail("Persistent burning ground did not deal its configured 1 damage tick")
		return
	if _friendly_hp_snapshot(npc_system, building_system, device_system) != friendly_before:
		_fail("Burning ground damaged an NPC, building, or friendly defense device")
		return

	_place_enemy(combat_system, enemy_ids[2], Vector3(8.0, 0.0, 0.0), burn_hp_before - 1)
	var escaped_burn_hp := int(combat_system.get_enemy(enemy_ids[2]).get("hp", 0))
	piety_system.debug_advance_effects(60.0)
	if int(combat_system.get_enemy(enemy_ids[2]).get("hp", 0)) != escaped_burn_hp:
		_fail("Burning ground damaged an enemy after it left the radius")
		return

	var impact_event := _find_latest_event(memory_system.get_all_events(), "piety_meteor_impact")
	if (
		impact_event.is_empty()
		or bool(impact_event.get("payload", {}).get("friendly_fire", true))
		or int(impact_event.get("payload", {}).get("impact_max_targets", 0)) != 12
		or not str(impact_event.get("summary", "")).contains("没有伤及友方")
	):
		_fail("Meteor impact event does not preserve the no-friendly-fire rule")
		return

	combat_system.clear_spawned_enemies()
	spawn_result = combat_system.debug_spawn_wave(4, true)
	if not bool(spawn_result.get("ok", false)) or combat_system.get_active_enemy_count() < 13:
		_fail("Could not spawn enough enemies for meteor impact-cap verification")
		return
	enemy_ids = combat_system.get_active_enemy_ids()
	for index in range(enemy_ids.size()):
		var offset := Vector3(float(index % 6) * 0.25, 0.0, float(index / 6) * 0.25)
		_place_enemy(combat_system, enemy_ids[index], offset, 100)
	piety_system.debug_fill_piety()
	cast_result = piety_system.request_meteor_cast(Vector3.ZERO)
	if not bool(cast_result.get("ok", false)):
		_fail("Meteor cast failed during 12-target cap verification")
		return
	piety_system.debug_advance_effects(120.0)
	var capped_impact: Dictionary = piety_system.get_piety_snapshot().get("last_impact_result", {})
	var capped_damage: Dictionary = capped_impact.get("damage_result", {})
	if (
		int(capped_impact.get("hit_count", 0)) != 12
		or int(capped_damage.get("max_targets", 0)) != 12
		or int(capped_damage.get("eligible_target_count", 0)) <= 12
	):
		_fail("Meteor impact did not stop at the nearest 12 eligible enemies: %s" % JSON.stringify(capped_impact))
		return

	combat_system.clear_spawned_enemies()
	spawn_result = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		_fail("Could not respawn enemies for all-clear verification")
		return
	enemy_ids = combat_system.get_active_enemy_ids()
	var final_enemy_id := enemy_ids[0]
	for index in range(1, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])
	_place_enemy(combat_system, final_enemy_id, Vector3(0.0, 0.0, 0.0), 20)
	piety_system.debug_fill_piety()
	cast_result = piety_system.request_meteor_cast(Vector3.ZERO)
	if not bool(cast_result.get("ok", false)):
		_fail("Second meteor cast failed during all-clear verification")
		return
	piety_system.debug_advance_effects(120.0)
	var last_area_result: Dictionary = combat_system.debug_get_combat_snapshot().get("last_area_damage_result", {})
	if (
		combat_system.get_active_enemy_count() != 0
		or (last_area_result.get("mode_exit_result", {}) as Dictionary).is_empty()
	):
		_fail("Meteor killing the last enemy did not execute normal battle-clear settlement")
		return
	if _friendly_hp_snapshot(npc_system, building_system, device_system) != friendly_before:
		_fail("Second meteor damaged friendly targets")
		return

	print("T0114 piety meteor ability and no-friendly-fire verification passed.")
	quit(0)


func _deploy_friendly_device(resource_system: Node, device_system: Node) -> Dictionary:
	resource_system.add_resource("item_wall_ballista", 1)
	for raw_slot in device_system.get_slots_for_device("wall_ballista", true):
		var slot: Dictionary = raw_slot if raw_slot is Dictionary else {}
		var result: Dictionary = device_system.deploy_device(
			"wall_ballista",
			str(slot.get("id", ""))
		)
		if bool(result.get("ok", false)):
			return result
	return {}


func _place_enemy(
	combat_system: Node,
	enemy_id: String,
	position: Vector3,
	hp: int
) -> void:
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	var enemy: Dictionary = active_enemies.get(enemy_id, {})
	enemy["position"] = position
	enemy["hp"] = hp
	enemy["max_hp"] = maxi(hp, int(enemy.get("max_hp", hp)))
	enemy["defense"] = 0.0
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)
	combat_system._refresh_enemy_node(enemy_id)


func _friendly_hp_snapshot(
	npc_system: Node,
	building_system: Node,
	device_system: Node
) -> Dictionary:
	var npc_hp := {}
	for npc_id in npc_system.get_npc_ids():
		npc_hp[str(npc_id)] = int(npc_system.get_npc_state(str(npc_id)).get("hp", 0))
	var building_hp := {}
	for building_id in building_system.get_building_ids():
		building_hp[str(building_id)] = int(building_system.get_building(str(building_id)).get("hp", 0))
	var device_hp := {}
	for raw_deployment in device_system.get_deployments():
		var deployment: Dictionary = raw_deployment if raw_deployment is Dictionary else {}
		device_hp[str(deployment.get("deployment_id", ""))] = int(deployment.get("hp", 0))
	return {
		"npcs": npc_hp,
		"buildings": building_hp,
		"devices": device_hp
	}


func _find_latest_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Variant = events[index]
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}


func _wait_for_active(action_system: Node, time_system: Node, npc_id: String, action_id: String, max_frames: int = 1800) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == action_id:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
