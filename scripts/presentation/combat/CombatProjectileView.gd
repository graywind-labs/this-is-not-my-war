extends Node3D

const ARROW_LENGTH := 0.82
const BOLT_LENGTH := 0.58

var _projectile_length := ARROW_LENGTH


func configure(projectile_id: String, weapon_type: String) -> void:
	name = _make_node_name(projectile_id)
	set_meta("projectile_id", projectile_id)
	set_meta("weapon_type", weapon_type)
	set_meta("presentation_only", true)
	set_meta("damage_authority", "combat_system_swept_collision")
	_build_projectile(weapon_type)


func project(position: Vector3, velocity: Vector3) -> void:
	global_position = position
	if velocity.length_squared() <= 0.000001:
		return
	var forward := velocity.normalized()
	var right := forward.cross(Vector3.UP)
	if right.length_squared() <= 0.000001:
		right = Vector3.RIGHT
	right = right.normalized()
	var depth := right.cross(forward).normalized()
	global_basis = Basis(right, forward, depth)


func stick_at(position: Vector3, incoming_velocity: Vector3, surface_normal: Vector3 = Vector3.ZERO) -> void:
	var direction := incoming_velocity.normalized()
	if direction.length_squared() <= 0.000001:
		direction = -surface_normal.normalized()
	if direction.length_squared() <= 0.000001:
		direction = Vector3.DOWN
	project(position, direction)
	# The Node3D origin is the shaft centre. Keep the metal tip slightly inside
	# the actual swept-collision point instead of leaving half the arrow beyond it.
	var tip_distance := _projectile_length * 0.5 + 0.13
	global_position = position - direction * maxf(0.0, tip_distance - 0.035)
	set_meta("projectile_state", "stuck")
	set_meta("collision_position", position)
	set_meta("incoming_direction", direction)
	set_meta("surface_normal", surface_normal)


func _build_projectile(weapon_type: String) -> void:
	var is_bolt := weapon_type == "crossbow"
	var length := BOLT_LENGTH if is_bolt else ARROW_LENGTH
	_projectile_length = length
	var shaft_material := StandardMaterial3D.new()
	shaft_material.albedo_color = Color(0.34, 0.16, 0.055, 1.0) if not is_bolt else Color(0.44, 0.22, 0.07, 1.0)
	shaft_material.roughness = 0.88
	var iron_material := StandardMaterial3D.new()
	iron_material.albedo_color = Color(0.25, 0.27, 0.27, 1.0)
	iron_material.metallic = 0.42
	iron_material.roughness = 0.52
	var fletching_material := StandardMaterial3D.new()
	fletching_material.albedo_color = Color(0.55, 0.13, 0.08, 1.0)
	fletching_material.roughness = 0.9

	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.014
	shaft_mesh.bottom_radius = 0.014
	shaft_mesh.height = length
	shaft_mesh.radial_segments = 6
	shaft_mesh.material = shaft_material
	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	shaft.mesh = shaft_mesh
	add_child(shaft)

	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 0.038 if is_bolt else 0.045
	head_mesh.height = 0.13
	head_mesh.radial_segments = 5
	head_mesh.material = iron_material
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = head_mesh
	head.position.y = length * 0.5 + 0.065
	add_child(head)

	for side in [-1.0, 1.0]:
		var feather_mesh := BoxMesh.new()
		feather_mesh.size = Vector3(0.09, 0.15, 0.012)
		feather_mesh.material = fletching_material
		var feather := MeshInstance3D.new()
		feather.name = "FletchingLeft" if side < 0.0 else "FletchingRight"
		feather.mesh = feather_mesh
		feather.position = Vector3(0.025 * side, -length * 0.38, 0.0)
		feather.rotation_degrees.y = 34.0 * side
		add_child(feather)


func _make_node_name(value: String) -> String:
	var result := ""
	for part in value.split("_", false):
		if part.is_empty():
			continue
		result += part.substr(0, 1).to_upper() + part.substr(1)
	return result if not result.is_empty() else "CombatProjectile"
