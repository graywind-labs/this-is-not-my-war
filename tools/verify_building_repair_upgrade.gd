extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn")
	if main_scene == null:
		push_error("Main scene failed to load.")
		quit(1)
		return

	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var panel := root.get_node_or_null("Main/UI/BuildingPanel")
	if building_system == null or resource_system == null or panel == null:
		push_error("Required systems or building panel are missing.")
		quit(1)
		return

	var building_id := "wall"
	var original: Dictionary = building_system.get_building(building_id)
	var original_stone: int = resource_system.get_resource("stone")
	if original.is_empty() or original_stone < 8:
		push_error("Verify precondition failed.")
		quit(1)
		return

	if not building_system.debug_damage_building(building_id, 40):
		push_error("Failed to damage building.")
		quit(1)
		return

	panel.show_building(building_id)
	if not building_system.can_repair_building(building_id):
		push_error("Damaged building should be repairable.")
		quit(1)
		return

	if not building_system.repair_building(building_id):
		push_error("Repair failed.")
		quit(1)
		return

	var repaired: Dictionary = building_system.get_building(building_id)
	if int(repaired.get("hp", 0)) <= int(original.get("hp", 0)) - 40:
		push_error("Repair did not restore HP.")
		quit(1)
		return
	if resource_system.get_resource("stone") != original_stone - 1:
		push_error("Repair did not spend stone.")
		quit(1)
		return

	var before_upgrade_stone: int = resource_system.get_resource("stone")
	var before_upgrade_workstations: Array = repaired.get("workstations", [])
	if not building_system.upgrade_building(building_id):
		push_error("Upgrade failed.")
		quit(1)
		return

	var upgraded: Dictionary = building_system.get_building(building_id)
	var upgraded_workstations: Array = upgraded.get("workstations", [])
	if int(upgraded.get("level", 0)) != int(repaired.get("level", 0)) + 1:
		push_error("Upgrade did not increase level.")
		quit(1)
		return
	if int(upgraded.get("max_hp", 0)) <= int(repaired.get("max_hp", 0)):
		push_error("Upgrade did not increase max HP.")
		quit(1)
		return
	if upgraded_workstations.size() <= before_upgrade_workstations.size():
		push_error("Upgrade did not add a workstation.")
		quit(1)
		return
	if resource_system.get_resource("stone") != before_upgrade_stone - 3:
		push_error("Upgrade did not spend stone.")
		quit(1)
		return

	var stone_before_failed_upgrade: int = resource_system.get_resource("stone")
	if building_system.upgrade_building(building_id):
		push_error("Upgrade should fail when stone is insufficient.")
		quit(1)
		return
	if resource_system.get_resource("stone") != stone_before_failed_upgrade:
		push_error("Failed upgrade changed stone.")
		quit(1)
		return

	print("T0205 repair and upgrade verification passed.")
	quit(0)
