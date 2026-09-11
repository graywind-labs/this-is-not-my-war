extends SceneTree


const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const GABLED_BUILDINGS := [
	{
		"path": "Main/WorldRoot/FormalStationLayout/BuildingRoots/DiningHall/DiningHallArt",
		"gable_path": "Exterior/SealedOchreGableEnds",
		"profile": "sealed_ochre_plaster_with_oak_frame"
	},
	{
		"path": "Main/WorldRoot/FormalStationLayout/BuildingRoots/Tavern/TavernArt",
		"gable_path": "Exterior/SealedCellarGableEnds",
		"profile": "sealed_cellar_plaster_with_wine_dark_timber"
	},
	{
		"path": "Main/WorldRoot/FormalStationLayout/BuildingRoots/Dormitory/DormitoryArt",
		"gable_path": "Exterior/SealedDormitoryGableEnds",
		"profile": "sealed_warm_plaster_with_bunkhouse_timber"
	},
	{
		"path": "Main/WorldRoot/FormalStationLayout/BuildingRoots/Workshop/WorkshopArt",
		"gable_path": "Exterior/SealedWorkshopGableEnds",
		"profile": "sealed_cool_plaster_with_engineering_timber"
	}
]
const BLACKSMITH_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Blacksmith/BlacksmithArt"


func _init() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	var daily_plan_system := main.get_node_or_null("Systems/DailyPlanSystem")
	if daily_plan_system != null:
		daily_plan_system.set_auto_execution_enabled(false)
	root.add_child(main)
	for _frame in range(5):
		await process_frame
		await physics_frame

	for contract in GABLED_BUILDINGS:
		if not _verify_gabled_building(contract):
			return
	if not _verify_roof_wall_alignment():
		return
	if not _verify_flat_blacksmith_roof():
		return

	print("T0135-P8AR7 building roof closure verification passed: four sealed styled gables and one flat smithy roof")
	main.queue_free()
	await process_frame
	quit(0)


func _verify_gabled_building(contract: Dictionary) -> bool:
	var art := root.get_node_or_null(str(contract.get("path", ""))) as Node3D
	if art == null:
		return _expect(false, "Missing formal building art: %s" % contract.get("path", ""))
	var gables := art.get_node_or_null(str(contract.get("gable_path", ""))) as Node3D
	if gables == null:
		return _expect(false, "Missing sealed gable group: %s" % contract.get("gable_path", ""))
	var sealed_walls: Array[MeshInstance3D] = []
	var timber_parts := 0
	for raw_mesh in gables.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if bool(mesh_instance.get_meta("sealed_gable_wall", false)):
			sealed_walls.append(mesh_instance)
		else:
			timber_parts += 1
	if not _expect(sealed_walls.size() == 2, "%s does not have two sealed gable wall prisms" % art.name):
		return false
	if not _expect(timber_parts >= 8, "%s gables do not have building-specific timber framing" % art.name):
		return false
	for wall in sealed_walls:
		if not _expect(wall.mesh is PrismMesh, "%s gable wall is not a closed triangular prism" % wall.name):
			return false
		var prism := wall.mesh as PrismMesh
		if not _expect(prism.size.x > 9.0 and prism.size.y >= 0.9 and prism.size.z >= 0.28, "%s gable prism does not span the roof-wall opening" % wall.name):
			return false
		if not _expect(wall.material_override == null and prism.material != null, "%s gable wall has no authored building material" % wall.name):
			return false
	if not _expect(gables.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s gable presentation added collision authority" % art.name):
		return false
	var snapshot: Dictionary = art.call("get_art_slice_snapshot")
	if not _expect(int(snapshot.get("sealed_gable_end_count", 0)) == 2, "%s snapshot lost its sealed gable count" % art.name):
		return false
	if not _expect(str(snapshot.get("gable_end_profile", "")) == str(contract.get("profile", "")), "%s gable style profile is incorrect" % art.name):
		return false
	art.call("apply_roof_camera_distance", 70.0, 1.0)
	var far_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	if not _expect(float(far_snapshot.get("exterior_opacity", 0.0)) >= 0.99, "%s gable shell is not opaque at far view" % art.name):
		return false
	art.call("apply_roof_camera_distance", 58.0, 0.0)
	var near_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	return _expect(float(near_snapshot.get("exterior_opacity", 1.0)) <= 0.07, "%s gable shell did not remain in the exterior fade chain" % art.name)


func _verify_roof_wall_alignment() -> bool:
	var workshop := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Workshop/WorkshopArt") as Node3D
	var dormitory := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Dormitory/DormitoryArt") as Node3D
	if not _expect(workshop != null and dormitory != null, "Roof-wall alignment buildings are unavailable"):
		return false

	var workshop_roof_root := workshop.get_node_or_null("Roof/RoundTileRoof") as Node3D
	var workshop_exterior := workshop.get_node_or_null("Exterior") as Node3D
	var workshop_gables := workshop.get_node_or_null("Exterior/SealedWorkshopGableEnds") as Node3D
	if not _expect(workshop_roof_root != null and workshop_exterior != null and workshop_gables != null, "Workshop roof-wall alignment nodes are incomplete"):
		return false
	if not _expect(is_equal_approx(abs(workshop_roof_root.rotation_degrees.y), 90.0), "Workshop imported ridge is not aligned with its authored gable ends"):
		return false
	var workshop_wall_roots: Array[Node3D] = []
	var wall_prefixes := ["FrontWall", "RearWall", "SideWall", "FrontPost", "RearPost", "SidePost", "DoorJamb", "FrontLintel", "RearLintel"]
	for raw_child in workshop_exterior.get_children():
		if not raw_child is Node3D:
			continue
		var child := raw_child as Node3D
		for prefix in wall_prefixes:
			if str(child.name).begins_with(prefix):
				workshop_wall_roots.append(child)
				break
	var workshop_wall_bounds := _combined_bounds_in_art(workshop, workshop_wall_roots)
	var workshop_roof_bounds := _subtree_bounds_in_art(workshop, workshop_roof_root)
	var workshop_gable_bounds := _subtree_bounds_in_art(workshop, workshop_gables)
	if not _expect(_four_edges_cover(workshop_roof_bounds, workshop_wall_bounds, 0.08), "Workshop roof does not overhang all four wall edges: roof=%s walls=%s" % [workshop_roof_bounds, workshop_wall_bounds]):
		return false
	var workshop_eave_gap := workshop_roof_bounds.position.y - workshop_wall_bounds.end.y
	if not _expect(workshop_eave_gap >= -0.02 and workshop_eave_gap <= 0.14, "Workshop eave is not seated on the wall top: gap=%.3f roof=%s walls=%s" % [workshop_eave_gap, workshop_roof_bounds, workshop_wall_bounds]):
		return false
	if not _expect(workshop_gable_bounds.position.y <= workshop_wall_bounds.end.y + 0.02, "Workshop gables float above the rectangular wall top"):
		return false
	if not _verify_workshop_gables_below_roof_profile(workshop, workshop_roof_root, workshop_gables):
		return false
	if not _verify_workshop_door_sign_below_eave(workshop, workshop_roof_root):
		return false

	var dormitory_roof := dormitory.get_node_or_null("Roof/LongWineShingleRoof") as Node3D
	var dormitory_wall_shell := dormitory.get_node_or_null("Exterior/WarmPlasterWallShell") as Node3D
	var dormitory_frame := dormitory.get_node_or_null("Exterior/FiveBayTimberFrame") as Node3D
	var dormitory_gables := dormitory.get_node_or_null("Exterior/SealedDormitoryGableEnds") as Node3D
	if not _expect(dormitory_roof != null and dormitory_wall_shell != null and dormitory_frame != null and dormitory_gables != null, "Dormitory roof-wall alignment nodes are incomplete"):
		return false
	var dormitory_wall_bounds := _combined_bounds_in_art(dormitory, [dormitory_wall_shell, dormitory_frame])
	var dormitory_roof_bounds := _subtree_bounds_in_art(dormitory, dormitory_roof)
	var dormitory_gable_bounds := _subtree_bounds_in_art(dormitory, dormitory_gables)
	if not _expect(_four_edges_cover(dormitory_roof_bounds, dormitory_wall_bounds, 0.08), "Dormitory roof does not overhang all four wall edges: roof=%s walls=%s" % [dormitory_roof_bounds, dormitory_wall_bounds]):
		return false
	var dormitory_eave_gap := dormitory_roof_bounds.position.y - dormitory_wall_bounds.end.y
	if not _expect(dormitory_eave_gap >= -0.02 and dormitory_eave_gap <= 0.10, "Dormitory eave is not seated on the wall top: gap=%.3f roof=%s walls=%s" % [dormitory_eave_gap, dormitory_roof_bounds, dormitory_wall_bounds]):
		return false
	if not _expect(dormitory_gable_bounds.position.y <= dormitory_wall_bounds.end.y + 0.02 and dormitory_gable_bounds.end.y >= dormitory_roof_bounds.end.y - 0.16, "Dormitory gables do not connect wall top to roof ridge"):
		return false
	return true


func _verify_workshop_gables_below_roof_profile(art: Node3D, roof_root: Node3D, gables: Node3D) -> bool:
	for side_name in ["West", "East"]:
		var wall := gables.get_node_or_null("%sCoolPlasterGableWall" % side_name) as MeshInstance3D
		if not _expect(wall != null and wall.mesh is PrismMesh, "Workshop %s gable prism is unavailable for profile validation" % side_name):
			return false
		var prism := wall.mesh as PrismMesh
		var half_width := prism.size.x * 0.5
		var base_y := wall.position.y - prism.size.y * 0.5
		for sample_z in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]:
			var roof_inner_y := _minimum_roof_vertex_y_near_cross_section(art, roof_root, wall.position.x, sample_z)
			if not _expect(not is_inf(roof_inner_y), "Workshop roof has no profile samples near %s gable at |z|=%.1f" % [side_name, sample_z]):
				return false
			var wall_top_y: float = base_y + prism.size.y * (1.0 - clampf(sample_z / half_width, 0.0, 1.0))
			if not _expect(wall_top_y <= roof_inner_y - 0.04, "Workshop %s gable pierces the roof profile at |z|=%.1f: wall=%.3f roof_inner=%.3f" % [side_name, sample_z, wall_top_y, roof_inner_y]):
				return false
		for beam_suffix in ["FrontRakingBeam", "RearRakingBeam"]:
			var beam := gables.get_node_or_null("%s%s" % [side_name, beam_suffix]) as MeshInstance3D
			if not _expect(beam != null and beam.mesh is BoxMesh, "Workshop %s %s is unavailable" % [side_name, beam_suffix]):
				return false
			var beam_mesh := beam.mesh as BoxMesh
			if not _expect(abs(abs(beam.rotation_degrees.x) - 16.0) <= 0.01 and beam_mesh.size.y <= 0.161 and beam.position.y <= 4.171, "Workshop %s %s is not inset below the tile profile" % [side_name, beam_suffix]):
				return false
	return true


func _verify_workshop_door_sign_below_eave(art: Node3D, roof_root: Node3D) -> bool:
	var sign := art.get_node_or_null("Exterior/WorkshopSign") as MeshInstance3D
	var compass_bar := art.get_node_or_null("Exterior/CompassBar") as MeshInstance3D
	var compass_stem := art.get_node_or_null("Exterior/CompassStem") as MeshInstance3D
	if not _expect(sign != null and compass_bar != null and compass_stem != null, "Workshop door sign assembly is incomplete"):
		return false
	var roof_inner_y := _minimum_roof_vertex_y_near_point(art, roof_root, Vector2(0.0, 6.23), Vector2(1.5, 0.4))
	if not _expect(not is_inf(roof_inner_y), "Workshop roof has no underside samples above the door sign"):
		return false
	for part in [sign, compass_bar, compass_stem]:
		var part_bounds := _subtree_bounds_in_art(art, part)
		if not _expect(part_bounds.end.y <= roof_inner_y - 0.04, "Workshop door sign part pierces the front eave: %s top=%.3f roof_inner=%.3f" % [part.name, part_bounds.end.y, roof_inner_y]):
			return false
	if not _expect(_subtree_bounds_in_art(art, sign).position.y >= 2.9, "Workshop door sign was lowered into the doorway"):
		return false
	return true


func _minimum_roof_vertex_y_near_cross_section(art: Node3D, roof_root: Node3D, gable_x: float, sample_abs_z: float) -> float:
	var minimum_y := INF
	for raw_mesh in roof_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance.mesh == null or bool(mesh_instance.get_meta("persistent_shell_shadow_proxy", false)) or bool(mesh_instance.get_meta("portrait_opaque_shell_proxy", false)):
			continue
		var relative_transform := art.global_transform.affine_inverse() * mesh_instance.global_transform
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point := relative_transform * vertex
				if abs(point.x - gable_x) <= 1.8 and abs(abs(point.z) - sample_abs_z) <= 0.18:
					minimum_y = min(minimum_y, point.y)
	return minimum_y


func _minimum_roof_vertex_y_near_point(art: Node3D, roof_root: Node3D, center_xz: Vector2, tolerance_xz: Vector2) -> float:
	var minimum_y := INF
	for raw_mesh in roof_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance.mesh == null or bool(mesh_instance.get_meta("persistent_shell_shadow_proxy", false)) or bool(mesh_instance.get_meta("portrait_opaque_shell_proxy", false)):
			continue
		var relative_transform := art.global_transform.affine_inverse() * mesh_instance.global_transform
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point := relative_transform * vertex
				if abs(point.x - center_xz.x) <= tolerance_xz.x and abs(point.z - center_xz.y) <= tolerance_xz.y:
					minimum_y = min(minimum_y, point.y)
	return minimum_y


func _four_edges_cover(roof_bounds: AABB, wall_bounds: AABB, minimum_overhang: float) -> bool:
	return (
		roof_bounds.position.x <= wall_bounds.position.x - minimum_overhang
		and roof_bounds.end.x >= wall_bounds.end.x + minimum_overhang
		and roof_bounds.position.z <= wall_bounds.position.z - minimum_overhang
		and roof_bounds.end.z >= wall_bounds.end.z + minimum_overhang
	)


func _combined_bounds_in_art(art: Node3D, roots: Array) -> AABB:
	var combined := AABB()
	var has_bounds := false
	for raw_root in roots:
		if not raw_root is Node3D:
			continue
		var bounds := _subtree_bounds_in_art(art, raw_root as Node3D)
		combined = combined.merge(bounds) if has_bounds else bounds
		has_bounds = true
	return combined


func _subtree_bounds_in_art(art: Node3D, subtree: Node3D) -> AABB:
	var combined := AABB()
	var has_bounds := false
	var mesh_nodes: Array[MeshInstance3D] = []
	if subtree is MeshInstance3D:
		mesh_nodes.append(subtree as MeshInstance3D)
	for raw_mesh in subtree.find_children("*", "MeshInstance3D", true, false):
		mesh_nodes.append(raw_mesh as MeshInstance3D)
	for mesh_instance in mesh_nodes:
		if mesh_instance.mesh == null or bool(mesh_instance.get_meta("persistent_shell_shadow_proxy", false)) or bool(mesh_instance.get_meta("portrait_opaque_shell_proxy", false)):
			continue
		var relative_transform := art.global_transform.affine_inverse() * mesh_instance.global_transform
		var bounds := relative_transform * mesh_instance.get_aabb()
		combined = combined.merge(bounds) if has_bounds else bounds
		has_bounds = true
	return combined


func _verify_flat_blacksmith_roof() -> bool:
	var art := root.get_node_or_null(BLACKSMITH_PATH) as Node3D
	if art == null:
		return _expect(false, "Missing formal blacksmith art")
	for obsolete_path in ["Roof/NorthSlateSlope", "Roof/SouthSlateSlope", "Roof/ColdRidgeCap"]:
		if not _expect(art.get_node_or_null(obsolete_path) == null, "Blacksmith still has pitched-roof element: %s" % obsolete_path):
			return false
	var deck := art.get_node_or_null("Roof/FlatSlateDeck") as MeshInstance3D
	if not _expect(deck != null and deck.mesh is BoxMesh, "Blacksmith flat slate deck is missing"):
		return false
	var deck_mesh := deck.mesh as BoxMesh
	if not _expect(deck.rotation_degrees.is_zero_approx() and deck_mesh.size.x >= 14.7 and deck_mesh.size.z >= 12.7 and deck_mesh.size.y <= 0.25, "Blacksmith roof deck is not flat or does not cover its envelope"):
		return false
	for parapet_path in ["Roof/NorthParapetCap", "Roof/SouthParapetCap", "Roof/WestParapetCap", "Roof/EastParapetCap"]:
		if not _expect(art.get_node_or_null(parapet_path) != null, "Blacksmith flat roof lacks edge cap: %s" % parapet_path):
			return false
	var snapshot: Dictionary = art.call("get_art_slice_snapshot")
	if not _expect(str(snapshot.get("roof_profile", "")) == "formal_flat_cold_slate_with_low_parapet", "Blacksmith snapshot still describes a pitched roof"):
		return false
	art.call("apply_roof_camera_distance", 58.0, 0.0)
	var near_snapshot: Dictionary = art.call("get_roof_visibility_snapshot")
	return _expect(
		float(near_snapshot.get("roof_opacity", 1.0)) <= 0.07
		and bool(near_snapshot.get("roof_shadow_enabled", false)),
		"Blacksmith flat roof lost the transparent shell or persistent shadow contract"
	)


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
