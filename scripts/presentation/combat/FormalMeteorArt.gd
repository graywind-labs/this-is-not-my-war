extends "res://scripts/presentation/combat/MeteorPresentation.gd"
## Approved T0379 art shared by production and the isolated comparison.
## PietySystem owns flight, damage, collision lifecycle and crater decay.
const ART_CONFIG_PATH := "res://data/presentation/meteor_art.json"
const ROCK_SHADER := preload("res://shaders/environment/meteor_trial_rock.gdshader")
const CRATER_SHADER := preload("res://shaders/environment/meteor_trial_crater.gdshader")
const PARTICLE_SHADER := preload("res://shaders/environment/meteor_trial_particle.gdshader")
var _rock_shader: ShaderMaterial
var _crater_shader: ShaderMaterial
var _hot_light: OmniLight3D
var _trail: Array[GPUParticles3D] = []
var _dust: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _flash: MeshInstance3D
var _flash_material: StandardMaterial3D
var _impact_age := -1.0
var _rng := RandomNumberGenerator.new()
var _rock_mesh: ArrayMesh
var _ground_fire: Array[GPUParticles3D] = []
var _pressure: MeshInstance3D
var _pressure_material: StandardMaterial3D
var _art_settings: Dictionary = {}

func configure(config: Dictionary) -> void:
	_art_settings = JSON.parse_string(FileAccess.get_file_as_string(ART_CONFIG_PATH)) as Dictionary
	super.configure(config)

func _build_body() -> void:
	_rng.seed = 379
	_body_root = Node3D.new()
	_body_root.name = "MeteorEntity"
	add_child(_body_root)
	_body_present = true
	_rock_shader = ShaderMaterial.new()
	_rock_shader.shader = ROCK_SHADER
	_rock_mesh = _make_rock(_body_radius)
	_mesh(_body_root, "FracturedMeteor", _rock_mesh, _rock_shader)
	_hot_light = OmniLight3D.new()
	_hot_light.light_color = Color("ff8037")
	_hot_light.light_energy = 2.5
	_hot_light.omni_range = 15.0
	_body_root.add_child(_hot_light)
	var tail_size := float(_art_settings.get("tail_size_scale",2.0))
	for entry in [["FlameTail", 150, 0.95, 0.23*tail_size, Color(1,0.25,0.025,0.85)], ["FlameCoreTail", 55, 0.65, 0.16*tail_size, Color(1,0.65,0.16,0.8)], ["EmberTail", 64, 1.3, 0.09, Color(1,0.64,0.16,1)], ["SmokeTail", 42, 1.9, 0.78, Color(0.19,0.18,0.17,0.35)]]:
		var particles := _particles(entry[0],entry[1],entry[2],entry[3],entry[4])
		_body_root.add_child(particles)
		_trail.append(particles)

func _make_rock(radius: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 15
	var rings := 9
	var rows: Array[PackedVector3Array] = []
	for row in range(rings+1):
		var vertices := PackedVector3Array()
		var phi := PI*float(row)/rings
		for col in range(segments):
			var angle := TAU*float(col)/segments + 0.13*sin(float(row)*2.1)
			var d := Vector3(sin(phi)*cos(angle),cos(phi),sin(phi)*sin(angle))
			var rough := 0.94+0.095*sin(d.x*5.7+d.z*3.1)+0.065*cos(d.y*7.1-d.x*4.2)+0.04*sin(d.z*11.3+d.y*5.0)
			vertices.append(d*radius*rough*Vector3(1.04,0.91,0.98))
		rows.append(vertices)
	for row in range(rings):
		for col in range(segments):
			var next := (col+1)%segments
			if row>0: _triangle(surface,rows[row][col],rows[row][next],rows[row+1][col])
			if row<rings-1: _triangle(surface,rows[row][next],rows[row+1][next],rows[row+1][col])
	surface.generate_normals()
	return surface.commit()

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot front faces wind clockwise when seen from outside.
	if (b-a).cross(c-a).dot((a+b+c)/3.0)>0.0:
		var swap := b
		b = c
		c = swap
	var tone := _rng.randf_range(0.22,0.83)
	surface.set_color(Color(tone,tone,tone,1))
	for v in [a,b,c]: surface.add_vertex(v)

func set_fall_transform(position: Vector3, progress: float) -> void:
	var movement := position-global_position
	global_position = position
	if _body_root == null: return
	# Ease rotation to the final orientation instead of snapping at impact.
	var final := Vector3(0.18,0.75,-0.12)
	_body_root.rotation = final + Vector3(-0.7,-1.1,0.32)*pow(1.0-progress,1.25)
	if movement.length()>0.001:
		var back := -movement.normalized()
		for p in _trail:
			p.position = _body_root.basis.inverse()*back*_body_radius*0.48
			var material := p.process_material as ParticleProcessMaterial
			material.direction = _body_root.global_basis.inverse()*back

func get_fall_world_position(start: Vector3, target: Vector3, progress: float) -> Vector3:
	return start.lerp(target+Vector3.UP*(_body_radius*0.58),pow(clampf(progress,0.0,1.0),1.7))

func impact_at(target_position: Vector3) -> void:
	super.impact_at(target_position)
	_impact_age = 0.0
	for p in _trail:
		p.emitting = false
	var smoke := _particles("RestingSmoke",18,2.5,0.45,Color(0.2,0.19,0.18,0.25))
	smoke.position.y = _body_radius*0.6
	_body_root.add_child(smoke)
	for i in range(5):
		var fire := _particles("GroundFlame%d"%i,9,0.7,0.11,Color(1.0,0.4,0.065,0.8))
		var angle := float(i)*2.39996
		fire.position = Vector3(cos(angle),0,sin(angle))*_crater_radius*0.72
		fire.position.y = -_body_radius*0.58+0.3
		(fire.process_material as ParticleProcessMaterial).emission_sphere_radius = 0.4
		_body_root.add_child(fire)
		_ground_fire.append(fire)

func _process(delta: float) -> void:
	var rate := _get_effect_rate()
	for particles in _particle_emitters:
		if is_instance_valid(particles): particles.speed_scale = rate
	delta *= rate
	if delta<=0.0: return
	if _impact_age<0.0: return
	_impact_age += delta
	var heat := maxf(0.14,exp(-_impact_age*0.25))
	_rock_shader.set_shader_parameter("heat",heat)
	if _impact_age>5.0:
		for fire in _ground_fire:
			if is_instance_valid(fire): fire.emitting = false
	if is_instance_valid(_hot_light): _hot_light.light_energy = 2.5*heat + 6.0*exp(-_impact_age*16.0)
	if not is_instance_valid(_impact_root): return
	if is_instance_valid(_flash):
		_flash.scale = Vector3.ONE*(1.0+_impact_age*5.0)
		_flash_material.albedo_color.a = maxf(0.0,0.8*(1.0-_impact_age/0.18))
	if is_instance_valid(_pressure):
		_pressure.scale = Vector3.ONE*(0.5+minf(_impact_age,1.0)*2.5)
		_pressure_material.albedo_color.a = maxf(0.0,0.38*(1.0-_impact_age/1.0))
	for item in _dust:
		var mesh: MeshInstance3D = item.node
		var age := maxf(0.0,_impact_age-float(item.delay))
		var distance := _crater_radius*(0.6+1.0*(1.0-exp(-age*2.3)))*float(_art_settings.get("impact_spread_scale",1.2))
		mesh.position = item.direction*distance + Vector3.UP*(0.15+age*0.37)
		mesh.scale = item.size*(0.4+age*0.85)*1.15
		var mat: StandardMaterial3D = item.material
		mat.albedo_color.a = clampf(age*5.0,0,1)*maxf(0.0,0.55*(1.0-age/2.4))
	for item in _debris:
		var mesh: MeshInstance3D = item.node
		var t := _impact_age
		mesh.position = item.start + item.velocity*t + Vector3(0,-8.0,0)*t*t
		mesh.position.y = maxf(0.06,mesh.position.y)
		mesh.rotation = item.spin*minf(t,0.9)
		mesh.scale = item.size*clampf((2.5-t)/0.6,0.0,1.0)
	if _impact_age>3.0:
		_impact_root.queue_free()
		_impact_root = null
		_dust.clear()
		_debris.clear()

func _get_effect_rate() -> float:
	if _landed: return _get_combat_frame_rate()
	# Match production flight: real seconds, independent of world speed, but pausable.
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	return 0.0 if time_system != null and time_system.is_gameplay_paused() else 1.0

func _build_crater() -> void:
	_crater_materials.clear()
	_crater_root = Node3D.new()
	_crater_root.name = "TrialScorchedCrater"
	add_child(_crater_root)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 61
	var radii := [0.0,0.50,0.74,0.94,1.26]
	var heights := [0.026,0.032,0.34,0.13,0.028]
	var colors := [Color("393a35"),Color("302d27"),Color("655a46"),Color("433c2c"),Color(0.18,0.17,0.12,0)]
	for ring in range(4):
		for i in range(segments):
			var points: Array[Vector3] = []
			for corner in [[ring,i],[ring,(i+1)%segments],[ring+1,i],[ring+1,(i+1)%segments]]:
				var angle := TAU*float(corner[1])/segments
				var r := float(radii[corner[0]])*_crater_radius*(1.0+0.065*sin(angle*5.0)+0.075*cos(angle*9.0+1.0))
				var h := float(heights[corner[0]])*(1.0+0.5*sin(angle*7.0)) if corner[0]>0 else float(heights[0])
				points.append(Vector3(cos(angle)*r,h,sin(angle)*r))
			for index in [0,2,1,2,3,1]:
				var color: Color = colors[ring if index<2 else ring+1]
				surface.set_color(color.srgb_to_linear())
				surface.add_vertex(points[index])
	surface.generate_normals()
	_crater_shader = ShaderMaterial.new()
	_crater_shader.shader = CRATER_SHADER
	_mesh(_crater_root,"BrokenEarthAndScorch",surface.commit(),_crater_shader)
	var rim_material := _register_crater_material(_ash_material(Color("595447")))
	for i in range(19):
		var angle := _rng.randf_range(0,TAU)
		var direction := Vector3(cos(angle),0,sin(angle))
		var rock := _mesh(_crater_root,"EjectedRimFragment%d"%i,_rock_mesh,rim_material)
		rock.position = direction*_crater_radius*_rng.randf_range(0.72,1.04)
		rock.position.y = 0.05
		rock.rotation = Vector3(_rng.randf(),angle,_rng.randf())
		rock.scale = Vector3(_rng.randf_range(0.06,0.15),_rng.randf_range(0.025,0.09),_rng.randf_range(0.05,0.14))

func _build_impact_vfx() -> void:
	_impact_root = Node3D.new()
	_impact_root.name = "TrialImpact"
	add_child(_impact_root)
	_flash_material = _glow_material(Color(1.0,0.72,0.23,0.8),true,5.0)
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = _crater_radius*0.80
	flash_mesh.height = 1.45
	_flash = _mesh(_impact_root,"ContactFlash",flash_mesh,_flash_material)
	_flash.position.y = 0.3
	var pressure_mesh := TorusMesh.new()
	pressure_mesh.inner_radius = _crater_radius-0.16
	pressure_mesh.outer_radius = _crater_radius+0.16
	pressure_mesh.rings = 64
	pressure_mesh.ring_segments = 4
	_pressure_material = _glow_material(Color(0.78,0.73,0.63,0.38),true,0.0)
	_pressure = _mesh(_impact_root,"AirPressureFront",pressure_mesh,_pressure_material)
	_pressure.position.y = 0.18
	var dust_mesh := SphereMesh.new()
	dust_mesh.radial_segments = 7
	dust_mesh.rings = 4
	for i in range(22):
		var angle := TAU*float(i)/22.0 + _rng.randf_range(-0.09,0.09)
		var mat := _ash_material(Color(0.39,0.34,0.26,0.0))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var dust := _mesh(_impact_root,"GroundDust%d"%i,dust_mesh,mat)
		_dust.append({"node":dust,"direction":Vector3(cos(angle),0,sin(angle)),"material":mat,"delay":_rng.randf_range(0.0,0.1),"size":Vector3(_rng.randf_range(1.3,2.2),_rng.randf_range(0.6,1.4),_rng.randf_range(1.3,2.2))})
	var debris_mat := _ash_material(Color("4c4537"))
	for i in range(36):
		var angle := _rng.randf_range(0,TAU)
		var d := Vector3(cos(angle),0,sin(angle))
		var piece := _mesh(_impact_root,"FlyingFragment%d"%i,_rock_mesh,debris_mat)
		_debris.append({"node":piece,"start":d*_rng.randf_range(1.0,3.2)+Vector3.UP*0.4,"velocity":d*_rng.randf_range(3,8)+Vector3.UP*_rng.randf_range(3,8),"spin":Vector3(_rng.randf(),_rng.randf(),_rng.randf())*7.0,"size":Vector3.ONE*_rng.randf_range(0.025,0.085)})

func _particles(label: String, amount: int, lifetime: float, radius: float, tint: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	_particle_emitters.append(p)
	p.name = label
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-60,-60,-60),Vector3(120,120,120))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = _body_radius*0.48
	pm.direction = Vector3.UP
	pm.spread = 17.0
	pm.initial_velocity_min = 4.0 if "Tail" in label else 0.7
	pm.initial_velocity_max = 9.0 if "Tail" in label else 1.8
	if "Tail" in label:
		var speed := float(_art_settings.get("tail_speed_scale",1.6))
		pm.initial_velocity_min *= speed
		pm.initial_velocity_max *= speed
	pm.gravity = Vector3(0,0.5,0)
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	var gradient := Gradient.new()
	gradient.set_color(0,Color(tint,0.0))
	gradient.add_point(0.12,tint)
	gradient.add_point(0.5,Color(tint,tint.a*0.65))
	gradient.set_color(1,Color(tint,0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	pm.color_ramp = ramp
	p.process_material = pm
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius*(3.6 if "Flame" in label else 2.0)
	shape.radial_segments = 6
	shape.rings = 3
	var material := ShaderMaterial.new()
	material.shader = PARTICLE_SHADER
	material.set_shader_parameter("tint",tint)
	material.set_shader_parameter("glow",0.0 if "Smoke" in label else 1.5)
	shape.material = material
	p.draw_pass_1 = shape
	return p

func set_crater_fade_progress(progress: float) -> void:
	super.set_crater_fade_progress(progress)
	if _crater_shader != null:
		_crater_shader.set_shader_parameter("opacity",1.0-_crater_fade_progress)

func _mesh(parent: Node3D, label: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	return node
