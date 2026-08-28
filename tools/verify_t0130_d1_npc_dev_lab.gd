extends SceneTree

const MOUNTED_PRESENTATION_REFERENCE := preload("res://scripts/presentation/characters/MountedPresentationReference.gd")


const EXPECTED_ENEMY_IDS := [
	"enemy:raider_sword",
	"enemy:raider_polearm",
	"enemy:raider_archer",
	"enemy:raider_crossbow",
	"enemy:raider_cavalry",
	"enemy:raider_sword_veteran",
	"enemy:raider_mounted_archer",
]
const EXPECTED_ENEMY_LOADOUTS := {
	"enemy:raider_sword": {"weapon": "sword_shield", "mounted": false, "visible": "sword_visible"},
	"enemy:raider_polearm": {"weapon": "polearm", "mounted": false, "visible": "polearm_visible"},
	"enemy:raider_archer": {"weapon": "bow", "mounted": false, "visible": "bow_visible"},
	"enemy:raider_crossbow": {"weapon": "crossbow", "mounted": false, "visible": "crossbow_visible"},
	"enemy:raider_cavalry": {"weapon": "sword_shield", "mounted": true, "visible": "sword_visible"},
	"enemy:raider_sword_veteran": {"weapon": "sword_shield", "mounted": false, "visible": "sword_visible"},
	"enemy:raider_mounted_archer": {"weapon": "bow", "mounted": true, "visible": "bow_visible"},
}
const FRIENDLY_IDS := [
	"stableman_01", "cook_01", "gardener_01", "blacksmith_01",
	"veteran_deputy_01", "priest_01", "doctor_01", "engineer_01",
]
const SHARED_PROFESSION_ACTIONS := {
	"work_blacksmith": {"clip": "Hammering", "tool": "hammer_visible"},
	"work_stable": {"clip": "Working_B", "tool": "stable_broom_visible"},
	"work_dining_hall": {"clip": "Working_C", "tool": "cook_spoon_visible"},
	"work_garden": {"clip": "Digging", "tool": "garden_hoe_visible"},
	"work_tavern": {"clip": "Working_A", "tool": ""},
	"work_clinic_doctor": {"clip": "Seated_Study_Idle", "tool": "medical_book_visible"},
	"work_workshop": {"clip": "Working_A", "tool": "engineer_wrench_visible"},
	"training_instructor": {"clip": "Melee_Block_Attack", "tool": ""},
	"medical_treatment": {"clip": "Working_A", "tool": "medical_bandage_visible"},
}
const MOUNTED_ACTION_EXPECTATIONS := {
	"walk": {"state": "mounted_walk", "clip": "Mounted_Walk", "horse_clip": "Walk"},
	"run": {"state": "mounted_walk", "clip": "Mounted_Walk", "horse_clip": "Gallop"},
	"hit_react": {"state": "mounted_hit_react", "clip": "Mounted_Hit", "horse_clip": "Idle_HitReact1"},
	"training_practice": {"state": "mounted_training", "clip": "Mounted_Training", "horse_clip": "Idle"},
}


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/debug/NPCDevLab.tscn") as PackedScene
	if packed == null:
		_fail("NPCDevLab.tscn failed to load")
		return
	var lab := packed.instantiate()
	root.add_child(lab)
	for _frame in 8:
		await process_frame

	var snapshot: Dictionary = lab.debug_get_snapshot()
	_assert(bool(snapshot.get("ready", false)), "developer lab should be ready")
	_assert(int(snapshot.get("friendly_count", 0)) == 8, "all eight friendly NPCs should be present")
	_assert(int(snapshot.get("enemy_count", 0)) == EXPECTED_ENEMY_IDS.size(), "enemy_waves enemy types should be deduplicated")
	_assert(int(snapshot.get("unit_count", 0)) == 8 + EXPECTED_ENEMY_IDS.size(), "unit selector count should match friendly + unique enemy types")
	for enemy_id in EXPECTED_ENEMY_IDS:
		_assert((snapshot.get("unit_ids", []) as Array).has(enemy_id), "missing enemy selector entry %s" % enemy_id)
	_assert(str(snapshot.get("selected_unit_id", "")) == "stableman_01", "profile order should select Toma first")
	_assert(str(snapshot.get("mode", "")) == "work", "friendly units should begin in work mode")
	_assert(str(snapshot.get("mode_scope", "")) == "shared_across_units", "mode should declare cross-unit scope")
	_assert(str(snapshot.get("loadout_scope", "")) == "shared_across_friendlies", "friendly loadout should declare cross-friendly scope")
	_assert(not bool(snapshot.get("enemy_equipment_locked", true)), "friendly equipment slots should remain editable")
	_assert((snapshot.get("usable_actions", []) as Array).has("attack"), "combat action should remain clickable for automatic mode switching")
	_assert((snapshot.get("disabled_actions", []) as Array).has("mounted_pose"), "mounted action should remain disabled until a shared mount is equipped")
	_assert((snapshot.get("usable_actions", []) as Array).has("work_dining_hall"), "Toma should expose cross-profession cooking")
	_assert((snapshot.get("usable_actions", []) as Array).has("work_blacksmith"), "Toma should expose cross-profession blacksmith work")
	_assert((snapshot.get("usable_actions", []) as Array).has("drink_wine"), "friendly NPCs should expose the work-mode drinking action")
	_assert(not (snapshot.get("usable_actions", []) as Array).has("mass_leader"), "Toma must not expose priest-only mass leadership")
	snapshot = lab.debug_set_mode("combat")
	snapshot = lab.debug_trigger_action("talk")
	var talk_character := snapshot.get("character", {}) as Dictionary
	_assert(str(snapshot.get("mode", "")) == "work", "talking should automatically switch a friendly NPC to work mode")
	_assert(str(snapshot.get("selected_action_id", "")) == "talk", "talking should remain the selected action after its automatic mode switch")
	_assert(str(talk_character.get("current_state", "")) == "talk", "talking should play the talk presentation after switching to work mode")
	snapshot = lab.debug_set_mode("combat")
	snapshot = lab.debug_trigger_action("drink_wine")
	var drink_character := snapshot.get("character", {}) as Dictionary
	_assert(str(snapshot.get("mode", "")) == "work", "drinking should automatically switch a friendly NPC to work mode")
	_assert(str(drink_character.get("current_state", "")) == "drink", "drinking should use its dedicated presentation state")
	_assert(str(drink_character.get("current_clip", "")) == "Drinking", "drinking should use its dedicated looping clip")
	_assert(bool(drink_character.get("drink_mug_visible", false)), "drinking should show a mug")
	_assert(str(drink_character.get("drink_mug_parent", "")) == "RightHand", "the mug should be attached to the right hand")
	_assert(float(drink_character.get("drink_mug_grip_hand_distance", 1.0)) < 0.01, "the mug handle grip should remain in the right hand")
	snapshot = lab.debug_trigger_action("idle")
	snapshot = lab.debug_trigger_action("work_blacksmith")
	var cross_character := snapshot.get("character", {}) as Dictionary
	_assert(str(cross_character.get("current_clip", "")) == "Hammering", "cross-profession blacksmith work should reuse Glen's animation")
	_assert(bool(cross_character.get("hammer_visible", false)), "cross-profession blacksmith work should put Glen's hammer in hand")
	snapshot = lab.debug_trigger_action("work_dining_hall")
	cross_character = snapshot.get("character", {}) as Dictionary
	_assert(str(cross_character.get("current_clip", "")) == "Working_C", "cross-profession cooking should reuse Bruno's animation")
	_assert(bool(cross_character.get("cook_spoon_visible", false)), "cross-profession cooking should put Bruno's utensil in hand")
	_assert(not bool(cross_character.get("hammer_visible", true)), "leaving cross-profession blacksmith work should hide its borrowed hammer")
	snapshot = lab.debug_trigger_action("work_garden")
	cross_character = snapshot.get("character", {}) as Dictionary
	_assert(str(cross_character.get("current_clip", "")) == "Digging", "cross-profession gardening should reuse Ivo's animation")
	_assert(bool(cross_character.get("garden_hoe_visible", false)), "cross-profession gardening should put Ivo's hoe in hand")
	snapshot = lab.debug_trigger_action("work_workshop")
	cross_character = snapshot.get("character", {}) as Dictionary
	_assert(str(cross_character.get("current_clip", "")) == "Working_A", "cross-profession engineering should reuse Owen's animation")
	_assert(bool(cross_character.get("engineer_wrench_visible", false)), "cross-profession engineering should put Owen's wrench in hand")
	_assert(float(cross_character.get("engineer_wrench_grip_hand_distance", 1.0)) < 0.01, "borrowed wrench should keep the calibrated handle grip")
	snapshot = lab.debug_trigger_action("medical_treatment")
	cross_character = snapshot.get("character", {}) as Dictionary
	_assert(bool(cross_character.get("medical_bandage_visible", false)), "cross-profession treatment should put Lina's bandage in hand")
	_assert(not bool(cross_character.get("engineer_wrench_visible", true)), "leaving cross-profession engineering should hide its borrowed wrench")
	snapshot = lab.debug_trigger_action("idle")

	for friendly_id in FRIENDLY_IDS:
		snapshot = lab.debug_select_unit(friendly_id)
		var friendly_actions := snapshot.get("usable_actions", []) as Array
		_assert(friendly_actions.has("drink_wine"), "%s should expose drinking" % friendly_id)
		for action_id in SHARED_PROFESSION_ACTIONS:
			_assert(friendly_actions.has(action_id), "%s should expose shared profession action %s" % [friendly_id, action_id])
			snapshot = lab.debug_trigger_action(action_id)
			if action_id == "work_garden":
				# The two hands move from idle into the digging grip during the
				# animation blend; inspect after that authored transition settles.
				for _blend_frame in 12:
					await process_frame
				snapshot = lab.debug_get_snapshot()
			var action_character := snapshot.get("character", {}) as Dictionary
			var expected := SHARED_PROFESSION_ACTIONS[action_id] as Dictionary
			_assert(str(action_character.get("current_clip", "")) == str(expected.get("clip", "")), "%s should reuse the specialist clip for %s" % [friendly_id, action_id])
			var tool_field := str(expected.get("tool", ""))
			if not tool_field.is_empty():
				_assert(bool(action_character.get(tool_field, false)), "%s should hold the specialist tool for %s" % [friendly_id, action_id])
			if action_id == "work_clinic_doctor":
				_assert(bool(snapshot.get("seat_preview_visible", false)), "%s clinic-duty preview should show the same seat as seated study" % friendly_id)
			if action_id == "work_stable":
				_assert(float(action_character.get("stable_tool_grip_hand_distance", 1.0)) < 0.01 and float(action_character.get("stable_tool_forward_dot", -1.0)) > 0.85, "%s should preserve Toma's stable-tool grip" % friendly_id)
			elif action_id == "work_dining_hall":
				_assert(float(action_character.get("cook_spoon_grip_hand_distance", 1.0)) < 0.01 and float(action_character.get("cook_spoon_palm_inward_offset", 0.0)) >= 0.07 and float(action_character.get("cook_spoon_forward_dot", -1.0)) > 0.85, "%s should preserve Bruno's palm-centered utensil grip" % friendly_id)
			elif action_id == "work_garden":
				_assert(float(action_character.get("garden_hoe_left_hand_distance", 1.0)) < 0.06 and float(action_character.get("garden_hoe_right_hand_distance", 1.0)) < 0.06, "%s should keep Ivo's hoe shaft inside both palms" % friendly_id)
			elif action_id == "work_workshop":
				_assert(float(action_character.get("engineer_wrench_grip_hand_distance", 1.0)) < 0.01 and float(action_character.get("engineer_wrench_forward_dot", -1.0)) > 0.9, "%s should preserve Owen's wrench grip" % friendly_id)
		_assert(friendly_actions.has("mass_leader") == (friendly_id == "priest_01"), "%s has the wrong priest-only mass permission" % friendly_id)
		snapshot = lab.debug_trigger_action("seated_study")
		var study_mount_position := Vector3(snapshot.get("character_mount_position", Vector3.ZERO))
		_assert(Vector2(study_mount_position.x, study_mount_position.z).length() > 0.1, "%s seated study should reuse the forward seating offset from seated eating" % friendly_id)
		var study_character := snapshot.get("character", {}) as Dictionary
		_assert(bool(study_character.get("medical_book_visible", false)), "%s should borrow Lina's book for seated study" % friendly_id)
		_assert(str(study_character.get("medical_book_parent", "")) == "Mount" and int(study_character.get("medical_book_mesh_count", 0)) >= 10, "%s should hold Lina's open medical book between both hands without wrist clipping" % friendly_id)
		snapshot = lab.debug_trigger_action("idle")

	snapshot = lab.debug_select_unit("priest_01")
	snapshot = lab.debug_set_mode("combat")
	snapshot = lab.debug_trigger_action("seated_prayer")
	_assert(str(snapshot.get("mode", "")) == "work", "work-only action should automatically switch to work mode")
	_assert(bool(snapshot.get("seat_preview_visible", false)), "seated prayer should show the inspection stool")
	_assert(float(snapshot.get("seated_height_compensation", 0.0)) > 0.4, "seated prayer should compensate the formal scene's downward seat offset")
	_assert(float(snapshot.get("character_mount_y", 0.0)) > 0.5, "seated prayer should lift the character above the plinth")
	for _seat_frame in 40:
		await process_frame
	snapshot = lab.debug_get_snapshot()
	_assert(float(snapshot.get("seat_hips_horizontal_distance", 0.0)) > 0.08 and float(snapshot.get("seat_hips_horizontal_distance", 1.0)) < 0.16, "seated prayer should reuse the eating pose's forward seat offset so both legs clear the stool")
	var seat_preview := root.get_node_or_null("NPCDevLab/Stage/SeatPreview") as Node3D
	_assert(seat_preview != null and seat_preview.find_children("*", "CollisionObject3D", true, false).is_empty(), "inspection stool should be presentation-only and contain no collision authority")
	snapshot = lab.debug_trigger_action("seated_eating")
	_assert(bool(snapshot.get("seat_preview_visible", false)), "seated eating should reuse the inspection stool")
	for _eat_seat_frame in 40:
		await process_frame
	snapshot = lab.debug_get_snapshot()
	_assert(str((snapshot.get("character", {}) as Dictionary).get("current_clip", "")) == "Seated_Eating", "seated eating should combine chair-seated legs with the eating upper body")
	_assert(float(snapshot.get("seat_hips_horizontal_distance", 0.0)) > 0.08 and float(snapshot.get("seat_hips_horizontal_distance", 1.0)) < 0.16, "seated eating should move the character slightly forward to keep the legs clear of the stool")
	snapshot = lab.debug_trigger_action("idle")
	_assert(not bool(snapshot.get("seat_preview_visible", true)), "leaving a seated action should hide the inspection stool")
	_assert(is_equal_approx(float(snapshot.get("character_mount_y", 0.0)), 0.12), "idle should restore the normal character height")

	snapshot = lab.debug_select_unit("doctor_01")
	_assert(str(snapshot.get("mode", "")) == "work", "friendly selection should preserve the shared work mode")
	snapshot = lab.debug_set_mode("combat")
	snapshot = lab.debug_trigger_action("seated_study")
	_assert(str(snapshot.get("mode", "")) == "work", "doctor work action should automatically switch back to work mode")
	_assert(bool(snapshot.get("seat_preview_visible", false)), "seated study should show the inspection stool")

	snapshot = lab.debug_select_unit("blacksmith_01")
	_assert(str(snapshot.get("mode", "")) == "work", "switching to Glen should keep the shared work mode")
	_assert((snapshot.get("usable_actions", []) as Array).has("work_blacksmith"), "Glen should expose blacksmith work")
	_assert((snapshot.get("usable_actions", []) as Array).has("work_dining_hall"), "Glen should expose cross-profession cooking")
	_assert((snapshot.get("usable_actions", []) as Array).has("work_workshop"), "Glen should expose cross-profession engineering work")
	_assert(not (snapshot.get("usable_actions", []) as Array).has("mass_leader"), "Glen must not expose priest-only mass leadership")
	snapshot = lab.debug_set_mode("combat")
	_assert((snapshot.get("usable_actions", []) as Array).has("attack"), "friendly combat mode should enable attack")
	_assert((snapshot.get("usable_actions", []) as Array).has("work_blacksmith"), "work action should remain clickable from combat mode")
	snapshot = lab.debug_trigger_action("work_blacksmith")
	_assert(str(snapshot.get("mode", "")) == "work", "blacksmith work should automatically switch to work mode")
	snapshot = lab.debug_trigger_action("attack")
	_assert(str(snapshot.get("mode", "")) == "combat", "combat-only action should automatically switch to combat mode")
	_assert(str(snapshot.get("selected_action_id", "")) == "attack", "legal action should be selected")
	snapshot = lab.debug_trigger_action("idle")
	for weapon_id in ["polearm", "bow", "crossbow"]:
		snapshot = lab.debug_trigger_action("idle")
		snapshot = lab.debug_equip("main_weapon", weapon_id)
		var weapon_character := snapshot.get("character", {}) as Dictionary
		_assert(str(snapshot.get("mode", "")) == "combat", "%s model preview should switch to combat mode" % weapon_id)
		_assert(bool(weapon_character.get("%s_visible" % weapon_id, false)), "%s model should be visible in the developer lab" % weapon_id)
		var expected_weapon_parent := "LeftHand" if weapon_id == "bow" else "RightHand"
		_assert(str(weapon_character.get("%s_parent" % weapon_id, "")) == expected_weapon_parent, "%s model should use its approved inspection hand" % weapon_id)
		_assert(int(weapon_character.get("%s_mesh_count" % weapon_id, 0)) > 0, "%s model should contain visible mesh geometry" % weapon_id)
		if weapon_id == "polearm":
			_assert(float(weapon_character.get("polearm_grip_palm_distance", 1.0)) < 0.01, "polearm grip should sit at the visible palm target rather than the wrist bone")
			_assert(float(weapon_character.get("polearm_axis_up_dot", 1.0)) < 0.02, "polearm shaft should remain parallel to the ground")
			_assert(float(weapon_character.get("polearm_palm_inward_offset", 0.0)) >= 0.05, "polearm grip should be pulled inward from the outer edge of the palm")
			snapshot = lab.debug_trigger_action("attack")
			for checkpoint_frames in [2, 12, 16]:
				for _frame in checkpoint_frames:
					await process_frame
				snapshot = lab.debug_get_snapshot()
				weapon_character = snapshot.get("character", {}) as Dictionary
				_assert(str(weapon_character.get("current_clip", "")) == "Melee_2H_Attack_Stab", "foot polearm attack should use the dedicated two-handed thrust clip")
				_assert(float(weapon_character.get("polearm_grip_palm_distance", 1.0)) < 0.01, "polearm should preserve the approved right-palm grip throughout the thrust")
				_assert(float(weapon_character.get("polearm_axis_forward_dot", -1.0)) > 0.99, "polearm should preserve the approved forward direction throughout the thrust")
				_assert(float(weapon_character.get("polearm_axis_up_dot", 1.0)) < 0.02, "polearm should remain level throughout the thrust")
				_assert(float(weapon_character.get("polearm_shaft_length", 0.0)) > 2.0, "lengthened polearm shaft should remain visibly longer than the wielder's torso")
		elif weapon_id == "bow":
			_assert(bool(weapon_character.get("bow_string_present", false)), "bow model should include a visible string between both limbs")
			_assert(float(weapon_character.get("bow_long_axis_forward_dot", -1.0)) > 0.98, "bow long axis should point along the character's forward direction")
			_assert(float(weapon_character.get("bow_grip_palm_distance", 1.0)) < 0.01, "bow grip should sit inside the left palm")
			_assert(float(weapon_character.get("bow_string_above_grip_offset", -1.0)) > 0.05, "bow should be rolled so the string sits above the grip")
			_assert(float(weapon_character.get("bow_down_offset", 0.0)) >= 0.08, "bow grip should be lowered from the previous wrist-high pose")
		elif weapon_id == "crossbow":
			_assert(float(weapon_character.get("crossbow_forward_dot", -1.0)) > 0.99, "crossbow bolt point should face forward rather than backward")
			_assert(float(weapon_character.get("crossbow_top_up_dot", -1.0)) > 0.99, "crossbow lock and loaded bolt should face upward rather than upside down")
			_assert(float(weapon_character.get("crossbow_grip_palm_distance", 1.0)) < 0.01, "crossbow grip should sit in the palm rather than at the wrist bone")
			_assert(float(weapon_character.get("crossbow_down_offset", 0.0)) >= 0.22, "resting crossbow should use the further-lowered carry pose")
			_assert(float(weapon_character.get("crossbow_grip_right_hand_distance", 1.0)) < 0.18, "resting crossbow should remain within the NPC's lowered right-palm grip zone")
			_assert(absf(float(weapon_character.get("crossbow_side_offset", 1.0))) < 0.31, "resting crossbow should sit further toward the NPC centerline")
			_assert(float(weapon_character.get("crossbow_centerline_offset", 0.0)) >= 0.04, "resting crossbow should use an explicit character-space centerline correction")
		for other_weapon_id in ["polearm", "bow", "crossbow"]:
			if other_weapon_id != weapon_id:
				_assert(not bool(weapon_character.get("%s_visible" % other_weapon_id, false)), "equipping %s should hide stale %s geometry" % [weapon_id, other_weapon_id])

	snapshot = lab.debug_trigger_action("idle")
	snapshot = lab.debug_equip("main_weapon", "bow")
	snapshot = lab.debug_trigger_action("attack")
	var bow_attack_character := snapshot.get("character", {}) as Dictionary
	_assert(str(bow_attack_character.get("current_clip", "")) == "Ranged_Bow_Draw", "foot bow attack should begin with the dedicated draw animation")
	var bow_character := lab.get("_character") as Node
	snapshot = bow_character.call("debug_advance_preview_bow_attack", 0.82) as Dictionary
	bow_attack_character = snapshot
	_assert(bool(bow_attack_character.get("bow_attack_active", false)), "bow attack sequence should remain active while drawing")
	_assert(bool(bow_attack_character.get("bow_loaded_arrow_visible", false)), "an arrow should appear between the hands while drawing")
	_assert(bool(bow_attack_character.get("bow_pulled_string_visible", false)), "bow string should bend toward the pulling hand")
	_assert(not bool(bow_attack_character.get("bow_static_string_visible", true)), "resting string should hide while the bow is drawn")
	_assert(float(bow_attack_character.get("bow_attack_grip_palm_distance", 1.0)) < 0.01, "raised bow should remain in the holding palm")
	_assert(float(bow_attack_character.get("bow_attack_long_axis_up_dot", -1.0)) > 0.99, "drawn bow should rotate its long axis upward")
	_assert(float(bow_attack_character.get("bow_attack_string_back_dot", -1.0)) > 0.99, "drawn bow string should sit behind the bow")
	_assert(float(bow_attack_character.get("bow_loaded_arrow_forward_dot", -1.0)) > 0.99, "loaded arrow should still aim forward after the bow rotates vertically")
	_assert(float(bow_attack_character.get("bow_arrow_visible_length", 0.0)) >= 1.30, "loaded and flying arrows should use the lengthened model")
	_assert(bool(bow_attack_character.get("bow_arrow_head_is_pointed", false)), "loaded and flying arrows should use a pointed conical arrowhead")
	bow_character.call("debug_advance_preview_bow_attack", 0.55)
	bow_attack_character = bow_character.call("debug_advance_preview_bow_attack", 0.01) as Dictionary
	_assert(float(bow_attack_character.get("bow_nock_pull_hand_distance", 1.0)) < 0.04, "fully drawn string nock should reach the pulling palm")
	bow_character.call("debug_advance_preview_bow_attack", 0.24)
	snapshot = bow_character.call("debug_advance_preview_bow_attack", 0.13) as Dictionary
	bow_attack_character = snapshot
	_assert(int(bow_attack_character.get("bow_shot_count", 0)) >= 1, "bow release should spawn a real presentation projectile")
	_assert(int(bow_attack_character.get("bow_active_projectile_count", 0)) >= 1, "fired arrow should travel independently from the bow")
	_assert(bool(bow_attack_character.get("bow_static_string_visible", false)), "bow string should snap back after release")
	_assert(not bool(bow_attack_character.get("bow_loaded_arrow_visible", true)), "loaded arrow should leave the bow on release")
	_assert(bool(bow_attack_character.get("bow_projectile_uses_arc", false)), "bow projectile preview should already use a ballistic arc")
	_assert(str(bow_attack_character.get("bow_projectile_damage_authority", "")) == "combat_system_on_confirmed_hit", "presentation arrow must not apply damage before a confirmed CombatSystem hit")

	snapshot = lab.debug_trigger_action("idle")
	snapshot = lab.debug_equip("main_weapon", "crossbow")
	snapshot = lab.debug_trigger_action("attack")
	var crossbow_attack_character := snapshot.get("character", {}) as Dictionary
	_assert(str(crossbow_attack_character.get("current_clip", "")) == "Ranged_2H_Aiming", "foot crossbow attack should begin with the library two-handed aiming clip")
	_assert(bool(crossbow_attack_character.get("crossbow_attack_active", false)), "crossbow attack should start its dedicated aim-shoot-reload sequence")
	_assert(bool(crossbow_attack_character.get("crossbow_loaded_bolt_visible", false)), "cocked crossbow should visibly carry a bolt while aiming")
	var crossbow_character := lab.get("_character") as Node
	crossbow_attack_character = crossbow_character.call("debug_advance_preview_crossbow_attack", 1.62) as Dictionary
	_assert(str(crossbow_attack_character.get("crossbow_attack_phase", "")) == "shoot", "crossbow should advance from aiming to shooting")
	_assert(str(crossbow_attack_character.get("current_clip", "")) == "Ranged_2H_Shoot", "crossbow release should use the library two-handed shooting clip")
	_assert(float(crossbow_attack_character.get("crossbow_forward_dot", -1.0)) > 0.99, "crossbow should remain aimed forward during the attack")
	_assert(float(crossbow_attack_character.get("crossbow_down_offset", 1.0)) <= 0.02, "attacking crossbow should visibly overcome the animation's downward hand motion and rise above the resting carry height")
	_assert(float(crossbow_attack_character.get("crossbow_grip_palm_distance", 1.0)) < 0.01, "crossbow trigger grip should stay in the right palm during the attack")
	_assert(float(crossbow_attack_character.get("crossbow_grip_right_hand_distance", 1.0)) < 0.13, "attacking crossbow should remain within the NPC's right-hand grip zone after the centerward shift")
	_assert(absf(float(crossbow_attack_character.get("crossbow_side_offset", 1.0))) < 0.31, "attacking crossbow should retain the same further-centerward placement")
	crossbow_attack_character = crossbow_character.call("debug_advance_preview_crossbow_attack", 0.34) as Dictionary
	_assert(int(crossbow_attack_character.get("crossbow_shot_count", 0)) >= 1, "crossbow release should spawn a real presentation bolt")
	_assert(int(crossbow_attack_character.get("crossbow_active_projectile_count", 0)) >= 1, "fired crossbow bolt should travel independently from the weapon")
	_assert(not bool(crossbow_attack_character.get("crossbow_loaded_bolt_visible", true)), "loaded crossbow bolt should leave the rail at release")
	_assert(float(crossbow_attack_character.get("crossbow_string_nock_y", 0.0)) > 0.50, "crossbow string should snap forward when the bolt is fired")
	crossbow_attack_character = crossbow_character.call("debug_advance_preview_crossbow_attack", 0.75) as Dictionary
	_assert(str(crossbow_attack_character.get("crossbow_attack_phase", "")) == "reload", "crossbow should enter its dedicated reload phase after firing")
	_assert(str(crossbow_attack_character.get("current_clip", "")) == "Ranged_2H_Reload", "crossbow reload should use the library two-handed reload clip")
	crossbow_attack_character = crossbow_character.call("debug_advance_preview_crossbow_attack", 1.62) as Dictionary
	_assert(not bool(crossbow_attack_character.get("crossbow_attack_active", true)), "crossbow attack sequence should finish after reloading")
	_assert(bool(crossbow_attack_character.get("crossbow_loaded_bolt_visible", false)), "crossbow should finish reloaded with a visible bolt")
	_assert(is_equal_approx(float(crossbow_attack_character.get("crossbow_string_nock_y", 0.0)), 0.27), "crossbow string should finish recocked")
	_assert(str(crossbow_attack_character.get("crossbow_projectile_damage_authority", "")) == "combat_system_on_confirmed_hit", "presentation bolt must not apply damage before a confirmed CombatSystem hit")

	snapshot = lab.debug_set_mode("work")
	snapshot = lab.debug_equip("main_weapon", "sword_shield")
	var character: Dictionary = snapshot.get("character", {})
	_assert(str(snapshot.get("mode", "")) == "combat", "equipping a weapon should automatically switch to combat mode")
	_assert(str((snapshot.get("loadout", {}) as Dictionary).get("main_weapon", {}).get("id", "")) == "sword_shield", "weapon slot should accept configured sword shield")
	_assert(bool(character.get("sword_visible", false)) and bool(character.get("shield_visible", false)), "sword shield should use existing hand attachments in combat mode")
	snapshot = lab.debug_trigger_action("idle")
	for _sword_idle_frame in 12:
		await process_frame
	snapshot = lab.debug_get_snapshot()
	character = snapshot.get("character", {}) as Dictionary
	var approved_foot_sword_position := Vector3(character.get("sword_local_position", Vector3.ZERO))
	var approved_foot_sword_rotation := Vector3(character.get("sword_local_rotation_degrees", Vector3.ZERO))
	snapshot = lab.debug_trigger_action("work_blacksmith")
	for _sword_work_frame in 12:
		await process_frame
	snapshot = lab.debug_get_snapshot()
	character = snapshot.get("character", {}) as Dictionary
	_assert(not Vector3(character.get("sword_local_rotation_degrees", Vector3.ZERO)).is_equal_approx(approved_foot_sword_rotation), "work animation should reproduce the distinct hand-space transform that previously contaminated the next sword attack")
	snapshot = lab.debug_trigger_action("attack")
	character = snapshot.get("character", {}) as Dictionary
	_assert(Vector3(character.get("sword_local_position", Vector3.ONE)).is_equal_approx(approved_foot_sword_position), "sword attack after another action should restore the approved foot-combat grip position")
	_assert(Vector3(character.get("sword_local_rotation_degrees", Vector3.ONE)).is_equal_approx(approved_foot_sword_rotation), "sword attack after another action should restore the approved foot-combat grip rotation")
	snapshot = lab.debug_equip("mount", "horse_chestnut_wind")
	character = snapshot.get("character", {})
	_assert(str(snapshot.get("selected_action_id", "")) == "mounted_pose", "equipping a mount should enter mounted idle")
	_assert(str(character.get("current_state", "")) == "vehicle_seated", "mounted idle should keep the dedicated seated state")
	_assert(float(character.get("sword_forward_dot", -1.0)) > 0.98, "mounted idle sword should point along the horse/rider forward axis")
	_assert(float(character.get("mounted_sword_grip_palm_distance", 1.0)) < 0.01, "mounted sword grip should remain inside the right palm target")
	_assert(float(character.get("shield_face_side_dot", -1.0)) > 0.98, "mounted shield face should point to the rider's side")
	for mounted_action_id in MOUNTED_ACTION_EXPECTATIONS:
		snapshot = lab.debug_trigger_action(mounted_action_id)
		character = snapshot.get("character", {}) as Dictionary
		var mounted_expected := MOUNTED_ACTION_EXPECTATIONS[mounted_action_id] as Dictionary
		_assert(str(character.get("current_state", "")) == str(mounted_expected.get("state", "")), "%s should use its mounted state while a combat mount is equipped" % mounted_action_id)
		_assert(str(character.get("current_clip", "")) == str(mounted_expected.get("clip", "")), "%s should use its dedicated mounted clip" % mounted_action_id)
		_assert(bool(snapshot.get("mount_visible", false)), "%s should keep the horse visible" % mounted_action_id)
		_assert(str(snapshot.get("horse_animation", "")) == str(mounted_expected.get("horse_clip", "")), "%s should drive the matching horse animation" % mounted_action_id)
		_assert(float(Vector3(character.get("presentation_pose_offset", Vector3.ZERO)).y) < -0.4, "%s should retain the mounted seated height offset" % mounted_action_id)
	snapshot = lab.debug_trigger_action("attack")
	character = snapshot.get("character", {})
	_assert(str(character.get("current_state", "")) == "mounted_attack", "mounted attack should use its own seated attack state")
	_assert(str(character.get("current_clip", "")) == "Mounted_1H_Attack", "mounted attack should use the upper-body-only cavalry clip")
	_assert(bool(snapshot.get("mount_visible", false)), "mounted attack should keep the horse visible")
	_assert(float(character.get("mounted_thigh_spread_degrees", 0.0)) >= 55.0, "mounted sword attack should retain the static straddle lower-body pose")
	_assert(float(character.get("sword_grip_hand_distance", 1.0)) < 0.001, "mounted sword attack should re-anchor the approved foot-combat blade to the mounted right hand")
	_assert(Vector3(character.get("sword_local_rotation_degrees", Vector3.ONE)).is_equal_approx(approved_foot_sword_rotation), "mounted sword attack should reuse the approved foot-combat hand-to-sword angle")
	var mounted_sword_fixed_local_position := Vector3(character.get("sword_local_position", Vector3.ZERO))
	var mounted_sword_fixed_local_rotation := Vector3(character.get("sword_local_rotation_degrees", Vector3.ZERO))
	var mounted_character_node := lab.get("_character") as Node
	var mounted_animation_player := mounted_character_node.find_child("PilotAnimationPlayer", true, false) as AnimationPlayer
	_assert(mounted_animation_player != null, "mounted sword attack should expose its animation player for pose verification")
	var mounted_sword_attack := mounted_animation_player.get_animation("Mounted_1H_Attack")
	var foot_sword_attack := mounted_animation_player.get_animation("Melee_1H_Attack_Slice_Horizontal")
	_assert(mounted_sword_attack != null and foot_sword_attack != null, "mounted and foot sword clips should both exist")
	_assert(is_equal_approx(mounted_sword_attack.length, foot_sword_attack.length), "mounted sword attack should use the full foot sword attack timing")
	for upper_body_bone in ["Spine", "Chest", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand"]:
		var mounted_track_index := _find_rotation_track(mounted_sword_attack, upper_body_bone)
		var foot_track_index := _find_rotation_track(foot_sword_attack, upper_body_bone)
		_assert(mounted_track_index >= 0 and foot_track_index >= 0, "mounted sword attack should contain the foot %s rotation track" % upper_body_bone)
		if mounted_track_index < 0 or foot_track_index < 0:
			continue
		_assert(mounted_sword_attack.track_get_key_count(mounted_track_index) == foot_sword_attack.track_get_key_count(foot_track_index), "mounted %s track should preserve every foot attack key" % upper_body_bone)
		for key_index in range(mini(mounted_sword_attack.track_get_key_count(mounted_track_index), foot_sword_attack.track_get_key_count(foot_track_index))):
			_assert(is_equal_approx(mounted_sword_attack.track_get_key_time(mounted_track_index, key_index), foot_sword_attack.track_get_key_time(foot_track_index, key_index)), "mounted %s track should preserve foot attack key timing" % upper_body_bone)
			var mounted_key := mounted_sword_attack.track_get_key_value(mounted_track_index, key_index) as Quaternion
			var foot_key := foot_sword_attack.track_get_key_value(foot_track_index, key_index) as Quaternion
			var expected_key := (foot_key * Quaternion(Vector3.RIGHT, deg_to_rad(10.0))).normalized() if upper_body_bone == "Spine" else foot_key
			_assert(mounted_key.is_equal_approx(expected_key), "mounted %s track should preserve the foot attack pose with only the approved spine lean" % upper_body_bone)
	for attack_progress in [0.2, 0.5, 0.8]:
		mounted_animation_player.play("Mounted_1H_Attack", 0.0)
		mounted_animation_player.seek(mounted_sword_attack.length * attack_progress, true)
		mounted_animation_player.pause()
		await process_frame
		var mounted_sword_frame := mounted_character_node.call("debug_get_snapshot") as Dictionary
		_assert(Vector3(mounted_sword_frame.get("sword_local_position", Vector3.ONE)).is_equal_approx(mounted_sword_fixed_local_position), "mounted sword must stay rigidly attached to the right hand throughout the reused foot attack")
		_assert(Vector3(mounted_sword_frame.get("sword_local_rotation_degrees", Vector3.ONE)).is_equal_approx(mounted_sword_fixed_local_rotation), "mounted sword rotation must stay fixed relative to the right hand throughout the reused foot attack")
		_assert(float(mounted_sword_frame.get("mounted_upper_body_forward_offset", -1.0)) > 0.005, "mounted sword attack should retain a slight forward torso lean throughout the swing")
	var mounted_weapon_attack_clips := {
		"polearm": "Mounted_Polearm_Stab",
		"bow": "Mounted_Bow_Draw",
		"crossbow": "Mounted_Crossbow_Aim",
	}
	for mounted_weapon_id in mounted_weapon_attack_clips:
		snapshot = lab.debug_equip("main_weapon", mounted_weapon_id)
		snapshot = lab.debug_trigger_action("attack")
		character = snapshot.get("character", {}) as Dictionary
		_assert(str(character.get("current_state", "")) == "mounted_attack", "%s attack should remain in the mounted attack state" % mounted_weapon_id)
		_assert(str(character.get("current_clip", "")) == str(mounted_weapon_attack_clips[mounted_weapon_id]), "%s should begin with its matching foot-combat upper-body clip composited over the mounted lower body" % mounted_weapon_id)
		_assert(bool(snapshot.get("mount_visible", false)), "%s attack should keep the horse visible" % mounted_weapon_id)
		_assert(float(Vector3(character.get("presentation_pose_offset", Vector3.ZERO)).y) < -0.4, "%s attack should retain the mounted seated height offset" % mounted_weapon_id)
		_assert(float(character.get("mounted_thigh_spread_degrees", 0.0)) >= 55.0, "%s attack should retain the mounted straddle lower-body pose" % mounted_weapon_id)
		match mounted_weapon_id:
			"polearm":
				_assert(float(character.get("polearm_grip_palm_distance", 1.0)) < 0.01, "mounted polearm should retain the verified right-palm grip")
				var mounted_polearm_animation := mounted_animation_player.get_animation("Mounted_Polearm_Stab")
				for dynamic_torso_bone in ["Spine", "Chest", "Head"]:
					var torso_track_index := _find_rotation_track(mounted_polearm_animation, dynamic_torso_bone)
					_assert(torso_track_index >= 0 and mounted_polearm_animation.track_get_key_count(torso_track_index) > 1, "mounted polearm should preserve the foot thrust's animated %s track" % dynamic_torso_bone)
					if torso_track_index >= 0 and mounted_polearm_animation.track_get_key_count(torso_track_index) > 1:
						var first_torso_rotation := mounted_polearm_animation.track_get_key_value(torso_track_index, 0) as Quaternion
						var torso_changes := false
						for torso_key_index in range(1, mounted_polearm_animation.track_get_key_count(torso_track_index)):
							var torso_rotation := mounted_polearm_animation.track_get_key_value(torso_track_index, torso_key_index) as Quaternion
							if not torso_rotation.is_equal_approx(first_torso_rotation):
								torso_changes = true
								break
						_assert(torso_changes, "mounted polearm %s should move through the thrust instead of being frozen to mounted idle" % dynamic_torso_bone)
				mounted_animation_player.play("Mounted_Polearm_Stab", 0.0)
				mounted_animation_player.seek(mounted_animation_player.current_animation_length * 0.50, true)
				mounted_animation_player.pause()
				await process_frame
				character = (lab.debug_get_snapshot().get("character", {}) as Dictionary)
				_assert(float(character.get("mounted_upper_body_forward_offset", -1.0)) > 0.04, "mounted polearm attack should keep the upper body slightly forward instead of inheriting the foot-thrust backward lean: %s" % str(character.get("mounted_upper_body_forward_offset")))
			"bow":
				_assert(float(character.get("bow_attack_grip_palm_distance", 1.0)) < 0.01, "mounted bow draw should retain the verified left-palm grip")
			"crossbow":
				_assert(float(character.get("crossbow_grip_palm_distance", 1.0)) < 0.01, "mounted crossbow aim should retain the verified right-palm grip")
				_assert(float(character.get("mounted_crossbow_centerline_extra_offset", 0.0)) >= 0.08, "mounted crossbow attack should receive an extra centerline correction without changing the approved foot pose")
	snapshot = lab.debug_equip("main_weapon", "bow")
	snapshot = lab.debug_trigger_action("attack")
	for ranged_clip_pair in [
		["Mounted_Bow_Draw", "Ranged_Bow_Draw"],
		["Mounted_Bow_Aim", "Ranged_Bow_Aiming_Idle"],
		["Mounted_Bow_Release", "Ranged_Bow_Release"],
		["Mounted_Crossbow_Aim", "Ranged_2H_Aiming"],
		["Mounted_Crossbow_Shoot", "Ranged_2H_Shoot"],
		["Mounted_Crossbow_Reload", "Ranged_2H_Reload"],
	]:
		_assert_upper_body_rotation_tracks_match(
			mounted_animation_player.get_animation(str(ranged_clip_pair[0])),
			mounted_animation_player.get_animation(str(ranged_clip_pair[1])),
			str(ranged_clip_pair[0])
		)
		_assert_mounted_lower_body_tracks_unchanged(
			mounted_animation_player.get_animation(str(ranged_clip_pair[0])),
			mounted_animation_player.get_animation("Mounted_Idle"),
			str(ranged_clip_pair[0])
		)
	var mounted_bow_character := mounted_character_node.call("debug_advance_preview_bow_attack", 1.34) as Dictionary
	_assert(str(mounted_bow_character.get("current_clip", "")) == "Mounted_Bow_Aim", "mounted bow should keep the rider seated while entering full draw")
	_assert(float(mounted_bow_character.get("mounted_thigh_spread_degrees", 0.0)) >= 55.0, "mounted bow aim should keep the straddle lower-body pose")
	_assert(float(mounted_bow_character.get("bow_nock_pull_hand_distance", 1.0)) < 0.04, "mounted bow draw should bring the string nock to the same pulling palm as the foot attack")
	_assert(float(mounted_bow_character.get("bow_loaded_arrow_forward_dot", -1.0)) > 0.99, "mounted bow arrow should aim along the rider and horse forward axis")
	snapshot = lab.debug_equip("main_weapon", "crossbow")
	snapshot = lab.debug_trigger_action("attack")
	var mounted_crossbow_character := mounted_character_node.call("debug_advance_preview_crossbow_attack", 1.62) as Dictionary
	_assert(str(mounted_crossbow_character.get("current_clip", "")) == "Mounted_Crossbow_Shoot", "mounted crossbow should keep the rider seated while firing")
	_assert(float(mounted_crossbow_character.get("mounted_thigh_spread_degrees", 0.0)) >= 55.0, "mounted crossbow shot should keep the straddle lower-body pose")
	snapshot = lab.debug_equip("main_weapon", "sword_shield")
	snapshot = lab.debug_unequip("mount")
	snapshot = lab.debug_set_mode("work")
	character = snapshot.get("character", {})
	_assert(not bool(character.get("sword_visible", false)) and not bool(character.get("shield_visible", false)), "work mode should hide combat weapon presentation")
	_assert(str((snapshot.get("loadout", {}) as Dictionary).get("main_weapon", {}).get("id", "")) == "sword_shield", "mode switch should retain the temporary loadout")

	snapshot = lab.debug_equip("helmet", "iron_helmet")
	_assert(str(snapshot.get("mode", "")) == "combat", "equipping armor should automatically switch to combat mode")
	_assert(str((snapshot.get("loadout", {}) as Dictionary).get("helmet", {}).get("id", "")) == "iron_helmet", "helmet slot should accept configured armor")
	for armor_entry in [
		["chest", "mail_chest"],
		["bracers", "iron_bracers"],
		["greaves", "iron_greaves"],
	]:
		snapshot = lab.debug_equip(str(armor_entry[0]), str(armor_entry[1]))
	var equipped_character := snapshot.get("character", {}) as Dictionary
	var equipped_armor := equipped_character.get("armor", {}) as Dictionary
	for armor_slot in ["helmet", "chest", "bracers", "greaves"]:
		var armor_visual := equipped_armor.get(armor_slot, {}) as Dictionary
		_assert(bool(armor_visual.get("visible", false)), "%s armor model should be visible in combat mode" % armor_slot)
		_assert(int(armor_visual.get("mesh_count", 0)) > 0, "%s armor model should contain real mesh geometry" % armor_slot)
	_assert(int((equipped_armor.get("helmet", {}) as Dictionary).get("part_count", 0)) == 1, "helmet should be one independent bone-attached model")
	_assert(int((equipped_armor.get("chest", {}) as Dictionary).get("part_count", 0)) == 1, "chest armor should be one independent bone-attached model")
	for extracted_slot in ["helmet", "chest", "bracers", "greaves"]:
		var extracted_visual := equipped_armor.get(extracted_slot, {}) as Dictionary
		_assert(int(extracted_visual.get("part_count", 0)) == 1, "%s should be one independently toggled skinned knight-armor model" % extracted_slot)
		_assert(str(extracted_visual.get("source_asset", "")).ends_with("SK_Knights_Dark_01.fbx"), "%s should come from the authored Synty knight" % extracted_slot)
		var extracted_parts := extracted_visual.get("parts", []) as Array
		_assert(not extracted_parts.is_empty() and bool((extracted_parts[0] as Dictionary).get("skinned", false)), "%s should retain the authored knight skin weights" % extracted_slot)
	var helmet_aabb := (((equipped_armor.get("helmet", {}) as Dictionary).get("parts", []) as Array)[0] as Dictionary).get("mesh_aabb", AABB()) as AABB
	var chest_aabb := (((equipped_armor.get("chest", {}) as Dictionary).get("parts", []) as Array)[0] as Dictionary).get("mesh_aabb", AABB()) as AABB
	var bracers_aabb := (((equipped_armor.get("bracers", {}) as Dictionary).get("parts", []) as Array)[0] as Dictionary).get("mesh_aabb", AABB()) as AABB
	var greaves_aabb := (((equipped_armor.get("greaves", {}) as Dictionary).get("parts", []) as Array)[0] as Dictionary).get("mesh_aabb", AABB()) as AABB
	_assert(helmet_aabb.size.x > 0.75 and helmet_aabb.size.y > 0.80, "helmet should include the enlarged full knight helm with head clearance")
	_assert(chest_aabb.size.y > 0.45, "chest slot should include the knight torso armor rather than a flat primitive")
	_assert(bracers_aabb.size.x > 1.60, "bracer slot should span both complete shoulder-to-hand assemblies")
	_assert(greaves_aabb.size.y > 0.75, "greave slot should span hips, thighs, shins and boots")
	_assert(bool(equipped_character.get("helmet_hair_hidden", false)), "helmet should activate the reversible detached-hair/headwear filter")
	snapshot = lab.debug_set_mode("work")
	var work_armor := ((snapshot.get("character", {}) as Dictionary).get("armor", {}) as Dictionary)
	for armor_slot in ["helmet", "chest", "bracers", "greaves"]:
		_assert(not bool((work_armor.get(armor_slot, {}) as Dictionary).get("visible", true)), "%s armor should hide in work mode" % armor_slot)
	_assert(not bool((snapshot.get("character", {}) as Dictionary).get("helmet_hair_hidden", true)), "hiding the helmet should restore detached hair/headwear")
	snapshot = lab.debug_set_mode("combat")
	snapshot = lab.debug_select_unit("doctor_01")
	_assert(str(snapshot.get("mode", "")) == "combat", "friendly selection should preserve the shared combat mode")
	_assert(str((snapshot.get("loadout", {}) as Dictionary).get("main_weapon", {}).get("id", "")) == "sword_shield", "weapon selection should persist across NPCs")
	_assert(str((snapshot.get("loadout", {}) as Dictionary).get("helmet", {}).get("id", "")) == "iron_helmet", "armor selection should persist across NPCs")
	var doctor_armor := ((snapshot.get("character", {}) as Dictionary).get("armor", {}) as Dictionary)
	for armor_slot in ["helmet", "chest", "bracers", "greaves"]:
		_assert(bool((doctor_armor.get(armor_slot, {}) as Dictionary).get("visible", false)), "%s armor should remain visible after switching to Lina" % armor_slot)
	snapshot = lab.debug_select_unit("blacksmith_01")
	var helmet_button := root.get_node_or_null("NPCDevLab/CanvasLayer/Overlay/EquipmentPanel/MarginContainer/VBoxContainer/EquipmentMannequin/HelmetSlotButton") as Button
	if helmet_button == null:
		# Runtime-generated container names may receive numeric suffixes; name lookup
		# keeps the contract focused on the explicit slot button itself.
		helmet_button = root.get_node("NPCDevLab/CanvasLayer/Overlay/EquipmentPanel").find_child("HelmetSlotButton", true, false) as Button
	_assert(helmet_button != null and helmet_button.text.is_empty(), "equipped slot should not show slot or item text")
	_assert(helmet_button != null and helmet_button.icon != null, "equipped slot should show its configured item icon")
	helmet_button.pressed.emit()
	await process_frame
	snapshot = lab.debug_get_snapshot()
	_assert(((snapshot.get("loadout", {}) as Dictionary).get("helmet", {}) as Dictionary).is_empty(), "clicking an occupied slot should unequip it")
	_assert(helmet_button.text == "+", "empty slot should display only plus")
	_assert(helmet_button.icon == null, "empty slot should not retain an item icon")
	snapshot = lab.debug_select_unit("doctor_01")
	_assert(((snapshot.get("loadout", {}) as Dictionary).get("helmet", {}) as Dictionary).is_empty(), "unequipped slot should remain empty after switching NPCs")
	snapshot = lab.debug_select_unit("blacksmith_01")
	helmet_button.pressed.emit()
	await process_frame
	snapshot = lab.debug_get_snapshot()
	_assert(bool(snapshot.get("picker_visible", false)), "clicking an empty slot should open the adjacent equipment picker")

	snapshot = lab.debug_set_mode("work")
	snapshot = lab.debug_equip("mount", "horse_chestnut_wind")
	_assert(str(snapshot.get("mode", "")) == "combat", "equipping a mount should automatically switch to combat mode")
	_assert(str(snapshot.get("selected_action_id", "")) == "mounted_pose", "equipping a mount should automatically select the mounted pose")
	_assert(bool(snapshot.get("mount_visible", false)), "selected mount should be visible in combat mode")
	_assert(float(snapshot.get("character_mount_y", 0.0)) > 1.25, "mounted preview should lift the rider high enough for both legs to clear the horse body")
	_assert(Vector3(snapshot.get("character_mount_position", Vector3.ZERO)).length() > 1.2, "mounted preview should move the rider both upward and toward the horse's saddle")
	await process_frame
	snapshot = lab.debug_get_snapshot()
	_assert(str(snapshot.get("selected_action_id", "")) == "mounted_pose", "mounted pose should be available with a horse")
	var mounted_character := snapshot.get("character", {}) as Dictionary
	_assert(str(mounted_character.get("current_clip", "")) == "Mounted_Idle", "mounted preview should use the dedicated straddle pose")
	_assert(float(mounted_character.get("mounted_thigh_spread_degrees", 0.0)) >= 55.0, "mounted preview should spread both thighs clear of the horse body")
	_assert(float(snapshot.get("mounted_forward_dot", -1.0)) > 0.99, "mounted character and visible horse should face the same direction: dot=%s character=%s horse=%s" % [str(snapshot.get("mounted_forward_dot", -1.0)), str(snapshot.get("character_visible_forward", Vector3.ZERO)), str(snapshot.get("horse_visible_forward", Vector3.ZERO))])
	_assert(Vector3(snapshot.get("horse_root_position", Vector3.ZERO)).is_equal_approx(MOUNTED_PRESENTATION_REFERENCE.FRIENDLY_HORSE_ROOT_POSITION), "friendly horse root should use the shared production reference")
	_assert(Vector3(snapshot.get("horse_model_scale", Vector3.ZERO)).is_equal_approx(MOUNTED_PRESENTATION_REFERENCE.FRIENDLY_HORSE_SCALE), "friendly horse scale should use the shared production reference")
	_assert(is_zero_approx(float(snapshot.get("horse_model_local_yaw_degrees", 180.0))), "horse source model should not retain the opposite 180-degree local yaw")
	snapshot = lab.debug_select_unit("doctor_01")
	_assert(str(snapshot.get("selected_action_id", "")) == "mounted_pose", "switching NPCs with a shared mount equipped should keep the automatic mounted pose")
	snapshot = lab.debug_unequip("mount")
	_assert(not bool(snapshot.get("mount_visible", false)), "unequipping mount should hide it")
	_assert(str(snapshot.get("selected_action_id", "")) == "idle", "removing the required mount should return to idle")

	var equipment_panel := root.get_node("NPCDevLab/CanvasLayer/Overlay/EquipmentPanel")
	for enemy_id in EXPECTED_ENEMY_LOADOUTS:
		var expected: Dictionary = EXPECTED_ENEMY_LOADOUTS[enemy_id]
		snapshot = lab.debug_select_unit(enemy_id)
		var enemy_loadout := snapshot.get("loadout", {}) as Dictionary
		var enemy_weapon := enemy_loadout.get("main_weapon", {}) as Dictionary
		var enemy_mount := enemy_loadout.get("mount", {}) as Dictionary
		var enemy_character := snapshot.get("character", {}) as Dictionary
		_assert(str(snapshot.get("loadout_scope", "")) == "fixed_by_enemy_type", "%s should declare a fixed-by-type loadout" % enemy_id)
		_assert(bool(snapshot.get("enemy_equipment_locked", false)), "%s should lock every equipment slot" % enemy_id)
		_assert(str(enemy_weapon.get("id", "")) == str(expected.get("weapon", "")), "%s should use its configured weapon" % enemy_id)
		_assert(not enemy_mount.is_empty() == bool(expected.get("mounted", false)), "%s mount should match enemy_waves.json" % enemy_id)
		_assert(bool(snapshot.get("mount_visible", false)) == bool(expected.get("mounted", false)), "%s visible mount should match its fixed type" % enemy_id)
		_assert(bool(enemy_character.get(str(expected.get("visible", "")), false)), "%s should visibly hold its fixed weapon" % enemy_id)
		for slot_name in ["MainWeapon", "Helmet", "Chest", "Bracers", "Greaves", "Mount"]:
			var slot_button := equipment_panel.find_child("%sSlotButton" % slot_name, true, false) as Button
			_assert(slot_button != null and slot_button.disabled, "%s %s slot should be read-only" % [enemy_id, slot_name])
		var fixed_before := enemy_loadout.duplicate(true)
		var rejected_equip: Dictionary = lab.debug_equip("main_weapon", "crossbow")
		_assert((rejected_equip.get("loadout", {}) as Dictionary) == fixed_before, "%s debug equip must not change fixed equipment" % enemy_id)
		var rejected_unequip: Dictionary = lab.debug_unequip("main_weapon")
		_assert((rejected_unequip.get("loadout", {}) as Dictionary) == fixed_before, "%s debug unequip must not change fixed equipment" % enemy_id)

	snapshot = lab.debug_select_unit("enemy:raider_mounted_archer")
	_assert(str(snapshot.get("mode", "")) == "combat", "enemy units should force the shared mode to combat")
	_assert(bool(snapshot.get("mount_visible", false)), "mounted enemies should always expose the same formal horse wrapper used by Main")
	_assert(bool(snapshot.get("uses_formal_enemy_mount", false)), "mounted enemy preview should use EnemyMountedArtView instead of the shared temporary mount")
	_assert(not bool(snapshot.get("enemy_mount_has_independent_hp", true)), "mounted enemy preview horse must not expose independent HP")
	_assert(str(snapshot.get("enemy_mount_damage_routing", "")) == "enemy_unit_only", "mounted enemy preview must display the real enemy-only damage routing")
	_assert((snapshot.get("usable_actions", []) as Array).has("mounted_defeat_escape"), "mounted enemy preview should expose the real defeat-and-escape acceptance action")
	_assert(str(((snapshot.get("loadout", {}) as Dictionary).get("main_weapon", {}) as Dictionary).get("id", "")) == "bow", "mounted archer should always use its configured bow")
	_assert(not (snapshot.get("usable_actions", []) as Array).has("work_dining_hall"), "enemy units should never expose cooking")
	snapshot = lab.debug_set_mode("work")
	_assert(str(snapshot.get("mode", "")) == "combat", "enemy units must reject work mode")
	var work_button := root.get_node("NPCDevLab/CanvasLayer/Overlay/ModePanel").find_child("WorkModeButton", true, false) as Button
	_assert(work_button != null and work_button.disabled, "enemy selection should disable the work-mode button")
	snapshot = lab.debug_select_unit("stableman_01")
	_assert(str(snapshot.get("mode", "")) == "combat", "returning to a friendly should keep the shared combat mode")
	_assert(str(snapshot.get("loadout_scope", "")) == "shared_across_friendlies", "returning to a friendly should restore the shared-friendly loadout scope")
	_assert(not bool(snapshot.get("enemy_equipment_locked", true)), "returning to a friendly should unlock equipment slots")
	_assert(str((snapshot.get("loadout", {}) as Dictionary).get("main_weapon", {}).get("id", "")) == "sword_shield", "shared weapon should remain equipped after friendly/enemy round-trip")
	var silhouette := root.get_node("NPCDevLab/CanvasLayer/Overlay/EquipmentPanel").find_child("TwoHeadSilhouette", true, false)
	_assert(silhouette != null, "equipment panel should contain the two-head silhouette")
	var rotation_area := root.get_node_or_null("NPCDevLab/Stage/RotationDragArea") as Area3D
	var overlay := root.get_node_or_null("NPCDevLab/CanvasLayer/Overlay") as Control
	var rotation_hint: Label = null
	if overlay != null:
		rotation_hint = overlay.find_child("RotationDragHint", true, false) as Label
	_assert(rotation_area != null and rotation_area.input_ray_pickable, "character preview should expose a pickable rotation drag area")
	_assert(overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "empty overlay space should pass clicks through to the 3D hit area")
	_assert(rotation_hint != null, "rotation drag affordance should be visible")
	snapshot = lab.debug_equip("mount", "horse_chestnut_wind")
	_assert(str(snapshot.get("selected_action_id", "")) == "mounted_pose", "re-equipping a mount should immediately restore the mounted pose")
	snapshot = lab.debug_trigger_action("attack")
	for _frame in 4:
		await process_frame
	snapshot = lab.debug_get_snapshot()
	var returned_mounted_sword_character := snapshot.get("character", {}) as Dictionary
	_assert(
		float(returned_mounted_sword_character.get("sword_grip_hand_distance", 1.0)) < 0.001,
		"friendly mounted sword grip should remain attached after an enemy/friendly round-trip"
	)
	snapshot = lab.debug_trigger_action("mounted_pose")
	for _frame in 40:
		await process_frame
	snapshot = lab.debug_get_snapshot()
	_assert(float(snapshot.get("mounted_forward_dot", -1.0)) > 0.99, "mounted facing should align before inspection drag")

	var drag_start: Dictionary = lab.debug_begin_rotation_drag()
	_assert(bool(drag_start.get("rotation_drag_active", false)), "character hit should start rotation drag")
	var drag_right: Dictionary = lab.debug_drag_rotation(100.0)
	_assert(is_equal_approx(float(drag_right.get("preview_yaw_degrees", 0.0)), 38.0), "right drag should rotate with deterministic sensitivity")
	var drag_left: Dictionary = lab.debug_drag_rotation(-50.0)
	_assert(is_equal_approx(float(drag_left.get("preview_yaw_degrees", 0.0)), 19.0), "left drag should rotate the preview back")
	_assert(is_equal_approx(float(drag_left.get("horse_yaw_degrees", 0.0)), 19.0), "horse and character preview should share the same yaw")
	_assert(float(drag_left.get("mounted_forward_dot", -1.0)) > 0.99, "mounted character and visible horse should stay aligned after inspection drag")
	_assert(is_equal_approx(float(drag_left.get("seat_preview_yaw_degrees", 0.0)), 19.0), "inspection stool and character preview should share the same yaw")
	lab.debug_end_rotation_drag()
	var released_snapshot: Dictionary = lab.debug_drag_rotation(100.0)
	_assert(not bool(released_snapshot.get("rotation_drag_active", true)), "mouse release should stop rotation drag")
	_assert(is_equal_approx(float(released_snapshot.get("preview_yaw_degrees", 0.0)), 19.0), "motion after release should not rotate preview")

	var formal_character := root.get_node_or_null("NPCDevLab/Stage/CharacterMount/PreviewCharacter") as Node3D
	_assert(formal_character != null, "mounted formal-state routing needs a live character presentation")
	if formal_character != null:
		formal_character.call("set_spatial_attachment_pose", "vehicle_seated")
		formal_character.call("set_movement_active", true, 3.2)
		var formal_snapshot: Dictionary = formal_character.call("debug_get_snapshot")
		_assert(str(formal_snapshot.get("desired_state", "")) == "mounted_walk", "formal mounted movement should route to mounted_walk")
		formal_character.call("set_movement_active", false, 0.0)
		formal_character.call("apply_profile", {"states": {"hp": 100, "unconscious": false, "current_action": "receive_weapon_training"}})
		formal_snapshot = formal_character.call("debug_get_snapshot")
		_assert(str(formal_snapshot.get("desired_state", "")) == "mounted_training", "formal mounted weapon training should route to mounted_training")
		formal_character.call("apply_profile", {"states": {"hp": 90, "unconscious": false, "current_action": "idle"}})
		var mounted_hit_event: Dictionary = formal_character.call(
			"play_temporary_presentation_action",
			"hit_react",
			"verify_t0156_mounted_hit"
		)
		formal_snapshot = formal_character.call("debug_get_snapshot")
		_assert(bool(mounted_hit_event.get("ok", false)), "formal mounted damage event should be accepted")
		_assert(str(formal_snapshot.get("desired_state", "")) == "mounted_hit_react", "formal mounted damage should route to mounted_hit_react")
		formal_character.call("set_spatial_attachment_pose", "")
		formal_character.set("_transient_state", "")
		formal_character.set("_transient_remaining", 0.0)
		formal_character.call("apply_profile", {"states": {"hp": 100, "unconscious": false, "current_action": "drink_wine"}})
		formal_snapshot = formal_character.call("debug_get_snapshot")
		_assert(str(formal_snapshot.get("desired_state", "")) == "drink", "formal drink_wine actions should route to the drinking state")
		_assert(bool(formal_snapshot.get("drink_mug_visible", false)), "formal drink_wine actions should show the right-hand mug")
		formal_character.set("_debug_equipment_preview_active", false)
		var formal_armor_equipment := {
			"helmet": {"id": "iron_helmet"},
			"chest": {"id": "mail_chest"},
			"bracers": {"id": "iron_bracers"},
			"greaves": {"id": "iron_greaves"},
		}
		formal_character.call("apply_profile", {"states": {"hp": 100, "unconscious": false, "current_action": "idle", "behavior_mode": "combat"}, "equipment": formal_armor_equipment})
		formal_snapshot = formal_character.call("debug_get_snapshot")
		var formal_armor := formal_snapshot.get("armor", {}) as Dictionary
		for armor_slot in ["helmet", "chest", "bracers", "greaves"]:
			_assert(bool((formal_armor.get(armor_slot, {}) as Dictionary).get("visible", false)), "formal combat profile should show equipped %s armor" % armor_slot)
		formal_character.call("apply_profile", {"states": {"hp": 100, "unconscious": false, "current_action": "idle", "behavior_mode": "work"}, "equipment": formal_armor_equipment})
		formal_snapshot = formal_character.call("debug_get_snapshot")
		formal_armor = formal_snapshot.get("armor", {}) as Dictionary
		for armor_slot in ["helmet", "chest", "bracers", "greaves"]:
			_assert(not bool((formal_armor.get(armor_slot, {}) as Dictionary).get("visible", true)), "formal work profile should hide equipped %s armor" % armor_slot)

	if _failed:
		quit(1)
	else:
		print("T0130-D1 NPC developer lab verification passed")
		quit(0)


var _failed := false


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _find_rotation_track(animation: Animation, bone_name: String) -> int:
	if animation == null:
		return -1
	for track_index in range(animation.get_track_count()):
		if animation.track_get_type(track_index) != Animation.TYPE_ROTATION_3D:
			continue
		var track_path := animation.track_get_path(track_index)
		if track_path.get_subname_count() > 0 and String(track_path.get_subname(0)) == bone_name:
			return track_index
	return -1


func _assert_upper_body_rotation_tracks_match(mounted_animation: Animation, foot_animation: Animation, label: String) -> void:
	_assert(mounted_animation != null and foot_animation != null, "%s and its foot source should both exist" % label)
	if mounted_animation == null or foot_animation == null:
		return
	_assert(is_equal_approx(mounted_animation.length, foot_animation.length), "%s should preserve the foot clip timing" % label)
	for bone_name in [
		"Spine", "Chest", "UpperChest", "Neck", "Head",
		"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
		"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
	]:
		var foot_track_index := _find_rotation_track(foot_animation, bone_name)
		if foot_track_index < 0:
			continue
		var mounted_track_index := _find_rotation_track(mounted_animation, bone_name)
		_assert(mounted_track_index >= 0, "%s should retain the foot %s track" % [label, bone_name])
		if mounted_track_index < 0:
			continue
		var key_count := foot_animation.track_get_key_count(foot_track_index)
		_assert(mounted_animation.track_get_key_count(mounted_track_index) == key_count, "%s %s should preserve every foot key" % [label, bone_name])
		for key_index in range(mini(key_count, mounted_animation.track_get_key_count(mounted_track_index))):
			var key_time := mounted_animation.track_get_key_time(mounted_track_index, key_index)
			_assert(is_equal_approx(key_time, foot_animation.track_get_key_time(foot_track_index, key_index)), "%s %s should preserve foot key timing" % [label, bone_name])
			var mounted_rotation := mounted_animation.track_get_key_value(mounted_track_index, key_index) as Quaternion
			var foot_rotation := foot_animation.track_get_key_value(foot_track_index, key_index) as Quaternion
			if bone_name == "Spine":
				var mounted_hips_track := _find_rotation_track(mounted_animation, "Hips")
				var foot_hips_track := _find_rotation_track(foot_animation, "Hips")
				_assert(mounted_hips_track >= 0 and foot_hips_track >= 0, "%s should expose both hip tracks for upper-body composition" % label)
				if mounted_hips_track >= 0 and foot_hips_track >= 0:
					var mounted_composed := (mounted_animation.rotation_track_interpolate(mounted_hips_track, key_time) * mounted_rotation).normalized()
					var foot_composed := (foot_animation.rotation_track_interpolate(foot_hips_track, key_time) * foot_rotation).normalized()
					_assert(mounted_composed.is_equal_approx(foot_composed), "%s should transfer the foot Hips+Spine orientation onto mounted Spine" % label)
			else:
				_assert(mounted_rotation.is_equal_approx(foot_rotation), "%s %s should preserve the exact foot pose" % [label, bone_name])


func _assert_mounted_lower_body_tracks_unchanged(mounted_animation: Animation, mounted_idle: Animation, label: String) -> void:
	_assert(mounted_animation != null and mounted_idle != null, "%s and mounted idle should both exist" % label)
	if mounted_animation == null or mounted_idle == null:
		return
	for bone_name in ["Hips", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]:
		var action_track_index := _find_rotation_track(mounted_animation, bone_name)
		var idle_track_index := _find_rotation_track(mounted_idle, bone_name)
		_assert(action_track_index >= 0 and idle_track_index >= 0, "%s should retain mounted-idle %s" % [label, bone_name])
		if action_track_index < 0 or idle_track_index < 0:
			continue
		var key_count := mounted_idle.track_get_key_count(idle_track_index)
		_assert(mounted_animation.track_get_key_count(action_track_index) == key_count, "%s should retain every mounted-idle %s key" % [label, bone_name])
		for key_index in range(mini(key_count, mounted_animation.track_get_key_count(action_track_index))):
			var action_rotation := mounted_animation.track_get_key_value(action_track_index, key_index) as Quaternion
			var idle_rotation := mounted_idle.track_get_key_value(idle_track_index, key_index) as Quaternion
			_assert(action_rotation.is_equal_approx(idle_rotation), "%s should keep %s frozen to the mounted straddle track" % [label, bone_name])


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
