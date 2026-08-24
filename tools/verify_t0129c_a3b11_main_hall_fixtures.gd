extends SceneTree

const MAIN_PATH := "res://scenes/main/Main.tscn"
const FIXTURE_PATH := "res://data/building_fixture_layouts.json"

func _init() -> void:
	var config := _load_json(FIXTURE_PATH)
	var packed := load(MAIN_PATH) as PackedScene
	if config.is_empty() or packed == null: _fail("A3b11R inputs unavailable"); return
	var main := packed.instantiate(); root.add_child(main)
	for _i in 4: await process_frame; await physics_frame
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var defense_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var hall := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/MainHall") as Node3D
	var fixture_root := hall.get_node_or_null("FixtureLayout") if hall != null else null
	if controller == null or defense_system == null or building_system == null or fixture_root == null: _fail("A3b11R hierarchy incomplete"); return
	var snapshot: Dictionary = controller.debug_get_layout_snapshot()
	if int(snapshot.get("configuration_error_count", -1)) != 0: _fail("A3b11R config errors: %s" % snapshot); return
	var hall_art := hall.get_node_or_null("MainHallArt") as Node3D
	var envelope := hall.get_node_or_null("Envelope") as MeshInstance3D
	if hall_art == null or str(hall_art.get_meta("art_revision", "")) not in ["a3b11r", "t0132_p1", "t0132_p1r", "t0132_p1r2", "t0132_p1r3", "t0132_p1r4", "t0132_p1r5"] or envelope == null or envelope.visible: _fail("Main hall exterior did not replace the blockout envelope"); return
	if building_system.is_building_enterable("main_hall") or not (building_system.get_building("main_hall").get("workstations", []) as Array).is_empty(): _fail("Main hall must remain non-enterable with zero NPC workstations"); return
	if str(hall_art.get_meta("art_revision", "")) in ["t0132_p1", "t0132_p1r", "t0132_p1r2", "t0132_p1r3", "t0132_p1r4", "t0132_p1r5"]:
		var front_door_path := "BaseVisuals/Exterior/TexturedFacadeModules/FrontDoor" if str(hall_art.get_meta("art_revision", "")) in ["t0132_p1r3", "t0132_p1r4", "t0132_p1r5"] else "BaseVisuals/Exterior/FrontGatehouse/FrontDoor"
		for node_path in ["BaseVisuals/Exterior/FortifiedPlinth", front_door_path, "BaseVisuals/Exterior/FrontStairs", "Roof", "UpgradeVisuals/Level6"]:
			if hall_art.get_node_or_null(node_path) == null: _fail("T0132-P1 exterior detail missing: %s" % node_path); return
	else:
		for node_name in ["FortifiedPlinth", "CommandMass", "UpperKeep", "FrontDoor", "FrontStairs", "CommandRoof", "LeftBanner", "RightBanner", "CommandShield"]:
			if hall_art.get_node_or_null(node_name) == null: _fail("A3b11R exterior detail missing: %s" % node_name); return
		if _count_prefix(hall_art, "FrontWindow") != 6 or _count_prefix(hall_art, "RearWindow") != 7 or _count_contains(hall_art, "SideWindow") != 8: _fail("A3b11R modular facade count drifted"); return
	var visuals := fixture_root.get_node_or_null("Visuals")
	var collisions := fixture_root.get_node_or_null("StaticCollision")
	var stands := fixture_root.get_node_or_null("NPCStands")
	if visuals == null or collisions == null or stands == null or visuals.get_child_count() != 7 or collisions.get_child_count() != 7 or stands.get_child_count() != 0: _fail("A3b11R main hall must have 7 fixtures and zero NPC stands"); return
	var cfg := ((config.get("buildings", {}) as Dictionary).get("main_hall", {}) as Dictionary)
	var platform_levels: Dictionary = {}
	var reinforcement_levels: Array[int] = []
	for raw in cfg.get("fixtures", []):
		var fixture := raw as Dictionary
		var fixture_id := str(fixture.get("id", ""))
		var visual := _find_by_meta(visuals,"fixture_id",fixture_id) as Node3D
		var body := _find_by_meta(collisions,"fixture_id",fixture_id) as StaticBody3D
		if visual == null or body == null: _fail("A3b11R main hall fixture missing: %s" % fixture_id); return
		var position_id := str(fixture.get("spatial_position_id", ""))
		if position_id.is_empty():
			reinforcement_levels.append(int(fixture.get("required_level",0)))
			match str(fixture.get("kind", "")):
				"main_hall_wall_brace":
					if fixture.has("primitive_visual") or visual.get_node_or_null("QuaterniusButtress01") == null: _fail("A3b11R wall reinforcement lacks Quaternius buttresses"); return
				"main_hall_roof_brace":
					if str(fixture.get("primitive_visual", "")) != "main_hall_roof_brace" or visual.get_node_or_null("GarrisonSwallowtailPennant") == null: _fail("A3b11R roof reinforcement lacks the garrison pennant"); return
				"main_hall_tower_reinforcement":
					if str(fixture.get("primitive_visual", "")) != "main_hall_tower_reinforcement" or visual.get_node_or_null("CommandTowerSolidCore") == null or visual.get_node_or_null("CommandTowerRoof") == null: _fail("A3b11R tower reinforcement lacks command silhouette"); return
			continue
		platform_levels[position_id] = int(fixture.get("required_level",0))
		var shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var box := shape.shape as BoxShape3D if shape != null else null
		if str(fixture.get("asset_path", "")) != "res://assets/3d/quaternius/buildings/main_hall_platform_floor.glb" or visual.get_node_or_null("DeviceMount") == null or _count_prefix(visual, "PlatformSupport") != 4 or box == null or body.global_position.y - box.size.y * 0.5 < 3.0: _fail("A3b11R main hall platform is not a detailed roof entity: %s" % position_id); return
		var route: Dictionary = controller.get_building_spatial_route("main_hall",position_id)
		if str(route.get("target_fixture_id","")) != fixture_id or str(route.get("arrival_mode","")) != "stand": _fail("Main hall spatial platform mapping drifted: %s" % position_id); return
	if platform_levels != {"main_hall_slot_01":1,"main_hall_slot_02":3,"main_hall_slot_03":5,"main_hall_slot_04":6} or reinforcement_levels != [2,4,6]: _fail("Main hall 1/3/5/6 platform sequence drifted: %s / %s" % [platform_levels,reinforcement_levels]); return
	var runtime_levels: Dictionary = {}
	for slot in defense_system.get_slots_for_building("main_hall", true): runtime_levels[str(slot.get("id",""))] = int(slot.get("required_building_level",0))
	if runtime_levels != platform_levels: _fail("DefenseDeviceSystem main hall level contract drifted: %s" % runtime_levels); return
	var facade_module_count := 50 if str(hall_art.get_meta("art_revision", "")) in ["t0132_p1r3", "t0132_p1r4", "t0132_p1r5"] else (53 if str(hall_art.get_meta("art_revision", "")) == "t0132_p1r2" else 21)
	print("T0129C A3b11R main hall verification passed: %s" % JSON.stringify({"facade_modules":facade_module_count,"platforms":platform_levels,"reinforcements":reinforcement_levels,"workstations":0}))
	quit(0)

func _find_by_meta(parent: Node,key:String,value:String)->Node:
	for child in parent.get_children():
		if str(child.get_meta(key,""))==value:return child
	return null
func _count_prefix(parent:Node,prefix:String)->int:
	var count:=0
	for child in parent.get_children():
		if str(child.name).begins_with(prefix):count+=1
	return count
func _count_contains(parent:Node,needle:String)->int:
	var count:=0
	for child in parent.get_children():
		if str(child.name).contains(needle):count+=1
	return count
func _load_json(path:String)->Dictionary:
	var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path));return value if value is Dictionary else {}
func _fail(message:String)->void:push_error(message);quit(1)
