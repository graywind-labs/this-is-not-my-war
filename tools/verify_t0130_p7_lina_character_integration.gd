extends SceneTree


const NPC_ID := "doctor_01"
const EXPECTED_APPEARANCE_ID := "lina_doctor_chibi_v1"

var _failures: Array[String] = []


func _init() -> void:
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
	var lina := _get_npc_node(npc_system) if npc_system != null else null
	if [npc_system, time_system, lina].has(null):
		_failures.append("T0130-P7 runtime dependencies unavailable")
		finish()
		return
	time_system.set_paused(false)
	npc_system.update_npc_state(NPC_ID, {
		"hp": 100,
		"unconscious": false,
		"fatigue": 0,
		"satiety": 100,
		"current_action": "idle",
		"last_action_result": "verify_t0130_p7_ready",
	})
	await process_frame

	var initial: Dictionary = lina.debug_get_character_art_snapshot()
	check(bool(initial.get("ready", false)), "Lina chibi art did not become ready")
	check(str(initial.get("appearance_id", "")) == EXPECTED_APPEARANCE_ID, "Lina still uses the legacy fallback")
	check(str(initial.get("equipment_mode", "")) == "medical_kit", "Lina does not use the medical-kit presentation contract")
	check(bool(initial.get("use_imported_character_material", false)), "Lina does not preserve the authored Synty material")
	check(str(initial.get("palette_path", "")).ends_with("PolygonMinis_Texture_Blue_A.png"), "Lina does not use the restrained blue medical palette")
	check(float(initial.get("palette_saturation", 1.0)) <= 0.5, "Lina palette is not restrained enough")
	check((initial.get("state_contract", []) as Array).has("medical_treatment"), "Shared chibi state contract is missing medical_treatment")
	check(bool(initial.get("medical_satchel_visible", false)), "Lina's medical satchel is missing at idle")
	check(str(initial.get("medical_satchel_parent", "")) == "Body", "Lina's medical satchel does not follow the body socket")
	check(not bool(initial.get("medical_book_visible", true)), "Lina shows her clinic book at idle")
	check(not bool(initial.get("medical_bandage_visible", true)), "Lina shows a bandage before treatment")
	check(str(initial.get("equipment_mode", "")) == "medical_kit", "Lina inherited another profession's equipment")
	check(not bool(initial.get("hammer_visible", true)) and not bool(initial.get("garden_hoe_visible", true)) and not bool(initial.get("cook_spoon_visible", true)), "Lina displays another profession's tool")
	check(not lina.get_node("BodyCollision").disabled, "Lina body collision was replaced by art")
	check(not lina.get_node("InteractionArea/InteractionCollision").disabled, "Lina interaction collision was replaced by art")
	check(not lina.get_node("LegacyVisuals").visible, "Lina legacy mesh is still visible")
	check(lina.find_child("SelectionArea", true, false) == null, "Lina production art added a duplicate selection collider")
	var target_mesh := lina.find_child("SK_Pirates_GovDaughter_01", true, false) as MeshInstance3D
	var authored_material := target_mesh.material_override as BaseMaterial3D if target_mesh != null else null
	check(target_mesh != null, "Lina's selected Synty body mesh is missing")
	check(authored_material != null and authored_material.vertex_color_use_as_albedo, "Lina lost authored face and clothing vertex colors")
	check(authored_material != null and authored_material.albedo_texture != null and authored_material.albedo_texture.resource_path.ends_with("PolygonMinis_Texture_Blue_A.png"), "Lina imported material does not bind the blue authored Albedo")
	for accessory_name in ["MedicalSatchel", "MedicalBook", "BandageRoll"]:
		var accessory := lina.find_child(accessory_name, true, false)
		check(accessory != null, "Lina accessory is missing: %s" % accessory_name)
		if accessory != null:
			check(accessory.find_children("*", "CollisionShape3D", true, false).is_empty(), "Lina visual accessory added gameplay collision: %s" % accessory_name)
			check(accessory.find_children("*", "Area3D", true, false).is_empty(), "Lina visual accessory added an interaction area: %s" % accessory_name)

	var action_before_preview := str(npc_system.get_npc_state(NPC_ID).get("current_action", ""))
	var expected_states := {
		"walk": "Walking_A",
		"talk": "Waving",
		"sleeping": "Lie_Idle",
	}
	for state_name in expected_states.keys():
		var preview: Dictionary = lina.debug_force_character_animation(str(state_name))
		check(str(preview.get("current_clip", "")) == str(expected_states[state_name]), "Lina state '%s' selected the wrong clip" % state_name)
		check(bool(preview.get("medical_satchel_visible", false)), "Lina's medical satchel disappeared in state '%s'" % state_name)
		check(not bool(preview.get("medical_book_visible", true)) and not bool(preview.get("medical_bandage_visible", true)), "Lina shows an active medical prop in state '%s'" % state_name)

	var clinic_work: Dictionary = lina.debug_force_character_animation("work")
	check(str(clinic_work.get("current_clip", "")) == "Working_B", "Lina clinic-duty preview does not use Working_B")
	check(bool(clinic_work.get("medical_book_visible", false)) and not bool(clinic_work.get("medical_bandage_visible", true)), "Lina clinic-duty preview does not show only the medical book")
	check(int(clinic_work.get("work_clip_loop_mode", Animation.LOOP_NONE)) == Animation.LOOP_LINEAR, "Lina clinic-duty animation is not cyclic")
	var treatment: Dictionary = lina.debug_force_character_animation("medical_treatment")
	check(str(treatment.get("current_clip", "")) == "Working_A", "Lina treatment preview does not use Working_A")
	check(bool(treatment.get("medical_bandage_visible", false)) and not bool(treatment.get("medical_book_visible", true)), "Lina treatment preview does not show only the bandage roll")
	check(int(treatment.get("medical_treatment_clip_loop_mode", Animation.LOOP_NONE)) == Animation.LOOP_LINEAR, "Lina treatment animation is not cyclic")
	check(str(npc_system.get_npc_state(NPC_ID).get("current_action", "")) == action_before_preview, "Animation preview changed Lina's authoritative action")
	npc_system.update_npc_state(NPC_ID, {"current_action": "idle"})
	await process_frame

	var damage_result: Dictionary = npc_system.debug_damage_npc(NPC_ID, 9999)
	check(bool(damage_result.get("ok", false)), "Lina authoritative damage entry failed")
	await process_frame
	var unconscious: Dictionary = lina.debug_get_character_art_snapshot()
	check(str(unconscious.get("desired_state", "")) == "unconscious", "Lina unconscious state did not select the fall clip")
	check(bool(unconscious.get("medical_satchel_visible", false)), "Lina's identity satchel disappeared while unconscious")
	check(not bool(unconscious.get("medical_book_visible", true)) and not bool(unconscious.get("medical_bandage_visible", true)), "Lina kept active treatment props while unconscious")
	var recovery_result: Dictionary = npc_system.debug_advance_unconscious_recovery(NPC_ID, 100.0 * 3600.0)
	check(not (recovery_result.get("revived", []) as Array).is_empty(), "Lina did not revive through the authority recovery API")
	await process_frame
	check(str(lina.debug_get_character_art_snapshot().get("desired_state", "")) == "get_up", "Lina revival did not select get-up")
	finish()


func _get_npc_node(npc_system: Node) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(NPC_ID, NodePath("")))


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func finish() -> void:
	if _failures.is_empty():
		print("T0130_P7_LINA_CHARACTER_INTEGRATION PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0130_P7_LINA_CHARACTER_INTEGRATION FAIL count=%d" % _failures.size())
	quit(1)
