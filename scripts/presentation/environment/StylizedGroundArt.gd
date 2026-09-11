extends Node3D
## Shared approved T0362 art, with no gameplay or collision authority.
const CONFIG_PATH := "res://data/presentation/ground_art_trial.json"
const SHADER := preload("res://shaders/environment/ground_art_trial.gdshader")
const WILDFLOWERS := preload("res://scripts/presentation/environment/LowPolyWildflowers.gd")
var _flower_placements: Array[Transform3D] = []
var grass_transforms: Array[Transform3D] = []
var grass_colors: Array[Color] = []
var _config: Dictionary = {}
var _layout: Dictionary = {}
var _roads: Array = []
var _tuft_count := 0
var _topology: Dictionary = {}
var _outer_tuft_count := 0
var _outer_chunk_count := 0
var _station_polygon := PackedVector2Array()
var _density_counts := {"inside":0,"outside":0}
var _density_area := {"inside":0.0,"outside":0.0}
var create_preview_surface := false
var ground_y := 0.02

func configure(config: Dictionary, layout: Dictionary, environment: Dictionary = {}) -> void:
    _config = config.duplicate(true)
    _layout = layout.duplicate(true)
    _roads = _layout.get("roads", [])
    _topology = environment.get("terrain_topology", {})
    for point in (_layout.get("station", {}) as Dictionary).get("interior_polygon", []):
        _station_polygon.append(Vector2(point[0],point[1]))

func _ready() -> void:
    assert(not _roads.is_empty() and _roads.size() <= 64)
    set_meta("presentation_only", true)
    if create_preview_surface:
        ground_y = 0.088
        build_preview_surface()
    _build_tufts()
    if bool((_config.get("outer_grass", {}) as Dictionary).get("enabled",false)) and not _topology.is_empty():
        _build_outer_tufts()

func make_surface_material() -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = SHADER
    for key in ["grass_dark", "grass_light", "soil_dark", "soil_light"]:
        material.set_shader_parameter(key, Color(_config[key]))
    var segments: Array[Vector4] = []
    var widths := PackedFloat32Array()
    for road: Dictionary in _roads:
        segments.append(Vector4(road.from[0], road.from[1], road.to[0], road.to[1]))
        widths.append(float(road.width))
    var road_count := segments.size()
    segments.resize(64)
    widths.resize(64)
    material.set_shader_parameter("road_count", road_count)
    material.set_shader_parameter("road_segments", segments)
    material.set_shader_parameter("road_widths", widths)
    material.set_shader_parameter("station_origin", Vector2(global_position.x,global_position.z))
    return material

func build_preview_surface() -> void:
    var material := make_surface_material()
    var bounds: Array = _config.bounds
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(bounds[2]-bounds[0], bounds[3]-bounds[1])
    mesh.material = material
    var surface := MeshInstance3D.new()
    surface.name = "ContinuousGrassAndEarth"
    surface.mesh = mesh
    surface.position = Vector3((bounds[0]+bounds[2])*0.5, 0.086, (bounds[1]+bounds[3])*0.5)
    surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(surface)

func _road_distance(p: Vector2) -> float:
    var result := INF
    for road: Dictionary in _roads:
        var a := Vector2(road.from[0], road.from[1])
        var b := Vector2(road.to[0], road.to[1])
        result = minf(result, p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))-float(road.width)*0.5)
    return result

func _in_lot(p: Vector2) -> bool:
    for building: Dictionary in _layout.buildings:
        var local := (p-Vector2(building.center[0],building.center[1])).rotated(deg_to_rad(float(building.rotation_degrees)))
        var half := Vector2(building.lot_size[0],building.lot_size[1])*0.5+Vector2.ONE*0.5
        if absf(local.x)<half.x and absf(local.y)<half.y:
            return true
    return false

func _build_tufts() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = int(_config.seed)
    var noise := FastNoiseLite.new()
    noise.seed = int(_config.seed)
    noise.frequency = 0.18
    var points: Array[Transform3D] = []
    var bounds: Array = _config.bounds
    var sample_area: float = (bounds[2]-bounds[0]-2.0)*(bounds[3]-bounds[1]-2.0)/float(_config.tuft_attempts)
    for attempt in int(_config.tuft_attempts):
        var p := Vector2(rng.randf_range(bounds[0]+1,bounds[2]-1),rng.randf_range(bounds[1]+1,bounds[3]-1))
        var distance := _road_distance(p)
        if distance<0.7 or _in_lot(p):
            continue
        var zone := "inside" if Geometry2D.is_point_in_polygon(p,_station_polygon) else "outside"
        _density_area[zone] += sample_area
        if noise.get_noise_2dv(p)<-0.12:
            continue
        if distance>4.0 and rng.randf()>0.22:
            continue
        var scale_value := rng.randf_range(0.6,1.35)
        var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value)
        points.append(Transform3D(basis,Vector3(p.x,ground_y,p.y)))
        _density_counts[zone] += 1
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = _tuft_mesh()
    var flowers := _select_wildflowers(points)
    multi.instance_count = points.size() - flowers.size()
    var retained_index := 0
    for index in points.size():
        if flowers.has(index):
            continue
        multi.set_instance_transform(retained_index,points[index])
        multi.set_instance_color(retained_index,Color(_config.tuft_colors[index%_config.tuft_colors.size()]).srgb_to_linear())
        grass_transforms.append(points[index])
        grass_colors.append(Color(_config.tuft_colors[index%_config.tuft_colors.size()]).srgb_to_linear())
        retained_index += 1
    var node := MultiMeshInstance3D.new()
    node.name = "SolidLowPolyGrass"
    node.multimesh = multi
    add_child(node)
    _tuft_count = points.size()
    _build_wildflowers(points, flowers, multi.mesh.get_aabb())

func _select_wildflowers(points: Array[Transform3D]) -> Dictionary:
    var settings: Dictionary = _config.get("wildflowers", {})
    if not bool(settings.get("enabled", false)):
        return {}
    var rng := RandomNumberGenerator.new()
    rng.seed = int(settings.get("seed", 369))
    var candidates: Array[int] = []
    for i in points.size():
        var p := Vector2(points[i].origin.x, points[i].origin.z)
        if not Geometry2D.is_point_in_polygon(p, _station_polygon) or _road_distance(p) < 1.0:
            continue
        candidates.append(i)
    var chosen: Dictionary = {}
    while not candidates.is_empty() and chosen.size() < int(settings.get("count", 8)):
        var pick := rng.randi_range(0, candidates.size()-1)
        var index := candidates[pick]
        candidates.remove_at(pick)
        var spaced := true
        for previous: int in chosen:
            if points[index].origin.distance_to(points[previous].origin) < float(settings.get("minimum_spacing", 9.0)):
                spaced = false
                break
        if spaced:
            chosen[index] = chosen.size() % 2
            _flower_placements.append(points[index])
    return chosen

func _build_wildflowers(points: Array[Transform3D], selected: Dictionary, grass_bounds: AABB) -> void:
    if selected.is_empty():
        return
    var settings: Dictionary = _config.get("wildflowers", {})
    var colors: Array = settings.get("petal_colors", ["#e7e3d0", "#dfbf4f"])
    for variant in 2:
        var positions: Array[Transform3D] = []
        for index: int in selected:
            if selected[index] == variant:
                positions.append(points[index])
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = WILDFLOWERS.make_mesh(Color(str(colors[variant])), grass_bounds)
        multi.instance_count = positions.size()
        for i in positions.size():
            multi.set_instance_transform(i, positions[i])
        var flowers := MultiMeshInstance3D.new()
        flowers.name = "WhiteWildflowers" if variant == 0 else "YellowWildflowers"
        flowers.multimesh = multi
        add_child(flowers)

func _build_outer_tufts() -> void:
    var config: Dictionary = _config.get("outer_grass", {})
    var terrain: Dictionary = _layout.get("terrain", {})
    var center: Array = terrain.get("center",[0.0,25.0])
    var size: Array = terrain.get("size",[700.0,720.0])
    var profile: Array = _topology.get("river_profile",[])
    if profile.size()<2:
        return
    var spacing := maxf(1.0,float(config.get("spacing",3.0)))
    var chunk_size := maxf(16.0,float(config.get("chunk_size",48.0)))
    var mountain: Dictionary = _topology.get("east_mountain",{})
    var mountain_start := float(mountain.get("near_x_range",[120.0,175.0])[0])
    var left: float = center[0]-size[0]*0.5+1.0
    var right := minf(float(center[0])+float(size[0])*0.5-1.0,mountain_start)
    var rng := RandomNumberGenerator.new()
    rng.seed = int(config.get("seed",3621))
    var noise := FastNoiseLite.new()
    noise.seed = rng.seed
    noise.frequency = 0.045
    var groups: Dictionary = {}
    for row in ceili((float(profile[-1][0])-float(profile[0][0])-2.0)/spacing):
        for column in ceili((right-left)/spacing):
            var p := Vector2(left+(column+rng.randf())*spacing,float(profile[0][0])+1.0+(row+rng.randf())*spacing)
            if not _outer_point_allowed(p) or _road_distance(p)<0.7 or _in_lot(p):
                continue
            _density_area.outside += spacing*spacing
            var weight := smoothstep(-0.35,0.35,noise.get_noise_2dv(p))
            var probability := lerpf(float(config.get("density_min",0.4)),float(config.get("density_max",0.9)),weight)
            probability *= smoothstep(0.0,float(config.get("mountain_fade_width",18.0)),mountain_start-p.x)
            if rng.randf()>probability:
                continue
            var chunk := Vector2i(floori(p.x/chunk_size),floori(p.y/chunk_size))
            if not groups.has(chunk):
                groups[chunk] = []
            var scale_value := rng.randf_range(0.6,1.35)
            var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value)
            groups[chunk].append(Transform3D(basis,Vector3(p.x,float(terrain.get("ground_surface_y",0.0))+0.02,p.y)))
            _outer_tuft_count += 1
    var mesh: Mesh = get_node("SolidLowPolyGrass").multimesh.mesh
    var outer_root := Node3D.new()
    outer_root.name = "OuterGrassChunks"
    add_child(outer_root)
    for chunk: Vector2i in groups:
        var placements: Array = groups[chunk]
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.use_colors = true
        multi.mesh = mesh
        multi.instance_count = placements.size()
        for index in placements.size():
            multi.set_instance_transform(index,placements[index])
            multi.set_instance_color(index,Color(_config.tuft_colors[index%_config.tuft_colors.size()]).srgb_to_linear())
        var node := MultiMeshInstance3D.new()
        node.name = "Grass_%s_%s" % [chunk.x,chunk.y]
        node.multimesh = multi
        outer_root.add_child(node)
    _outer_chunk_count = groups.size()
    _density_counts.outside += _outer_tuft_count

func _outer_point_allowed(p: Vector2) -> bool:
    var bounds: Array = _config.bounds
    if Rect2(Vector2(bounds[0],bounds[1]),Vector2(bounds[2]-bounds[0],bounds[3]-bounds[1])).has_point(p):
        return false
    var terrain: Dictionary = _layout.get("terrain",{})
    var center: Array = terrain.get("center",[0.0,25.0])
    var size: Array = terrain.get("size",[700.0,720.0])
    var profile: Array = _topology.get("river_profile",[])
    var mountain: Dictionary = _topology.get("east_mountain",{})
    if profile.size()<2 or p.y<=float(profile[0][0])+0.5 or p.y>=float(profile[-1][0])-0.5:
        return false
    if p.x<=float(center[0])-float(size[0])*0.5+0.5 or p.x>=float(mountain.get("near_x_range",[120.0,175.0])[0]):
        return false
    for index in profile.size()-1:
        var a: Array = profile[index]
        var b: Array = profile[index+1]
        if p.y<float(a[0]) or p.y>float(b[0]):
            continue
        var t := inverse_lerp(float(a[0]),float(b[0]),p.y)
        var river_center := lerpf(float(a[1]),float(b[1]),t)
        var half_valley := lerpf(float(a[2]),float(b[2]),t)*0.5
        return absf(p.x-river_center)>half_valley+float((_config.get("outer_grass",{}) as Dictionary).get("river_clearance",1.2))
    return false

func _tuft_mesh() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for blade in 5:
        var angle := float(blade)*2.4
        var center := Vector3(cos(angle),0,sin(angle))*0.12
        var vertices: Array[Vector3] = [center+Vector3(-0.09,0,-0.055),center+Vector3(0.09,0,-0.055),center+Vector3(0,0,0.08),center+Vector3(cos(angle)*0.14,0.27+float(blade%3)*0.095,sin(angle)*0.14)]
        var centroid := (vertices[0]+vertices[1]+vertices[2]+vertices[3])*0.25
        for face in [[0,1,3],[1,2,3],[2,0,3],[0,2,1]]:
            var a: Vector3=vertices[face[0]]
            var b: Vector3=vertices[face[1]]
            var c: Vector3=vertices[face[2]]
            var normal := (c-a).cross(b-a).normalized()
            if normal.dot((a+b+c)/3.0-centroid)<0.0:
                var swap := b
                b=c
                c=swap
                normal = -normal
            for v in [a,b,c]:
                st.set_normal(normal)
                st.add_vertex(v)
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.roughness = 1.0
    st.set_material(material)
    return st.commit()

func get_debug_snapshot() -> Dictionary:
    return {"art_revision":"t0362_approved", "tufts":_tuft_count, "grass_tufts":_tuft_count-_flower_placements.size(), "wildflowers":_flower_placements.size(), "outer_tufts":_outer_tuft_count,"outer_chunks":_outer_chunk_count,"estimated_inside_density":float(_density_counts.inside)/maxf(1.0,_density_area.inside),"estimated_outside_density":float(_density_counts.outside)/maxf(1.0,_density_area.outside),"road_count":_roads.size(), "has_collision":not find_children("*","CollisionObject3D",true,false).is_empty(), "has_navigation":not find_children("*","NavigationRegion3D",true,false).is_empty(), "authority_role":"presentation_only"}

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
