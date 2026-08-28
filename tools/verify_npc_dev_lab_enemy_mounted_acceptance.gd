extends SceneTree

const MOUNTED_PRESENTATION_REFERENCE := preload("res://scripts/presentation/characters/MountedPresentationReference.gd")


func _init() -> void:
	var packed := load("res://scenes/debug/NPCDevLab.tscn") as PackedScene
	if packed == null:
		_fail("NPCDevLab.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	await process_frame
	await process_frame

	var lab := root.get_node_or_null("NPCDevLab")
	if lab == null:
		_fail("NPCDevLab root is missing")
		return

	var snapshot: Dictionary = lab.debug_select_unit("enemy:raider_cavalry")
	for _frame in 30:
		await process_frame
	snapshot = lab.debug_get_snapshot()
	_assert_formal_mount(snapshot, "cavalry")
	_assert(str(snapshot.get("selected_action_id", "")) == "mounted_pose", "mounted cavalry should open in its real mounted idle pose")
	_assert(str((snapshot.get("character", {}) as Dictionary).get("current_clip", "")) == "Mounted_Idle", "mounted cavalry idle should use Mounted_Idle")
	var cavalry_character: Dictionary = snapshot.get("character", {})
	_assert(bool(cavalry_character.get("foot_sword_attack_attachment_valid", false)), "mounted cavalry must cache the approved foot-combat hand-to-sword contract before its first mounted profile")

	snapshot = lab.debug_trigger_action("walk")
	await process_frame
	snapshot = lab.debug_get_snapshot()
	_assert(str((snapshot.get("character", {}) as Dictionary).get("desired_state", "")) == "mounted_walk", "cavalry walk should route through the real mounted movement state")
	_assert(str(snapshot.get("horse_animation", "")) == "Walk", "cavalry movement should drive the real wrapper horse Walk clip")

	snapshot = lab.debug_trigger_action("attack")
	await process_frame
	snapshot = lab.debug_get_snapshot()
	_assert(str((snapshot.get("character", {}) as Dictionary).get("desired_state", "")) == "mounted_attack", "cavalry attack should route through the real mounted attack state")
	_assert(str((snapshot.get("character", {}) as Dictionary).get("current_clip", "")) == "Mounted_1H_Attack", "cavalry attack should use the production mounted attack clip")
	cavalry_character = snapshot.get("character", {})
	var attack_sword_transform := Transform3D(cavalry_character.get("sword_local_transform", Transform3D.IDENTITY))
	_assert(float(cavalry_character.get("sword_grip_hand_distance", 1.0)) < 0.01, "enemy mounted attack must anchor the visible sword handle in the right gauntlet")
	var cavalry_player := lab.find_child("PilotAnimationPlayer", true, false) as AnimationPlayer
	var cavalry_attack := cavalry_player.get_animation("Mounted_1H_Attack") if cavalry_player != null else null
	_assert(cavalry_attack != null, "enemy mounted attack should expose the shared friendly Mounted_1H_Attack clip")
	if cavalry_player != null and cavalry_attack != null:
		for attack_progress in [0.2, 0.5, 0.8]:
			cavalry_player.play("Mounted_1H_Attack", 0.0)
			cavalry_player.seek(cavalry_attack.length * attack_progress, true)
			cavalry_player.pause()
			await process_frame
			cavalry_character = ((lab.debug_get_snapshot().get("character", {}) as Dictionary))
			_assert(Transform3D(cavalry_character.get("sword_local_transform", Transform3D.IDENTITY)).is_equal_approx(attack_sword_transform), "enemy mounted sword must keep one rigid hand attachment throughout the shared friendly swing")
			_assert(float(cavalry_character.get("sword_grip_hand_distance", 1.0)) < 0.01, "enemy mounted sword handle must remain inside the right gauntlet throughout the swing")

	snapshot = lab.debug_trigger_action("hit_react")
	await process_frame
	snapshot = lab.debug_get_snapshot()
	_assert(str((snapshot.get("character", {}) as Dictionary).get("desired_state", "")) == "mounted_hit_react", "cavalry hit preview should use the production mounted hit reaction")

	snapshot = lab.debug_trigger_action("mounted_defeat_escape")
	await process_frame
	snapshot = lab.debug_get_snapshot()
	var defeat: Dictionary = snapshot.get("character", {})
	_assert(str(defeat.get("escape_phase", "")) == "fleeing_to_map_edge", "defeat acceptance action should start the real horse escape state")
	_assert(bool(defeat.get("mounted_fall_active", false)), "defeat acceptance action should start the rider fall at the same time")
	_assert(str(defeat.get("current_clip", "")) == "Death_A", "mounted enemy defeat should reuse the agreed Death_A clip")

	await create_timer(0.46).timeout
	snapshot = lab.debug_get_snapshot()
	defeat = snapshot.get("character", {})
	_assert(float(defeat.get("mounted_fall_progress", 0.0)) >= 0.35, "DevLab should expose a readable airborne rider phase")
	_assert(float(defeat.get("escape_distance", 0.0)) > 2.0, "horse should visibly leave the rider while the fall advances")

	snapshot = lab.debug_advance_enemy_mounted_escape(60.0)
	var released: Dictionary = snapshot.get("last_enemy_mounted_escape", {})
	_assert(str(released.get("escape_phase", "")) == "released_outside_map", "formal wrapper should release the horse after it leaves the DevLab view")
	_assert(bool(released.get("released_outside_map", false)), "released snapshot should retain the outside-map fact")

	snapshot = lab.debug_trigger_action("mounted_pose")
	for _frame in 30:
		await process_frame
	snapshot = lab.debug_get_snapshot()
	_assert_formal_mount(snapshot, "replayed cavalry")
	_assert(str((snapshot.get("character", {}) as Dictionary).get("escape_phase", "")) == "mounted", "clicking another action should respawn the formal mounted wrapper for replay")

	snapshot = lab.debug_select_unit("enemy:raider_archer")
	await process_frame
	snapshot = lab.debug_get_snapshot()
	_assert(not bool(snapshot.get("mount_visible", false)), "ordinary ranged enemy must not inherit a horse")
	_assert(not bool(snapshot.get("uses_formal_enemy_mount", false)), "ordinary ranged enemy must not use EnemyMountedArtView")
	_assert(not (snapshot.get("usable_actions", []) as Array).has("mounted_defeat_escape"), "ordinary enemy must not expose mounted defeat acceptance")

	snapshot = lab.debug_select_unit("enemy:raider_mounted_archer")
	for _frame in 30:
		await process_frame
	snapshot = lab.debug_get_snapshot()
	_assert_formal_mount(snapshot, "mounted ranged")
	_assert(str((snapshot.get("character", {}) as Dictionary).get("equipment_mode", "")) == "none", "mounted ranged preview should not counterfeit a sword and shield")

	if _failed:
		quit(1)
	else:
		print("T0139-D1 NPCDevLab enemy mounted acceptance verification passed.")
		quit(0)


var _failed := false


func _assert_formal_mount(snapshot: Dictionary, label: String) -> void:
	_assert(bool(snapshot.get("mount_visible", false)), "%s should show its horse" % label)
	_assert(bool(snapshot.get("uses_formal_enemy_mount", false)), "%s should use EnemyMountedArtView" % label)
	_assert(snapshot.get("enemy_mount_has_independent_hp", true) != true, "%s horse must have no independent HP" % label)
	_assert(str(snapshot.get("enemy_mount_damage_routing", "")) == "enemy_unit_only", "%s damage routing must stay enemy-unit-only" % label)
	_assert(Vector3(snapshot.get("horse_root_position", Vector3.ZERO)).is_equal_approx(MOUNTED_PRESENTATION_REFERENCE.ENEMY_HORSE_LOCAL_POSITION), "%s horse position should use the shared production reference" % label)
	_assert(Vector3(snapshot.get("horse_model_scale", Vector3.ZERO)).is_equal_approx(MOUNTED_PRESENTATION_REFERENCE.ENEMY_HORSE_SCALE), "%s horse scale should use the shared production reference" % label)
	_assert(float(snapshot.get("mounted_forward_dot", -1.0)) > 0.99, "%s rider and horse should share the same visible facing: dot=%s rider=%s horse=%s" % [label, snapshot.get("mounted_forward_dot", -1.0), snapshot.get("character_visible_forward", Vector3.ZERO), snapshot.get("horse_visible_forward", Vector3.ZERO)])


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
