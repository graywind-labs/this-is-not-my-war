extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

const EXPECTED_ASSETS := [
	"sfx_combat_sword_swing",
	"sfx_combat_polearm_swing",
	"sfx_combat_bow_release",
	"sfx_combat_hand_crossbow_release",
	"sfx_arrow_tower_release",
	"sfx_combat_ballista_release",
	"sfx_combat_arrow_and_hand_crossbow_bolt_whoosh",
	"sfx_combat_ballista_bolt_whoosh",
	"sfx_combat_arrow_bolt_tower_impact",
	"sfx_ballista_heavy_bolt_impact",
	"sfx_combat_hit_contact_01",
	"sfx_combat_hit_contact_02",
	"sfx_combat_hit_contact_03",
	"voice_combat_friendly_male_hurt_voice",
	"voice_combat_friendly_female_hurt_voice",
	"voice_combat_enemy_hurt_voice",
	"sfx_combat_unconscious_fall",
	"sfx_combat_horse_death",
	"sfx_combat_stone_structure_damage",
	"sfx_combat_wood_damage_01",
	"sfx_combat_wood_damage_02",
	"sfx_wood_structure_severe_collapse",
	"sfx_stone_structure_severe_collapse",
	"sfx_enemy_entry_stinger",
	"sfx_wave_clear_stinger",
	"sfx_final_victory_stinger",
	"sfx_defeat_stinger",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var controller := main.get_node("Presentation/CombatAudioController")
	var movement_controller := main.get_node("Presentation/MovementAudioController")
	var audio_manager := root.get_node("AudioManager")
	var npc_system := main.get_node("Systems/NPCSystem")
	var building_system := main.get_node("Systems/BuildingSystem")
	var horse_system := main.get_node("Systems/HorseSystem")
	var snapshot: Dictionary = controller.get_debug_snapshot()
	_assert(bool(snapshot.get("initialized", false)), "combat audio controller did not initialize")
	_assert(str(snapshot.get("schema_version", "")) == "combat_audio_v1", "wrong combat audio schema")
	_assert((snapshot.get("connected_signals", []) as Array).has("combat_audio_event"), "combat audio signal is not connected")
	_assert((snapshot.get("connected_signals", []) as Array).has("game_over_changed"), "game-over signal is not connected")
	_assert_all_assets_exist(audio_manager)
	_assert_silent_rules(snapshot)
	_assert(is_equal_approx(float((controller.get("_config") as Dictionary).get("hurt_voice_probability", -1.0)), 0.5), "hurt voice probability is not 50%")

	_assert_mapping(controller, {"event_type": "attack_swing", "weapon_type": "sword_shield"}, ["sfx_combat_sword_swing"])
	_assert_mapping(controller, {"event_type": "attack_swing", "weapon_type": "polearm"}, ["sfx_combat_polearm_swing"])
	_assert_mapping(controller, {"event_type": "projectile_released", "weapon_type": "bow"}, [
		"sfx_combat_bow_release", "sfx_combat_arrow_and_hand_crossbow_bolt_whoosh",
	])
	_assert_mapping(controller, {"event_type": "projectile_released", "weapon_type": "crossbow"}, [
		"sfx_combat_hand_crossbow_release", "sfx_combat_arrow_and_hand_crossbow_bolt_whoosh",
	])
	_assert_mapping(controller, {"event_type": "projectile_released", "device_id": "wall_arrow_tower"}, [
		"sfx_arrow_tower_release", "sfx_combat_arrow_and_hand_crossbow_bolt_whoosh",
	])
	_assert_mapping(controller, {"event_type": "projectile_released", "device_id": "wall_ballista"}, [
		"sfx_combat_ballista_release", "sfx_combat_ballista_bolt_whoosh",
	])
	_assert_mapping(controller, {"event_type": "projectile_hit", "device_id": "wall_arrow_tower"}, ["sfx_combat_arrow_bolt_tower_impact"])
	_assert_mapping(controller, {"event_type": "projectile_hit", "device_id": "wall_ballista"}, ["sfx_ballista_heavy_bolt_impact"])

	var config: Dictionary = controller.get("_config")
	config["hurt_voice_probability"] = 1.0
	controller.set("_config", config)
	_assert_damage_mapping(controller, "npc", "stableman_01", "voice_combat_friendly_male_hurt_voice", false)
	_assert_damage_mapping(controller, "npc", "doctor_01", "voice_combat_friendly_female_hurt_voice", true)
	_assert_damage_mapping(controller, "enemy", "enemy_audio_probe", "voice_combat_enemy_hurt_voice", false)
	_assert_mapping(controller, {"event_type": "horse_died", "target_type": "horse", "target_id": "horse_probe"}, ["sfx_combat_horse_death"])
	_assert_mapping(controller, {"event_type": "structure_damaged", "target_type": "building", "target_id": "warehouse"}, [], "sfx_combat_wood_damage_")
	_assert_mapping(controller, {"event_type": "structure_damaged", "target_type": "building", "target_id": "warehouse", "destroyed": true}, ["sfx_wood_structure_severe_collapse"], "sfx_combat_wood_damage_")
	_assert_mapping(controller, {"event_type": "structure_damaged", "target_type": "building", "target_id": "main_hall"}, ["sfx_combat_stone_structure_damage"])
	_assert_mapping(controller, {"event_type": "structure_damaged", "target_type": "building", "target_id": "chapel", "destroyed": true}, [
		"sfx_combat_stone_structure_damage", "sfx_stone_structure_severe_collapse",
	])
	_assert_mapping(controller, {"event_type": "structure_damaged", "target_type": "defense_device", "target_id": "device_probe"}, [], "sfx_combat_wood_damage_")
	_assert_mapping(controller, {"event_type": "battle_started"}, ["sfx_enemy_entry_stinger"])
	_assert_mapping(controller, {"event_type": "wave_cleared"}, ["sfx_wave_clear_stinger"])
	controller.debug_reset_history()
	controller.call("_on_game_over_changed", "victory", "audio_test")
	_assert_history_contains(controller, "sfx_final_victory_stinger")
	controller.debug_reset_history()
	controller.call("_on_game_over_changed", "failure", "audio_test")
	_assert_history_contains(controller, "sfx_defeat_stinger")

	# Authoritative system hooks: no positive HP delta means no presentation event.
	config["hurt_voice_probability"] = 0.0
	controller.set("_config", config)
	controller.debug_reset_history()
	var npc_damage: Dictionary = npc_system.apply_damage_to_npc("stableman_01", 1, "veteran_deputy_01")
	_assert(int(npc_damage.get("hp_after", -1)) < int(npc_damage.get("hp_before", -1)), "NPC damage did not commit")
	_assert_history_prefix(controller, "sfx_combat_hit_contact_")

	controller.debug_reset_history()
	var building_damage: Dictionary = building_system.apply_damage_to_building("warehouse", 1, "audio_test")
	_assert(bool(building_damage.get("ok", false)), "building damage did not commit")
	_assert_history_prefix(controller, "sfx_combat_wood_damage_")

	var horse_ids: Array[String] = horse_system.get_horse_ids()
	_assert(not horse_ids.is_empty(), "no horse is available for combat audio verification")
	if not horse_ids.is_empty():
		var horse_id := horse_ids[0]
		var horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
		var horse_hp := float(horse.get("hp", 1.0))
		controller.debug_reset_history()
		var graze: Dictionary = horse_system.apply_damage_to_horse(horse_id, minf(1.0, maxf(0.5, horse_hp * 0.25)), {"actor_id": "audio_test"})
		_assert(bool(graze.get("ok", false)), "ordinary horse damage did not commit")
		_assert(int(controller.get_debug_snapshot().get("recent_play_count", -1)) == 0, "ordinary horse damage incorrectly played audio")
		controller.debug_reset_history()
		var death: Dictionary = horse_system.apply_damage_to_horse(horse_id, horse_hp + 100.0, {"actor_id": "audio_test"})
		_assert(bool(death.get("died", false)), "horse death did not commit")
		_assert_history_contains(controller, "sfx_combat_horse_death")

	_assert_frame_budget(controller)
	_assert(movement_controller.debug_is_enemy_running({"movement_active": true, "actual_horizontal_speed": 0.1}), "moving enemy was not classified as running")
	_assert(not movement_controller.debug_is_enemy_running({"movement_active": true, "actual_horizontal_speed": 0.0}), "stationary enemy was classified as running")
	_assert(not movement_controller.debug_is_enemy_running({"movement_active": false, "actual_horizontal_speed": 5.0}), "inactive enemy was classified as running")
	_assert_enemy_loop_limit(main, movement_controller)

	audio_manager.stop_all_one_shots()
	main.queue_free()
	await process_frame
	await process_frame
	print("T0135_P10E_COMBAT_AUDIO_PASS assets=27 mapping=pass authority=pass positional=pass frame_budget=pass")
	quit(0)


func _assert_all_assets_exist(audio_manager: Node) -> void:
	_assert(EXPECTED_ASSETS.size() == 27, "expected combat asset inventory changed")
	for asset_id in EXPECTED_ASSETS:
		_assert(audio_manager.has_asset(asset_id), "missing combat audio asset: %s" % asset_id)


func _assert_silent_rules(snapshot: Dictionary) -> void:
	var silent_rules: Array = snapshot.get("silent_rules", [])
	for rule in ["shield_block_no_authority", "npc_revive", "horse_regular_damage"]:
		_assert(silent_rules.has(rule), "missing silent combat rule: %s" % rule)


func _assert_mapping(controller: Node, raw_event: Dictionary, expected_assets: Array, expected_prefix := "") -> void:
	var event := raw_event.duplicate(true)
	event["world_position"] = Vector3(4.0, 0.0, 7.0)
	controller.debug_reset_history()
	controller.debug_handle_audio_event(event)
	for asset_id in expected_assets:
		_assert_history_contains(controller, str(asset_id))
	if not expected_prefix.is_empty():
		_assert_history_prefix(controller, expected_prefix)
	_assert_history_is_positional(controller)


func _assert_damage_mapping(controller: Node, target_type: String, target_id: String, voice_asset: String, unconscious: bool) -> void:
	controller.debug_set_rng_seed(1305)
	controller.debug_reset_history()
	controller.debug_handle_audio_event({
		"event_type": "actor_damaged",
		"target_type": target_type,
		"target_id": target_id,
		"became_unconscious": unconscious,
		"world_position": Vector3(8.0, 0.0, 9.0),
	})
	_assert_history_prefix(controller, "sfx_combat_hit_contact_")
	_assert_history_contains(controller, voice_asset)
	if unconscious:
		_assert_history_contains(controller, "sfx_combat_unconscious_fall")
	_assert_history_is_positional(controller)


func _assert_frame_budget(controller: Node) -> void:
	var config: Dictionary = controller.get("_config")
	config["hurt_voice_probability"] = 0.0
	controller.set("_config", config)
	controller.debug_reset_history()
	for index in range(20):
		controller.debug_handle_audio_event({
			"event_type": "actor_damaged",
			"target_type": "enemy",
			"target_id": "budget_%d" % index,
			"world_position": Vector3(float(index), 0.0, 0.0),
		})
	var snapshot: Dictionary = controller.get_debug_snapshot()
	_assert(int(snapshot.get("recent_play_count", 0)) <= 8, "impact frame budget was exceeded")
	var skipped: Array = snapshot.get("skipped_events", [])
	var saw_frame_budget := false
	for entry in skipped:
		if entry is Dictionary and str((entry as Dictionary).get("reason", "")) == "frame_budget":
			saw_frame_budget = true
			break
	_assert(saw_frame_budget, "same-frame combat burst was not throttled")


func _assert_enemy_loop_limit(main: Node, movement_controller: Node) -> void:
	var combat_system := main.get_node("Systems/CombatSystem")
	var camera := main.get_node("CameraRig/Camera3D") as Camera3D
	var enemies: Dictionary = combat_system.get("_active_enemies")
	var slices: Dictionary = combat_system.get("_formal_first_wave_slices")
	for index in range(8):
		var enemy_id := "audio_enemy_%d" % index
		enemies[enemy_id] = {
			"id": enemy_id,
			"alive": true,
			"unit_type": "cavalry" if index == 0 else "infantry",
			"position": Vector3(camera.global_position.x + float(index), 0.0, camera.global_position.z),
		}
		slices[enemy_id] = {
			"presentation_movement_active": true,
			"presentation_planar_speed": 3.0,
		}
	combat_system.set("_active_enemies", enemies)
	combat_system.set("_formal_first_wave_slices", slices)
	movement_controller.debug_force_refresh()
	var loops: Dictionary = movement_controller.get_debug_snapshot().get("active_loops", {})
	var enemy_loop_count := 0
	for raw_key in loops.keys():
		if str(raw_key).begins_with("enemy:") or str(raw_key).begins_with("mounted_enemy:"):
			enemy_loop_count += 1
	_assert(enemy_loop_count == 6, "enemy movement loop cap is not six")
	_assert(loops.has("mounted_enemy:audio_enemy_0"), "nearest mounted enemy did not use horse audio")
	_assert(not loops.has("enemy:audio_enemy_7"), "far enemy survived nearest-six limit")
	enemies.clear()
	slices.clear()
	combat_system.set("_active_enemies", enemies)
	combat_system.set("_formal_first_wave_slices", slices)
	movement_controller.debug_force_refresh()


func _assert_history_contains(controller: Node, asset_id: String) -> void:
	var history: Array = controller.get_debug_snapshot().get("recent_history", [])
	for entry in history:
		if entry is Dictionary and str((entry as Dictionary).get("asset_id", "")) == asset_id:
			return
	_assert(false, "combat audio history is missing: %s" % asset_id)


func _assert_history_prefix(controller: Node, prefix: String) -> void:
	var history: Array = controller.get_debug_snapshot().get("recent_history", [])
	for entry in history:
		if entry is Dictionary and str((entry as Dictionary).get("asset_id", "")).begins_with(prefix):
			return
	_assert(false, "combat audio history is missing prefix: %s" % prefix)


func _assert_history_is_positional(controller: Node) -> void:
	var history: Array = controller.get_debug_snapshot().get("recent_history", [])
	_assert(not history.is_empty(), "combat mapping produced no playback")
	for entry in history:
		if not entry is Dictionary:
			continue
		_assert(str((entry as Dictionary).get("player_type", "")) == "AudioStreamPlayer3D", "combat sound is not positional")
		_assert(str((entry as Dictionary).get("bus", "")) == "Combat", "combat sound is not routed to Combat bus")


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("T0135 P10E verification failed: %s" % message)
	quit(1)
