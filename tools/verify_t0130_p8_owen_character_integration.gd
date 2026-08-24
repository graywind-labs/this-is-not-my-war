extends SceneTree


const NPC_ID := "engineer_01"
const EXPECTED_APPEARANCE_ID := "owen_engineer_chibi_v1"
const EXPECTED_PROFILE_APPEARANCE := "额前架着一副铜框护目镜，皮带上挂着折尺、炭笔和几枚木楔，常盯着墙角估算承重。"
const NPCPromptProfile = preload("res://scripts/core/NPCPromptProfile.gd")

var _failures: Array[String] = []


func _init() -> void:
	verify_profile_sync()
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_failures.append("Main.tscn unavailable")
		finish()
		return
	var main := packed.instantiate()
	var daily_plan_system := main.get_node_or_null("Systems/DailyPlanSystem")
	if daily_plan_system != null:
		daily_plan_system.set_auto_execution_enabled(false)
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var owen := _get_npc_node(npc_system) if npc_system != null else null
	if [npc_system, equipment_system, resource_system, time_system, owen].has(null):
		_failures.append("T0130-P8 runtime dependencies unavailable")
		finish()
		return
	time_system.set_paused(false)
	npc_system.update_npc_state(NPC_ID, {
		"hp": 94,
		"unconscious": false,
		"fatigue": 0,
		"satiety": 100,
		"current_action": "idle",
		"last_action_result": "verify_t0130_p8_ready",
	})
	await process_frame

	var initial: Dictionary = owen.debug_get_character_art_snapshot()
	check(bool(initial.get("ready", false)), "Owen chibi art did not become ready")
	check(str(initial.get("appearance_id", "")) == EXPECTED_APPEARANCE_ID, "Owen still uses the legacy fallback")
	check(str(initial.get("equipment_mode", "")) == "engineering_kit", "Owen does not use the engineering-kit presentation contract")
	check(bool(initial.get("use_imported_character_material", false)), "Owen does not preserve the authored Synty material")
	check(str(initial.get("palette_path", "")).ends_with("PolygonMinis_Texture_01_A.png"), "Owen does not preserve the restrained workwear palette")
	check(float(initial.get("palette_value_scale", 1.0)) <= 0.8, "Owen workwear is not darkened enough for the station palette")
	check(bool(initial.get("engineer_goggles_visible", false)), "Owen's brass goggles are missing")
	check(str(initial.get("engineer_goggles_parent", "")) == "Head", "Owen's goggles do not follow the head bone")
	check(str(initial.get("engineer_goggles_mode", "")) == "forehead", "Owen wears his goggles over his eyes while idle")
	check(bool(initial.get("engineer_tool_belt_visible", false)), "Owen's tool belt is missing")
	check(str(initial.get("engineer_tool_belt_parent", "")) == "Body", "Owen's tool belt does not follow the body bone")
	check(not bool(initial.get("engineer_wrench_visible", true)), "Owen holds his active work tool while idle")
	check(not bool(initial.get("hammer_visible", true)) and not bool(initial.get("garden_hoe_visible", true)) and not bool(initial.get("cook_spoon_visible", true)), "Owen inherited another profession's tool")
	check(not owen.get_node("BodyCollision").disabled, "Owen body collision was replaced by art")
	check(not owen.get_node("InteractionArea/InteractionCollision").disabled, "Owen interaction collision was replaced by art")
	check(not owen.get_node("LegacyVisuals").visible, "Owen legacy mesh is still visible")
	check(owen.find_child("SelectionArea", true, false) == null, "Owen production art added a duplicate selection collider")
	var target_mesh := owen.find_child("SK_Pirates_Firstmate_01", true, false) as MeshInstance3D
	var authored_material := target_mesh.material_override as BaseMaterial3D if target_mesh != null else null
	check(target_mesh != null, "Owen's selected Synty foreman body is missing")
	check(authored_material != null and authored_material.vertex_color_use_as_albedo, "Owen lost authored face and workwear vertex colors")
	check(authored_material != null and authored_material.albedo_texture != null and authored_material.albedo_texture.resource_path.ends_with("PolygonMinis_Texture_01_A.png"), "Owen imported material does not bind the authored Albedo")
	for accessory_name in ["EngineerGoggles", "EngineerToolBelt", "EngineerWrench"]:
		var accessory := owen.find_child(accessory_name, true, false)
		check(accessory != null, "Owen accessory is missing: %s" % accessory_name)
		if accessory != null:
			check(accessory.find_children("*", "CollisionShape3D", true, false).is_empty(), "Owen visual accessory added gameplay collision: %s" % accessory_name)
			check(accessory.find_children("*", "Area3D", true, false).is_empty(), "Owen visual accessory added an interaction area: %s" % accessory_name)

	var action_before_preview := str(npc_system.get_npc_state(NPC_ID).get("current_action", ""))
	var expected_states := {
		"walk": "Walking_A",
		"talk": "Waving",
		"work": "Working_A",
		"training_practice": "Melee_1H_Attack_Slice_Diagonal",
		"attack": "Melee_1H_Attack_Slice_Horizontal",
	}
	for state_name in expected_states.keys():
		var preview: Dictionary = owen.debug_force_character_animation(str(state_name))
		check(str(preview.get("current_clip", "")) == str(expected_states[state_name]), "Owen state '%s' selected the wrong clip" % state_name)
		check(bool(preview.get("engineer_goggles_visible", false)) and bool(preview.get("engineer_tool_belt_visible", false)), "Owen identity accessories disappeared in state '%s'" % state_name)
		check(str(preview.get("engineer_goggles_mode", "")) == ("worn" if state_name == "work" else "forehead"), "Owen goggles use the wrong pose in state '%s'" % state_name)
		check(bool(preview.get("engineer_wrench_visible", false)) == (state_name == "work"), "Owen work tool visibility is wrong in state '%s'" % state_name)
	check(int(owen.debug_get_character_art_snapshot().get("work_clip_loop_mode", Animation.LOOP_NONE)) == Animation.LOOP_LINEAR, "Owen's assembly animation is not cyclic")
	check(str(npc_system.get_npc_state(NPC_ID).get("current_action", "")) == action_before_preview, "Animation preview changed Owen's authoritative action")
	npc_system.update_npc_state(NPC_ID, {"current_action": "idle"})
	await process_frame

	check(npc_system.set_npc_recruited(NPC_ID, true), "Could not recruit Owen for equipment synchronization verification")
	resource_system.add_resource("item_sword_shield", 1)
	var sword_result: Dictionary = equipment_system.equip_npc_main_weapon(NPC_ID, "sword_shield", "private")
	check(bool(sword_result.get("ok", false)), "Could not equip Owen with a real sword and shield")
	npc_system.update_npc_state(NPC_ID, {"current_action": "receive_weapon_training"})
	await process_frame
	var training: Dictionary = owen.debug_get_character_art_snapshot()
	check(str(training.get("desired_state", "")) == "training_practice", "Owen's real training action did not select practice animation")
	check(str(training.get("authority_main_weapon_id", "")) == "sword_shield", "Owen's real weapon authority did not reach presentation")
	check(bool(training.get("sword_visible", false)) and bool(training.get("shield_visible", false)), "Owen's real sword and shield are not visible during training")
	check(not bool(training.get("engineer_wrench_visible", true)), "Owen kept his wrench during weapon training")
	var unequip_result: Dictionary = equipment_system.unequip_npc_slot(NPC_ID, "main_weapon", "private")
	check(bool(unequip_result.get("ok", false)), "Could not remove Owen's test weapon")
	await process_frame
	var unarmed: Dictionary = owen.debug_get_character_art_snapshot()
	check(not bool(unarmed.get("sword_visible", true)) and not bool(unarmed.get("shield_visible", true)), "Owen kept false combat props after authoritative unequip")
	npc_system.update_npc_state(NPC_ID, {"current_action": "idle"})
	await process_frame

	var damage_result: Dictionary = npc_system.debug_damage_npc(NPC_ID, 9999)
	check(bool(damage_result.get("ok", false)), "Owen authoritative damage entry failed")
	await process_frame
	var unconscious: Dictionary = owen.debug_get_character_art_snapshot()
	check(str(unconscious.get("desired_state", "")) == "unconscious", "Owen unconscious state did not select the fall clip")
	check(bool(unconscious.get("engineer_goggles_visible", false)) and bool(unconscious.get("engineer_tool_belt_visible", false)), "Owen's identity accessories disappeared while unconscious")
	check(not bool(unconscious.get("engineer_wrench_visible", true)), "Owen kept his work tool while unconscious")
	var recovery_result: Dictionary = npc_system.debug_advance_unconscious_recovery(NPC_ID, 100.0 * 3600.0)
	check(not (recovery_result.get("revived", []) as Array).is_empty(), "Owen did not revive through the authority recovery API")
	await process_frame
	check(str(owen.debug_get_character_art_snapshot().get("desired_state", "")) == "get_up", "Owen revival did not select get-up")
	finish()


func verify_profile_sync() -> void:
	var file := FileAccess.open("res://data/npc_profiles.json", FileAccess.READ)
	check(file != null, "npc_profiles.json unavailable")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	check(parsed is Array, "npc_profiles.json root is not an array")
	if not parsed is Array:
		return
	var profile: Dictionary = {}
	for raw_profile in parsed:
		if raw_profile is Dictionary and str(raw_profile.get("id", "")) == NPC_ID:
			profile = raw_profile
			break
	check(not profile.is_empty(), "Owen profile unavailable")
	if profile.is_empty():
		return
	check(str(profile.get("appearance", "")) == EXPECTED_PROFILE_APPEARANCE, "Owen profile does not match the current chibi art")
	check(not str(profile.get("background_story", "")).is_empty(), "Owen background story was damaged")
	var setting: Dictionary = NPCPromptProfile.build_setting(profile)
	check(str(setting.get("appearance", "")) == EXPECTED_PROFILE_APPEARANCE, "Owen appearance did not reach npc_setting")


func _get_npc_node(npc_system: Node) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(NPC_ID, NodePath("")))


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func finish() -> void:
	if _failures.is_empty():
		print("T0130_P8_OWEN_CHARACTER_INTEGRATION PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0130_P8_OWEN_CHARACTER_INTEGRATION FAIL count=%d" % _failures.size())
	quit(1)
