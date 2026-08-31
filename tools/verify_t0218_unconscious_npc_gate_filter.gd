extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gate_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/WallsAndGates/FrontGate") as Node3D
	var gate_art := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/WallsAndGates/FortificationArt/GateArt/FrontGateArt") as Node3D
	var npc_actor := _get_npc_actor(npc_system, NPC_ID) as CharacterBody3D
	_check(npc_system != null and time_system != null, "T0218 NPC/time systems missing")
	_check(gate_root != null and gate_art != null and npc_actor != null, "T0218 formal NPC/gate runtime missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)
	if npc_actor.has_method("stop_movement"):
		npc_actor.stop_movement()
	npc_actor.global_position = gate_root.to_global(Vector3(0.0, 0.2, -3.0))
	gate_art.call("debug_set_open_fraction", 0.0)

	for _frame in range(40):
		await physics_frame
	var conscious_snapshot: Dictionary = gate_art.call("debug_get_snapshot")
	_check(bool(gate_art.call("_is_friendly_body", npc_actor)), "T0218 conscious NPC was rejected by the gate identity filter")
	_check(bool(conscious_snapshot.get("friendly_near", false)), "T0218 conscious NPC was not detected near the gate: %s" % conscious_snapshot)
	_check(float(conscious_snapshot.get("open_fraction", 0.0)) > 0.25, "T0218 conscious NPC did not open the gate: %s" % conscious_snapshot)

	var damage_result: Dictionary = npc_system.debug_damage_npc(NPC_ID, 10000, "local_public")
	_check(bool(damage_result.get("ok", false)), "T0218 failed to knock out the gate-side NPC: %s" % damage_result)
	_check(bool(npc_actor.call("is_unconscious")), "T0218 NPC actor did not expose the authoritative unconscious state")
	_check(not bool(gate_art.call("_is_friendly_body", npc_actor)), "T0218 newly unconscious NPC remained a friendly gate trigger before collision refresh")
	var immediate_unconscious_snapshot: Dictionary = gate_art.call("debug_get_snapshot")
	_check(not bool(immediate_unconscious_snapshot.get("friendly_near", true)), "T0218 unconscious NPC still counted as near the gate: %s" % immediate_unconscious_snapshot)

	for _frame in range(170):
		await physics_frame
	var unconscious_snapshot: Dictionary = gate_art.call("debug_get_snapshot")
	var attachment: Dictionary = npc_actor.debug_get_spatial_attachment_snapshot()
	_check(not bool(unconscious_snapshot.get("friendly_near", true)), "T0218 fallen NPC kept the gate sensor active: %s" % unconscious_snapshot)
	_check(float(unconscious_snapshot.get("open_fraction", 1.0)) <= 0.01, "T0218 gate did not close after the nearby NPC fell unconscious: %s" % unconscious_snapshot)
	_check(bool(attachment.get("body_collision_disabled", false)), "T0218 unconscious NPC body collision was not suppressed: %s" % attachment)
	_check(bool(attachment.get("interaction_enabled", false)), "T0218 unconscious NPC lost its interaction area: %s" % attachment)

	var revive_result: Dictionary = npc_system._revive_npc_from_unconscious(NPC_ID, 0, 1, "t0218_verification")
	_check(bool(revive_result.get("revived", false)), "T0218 failed to revive the gate-side NPC: %s" % revive_result)
	for _frame in range(45):
		await physics_frame
	var revived_snapshot: Dictionary = gate_art.call("debug_get_snapshot")
	var revived_attachment: Dictionary = npc_actor.debug_get_spatial_attachment_snapshot()
	_check(not bool(npc_actor.call("is_unconscious")), "T0218 revived NPC still reports unconscious")
	_check(bool(revived_snapshot.get("friendly_near", false)), "T0218 revived NPC was not redetected near the gate: %s" % revived_snapshot)
	_check(float(revived_snapshot.get("open_fraction", 0.0)) > 0.25, "T0218 revived NPC did not reopen the gate: %s" % revived_snapshot)
	_check(not bool(revived_attachment.get("body_collision_disabled", true)), "T0218 revived NPC body collision did not return: %s" % revived_attachment)

	print("T0218_UNCONSCIOUS_NPC_GATE_FILTER_DIAGNOSTICS %s" % JSON.stringify({
		"conscious_gate": conscious_snapshot,
		"immediate_unconscious_gate": immediate_unconscious_snapshot,
		"unconscious_gate": unconscious_snapshot,
		"revived_gate": revived_snapshot,
		"unconscious_interaction_enabled": bool(attachment.get("interaction_enabled", false))
	}))
	_finish()


func _get_npc_actor(npc_system: Node, npc_id: String) -> Node:
	if npc_system == null:
		return null
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath("")))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0218_UNCONSCIOUS_NPC_GATE_FILTER_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
