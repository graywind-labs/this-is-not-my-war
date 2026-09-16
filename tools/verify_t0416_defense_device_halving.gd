extends SceneTree


const EXPECTED := {
	"wall_ballista": {"max_hp": 25, "damage": 22},
	"wall_arrow_tower": {"max_hp": 50, "damage": 8},
}


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	await process_frame
	await physics_frame
	var devices := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var resources := root.get_node_or_null("Main/Systems/ResourceSystem")
	if devices == null or resources == null:
		_fail("Defense-device authority is missing")
		return
	if devices.get_device_ids().size() != EXPECTED.size():
		_fail("Not every configured defense-device type is covered")
		return
	var slots := {"wall_ballista": "wall_slot_01", "wall_arrow_tower": "main_hall_slot_03"}
	for device_id in EXPECTED:
		var definition: Dictionary = devices.get_device_definition(device_id)
		var expected: Dictionary = EXPECTED[device_id]
		if int(definition.get("max_hp", 0)) != int(expected.max_hp) or int(definition.get("effect", {}).get("damage", 0)) != int(expected.damage):
			_fail("Definition mismatch for %s" % device_id)
			return
		var inventory_id := str((definition.get("inventory_cost", {}) as Dictionary).keys()[0])
		resources.add_resource(inventory_id, 1)
		var result: Dictionary = devices.deploy_device(device_id, slots[device_id])
		var deployment: Dictionary = devices.get_deployment(str(result.get("deployment_id", "")))
		if not bool(result.get("ok", false)) or int(deployment.get("hp", 0)) != int(expected.max_hp) or int(deployment.get("max_hp", 0)) != int(expected.max_hp) or int(deployment.get("effect", {}).get("damage", 0)) != int(expected.damage):
			_fail("Runtime deployment mismatch for %s" % device_id)
			return
	var tutorial_deployment: Dictionary = devices.get_deployment_for_slot("main_hall_slot_03")
	var tutorial_override: Dictionary = devices.apply_tutorial_deployment_overrides(
		str(tutorial_deployment.get("deployment_id", "")),
		{"max_hp": 15, "damage": 16}
	)
	if int(tutorial_override.get("hp", 0)) != 15 or int(tutorial_override.get("max_hp", 0)) != 15 or int(tutorial_override.get("effect", {}).get("damage", 0)) != 16:
		_fail("Tutorial arrow-tower override did not apply the configured tutorial values")
		return
	var formal_definition: Dictionary = devices.get_device_definition("wall_arrow_tower")
	if int(formal_definition.get("max_hp", 0)) != 50 or int(formal_definition.get("effect", {}).get("damage", 0)) != 8:
		_fail("Tutorial override leaked into the formal arrow-tower definition")
		return
	print("T0416 defense-device HP and damage halving verified")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
