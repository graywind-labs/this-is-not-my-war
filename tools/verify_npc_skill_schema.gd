extends SceneTree

const EXPECTED_SKILLS := ["养马", "厨艺", "耕种", "打铁", "教练", "酿酒", "医术", "工程", "剑盾", "长杆", "弓", "弩", "骑术"]


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	if npc_system == null:
		push_error("NPCSystem not found")
		quit(1)
		return

	for npc_id in npc_system.get_npc_ids():
		var npc: Dictionary = npc_system.get_npc(npc_id)
		var skills: Dictionary = npc.get("skills", {})
		if skills.size() != EXPECTED_SKILLS.size():
			push_error("%s should have %d skills, got %d" % [npc_id, EXPECTED_SKILLS.size(), skills.size()])
			quit(1)
			return

		for skill_name in EXPECTED_SKILLS:
			if not skills.has(skill_name):
				push_error("%s missing skill: %s" % [npc_id, skill_name])
				quit(1)
				return

		for skill_name in skills.keys():
			if not EXPECTED_SKILLS.has(str(skill_name)):
				push_error("%s has unexpected skill: %s" % [npc_id, str(skill_name)])
				quit(1)
				return

	print("NPC skill schema verification passed.")
	quit(0)
