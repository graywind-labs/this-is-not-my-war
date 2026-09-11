extends Node3D


const MAIN_HALL_ART_SCRIPT := preload("res://scripts/presentation/buildings/FormalMainHallArtView.gd")
const FORTIFICATION_ART_SCRIPT := preload("res://scripts/presentation/buildings/FormalFortificationArtView.gd")
const STATION_LAYOUT_CONTROLLER_SCRIPT := preload("res://scripts/world/StationLayoutController.gd")
const DINING_HALL_ART_SCRIPT := preload("res://scripts/presentation/buildings/FormalDiningHallArtView.gd")
const FIXTURE_LAYOUTS_PATH := "res://data/building_fixture_layouts.json"

const CHARACTER_SCENES := {
	"veteran_deputy_01": preload("res://scenes/characters/AdaChibiArtView.tscn"),
	"stableman_01": preload("res://scenes/characters/TomaChibiArtView.tscn"),
	"cook_01": preload("res://scenes/characters/BrunoChibiArtView.tscn"),
	"gardener_01": preload("res://scenes/characters/IvoChibiArtView.tscn"),
	"blacksmith_01": preload("res://scenes/characters/GlenChibiArtView.tscn"),
	"priest_01": preload("res://scenes/characters/MarcelChibiArtView.tscn"),
	"doctor_01": preload("res://scenes/characters/LinaChibiArtView.tscn"),
	"engineer_01": preload("res://scenes/characters/OwenChibiArtView.tscn"),
}
const ENEMY_SCENE := preload("res://scenes/characters/EnemySwordShieldChibiArtView.tscn")
const HORSE_SCENE := preload("res://assets/3d/quaternius/animals/merchant_horse.glb")
const WORKBENCH_SCENE := preload("res://assets/3d/quaternius/props/workshop_workbench.glb")
const BOOK_STAND_SCENE := preload("res://assets/3d/quaternius/props/chapel_book_stand.glb")
const BOOK_SCENE := preload("res://assets/3d/quaternius/props/chapel_book.glb")
const SWORD_SCENE := preload("res://assets/3d/quaternius/props/sword_bronze.glb")
const SHIELD_SCENE := preload("res://assets/3d/quaternius/props/shield_wooden.glb")
const CRATE_SCENE := preload("res://assets/3d/quaternius/props/crate_wooden.glb")
const BAG_SCENE := preload("res://assets/3d/quaternius/props/warehouse_bag.glb")
const BARREL_SCENE := preload("res://assets/3d/quaternius/props/barrel.glb")
const LANTERN_SCENE := preload("res://assets/3d/quaternius/props/main_hall_lantern.glb")
const TREE_SCENE := preload("res://assets/3d/quaternius/nature/common_tree_a.glb")
const LOOP_SECONDS := 12.0
const OUTER_TREE_LAYOUT := [
	{"position": Vector3(-10.5, 0.0, -23.2), "scale": 0.82, "yaw": -18.0, "zone": "rear"},
	{"position": Vector3(-5.2, 0.0, -24.8), "scale": 0.96, "yaw": 26.0, "zone": "rear"},
	{"position": Vector3(0.8, 0.0, -22.7), "scale": 1.08, "yaw": -31.0, "zone": "rear"},
	{"position": Vector3(7.2, 0.0, -25.4), "scale": 0.86, "yaw": 14.0, "zone": "rear"},
	{"position": Vector3(13.7, 0.0, -23.5), "scale": 1.04, "yaw": 37.0, "zone": "rear"},
	{"position": Vector3(20.2, 0.0, -25.1), "scale": 0.91, "yaw": -9.0, "zone": "rear"},
	{"position": Vector3(25.7, 0.0, -22.8), "scale": 1.13, "yaw": 23.0, "zone": "rear"},
	{"position": Vector3(-7.7, 0.0, -31.0), "scale": 0.72, "yaw": -36.0, "zone": "rear_mid"},
	{"position": Vector3(3.9, 0.0, -31.7), "scale": 0.76, "yaw": 41.0, "zone": "rear_mid"},
	{"position": Vector3(10.2, 0.0, -29.4), "scale": 0.90, "yaw": -22.0, "zone": "rear_mid"},
	{"position": Vector3(16.1, 0.0, -31.3), "scale": 0.70, "yaw": 29.0, "zone": "rear_mid"},
	{"position": Vector3(22.0, 0.0, -29.0), "scale": 0.86, "yaw": -13.0, "zone": "rear_mid"},
	{"position": Vector3(28.0, 0.0, -31.1), "scale": 0.74, "yaw": 35.0, "zone": "rear_mid"},
	{"position": Vector3(-3.9, 0.0, -34.0), "scale": 0.76, "yaw": 32.0, "zone": "rear_far"},
	{"position": Vector3(2.7, 0.0, -35.2), "scale": 0.64, "yaw": -7.0, "zone": "rear_far"},
	{"position": Vector3(9.1, 0.0, -33.8), "scale": 0.80, "yaw": 21.0, "zone": "rear_far"},
	{"position": Vector3(15.8, 0.0, -35.0), "scale": 0.66, "yaw": -34.0, "zone": "rear_far"},
	{"position": Vector3(22.4, 0.0, -34.1), "scale": 0.77, "yaw": 12.0, "zone": "rear_far"},
	{"position": Vector3(29.1, 0.0, -35.3), "scale": 0.63, "yaw": 38.0, "zone": "rear_far"},
	{"position": Vector3(34.5, 0.0, -33.2), "scale": 0.71, "yaw": -19.0, "zone": "rear_far"},
	{"position": Vector3(-16.1, 0.0, -17.8), "scale": 0.78, "yaw": 32.0, "zone": "left"},
	{"position": Vector3(-17.6, 0.0, -8.7), "scale": 0.92, "yaw": -27.0, "zone": "left"},
	{"position": Vector3(-16.4, 0.0, 1.8), "scale": 0.83, "yaw": 11.0, "zone": "left"},
	{"position": Vector3(29.0, 0.0, -21.5), "scale": 1.22, "yaw": 20.0, "zone": "right"},
	{"position": Vector3(32.5, 0.0, -15.0), "scale": 1.05, "yaw": -24.0, "zone": "right"},
	{"position": Vector3(30.8, 0.0, -6.8), "scale": 0.94, "yaw": 31.0, "zone": "right"},
	{"position": Vector3(29.5, 0.0, 7.0), "scale": 0.88, "yaw": -14.0, "zone": "right"},
]

const CHARACTER_LAYOUT := [
	{"id": "veteran_deputy_01", "position": Vector3(7.0, 0.0, 6.0), "yaw": 168.0, "action": "", "state": "idle"},
	{"id": "blacksmith_01", "position": Vector3(10.7, 0.0, 5.45), "yaw": 0.0, "action": "work_blacksmith", "state": "work"},
	{"id": "stableman_01", "position": Vector3(15.15, 0.0, 6.65), "yaw": 0.0, "action": "work_stable", "state": "work"},
	{"id": "cook_01", "position": Vector3(4.15, 0.0, 6.18), "yaw": 0.0, "action": "work_dining_hall", "state": "work"},
	{"id": "gardener_01", "position": Vector3(13.4, 0.0, 3.58), "yaw": 0.0, "action": "work_garden", "state": "work"},
	{"id": "priest_01", "position": Vector3(3.55, 0.0, 3.62), "yaw": 0.0, "action": "", "state": "mass_leader"},
	{"id": "doctor_01", "position": Vector3(6.0, 0.5, 1.07), "yaw": 0.0, "action": "work_clinic_doctor", "state": "seated_study", "attachment_pose": "seated_study"},
	{"id": "engineer_01", "position": Vector3(11.0, 0.0, 1.48), "yaw": 0.0, "action": "work_workshop", "state": "work"},
]

const OUTWARD_FACING_LAYOUT := {
	"blacksmith_01": {"screen_horizontal": -1.0, "screen_depth": 1.0, "target_distance": 1.12, "label": "left_front"},
	"cook_01": {"screen_horizontal": 1.0, "screen_depth": 1.0, "target_distance": 1.18, "label": "right_front"},
	"gardener_01": {"screen_horizontal": -1.0, "screen_depth": 0.0, "target_distance": 1.35, "label": "left"},
	"priest_01": {"screen_horizontal": 1.0, "screen_depth": 0.0, "target_distance": 1.25, "label": "right"},
	"doctor_01": {"screen_horizontal": 1.0, "screen_depth": -1.0, "target_distance": 0.42, "label": "right_back"},
	"engineer_01": {"screen_horizontal": -1.0, "screen_depth": -1.0, "target_distance": 1.12, "label": "left_back"},
}

@onready var set_root: Node3D = $Set
@onready var camera: Camera3D = $Camera3D

var _elapsed := 0.0
var _runtime_connected := false
var _motion_ready := false
var _camera_base_transform := Transform3D.IDENTITY
var _horse_base_transform := Transform3D.IDENTITY
var _character_base_transforms := {}
var _tree_base_transforms := {}
var _light_base_energy := {}
var _torch_base_positions := {}
var _fixture_layouts := {}
var _workstation_bindings := {}
var _workstation_targets := {}
var _screen_right_ground := Vector3.RIGHT
var _screen_front_ground := Vector3.FORWARD


func _ready() -> void:
	camera.look_at(Vector3(5.6, 2.05, -1.9), Vector3.UP)
	_configure_outward_workstation_targets()
	_build_main_hall()
	_build_fortification_frame()
	_build_story_props()
	_build_profession_workstations()
	_build_characters()
	_build_horse()
	_build_distant_threat()
	_build_tree_silhouettes()
	call_deferred("_finish_staging")
	set_process(true)


func _process(delta: float) -> void:
	if not _motion_ready:
		return
	_elapsed = fmod(_elapsed + delta, LOOP_SECONDS)
	_apply_motion_at_time(_elapsed)


func configure_runtime_cover() -> void:
	_runtime_connected = true


func debug_set_motion_time(seconds: float) -> void:
	_elapsed = fposmod(seconds, LOOP_SECONDS)
	if _motion_ready:
		_apply_motion_at_time(_elapsed)


func get_preview_snapshot() -> Dictionary:
	return {
		"purpose": "menu_cover_runtime_loop" if _runtime_connected else "menu_cover_review",
		"formal_menu_connected": _runtime_connected,
		"character_count": set_root.get_node("Characters").get_child_count(),
		"character_ids": CHARACTER_LAYOUT.map(func(entry: Dictionary) -> String: return str(entry.id)),
		"enemy_silhouette_count": set_root.get_node("DistantThreat/Enemies").get_child_count(),
		"uses_existing_licensed_assets": true,
		"ground_candidate_textures_connected": false,
		"ground_color": Color(0.12, 0.145, 0.13, 1),
		"camera_fov": camera.fov,
		"menu_safe_zone_ratio": 0.36,
		"motion_loop_seconds": LOOP_SECONDS,
		"motion_ready": _motion_ready,
		"camera_static": camera.transform.is_equal_approx(_camera_base_transform) if _motion_ready else true,
		"motion_time": _elapsed,
		"workstation_count": set_root.get_node("ProfessionWorkstations").get_child_count(),
		"workstation_bindings": _workstation_bindings.duplicate(true),
		"workstation_source": "existing_formal_fixture_assets",
		"ada_staging_unchanged": true,
		"outward_facing_layout": OUTWARD_FACING_LAYOUT.duplicate(true),
		"screen_right_ground": _screen_right_ground,
		"screen_front_ground": _screen_front_ground,
		"outer_tree_count": OUTER_TREE_LAYOUT.size(),
		"outer_tree_zones": ["rear", "rear_mid", "rear_far", "left", "right"],
	}


func _configure_outward_workstation_targets() -> void:
	# The authored cover is viewed through the SubViewport cover crop; its perceived
	# left/right axis is the inverse of Camera3D local +X in this staging setup.
	_screen_right_ground = -Vector3(camera.global_basis.x.x, 0.0, camera.global_basis.x.z).normalized()
	_screen_front_ground = Vector3(camera.global_basis.z.x, 0.0, camera.global_basis.z.z).normalized()
	_workstation_targets.clear()
	for npc_id in OUTWARD_FACING_LAYOUT:
		var config := OUTWARD_FACING_LAYOUT[npc_id] as Dictionary
		var direction := (
			_screen_right_ground * float(config.get("screen_horizontal", 0.0))
			+ _screen_front_ground * float(config.get("screen_depth", 0.0))
		).normalized()
		var target_position := _character_layout_position(npc_id) + direction * float(config.get("target_distance", 1.0))
		target_position.y = 0.0
		_workstation_targets[npc_id] = target_position
	_workstation_targets["stableman_01"] = Vector3(17.1, 0.34, 5.9)


func _character_layout_position(npc_id: String) -> Vector3:
	for entry in CHARACTER_LAYOUT:
		if str(entry.id) == npc_id:
			return entry.position
	return Vector3.ZERO


func _workstation_rotation(npc_id: String, additional_yaw: float = 0.0) -> Vector3:
	var character_position := _character_layout_position(npc_id)
	var target: Vector3 = _workstation_targets.get(npc_id, character_position + Vector3.FORWARD)
	var direction := target - character_position
	direction.y = 0.0
	return Vector3(0.0, rad_to_deg(atan2(-direction.x, -direction.z)) + additional_yaw, 0.0)


func _build_main_hall() -> void:
	var hall := MAIN_HALL_ART_SCRIPT.new() as Node3D
	# A keeps its authored baseline; approved B installs the shared closure itself.
	hall.shell_finish_enabled = false
	hall.name = "MainHallHero"
	hall.position = Vector3(8.4, 0.0, -8.8)
	set_root.add_child(hall)


func _build_fortification_frame() -> void:
	var fortification := FORTIFICATION_ART_SCRIPT.new()
	fortification.name = "FortificationFrame"
	fortification.configure({
		"wall_segments": [
			{"id": "cover_back", "from": [-13.0, -20.0], "to": [27.0, -20.0]},
			{"id": "cover_left", "from": [-13.0, -20.0], "to": [-13.0, 10.0]},
			{"id": "cover_right", "from": [27.0, -20.0], "to": [27.0, 10.0]},
		],
	})
	set_root.add_child(fortification)


func _build_story_props() -> void:
	var props := Node3D.new()
	props.name = "StoryProps"
	set_root.add_child(props)
	_add_scene(props, WORKBENCH_SCENE, "WarTable", Vector3(8.2, 0.0, 4.0), Vector3(0.0, 90.0, 0.0), Vector3.ONE)
	_add_scene(props, BOOK_STAND_SCENE, "OrderStand", Vector3(8.15, 1.14, 3.98), Vector3(0.0, 180.0, 0.0), Vector3.ONE * 0.82)
	_add_scene(props, BOOK_SCENE, "SealedOrder", Vector3(8.15, 1.43, 3.93), Vector3(0.0, 180.0, -7.0), Vector3.ONE * 0.88)
	_add_scene(props, SWORD_SCENE, "UnclaimedSword", Vector3(9.35, 1.17, 4.2), Vector3(83.0, 18.0, 4.0), Vector3.ONE * 0.92)
	_add_scene(props, SHIELD_SCENE, "UnclaimedShield", Vector3(7.05, 0.38, 4.15), Vector3(8.0, 42.0, -70.0), Vector3.ONE * 0.86)
	_add_scene(props, CRATE_SCENE, "SupplyCrate", Vector3(15.1, 0.0, 3.4), Vector3(0.0, -18.0, 0.0), Vector3.ONE)
	_add_scene(props, BAG_SCENE, "SupplyBag", Vector3(14.5, 0.0, 4.6), Vector3(0.0, 24.0, 0.0), Vector3.ONE)
	_add_scene(props, BARREL_SCENE, "SupplyBarrel", Vector3(15.7, 0.0, 4.7), Vector3.ZERO, Vector3.ONE)
	_add_lantern(props, Vector3(3.0, 0.0, 1.2), 0.92)
	_add_lantern(props, Vector3(13.8, 0.0, 0.0), 0.82)


func _build_profession_workstations() -> void:
	_load_fixture_layouts()
	var workstations := Node3D.new()
	workstations.name = "ProfessionWorkstations"
	workstations.set_meta("presentation_only", true)
	set_root.add_child(workstations)
	var fixture_factory := STATION_LAYOUT_CONTROLLER_SCRIPT.new()
	var dining_factory := DINING_HALL_ART_SCRIPT.new()

	var altar_fixture := _get_fixture("chapel", "chapel_altar")
	var altar_group := _add_primitive_fixture(
		workstations, fixture_factory, "chapel", altar_fixture, "MarcelChapelAltar",
		_workstation_targets.priest_01, _workstation_rotation("priest_01"), Vector3.ONE * 0.72
	)
	for runner_name in ["AisleRunner", "AisleRunnerLeftEdge", "AisleRunnerRightEdge"]:
		var runner := altar_group.find_child(runner_name, true, false)
		if runner != null:
			runner.queue_free()
	_bind_workstation("priest_01", altar_group, "chapel_altar_with_cross")

	var clinic_table_fixture := _get_fixture("clinic", "doctor_desk_01_table")
	var clinic_table := _add_imported_fixture(
		workstations, fixture_factory, "clinic", clinic_table_fixture, "LinaClinicDesk",
		_workstation_targets.doctor_01, _workstation_rotation("doctor_01")
	)
	_bind_workstation("doctor_01", clinic_table, "clinic_desk_and_seated_study")
	var chair_fixture := _get_fixture("clinic", "doctor_desk_01_chair")
	var lina_position := _character_layout_position("doctor_01")
	var lina_forward: Vector3 = _workstation_targets.doctor_01 - lina_position
	lina_forward.y = 0.0
	lina_forward = lina_forward.normalized()
	var chair_position: Vector3 = lina_position - lina_forward * 0.52
	chair_position.y = 0.0
	_add_imported_fixture(
		workstations, fixture_factory, "clinic", chair_fixture, "LinaClinicChair",
		chair_position, _workstation_rotation("doctor_01", 180.0)
	)

	var cauldron_fixture := _get_fixture("dining_hall", "kitchen_station_01_cauldron")
	var cauldron := _add_imported_fixture(
		workstations, fixture_factory, "dining_hall", cauldron_fixture, "BrunoActiveCauldron",
		_workstation_targets.cook_01, _workstation_rotation("cook_01")
	)
	var ember := cauldron.find_child("Ember", true, false) as MeshInstance3D
	if ember != null:
		ember.visible = true
	_add_active_cauldron_fx(dining_factory, cauldron)
	_bind_workstation("cook_01", cauldron, "active_dining_cauldron_with_food_and_steam")

	var garden_fixture := _get_fixture("garden", "garden_plot_01_bed")
	var garden_bed := _add_primitive_fixture(
		workstations, fixture_factory, "garden", garden_fixture, "IvoGardenBed",
		_workstation_targets.gardener_01, _workstation_rotation("gardener_01"), Vector3.ONE * 0.72
	)
	_bind_workstation("gardener_01", garden_bed, "formal_garden_bed")

	var anvil_fixture := _get_fixture("blacksmith", "forge_01_anvil")
	var anvil := _add_imported_fixture(
		workstations, fixture_factory, "blacksmith", anvil_fixture, "GlenAnvil",
		_workstation_targets.blacksmith_01, _workstation_rotation("blacksmith_01")
	)
	var hot_metal := anvil.find_child("HotMetal", true, false) as MeshInstance3D
	if hot_metal != null:
		hot_metal.visible = true
	_bind_workstation("blacksmith_01", anvil, "formal_blacksmith_anvil")

	var workshop_fixture := _get_fixture("workshop", "workbench_02_engineering_table")
	var workshop_bench := _add_imported_fixture(
		workstations, fixture_factory, "workshop", workshop_fixture, "OwenEngineeringWorkbench",
		_workstation_targets.engineer_01, _workstation_rotation("engineer_01")
	)
	_bind_workstation("engineer_01", workshop_bench, "formal_mechanism_workbench")
	_workstation_bindings["stableman_01"] = {
		"node": "../StableHorse",
		"kind": "existing_cover_horse",
		"target": _workstation_targets.stableman_01,
	}

	fixture_factory.free()
	dining_factory.free()


func _load_fixture_layouts() -> void:
	var file := FileAccess.open(FIXTURE_LAYOUTS_PATH, FileAccess.READ)
	if file == null:
		push_error("MenuCoverPreview: cannot open formal fixture layouts")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_fixture_layouts = parsed


func _get_fixture(building_id: String, fixture_id: String) -> Dictionary:
	var buildings := _fixture_layouts.get("buildings", {}) as Dictionary
	var building := buildings.get(building_id, {}) as Dictionary
	for raw_fixture in building.get("fixtures", []):
		if raw_fixture is Dictionary and str(raw_fixture.get("id", "")) == fixture_id:
			return (raw_fixture as Dictionary).duplicate(true)
	push_error("MenuCoverPreview: missing fixture %s/%s" % [building_id, fixture_id])
	return {}


func _add_imported_fixture(
	parent: Node3D,
	fixture_factory: Node,
	building_id: String,
	fixture: Dictionary,
	node_name: String,
	position: Vector3,
	rotation_degrees: Vector3
) -> Node3D:
	var packed := load(str(fixture.get("asset_path", ""))) as PackedScene
	var visual := packed.instantiate() as Node3D
	visual.name = node_name
	visual.position = position + Vector3.UP * float(fixture.get("visual_y", 0.0))
	visual.rotation_degrees = rotation_degrees
	visual.scale = _fixture_vector3(fixture.get("visual_scale", [1.0, 1.0, 1.0]))
	visual.set_meta("presentation_only", true)
	visual.set_meta("source_fixture_id", str(fixture.get("id", "")))
	visual.set_meta("source_building_id", building_id)
	parent.add_child(visual)
	fixture_factory.call("_decorate_fixture_visual", visual, fixture)
	return visual


func _add_primitive_fixture(
	parent: Node3D,
	fixture_factory: Node,
	building_id: String,
	fixture: Dictionary,
	node_name: String,
	position: Vector3,
	rotation_degrees: Vector3,
	visual_scale: Vector3
) -> Node3D:
	var group := Node3D.new()
	group.name = node_name
	group.position = position
	group.rotation_degrees = rotation_degrees
	group.scale = visual_scale
	group.set_meta("presentation_only", true)
	group.set_meta("source_fixture_id", str(fixture.get("id", "")))
	group.set_meta("source_building_id", building_id)
	parent.add_child(group)
	var local_fixture := fixture.duplicate(true)
	local_fixture["center"] = [0.0, 0.0]
	fixture_factory.call("_build_primitive_fixture_visual", group, building_id, local_fixture)
	return group


func _add_active_cauldron_fx(dining_factory: Node, cauldron: Node3D) -> void:
	var fx_root := Node3D.new()
	fx_root.name = "CoverKitchenWorkFX"
	cauldron.add_child(fx_root)
	dining_factory.call("_add_kitchen_station_work_fx", fx_root, {
		"node_name": "ActivePotFX",
		"workstation_id": "dining_kitchen_station_01",
		"chimney_name": "",
		"x": 0.0,
		"required_level": 1,
	})
	var station := fx_root.get_node("ActivePotFX") as Node3D
	station.position = Vector3(0.0, -0.18, 0.0)
	(station.get_node("FireVisuals") as Node3D).visible = true
	(station.get_node("FoodVisuals") as Node3D).visible = true
	var pot_steam := station.get_node("PotSteam") as GPUParticles3D
	pot_steam.emitting = true
	var chimney_smoke := station.get_node("ChimneySmoke") as GPUParticles3D
	chimney_smoke.emitting = false
	chimney_smoke.visible = false
	var fire_light := station.get_node("FireLight") as OmniLight3D
	fire_light.light_energy = 2.1


func _bind_workstation(npc_id: String, workstation: Node3D, kind: String) -> void:
	_workstation_bindings[npc_id] = {
		"node": str(workstation.get_path()),
		"kind": kind,
		"target": _workstation_targets.get(npc_id, workstation.position),
	}


func _fixture_vector3(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ONE


func _build_characters() -> void:
	var characters := Node3D.new()
	characters.name = "Characters"
	set_root.add_child(characters)
	for entry in CHARACTER_LAYOUT:
		var scene := CHARACTER_SCENES[str(entry.id)] as PackedScene
		var character := scene.instantiate() as Node3D
		character.name = str(entry.id)
		character.position = entry.position
		character.rotation_degrees.y = float(entry.yaw)
		characters.add_child(character)
		character.set_meta("cover_action", str(entry.action))
		character.set_meta("cover_state", str(entry.state))


func _build_horse() -> void:
	var horse := _add_scene(set_root, HORSE_SCENE, "StableHorse", Vector3(17.1, 0.34, 5.9), Vector3(0.0, -112.0, 0.0), Vector3.ONE * 0.92)
	horse.set_meta("presentation_only", true)


func _build_distant_threat() -> void:
	var threat := Node3D.new()
	threat.name = "DistantThreat"
	set_root.add_child(threat)
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	threat.add_child(enemies)
	var enemy_positions := [
		Vector3(17.8, 0.0, -26.4), Vector3(20.1, 0.0, -27.2), Vector3(22.3, 0.0, -25.8),
		Vector3(24.1, 0.0, -27.6), Vector3(15.5, 0.0, -28.2),
	]
	for index in enemy_positions.size():
		var enemy := ENEMY_SCENE.instantiate() as Node3D
		enemy.name = "EnemySilhouette%02d" % (index + 1)
		enemy.position = enemy_positions[index]
		enemy.rotation_degrees.y = 180.0 + float(index - 2) * 8.0
		enemy.scale = Vector3.ONE * 0.86
		enemies.add_child(enemy)
		_add_threat_glow(threat, enemy.position + Vector3(0.35, 2.15, 0.15), index)


func _build_tree_silhouettes() -> void:
	var trees := Node3D.new()
	trees.name = "TreeSilhouettes"
	trees.set_meta("presentation_only", true)
	trees.set_meta("placement_zone", "outside_station_walls")
	set_root.add_child(trees)
	for index in OUTER_TREE_LAYOUT.size():
		var entry := OUTER_TREE_LAYOUT[index] as Dictionary
		var tree := _add_scene(
			trees,
			TREE_SCENE,
			"Tree%02d" % (index + 1),
			entry.position,
			Vector3(0.0, float(entry.yaw), 0.0),
			Vector3.ONE * float(entry.scale)
		)
		tree.set_meta("outside_station", true)
		tree.set_meta("tree_zone", str(entry.zone))


func _finish_staging() -> void:
	var hall := set_root.get_node_or_null("MainHallHero")
	if hall != null and hall.has_method("debug_force_visual_level"):
		hall.call("debug_force_visual_level", 3)
	var fortification := set_root.get_node_or_null("FortificationFrame")
	if fortification != null and fortification.has_method("debug_force_visual_level"):
		fortification.call("debug_force_visual_level", 1)
	var characters := set_root.get_node("Characters")
	for entry in CHARACTER_LAYOUT:
		var character := characters.get_node_or_null(str(entry.id))
		if character == null:
			continue
		var attachment_pose := str(entry.get("attachment_pose", ""))
		if not attachment_pose.is_empty() and character.has_method("set_spatial_attachment_pose"):
			character.call("set_spatial_attachment_pose", attachment_pose)
		if _workstation_targets.has(str(entry.id)):
			_face_character_to_target(character as Node3D, _workstation_targets[str(entry.id)])
		var action_id := str(entry.action)
		var state_name := str(entry.state)
		if not action_id.is_empty() and character.has_method("debug_force_action_preview"):
			character.call("debug_force_action_preview", action_id, state_name)
		elif character.has_method("debug_force_animation_state"):
			character.call("debug_force_animation_state", state_name)
		if str(entry.id) == "veteran_deputy_01" and character.has_method("debug_set_equipment_preview"):
			character.call("debug_set_equipment_preview", "sword_shield", true)
	for enemy in set_root.get_node("DistantThreat/Enemies").get_children():
		if enemy.has_method("debug_force_animation_state"):
			enemy.call("debug_force_animation_state", "idle")
	_capture_motion_bases()
	_motion_ready = true
	_apply_motion_at_time(_elapsed)


func _face_character_to_target(character: Node3D, target: Vector3) -> void:
	var direction := target - character.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return
	character.rotation_degrees.y = 0.0
	if character.has_method("set_facing_direction"):
		character.call("set_facing_direction", direction.normalized())


func _capture_motion_bases() -> void:
	_camera_base_transform = camera.transform
	var horse := set_root.get_node_or_null("StableHorse") as Node3D
	if horse != null:
		_horse_base_transform = horse.transform
	_character_base_transforms.clear()
	for character in set_root.get_node("Characters").get_children():
		_character_base_transforms[character.get_instance_id()] = (character as Node3D).transform
	_tree_base_transforms.clear()
	for tree in set_root.get_node("TreeSilhouettes").get_children():
		_tree_base_transforms[tree.get_instance_id()] = (tree as Node3D).transform
	_light_base_energy.clear()
	for light in find_children("*", "OmniLight3D", true, false):
		_light_base_energy[light.get_instance_id()] = (light as OmniLight3D).light_energy
	_torch_base_positions.clear()
	for torch in set_root.get_node("DistantThreat").get_children():
		if torch is MeshInstance3D and str(torch.name).begins_with("EnemyTorch"):
			_torch_base_positions[torch.get_instance_id()] = (torch as Node3D).position


func _apply_motion_at_time(seconds: float) -> void:
	var phase := seconds / LOOP_SECONDS * TAU
	var horse := set_root.get_node_or_null("StableHorse") as Node3D
	if horse != null:
		horse.transform = _horse_base_transform
		horse.position.y += sin(phase) * 0.025
		horse.rotation_degrees.y += sin(phase * 2.0 + 0.4) * 0.65
	var characters := set_root.get_node("Characters").get_children()
	for index in characters.size():
		var character := characters[index] as Node3D
		var base_transform: Transform3D = _character_base_transforms.get(character.get_instance_id(), character.transform)
		character.transform = base_transform
		character.position.y += sin(phase * 2.0 + float(index) * 0.83) * 0.012
	var trees := set_root.get_node("TreeSilhouettes").get_children()
	for index in trees.size():
		var tree := trees[index] as Node3D
		var base_transform: Transform3D = _tree_base_transforms.get(tree.get_instance_id(), tree.transform)
		tree.transform = base_transform
		tree.rotation_degrees.z += sin(phase + float(index) * 1.7) * 0.42
	for light in find_children("*", "OmniLight3D", true, false):
		var omni := light as OmniLight3D
		var base_energy := float(_light_base_energy.get(omni.get_instance_id(), omni.light_energy))
		var light_phase := phase * 3.0 + float(omni.get_instance_id() % 17) * 0.37
		omni.light_energy = base_energy * (1.0 + sin(light_phase) * 0.055 + sin(light_phase * 2.0 + 0.8) * 0.025)
	for torch in set_root.get_node("DistantThreat").get_children():
		if not (torch is MeshInstance3D) or not str(torch.name).begins_with("EnemyTorch"):
			continue
		var torch_node := torch as Node3D
		var base_position: Vector3 = _torch_base_positions.get(torch_node.get_instance_id(), torch_node.position)
		torch_node.position = base_position + Vector3(
			sin(phase * 2.0 + float(torch_node.get_index())) * 0.025,
			sin(phase * 3.0 + float(torch_node.get_index())) * 0.035,
			0.0
		)


func _add_scene(parent: Node, scene: PackedScene, node_name: String, position: Vector3, rotation_degrees: Vector3, scale: Vector3) -> Node3D:
	var instance := scene.instantiate() as Node3D
	instance.name = node_name
	instance.position = position
	instance.rotation_degrees = rotation_degrees
	instance.scale = scale
	parent.add_child(instance)
	return instance


func _add_lantern(parent: Node, position: Vector3, energy: float) -> void:
	var root := _add_scene(parent, LANTERN_SCENE, "CourtyardLantern", position, Vector3.ZERO, Vector3.ONE)
	var light := OmniLight3D.new()
	light.name = "WarmLight"
	light.position = Vector3(0.0, 2.25, 0.0)
	light.light_color = Color(1.0, 0.46, 0.17)
	light.light_energy = energy * 2.25
	light.omni_range = 13.5
	light.shadow_enabled = true
	root.add_child(light)


func _add_threat_glow(parent: Node3D, position: Vector3, index: int) -> void:
	var ember_material := StandardMaterial3D.new()
	ember_material.albedo_color = Color(0.92, 0.18, 0.045)
	ember_material.emission_enabled = true
	ember_material.emission = Color(1.0, 0.08, 0.01)
	ember_material.emission_energy_multiplier = 6.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.material = ember_material
	var ember := MeshInstance3D.new()
	ember.name = "EnemyTorch%02d" % (index + 1)
	ember.position = position
	ember.mesh = mesh
	parent.add_child(ember)
	var light := OmniLight3D.new()
	light.name = "EnemyFireGlow%02d" % (index + 1)
	light.position = position
	light.light_color = Color(1.0, 0.13, 0.02)
	light.light_energy = 1.7
	light.omni_range = 7.5
	light.shadow_enabled = false
	parent.add_child(light)
