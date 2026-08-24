extends Node3D

const EXPECTED_SCHEMA := "environment_art_v1"
const ART_REVISION := "t0135_p1r2"

var _environment_config: Dictionary = {}
var _layout: Dictionary = {}
var _asset_scene_cache: Dictionary = {}
var _missing_assets: Array[String] = []
var _cluster_count := 0
var _prop_count := 0


func configure(environment_config: Dictionary, station_layout: Dictionary) -> void:
	_environment_config = environment_config.duplicate(true)
	_layout = station_layout.duplicate(true)
	if is_inside_tree():
		_rebuild()


func _ready() -> void:
	_rebuild()


func get_debug_snapshot() -> Dictionary:
	return {
		"art_revision": ART_REVISION,
		"cluster_count": _cluster_count,
		"prop_count": _prop_count,
		"missing_assets": _missing_assets.duplicate(),
		"has_collision": find_children("*", "CollisionShape3D", true, false).size() > 0,
		"has_static_body": find_children("*", "StaticBody3D", true, false).size() > 0,
		"has_navigation_region": find_children("*", "NavigationRegion3D", true, false).size() > 0,
		"has_interaction_area": find_children("*", "Area3D", true, false).size() > 0,
		"authority_role": "presentation_only"
	}


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_asset_scene_cache.clear()
	_missing_assets.clear()
	_cluster_count = 0
	_prop_count = 0
	if str(_environment_config.get("schema_version", "")) != EXPECTED_SCHEMA:
		return
	var details := _environment_config.get("station_details", {}) as Dictionary
	var catalog := details.get("asset_catalog", {}) as Dictionary
	for raw_cluster in details.get("clusters", []):
		var cluster := raw_cluster as Dictionary
		var building := _find_building(str(cluster.get("building_id", "")))
		if building.is_empty():
			continue
		var cluster_root := Node3D.new()
		cluster_root.name = "StationDetail_%s" % str(cluster.get("id", "cluster"))
		var center := _v2(building.get("center", [0.0, 0.0]))
		cluster_root.position = Vector3(center.x, 0.02, center.y)
		cluster_root.rotation_degrees.y = float(building.get("rotation_degrees", 0.0))
		cluster_root.set_meta("functional_cluster", str(cluster.get("function", "station_life")))
		cluster_root.set_meta("building_id", str(building.get("id", "")))
		cluster_root.set_meta("presentation_only", true)
		add_child(cluster_root)
		_cluster_count += 1
		for raw_item in cluster.get("items", []):
			var item := raw_item as Dictionary
			var asset_key := str(item.get("asset", ""))
			var asset_path := str(catalog.get(asset_key, ""))
			var instance := _instantiate_prop(asset_path)
			if instance == null:
				continue
			instance.name = "%s_%02d" % [asset_key.to_pascal_case(), _prop_count + 1]
			var local_position := _v2(item.get("position", [0.0, 0.0]))
			instance.position = Vector3(local_position.x, float(item.get("height", 0.0)), local_position.y)
			instance.rotation_degrees.y = float(item.get("rotation_degrees", 0.0))
			var scale_value := float(item.get("scale", 1.0))
			instance.scale = Vector3(scale_value, scale_value, scale_value)
			instance.set_meta("detail_function", str(cluster.get("function", "station_life")))
			cluster_root.add_child(instance)
			_prop_count += 1
	set_meta("art_revision", ART_REVISION)
	set_meta("presentation_only", true)


func _instantiate_prop(asset_path: String) -> Node3D:
	if asset_path.is_empty():
		return null
	var packed := _asset_scene_cache.get(asset_path) as PackedScene
	if packed == null:
		packed = load(asset_path) as PackedScene
		if packed == null:
			if not _missing_assets.has(asset_path):
				_missing_assets.append(asset_path)
			return null
		_asset_scene_cache[asset_path] = packed
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return null
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	instance.set_meta("source_asset", asset_path)
	instance.set_meta("presentation_only", true)
	for body in instance.find_children("*", "CollisionObject3D", true, false):
		var body_parent := body.get_parent()
		if body_parent != null:
			body_parent.remove_child(body)
		body.queue_free()
	for mesh in instance.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return instance


func _find_building(building_id: String) -> Dictionary:
	for raw_building in _layout.get("buildings", []):
		var building := raw_building as Dictionary
		if str(building.get("id", "")) == building_id:
			return building
	return {}


func _v2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
