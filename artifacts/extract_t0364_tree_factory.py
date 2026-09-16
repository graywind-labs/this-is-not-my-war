from pathlib import Path

root = Path('scripts/presentation/environment')
trial_path = root / 'TrialForestArtView.gd'
source = trial_path.read_text(encoding='utf-8')
geometry = source[source.index('func _make_tree('):source.index('func get_trial_snapshot(')]
header = '''extends RefCounted
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

'''
(root / 'StylizedTreeMeshes.gd').write_text(header + geometry, encoding='utf-8')
source = source.replace('## T0364 preview only. Reuses formal point generation and route/river/station exclusions.', '## T0364 preview only. Formal placement rules and approved meshes are shared.\nconst TREE_MESHES := preload("res://scripts/presentation/environment/StylizedTreeMeshes.gd")')
source = source.replace('var _surface_material := StandardMaterial3D.new()\nvar _groups_noise := FastNoiseLite.new()', 'var _tree_art: RefCounted')
start = source.index('\t_surface_material.vertex_color_use_as_albedo')
end = source.index('\nfunc _build_tree_multimeshes', start)
source = source[:start] + '\t_tree_art = TREE_MESHES.new(style)\n\tmeshes = _tree_art.meshes\n' + source[end:]
start = source.index('\tvar species_rng :=')
end = source.index('\tvar scale_range :=', start)
source = source[:start] + '\tvar species_rng: RandomNumberGenerator = _tree_art.make_species_rng(chunk_center)\n' + source[end:]
start = source.index('\t\tvar noise_value :=')
end = source.index('\t\tvar station_distance :=',start)
source = source[:start] + '\t\tvar variant: int = _tree_art.choose_variant(point,species_rng)\n' + source[end:]
start = source.index('\tfor index in groups.size():')
end = source.index('func get_trial_snapshot(',start)
source = source[:start] + '\t_tree_art.build_multimeshes(chunk,groups,GeometryInstance3D.SHADOW_CASTING_SETTING_ON)\n\n' + source[end:]
trial_path.write_text(source,encoding='utf-8')
