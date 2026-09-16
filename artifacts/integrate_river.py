from pathlib import Path
p=Path('scripts/presentation/RiverArtTrial.gd')
s=p.read_text(encoding='utf-8')
header=s[:s.index('func _ready()')]
header=header.replace('## Isolated water/bank art on unchanged production river geometry.','## Approved river appearance shared by production and the independent review.')
header='\n'.join(line for line in header.split('\n') if not line.startswith(('const ENVIRONMENT', 'const OUTPUT', 'var _camera', 'var _label', 'var _night')))
header=header.replace('const WATER_SHADER', 'const CONFIG_PATH := "res://data/presentation/river_art_trial.json"\nconst WATER_SHADER')
setup=s[s.index('\t_terrain = _environment.get_node'):s.index('\t_camera.name')]
setup=setup.replace('float(layout.get("terrain", {}).get("river_surface_y", -1.2))','float(_water.get_meta("water_surface_y", -1.2))')
setup=setup.replace('\t_water_material.shader = WATER_SHADER','\t_water_material.shader = WATER_SHADER\n\t_water_material.set_shader_parameter("environment_origin", _environment.global_position)')
setup=setup.replace('\t_bank_material.shader = BANK_SHADER','\t_bank_material.shader = BANK_SHADER\n\t_bank_material.set_shader_parameter("environment_origin", _environment.global_position)')
body=s[s.index('func _process'):s.index('func set_view')]
body=body.replace('func set_candidate(', 'func set_enabled(')
body='\n'.join(line for line in body.split('\n') if not line.startswith('\t_label.text') and 'assert(get_node_or_null("/root/Main")' not in line)
body=body.replace('func _verify()', 'func verify_geometry_contract()')
body=body.replace('"main_created": false, "production_enabled": false','"enabled": _candidate')
helper=header+'func configure(environment: Node3D, settings: Dictionary) -> void:\n\t_environment = environment\n\t_style = settings.duplicate(true)\n\tassert(_style.get("schema_version", "") == "river_art_trial_v1")\n\tset_meta("presentation_only", true)\n'+setup+'\tset_enabled(true)\n\n'+body
helper+='func get_debug_snapshot() -> Dictionary:\n\treturn {"enabled": _candidate, "waterline_rocks": _footprints.size(), "foam_footprints": _footprints.size(), "bank_and_rock_meshes": _geometry.size(), "flow_time": _flow_time, "authority_role": "presentation_only"}\n'
Path('scripts/presentation/environment/StylizedRiverArt.gd').write_text(helper,encoding='utf-8')
trial='''extends Node3D
## Isolated A/B review using the approved production river implementation.
const ENVIRONMENT := preload("res://scripts/presentation/environment/FormalGroundSurfaceArtView.gd")
const RIVER_ART := preload("res://scripts/presentation/environment/StylizedRiverArt.gd")
const OUTPUT := "res://artifacts/visual_qa/t0366/shared_revision"
var _style: Dictionary = {}
var _environment: Node3D
var _art: Node3D
var _water_material: ShaderMaterial
var _camera := Camera3D.new()
var _label := Label.new()
var _candidate := true
var _night := false
var _motion := true
var _flow_time := 0.0

func _ready() -> void:
	_style = _read(RIVER_ART.CONFIG_PATH)
	var config := _read("res://data/presentation/environment_art.json")
	config["approved_river"] = {"enabled": false}
	_environment = ENVIRONMENT.new()
	_environment.name = "ReadOnlyEnvironment"
	_environment.configure(config, _read("res://data/station_layout.json"))
	add_child(_environment)
	_environment.get_node("StationLifeDetails").hide()
	_art = RIVER_ART.new()
	_art.name = "ReviewStylizedRiver"
	_environment.add_child(_art)
	_art.configure(_environment, _style)
	_art.set_process(false)
	_water_material = _art._water_material
'''
trial+=s[s.index('\t_camera.name'):s.index('func _build_water_uv')]
trial+='''func set_candidate(enabled: bool) -> void:
	_candidate = enabled
	_art.set_enabled(enabled)
	_label.text = "T0366  河流试验 / " + ("B · 纵向流痕、水岸石组与绕石白沫" if enabled else "A · 原版河流")

func _verify() -> Dictionary:
	var snapshot: Dictionary = _art.verify_geometry_contract()
	assert(get_node_or_null("/root/Main") == null)
	snapshot["main_created"] = false
	snapshot["production_enabled"] = false
	return snapshot

'''
trial+=s[s.index('func _read'):]
trial=trial.replace('# Sample the actual unchanged render triangles, never the coarse mountain profile.','')
p.write_text(trial,encoding='utf-8')
p=Path('scripts/presentation/environment/FormalGroundSurfaceArtView.gd');s=p.read_text(encoding='utf-8')
s=s.replace('const STYLIZED_MOUNTAIN_SCRIPT :=', 'const STYLIZED_RIVER_SCRIPT := preload("res://scripts/presentation/environment/StylizedRiverArt.gd")\nconst STYLIZED_MOUNTAIN_SCRIPT :=')
s=s.replace('var _approved_mountain: Node3D','var _approved_mountain: Node3D\nvar _approved_river: Node3D')
s=s.replace('\t\t"approved_mountain":', '\t\t"approved_river": _approved_river.get_debug_snapshot() if is_instance_valid(_approved_river) else {},\n\t\t"approved_mountain":')
s=s.replace('\t_approved_mountain = null','\t_approved_mountain = null\n\t_approved_river = null')
hook='''	if bool((_environment_config.get("approved_river", {}) as Dictionary).get("enabled", false)):
		var river_path := str(_environment_config.approved_river.get("config_path", STYLIZED_RIVER_SCRIPT.CONFIG_PATH))
		var river_settings: Variant = JSON.parse_string(FileAccess.get_file_as_string(river_path))
		if river_settings is Dictionary and river_settings.get("schema_version", "") == "river_art_trial_v1":
			_approved_river = STYLIZED_RIVER_SCRIPT.new()
			_approved_river.name = "ApprovedStylizedRiver"
			add_child(_approved_river)
			_approved_river.configure(self, river_settings)
		else:
			push_error("Approved river configuration is invalid")
'''
s=s.replace('\t_station_detail_view = STATION_DETAIL_VIEW_SCRIPT.new()',hook+'\t_station_detail_view = STATION_DETAIL_VIEW_SCRIPT.new()');p.write_text(s,encoding='utf-8')
p=Path('data/presentation/environment_art.json');s=p.read_text(encoding='utf-8');s=s.replace('{\n','{\n  "approved_river": {"enabled": true, "config_path": "res://data/presentation/river_art_trial.json", "revision": "t0366_approved"},\n',1);p.write_text(s,encoding='utf-8')
p=Path('scripts/presentation/GroundArtTrial.gd');s=p.read_text(encoding='utf-8');s=s.replace('    environment_config["approved_mountain"] = {"enabled": false}', '    environment_config["approved_mountain"] = {"enabled": false}\n    environment_config["approved_river"] = {"enabled": false}');p.write_text(s,encoding='utf-8')
p=Path('shaders/environment/river_art_trial.gdshader');s=p.read_text(encoding='utf-8').replace('varying vec2 water_position;', 'uniform vec3 environment_origin = vec3(0.0);\nvarying vec2 water_position;').replace('(MODEL_MATRIX * vec4(VERTEX, 1)).xz','(MODEL_MATRIX * vec4(VERTEX, 1)).xz - environment_origin.xz');p.write_text(s,encoding='utf-8')
p=Path('docs/TASKS.md');s=p.read_text(encoding='utf-8');start=s.index('### T0367');end=s.index('### T0366-I',start);s=s[:start]+s[end:];s=s.replace('### T0367 已认可样片的风格统一与整合评审（条目见上）','### T0367 已认可样片的风格统一与整合评审');p.write_text(s,encoding='utf-8')
