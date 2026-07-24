extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	if equipment_system == null or resource_system == null or npc_system == null:
		push_error("T0902 required systems are missing")
		quit(1)
		return

	var target_id := "veteran_deputy_01"
	if not bool(npc_system.get_npc(target_id).get("recruited", false)):
		push_error("Veteran deputy should start recruited for T0902 verification")
		quit(1)
		return

	if equipment_system.get_weapon_ids().has("short_sword"):
		push_error("Removed short_sword should not be available for unit type classification")
		quit(1)
		return
	if not _verify_direct_classification(equipment_system):
		quit(1)
		return
	var inventory_boundary_ok: bool = await _verify_inventory_does_not_imply_mount(equipment_system, resource_system, npc_system, target_id)
	if not inventory_boundary_ok:
		quit(1)
		return

	print("T0902 unit type classification verification passed.")
	quit(0)


func _verify_direct_classification(equipment_system: Node) -> bool:
	var cases := [
		{
			"name": "无武器",
			"equipment": {},
			"expected": "non_combat",
			"label": "非战斗人员 / 避战单位"
		},
		{
			"name": "只有坐骑",
			"equipment": {"mount": equipment_system.get_mount_def("riding_horse")},
			"expected": "non_combat",
			"label": "非战斗人员 / 避战单位"
		},
		{
			"name": "剑盾",
			"equipment": {"main_weapon": equipment_system.get_weapon_def("sword_shield")},
			"expected": "melee_infantry",
			"label": "近战步兵"
		},
		{
			"name": "长杆武器",
			"equipment": {"main_weapon": equipment_system.get_weapon_def("polearm")},
			"expected": "polearm_infantry",
			"label": "长杆步兵"
		},
		{
			"name": "弓",
			"equipment": {"main_weapon": equipment_system.get_weapon_def("bow")},
			"expected": "archer",
			"label": "弓箭兵"
		},
		{
			"name": "弩",
			"equipment": {"main_weapon": equipment_system.get_weapon_def("crossbow")},
			"expected": "crossbowman",
			"label": "弩兵"
		},
		{
			"name": "剑盾 + 坐骑",
			"equipment": {
				"main_weapon": equipment_system.get_weapon_def("sword_shield"),
				"mount": equipment_system.get_mount_def("riding_horse")
			},
			"expected": "cavalry",
			"label": "近战骑兵"
		},
		{
			"name": "长杆 + 坐骑",
			"equipment": {
				"main_weapon": equipment_system.get_weapon_def("polearm"),
				"mount": equipment_system.get_mount_def("riding_horse")
			},
			"expected": "cavalry",
			"label": "近战骑兵"
		},
		{
			"name": "弓 + 坐骑",
			"equipment": {
				"main_weapon": equipment_system.get_weapon_def("bow"),
				"mount": equipment_system.get_mount_def("riding_horse")
			},
			"expected": "mounted_ranged",
			"label": "骑射单位"
		},
		{
			"name": "弩 + 坐骑",
			"equipment": {
				"main_weapon": equipment_system.get_weapon_def("crossbow"),
				"mount": equipment_system.get_mount_def("riding_horse")
			},
			"expected": "mounted_ranged",
			"label": "骑射单位"
		}
	]

	for test_case in cases:
		var equipment: Dictionary = test_case.get("equipment", {})
		var actual := str(equipment_system.determine_unit_type(equipment))
		var expected := str(test_case.get("expected", ""))
		if actual != expected:
			push_error("%s should classify as %s, got %s" % [str(test_case.get("name", "")), expected, actual])
			return false
		var label := str(equipment_system.get_unit_type_label(actual))
		if label != str(test_case.get("label", "")):
			push_error("%s label should be %s, got %s" % [str(test_case.get("name", "")), str(test_case.get("label", "")), label])
			return false
	return true


func _verify_inventory_does_not_imply_mount(
	equipment_system: Node,
	resource_system: Node,
	_npc_system: Node,
	target_id: String
) -> bool:
	resource_system.add_resource("item_bow", 1)
	await process_frame

	var initial_snapshot: Dictionary = equipment_system.get_unit_type_snapshot(target_id)
	if str(initial_snapshot.get("unit_type", "")) != "melee_infantry" or str(initial_snapshot.get("main_weapon_id", "")) != "sword_shield":
		push_error("Ada should begin as sword-and-shield melee infantry: %s" % JSON.stringify(initial_snapshot))
		return false
	if bool(initial_snapshot.get("has_mount", false)):
		push_error("Initial snapshot should not show a mount before EquipmentSystem writes equipment.mount")
		return false

	var weapon_only_snapshot: Dictionary = equipment_system.get_unit_type_snapshot(target_id)
	if str(weapon_only_snapshot.get("unit_type", "")) != "melee_infantry":
		push_error("Unassigned stable horses must not turn Ada's initial weapon-only loadout into cavalry: %s" % JSON.stringify(weapon_only_snapshot))
		return false
	if bool(weapon_only_snapshot.get("has_mount", false)):
		push_error("Weapon-only snapshot should not show a mount before equip_npc_mount")
		return false

	var mount_result: Dictionary = equipment_system.equip_npc_mount(target_id, "", "private")
	if not bool(mount_result.get("ok", false)):
		push_error("Failed to equip mount: %s" % JSON.stringify(mount_result))
		return false
	var cavalry_snapshot: Dictionary = equipment_system.get_unit_type_snapshot(target_id)
	if str(cavalry_snapshot.get("unit_type", "")) != "cavalry" or not bool(cavalry_snapshot.get("has_mount", false)):
		push_error("Sword and shield plus equipment.mount should classify as cavalry: %s" % JSON.stringify(cavalry_snapshot))
		return false

	var bow_result: Dictionary = equipment_system.equip_npc_main_weapon(target_id, "bow", "private")
	if not bool(bow_result.get("ok", false)):
		push_error("Failed to equip bow: %s" % JSON.stringify(bow_result))
		return false
	var mounted_ranged_snapshot: Dictionary = equipment_system.get_unit_type_snapshot(target_id)
	if str(mounted_ranged_snapshot.get("unit_type", "")) != "mounted_ranged":
		push_error("Bow plus equipment.mount should classify as mounted ranged: %s" % JSON.stringify(mounted_ranged_snapshot))
		return false

	return true
