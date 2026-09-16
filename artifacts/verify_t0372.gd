extends SceneTree
const OUT := "res://artifacts/visual_qa/t0372/"
var failures: Array[String]=[]
var views: Array[Dictionary]=[]
func _init() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func capture(name: String) -> void:
	await frames(15)
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(OUT+name)!=OK: failures.append(name)
func run() -> void:
	var menu:=load("res://scenes/frontend/MainMenu.tscn").instantiate() as Control
	root.add_child(menu)
	await frames(80)
	var cover: Node3D=menu._cover_scene
	var display:=cover.get_node("Set/MainHallHero/CoverDefenseDisplay") as Node3D
	var platform:=display.get_node("LevelOnePlatform") as Node3D
	var ballista:=display.get_node("LoadedBallista") as Node3D
	if not display.position.is_zero_approx() or not platform.position.is_equal_approx(Vector3(-7,3.05,5)): failures.append("Not at formal level-one corner")
	if platform.get_debug_snapshot().structure_parts!=26 or ballista.get_debug_snapshot().structure_parts!=62: failures.append("Formal art changed")
	if not is_equal_approx(ballista.position.y-platform.position.y,0.88): failures.append("Mount anchor changed")
	if not display.find_children("*","CollisionObject3D",true,false).is_empty(): failures.append("Collision added")
	if not display.find_children("*","NavigationRegion3D",true,false).is_empty(): failures.append("Navigation added")
	if root.get_node_or_null("Main")!=null: failures.append("Main started")
	if ballista.get_debug_snapshot().shot_count!=0: failures.append("Combat started")
	var camera:=cover.get_node("Camera3D") as Camera3D
	for size in [Vector2i(922,518),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1600,1200),Vector2i(2560,1080)]:
		root.size=size
		await frames(8)
		var hero:=menu.find_child("MenuHeroBackdrop",true,false) as Control
		var source: Rect2=hero.debug_get_cover_snapshot().source_rect
		var bounds:=Rect2()
		var first:=true
		for mesh in ballista.find_children("*","MeshInstance3D",true,false):
			for i in 8:
				var p:=camera.unproject_position(mesh.to_global(mesh.get_aabb().get_endpoint(i)))
				p=(p-source.position)/source.size*hero.size
				if first: bounds=Rect2(p,Vector2.ZERO);first=false
				else: bounds=bounds.expand(p)
		var panel: Rect2=menu.get_node("MenuPanel").get_global_rect()
		if panel.encloses(bounds): failures.append("Weapon fully hidden: %s"%size)
		views.append({"size":str(size),"weapon_rect":str(bounds),"panel":str(panel),"partial_menu_overlap":bounds.intersects(panel)})
		await capture("menu_%dx%d.png"%[size.x,size.y])
	root.size=Vector2i(1920,1080)
	for path in ["TitleBlock","MenuPanel","VersionLabel"]: menu.get_node(path).hide()
	for entry in [["ballista_front.png",Vector3(-5.4,9,8),Vector3(1.4,4.4,-3.8)],["ballista_side.png",Vector3(-10.4,9,-6),Vector3(1.4,4.4,-3.8)]]:
		camera.position=entry[1]
		camera.look_at(entry[2])
		camera.fov=32
		await capture(entry[0])
	FileAccess.open(OUT+"verification.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"views":views,"platform":platform.get_debug_snapshot(),"ballista":ballista.get_debug_snapshot()},"  "))
	menu.queue_free()
	root.get_node("AudioManager").stop_music(0)
	await frames(30)
	print("T0372_GPU_PASS" if failures.is_empty() else JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
