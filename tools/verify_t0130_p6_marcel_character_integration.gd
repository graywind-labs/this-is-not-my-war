extends SceneTree


const NPC_ID := "priest_01"
const EXPECTED_APPEARANCE_ID := "marcel_priest_chibi_v1"
const EXPECTED_PROFILE_APPEARANCE := "灰白长发和胡须修得整齐，暗紫旧袍压着褪色金边，胸前挂着木质圣徽，眼神温和但并不软弱。"
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
	var startup_plan_system := main.get_node_or_null("Systems/DailyPlanSystem")
	if startup_plan_system != null:
		startup_plan_system.set_auto_execution_enabled(false)
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var marcel := _get_npc_node(npc_system, NPC_ID) if npc_system != null else null
	if [npc_system, time_system, marcel].has(null):
		_failures.append("T0130-P6 runtime dependencies unavailable")
		finish()
		return
	time_system.set_paused(false)
	npc_system.update_npc_state(NPC_ID, {
		"unconscious": false,
		"fatigue": 0,
		"satiety": 100,
		"current_action": "idle",
		"last_action_result": "verify_t0130_p6_ready",
	})
	await process_frame

	var initial: Dictionary = marcel.debug_get_character_art_snapshot()
	check(bool(initial.get("ready", false)), "Marcel chibi art did not become ready")
	check(str(initial.get("appearance_id", "")) == EXPECTED_APPEARANCE_ID, "Marcel still uses the legacy fallback")
	check(bool(initial.get("use_imported_character_material", false)), "Marcel does not preserve the authored Synty material")
	check(str(initial.get("palette_path", "")).ends_with("PolygonMinis_Texture_Purple_A.png"), "Marcel does not use the subdued priest palette")
	check(bool(initial.get("remove_detached_headwear", false)), "Marcel's wizard headwear filter is disabled")
	check(int(initial.get("removed_headwear_triangle_count", 0)) == 114, "Marcel's audited 114-triangle wizard hat topology changed or was not removed")
	check(bool(initial.get("wooden_cross_visible", false)), "Marcel's wooden cross is missing")
	check(str(initial.get("wooden_cross_parent", "")) == "Body", "Marcel's wooden cross does not follow the chest bone")
	check(bool(initial.get("rounded_tonsure_hair_visible", false)), "Marcel's rounded hair crown is missing")
	check(str(initial.get("rounded_tonsure_hair_parent", "")) == "Head", "Marcel's rounded hair crown does not follow the head bone")
	check(int(initial.get("rounded_tonsure_hair_mesh_count", 0)) == 1, "Marcel's rounded hair crown topology changed")
	check(str(initial.get("equipment_mode", "")) == "none", "Marcel inherited another profession's equipment")
	check(not marcel.get_node("BodyCollision").disabled, "Marcel body collision was replaced by art")
	check(not marcel.get_node("InteractionArea/InteractionCollision").disabled, "Marcel interaction collision was replaced by art")
	check(not marcel.get_node("LegacyVisuals").visible, "Marcel legacy mesh is still visible")
	check(marcel.find_child("SelectionArea", true, false) == null, "Marcel production art added a duplicate selection collider")
	var rounded_hair := marcel.find_child("RoundedTonsureHair", true, false)
	check(rounded_hair != null and rounded_hair.find_children("*", "CollisionShape3D", true, false).is_empty(), "Marcel's visual hair crown added gameplay collision")
	var target_mesh := marcel.find_child("SK_Fantasy_Wizard_01", true, false) as MeshInstance3D
	var authored_material := target_mesh.material_override as BaseMaterial3D if target_mesh != null else null
	check(target_mesh != null, "Marcel's authored Synty body mesh is missing")
	check(authored_material != null and authored_material.vertex_color_use_as_albedo, "Marcel lost authored face/robe vertex colors")
	check(authored_material != null and authored_material.albedo_texture != null and authored_material.albedo_texture.resource_path.ends_with("PolygonMinis_Texture_Purple_A.png"), "Marcel's imported material does not bind the priest palette")

	var action_before_preview := str(npc_system.get_npc_state(NPC_ID).get("current_action", ""))
	var expected_states := {
		"walk": "Walking_A",
		"talk": "Waving",
		"work": "Working_A",
		"mass_leader": "Ranged_Magic_Spellcasting_Long",
		"seated_prayer": "Sit_Chair_Idle",
	}
	for state_name in expected_states.keys():
		var preview: Dictionary = marcel.debug_force_character_animation(str(state_name))
		check(str(preview.get("current_clip", "")) == str(expected_states[state_name]), "Marcel state '%s' selected the wrong clip" % state_name)
		check(bool(preview.get("wooden_cross_visible", false)), "Marcel's cross disappeared in state '%s'" % state_name)
		check(bool(preview.get("rounded_tonsure_hair_visible", false)), "Marcel's rounded hair crown disappeared in state '%s'" % state_name)
		check(not bool(preview.get("hammer_visible", true)) and not bool(preview.get("garden_hoe_visible", true)) and not bool(preview.get("cook_spoon_visible", true)), "Marcel displays another profession's tool in state '%s'" % state_name)
	check(int(marcel.debug_get_character_art_snapshot().get("mass_leader_clip_loop_mode", Animation.LOOP_NONE)) == Animation.LOOP_LINEAR, "Marcel's Mass gesture is not cyclic")
	check(int(marcel.debug_get_character_art_snapshot().get("work_clip_loop_mode", Animation.LOOP_NONE)) == Animation.LOOP_LINEAR, "Marcel's brewing gesture is not cyclic")
	check(str(npc_system.get_npc_state(NPC_ID).get("current_action", "")) == action_before_preview, "Animation preview changed Marcel's authoritative action")
	npc_system.update_npc_state(NPC_ID, {"current_action": "idle"})
	await process_frame

	var damage_result: Dictionary = npc_system.debug_damage_npc(NPC_ID, 9999)
	check(bool(damage_result.get("ok", false)), "Marcel authoritative damage entry failed")
	await process_frame
	var unconscious: Dictionary = marcel.debug_get_character_art_snapshot()
	check(str(unconscious.get("desired_state", "")) == "unconscious", "Marcel unconscious state did not select the fall clip")
	check(bool(unconscious.get("wooden_cross_visible", false)), "Marcel's identity cross disappeared while unconscious")
	check(bool(unconscious.get("rounded_tonsure_hair_visible", false)), "Marcel's rounded hair crown disappeared while unconscious")
	var recovery_result: Dictionary = npc_system.debug_advance_unconscious_recovery(NPC_ID, 100.0 * 3600.0)
	check(not (recovery_result.get("revived", []) as Array).is_empty(), "Marcel did not revive through the authority recovery API")
	await process_frame
	check(str(marcel.debug_get_character_art_snapshot().get("desired_state", "")) == "get_up", "Marcel revival did not select get-up")
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
	check(not profile.is_empty(), "Marcel profile unavailable")
	if profile.is_empty():
		return
	check(str(profile.get("appearance", "")) == EXPECTED_PROFILE_APPEARANCE, "Marcel profile does not match the current chibi art")
	check(not str(profile.get("background_story", "")).is_empty(), "Marcel background story was damaged")
	var setting: Dictionary = NPCPromptProfile.build_setting(profile)
	check(str(setting.get("appearance", "")) == EXPECTED_PROFILE_APPEARANCE, "Marcel appearance did not reach npc_setting")
	check(not setting.has("signature_lines"), "Marcel npc_setting reintroduced fixed signature lines")


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func finish() -> void:
	if _failures.is_empty():
		print("T0130_P6_MARCEL_CHARACTER_INTEGRATION PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0130_P6_MARCEL_CHARACTER_INTEGRATION FAIL count=%d" % _failures.size())
	quit(1)
