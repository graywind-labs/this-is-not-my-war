extends Node3D
## Isolated art comparison. Formal assets/configuration are read-only context.
## No Main, simulation or workstation authority; new terrain is collision-free.

const CONFIG_PATH := "res://data/presentation/ground_art_trial.json"
const GROUND_SCRIPT := preload("res://scripts/presentation/environment/FormalGroundSurfaceArtView.gd")
const ROAD_SCRIPT := preload("res://scripts/presentation/environment/FormalRoadNetworkArtView.gd")
const HALL_SCRIPT := preload("res://scripts/presentation/buildings/FormalMainHallArtView.gd")
const COVER_SCRIPT := preload("res://scripts/presentation/MenuCoverPreview.gd")
const APPROVED_ART := preload("res://scripts/presentation/environment/StylizedGroundArt.gd")

var _config: Dictionary
var _layout: Dictionary
var _roads: Array
var _old_ground: Node3D
var _trial := APPROVED_ART.new()
var _camera := Camera3D.new()
var _hidden_in_trial: Array[Node3D] = []
var _label := Label.new()
var _candidate := true
var _tuft_count := 0
var _night := false

func _read(path: String) -> Dictionary:
    return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary

func _ready() -> void:
    _config = _read(CONFIG_PATH)
    _layout = _read("res://data/station_layout.json")
    _roads = _layout.get("roads", [])
    assert(not _roads.is_empty() and _roads.size() <= 64)
    var environment_config := _read("res://data/presentation/environment_art.json")
    environment_config["approved_ground"] = {"enabled": false}
    environment_config["approved_forest"] = {"enabled": false}
    environment_config["approved_mountain"] = {"enabled": false}
    environment_config["approved_river"] = {"enabled": false}
    _old_ground = GROUND_SCRIPT.new()
    _old_ground.name = "OriginalEnvironment"
    _old_ground.configure(environment_config, _layout)
    add_child(_old_ground)
    _old_ground.get_node("StationLifeDetails").hide()
    var roads := ROAD_SCRIPT.new()
    roads.name = "OriginalRoads"
    roads.configure(_roads)
    add_child(roads)
    var hall := HALL_SCRIPT.new()
    hall.name = "UnchangedMainHall"
    for building: Dictionary in _layout.buildings:
        if building.id == "main_hall":
            hall.position = Vector3(building.center[0], 0.0, building.center[1])
    add_child(hall)
    for entry: Dictionary in _layout.npc_initial_positions:
        var packed: PackedScene = COVER_SCRIPT.CHARACTER_SCENES.get(str(entry.npc_id))
        if packed == null:
            continue
        var character := packed.instantiate() as Node3D
        character.position = Vector3(entry.position[0], 0.0, entry.position[1])
        add_child(character)
        character.call("debug_force_action_preview", "", "idle")
    var board := (load("res://scenes/props/NoticeBoard.tscn") as PackedScene).instantiate() as Node3D
    board.position = Vector3(-3.6, 0.0, 2.6)
    add_child(board)
    # Only the preview's plant meshes are hidden. Shared source nodes never change.
    for child in _old_ground.get_node("GroundSurface").get_children():
        if child is Node3D and str(child.name).begins_with("GroundVegetation"):
            _hidden_in_trial.append(child)
    var scatter := _old_ground.get_node("FullMapNaturalScatter")
    _hidden_in_trial.append(scatter)
    _trial.name = "TrialSurface"
    _trial.set_meta("presentation_only", true)
    _trial.create_preview_surface = true
    _trial.configure(_config,_layout,environment_config)
    add_child(_trial)
    _tuft_count = _trial.get_debug_snapshot().tufts
    _camera.name = "ReviewCamera"
    _camera.fov = 48.0
    _camera.far = 900.0
    add_child(_camera)
    _camera.current = true
    set_review_view(false)
    _build_controls()
    set_candidate(true)
    set_night(false)
    get_viewport().msaa_3d = Viewport.MSAA_4X
    assert(_trial.find_children("*", "CollisionObject3D", true, false).is_empty())
    assert(_trial.find_children("*", "NavigationRegion3D", true, false).is_empty())
    if "--capture-ground-trial" in OS.get_cmdline_user_args():
        call_deferred("_capture_review")

func set_candidate(enabled: bool) -> void:
    _candidate=enabled
    _trial.visible=enabled
    for node in _hidden_in_trial:
        node.visible=not enabled
    _label.text="T0362  地表试验  /  %s" % ("B · 草泥过渡 + 立体草簇" if enabled else "A · 当前地表")

func set_review_view(close: bool) -> void:
    var target:=Vector3(_config.camera_target[0],_config.camera_target[1],_config.camera_target[2])
    var offset:=Vector3(_config.camera_offset[0],_config.camera_offset[1],_config.camera_offset[2])
    if close:
        target=Vector3(1,0,14)
        offset=Vector3(9,16,20)
    _camera.position=target+offset
    _camera.look_at(target)

func set_night(enabled: bool) -> void:
    _night=enabled
    _old_ground.get_node("CelestialCycleController").call("_apply_time",1,0 if enabled else 12,30,0)

func _build_controls() -> void:
    var layer:=CanvasLayer.new()
    layer.name="ReviewControls"
    add_child(layer)
    var panel:=PanelContainer.new()
    panel.position=Vector2(18,18)
    layer.add_child(panel)
    var column:=VBoxContainer.new()
    panel.add_child(column)
    _label.add_theme_font_size_override("font_size",20)
    column.add_child(_label)
    var row:=HBoxContainer.new()
    column.add_child(row)
    for entry in [["原版 A",func():set_candidate(false)],["试案 B",func():set_candidate(true)],["整体",func():set_review_view(false)],["近看",func():set_review_view(true)],["昼 / 夜",func():set_night(not _night)]]:
        var button:=Button.new()
        button.text=entry[0]
        button.pressed.connect(entry[1])
        row.add_child(button)

func get_review_snapshot() -> Dictionary:
    return {"candidate":_candidate,"tufts":_tuft_count,"road_count":_roads.size(),"simulation_created":get_node_or_null("/root/Main")!=null,"trial_colliders":_trial.find_children("*","CollisionObject3D",true,false).size(),"trial_navigation":_trial.find_children("*","NavigationRegion3D",true,false).size()}

func _capture_review() -> void:
    get_window().size=Vector2i(1280,720)
    var directory:="res://artifacts/visual_qa/t0362"
    DirAccess.make_dir_recursive_absolute(directory)
    for view in [false,true]:
        set_review_view(view)
        for night in [false,true]:
            set_night(night)
            for candidate in [false,true]:
                set_candidate(candidate)
                for frame in 8:
                    await get_tree().process_frame
                await RenderingServer.frame_post_draw
                var filename:="%s/%s_%s_%s.png" % [directory,"close" if view else "overview","night" if night else "day","B" if candidate else "A"]
                get_viewport().get_texture().get_image().save_png(filename)
    var snapshot:=get_review_snapshot()
    assert(not snapshot.simulation_created)
    assert(snapshot.trial_colliders==0 and snapshot.trial_navigation==0)
    assert(snapshot.tufts>0)
    var file:=FileAccess.open(directory+"/review_snapshot.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(snapshot,"  "))
    print("T0362_PASS ",JSON.stringify(snapshot))
    get_tree().quit()
