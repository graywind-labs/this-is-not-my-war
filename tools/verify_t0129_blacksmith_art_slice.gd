extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const BLACKSMITH_VIEW_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Blacksmith/BlacksmithArt"
const LEGACY_VIEW_PATH := "Main/WorldRoot/Station/Buildings/BlacksmithArtView"
const GLEN_ID := "blacksmith_01"

var _failed := false


func _init() -> void:
	var main_scene := load(MAIN_SCENE_PATH) as PackedScene
	if main_scene == null:
		_fail("Failed to load Main scene")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame
	var art_view := root.get_node_or_null(BLACKSMITH_VIEW_PATH)
	if not _expect(art_view != null and art_view.has_method("get_art_slice_snapshot"), "Formal 14x12 blacksmith art view is missing"):
		return
	if not _expect(root.get_node_or_null(LEGACY_VIEW_PATH) != art_view, "T0129 still points at the rejected 4x4 prototype"):
		return
	var level_1: Dictionary = art_view.debug_force_visual_level(1)
	if not _verify_level_one(art_view, level_1):
		return
	art_view.apply_roof_camera_distance(70.0, 1.0)
	var far_roof: Dictionary = art_view.get_roof_visibility_snapshot()
	if not _expect(float(far_roof.get("roof_opacity", 0.0)) >= 0.98, "Far camera does not restore the complete smithy roof"):
		return
	art_view.apply_roof_camera_distance(58.0, 0.0)
	var near_roof: Dictionary = art_view.get_roof_visibility_snapshot()
	if not _expect(float(near_roof.get("roof_opacity", 1.0)) <= 0.1 and float(near_roof.get("exterior_opacity", 1.0)) <= 0.1 and bool(near_roof.get("interior_revealed_for_selection", false)) and bool(near_roof.get("roof_shadow_enabled", false)) and bool(near_roof.get("exterior_shadow_enabled", false)) and not bool(near_roof.get("visible_shell_meshes_cast_shadow", true)), "Near camera must reveal the formal interior while preserving roof/wall shadows through proxies"):
		return
	if not await _verify_transparent_interior_click_contract(art_view):
		return
	var level_2: Dictionary = art_view.debug_force_visual_level(2)
	if not _expect(bool(level_2.get("level_2_visible", false)) and not bool(level_2.get("level_3_visible", true)), "Level 2 visual delta is wrong"):
		return
	if not _expect(int(level_2.get("active_workstation_visual_count", 0)) == 4, "Level 2 must add only the fuel reserve while preserving two forge bays"):
		return
	for path in [
		"ChimneyAssembly/StoneChimney",
		"ChimneyAssembly/InteriorSmokeHood",
		"UpgradeVisuals/Level2/ExteriorAdditions/FuelShelter/SlateLeanToRoof",
		"UpgradeVisuals/Level2/ExteriorAdditions/FuelShelter/OuterFascia",
		"UpgradeVisuals/Level2/ExteriorAdditions/FuelShelter/FuelBarrel",
		"UpgradeVisuals/Level2/InteriorAdditions/FinishedWeaponStand",
		"UpgradeVisuals/Level2/InteriorAdditions/PedalGrindstone",
		"Interior/ForgeAmbient/Bellows",
		"Interior/Level1CommonProps/RepairWorkbench",
		"Interior/Level1CommonProps/MaterialShelf",
		"Interior/Level1CommonProps/QuenchTrough",
		"Interior/Level1CommonProps/CoalBunker",
		"Interior/Level1StationDecor/Forge01ToolRack",
		"Interior/Level1StationDecor/Forge02ToolRack"
	]:
		if not _expect(art_view.get_node_or_null(path) != null, "Required formal smithy prop is missing: %s" % path):
			return
	if not _expect(art_view.get_node_or_null("UpgradeVisuals/Level2/ExteriorAdditions/FuelShelterRoof") == null, "Obsolete out-of-lot fuel shelter roof still exists"):
		return
	var level_3: Dictionary = art_view.debug_force_visual_level(3)
	if not _expect(bool(level_3.get("level_2_visible", false)) and bool(level_3.get("level_3_visible", false)), "Level 3 did not preserve cumulative upgrades"):
		return
	if not _expect(int(level_3.get("active_workstation_visual_count", 0)) == 5, "Level 3 did not add exactly the third visible forge fixture"):
		return
	if not _expect(bool(((level_3.get("workstations", {}) as Dictionary).get("forge_03", {}) as Dictionary).get("available", false)), "Level 3 did not expose forge_03"):
		return
	if not _expect(art_view.get_node_or_null("UpgradeVisuals/Level3/InteriorAdditions/Forge03QuenchBucket") != null, "Third forge lacks its own visible working equipment"):
		return
	for path in [
		"UpgradeVisuals/Level3/RoofStructureAdditions/CeilingHoistBeam",
		"UpgradeVisuals/Level3/ExteriorAdditions/FinishingBay/SlateLeanToRoof",
		"UpgradeVisuals/Level3/ExteriorAdditions/FinishingBay/FinishedWeaponStand",
		"UpgradeVisuals/Level3/ExteriorAdditions/FinishingBay/QuenchBucket"
	]:
		if not _expect(art_view.get_node_or_null(path) != null, "Required level-three smithy addition is missing: %s" % path):
			return
	if not _expect(art_view.get_node_or_null("UpgradeVisuals/Level3/ExteriorAdditions/SideAwning") == null, "Obsolete clipping side awning still exists"):
		return
	var main_roof_bounds := _subtree_bounds(art_view.get_node_or_null("Roof"))
	var fuel_shelter_bounds := _subtree_bounds(art_view.get_node_or_null("UpgradeVisuals/Level2/ExteriorAdditions/FuelShelter/SlateLeanToRoof"))
	var finishing_bay_bounds := _subtree_bounds(art_view.get_node_or_null("UpgradeVisuals/Level3/ExteriorAdditions/FinishingBay/SlateLeanToRoof"))
	if not _expect(
		main_roof_bounds.has_volume()
		and fuel_shelter_bounds.has_volume()
		and finishing_bay_bounds.has_volume()
		and fuel_shelter_bounds.end.y <= main_roof_bounds.position.y - 0.1
		and finishing_bay_bounds.end.y <= main_roof_bounds.position.y - 0.1,
		"Smithy lean-to roof intersects the main roof: main=%s fuel=%s finishing=%s" % [main_roof_bounds, fuel_shelter_bounds, finishing_bay_bounds]
	):
		return
	for exterior_path in [
		"UpgradeVisuals/Level2/ExteriorAdditions",
		"UpgradeVisuals/Level3/ExteriorAdditions"
	]:
		var exterior_bounds := _subtree_bounds_in_space(art_view.get_node_or_null(exterior_path), art_view)
		if not _expect(
			exterior_bounds.has_volume()
			and exterior_bounds.position.x >= -8.05
			and exterior_bounds.position.z >= -8.05
			and exterior_bounds.end.x <= 8.05
			and exterior_bounds.end.z <= 8.05,
			"Smithy exterior additions escaped the approved 16 x 16 m lot (%s): %s" % [exterior_path, exterior_bounds]
		):
			return
	if not _expect(_mesh_opacity(art_view, "UpgradeVisuals/Level3/RoofStructureAdditions/CeilingHoistBeam") <= 0.1, "Level-three ceiling hoist beam did not fade with the roof"):
		return
	var addition_counts := level_3.get("level_visual_addition_counts", {}) as Dictionary
	if not _expect(int(addition_counts.get("level_1", 0)) >= 29 and int(addition_counts.get("level_2", 0)) >= 21 and int(addition_counts.get("level_3", 0)) >= 21, "Smithy upgrade levels do not expose enough distinct visual additions: %s" % JSON.stringify(addition_counts)):
		return
	if not _expect(int(level_3.get("roof_structure_addition_count", 0)) == 1 and bool(level_3.get("roof_structure_additions_fade_with_roof", false)), "Smithy upgrade roof structure is not registered with the roof fade contract"):
		return
	art_view.apply_roof_camera_distance(70.0, 1.0)
	if not _expect(_mesh_opacity(art_view, "UpgradeVisuals/Level3/RoofStructureAdditions/CeilingHoistBeam") >= 0.98, "Level-three ceiling hoist beam did not return with the distant roof"):
		return
	if not _verify_ui_theme():
		return
	if not await _verify_glen_feedback():
		return
	if not await _verify_formal_enemy_feedback():
		return
	print("T0129 formal blacksmith art vertical slice verification passed: %s" % JSON.stringify(level_3))
	main.queue_free()
	await process_frame
	quit(0)


func _verify_level_one(art_view: Node, snapshot: Dictionary) -> bool:
	if not _expect(int(snapshot.get("building_level", 0)) == 1, "Initial formal blacksmith art level is not 1"):
		return false
	if not _expect(not bool(snapshot.get("level_2_visible", true)) and not bool(snapshot.get("level_3_visible", true)), "Level 1 exposes future upgrade visuals"):
		return false
	if not _expect(bool(snapshot.get("navigation_ready", false)), "Formal station navigation authority is not ready"):
		return false
	if not _expect(str(snapshot.get("authority_role", "")) == "presentation_only", "Art view escaped the presentation boundary"):
		return false
	if not _expect(str(snapshot.get("navigation_authority", "")) == "formal_station_navigation_mesh", "Smithy still owns a private 4x4 navigation surface"):
		return false
	var footprint: Vector2 = snapshot.get("building_footprint", Vector2.ZERO)
	var clear_size: Vector2 = snapshot.get("interior_clear_size", Vector2.ZERO)
	if not _expect(footprint == Vector2(14.0, 12.0) and clear_size.x >= 13.0 and clear_size.y >= 11.0, "Formal smithy did not reserve the approved future-capacity envelope"):
		return false
	if not _expect(bool(snapshot.get("future_capacity_reserved", false)), "Formal smithy does not declare future upgrade capacity"):
		return false
	if not _expect(str(snapshot.get("roof_profile", "")) == "formal_low_pitch_cold_slate_modular", "Smithy roof is not the approved modular low-pitch cold slate profile"):
		return false
	if not _expect(int(snapshot.get("roof_module_count", 0)) >= 4, "Smithy roof does not cover the formal envelope"):
		return false
	var roof_color := snapshot.get("roof_albedo_override", Color.WHITE) as Color
	if not _expect(roof_color.b > roof_color.r, "Smithy roof palette is not cool-toned"):
		return false
	if not _expect(int(snapshot.get("exterior_material_count", 0)) > 0, "Smithy exterior palette was not applied"):
		return false
	if not _expect(bool(snapshot.get("chimney_clearance_ready", false)) and bool(snapshot.get("chimney_forge_aligned", false)), "Smithy chimney is not raised and aligned over the shared hearth"):
		return false
	if not _expect(bool(snapshot.get("smoke_outlet_above_roof", false)), "Smithy smoke still emits below the chimney outlet"):
		return false
	if not _expect(str(snapshot.get("collision_authority", "")) == "formal_station_static_and_fixture_collision", "Smithy collision is not mapped to the formal station"):
		return false
	var roof_snapshot: Dictionary = art_view.get_roof_visibility_snapshot()
	if not _expect(bool(roof_snapshot.get("static_collision_enabled", false)), "Formal smithy walls have no enabled collision"):
		return false
	var ambient := snapshot.get("ambient_fx", {}) as Dictionary
	for key in ["fire_light_ready", "flame_core_ready", "bellows_animated", "building_signal_connected", "npc_signal_connected"]:
		if not _expect(bool(ambient.get(key, false)), "Formal smithy ambient contract is missing %s" % key):
			return false
	if not _expect(
		not bool(ambient.get("forge_active", true))
		and not bool(ambient.get("sparks_emitting", true))
		and not bool(ambient.get("smoke_emitting", true)),
		"Empty smithy must keep fire, sparks and chimney smoke off"
	):
		return false
	var workstations := snapshot.get("workstations", {}) as Dictionary
	if not _expect(bool((workstations.get("forge_01", {}) as Dictionary).get("available", false)), "Level 1 forge_01 unavailable"):
		return false
	if not _expect(bool((workstations.get("forge_02", {}) as Dictionary).get("available", false)), "Level 1 forge_02 unavailable"):
		return false
	if not _expect(not bool((workstations.get("forge_03", {}) as Dictionary).get("available", true)), "Level 1 exposed forge_03 early"):
		return false
	return _expect(int(snapshot.get("active_workstation_visual_count", 0)) == 3, "Level 1 must expose two anvils and one shared hearth")


func _verify_ui_theme() -> bool:
	var theme := load("res://resources/themes/blacksmith_vertical_slice_theme.tres") as Theme
	if not _expect(theme != null and theme.has_stylebox("panel", "PanelContainer"), "Blacksmith UI slice theme is invalid"):
		return false
	for panel_path in ["Main/UI/HUD", "Main/UI/NPCPanel", "Main/UI/BuildingPanel"]:
		var panel := root.get_node_or_null(panel_path) as Control
		if not _expect(panel != null and panel.theme == theme, "Slice theme not applied to %s" % panel_path):
			return false
	return true


func _verify_transparent_interior_click_contract(art_view: Node3D) -> bool:
	var ray_hit: Dictionary = art_view.get_building_interaction_ray_hit(
		art_view.global_position + Vector3(0.0, 20.0, 0.0),
		art_view.global_position + Vector3(0.0, -5.0, 0.0)
	)
	if not _expect(str(ray_hit.get("building_id", "")) == "blacksmith" and bool(ray_hit.get("interior_revealed", false)), "Transparent smithy interaction bounds are not selectable"):
		return false
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if not _expect(npc_system != null and building_system != null and camera != null, "Transparent click verification dependencies are missing"):
		return false
	if not _expect(npc_system.debug_enter_location_immediately(GLEN_ID, "blacksmith", false), "Could not place Glen in the smithy for click verification"):
		return false
	var glen_path: Variant = npc_system.get("_npc_nodes").get(GLEN_ID)
	var glen := npc_system.get_node_or_null(glen_path) as Node3D
	if not _expect(glen != null, "Glen node is missing for click verification"):
		return false
	glen.global_position = art_view.to_global(Vector3(0.0, 0.0, 0.0))
	await physics_frame
	var screen_position := camera.unproject_position(glen.global_position + Vector3(0.0, 1.0, 0.0))
	var interaction: Dictionary = npc_system.get_world_click_interaction(screen_position)
	if not _expect(str(interaction.get("npc_id", "")) == GLEN_ID, "Transparent shell does not expose the interior NPC ray target: %s" % JSON.stringify(interaction)):
		return false
	if not _expect(bool(building_system.call("_try_select_interior_npc", screen_position, "blacksmith")), "Transparent building click did not route to the interior NPC"):
		return false
	art_view.apply_roof_camera_distance(70.0, 1.0)
	if not _expect(bool(npc_system.call("_is_npc_hidden_by_opaque_building", GLEN_ID)), "Opaque smithy does not restore building-first click priority"):
		return false
	art_view.apply_roof_camera_distance(58.0, 0.0)
	return _expect(not bool(npc_system.call("_is_npc_hidden_by_opaque_building", GLEN_ID)), "Transparent smithy still blocks the interior NPC")


func _verify_glen_feedback() -> bool:
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	if not _expect(npc_system != null, "NPCSystem missing"):
		return false
	var glen_path: Variant = npc_system.get("_npc_nodes").get(GLEN_ID)
	var glen := npc_system.get_node_or_null(glen_path)
	if not _expect(glen != null, "Glen world node missing"):
		return false
	var before: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(bool(before.get("blood_vfx_ready", false)), "Glen blood feedback is not ready"):
		return false
	npc_system.debug_damage_npc(GLEN_ID, 7)
	await process_frame
	var hit: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(int(hit.get("damage_feedback_count", 0)) == int(before.get("damage_feedback_count", 0)) + 1, "Damage did not trigger Glen physical feedback"):
		return false
	if not _expect(bool(hit.get("blood_vfx_emitting", false)), "Damage did not emit Glen blood particles"):
		return false
	npc_system.debug_damage_npc(GLEN_ID, 9999)
	await process_frame
	var fallen: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(str(fallen.get("desired_state", "")) == "unconscious", "Unconscious authority did not trigger Glen's fall"):
		return false
	return _expect(str(fallen.get("fall_feedback_mode", "")) == "animated_fall_with_physics_impulse", "Glen fall feedback mode is missing")


func _verify_formal_enemy_feedback() -> bool:
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	if not _expect(combat_system != null, "CombatSystem missing"):
		return false
	var spawn: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not _expect(bool(spawn.get("ok", false)), "Enemy slice spawn failed"):
		return false
	await process_frame
	await physics_frame
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	var enemy_nodes: Dictionary = combat_system.get("_enemy_nodes")
	if not _expect(not enemy_ids.is_empty(), "No formal enemy spawned"):
		return false
	for enemy_id in enemy_ids:
		var enemy_node := combat_system.get_node_or_null(enemy_nodes.get(enemy_id, NodePath("")))
		if not _expect(enemy_node is CharacterBody3D, "Active enemy is not a physical CharacterBody3D: %s" % enemy_id):
			return false
		if not _expect(enemy_node.get_node_or_null("BodyCollision") is CollisionShape3D, "Active enemy has no body collision: %s" % enemy_id):
			return false
		if not _expect(enemy_node.get_node_or_null("EnemyArtView") != null, "Active enemy has no Quaternius art: %s" % enemy_id):
			return false
	var first_id := enemy_ids[0]
	combat_system.set("_active_enemies", _set_enemy_sample_action(combat_system.get("_active_enemies"), first_id))
	combat_system.call("_refresh_enemy_node", first_id)
	var first_enemy := combat_system.get_node_or_null(enemy_nodes.get(first_id, NodePath("")))
	var enemy_art := first_enemy.get_node_or_null("EnemyArtView") if first_enemy != null else null
	if not _expect(enemy_art != null and str(enemy_art.debug_get_snapshot().get("desired_state", "")) == "attack", "Enemy authority action did not reach the attack animation"):
		return false
	combat_system.debug_clear_enemies()
	await process_frame
	return true


func _set_enemy_sample_action(active_enemies: Dictionary, enemy_id: String) -> Dictionary:
	var updated := active_enemies.duplicate(true)
	var enemy: Dictionary = updated.get(enemy_id, {})
	enemy["current_action"] = "attacking_blacksmith_01"
	updated[enemy_id] = enemy
	return updated


func _mesh_opacity(art_view: Node, path: String) -> float:
	var mesh_instance := art_view.get_node_or_null(path) as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return -1.0
	var material := mesh_instance.get_active_material(0) as BaseMaterial3D
	return material.albedo_color.a if material != null else -1.0


func _subtree_bounds(root_node: Node) -> AABB:
	if root_node == null:
		return AABB()
	var meshes: Array[MeshInstance3D] = []
	if root_node is MeshInstance3D:
		meshes.append(root_node as MeshInstance3D)
	for raw_mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(raw_mesh as MeshInstance3D)
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance in meshes:
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var world_bounds := mesh_instance.global_transform * mesh_instance.get_aabb()
		bounds = bounds.merge(world_bounds) if has_bounds else world_bounds
		has_bounds = true
	return bounds


func _subtree_bounds_in_space(root_node: Node, space: Node3D) -> AABB:
	if root_node == null or space == null:
		return AABB()
	var meshes: Array[MeshInstance3D] = []
	if root_node is MeshInstance3D:
		meshes.append(root_node as MeshInstance3D)
	for raw_mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(raw_mesh as MeshInstance3D)
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance in meshes:
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform := space.global_transform.affine_inverse() * mesh_instance.global_transform
		var local_bounds := relative_transform * mesh_instance.get_aabb()
		bounds = bounds.merge(local_bounds) if has_bounds else local_bounds
		has_bounds = true
	return bounds


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
