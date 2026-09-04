class_name BuildingArtView
extends Node3D


const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const MAIN_CAMERA_FADING_SHELL_VISUAL_LAYER := 19
const PORTRAIT_OPAQUE_SHELL_VISUAL_LAYER := 18

@export var building_id := "art_sample"
@export var roof_path: NodePath = NodePath("Roof")
@export var exterior_path: NodePath = NodePath("Exterior")
@export var interior_path: NodePath = NodePath("Interior")
@export var static_collision_path: NodePath = NodePath("StaticCollision")
@export var click_area_path: NodePath = NodePath("ClickArea")
@export var interior_trigger_path: NodePath = NodePath("InteriorTrigger")
@export var entry_marker_path: NodePath = NodePath("EntryMarker")
@export var exit_marker_path: NodePath = NodePath("ExitMarker")
@export var door_inside_marker_path: NodePath = NodePath("DoorInsideMarker")
@export var interior_standing_marker_path: NodePath = NodePath("Interior/InteriorStandingMarker")
@export var workstation_markers_path: NodePath = NodePath("Interior/WorkstationMarkers")
@export var roof_near_distance := 21.0
@export var roof_far_distance := 30.0
@export_range(0.0, 1.0, 0.01) var minimum_roof_opacity := 0.08
# Retained for scene compatibility. Since T0135-P7R, shell shadows are
# persistent and no longer gated by this opacity value.
@export_range(0.0, 1.0, 0.01) var shadow_enable_opacity := 0.98
@export var roof_albedo_override := Color(0.29, 0.36, 0.5, 1.0)
@export var preserve_roof_albedo_texture := false
@export var exterior_albedo_tint := Color(0.72, 0.78, 0.92, 1.0)
@export var fade_exterior_with_roof := false
@export_range(0.0, 1.0, 0.01) var minimum_exterior_opacity := 0.08
@export_range(0.0, 1.0, 0.01) var interior_reveal_opacity_threshold := 0.72
@export var additional_roof_fade_paths: Array[NodePath] = []
@export var additional_exterior_fade_paths: Array[NodePath] = []
@export var interaction_bounds_center := Vector3.ZERO
@export var interaction_bounds_size := Vector3.ZERO

var _roof_meshes: Array[MeshInstance3D] = []
var _roof_materials: Array[BaseMaterial3D] = []
var _roof_shadow_proxies: Array[MeshInstance3D] = []
var _exterior_meshes: Array[MeshInstance3D] = []
var _exterior_materials: Array[BaseMaterial3D] = []
var _exterior_shadow_proxies: Array[MeshInstance3D] = []
var _persistent_shadow_proxy_by_source: Dictionary = {}
var _portrait_opaque_shell_proxies: Array[MeshInstance3D] = []
var _portrait_opaque_shell_materials: Array[BaseMaterial3D] = []
var _portrait_opaque_proxy_by_source: Dictionary = {}
var _roof_opacity := 1.0
var _exterior_opacity := 1.0
var _camera_distance := -1.0
var _zoom_normalized := 0.0
var _building_level := 1
var _upgrade_in_progress := false


func _ready() -> void:
	add_to_group("building_art_view")
	_cache_roof_materials()
	_cache_exterior_materials()
	_register_with_controller()
	_bind_click_area()
	_configure_navigation_region()
	_bind_building_state()
	call_deferred("_refresh_building_state")


func _exit_tree() -> void:
	for controller in get_tree().get_nodes_in_group("roof_visibility_controller"):
		if controller.has_method("unregister_view"):
			controller.call("unregister_view", self)


func apply_roof_camera_distance(camera_distance: float, zoom_normalized: float) -> void:
	_camera_distance = camera_distance
	_zoom_normalized = zoom_normalized
	var distance_t := clampf(
		inverse_lerp(roof_near_distance, roof_far_distance, camera_distance),
		0.0,
		1.0
	)
	var smooth_t := distance_t * distance_t * (3.0 - 2.0 * distance_t)
	var roof_opacity := lerpf(minimum_roof_opacity, 1.0, smooth_t)
	_set_roof_opacity(roof_opacity)
	if fade_exterior_with_roof:
		_set_exterior_opacity(lerpf(minimum_exterior_opacity, 1.0, smooth_t))


func get_roof_visibility_snapshot() -> Dictionary:
	return {
		"building_id": building_id,
		"camera_distance": _camera_distance,
		"zoom_normalized": _zoom_normalized,
		"roof_near_distance": roof_near_distance,
		"roof_far_distance": roof_far_distance,
		"minimum_roof_opacity": minimum_roof_opacity,
		"roof_opacity": _roof_opacity,
		"exterior_opacity": _exterior_opacity,
		"exterior_fades_with_roof": fade_exterior_with_roof,
		"minimum_exterior_opacity": minimum_exterior_opacity,
		"interior_revealed_for_selection": is_interior_revealed_for_selection(),
		"roof_shadow_enabled": _persistent_shadows_ready(_roof_shadow_proxies),
		"exterior_shadow_enabled": not fade_exterior_with_roof or _persistent_shadows_ready(_exterior_shadow_proxies),
		"roof_shadow_proxy_count": _roof_shadow_proxies.size(),
		"exterior_shadow_proxy_count": _exterior_shadow_proxies.size(),
		"portrait_opaque_shell_proxy_count": _portrait_opaque_shell_proxies.size(),
		"portrait_opaque_shell_material_count": _portrait_opaque_shell_materials.size(),
		"portrait_opaque_shells_ready": _portrait_opaque_shells_ready(),
		"fading_shell_layers_ready": _fading_shell_layers_ready(),
		"main_camera_fading_shell_visual_layer": MAIN_CAMERA_FADING_SHELL_VISUAL_LAYER,
		"portrait_opaque_shell_visual_layer": PORTRAIT_OPAQUE_SHELL_VISUAL_LAYER,
		"visible_shell_meshes_cast_shadow": _visible_shell_meshes_cast_shadow(),
		"roof_mesh_count": _roof_meshes.size(),
		"exterior_mesh_count": _exterior_meshes.size(),
		"building_level": _building_level,
		"level_2_visible": _is_visible(NodePath("UpgradeVisuals/Level2")),
		"level_3_visible": _is_visible(NodePath("UpgradeVisuals/Level3")),
		"exterior_visible": _is_visible(exterior_path),
		"interior_visible": _is_visible(interior_path),
		"static_collision_enabled": _has_enabled_collision(static_collision_path),
		"click_area_enabled": _has_enabled_collision(click_area_path),
		"interior_trigger_enabled": _has_enabled_collision(interior_trigger_path)
	}


func is_interior_revealed_for_selection() -> bool:
	return fade_exterior_with_roof and maxf(_roof_opacity, _exterior_opacity) <= interior_reveal_opacity_threshold


func get_building_interaction_ray_hit(ray_origin: Vector3, ray_end: Vector3) -> Dictionary:
	if interaction_bounds_size.x <= 0.0 or interaction_bounds_size.y <= 0.0 or interaction_bounds_size.z <= 0.0:
		return {}
	var local_origin := to_local(ray_origin)
	var local_end := to_local(ray_end)
	var bounds := AABB(interaction_bounds_center - interaction_bounds_size * 0.5, interaction_bounds_size)
	var local_hit: Variant = bounds.intersects_segment(local_origin, local_end)
	if local_hit == null:
		return {}
	var global_hit := to_global(local_hit as Vector3)
	return {
		"building_id": building_id,
		"distance": ray_origin.distance_to(global_hit),
		"global_position": global_hit,
		"interior_revealed": is_interior_revealed_for_selection()
	}


func get_world_feedback_anchor_position() -> Vector3:
	var local_anchor := Vector3(
		interaction_bounds_center.x,
		interaction_bounds_center.y + interaction_bounds_size.y * 0.5 + 0.55,
		interaction_bounds_center.z
	)
	return to_global(local_anchor)


func get_art_slice_snapshot() -> Dictionary:
	var ambient_fx := get_node_or_null("Interior/Furniture/ForgeCore/AmbientFX")
	var ambient_snapshot: Dictionary = {}
	if ambient_fx != null and ambient_fx.has_method("debug_get_snapshot"):
		ambient_snapshot = ambient_fx.debug_get_snapshot()
	var marker_states := {}
	var marker_root := get_node_or_null(workstation_markers_path)
	if marker_root != null:
		for raw_marker in marker_root.get_children():
			if not raw_marker is Marker3D:
				continue
			var marker := raw_marker as Marker3D
			marker_states[str(marker.name)] = {
				"required_level": int(marker.get_meta("required_level", 1)),
				"available": int(marker.get_meta("required_level", 1)) <= _building_level,
				"global_position": marker.global_position
			}
	return {
		"building_id": building_id,
		"building_level": _building_level,
		"upgrade_in_progress": _upgrade_in_progress,
		"level_2_visible": _is_visible(NodePath("UpgradeVisuals/Level2")),
		"level_3_visible": _is_visible(NodePath("UpgradeVisuals/Level3")),
		"workstations": marker_states,
		"ambient_fx": ambient_snapshot,
		"navigation_ready": _is_navigation_ready(),
		"roof_profile": "low_pitch_cold_slate",
		"roof_scale": _get_node_scale(NodePath("Roof/RoundTileRoof")),
		"roof_albedo_override": roof_albedo_override,
		"exterior_material_count": _exterior_materials.size(),
		"chimney_clearance_ready": _is_chimney_clearance_ready(),
		"chimney_forge_aligned": _is_chimney_forge_aligned(),
		"authority_role": "presentation_only"
	}


func debug_force_visual_level(level: int) -> Dictionary:
	_apply_visual_level(clampi(level, 1, 3), false)
	return get_art_slice_snapshot()


func get_interior_route_snapshot(workstation_id: String = "") -> Dictionary:
	var entry_marker := get_node_or_null(entry_marker_path) as Marker3D
	var exit_marker := get_node_or_null(exit_marker_path) as Marker3D
	var door_inside_marker := get_node_or_null(door_inside_marker_path) as Marker3D
	var interior_target := _get_workstation_marker(workstation_id)
	if interior_target == null:
		interior_target = get_node_or_null(interior_standing_marker_path) as Marker3D
	if entry_marker == null or exit_marker == null or door_inside_marker == null or interior_target == null:
		return {}
	return {
		"building_id": building_id,
		"workstation_id": workstation_id,
		"entry_outside_position": entry_marker.global_position,
		"exit_outside_position": exit_marker.global_position,
		"door_inside_position": door_inside_marker.global_position,
		"interior_target_position": interior_target.global_position,
		"interior_target_facing_direction": -interior_target.global_basis.z.normalized()
	}


func _cache_roof_materials() -> void:
	var fade_roots: Array[Node] = []
	var roof_root := get_node_or_null(roof_path)
	if roof_root != null:
		fade_roots.append(roof_root)
	for path in additional_roof_fade_paths:
		var extra_root := get_node_or_null(path)
		if extra_root != null and not fade_roots.has(extra_root):
			fade_roots.append(extra_root)
	for fade_root in fade_roots:
		if fade_root is MeshInstance3D:
			_cache_roof_mesh(fade_root as MeshInstance3D)
		for raw_mesh in fade_root.find_children("*", "MeshInstance3D", true, false):
			_cache_roof_mesh(raw_mesh as MeshInstance3D)


func _cache_roof_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null or mesh_instance.mesh == null or bool(mesh_instance.get_meta("persistent_shell_shadow_proxy", false)) or bool(mesh_instance.get_meta("portrait_opaque_shell_proxy", false)) or _roof_meshes.has(mesh_instance):
		return
	_roof_meshes.append(mesh_instance)
	var shadow_proxy := _ensure_persistent_shadow_proxy(mesh_instance, "roof")
	if shadow_proxy != null and not _roof_shadow_proxies.has(shadow_proxy):
		_roof_shadow_proxies.append(shadow_proxy)
	if mesh_instance.material_override is BaseMaterial3D:
		var override_copy := (mesh_instance.material_override as BaseMaterial3D).duplicate() as BaseMaterial3D
		override_copy.resource_local_to_scene = true
		override_copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		override_copy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if preserve_roof_albedo_texture:
			var override_source_color := override_copy.albedo_color
			override_copy.albedo_color = Color(
				override_source_color.r * roof_albedo_override.r,
				override_source_color.g * roof_albedo_override.g,
				override_source_color.b * roof_albedo_override.b,
				override_source_color.a
			)
		else:
			override_copy.albedo_texture = null
			override_copy.albedo_color = Color(
				roof_albedo_override.r,
				roof_albedo_override.g,
				roof_albedo_override.b,
				(mesh_instance.material_override as BaseMaterial3D).albedo_color.a
			)
		mesh_instance.material_override = override_copy
		_roof_materials.append(override_copy)
		if minimum_roof_opacity < 0.999:
			_ensure_portrait_opaque_shell_proxy(mesh_instance, "roof")
		return
	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		var source_material := mesh_instance.get_active_material(surface_index)
		if not source_material is BaseMaterial3D:
			continue
		var material_copy := source_material.duplicate() as BaseMaterial3D
		material_copy.resource_local_to_scene = true
		material_copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		material_copy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if preserve_roof_albedo_texture:
			var source_color := material_copy.albedo_color
			material_copy.albedo_color = Color(
				source_color.r * roof_albedo_override.r,
				source_color.g * roof_albedo_override.g,
				source_color.b * roof_albedo_override.b,
				roof_albedo_override.a
			)
		else:
			material_copy.albedo_texture = null
			material_copy.albedo_color = roof_albedo_override
		mesh_instance.set_surface_override_material(surface_index, material_copy)
		_roof_materials.append(material_copy)
	if minimum_roof_opacity < 0.999:
		_ensure_portrait_opaque_shell_proxy(mesh_instance, "roof")


func _cache_exterior_materials() -> void:
	var fade_roots: Array[Node] = []
	var exterior_root := get_node_or_null(exterior_path)
	if exterior_root != null:
		fade_roots.append(exterior_root)
	for path in additional_exterior_fade_paths:
		var extra_root := get_node_or_null(path)
		if extra_root != null and not fade_roots.has(extra_root):
			fade_roots.append(extra_root)
	for fade_root in fade_roots:
		if fade_root is MeshInstance3D and not bool(fade_root.get_meta("persistent_shell_shadow_proxy", false)) and not bool(fade_root.get_meta("portrait_opaque_shell_proxy", false)) and not _exterior_meshes.has(fade_root as MeshInstance3D):
			_exterior_meshes.append(fade_root as MeshInstance3D)
		for raw_mesh in fade_root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := raw_mesh as MeshInstance3D
			if mesh_instance != null and not bool(mesh_instance.get_meta("persistent_shell_shadow_proxy", false)) and not bool(mesh_instance.get_meta("portrait_opaque_shell_proxy", false)) and not _exterior_meshes.has(mesh_instance):
				_exterior_meshes.append(mesh_instance)
	for mesh_instance in _exterior_meshes:
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var shadow_proxy := _ensure_persistent_shadow_proxy(mesh_instance, "exterior")
		if shadow_proxy != null and not _exterior_shadow_proxies.has(shadow_proxy):
			_exterior_shadow_proxies.append(shadow_proxy)
		if mesh_instance.material_override is BaseMaterial3D:
			var override_copy := (mesh_instance.material_override as BaseMaterial3D).duplicate() as BaseMaterial3D
			override_copy.resource_local_to_scene = true
			if fade_exterior_with_roof:
				override_copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			var override_source_color := override_copy.albedo_color
			override_copy.albedo_color = Color(
				override_source_color.r * exterior_albedo_tint.r,
				override_source_color.g * exterior_albedo_tint.g,
				override_source_color.b * exterior_albedo_tint.b,
				override_source_color.a
			)
			override_copy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mesh_instance.material_override = override_copy
			_exterior_materials.append(override_copy)
			if fade_exterior_with_roof and minimum_exterior_opacity < 0.999:
				_ensure_portrait_opaque_shell_proxy(mesh_instance, "exterior")
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.get_active_material(surface_index)
			if not source_material is BaseMaterial3D:
				continue
			var material_copy := source_material.duplicate() as BaseMaterial3D
			material_copy.resource_local_to_scene = true
			if fade_exterior_with_roof:
				material_copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			var source_color := material_copy.albedo_color
			material_copy.albedo_color = Color(
				source_color.r * exterior_albedo_tint.r,
				source_color.g * exterior_albedo_tint.g,
				source_color.b * exterior_albedo_tint.b,
				source_color.a
			)
			material_copy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mesh_instance.set_surface_override_material(surface_index, material_copy)
			_exterior_materials.append(material_copy)
		if fade_exterior_with_roof and minimum_exterior_opacity < 0.999:
			_ensure_portrait_opaque_shell_proxy(mesh_instance, "exterior")


func _get_node_scale(path: NodePath) -> Vector3:
	var node := get_node_or_null(path) as Node3D
	return node.scale if node != null else Vector3.ZERO


func _is_chimney_clearance_ready() -> bool:
	var chimney := get_node_or_null("UpgradeVisuals/Level2/StoneChimney") as Node3D
	var roof_model := get_node_or_null("Roof/RoundTileRoof") as Node3D
	return chimney != null and roof_model != null and chimney.position.y >= 1.5 and roof_model.scale.y <= 0.5


func _is_chimney_forge_aligned() -> bool:
	var chimney := get_node_or_null("UpgradeVisuals/Level2/StoneChimney") as Node3D
	if chimney == null:
		return false
	var chimney_plan := Vector2(chimney.position.x, chimney.position.z)
	var forge_plan := Vector2(-0.75, -1.48)
	return chimney_plan.distance_to(forge_plan) <= 0.2


func _register_with_controller() -> void:
	var controllers := get_tree().get_nodes_in_group("roof_visibility_controller")
	if not controllers.is_empty() and controllers[0].has_method("register_view"):
		controllers[0].call("register_view", self)


func _bind_click_area() -> void:
	var click_area := get_node_or_null(click_area_path) as Area3D
	if click_area == null:
		return
	click_area.input_ray_pickable = true
	click_area.set_meta("building_id", building_id)


func _configure_navigation_region() -> void:
	var navigation_region := get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	if navigation_region == null:
		return
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.agent_radius = 0.35
	navigation_mesh.agent_height = 1.8
	navigation_mesh.vertices = PackedVector3Array([
		Vector3(-1.72, 0.08, -1.72),
		Vector3(1.72, 0.08, -1.72),
		Vector3(1.72, 0.08, 1.72),
		Vector3(-1.72, 0.08, 1.72),
		Vector3(-1.28, 0.08, 2.58),
		Vector3(-0.72, 0.08, 2.58)
	])
	navigation_mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	navigation_mesh.add_polygon(PackedInt32Array([3, 2, 5, 4]))
	navigation_region.navigation_mesh = navigation_mesh
	navigation_region.enabled = true


func _is_navigation_ready() -> bool:
	var navigation_region := get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	return (
		navigation_region != null
		and navigation_region.enabled
		and navigation_region.navigation_mesh != null
		and navigation_region.navigation_mesh.get_polygon_count() >= 2
	)


func _get_workstation_marker(workstation_id: String) -> Marker3D:
	if workstation_id.is_empty():
		return null
	var marker_root := get_node_or_null(workstation_markers_path)
	if marker_root == null:
		return null
	var marker := marker_root.get_node_or_null(NodePath(workstation_id)) as Marker3D
	if marker != null and int(marker.get_meta("required_level", 1)) > _building_level:
		return null
	return marker


func _bind_building_state() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if (
		event_bus != null
		and event_bus.has_signal("building_state_changed")
		and not event_bus.building_state_changed.is_connected(_on_building_state_changed)
	):
		event_bus.building_state_changed.connect(_on_building_state_changed)


func _on_building_state_changed(changed_building_id: String) -> void:
	if changed_building_id == building_id:
		_refresh_building_state()


func _refresh_building_state() -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building"):
		_apply_visual_level(_building_level, false)
		return
	var building: Dictionary = building_system.get_building(building_id)
	if building.is_empty():
		_apply_visual_level(_building_level, false)
		return
	_apply_visual_level(
		int(building.get("level", 1)),
		not (building.get("upgrade_status", {}) as Dictionary).is_empty()
	)


func _apply_visual_level(level: int, upgrade_in_progress: bool) -> void:
	_building_level = clampi(level, 1, 3)
	_upgrade_in_progress = upgrade_in_progress
	var level_2 := get_node_or_null("UpgradeVisuals/Level2") as Node3D
	var level_3 := get_node_or_null("UpgradeVisuals/Level3") as Node3D
	if level_2 != null:
		level_2.visible = _building_level >= 2
	if level_3 != null:
		level_3.visible = _building_level >= 3


func _set_roof_opacity(value: float) -> void:
	_roof_opacity = clampf(value, minimum_roof_opacity, 1.0)
	for material in _roof_materials:
		var color := material.albedo_color
		color.a = _roof_opacity
		material.albedo_color = color
	for mesh_instance in _roof_meshes:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for shadow_proxy in _roof_shadow_proxies:
		shadow_proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


func _set_exterior_opacity(value: float) -> void:
	_exterior_opacity = clampf(value, minimum_exterior_opacity, 1.0)
	for material in _exterior_materials:
		var color := material.albedo_color
		color.a = _exterior_opacity
		material.albedo_color = color
	for mesh_instance in _exterior_meshes:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for shadow_proxy in _exterior_shadow_proxies:
		shadow_proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


func _ensure_portrait_opaque_shell_proxy(source: MeshInstance3D, category: String) -> MeshInstance3D:
	var source_id := source.get_instance_id()
	if _portrait_opaque_proxy_by_source.has(source_id):
		var existing := _portrait_opaque_proxy_by_source[source_id] as MeshInstance3D
		if is_instance_valid(existing):
			var categories := existing.get_meta("portrait_shell_categories", []) as Array
			if not categories.has(category):
				categories.append(category)
				existing.set_meta("portrait_shell_categories", categories)
			return existing
	var proxy := MeshInstance3D.new()
	proxy.name = "PortraitOpaqueShell"
	proxy.mesh = source.mesh
	proxy.layers = 1 << (PORTRAIT_OPAQUE_SHELL_VISUAL_LAYER - 1)
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	proxy.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	proxy.process_mode = Node.PROCESS_MODE_DISABLED
	if source.material_override != null:
		proxy.material_override = _duplicate_opaque_portrait_material(source.material_override)
	else:
		for surface_index in range(source.mesh.get_surface_count()):
			var source_material := source.get_active_material(surface_index)
			if source_material != null:
				proxy.set_surface_override_material(
					surface_index,
					_duplicate_opaque_portrait_material(source_material)
				)
	proxy.set_meta("presentation_only", true)
	proxy.set_meta("portrait_opaque_shell_proxy", true)
	proxy.set_meta("portrait_shell_source", str(source.get_path()))
	proxy.set_meta("portrait_shell_categories", [category])
	# The source and proxy inherit the same authored transform and visibility.
	# Separate visual layers let each camera render its own material state without
	# duplicating building gameplay nodes or changing the shared World3D.
	source.add_child(proxy, false, Node.INTERNAL_MODE_FRONT)
	source.layers = 1 << (MAIN_CAMERA_FADING_SHELL_VISUAL_LAYER - 1)
	_portrait_opaque_shell_proxies.append(proxy)
	_portrait_opaque_proxy_by_source[source_id] = proxy
	return proxy


func _duplicate_opaque_portrait_material(source_material: Material) -> Material:
	var material_copy := source_material.duplicate() as Material
	material_copy.resource_local_to_scene = true
	if material_copy is BaseMaterial3D:
		var base_material := material_copy as BaseMaterial3D
		var color := base_material.albedo_color
		color.a = 1.0
		base_material.albedo_color = color
		base_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		_portrait_opaque_shell_materials.append(base_material)
	return material_copy


func _ensure_persistent_shadow_proxy(source: MeshInstance3D, category: String) -> MeshInstance3D:
	var source_id := source.get_instance_id()
	if _persistent_shadow_proxy_by_source.has(source_id):
		var existing := _persistent_shadow_proxy_by_source[source_id] as MeshInstance3D
		if is_instance_valid(existing):
			var categories := existing.get_meta("shell_shadow_categories", []) as Array
			if not categories.has(category):
				categories.append(category)
				existing.set_meta("shell_shadow_categories", categories)
			return existing
	var proxy := MeshInstance3D.new()
	proxy.name = "PersistentShellShadowCaster"
	proxy.mesh = source.mesh
	proxy.layers = source.layers
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	proxy.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	proxy.process_mode = Node.PROCESS_MODE_DISABLED
	if source.material_override != null:
		proxy.material_override = source.material_override
	for surface_index in range(source.mesh.get_surface_count()):
		var surface_override := source.get_surface_override_material(surface_index)
		if surface_override != null:
			proxy.set_surface_override_material(surface_index, surface_override)
	proxy.set_meta("presentation_only", true)
	proxy.set_meta("persistent_shell_shadow_proxy", true)
	proxy.set_meta("shell_shadow_source", str(source.get_path()))
	proxy.set_meta("shell_shadow_categories", [category])
	# Keep the renderer-only duplicate internal: it must inherit the source
	# transform/visibility (including animated doors and upgrade parents) without
	# becoming a second authored mesh in scene traversal, counts, or interaction.
	source.add_child(proxy, false, Node.INTERNAL_MODE_FRONT)
	source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_persistent_shadow_proxy_by_source[source_id] = proxy
	return proxy


func _persistent_shadows_ready(proxies: Array[MeshInstance3D]) -> bool:
	if proxies.is_empty():
		return false
	for proxy in proxies:
		if not is_instance_valid(proxy) or proxy.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			return false
	return true


func _visible_shell_meshes_cast_shadow() -> bool:
	for mesh_instance in _roof_meshes:
		if is_instance_valid(mesh_instance) and mesh_instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return true
	for mesh_instance in _exterior_meshes:
		if is_instance_valid(mesh_instance) and mesh_instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return true
	return false


func _portrait_opaque_shells_ready() -> bool:
	for proxy in _portrait_opaque_shell_proxies:
		if (
			not is_instance_valid(proxy)
			or proxy.layers != 1 << (PORTRAIT_OPAQUE_SHELL_VISUAL_LAYER - 1)
			or proxy.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		):
			return false
	for material in _portrait_opaque_shell_materials:
		if (
			not is_instance_valid(material)
			or not is_equal_approx(material.albedo_color.a, 1.0)
			or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		):
			return false
	return true


func _fading_shell_layers_ready() -> bool:
	if minimum_roof_opacity < 0.999:
		for mesh_instance in _roof_meshes:
			if is_instance_valid(mesh_instance) and mesh_instance.layers != 1 << (MAIN_CAMERA_FADING_SHELL_VISUAL_LAYER - 1):
				return false
	if fade_exterior_with_roof and minimum_exterior_opacity < 0.999:
		for mesh_instance in _exterior_meshes:
			if is_instance_valid(mesh_instance) and mesh_instance.layers != 1 << (MAIN_CAMERA_FADING_SHELL_VISUAL_LAYER - 1):
				return false
	return true


func _add_gable_wall(
	parent: Node3D,
	node_name: String,
	center: Vector3,
	size: Vector3,
	material: Material,
	rotation_y_degrees: float = 0.0
) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	mesh.left_to_right = 0.5
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = center
	instance.rotation_degrees.y = rotation_y_degrees
	instance.mesh = mesh
	instance.set_meta("sealed_gable_wall", true)
	instance.set_meta("presentation_only", true)
	parent.add_child(instance)
	return instance


func _count_authored_meshes_at(path: NodePath) -> int:
	var root_node := get_node_or_null(path)
	if root_node == null:
		return 0
	var count := 0
	if (
		root_node is MeshInstance3D
		and not bool(root_node.get_meta("persistent_shell_shadow_proxy", false))
		and not bool(root_node.get_meta("portrait_opaque_shell_proxy", false))
	):
		count += 1
	for raw_mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		if (
			not bool(raw_mesh.get_meta("persistent_shell_shadow_proxy", false))
			and not bool(raw_mesh.get_meta("portrait_opaque_shell_proxy", false))
		):
			count += 1
	return count


func _is_visible(path: NodePath) -> bool:
	var node := get_node_or_null(path)
	return node is Node3D and (node as Node3D).visible


func _has_enabled_collision(path: NodePath) -> bool:
	var node := get_node_or_null(path)
	if node == null:
		return false
	for raw_shape in node.find_children("*", "CollisionShape3D", true, false):
		var shape := raw_shape as CollisionShape3D
		if not shape.disabled and shape.shape != null:
			return true
	return false
