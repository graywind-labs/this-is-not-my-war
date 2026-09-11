class_name MeteorPresentation
extends Node3D

const ROCK_SCENE := preload("res://assets/3d/quaternius/nature/ground_detail/pebble_round_1.glb")

var _body_root: Node3D
var _crater_root: Node3D
var _impact_root: Node3D
var _shockwave_materials: Array[StandardMaterial3D] = []
var _crater_materials: Array[StandardMaterial3D] = []
var _particle_emitters: Array[GPUParticles3D] = []
var _impact_elapsed := 0.0
var _impact_duration := 2.0
var _body_radius := 4.2
var _crater_radius := 4.8
var _crater_fade_progress := 0.0
var _landed := false
var _body_present := false


func configure(config: Dictionary) -> void:
	_body_radius = maxf(0.5, float(config.get("body_radius", 4.2)))
	_crater_radius = maxf(_body_radius, float(config.get("crater_radius", 4.8)))
	_impact_duration = maxf(0.1, float(config.get("impact_vfx_duration_seconds", 2.0)))
	_build_body()
	_build_crater()
	_crater_root.visible = false


func set_fall_transform(position: Vector3, progress: float) -> void:
	global_position = position
	if _body_root == null:
		return
	_body_root.rotation = Vector3(
		progress * 4.8,
		progress * 7.2,
		progress * 3.1
	)


func impact_at(target_position: Vector3) -> void:
	global_position = target_position
	_landed = true
	_impact_elapsed = 0.0
	if _body_root != null:
		_body_root.position = Vector3(0.0, _body_radius * 0.58, 0.0)
		_body_root.rotation = Vector3(0.18, 0.75, -0.12)
		_add_body_collider()
	if _crater_root != null:
		_crater_root.visible = true
	set_crater_fade_progress(0.0)
	_build_impact_vfx()


func remove_landed_body() -> void:
	if _body_root != null and is_instance_valid(_body_root):
		_body_root.queue_free()
	_body_root = null
	_body_present = false


func is_landed() -> bool:
	return _landed


func has_body() -> bool:
	return _body_present


func get_landed_collision_radius() -> float:
	return _body_radius * 0.78


func has_crater() -> bool:
	return _crater_root != null and is_instance_valid(_crater_root) and _crater_root.visible


func has_permanent_crater() -> bool:
	# Compatibility alias for T0165-era diagnostics. The crater now expires.
	return has_crater()


func set_crater_fade_progress(progress: float) -> void:
	_crater_fade_progress = clampf(progress, 0.0, 1.0)
	var opacity := 1.0 - _crater_fade_progress
	for material in _crater_materials:
		if material == null:
			continue
		var color := material.albedo_color
		color.a = opacity
		material.albedo_color = color


func remove_crater() -> void:
	if _crater_root != null and is_instance_valid(_crater_root):
		_crater_root.queue_free()
	_crater_root = null
	_crater_materials.clear()
	_crater_fade_progress = 1.0


func get_presentation_snapshot() -> Dictionary:
	return {
		"landed": _landed,
		"body_present": has_body(),
		"crater_present": has_crater(),
		"crater_fade_progress": _crater_fade_progress,
		"crater_opacity": 1.0 - _crater_fade_progress,
		"permanent_crater": has_permanent_crater(),
		"body_radius": _body_radius,
		"crater_radius": _crater_radius,
		"impact_vfx_active": _impact_root != null and is_instance_valid(_impact_root)
	}


func _process(delta: float) -> void:
	var combat_rate := _get_combat_frame_rate()
	for particles in _particle_emitters:
		if particles != null and is_instance_valid(particles):
			particles.speed_scale = combat_rate
	if _impact_root == null or not is_instance_valid(_impact_root):
		return
	var combat_delta := _get_combat_frame_delta_seconds(delta)
	if combat_delta <= 0.0:
		return
	_impact_elapsed = minf(_impact_duration, _impact_elapsed + combat_delta)
	var progress := clampf(_impact_elapsed / _impact_duration, 0.0, 1.0)
	var rings := _impact_root.get_node_or_null("Shockwaves") as Node3D
	if rings != null:
		rings.scale = Vector3.ONE * lerpf(0.62, 1.72, ease(progress, -1.8))
	for material in _shockwave_materials:
		if material != null:
			var color := material.albedo_color
			color.a = lerpf(0.68, 0.0, progress)
			material.albedo_color = color
			material.emission_energy_multiplier = lerpf(4.5, 0.2, progress)
	if _impact_elapsed >= _impact_duration:
		_impact_root.queue_free()
		_impact_root = null
		_shockwave_materials.clear()


func _get_combat_frame_delta_seconds(real_delta_seconds: float) -> float:
	var time_system := get_node_or_null("/root/Main/Systems/TimeSystem")
	if time_system != null and time_system.has_method("get_combat_frame_delta_seconds"):
		return maxf(0.0, float(time_system.get_combat_frame_delta_seconds(real_delta_seconds)))
	return maxf(0.0, real_delta_seconds)


func _get_combat_frame_rate() -> float:
	return _get_combat_frame_delta_seconds(1.0)


func _build_body() -> void:
	_body_root = Node3D.new()
	_body_root.name = "MeteorEntity"
	add_child(_body_root)
	_body_present = true
	var mass := MeshInstance3D.new()
	mass.name = "MeteorRockMass"
	var mass_mesh := SphereMesh.new()
	mass_mesh.radius = _body_radius
	mass_mesh.height = _body_radius * 2.0
	mass_mesh.radial_segments = 16
	mass_mesh.rings = 9
	mass.mesh = mass_mesh
	mass.scale = Vector3(1.0, 0.94, 1.04)
	mass.set_surface_override_material(0, _rock_material())
	_body_root.add_child(mass)
	var heat_shell := MeshInstance3D.new()
	heat_shell.name = "MeteorHeatShell"
	var heat_mesh := SphereMesh.new()
	heat_mesh.radius = _body_radius * 1.045
	heat_mesh.height = _body_radius * 2.09
	heat_mesh.radial_segments = 24
	heat_mesh.rings = 14
	heat_shell.mesh = heat_mesh
	heat_shell.set_surface_override_material(0, _glow_material(Color(1.0, 0.16, 0.01, 0.055), true, 2.8))
	_body_root.add_child(heat_shell)

	var core := ROCK_SCENE.instantiate() as Node3D
	core.name = "QuaterniusRockCore"
	core.scale = Vector3(_body_radius * 1.3, _body_radius * 1.12, _body_radius * 1.26)
	_body_root.add_child(core)
	_tint_meshes(core, _rock_material())

	# Dark inset patches break up the silhouette and read as old impact pits.
	var crater_specs := [
		[Vector3(-0.35, 0.73, 0.22), Vector3(0.72, 0.18, 0.58)],
		[Vector3(0.46, 0.48, -0.48), Vector3(0.52, 0.15, 0.46)],
		[Vector3(-0.58, 0.24, -0.35), Vector3(0.44, 0.13, 0.38)],
		[Vector3(0.62, -0.08, 0.31), Vector3(0.34, 0.11, 0.30)]
	]
	for index in range(crater_specs.size()):
		var spec: Array = crater_specs[index]
		var pit := MeshInstance3D.new()
		pit.name = "SurfacePit%d" % (index + 1)
		var pit_mesh := SphereMesh.new()
		pit_mesh.radius = 1.0
		pit_mesh.height = 2.0
		pit_mesh.radial_segments = 20
		pit_mesh.rings = 10
		pit.mesh = pit_mesh
		pit.scale = spec[1] * (_body_radius * 0.2)
		pit.position = spec[0] * _body_radius
		pit.set_surface_override_material(0, _ash_material(Color(0.065, 0.045, 0.035, 1.0)))
		_body_root.add_child(pit)
	var top_pits := [Vector2(-1.35, -0.8), Vector2(0.95, -1.15), Vector2(-0.25, 0.55), Vector2(1.55, 0.7)]
	for index in range(top_pits.size()):
		var offset: Vector2 = top_pits[index]
		var pit_disk := MeshInstance3D.new()
		pit_disk.name = "TopImpactPit%d" % (index + 1)
		var disk_mesh := CylinderMesh.new()
		disk_mesh.top_radius = 0.58 + 0.12 * float(index % 2)
		disk_mesh.bottom_radius = disk_mesh.top_radius
		disk_mesh.height = 0.055
		disk_mesh.radial_segments = 20
		pit_disk.mesh = disk_mesh
		var surface_y := sqrt(maxf(0.0, _body_radius * _body_radius - offset.length_squared()))
		pit_disk.position = Vector3(offset.x, surface_y + 0.025, offset.y)
		pit_disk.set_surface_override_material(0, _ash_material(Color(0.045, 0.026, 0.02, 1.0)))
		_body_root.add_child(pit_disk)

	_body_root.add_child(_make_particle_emitter(
		"RagingFlames", 42, 0.62, _body_radius * 0.74,
		Vector3(0.0, 1.0, 0.0), 2.2, 5.4,
		Vector3(0.0, 1.2, 0.0), Color(1.0, 0.18, 0.015, 0.72), 0.2
	))
	_body_root.add_child(_make_particle_emitter(
		"EmberTrail", 32, 1.1, _body_radius * 0.52,
		Vector3(0.0, 1.0, 0.0), 1.0, 3.2,
		Vector3(0.0, 0.5, 0.0), Color(1.0, 0.55, 0.04, 0.88), 0.1
	))
	_body_root.add_child(_make_particle_emitter(
		"SmokeTrail", 22, 1.7, _body_radius * 0.5,
		Vector3(0.0, 1.0, 0.0), 1.3, 2.6,
		Vector3(0.0, 0.8, 0.0), Color(0.12, 0.095, 0.08, 0.2), 0.27
	))

	var light := OmniLight3D.new()
	light.name = "MeteorLight"
	light.light_color = Color(1.0, 0.22, 0.035, 1.0)
	light.light_energy = 7.5
	light.omni_range = _body_radius * 4.2
	_body_root.add_child(light)


func _build_crater() -> void:
	_crater_materials.clear()
	_crater_root = Node3D.new()
	_crater_root.name = "PermanentCraterAndAsh"
	_crater_root.position.y = 0.12
	add_child(_crater_root)

	var bowl := MeshInstance3D.new()
	bowl.name = "DepressedCrater"
	bowl.mesh = _make_crater_mesh(_crater_radius)
	bowl.set_surface_override_material(0, _register_crater_material(_ash_material(Color(0.095, 0.07, 0.055, 1.0))))
	_crater_root.add_child(bowl)

	var ash := MeshInstance3D.new()
	ash.name = "PermanentAshBed"
	var ash_mesh := CylinderMesh.new()
	ash_mesh.top_radius = _crater_radius * 0.7
	ash_mesh.bottom_radius = _crater_radius * 0.7
	ash_mesh.height = 0.025
	ash_mesh.radial_segments = 48
	ash.mesh = ash_mesh
	ash.position.y = 0.035
	ash.set_surface_override_material(0, _register_crater_material(_ash_material(Color(0.07, 0.058, 0.052, 1.0))))
	_crater_root.add_child(ash)
	var scorch := MeshInstance3D.new()
	scorch.name = "PermanentScorchedGround"
	var scorch_mesh := CylinderMesh.new()
	scorch_mesh.top_radius = _crater_radius
	scorch_mesh.bottom_radius = _crater_radius
	scorch_mesh.height = 0.028
	scorch_mesh.radial_segments = 64
	scorch.mesh = scorch_mesh
	scorch.position.y = 0.018
	scorch.set_surface_override_material(0, _register_crater_material(_ash_material(Color(0.105, 0.073, 0.052, 1.0))))
	_crater_root.add_child(scorch)
	_crater_root.move_child(scorch, 0)
	var scorch_material := _register_crater_material(_ash_material(Color(0.085, 0.057, 0.043, 1.0)))
	for index in range(11):
		var angle := TAU * float(index) / 11.0 + 0.14 * sin(float(index) * 1.7)
		var edge_patch := MeshInstance3D.new()
		edge_patch.name = "IrregularScorchEdge%02d" % index
		var edge_mesh := SphereMesh.new()
		edge_mesh.radius = 0.72 + 0.16 * float(index % 3)
		edge_mesh.height = 0.13
		edge_mesh.radial_segments = 12
		edge_mesh.rings = 5
		edge_patch.mesh = edge_mesh
		edge_patch.position = Vector3(cos(angle), 0.035, sin(angle)) * _crater_radius * 0.9
		edge_patch.set_surface_override_material(0, scorch_material)
		_crater_root.add_child(edge_patch)
	var ash_clump_material := _register_crater_material(_ash_material(Color(0.22, 0.205, 0.19, 1.0)))
	for index in range(18):
		var angle := float(index) * 2.39996
		var distance := _crater_radius * (0.15 + 0.035 * float(index % 10))
		var ash_clump := MeshInstance3D.new()
		ash_clump.name = "PermanentAshClump%02d" % index
		var clump_mesh := SphereMesh.new()
		clump_mesh.radius = 0.11 + 0.035 * float(index % 4)
		clump_mesh.height = clump_mesh.radius * (0.7 + 0.12 * float(index % 3))
		clump_mesh.radial_segments = 8
		clump_mesh.rings = 4
		ash_clump.mesh = clump_mesh
		ash_clump.position = Vector3(cos(angle) * distance, 0.09, sin(angle) * distance)
		ash_clump.set_surface_override_material(0, ash_clump_material)
		_crater_root.add_child(ash_clump)

	var rim_material := _register_crater_material(_ash_material(Color(0.16, 0.115, 0.08, 1.0)))
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		var rim_rock := ROCK_SCENE.instantiate() as Node3D
		rim_rock.name = "CraterRimRock%02d" % index
		rim_rock.position = Vector3(cos(angle), 0.0, sin(angle)) * _crater_radius * 0.9
		rim_rock.position.y = -0.08 + 0.07 * sin(float(index) * 2.17)
		rim_rock.rotation = Vector3(0.0, -angle, 0.12 * sin(float(index)))
		var size := _crater_radius * (0.23 + 0.045 * float(index % 3))
		rim_rock.scale = Vector3(size, size * 0.42, size * 0.72)
		_tint_meshes(rim_rock, rim_material)
		_crater_root.add_child(rim_rock)


func _build_impact_vfx() -> void:
	_impact_root = Node3D.new()
	_impact_root.name = "ImpactExplosion"
	add_child(_impact_root)
	_shockwave_materials.clear()

	var rings := Node3D.new()
	rings.name = "Shockwaves"
	_impact_root.add_child(rings)
	for index in range(3):
		var ring := MeshInstance3D.new()
		ring.name = "AirShockwave%d" % (index + 1)
		var torus := TorusMesh.new()
		torus.inner_radius = _crater_radius * (1.0 + float(index) * 0.38)
		torus.outer_radius = torus.inner_radius + 0.18 + float(index) * 0.06
		torus.rings = 64
		torus.ring_segments = 10
		ring.mesh = torus
		ring.position.y = 0.15 + float(index) * 0.28
		var material := _glow_material(Color(1.0, 0.66, 0.22, 0.68), true, 4.5)
		ring.set_surface_override_material(0, material)
		_shockwave_materials.append(material)
		rings.add_child(ring)

	var flash := MeshInstance3D.new()
	flash.name = "GroundExplosionFlash"
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = _crater_radius * 0.65
	flash_mesh.height = _crater_radius * 0.72
	flash_mesh.radial_segments = 32
	flash_mesh.rings = 16
	flash.mesh = flash_mesh
	flash.position.y = _crater_radius * 0.18
	var flash_material := _glow_material(Color(1.0, 0.28, 0.025, 0.54), true, 6.0)
	flash.set_surface_override_material(0, flash_material)
	_shockwave_materials.append(flash_material)
	_impact_root.add_child(flash)

	var debris := _make_particle_emitter(
		"ImpactDebris", 120, 1.8, _crater_radius * 0.42,
		Vector3(0.0, 1.0, 0.0), 5.5, 11.5,
		Vector3(0.0, -8.5, 0.0), Color(0.2, 0.11, 0.055, 1.0), 0.22
	)
	debris.one_shot = true
	debris.explosiveness = 0.92
	_impact_root.add_child(debris)
	debris.restart()


func _add_body_collider() -> void:
	if _body_root == null or _body_root.get_node_or_null("MeteorStaticBody") != null:
		return
	var static_body := StaticBody3D.new()
	static_body.name = "MeteorStaticBody"
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	static_body.set_meta("meteor_entity", true)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "MeteorCollision"
	var shape := SphereShape3D.new()
	shape.radius = get_landed_collision_radius()
	shape_node.shape = shape
	static_body.add_child(shape_node)
	_body_root.add_child(static_body)


func _make_particle_emitter(
	node_name: String,
	amount: int,
	lifetime: float,
	emission_radius: float,
	direction: Vector3,
	velocity_min: float,
	velocity_max: float,
	gravity: Vector3,
	color: Color,
	particle_radius: float
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	_particle_emitters.append(particles)
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = minf(lifetime, 0.45)
	particles.local_coords = false
	particles.visibility_aabb = AABB(
		Vector3.ONE * -(_body_radius * 4.0),
		Vector3.ONE * (_body_radius * 8.0)
	)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = emission_radius
	process.direction = direction
	process.spread = 48.0
	process.initial_velocity_min = velocity_min
	process.initial_velocity_max = velocity_max
	process.gravity = gravity
	process.scale_min = 0.55
	process.scale_max = 1.55
	process.damping_min = 0.25
	process.damping_max = 0.75
	particles.process_material = process
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = particle_radius
	particle_mesh.height = particle_radius * (2.7 if "Flame" in node_name else 2.0)
	particle_mesh.radial_segments = 10
	particle_mesh.rings = 6
	particle_mesh.material = _glow_material(color, color.a < 0.999, 3.8)
	particles.draw_pass_1 = particle_mesh
	return particles


func _make_crater_mesh(radius: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_radii := [0.0, radius * 0.34, radius * 0.67, radius]
	var ring_heights := [-0.82, -0.7, -0.31, 0.01]
	var segments := 64
	for ring_index in range(ring_radii.size() - 1):
		for segment in range(segments):
			var angle_a := TAU * float(segment) / float(segments)
			var angle_b := TAU * float(segment + 1) / float(segments)
			var p00 := Vector3(cos(angle_a) * ring_radii[ring_index], ring_heights[ring_index], sin(angle_a) * ring_radii[ring_index])
			var p01 := Vector3(cos(angle_b) * ring_radii[ring_index], ring_heights[ring_index], sin(angle_b) * ring_radii[ring_index])
			var p10 := Vector3(cos(angle_a) * ring_radii[ring_index + 1], ring_heights[ring_index + 1], sin(angle_a) * ring_radii[ring_index + 1])
			var p11 := Vector3(cos(angle_b) * ring_radii[ring_index + 1], ring_heights[ring_index + 1], sin(angle_b) * ring_radii[ring_index + 1])
			surface.add_vertex(p00)
			surface.add_vertex(p01)
			surface.add_vertex(p10)
			surface.add_vertex(p10)
			surface.add_vertex(p01)
			surface.add_vertex(p11)
	surface.generate_normals()
	return surface.commit()


func _rock_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.17, 0.082, 0.042, 1.0)
	material.roughness = 0.92
	material.emission_enabled = true
	material.emission = Color(0.13, 0.018, 0.004, 1.0)
	material.emission_energy_multiplier = 0.72
	return material


func _ash_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _register_crater_material(material: StandardMaterial3D) -> StandardMaterial3D:
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_crater_materials.append(material)
	return material


func _glow_material(color: Color, transparent: bool, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = energy
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _tint_meshes(root: Node, material: StandardMaterial3D) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				mesh_instance.set_surface_override_material(surface_index, material)
	for child in root.get_children():
		_tint_meshes(child, material)
