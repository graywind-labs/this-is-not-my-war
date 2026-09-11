extends SceneTree


const NPC_ID := "blacksmith_01"
const BUILDING_ID := "blacksmith"
const ACTION_ID := "work_blacksmith"
const RECIPE_ID := "craft_iron_helmet"
const FORGE_ID := "forge_01"
const LANTERN_NAMES := ["RearForgeLantern", "SmithingBayLantern", "ServiceLantern", "Forge03Lantern"]

var _failed := false


func _init() -> void:
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in range(10):
		await process_frame
		await physics_frame
	var blacksmith := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Blacksmith") as Node3D
	var art := blacksmith.get_node_or_null("BlacksmithArt") if blacksmith != null else null
	var visuals := blacksmith.get_node_or_null("FixtureLayout/Visuals") if blacksmith != null else null
	var collision_root := blacksmith.get_node_or_null("StaticCollision") if blacksmith != null else null
	var ambient := art.get_node_or_null("Interior/ForgeAmbient/AmbientFX") if art != null else null
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var glen := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Blacksmith01") as CharacterBody3D
	if [blacksmith, art, visuals, collision_root, ambient, action_system, npc_system, building_system, crafting_system, resource_system, time_system, glen].has(null):
		_fail("P8AR3 runtime hierarchy is incomplete")
		return
	if not await _verify_structure(blacksmith, art, visuals, collision_root, ambient):
		return
	if not await _verify_real_work(blacksmith, art, visuals, ambient, action_system, npc_system, building_system, crafting_system, resource_system, time_system, glen):
		return
	print("T0135-P8AR3 blacksmith hybrid forge verification passed")
	quit(0)


func _verify_structure(blacksmith: Node3D, art: Node, visuals: Node, collision_root: Node, ambient: Node) -> bool:
	var snapshot := art.call("get_art_slice_snapshot") as Dictionary
	if str(snapshot.get("structure_profile", "")) != "rear_masonry_forge_with_flat_roofed_fully_open_front_smithing_shed":
		return _fail_bool("Blacksmith did not expose the approved fully open-front structure profile")
	var side_shape := _collision_box_size(collision_root.get_node_or_null("LeftWall"))
	if side_shape.z > 4.61 or collision_root.get_node_or_null("FrontLeft") != null or collision_root.get_node_or_null("FrontRight") != null:
		return _fail_bool("Fully open front visual shell and structural collision do not match")
	var exterior := art.get_node_or_null("Exterior")
	if exterior == null:
		return _fail_bool("Blacksmith exterior root is missing")
	for removed_name in ["FrontWall", "FrontDoor", "DoorJambLeft", "DoorJambRight", "AutoDoor"]:
		if exterior.get_node_or_null(removed_name) != null:
			return _fail_bool("Open smithy front still contains enclosure part: %s" % removed_name)
	if int(snapshot.get("front_support_post_count", 0)) != 4:
		return _fail_bool("Open smithy front did not retain exactly four original roof posts")
	var flat_deck := art.get_node_or_null("Roof/FlatSlateDeck") as MeshInstance3D
	if flat_deck == null or not flat_deck.mesh is BoxMesh:
		return _fail_bool("Blacksmith flat roof deck is missing")
	var roof_bottom := flat_deck.position.y - (flat_deck.mesh as BoxMesh).size.y * 0.5
	for brace_name in ["ReinforcedWallBraceWest", "ReinforcedWallBraceEast"]:
		var brace := art.get_node_or_null("UpgradeVisuals/Level2/ExteriorAdditions/%s" % brace_name) as MeshInstance3D
		if brace == null or not brace.mesh is BoxMesh:
			return _fail_bool("Smithy side reinforcement column is missing: %s" % brace_name)
		var brace_size := (brace.mesh as BoxMesh).size
		var brace_bottom := brace.position.y - brace_size.y * 0.5
		var brace_top := brace.position.y + brace_size.y * 0.5
		if brace_bottom > 0.181 or brace_top > roof_bottom - 0.019:
			return _fail_bool("Smithy side reinforcement column is not grounded below the flat roof: %s bottom=%.3f top=%.3f roof=%.3f" % [brace_name, brace_bottom, brace_top, roof_bottom])
	var hearth := art.get_node_or_null("Interior/ForgeAmbient") as Node3D
	var chimney := art.get_node_or_null("ChimneyAssembly/StoneChimney") as Node3D
	if hearth == null or chimney == null:
		return _fail_bool("Detailed rear hearth or chimney is missing")
	var open_direction: Vector3 = hearth.get_meta("open_direction_local", Vector3.ZERO)
	var direction_to_anvils := Vector3(0.0, 0.0, -3.65) - hearth.position
	if open_direction.normalized().dot(direction_to_anvils.normalized()) < 0.99:
		return _fail_bool("Forge mouth still faces the wall instead of the anvils")
	if Vector2(hearth.position.x, hearth.position.z).distance_to(Vector2(chimney.position.x, chimney.position.z)) > 0.1:
		return _fail_bool("Chimney is no longer vertically aligned with the hearth")
	for fixture_id in ["forge_01_anvil", "forge_02_anvil", "forge_03_anvil"]:
		var fixture := _find_by_meta(visuals, "fixture_id", fixture_id) as Node3D
		var bounds := _local_visual_bounds(fixture, blacksmith)
		var size: Vector3 = bounds.get("size", Vector3.ZERO)
		var minimum: Vector3 = bounds.get("min", Vector3.ZERO)
		if fixture == null or fixture.get_node_or_null("AnvilStump") == null or fixture.get_node_or_null("StoneFoot") == null:
			return _fail_bool("Anvil is missing its modeled stump/footing: %s" % fixture_id)
		if minimum.y > 0.181 or size.y < 0.93:
			return _fail_bool("Anvil support does not bridge floor to iron head: %s => %s" % [fixture_id, bounds])
		var hot_metal := fixture.get_node_or_null("HotMetal") as Node3D
		if hot_metal == null or hot_metal.visible:
			return _fail_bool("Idle anvil hot metal must exist but remain cold/hidden: %s" % fixture_id)
	for prefix in ["Forge01", "Forge02", "Forge03"]:
		var level_path := "Interior/Level1StationDecor" if prefix != "Forge03" else "UpgradeVisuals/Level3/InteriorAdditions"
		var decor := art.get_node_or_null(level_path)
		if decor == null or decor.get_node_or_null("%sToolRestTop" % prefix) == null or decor.get_node_or_null("%sToolRestLeg" % prefix) == null:
			return _fail_bool("Tool rest is not physically supported: %s" % prefix)
	var lamp_mount_contract := {
		"Support_RearForgeLantern": "WallBackplate",
		"Support_SmithingBayLantern": "WallBackplate",
		"Support_ServiceLantern": "WallBackplate",
		"Support_Forge03Lantern": "WallBackplate",
	}
	for support_name in lamp_mount_contract:
		var support := _find_descendant_named(art, str(support_name)) as Node3D
		var contact_name := str(lamp_mount_contract[support_name])
		if support == null or support.get_node_or_null(contact_name) == null or str(support.get_meta("structural_mount_kind", "")).is_empty():
			return _fail_bool("Smithy lantern is not connected to modeled structure: %s" % support_name)
		for forbidden_frame_part in ["CanopyTieBeam", "CanopyEndPost", "ServicePost", "ForgeTieBeam", "TrussEndPost"]:
			if support.get_node_or_null(forbidden_frame_part) != null:
				return _fail_bool("Smithy lantern still owns an obstructive dedicated frame: %s/%s" % [support_name, forbidden_frame_part])
	var grindstone := art.get_node_or_null("UpgradeVisuals/Level2/InteriorAdditions/PedalGrindstone") as Node3D
	if grindstone == null or absf(grindstone.position.x) < 2.5 or grindstone.position.z > 3.6 or not bool(grindstone.get_meta("primary_entry_clear", false)):
		return _fail_bool("Pedal grindstone still blocks the primary entry lane")
	var roof_structure := art.get_node_or_null("UpgradeVisuals/Level3/RoofStructureAdditions")
	if (
		roof_structure == null
		or roof_structure.get_node_or_null("CeilingHoistBeam") == null
		or roof_structure.get_node_or_null("HoistChain") == null
		or roof_structure.get_node_or_null("HoistHook") == null
		or art.get_node_or_null("UpgradeVisuals/Level3/InteriorAdditions/HoistChain") != null
	):
		return _fail_bool("Hoist chain/hook do not share the roof support fade branch")
	var idle_fx := ambient.call("debug_force_refresh") as Dictionary
	if (
		bool(idle_fx.get("forge_active", true))
		or bool(idle_fx.get("sparks_emitting", true))
		or bool(idle_fx.get("smoke_emitting", true))
		or float(idle_fx.get("fire_light_energy", -1.0)) > 0.001
		or int(idle_fx.get("active_station_heat_visual_count", -1)) != 0
	):
		return _fail_bool("Empty forge still emits work-only heat effects: %s" % idle_fx)
	for level in [1, 2, 3]:
		art.call("debug_force_visual_level", level)
		await process_frame
		var expected: int = int(level) + 1
		if _visible_lantern_count(art) != expected:
			return _fail_bool("Blacksmith lanterns did not progress 2/3/4 at Lv.%d" % level)
	art.call("debug_force_visual_level", 1)
	return true


func _verify_real_work(
	blacksmith: Node3D,
	art: Node,
	visuals: Node,
	ambient: Node,
	action_system: Node,
	npc_system: Node,
	building_system: Node,
	crafting_system: Node,
	resource_system: Node,
	time_system: Node,
	glen: CharacterBody3D
) -> bool:
	time_system.call("set_paused", false)
	time_system.call("set_current_time", 1, 19, 0, 0)
	glen.set("move_speed", 40.0)
	resource_system.call("add_resource", "iron", 10)
	resource_system.call("add_resource", "wood", 10)
	var target := crafting_system.call("set_target", BUILDING_ID, RECIPE_ID, true) as Dictionary
	if not bool(target.get("ok", false)):
		return _fail_bool("Could not prepare real blacksmith work: %s" % target)
	npc_system.call("update_npc_state", NPC_ID, {"fatigue": 0, "satiety": 100, "current_action": "idle"})
	if not bool(action_system.call("debug_assign_work", NPC_ID, BUILDING_ID)):
		return _fail_bool("Real Glen blacksmith action did not dispatch")
	for _frame in range(1800):
		await physics_frame
		var runtime := action_system.call("get_runtime_action_snapshot", NPC_ID) as Dictionary
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == ACTION_ID:
			break
		if _frame == 1799:
			return _fail_bool("Glen did not physically reach the corrected anvil stand")
	for _frame in range(4):
		await process_frame
	var active_fx := ambient.call("debug_force_refresh") as Dictionary
	if (
		not bool(active_fx.get("forge_active", false))
		or not bool(active_fx.get("sparks_emitting", false))
		or not bool(active_fx.get("smoke_emitting", false))
		or float(active_fx.get("fire_light_energy", 0.0)) <= 0.1
		or not (active_fx.get("active_workstation_ids", []) as Array).has(FORGE_ID)
		or int(active_fx.get("active_station_heat_visual_count", 0)) != 1
	):
		return _fail_bool("Active real forge did not light all work-only effects: %s" % active_fx)
	var anvil := _find_by_meta(visuals, "fixture_id", "forge_01_anvil") as Node3D
	var glen_local := blacksmith.to_local(glen.global_position)
	var horizontal_distance := Vector2(glen_local.x, glen_local.z).distance_to(Vector2(anvil.position.x, anvil.position.z))
	if horizontal_distance < 1.05 or horizontal_distance > 1.16:
		return _fail_bool("Glen/anvil strike distance is outside the corrected reach band: %.3f" % horizontal_distance)
	var art_snapshot := glen.call("debug_get_character_art_snapshot") as Dictionary
	var visible_forward: Vector3 = art_snapshot.get("visual_forward", Vector3.ZERO)
	var target_forward: Vector3 = art_snapshot.get("target_facing_direction", Vector3.ZERO)
	if visible_forward.length_squared() <= 0.001 or target_forward.length_squared() <= 0.001 or visible_forward.normalized().dot(target_forward.normalized()) < 0.9:
		return _fail_bool("Glen visible front is not aligned with the anvil-facing work pose")
	if not bool(action_system.call("interrupt_npc_action", NPC_ID, "verify_p8ar3_forge_stop", true)):
		return _fail_bool("Could not interrupt real blacksmith work for extinguish verification")
	for _frame in range(5):
		await process_frame
	var stopped_fx := ambient.call("debug_force_refresh") as Dictionary
	if (
		bool(stopped_fx.get("forge_active", true))
		or bool(stopped_fx.get("sparks_emitting", true))
		or bool(stopped_fx.get("smoke_emitting", true))
		or float(stopped_fx.get("fire_light_energy", -1.0)) > 0.001
		or int(stopped_fx.get("active_station_heat_visual_count", -1)) != 0
	):
		return _fail_bool("Forge effects did not extinguish after authoritative work stopped: %s" % stopped_fx)
	if not _workstation_clear(building_system, FORGE_ID):
		return _fail_bool("Interrupt left the corrected forge occupied")
	return true


func _visible_lantern_count(art: Node) -> int:
	var count := 0
	for lantern_name in LANTERN_NAMES:
		for raw_match in art.find_children(lantern_name, "Node3D", true, false):
			if (raw_match as Node3D).is_visible_in_tree():
				count += 1
	return count


func _collision_box_size(body: Node) -> Vector3:
	if body == null:
		return Vector3.ZERO
	var shape_node := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or not shape_node.shape is BoxShape3D:
		return Vector3.ZERO
	return (shape_node.shape as BoxShape3D).size


func _find_by_meta(parent: Node, key: String, value: String) -> Node:
	if parent == null:
		return null
	for child in parent.get_children():
		if str(child.get_meta(key, "")) == value:
			return child
	return null


func _find_descendant_named(parent: Node, node_name: String) -> Node:
	if parent == null:
		return null
	for raw_match in parent.find_children(node_name, "Node", true, false):
		return raw_match
	return null


func _local_visual_bounds(node: Node3D, relative_to: Node3D) -> Dictionary:
	if node == null:
		return {}
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for raw_mesh in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var aabb := mesh_instance.mesh.get_aabb()
		for corner_index in range(8):
			var local_point := relative_to.to_local(mesh_instance.to_global(aabb.get_endpoint(corner_index)))
			minimum = minimum.min(local_point)
			maximum = maximum.max(local_point)
	return {"min": minimum, "max": maximum, "size": maximum - minimum}


func _workstation_clear(building_system: Node, workstation_id: String) -> bool:
	for raw_workstation in (building_system.call("get_building", BUILDING_ID) as Dictionary).get("workstations", []):
		var workstation := raw_workstation as Dictionary
		if str(workstation.get("id", "")) != workstation_id:
			continue
		return _clean_id(workstation.get("occupied_by", "")).is_empty() and _clean_id(workstation.get("reserved_by", "")).is_empty()
	return false


func _clean_id(value: Variant) -> String:
	if value == null:
		return ""
	var result := str(value)
	return "" if result in ["", "<null>", "null"] else result


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
