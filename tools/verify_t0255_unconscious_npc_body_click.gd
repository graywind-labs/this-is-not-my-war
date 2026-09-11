extends SceneTree


const NPC_ID := "veteran_deputy_01"
const INTERACTION_MASK := 4


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("T0255 could not load Main.tscn")
		return
	var main := main_scene.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup.set("_startup_running", true)
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	var npc := _find_npc_node(main, NPC_ID)
	if npc_system == null or npc_panel == null or npc == null:
		_fail("T0255 required NPC runtime nodes are missing")
		return
	var interaction_area := npc.get_node_or_null("InteractionArea") as Area3D
	var interaction_collision := npc.get_node_or_null("InteractionArea/InteractionCollision") as CollisionShape3D
	var body_collision := npc.get_node_or_null("BodyCollision") as CollisionShape3D
	if interaction_area == null or interaction_collision == null or body_collision == null:
		_fail("T0255 NPC collision nodes are missing")
		return

	var standing: Dictionary = npc.debug_get_spatial_attachment_snapshot()
	if (
		str(standing.get("interaction_pose", "")) != "standing"
		or absf((standing.get("interaction_long_axis", Vector3.ZERO) as Vector3).dot(Vector3.UP)) < 0.99
		or not _ray_hits_area(npc, interaction_area, Vector3(0.0, 2.2, 0.0), Vector3(0.0, -0.2, 0.0))
	):
		_fail("T0255 standing interaction did not cover the visible upright body: %s" % standing)
		return

	var damage_result: Dictionary = npc_system.apply_damage_to_npc(
		NPC_ID,
		999,
		"guard_officer",
		"private",
		{"request_plan_reevaluation": false}
	)
	await process_frame
	await physics_frame
	var fallen: Dictionary = npc.debug_get_spatial_attachment_snapshot()
	var fallen_axis: Vector3 = fallen.get("interaction_long_axis", Vector3.ZERO)
	if (
		not bool(damage_result.get("unconscious", false))
		or str(fallen.get("interaction_pose", "")) != "unconscious_horizontal"
		or absf(fallen_axis.dot(Vector3.RIGHT)) < 0.99
		or float(fallen.get("interaction_capsule_height", 0.0)) < 2.0
		or float(fallen.get("interaction_local_position", Vector3.ZERO).y) > 0.5
		or not body_collision.disabled
	):
		_fail("T0255 unconscious interaction did not follow the fallen body: %s" % fallen)
		return

	# The new horizontal capsule reaches the visible fallen torso/legs to the side.
	var fallen_body_hit := _ray_hits_area(
		npc,
		interaction_area,
		Vector3(0.78, 2.0, -0.12),
		Vector3(0.78, -0.2, -0.12)
	)
	# The old upright capsule's upper region must no longer be the primary hot area.
	var stale_upright_hit := _ray_hits_area(
		npc,
		interaction_area,
		Vector3(0.0, 1.35, -1.5),
		Vector3(0.0, 1.35, 1.5)
	)
	if not fallen_body_hit or stale_upright_hit:
		_fail("T0255 fallen-body ray contract failed: body=%s stale_upright=%s" % [fallen_body_hit, stale_upright_hit])
		return

	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if camera == null:
		_fail("T0255 production camera is missing")
		return
	var fallen_screen_position := camera.unproject_position(npc.to_global(Vector3(0.78, 0.44, -0.12)))
	var picked: Dictionary = npc_system._pick_npc_interaction_at_screen_position(fallen_screen_position)
	if str(picked.get("npc_id", "")) != NPC_ID:
		_fail("T0255 production camera ray did not resolve the fallen body: %s" % picked)
		return

	npc_panel.visible = false
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = fallen_screen_position
	click.global_position = fallen_screen_position
	npc_system._unhandled_input(click)
	await process_frame
	if not npc_panel.visible or str(npc_panel.get("_current_npc_id")) != NPC_ID:
		_fail("T0255 clicking the fallen body did not open the correct NPCPanel")
		return

	var revive_result: Dictionary = npc_system.debug_advance_unconscious_recovery(NPC_ID, 200000.0)
	await process_frame
	await physics_frame
	var revived: Dictionary = npc.debug_get_spatial_attachment_snapshot()
	if (
		not (revive_result.get("revived", []) as Array).has(NPC_ID)
		or str(revived.get("interaction_pose", "")) != "standing"
		or absf((revived.get("interaction_long_axis", Vector3.ZERO) as Vector3).dot(Vector3.UP)) < 0.99
		or body_collision.disabled
	):
		_fail("T0255 revive did not restore the standing interaction: %s" % revived)
		return

	print("T0255_UNCONSCIOUS_NPC_BODY_CLICK_OK %s" % JSON.stringify({
		"standing": standing,
		"fallen": fallen,
		"revived": revived,
		"panel_npc_id": str(npc_panel.get("_current_npc_id"))
	}))
	quit(0)


func _find_npc_node(main: Node, npc_id: String) -> Node3D:
	for raw_node in main.find_children("*", "CharacterBody3D", true, false):
		if str(raw_node.get_meta("npc_id", "")) == npc_id:
			return raw_node as Node3D
	return null


func _ray_hits_area(npc: Node3D, area: Area3D, local_from: Vector3, local_to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		npc.to_global(local_from),
		npc.to_global(local_to),
		INTERACTION_MASK
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit: Dictionary = npc.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") == area


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
