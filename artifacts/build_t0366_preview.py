from pathlib import Path
source=Path('scripts/presentation/MountainArtTrial.gd').read_text(encoding='utf-8')
def method(name):
    a=source.index('func '+name+'('); b=source.find('\nfunc ',a+5)
    return source[a:] if b<0 else source[a:b]
header='''extends Node3D
## Isolated water/bank art on unchanged production river geometry.
const ENVIRONMENT := preload("res://scripts/presentation/environment/FormalGroundSurfaceArtView.gd")
const WATER_SHADER := preload("res://shaders/environment/river_art_trial.gdshader")
const BANK_SHADER := preload("res://shaders/environment/riverbank_art_trial.gdshader")
const OUTPUT := "res://artifacts/visual_qa/t0366"
var _style: Dictionary = {}
var _environment: Node3D
var _terrain: Node3D
var _water: MeshInstance3D
var _water_original: Mesh
var _water_candidate: Mesh
var _water_material := ShaderMaterial.new()
var _bank_material := ShaderMaterial.new()
var _original: Dictionary = {}
var _geometry: Dictionary = {}
var _camera := Camera3D.new()
var _label := Label.new()
var _candidate := true
var _night := false
var _motion := true
var _flow_time := 0.0

func _ready() -> void:
	_style = _read("res://data/presentation/river_art_trial.json")
	assert(_style.get("schema_version", "") == "river_art_trial_v1")
	var layout := _read("res://data/station_layout.json")
	_environment = ENVIRONMENT.new()
	_environment.name = "ReadOnlyEnvironment"
	_environment.configure(_read("res://data/presentation/environment_art.json"), layout)
	add_child(_environment)
	_environment.get_node("StationLifeDetails").hide()
	_terrain = _environment.get_node("FullMapTerrainTopology")
	_water = _terrain.get_node("RiverWaterRibbon")
	_water_original = _water.mesh
	_water_material.shader = WATER_SHADER
	for key in ["deep_color", "shallow_color", "foam_color"]:
		_water_material.set_shader_parameter(key, Color(str(_style.get(key, "#30535a"))))
	for key in ["flow_speed", "ripple_strength"]:
		_water_material.set_shader_parameter(key, float(_style.get(key, 0.2)))
	_bank_material.shader = BANK_SHADER
	var ground := _read("res://data/presentation/ground_art_trial.json")
	for key in ["grass_dark", "grass_light", "soil_dark", "soil_light"]:
		_bank_material.set_shader_parameter(key, Color(str(ground.get(key, "#38452c"))))
	for key in ["wet_color", "gravel_color"]:
		_bank_material.set_shader_parameter(key, Color(str(_style.get(key, "#54584c"))))
	_bank_material.set_shader_parameter("water_height", float(layout.get("terrain", {}).get("river_surface_y", -1.2)))
	for branch in ["TerracedRiverBanks", "RiverbankRockBreakup"]:
		for node: MeshInstance3D in _terrain.get_node(branch).find_children("*", "MeshInstance3D", true, false):
			_original[node] = node.material_override
			_geometry[node] = {"mesh": node.mesh, "vertices": hash(node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]), "transform": node.transform}
	_build_water_uv()
	_camera.name = "ReviewCamera"
	_camera.fov = 48.0
	_camera.far = 1200.0
	add_child(_camera)
	_camera.current = true
	_build_controls()
	set_view("overview")
	set_candidate(true)
	set_night(false)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_verify()
	if "--capture-river-trial" in OS.get_cmdline_user_args():
		call_deferred("_capture")

func _process(delta: float) -> void:
	if _motion:
		_flow_time += delta
	_water_material.set_shader_parameter("flow_time", _flow_time)

func _build_water_uv() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices: PackedVector3Array = _water_original.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var profile: Array = _terrain._profile
	for vertex in vertices:
		var river_sample: Dictionary = profile[0]
		for sample_point: Dictionary in profile:
			if is_equal_approx(float(sample_point.z), vertex.z):
				river_sample = sample_point
				break
		var width := float(river_sample.water_width)
		var center: float = _terrain._water_center(river_sample)
		var cross_stream := (vertex.x-center)/width+0.5
		assert(cross_stream >= -0.0001 and cross_stream <= 1.0001)
		surface.set_uv(Vector2(cross_stream, vertex.z))
		surface.set_uv2(Vector2(width, 0.0))
		surface.set_normal(Vector3.UP)
		surface.add_vertex(vertex)
	_water_candidate = surface.commit()

func set_candidate(enabled: bool) -> void:
	_candidate = enabled
	_water.mesh = _water_candidate if enabled else _water_original
	_water.material_override = _water_material if enabled else null
	_terrain.get_node("SubtleBankFoam").visible = not enabled
	for node: MeshInstance3D in _original:
		node.material_override = _bank_material if enabled else _original[node]
	_label.text = "T0366  河流试验 / " + ("B · 深浅水色、细水纹与湿岸" if enabled else "A · 当前河流")

func _verify() -> Dictionary:
	var original_vertices: PackedVector3Array = _water_original.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(original_vertices == _water_candidate.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	for node: MeshInstance3D in _geometry:
		assert(node.mesh == _geometry[node].mesh and node.transform == _geometry[node].transform)
		assert(hash(node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]) == _geometry[node].vertices)
	assert(get_node_or_null("/root/Main") == null)
	assert(find_children("*", "CollisionObject3D", true, false).is_empty())
	assert(find_children("*", "NavigationRegion3D", true, false).is_empty())
	var forest: Dictionary = _environment.get_node("FullMapDenseForest").get_debug_snapshot()
	assert(forest.total_tree_count == 7393)
	return {"original_water_vertices": original_vertices.size(), "water_positions_unchanged": true, "bank_and_rock_meshes_unchanged": _geometry.size(), "trees": forest.total_tree_count, "collision": false, "navigation": false, "main_created": false, "production_enabled": false}
'''
tail='\n\n'.join(method(n) for n in ['_read','set_view','set_night','_build_controls','_capture'])
tail=tail.replace('Mountain review capture failed:', 'River review capture failed:').replace('T0365_PASS','T0366_PASS')
Path('scripts/presentation/RiverArtTrial.gd').write_text(header+'\n'+tail+'\n',encoding='utf-8',newline='\n')
