from pathlib import Path
s=Path('tools/verify_t0366_formal_river.gd').read_text(encoding='utf-8')
s=s.replace('Approved river appearance','Building/ground contact appearance').replace('t0366_r1_integration','t0368').replace('T0366','T0368').replace('ApprovedStylizedRiver','BuildingGroundContact')
a=s.index('\tvar snapshot: Dictionary');b=s.index('\tDirAccess.make_dir_recursive_absolute',a)
s=s[:a]+'''\tvar snapshot: Dictionary = art.verify_contract()
	assert(snapshot.enabled and snapshot.new_meshes == 0)
	var ground: MeshInstance3D = formal.get_node("FormalEnvironmentArtView/GroundSurface/StationDeepGrassVariation")
	assert(ground.material_override == art._material)
	var plateau: Node = formal.get_node("FormalEnvironmentArtView/FullMapTerrainTopology/DisconnectedPlateaus")
	for mesh in plateau.get_children():
		assert(mesh.material_override == art._material, "Wall exterior and station interior must share the mask")
'''+s[b:]
a=s.index('\t\t["west_wall"');b=s.index('\t]:',a)
s=s[:a]+'''		["main_hall", Vector3(0, 0.2, -1), Vector3(18, 21, 28)],
		["blacksmith", Vector3(15, 0.1, 36), Vector3(-18, 17, -20)],
		["wall_inside", Vector3(-55, 0, 8), Vector3(15, 10, 18)],
		["wall_outside", Vector3(-55, 0, 8), Vector3(-16, 10, 18)],
		["front_gate", Vector3(5, 0, 54), Vector3(12, 17, 23)],
		["garden", Vector3(-42, 0, 10), Vector3(18, 18, 22)],
'''+s[b:]
a=s.index('\t\t\tfor frame in 12:');b=s.index('\t\tif "--measure-river"',a)
s=s[:a]+'''			for enabled in [false, true]:
				art.set_enabled(enabled)
				for frame in 8:
					await process_frame
				await RenderingServer.frame_post_draw
				var result := root.get_texture().get_image().save_png("%s/%s_%s_%s.png" % [OUTPUT, entry[0], "night" if night else "day", "B" if enabled else "A"])
				assert(result == OK)
'''+s[b:]
s=s.replace('--measure-river','--measure-contact').replace('["station", "river_overview", "full_map"]','["station"]')
Path('tools/verify_t0368_building_ground_contact.gd').write_text(s,encoding='utf-8')
