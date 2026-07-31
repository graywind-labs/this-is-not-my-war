extends SceneTree

const REQUIRED_ENEMY_FIELDS := [
	"enemy_type_id",
	"name",
	"count",
	"unit_type",
	"weapon_type",
	"hp",
	"max_hp",
	"attack_power",
	"defense",
	"penetration",
	"move_speed",
	"attack_range",
	"attack_speed",
	"attack_interval",
	"attack_windup",
	"target_preference"
]
const VALID_UNIT_TYPES := [
	"melee_infantry",
	"polearm_infantry",
	"archer",
	"crossbowman",
	"cavalry",
	"mounted_ranged"
]


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var enemy_root := root.get_node_or_null("Main/WorldRoot/Station/Enemies")
	var ground := root.get_node_or_null("Main/WorldRoot/Station/Ground") as MeshInstance3D
	var front_road := root.get_node_or_null("Main/WorldRoot/Station/Props/FrontRoad") as MeshInstance3D
	var camera_rig := root.get_node_or_null("Main/CameraRig")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	if combat_system == null or enemy_root == null or ground == null or front_road == null or camera_rig == null or gm_panel == null:
		push_error("Enemy wave verification required nodes not found")
		quit(1)
		return

	if combat_system.get_wave_count() < 5:
		push_error("T1101 requires at least 5 configured enemy waves")
		quit(1)
		return

	var previous_threat := 0.0
	var previous_enemy_count := 0
	for wave_number in combat_system.get_wave_numbers():
		var wave: Dictionary = combat_system.get_wave_config(int(wave_number))
		if wave.is_empty():
			push_error("Missing wave config for wave %s" % str(wave_number))
			quit(1)
			return
		var enemies: Array = wave.get("enemies", [])
		if enemies.is_empty():
			push_error("Wave %s has no enemies" % str(wave_number))
			quit(1)
			return
		var threat := 0.0
		for raw_enemy in enemies:
			var enemy: Dictionary = raw_enemy if raw_enemy is Dictionary else {}
			if not _has_required_enemy_fields(enemy):
				push_error("Wave %s enemy is missing required fields: %s" % [str(wave_number), JSON.stringify(enemy)])
				quit(1)
				return
			if not VALID_UNIT_TYPES.has(str(enemy.get("unit_type", ""))):
				push_error("Wave %s enemy has invalid unit_type: %s" % [str(wave_number), str(enemy.get("unit_type", ""))])
				quit(1)
				return
			if int(enemy.get("hp", 0)) <= 0 or int(enemy.get("attack_power", 0)) <= 0 or float(enemy.get("move_speed", 0.0)) <= 0.0:
				push_error("Wave %s enemy stats must be positive: %s" % [str(wave_number), JSON.stringify(enemy)])
				quit(1)
				return
			if (
				float(enemy.get("defense", -1.0)) < 0.0
				or float(enemy.get("penetration", -1.0)) < 0.0
				or float(enemy.get("attack_speed", 0.0)) <= 0.0
				or float(enemy.get("attack_interval", 0.0)) <= 0.0
				or float(enemy.get("attack_windup", 0.0)) <= 0.0
			):
				push_error("Wave %s enemy defense/penetration/speed/windup contract is invalid: %s" % [
					str(wave_number),
					JSON.stringify(enemy)
				])
				quit(1)
				return
			if not is_equal_approx(
				float(enemy.get("attack_interval", 0.0)),
				1.0 / float(enemy.get("attack_speed", 1.0))
			):
				push_error("Wave %s enemy attack_speed should be the reciprocal of attack_interval" % str(wave_number))
				quit(1)
				return
			var target_preference: Array = enemy.get("target_preference", [])
			if not target_preference.has("front_gate") or not target_preference.has("main_hall"):
				push_error("Enemy target_preference should include front_gate and main_hall")
				quit(1)
				return
			threat += float(enemy.get("count", 0)) * (
				float(enemy.get("hp", 0)) * 0.12
				+ float(enemy.get("attack_power", 0))
				+ float(enemy.get("defense", 0)) * 1.5
			)
		var enemy_count := _wave_enemy_count(wave)
		if enemy_count <= previous_enemy_count:
			push_error("Enemy wave counts should strictly increase. wave=%s count=%d previous=%d" % [
				str(wave_number),
				enemy_count,
				previous_enemy_count
			])
			quit(1)
			return
		previous_enemy_count = enemy_count
		if previous_threat > 0.0 and threat < previous_threat:
			push_error("Enemy waves should not get weaker. wave=%s threat=%s previous=%s" % [str(wave_number), str(threat), str(previous_threat)])
			quit(1)
			return
		previous_threat = threat

	var ground_mesh := ground.mesh as PlaneMesh
	if ground_mesh == null or ground_mesh.size.y < 60.0:
		push_error("Front-side ground should be expanded for enemies outside the gate")
		quit(1)
		return
	if front_road.global_position.z < 22.0:
		push_error("Front road should extend farther outside the front gate")
		quit(1)
		return
	if camera_rig.z_limits.y < 30.0:
		push_error("Camera z limit should allow viewing the enemy spawn area")
		quit(1)
		return

	var wave_one: Dictionary = combat_system.get_wave_config(1)
	var expected_wave_one_count := _wave_enemy_count(wave_one)
	if expected_wave_one_count <= 3:
		push_error("First wave should contain more enemies than the old three-unit baseline")
		quit(1)
		return
	var spawn_position: Dictionary = wave_one.get("spawn_position", {})
	if float(spawn_position.get("z", 0.0)) < 27.0:
		push_error("First wave should spawn outside and ahead of the front gate")
		quit(1)
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		push_error("CombatSystem failed to spawn first wave: %s" % JSON.stringify(spawn_result))
		quit(1)
		return
	if int(spawn_result.get("spawned_count", 0)) != expected_wave_one_count:
		push_error("First wave spawned wrong enemy count")
		quit(1)
		return
	if combat_system.get_active_enemy_count() != expected_wave_one_count:
		push_error("Active enemy count should match spawned first wave count")
		quit(1)
		return
	if enemy_root.get_child_count() != expected_wave_one_count:
		push_error("Enemy nodes should be created under Station/Enemies")
		quit(1)
		return

	for enemy_id in combat_system.get_active_enemy_ids():
		var enemy: Dictionary = combat_system.get_enemy(enemy_id)
		if enemy.is_empty():
			push_error("Active enemy state missing: %s" % enemy_id)
			quit(1)
			return
		var position: Vector3 = enemy.get("position", Vector3.ZERO)
		if position.z < 27.0:
			push_error("Enemy should spawn outside the front gate: %s at %s" % [enemy_id, str(position)])
			quit(1)
			return
		var enemy_node := enemy_root.get_node_or_null(_make_node_name(enemy_id))
		if enemy_node == null or str(enemy_node.get_meta("enemy_id", "")) != enemy_id:
			push_error("Enemy node metadata should preserve enemy id")
			quit(1)
			return

	combat_system.debug_clear_enemies()
	await process_frame
	await process_frame
	if combat_system.get_active_enemy_count() != 0:
		push_error("debug_clear_enemies should clear active enemy state")
		quit(1)
		return

	var spawn_button := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as PanelContainer
	var gm_button := root.get_node_or_null("Main/UI/GMPanel/GMButton") as Button
	if gm_button == null:
		push_error("GM button missing")
		quit(1)
		return
	gm_button.pressed.emit()
	await process_frame
	spawn_button = root.get_node_or_null("Main/UI/GMPanel/GMWindow") as PanelContainer
	var spawn_first_wave_button := spawn_button.find_child("SpawnFirstWaveButton", true, false) as Button
	if spawn_first_wave_button == null:
		push_error("GMPanel should expose SpawnFirstWaveButton")
		quit(1)
		return
	spawn_first_wave_button.pressed.emit()
	await process_frame
	if combat_system.get_active_enemy_count() != expected_wave_one_count:
		push_error("GM SpawnFirstWaveButton should spawn first wave enemies")
		quit(1)
		return
	gm_panel._execute_command("clear_enemies")
	await process_frame
	gm_panel._execute_command("spawn_wave 1")
	await process_frame
	if combat_system.get_active_enemy_count() != expected_wave_one_count:
		push_error("GM spawn_wave command should spawn first wave enemies")
		quit(1)
		return
	gm_panel._execute_command("enemies")

	print("Enemy wave generation verification passed.")
	quit(0)


func _has_required_enemy_fields(enemy: Dictionary) -> bool:
	for field in REQUIRED_ENEMY_FIELDS:
		if not enemy.has(field):
			return false
	return true


func _wave_enemy_count(wave: Dictionary) -> int:
	var total := 0
	for raw_enemy in (wave.get("enemies", []) as Array):
		var enemy: Dictionary = raw_enemy if raw_enemy is Dictionary else {}
		total += int(enemy.get("count", 0))
	return total


func _make_node_name(id_value: String) -> String:
	var parts := id_value.split("_")
	var result := ""
	for part in parts:
		if part.is_empty():
			continue
		result += part.substr(0, 1).to_upper() + part.substr(1).to_lower()
	return "Enemy" if result.is_empty() else result
