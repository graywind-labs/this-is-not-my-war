extends SceneTree

const MAIN_PATH := "res://scenes/main/Main.tscn"
const LAYOUT_PATH := "res://data/station_layout.json"

func _init() -> void:
	var layout:=_load_json(LAYOUT_PATH);var packed:=load(MAIN_PATH)as PackedScene
	if layout.is_empty()or packed==null:_fail("A3b13 inputs unavailable");return
	var main:=packed.instantiate();root.add_child(main)
	for _i in 5:await process_frame;await physics_frame
	var controller:=root.get_node_or_null("Main/Presentation/StationLayoutController")
	var formal:=root.get_node_or_null("Main/WorldRoot/FormalStationLayout")as Node3D
	var natural:=formal.get_node_or_null("NaturalBoundaries")if formal!=null else null
	var region:=root.get_node_or_null("Main/WorldRoot/FormalStationLayout/SpatialContract/StationNavigation")as NavigationRegion3D
	if controller==null or formal==null or natural==null or region==null:_fail("A3b13 hierarchy incomplete");return
	var snapshot:Dictionary=controller.debug_get_layout_snapshot();var physics:Dictionary=controller.debug_get_physics_navigation_snapshot();var production:Dictionary=controller.debug_get_production_navigation_snapshot()
	if int(snapshot.get("configuration_error_count",-1))!=0 or int(snapshot.get("natural_boundary_count",0))!=24 or int(physics.get("natural_boundary_count",0))!=24 or int(physics.get("static_body_count",0))!=243 or int(physics.get("building_interior_blocker_count",0))!=1 or int(production.get("source_static_body_count",0))!=239 or int(production.get("vertex_count",0))!=966 or int(production.get("polygon_count",0))!=892 or int(production.get("building_door_link_count",0))!=11:_fail("A3 final counts/config drifted: %s / %s / %s"%[snapshot,physics,production]);return
	var categories:Dictionary=physics.get("collision_category_counts",{})
	if int(categories.get("natural_river_cliff",0))!=8 or int(categories.get("natural_rock_ridge",0))!=4 or int(categories.get("natural_dense_forest",0))!=12:_fail("Natural category counts drifted: %s"%categories);return
	var natural_bodies:=natural.find_children("*","StaticBody3D",true,false)
	if natural_bodies.size()!=24:_fail("Expected 24 auditable natural StaticBodies");return
	for raw in natural_bodies:
		var body:=raw as StaticBody3D;var shape:=body.get_node_or_null("CollisionShape3D")as CollisionShape3D
		if body.collision_layer!=1 or body.collision_mask!=2 or shape==null or not shape.shape is BoxShape3D or not body.is_in_group("formal_navigation_source")or str(body.get_meta("natural_barrier_id","")).is_empty():_fail("Invalid natural body: %s"%body.name);return
	var space:=formal.get_world_3d().direct_space_state
	if not _ray_hits_natural(space,formal.to_global(Vector3(-74.0,1.0,0.0)),formal.to_global(Vector3(-90.0,1.0,0.0)),"natural_river_cliff"):_fail("River cliff physical barrier missing");return
	if not _ray_hits_natural(space,formal.to_global(Vector3(110.0,1.0,0.0)),formal.to_global(Vector3(180.0,1.0,0.0)),"natural_rock_ridge"):_fail("East ridge physical barrier missing");return
	if not _ray_hits_natural(space,formal.to_global(Vector3(-100.0,1.0,70.0)),formal.to_global(Vector3(-100.0,1.0,100.0)),"natural_dense_forest"):_fail("Front forest physical barrier missing");return
	for raw_road in layout.get("roads",[]):
		var road:=raw_road as Dictionary
		if str(road.get("kind",""))not in["enemy","trade"]:continue
		var a:=_v2(road.get("from",[]));var b:=_v2(road.get("to",[]))
		var query:=PhysicsRayQueryParameters3D.create(formal.to_global(Vector3(a.x,1.0,a.y)),formal.to_global(Vector3(b.x,1.0,b.y)),1);query.collide_with_bodies=true
		var hit:=space.intersect_ray(query);var collider:=hit.get("collider")as StaticBody3D
		if collider!=null and str(collider.get_meta("collision_category","")).begins_with("natural_"):_fail("Natural boundary blocks %s corridor at %s"%[str(road.get("id","")),collider.name]);return
	controller.debug_set_preview_enabled(true)
	for _i in 4:await physics_frame
	var map:=region.get_navigation_map();NavigationServer3D.map_force_update(map);var route_count:=0;var minimum_points:=999
	for raw_building in layout.get("buildings",[]):
		var building:=raw_building as Dictionary;var building_id:=str(building.get("id",""));var spatial:=((layout.get("building_spatial",{})as Dictionary).get(building_id,{})as Dictionary)
		for raw_position in spatial.get("positions",[]):
			var position:=raw_position as Dictionary
			if str(position.get("authority",""))!="building_workstation":continue
			var route:Dictionary=controller.get_building_spatial_route(building_id,str(position.get("id","")));var target:Vector3=route.get("interior_target_position",Vector3.ZERO);var path:=NavigationServer3D.map_get_path(map,route.get("entry_outside_position",Vector3.ZERO),target,true)
			if path.size()<3 or path[-1].distance_to(target)>0.31:_fail("A3 production route failed: %s/%s / %s"%[building_id,str(position.get("id","")),path]);return
			route_count+=1;minimum_points=mini(minimum_points,path.size())
	controller.debug_set_preview_enabled(false)
	if route_count!=61:_fail("A3 must verify all 61 NPC workstation routes, got %d"%route_count);return
	print("T0129C A3b13 / A3 complete verification passed: %s"%JSON.stringify({"natural_bodies":24,"workstation_routes":route_count,"minimum_route_points":minimum_points,"production_navigation":production}));quit(0)

func _ray_hits_natural(space:PhysicsDirectSpaceState3D,from:Vector3,to:Vector3,category:String)->bool:
	var query:=PhysicsRayQueryParameters3D.create(from,to,1);query.collide_with_bodies=true;var hit:=space.intersect_ray(query);var collider:=hit.get("collider")as StaticBody3D;return collider!=null and str(collider.get_meta("collision_category",""))==category
func _load_json(path:String)->Dictionary:
	var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path));return value if value is Dictionary else {}
func _v2(value:Variant)->Vector2:return Vector2(float(value[0]),float(value[1]))if value is Array and value.size()>=2 else Vector2.ZERO
func _fail(message:String)->void:push_error(message);quit(1)
