extends SceneTree

const PANEL_LABEL_COLOR := Color(0.94, 0.87, 0.70, 1.0)


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame in 4:
		await process_frame
		await physics_frame

	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var device_presenter := root.get_node_or_null("Main/WorldRoot/Station/DefenseDevices")
	var world_feedback := root.get_node_or_null("Main/UI/WorldFeedbackPresenter")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	if [building_system, resource_system, device_system, device_presenter, world_feedback, npc_system, npc_panel].has(null):
		_fail("T0327 required systems or presenters are missing")
		return

	_set_building_level(building_system, "wall", 2)
	resource_system.add_resource("item_wall_ballista", 1)
	resource_system.add_resource("item_wall_arrow_tower", 1)
	if not await _verify_device_anchor(device_system, device_presenter, world_feedback, "wall_ballista", "wall_slot_01"):
		return
	if not await _verify_device_anchor(device_system, device_presenter, world_feedback, "wall_arrow_tower", "wall_slot_02"):
		return
	if not await _verify_experience_color(npc_system, npc_panel):
		return

	main.queue_free()
	for _frame in 3:
		await process_frame
	print("T0327 defense feedback anchor and NPC experience color verification passed.")
	quit(0)


func _verify_device_anchor(
	device_system: Node,
	device_presenter: Node,
	world_feedback: Node,
	device_id: String,
	slot_id: String
) -> bool:
	var deployed: Dictionary = device_system.deploy_device(device_id, slot_id)
	if not bool(deployed.get("ok", false)):
		return _fail("Could not deploy %s: %s" % [device_id, deployed])
	await process_frame
	await process_frame
	var deployment_id := str(deployed.get("deployment_id", ""))
	var view: Node3D = device_presenter.get_view_for_deployment(deployment_id)
	if view == null:
		return _fail("Missing formal view for %s" % device_id)
	var overhead: Dictionary = view.get_debug_snapshot().get("overhead_ui", {})
	var bar: Dictionary = overhead.get("health_bar", {})
	var bar_world_position := view.to_global(bar.get("position", Vector3.ZERO))
	var feedback_anchor: Variant = device_system.get_deployment_feedback_anchor_position(deployment_id)
	if not feedback_anchor is Vector3 or (feedback_anchor as Vector3).y < bar_world_position.y + 0.3:
		return _fail("%s feedback anchor is not above its own health bar" % device_id)

	var damaged: Dictionary = device_system.apply_damage_to_device(deployment_id, 1, {
		"attacker_id": "verify_t0327",
		"hit_world_position": Vector3(90.0, -10.0, 90.0)
	})
	if int(damaged.get("hp_before", 0)) - int(damaged.get("hp_after", 0)) != 1:
		return _fail("Prepared %s damage did not commit" % device_id)
	var group := _find_group(world_feedback, "defense_device:%s" % deployment_id, "damage")
	if (
		group.get("fallback_world_position", null) != feedback_anchor
		or not bool(group.get("prefer_fallback_position", false))
		or not is_zero_approx(float(group.get("anchor_height", -1.0)))
	):
		return _fail("%s damage still used its low hit point instead of the health-bar anchor" % device_id)
	world_feedback.debug_advance_feedback(2.1)
	return true


func _verify_experience_color(npc_system: Node, npc_panel: Control) -> bool:
	if not npc_system.debug_select_npc("veteran_deputy_01"):
		return _fail("Could not open NPC panel")
	for _frame in 3:
		await process_frame
	var experience_label := npc_panel.find_child("NPCExperienceLabel", true, false) as Label
	var experience_progress := npc_panel.find_child("NPCExperienceProgress", true, false) as ProgressBar
	if experience_label == null or experience_progress == null:
		return _fail("NPC experience controls are missing")
	var fill := experience_progress.get_theme_stylebox("fill") as StyleBoxFlat
	if fill == null or not fill.bg_color.is_equal_approx(PANEL_LABEL_COLOR):
		return _fail("NPC experience bar is not using the panel pale-yellow label color")
	if not experience_label.get_theme_color("font_color").is_equal_approx(PANEL_LABEL_COLOR):
		return _fail("NPC panel label theme color no longer matches the experience fill contract")
	return true


func _find_group(presenter: Node, anchor_key: String, channel: String) -> Dictionary:
	for raw_group in presenter.debug_get_snapshot():
		if raw_group is Dictionary and str(raw_group.get("anchor_key", "")) == anchor_key and str(raw_group.get("channel", "")) == channel:
			return raw_group
	return {}


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var buildings: Dictionary = building_system.get("_buildings")
	var building: Dictionary = buildings.get(building_id, {})
	building["level"] = level
	building["hp"] = maxi(1, int(building.get("max_hp", 1)))
	buildings[building_id] = building
	building_system.set("_buildings", buildings)


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
