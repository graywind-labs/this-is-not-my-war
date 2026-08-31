extends SceneTree


const NPC_SCENE_PATH := "res://scenes/npc/NPC.tscn"
const GLEN_ID := "blacksmith_01"
const REQUIRED_STATES := [
	"idle", "walk", "run", "talk", "work", "training_instructor", "training_practice", "mass_leader", "seated_prayer", "attack", "hit_react", "unconscious", "get_up"
]
const REQUIRED_SOCKETS := {
	"RightHand": "RightHand",
	"LeftHand": "LeftHand",
	"Back": "UpperChest",
	"Head": "Head",
	"Body": "Chest",
	"Mount": "Hips"
}


func _init() -> void:
	var npc_scene := load(NPC_SCENE_PATH) as PackedScene
	if npc_scene == null:
		_fail("Failed to load NPC scene")
		return

	var glen := npc_scene.instantiate()
	root.add_child(glen)
	var profile := _make_profile(GLEN_ID, "格伦")
	glen.setup(profile)
	await process_frame
	await process_frame

	var initial: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(bool(initial.get("ready", false)), "Glen formal art view is not ready"):
		return
	if not _expect(str(initial.get("appearance_id", "")) == "glen_blacksmith_chibi_v1", "Glen appearance mapping is wrong"):
		return
	if not _expect(str(initial.get("authority_role", "")) == "presentation_only", "Character art must remain presentation-only"):
		return
	if not _expect(int(initial.get("rebound_mesh_count", 0)) >= 1, "Synty character mesh was not bound to the retargeted rig"):
		return
	if not _expect(bool(initial.get("ragdoll_placeholder_ready", false)), "Physical bone simulator placeholder is missing"):
		return
	if not _expect(str(initial.get("hammer_parent", "")) == "Back", "Idle smith hammer should be stored on the back socket"):
		return

	var state_contract: Array = initial.get("state_contract", [])
	var state_clips: Dictionary = initial.get("state_clips", {})
	var available_clips: Array = initial.get("available_clips", [])
	for state_name in REQUIRED_STATES:
		if not _expect(state_contract.has(state_name), "Animation state contract is missing %s" % state_name):
			return
		var clip_name := str(state_clips.get(state_name, ""))
		if not _expect(not clip_name.is_empty() and available_clips.has(clip_name), "Animation state %s has no real UAL2 clip" % state_name):
			return

	var socket_contract: Dictionary = initial.get("socket_contract", {})
	for raw_socket_name in REQUIRED_SOCKETS.keys():
		var socket_name := str(raw_socket_name)
		var socket: Dictionary = socket_contract.get(socket_name, {}) if socket_contract.get(socket_name, {}) is Dictionary else {}
		if not _expect(bool(socket.get("present", false)), "Equipment socket is missing: %s" % socket_name):
			return
		if not _expect(str(socket.get("bone", "")) == str(REQUIRED_SOCKETS[socket_name]), "Equipment socket uses the wrong bone: %s" % socket_name):
			return

	# Movement stays program-authoritative; the non-root-motion animation follows it and faces the target.
	var start_position: Vector3 = glen.global_position
	glen.move_to_location("t0128_walk_target", Vector3(8.0, 0.0, 0.0))
	await create_timer(0.14).timeout
	var walking: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(str(walking.get("desired_state", "")) == "walk", "Program movement did not select the walk animation"):
		return
	if not _expect(glen.global_position.distance_to(start_position) > 0.2, "NPC did not move under the existing movement authority"):
		return
	glen.stop_movement()

	profile.states.current_action = "work_blacksmith"
	glen.update_profile(profile)
	await create_timer(0.14).timeout
	var working: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(str(working.get("desired_state", "")) == "work", "Blacksmith work did not select the work animation"):
		return
	if not _expect(str(working.get("hammer_parent", "")) == "RightHand", "Blacksmith work did not move the hammer to the right hand socket"):
		return

	profile.states.current_action = "idle"
	profile.states.hp = 85
	glen.update_profile(profile)
	await process_frame
	if not _expect(str(glen.debug_get_character_art_snapshot().get("desired_state", "")) == "hit_react", "HP loss did not trigger hit reaction presentation"):
		return

	profile.states.hp = 0
	profile.states.unconscious = true
	profile.states.current_action = "unconscious"
	glen.update_profile(profile)
	await process_frame
	if not _expect(str(glen.debug_get_character_art_snapshot().get("desired_state", "")) == "unconscious", "Authoritative unconscious state did not select fall presentation"):
		return
	await create_timer(1.8).timeout
	var settled_unconscious: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(not bool(settled_unconscious.get("current_animation_playing", true)), "Unconscious fall clip did not settle on its final pose"):
		return
	var settled_position := float(settled_unconscious.get("current_animation_position", 0.0))
	var settled_length := float(settled_unconscious.get("current_animation_length", 0.0))
	for _refresh in range(3):
		glen.update_profile(profile)
		await process_frame
	var refreshed_unconscious: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(
		not bool(refreshed_unconscious.get("current_animation_playing", true))
		and str(refreshed_unconscious.get("desired_state", "")) == "unconscious"
		and is_equal_approx(float(refreshed_unconscious.get("current_animation_position", -1.0)), settled_position)
		and settled_length > 0.0
		and settled_position >= settled_length - 0.05,
		"Repeated unconscious profile refresh replayed the one-shot fall clip"
	):
		return

	profile.states.hp = 30
	profile.states.unconscious = false
	profile.states.current_action = "idle"
	glen.update_profile(profile)
	await process_frame
	if not _expect(str(glen.debug_get_character_art_snapshot().get("desired_state", "")) == "get_up", "Revival did not select get-up presentation"):
		return
	await create_timer(1.35).timeout
	if not _expect(str(glen.debug_get_character_art_snapshot().get("desired_state", "")) == "idle", "Get-up presentation did not return to authoritative idle"):
		return

	profile.states.current_action = "attacking_enemy_t0128"
	glen.update_profile(profile)
	await process_frame
	if not _expect(str(glen.debug_get_character_art_snapshot().get("desired_state", "")) == "attack", "Attack action did not select attack presentation"):
		return

	for state_name in REQUIRED_STATES:
		var forced: Dictionary = glen.debug_force_character_animation(state_name)
		if not _expect(bool(forced.get("ready", false)), "Failed to preview animation state: %s" % state_name):
			return
		if not _expect(str(forced.get("desired_state", "")) == state_name, "Animation preview did not enter state: %s" % state_name):
			return
		if state_name == "work" and not _expect(str(forced.get("hammer_parent", "")) == "RightHand", "Work preview did not attach the hammer to RightHand"):
			return
	if not _expect(str(profile.states.current_action) == "attacking_enemy_t0128" and int(profile.states.hp) == 30, "Animation preview mutated authoritative caller state"):
		return

	# A5-P5a/P5c/P5d add the other characters whose formal work slices are live.
	var toma := npc_scene.instantiate()
	root.add_child(toma)
	var toma_profile := _make_profile("stableman_01", "托马")
	toma_profile.states.current_action = "work_stable"
	toma.setup(toma_profile)
	await process_frame
	var toma_art: Dictionary = toma.debug_get_character_art_snapshot()
	if not _expect(
		bool(toma_art.get("ready", false))
		and str(toma_art.get("appearance_id", "")) == "toma_stableman_chibi_v1"
		and str(toma_art.get("desired_state", "")) == "work"
		and str(toma_art.get("current_clip", "")) == "Working_B"
		and bool(toma_art.get("stable_broom_visible", false))
		and not bool(toma_art.get("hammer_visible", true)),
		"Toma's formal stable-work presentation contract is incomplete"
	):
		return
	var owen := npc_scene.instantiate()
	root.add_child(owen)
	var owen_profile := _make_profile("engineer_01", "欧文")
	owen_profile.states.current_action = "work_workshop"
	owen.setup(owen_profile)
	await process_frame
	var owen_art: Dictionary = owen.debug_get_character_art_snapshot()
	if not _expect(
		bool(owen_art.get("ready", false))
		and str(owen_art.get("appearance_id", "")) == "owen_engineer_chibi_v1"
		and str(owen_art.get("desired_state", "")) == "work"
		and bool(owen_art.get("engineer_wrench_visible", false))
		and not bool(owen_art.get("hammer_visible", true)),
		"Owen's formal workshop-work presentation contract is incomplete"
	):
		return
	var bruno := npc_scene.instantiate()
	root.add_child(bruno)
	var bruno_profile := _make_profile("cook_01", "布鲁诺")
	bruno_profile.states.current_action = "work_dining_hall"
	bruno.setup(bruno_profile)
	await process_frame
	var bruno_art: Dictionary = bruno.debug_get_character_art_snapshot()
	if not _expect(
		bool(bruno_art.get("ready", false))
		and str(bruno_art.get("appearance_id", "")) == "bruno_cook_chibi_v1"
		and str(bruno_art.get("desired_state", "")) == "work"
		and str(bruno_art.get("current_clip", "")) == "Working_C"
		and bool(bruno_art.get("cook_spoon_visible", false))
		and not bool(bruno_art.get("hammer_visible", true)),
		"Bruno's formal dining-hall work presentation contract is incomplete"
	):
		return

	var ivo := npc_scene.instantiate()
	root.add_child(ivo)
	var ivo_profile := _make_profile("gardener_01", "伊沃")
	ivo_profile.states.current_action = "work_garden"
	ivo.setup(ivo_profile)
	await process_frame
	var ivo_art: Dictionary = ivo.debug_get_character_art_snapshot()
	if not _expect(
		bool(ivo_art.get("ready", false))
		and str(ivo_art.get("appearance_id", "")) == "ivo_gardener_chibi_v1"
		and str(ivo_art.get("desired_state", "")) == "work"
		and str(ivo_art.get("current_clip", "")) == "Digging"
		and bool(ivo_art.get("garden_hoe_visible", false))
		and not bool(ivo_art.get("hammer_visible", true)),
		"Ivo's formal garden-work presentation contract is incomplete"
	):
		return
	ivo_profile.states.current_action = "pray_at_chapel"
	ivo.update_profile(ivo_profile)
	await process_frame
	ivo_art = ivo.debug_get_character_art_snapshot()
	if not _expect(
		str(ivo_art.get("desired_state", "")) == "seated_prayer"
		and int(ivo_art.get("seated_prayer_clip_loop_mode", 0)) != 0
		and not bool(ivo_art.get("garden_hoe_visible", true))
		and float((ivo_art.get("presentation_pose_offset", Vector3.ZERO) as Vector3).y) < -0.5,
		"Ivo's seated-prayer loop and bench pose offset are incomplete"
	):
		return

	var marcel := npc_scene.instantiate()
	root.add_child(marcel)
	var marcel_profile := _make_profile("priest_01", "马塞尔")
	marcel_profile.states.current_action = "work_tavern"
	marcel.setup(marcel_profile)
	await process_frame
	var marcel_art: Dictionary = marcel.debug_get_character_art_snapshot()
	if not _expect(
		bool(marcel_art.get("ready", false))
		and str(marcel_art.get("appearance_id", "")) == "marcel_priest_chibi_v1"
		and str(marcel_art.get("desired_state", "")) == "work"
		and str(marcel_art.get("current_clip", "")) == "Working_A"
		and int(marcel_art.get("work_clip_loop_mode", 0)) != 0
		and int(marcel_art.get("removed_headwear_triangle_count", 0)) == 114
		and bool(marcel_art.get("wooden_cross_visible", false))
		and not bool(marcel_art.get("hammer_visible", true)),
		"Marcel's formal tavern-work presentation contract is incomplete"
	):
		return
	marcel_profile.states.current_action = "lead_mass"
	marcel.update_profile(marcel_profile)
	await process_frame
	marcel_art = marcel.debug_get_character_art_snapshot()
	if not _expect(
		str(marcel_art.get("desired_state", "")) == "mass_leader"
		and str(marcel_art.get("current_clip", "")) == "Ranged_Magic_Spellcasting_Long"
		and int(marcel_art.get("mass_leader_clip_loop_mode", 0)) != 0
		and bool(marcel_art.get("wooden_cross_visible", false))
		and not bool(marcel_art.get("hammer_visible", true)),
		"Marcel's looping Mass-leader presentation contract is incomplete"
	):
		return

	var lina := npc_scene.instantiate()
	root.add_child(lina)
	var lina_profile := _make_profile("doctor_01", "莉娜")
	lina_profile.states.current_action = "work_clinic_doctor"
	lina.setup(lina_profile)
	await process_frame
	var lina_art: Dictionary = lina.debug_get_character_art_snapshot()
	if not _expect(
		bool(lina_art.get("ready", false))
		and str(lina_art.get("appearance_id", "")) == "lina_doctor_chibi_v1"
		and str(lina_art.get("desired_state", "")) == "work"
		and str(lina_art.get("current_clip", "")) == "Working_B"
		and float(lina_art.get("work_cycle_length", 0.0)) > 0.0
		and int(lina_art.get("work_clip_loop_mode", 0)) != 0
		and bool(lina_art.get("medical_satchel_visible", false))
		and bool(lina_art.get("medical_book_visible", false))
		and not bool(lina_art.get("medical_bandage_visible", true))
		and not bool(lina_art.get("hammer_visible", true)),
		"Lina's formal clinic-duty presentation contract is incomplete"
	):
		return

	var ada := npc_scene.instantiate()
	root.add_child(ada)
	var ada_profile := _make_profile("veteran_deputy_01", "艾达")
	ada_profile.equipment = {"main_weapon": {"id": "sword_shield"}}
	ada_profile.states.current_action = "work_training_instructor"
	ada.setup(ada_profile)
	await process_frame
	var ada_art: Dictionary = ada.debug_get_character_art_snapshot()
	if not _expect(
		bool(ada_art.get("ready", false))
		and str(ada_art.get("appearance_id", "")) == "ada_veteran_deputy_chibi_v1"
		and str(ada_art.get("desired_state", "")) == "training_instructor"
		and int(ada_art.get("training_instructor_clip_loop_mode", 0)) != 0
		and bool(ada_art.get("sword_visible", false))
		and bool(ada_art.get("shield_visible", false))
		and not bool(ada_art.get("hammer_visible", true)),
		"Ada's looping instructor presentation contract is incomplete"
	):
		return

	var trainee := npc_scene.instantiate()
	root.add_child(trainee)
	var trainee_profile := _make_profile("blacksmith_01", "格伦")
	trainee_profile.states.current_action = "receive_weapon_training"
	trainee.setup(trainee_profile)
	await process_frame
	var trainee_art: Dictionary = trainee.debug_get_character_art_snapshot()
	if not _expect(
		str(trainee_art.get("desired_state", "")) == "training_practice"
		and int(trainee_art.get("training_practice_clip_loop_mode", 0)) != 0
		and not bool(trainee_art.get("hammer_visible", true)),
		"Trainee practice must loop without carrying the smith hammer"
	):
		return

	# Unknown future NPCs still retain the legacy placeholder.
	var legacy_npc := npc_scene.instantiate()
	root.add_child(legacy_npc)
	legacy_npc.setup(_make_profile("future_npc_legacy_01", "未登记角色"))
	await process_frame
	if not _expect(not bool(legacy_npc.debug_get_character_art_snapshot().get("ready", true)), "An unregistered NPC received a formal appearance"):
		return
	if not _expect(legacy_npc.get_node("LegacyVisuals").visible, "Legacy fallback was hidden without a formal appearance"):
		return

	print("T0128 character animation verification passed: %s" % JSON.stringify(initial))
	quit(0)


func _make_profile(npc_id: String, display_name: String) -> Dictionary:
	return {
		"id": npc_id,
		"name": display_name,
		"recruited": false,
		"states": {
			"hp": 100,
			"max_hp": 100,
			"current_action": "idle",
			"behavior_mode": "work",
			"unconscious": false,
			"escaped": false,
			"morale_boost": {},
			"escape_intent": {}
		},
		"equipment": {}
	}


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
