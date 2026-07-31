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

	var panel := root.get_node_or_null("Main/UI/BuildingPanel")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var workstation_label: Label = panel.get("workstation_label") as Label if panel != null else null
	var location_label: Label = panel.get("location_label") as Label if panel != null else null
	if panel == null or building_system == null or npc_system == null or workstation_label == null or location_label == null:
		push_error("Required building panel systems are missing")
		quit(1)
		return

	var raw_tag_tokens := [
		"command", "failure_target", "living", "rest", "food", "storage",
		"raid_target", "defense", "outer_barrier", "gate", "escape_route",
		"merchant_route", "production", "morale", "weapons", "training",
		"combat", "horses", "faith", "medical", "recovery", "engineering"
	]
	for raw_building_id in building_system.get_building_ids():
		var tag_building_id := str(raw_building_id)
		panel.show_building(tag_building_id)
		if location_label.text.contains("地点标签"):
			push_error("Building panel should hide metadata tags: %s / %s" % [tag_building_id, location_label.text])
			quit(1)
			return
		for token in raw_tag_tokens:
			if location_label.text.contains(str(token)):
				push_error("Building panel leaked metadata tag '%s': %s / %s" % [token, tag_building_id, location_label.text])
				quit(1)
				return

	var expected_legacy_position_names := {
		"tavern": ["酿酒位1", "酿酒位"],
		"garden": ["耕作位1", "耕作位"],
		"blacksmith": ["锻造位1", "锻造位"],
		"stable": ["照料位1", "照料位"],
		"workshop": ["工程位1", "工程位"]
	}
	for raw_building_id in expected_legacy_position_names.keys():
		var legacy_building_id := str(raw_building_id)
		var expected: Array = expected_legacy_position_names[legacy_building_id]
		var legacy_building: Dictionary = building_system.get_building(legacy_building_id)
		var positions: Array = legacy_building.get("workstations", [])
		if positions.is_empty() or str(positions[0].get("name", "")) != str(expected[0]):
			push_error("Legacy position should have a configured Chinese name: %s / %s" % [legacy_building_id, JSON.stringify(positions)])
			quit(1)
			return
		var upgrade: Dictionary = legacy_building.get("upgrade", {})
		if str(upgrade.get("workstation_name_prefix", "")) != str(expected[1]):
			push_error("Upgraded positions should keep a Chinese name prefix: %s / %s" % [legacy_building_id, JSON.stringify(upgrade)])
			quit(1)
			return
		panel.show_building(legacy_building_id)
		if not workstation_label.text.begins_with("%s：" % str(expected[0])):
			push_error("Legacy position leaked an internal type in the panel: %s / %s" % [legacy_building_id, workstation_label.text])
			quit(1)
			return

	panel.show_building("dining_hall")
	var dining_hall: Dictionary = building_system.get_building("dining_hall")
	var dining_workstations: Array = dining_hall.get("workstations", [])
	if dining_workstations.is_empty() or not dining_workstations[0] is Dictionary:
		push_error("Dining hall should expose configured workstation order")
		quit(1)
		return
	var kitchen_station: Dictionary = dining_workstations[0]
	if str(kitchen_station.get("type", "")) != "dining_kitchen_station":
		push_error("Dining hall first configured position should be the kitchen station")
		quit(1)
		return
	var kitchen_name := str(kitchen_station.get("name", "灶台1"))
	var dining_lines := workstation_label.text.split("\n")
	if dining_lines.is_empty() or dining_lines[0] != "%s：空闲" % kitchen_name:
		push_error("Building panel should preserve config order and station.name: %s" % workstation_label.text)
		quit(1)
		return
	if workstation_label.text.contains("主动") or workstation_label.text.contains("被动") or workstation_label.text.contains("/"):
		push_error("Building panel should use concrete per-position occupancy lines: %s" % workstation_label.text)
		quit(1)
		return

	var claim_result: Dictionary = building_system.claim_workstation(
		"dining_hall",
		"cook_01",
		"dining_kitchen_station"
	)
	if not bool(claim_result.get("ok", false)):
		push_error("Failed to claim dining hall kitchen station: %s" % claim_result)
		quit(1)
		return
	panel.show_building("dining_hall")
	var occupied_kitchen_line := "%s：%s占用中" % [kitchen_name, _npc_name(npc_system, "cook_01")]
	if workstation_label.text.split("\n")[0] != occupied_kitchen_line:
		push_error("Occupied position should show its concrete NPC: %s" % workstation_label.text)
		quit(1)
		return
	building_system.release_workstation(
		"dining_hall",
		"cook_01",
		str(claim_result.get("workstation_id", ""))
	)

	var custom_clinic_workstations: Array[Dictionary] = [
		{"id": "doctor_desk_01", "type": "clinic_doctor_station", "name": "医生位", "occupied_by": "doctor_01"},
		{"id": "treatment_bed_01", "type": "clinic_patient_bed", "name": "病床", "occupied_by": "priest_01"},
		{"id": "treatment_bed_02", "type": "clinic_patient_bed", "name": "病床", "occupied_by": null}
	]
	var clinic_text := str(panel._format_workstations(custom_clinic_workstations))
	var expected_clinic_text := "\n".join([
		"医生位：%s占用中" % _npc_name(npc_system, "doctor_01"),
		"病床1：%s占用中" % _npc_name(npc_system, "priest_01"),
		"病床2：空闲"
	])
	if clinic_text != expected_clinic_text:
		push_error("Clinic positions should render one line each in config order: %s" % clinic_text)
		quit(1)
		return

	var custom_chapel_workstations: Array[Dictionary] = [
		{"id": "chapel_altar_01", "type": "chapel_altar", "occupied_by": null},
		{"id": "chapel_prayer_seat_01", "type": "chapel_prayer_seat", "occupied_by": null},
		{"id": "chapel_prayer_seat_02", "type": "chapel_prayer_seat", "occupied_by": "gardener_01"}
	]
	var chapel_text := str(panel._format_workstations(custom_chapel_workstations))
	var expected_chapel_text := "\n".join([
		"祭坛：空闲",
		"祈祷席1：空闲",
		"祈祷席2：%s占用中" % _npc_name(npc_system, "gardener_01")
	])
	if chapel_text != expected_chapel_text:
		push_error("Type labels should provide stable fallbacks when station.name is absent: %s" % chapel_text)
		quit(1)
		return

	var custom_training_workstations: Array[Dictionary] = [
		{"id": "training_student_01", "type": "training_practice_slot", "name": "训练位", "occupied_by": null},
		{"id": "training_instructor_01", "type": "training_instructor_station", "name": "教官位", "occupied_by": "veteran_deputy_01"},
		{"id": "training_student_02", "type": "training_practice_slot", "name": "训练位", "occupied_by": "stableman_01"}
	]
	var training_text := str(panel._format_workstations(custom_training_workstations))
	var expected_training_text := "\n".join([
		"训练位1：空闲",
		"教官位：%s占用中" % _npc_name(npc_system, "veteran_deputy_01"),
		"训练位2：%s占用中" % _npc_name(npc_system, "stableman_01")
	])
	if training_text != expected_training_text:
		push_error("Training positions should not be regrouped by type: %s" % training_text)
		quit(1)
		return

	var named_unknown_text := str(panel._format_workstations([
		{"id": "custom_01", "type": "future_position_type", "name": "靠窗位", "occupied_by": null}
	]))
	if named_unknown_text != "靠窗位：空闲":
		push_error("Explicit station.name should take priority over type mapping: %s" % named_unknown_text)
		quit(1)
		return

	var unnamed_unknown_text := str(panel._format_workstations([
		{"id": "future_01", "type": "future_position_type", "name": "future_position_type 1", "occupied_by": null}
	]))
	if unnamed_unknown_text != "位置：空闲":
		push_error("Unknown internal position types should use a Chinese fallback: %s" % unnamed_unknown_text)
		quit(1)
		return

	panel.show_building("stable")
	await process_frame
	await process_frame
	await process_frame
	var horse_section := panel.find_child("HorseSection", true, false) as VBoxContainer
	var horse_summary := panel.find_child("HorseSummaryLabel", true, false) as Label
	if horse_section == null or horse_summary == null:
		push_error("Stable horse UI nodes are missing")
		quit(1)
		return
	if not horse_summary.text.begins_with("在厩：") or not horse_summary.text.contains("｜离厩："):
		push_error("Stable summary should use simplified in/out wording: %s" % horse_summary.text)
		quit(1)
		return
	var assignment_count := 0
	for node in horse_section.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null:
			continue
		if label.text == "马厩马匹" or label.text.contains("物理在厩") or label.text.contains("骑手："):
			push_error("Stable panel retained redundant horse wording: %s" % label.text)
			quit(1)
			return
		if label.name.begins_with("HorseAssignment_"):
			assignment_count += 1
			if not label.text.begins_with("分配：") or label.text.contains("｜"):
				push_error("Horse assignment line should contain only assignment: %s" % label.text)
				quit(1)
				return
	if assignment_count == 0:
		push_error("Stable panel should render at least one horse assignment line")
		quit(1)
		return

	panel.show_building("wall")
	if workstation_label.text != "位置：无":
		push_error("Buildings without positions should use the concrete empty-state label: %s" % workstation_label.text)
		quit(1)
		return

	print("Building panel per-position workstation display verification passed.")
	quit(0)


func _npc_name(npc_system: Node, npc_id: String) -> String:
	var npc: Dictionary = npc_system.get_npc(npc_id)
	return str(npc.get("name", npc_id))
