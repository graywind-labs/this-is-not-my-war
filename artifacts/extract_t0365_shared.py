from pathlib import Path
p=Path('scripts/presentation/MountainArtTrial.gd')
s=p.read_text(encoding='utf-8')
def method(name):
    a=s.index('func '+name+'(')
    b=s.find('\nfunc ',a+5)
    return s[a:] if b<0 else s[a:b]
header='''extends Node3D
## Approved high-cliff presentation shared by production and the independent review.
const ROCK_SHADER := preload("res://shaders/environment/mountain_art_trial.gdshader")
const CONFIG_PATH := "res://data/presentation/mountain_art_trial.json"
var _style: Dictionary = {}
var _environment: Node3D
var _mountain: Node3D
var _original: Dictionary = {}
var _geometry: Dictionary = {}
var _material := ShaderMaterial.new()
var _outcrops := Node3D.new()
var _cliffs := Node3D.new()
var _lifted_instances: Array[Dictionary] = []
var _peak_heights: Dictionary = {}
var _surfaces: Array[MeshInstance3D] = []
var _rock_bases: Array[Vector3] = []
var _candidate := true

func configure(environment: Node3D, settings: Dictionary) -> void:
	_environment = environment
	_style = settings.duplicate(true)
	assert(_style.get("schema_version", "") == "mountain_art_trial_v1")
	set_meta("presentation_only", true)
'''
a=s.index('\t_mountain = _environment.get_node')
b=s.index('\t_camera.name = ',a)
init=s[a:b]+'\tset_enabled(true)\n'
init=init.replace('_material.shader = ROCK_SHADER','_material.shader = ROCK_SHADER\n\t_material.set_shader_parameter("environment_origin", _environment.global_position)')
toggle='''func set_enabled(enabled: bool) -> void:
	_candidate = enabled
	_outcrops.visible = enabled
	_mountain.visible = not enabled
	_cliffs.visible = enabled
	for entry in _lifted_instances:
		entry.node.multimesh.set_instance_transform(entry.index, entry.candidate if enabled else entry.original)
'''
functions='\n\n'.join(method(n) for n in ['_read','_build_cliffs','_lift_mountain_scatter','_height_at','_build_outcrops','_face','_verify'])
functions=functions.replace('var position_on_map := Vector2(source.global_position.x, source.global_position.z)','var local_position := _environment.to_local(source.global_position)\n\t\tvar position_on_map := Vector2(local_position.x, local_position.z)')
functions=functions.replace('rock.transform = source.global_transform','rock.transform = _environment.global_transform.affine_inverse() * source.global_transform')
functions=functions.replace('var world_point := node.to_global(original.origin)','var world_point := _environment.to_local(node.to_global(original.origin))')
functions=functions.replace('candidate.origin = node.to_local(world_point)','candidate.origin = node.to_local(_environment.to_global(world_point))')
functions=functions.replace('\tassert(get_node_or_null("/root/Main") == null)\n','')
functions=functions.replace('"main_created": false, "production_enabled": false','"enabled": _candidate')
functions=functions.replace('func _verify()', 'func get_debug_snapshot()')
Path('scripts/presentation/environment/StylizedMountainArt.gd').write_text(header+init+'\n'+toggle+'\n'+functions+'\n',encoding='utf-8',newline='\n')
preview='''extends Node3D
## Independent A/B using the same approved cliff construction as production.
const ENVIRONMENT := preload("res://scripts/presentation/environment/FormalGroundSurfaceArtView.gd")
const MOUNTAIN_ART := preload("res://scripts/presentation/environment/StylizedMountainArt.gd")
const OUTPUT := "res://artifacts/visual_qa/t0365/shared_revision"
var _style: Dictionary = {}
var _environment: Node3D
var _art := MOUNTAIN_ART.new()
var _camera := Camera3D.new()
var _label := Label.new()
var _candidate := true
var _night := false

func _ready() -> void:
	_style = _read(MOUNTAIN_ART.CONFIG_PATH)
	var environment_config := _read("res://data/presentation/environment_art.json")
	environment_config["approved_mountain"] = {"enabled": false}
	_environment = ENVIRONMENT.new()
	_environment.name = "ReadOnlyEnvironment"
	_environment.configure(environment_config, _read("res://data/station_layout.json"))
	add_child(_environment)
	_environment.get_node("StationLifeDetails").hide()
	_art.name = "ApprovedMountainReview"
	_environment.add_child(_art)
	_art.configure(_environment, _style)
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
	if "--capture-mountain-trial" in OS.get_cmdline_user_args():
		call_deferred("_capture")

func set_candidate(enabled: bool) -> void:
	_candidate = enabled
	_art.set_enabled(enabled)
	_label.text = "T0365  山体试验 / " + ("B · 高岩壁与错落山脊" if enabled else "A · 当前山体")

func _verify() -> Dictionary:
	assert(get_node_or_null("/root/Main") == null)
	var snapshot := _art.get_debug_snapshot()
	snapshot["main_created"] = false
	snapshot["production_enabled"] = false
	return snapshot
'''
preview+='\n\n'+'\n\n'.join(method(n) for n in ['_read','set_view','set_night','_build_controls','_capture'])+'\n'
p.write_text(preview,encoding='utf-8',newline='\n')
# Fix registration order without retaining a duplicate task identifier.
p=Path('docs/TASKS.md'); t=p.read_text(encoding='utf-8')
a=t.index('### T0366 河流与河岸表现试验\n'); b=t.index('### T0365-I',a)
t=t[:a]+t[b:]
t=t.replace('### T0366 河流与河岸表现试验（条目见上）','### T0366 河流与河岸表现试验',1)
p.write_text(t,encoding='utf-8',newline='\n')
