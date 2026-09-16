extends SceneTree


func _init() -> void:
	var tutorial := _load_json_dictionary("res://data/tutorial_config.json")
	var waves := _load_json_array("res://data/enemy_waves.json")
	if tutorial.is_empty() or waves.is_empty():
		_fail("T0443 could not load tutorial or formal enemy configuration")
		return
	var overrides: Dictionary = tutorial.get("tutorial_device_overrides", {})
	if int(overrides.get("max_hp", 0)) != 15:
		_fail("T0443 tutorial arrow-tower Max HP must be 15")
		return
	var tutorial_enemies: Array = (tutorial.get("tutorial_raid", {}) as Dictionary).get("enemies", [])
	var first_wave_enemies: Array = (waves[0] as Dictionary).get("enemies", [])
	if tutorial_enemies.size() != 1 or first_wave_enemies.is_empty():
		_fail("T0443 expected one tutorial enemy group and a non-empty first wave")
		return
	var tutorial_attack := int((tutorial_enemies[0] as Dictionary).get("attack_power", 0))
	var first_wave_attack := int((first_wave_enemies[0] as Dictionary).get("attack_power", 0))
	if tutorial_attack != first_wave_attack or tutorial_attack != 6:
		_fail("T0443 tutorial attack must equal first-wave attack: tutorial=%d formal=%d" % [tutorial_attack, first_wave_attack])
		return
	if (tutorial.get("tutorial_raid", {}) as Dictionary).has("defense_device_damage_multiplier"):
		_fail("T0444 tutorial config must not retain a defense-device damage multiplier")
		return

	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("T0443 could not load Main.tscn")
		return
	root.add_child(packed.instantiate())
	await process_frame
	await physics_frame
	var devices := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var resources := root.get_node_or_null("Main/Systems/ResourceSystem")
	if devices == null or resources == null:
		_fail("T0443 runtime systems are missing")
		return
	var formal_definition: Dictionary = devices.get_device_definition("wall_arrow_tower")
	resources.add_resource("item_wall_arrow_tower", 1)
	var deployed: Dictionary = devices.deploy_device("wall_arrow_tower", "wall_slot_01")
	var deployment_id := str(deployed.get("deployment_id", ""))
	var applied: Dictionary = devices.apply_tutorial_deployment_overrides(deployment_id, overrides)
	if int(applied.get("hp", 0)) != 15 or int(applied.get("max_hp", 0)) != 15:
		_fail("T0443 runtime tutorial deployment did not become 15/15 HP")
		return
	var formal_after: Dictionary = devices.get_device_definition("wall_arrow_tower")
	if formal_after != formal_definition:
		_fail("T0443 tutorial override leaked into the formal arrow-tower definition")
		return
	print("T0443 tutorial combat rebalance verified: tower 15 HP, enemy attack 6")
	quit(0)


func _load_json_dictionary(path: String) -> Dictionary:
	var parsed = _load_json(path)
	return parsed if parsed is Dictionary else {}


func _load_json_array(path: String) -> Array:
	var parsed = _load_json(path)
	return parsed if parsed is Array else []


func _load_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) if file != null else null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
