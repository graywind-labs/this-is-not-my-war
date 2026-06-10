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
	var workstation_label := root.get_node_or_null("Main/UI/BuildingPanel/PanelContainer/MarginContainer/Content/BuildingWorkstationLabel") as Label
	if panel == null or building_system == null or npc_system == null or workstation_label == null:
		push_error("Required building panel systems are missing")
		quit(1)
		return

	panel.show_building("dining_hall")
	if workstation_label.text.contains("当前工作位"):
		push_error("Building panel should not show the old standalone workstation summary")
		quit(1)
		return
	if not workstation_label.text.contains("厨师 1/1：空闲"):
		push_error("Free dining hall workstation should show free/total count inline: %s" % workstation_label.text)
		quit(1)
		return

	var claim_result: Dictionary = building_system.claim_workstation("dining_hall", "cook_01", "cook")
	if not bool(claim_result.get("ok", false)):
		push_error("Failed to claim dining hall cook workstation")
		quit(1)
		return
	panel.show_building("dining_hall")
	var cook_name := _npc_name(npc_system, "cook_01")
	if not workstation_label.text.contains("厨师 0/1：%s" % cook_name):
		push_error("Occupied dining hall workstation should show NPC name and 0 free slots: %s" % workstation_label.text)
		quit(1)
		return
	building_system.release_workstation("dining_hall", "cook_01", str(claim_result.get("workstation_id", "")))

	var custom_clinic_workstations: Array[Dictionary] = [
		{"id": "doctor_desk_01", "type": "clinic_doctor", "occupied_by": "doctor_01"},
		{"id": "treatment_bed_01", "type": "patient_bed", "occupied_by": "priest_01"},
		{"id": "treatment_bed_02", "type": "patient_bed", "occupied_by": null}
	]
	var clinic_text := str(panel._format_workstations(custom_clinic_workstations))
	if not clinic_text.contains("医生 0/1：%s" % _npc_name(npc_system, "doctor_01")):
		push_error("Clinic doctor slot should show its own free/total count and occupant: %s" % clinic_text)
		quit(1)
		return
	if not clinic_text.contains("病床 1/2：%s" % _npc_name(npc_system, "priest_01")):
		push_error("Clinic beds should be grouped with real free/total count: %s" % clinic_text)
		quit(1)
		return

	var custom_training_workstations: Array[Dictionary] = [
		{"id": "training_instructor_01", "type": "training_instructor", "occupied_by": "veteran_deputy_01"},
		{"id": "training_student_01", "type": "training_student", "occupied_by": "stableman_01"},
		{"id": "training_student_02", "type": "training_student", "occupied_by": null}
	]
	var training_text := str(panel._format_workstations(custom_training_workstations))
	if not training_text.contains("教官 0/1：%s" % _npc_name(npc_system, "veteran_deputy_01")):
		push_error("Training instructor slot should show its own line: %s" % training_text)
		quit(1)
		return
	if not training_text.contains("受训者 1/2：%s" % _npc_name(npc_system, "stableman_01")):
		push_error("Training student slots should be grouped with free/total count: %s" % training_text)
		quit(1)
		return

	panel.show_building("wall")
	if workstation_label.text != "工位：无":
		push_error("Buildings without workstations should use the new no-workstation label: %s" % workstation_label.text)
		quit(1)
		return

	print("T0016 building panel workstation display verification passed.")
	quit(0)


func _npc_name(npc_system: Node, npc_id: String) -> String:
	var npc: Dictionary = npc_system.get_npc(npc_id)
	return str(npc.get("name", npc_id))
