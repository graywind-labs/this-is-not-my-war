extends RefCounted
## Approved T0364 meshes and species selection shared by previews and production.

const VARIANT_NAMES := ["oak_mature","oak_young","birch_mature","birch_young","pine_mature","pine_young"]
var style: Dictionary = {}
var meshes: Array[ArrayMesh] = []
var _surface_material := StandardMaterial3D.new()
var _groups_noise := FastNoiseLite.new()

func _init(settings: Dictionary = {}) -> void:
	style = settings.duplicate(true)
	_surface_material.vertex_color_use_as_albedo = true
	_surface_material.vertex_color_is_srgb = true
	_surface_material.roughness = 1.0
	_groups_noise.seed = int(style.get("seed",364))
	_groups_noise.frequency = float(style.get("group_noise_frequency",0.035))
	for family in 3:
		for young in [false,true]:
			meshes.append(_make_tree(family,young))

func make_species_rng(center: Vector2) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(style.get("seed",364))+int(center.x)*131+int(center.y)*4099
	return rng

func choose_variant(point: Vector2, rng: RandomNumberGenerator) -> int:
	var oak_share := lerpf(0.25,0.65,smoothstep(-0.25,0.25,_groups_noise.get_noise_2dv(point)))
	var roll := rng.randf()
	var family := 0 if roll<oak_share else (1 if roll<oak_share+0.22 else 2)
	return family*2+int(rng.randf()<float(style.get("young_fraction",0.28)))

func build_multimeshes(parent: Node3D, groups: Array, shadows: int) -> void:
	for index in groups.size():
		if groups[index].is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = meshes[index]
		multi.instance_count = groups[index].size()
		for placement in groups[index].size():
			multi.set_instance_transform(placement,groups[index][placement])
		var node := MultiMeshInstance3D.new()
		node.name = VARIANT_NAMES[index]
		node.multimesh = multi
		node.cast_shadow = shadows
		node.set_meta("presentation_only",true)
		node.set_meta("approved_tree_variant",VARIANT_NAMES[index])
		parent.add_child(node)

func _make_tree(family: int, young: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(str(style.get("bark_color","#554331")))
	var colors: Array = style.get("pine_colors",["#334b39","#405a40","#506547"]) if family==2 else style.get("leaf_colors",["#405638","#53663c","#657348"])
	var leaf := Color(str(colors[family%3]))
	var growth := 0.62 if young else 1.0
	if family==0:
		_branch(surface,Vector3.ZERO,Vector3(0.12,3.8,0)*growth,0.34*growth,0.12*growth,bark)
		var crowns := [[Vector3(-1.10,3.85,0.10),Vector3(1.45,1.18,1.40)], [Vector3(0.95,4.40,-0.10),Vector3(1.60,1.38,1.38)], [Vector3(-0.05,5.15,-0.05),Vector3(1.50,1.28,1.38)], [Vector3(0.20,3.90,1.04),Vector3(1.10,0.95,1.04)]]
		if young:
			crowns = [[Vector3(-0.40,3.9,0.10),Vector3(1.04,1.16,1.03)],[Vector3(0.30,4.85,-0.05),Vector3(1.18,1.30,1.05)]]
		for index in crowns.size():
			var center: Vector3 = crowns[index][0]*growth
			_branch(surface,Vector3(0.05,2.15,0)*growth,center,0.17*growth,0.055*growth,bark)
			_crown(surface,center,crowns[index][1]*growth,leaf.lightened(index*0.025),10+index)
	elif family==1:
		bark = Color(str(style.get("birch_bark","#b6b29a")))
		_branch(surface,Vector3.ZERO,Vector3(0.20,5.7,0.10)*growth,0.18*growth,0.055*growth,bark)
		for index in (3 if young else 4):
			var angle := float(index)*2.3
			var center := Vector3(cos(angle)*0.65,3.0+index*0.86,sin(angle)*0.48)*growth
			_branch(surface,Vector3(0.1,2.25+index*0.60,0)*growth,center,0.09*growth,0.025*growth,bark)
			_crown(surface,center,Vector3(0.92,1.26,0.84)*growth,leaf.lightened(index*0.017),20+index)
		# Short dark bark marks give the pale trunk an identity at playable camera distance.
		for index in 5:
			var start := Vector3(0.03,0.55+index*0.40,0)*growth
			_branch(surface,start,start+Vector3(0.015,0.10,0)*growth,0.17*growth,0.16*growth,bark.darkened(0.40))
	else:
		_branch(surface,Vector3.ZERO,Vector3(0.08,6.9,0)*growth,0.24*growth,0.045*growth,bark)
		for tier in 4:
			var width := (1.75-tier*0.32)*growth
			for arm in (2 if young else 3):
				var angle := float(arm)*TAU/3.0+tier*1.1
				var center := Vector3(cos(angle)*width*0.52,(2.60+tier*1.02)*growth,sin(angle)*width*0.52)
				_branch(surface,Vector3(0,center.y-0.40*growth,0),center,0.08*growth,0.025*growth,bark)
				_crown(surface,center,Vector3(width*0.78,(0.86-tier*0.09)*growth,width*0.66),Color(str(colors[tier%3])),30+tier*3+arm,true)
		_crown(surface,Vector3(0.08,6.3,0)*growth,Vector3(0.68,1.15,0.60)*growth,Color(str(colors[2])),49,true)
	surface.set_material(_surface_material)
	return surface.commit()

func _branch(surface: SurfaceTool, a: Vector3, b: Vector3, radius_a: float, radius_b: float, color: Color) -> void:
	var axis := (b-a).normalized()
	var right := axis.cross(Vector3.FORWARD).normalized()
	var forward := axis.cross(right).normalized()
	var center := (a+b)*0.5
	for index in 6:
		var angle := float(index)*TAU/6.0
		var next := float(index+1)*TAU/6.0
		var u := right*cos(angle)+forward*sin(angle)
		var v := right*cos(next)+forward*sin(next)
		_face(surface,a+u*radius_a,a+v*radius_a,b+u*radius_b,center,color)
		_face(surface,a+v*radius_a,b+v*radius_b,b+u*radius_b,center,color)
		_face(surface,a,a+v*radius_a,a+u*radius_a,center,color)
		_face(surface,b,b+u*radius_b,b+v*radius_b,center,color)

func _crown(surface: SurfaceTool, center: Vector3, size: Vector3, color: Color, seed_value: int, pointed: bool=false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rings: Array = []
	for level in 3:
		var ring: Array[Vector3] = []
		for index in 7:
			var angle := float(index)*TAU/7.0+float(level)*0.19
			var radius: float = [0.58,1.0,0.57][level]*rng.randf_range(0.85,1.13)
			var height: float = [-0.65,-0.02,0.64][level]
			ring.append(center+Vector3(cos(angle)*radius*size.x,(height+rng.randf_range(-0.08,0.08))*size.y,sin(angle)*radius*size.z))
		rings.append(ring)
	for level in 2:
		for index in 7:
			var next := (index+1)%7
			_face(surface,rings[level][index],rings[level][next],rings[level+1][index],center,color)
			_face(surface,rings[level][next],rings[level+1][next],rings[level+1][index],center,color)
	for index in 7:
		_face(surface,rings[2][index],rings[2][(index+1)%7],center+Vector3(0.09,1.35 if pointed else 0.98,0.06)*size,center,color.lightened(0.04))
		_face(surface,rings[0][index],center-Vector3.UP*size.y*0.85,rings[0][(index+1)%7],center,color.darkened(0.07))

func _face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3, color: Color) -> void:
	var normal := (c-a).cross(b-a).normalized()
	if normal.dot((a+b+c)/3.0-center)<0:
		var temporary := b
		b=c
		c=temporary
		normal = -normal
	for vertex in [a,b,c]:
		surface.set_normal(normal)
		surface.set_color(color)
		surface.add_vertex(vertex)

