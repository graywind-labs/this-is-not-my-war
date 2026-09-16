from pathlib import Path
root = Path.cwd()
p = root / 'scripts/presentation/GroundArtTrial.gd'
s = p.read_text(encoding='utf-8-sig')
material = s[s.index('    var material := ShaderMaterial.new()',s.index('func _build_surface')):s.index('    var bounds: Array = _config.bounds',s.index('func _build_surface'))]
surface = s[s.index('    var bounds: Array = _config.bounds',s.index('func _build_surface')):s.index('func _road_distance')]
helpers = s[s.index('func _road_distance'):s.index('func set_candidate')]
header='''extends Node3D
## Shared approved T0362 art, with no gameplay or collision authority.
const CONFIG_PATH := "res://data/presentation/ground_art_trial.json"
const SHADER := preload("res://shaders/environment/ground_art_trial.gdshader")
var _config: Dictionary = {}
var _layout: Dictionary = {}
var _roads: Array = []
var _tuft_count := 0
var create_preview_surface := false
var ground_y := 0.02

func configure(config: Dictionary, layout: Dictionary) -> void:
    _config = config.duplicate(true)
    _layout = layout.duplicate(true)
    _roads = _layout.get("roads", [])

func _ready() -> void:
    assert(not _roads.is_empty() and _roads.size() <= 64)
    set_meta("presentation_only", true)
    if create_preview_surface:
        ground_y = 0.088
        build_preview_surface()
    _build_tufts()

func make_surface_material() -> ShaderMaterial:
'''
material += '    material.set_shader_parameter("station_origin", Vector2(global_position.x,global_position.z))\n    return material\n\n'
surface = 'func build_preview_surface() -> void:\n    var material := make_surface_material()\n' + surface.replace('_trial.add_child(surface)','add_child(surface)')
helpers = helpers.replace('_trial.add_child(node)','add_child(node)').replace('Vector3(p.x,0.088,p.y)','Vector3(p.x,ground_y,p.y)')
tail='''func get_debug_snapshot() -> Dictionary:
    return {"art_revision":"t0362_approved", "tufts":_tuft_count, "road_count":_roads.size(), "has_collision":not find_children("*","CollisionObject3D",true,false).is_empty(), "has_navigation":not find_children("*","NavigationRegion3D",true,false).is_empty(), "authority_role":"presentation_only"}

func replace_original_scatter(scatter_root: Node3D) -> int:
    var bounds: Array = _config.bounds
    var rect := Rect2(Vector2(bounds[0],bounds[1]),Vector2(bounds[2]-bounds[0],bounds[3]-bounds[1]))
    var removed := 0
    for instance in scatter_root.find_children("*","MultiMeshInstance3D",true,false):
        var original: MultiMesh = instance.multimesh
        var retained: Array[Transform3D] = []
        for index in original.instance_count:
            var transform := original.get_instance_transform(index)
            var position_in_station: Vector3 = to_local(instance.to_global(transform.origin))
            if rect.has_point(Vector2(position_in_station.x,position_in_station.z)):
                removed += 1
            else:
                retained.append(transform)
        var replacement := MultiMesh.new()
        replacement.transform_format = MultiMesh.TRANSFORM_3D
        replacement.mesh = original.mesh
        replacement.instance_count = retained.size()
        for index in retained.size():
            replacement.set_instance_transform(index,retained[index])
        instance.multimesh = replacement
    return removed
'''
(root/'scripts/presentation/environment/StylizedGroundArt.gd').write_text(header+material+surface+helpers+tail,encoding='utf-8')
s=s.replace('const SHADER := preload("res://shaders/environment/ground_art_trial.gdshader")','const APPROVED_ART := preload("res://scripts/presentation/environment/StylizedGroundArt.gd")')
s=s.replace('var _trial := Node3D.new()','var _trial := APPROVED_ART.new()')
s=s.replace('    _old_ground = GROUND_SCRIPT.new()','    environment_config["approved_ground"] = {"enabled": false}\n    _old_ground = GROUND_SCRIPT.new()')
s=s.replace('    add_child(_trial)\n    _build_surface()\n    _build_tufts()','    _trial.create_preview_surface = true\n    _trial.configure(_config,_layout)\n    add_child(_trial)\n    _tuft_count = _trial.get_debug_snapshot().tufts')
s=s[:s.index('func _build_surface()')]+s[s.index('func set_candidate'):]
p.write_text(s,encoding='utf-8')
