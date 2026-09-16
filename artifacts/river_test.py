from pathlib import Path
s=Path('tools/verify_t0365_formal_mountain.gd').read_text(encoding='utf-8')
s=s.replace('Approved cliff appearance', 'Approved river appearance').replace('t0365_integration','t0366_integration').replace('ApprovedStylizedMountain','ApprovedStylizedRiver').replace('T0365','T0366').replace('--measure-mountain','--measure-river')
a=s.index('\tassert(snapshot.enabled');b=s.index('\tDirAccess.make_dir_recursive_absolute',a)
s=s[:a]+'''	assert(snapshot.enabled and snapshot.original_water_vertices == 120)
	assert(snapshot.bank_and_rock_meshes_unchanged == 52)
	assert(snapshot.trees == 7393 and snapshot.waterline_rocks == 21 and snapshot.foam_footprints == 21)
	var nav := formal.get_node("SpatialContract/StationNavigation") as NavigationRegion3D
	var min_navigation_x := INF
	for v in nav.navigation_mesh.get_vertices():
		min_navigation_x = minf(min_navigation_x, formal.to_local(nav.to_global(v)).x)
	var max_rock_x := -INF
	for rock: MeshInstance3D in art._shore_rocks.get_children():
		for v in rock.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			max_rock_x = maxf(max_rock_x, formal.to_local(rock.to_global(v)).x)
	assert(max_rock_x < min_navigation_x, "The shoreline decorations overlap navigable ground")
	var environment: Node3D = art.get_parent()
	assert(art._water_material.get_shader_parameter("environment_origin").is_equal_approx(environment.global_position))
	assert(art._bank_material.get_shader_parameter("environment_origin").is_equal_approx(environment.global_position))
	var initial_flow: float = art._flow_time
	for frame in 5:
		await process_frame
	assert(art._flow_time > initial_flow, "Production water animation must advance")
	snapshot["min_navigation_x"] = min_navigation_x
	snapshot["max_waterline_rock_x"] = max_rock_x
	snapshot["flow_advances"] = true
'''+s[b:]
a=s.index('\t\t["east_wall"');b=s.index('\t\t["full_map"',a)
s=s[:a]+'''		["west_wall", Vector3(-60, 0, 30), Vector3(28, 30, 40)],
		["river_close", Vector3(-96, -1, 93), Vector3(14, 16, 22)],
		["river_overview", Vector3(-97, -0.5, 85), Vector3(40, 64, 70)],
		["river_side", Vector3(-94, -0.6, 143), Vector3(22, 10, -29)],
'''+s[b:]
s=s.replace('"cliff_overview"', '"river_overview"')
Path('tools/verify_t0366_formal_river.gd').write_text(s,encoding='utf-8')
