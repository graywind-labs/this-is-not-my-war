extends SceneTree

const MAIN_SCENE := "res://scenes/main/Main.tscn"

const BUILDING_CURVES := {
	"tavern": {
		"type": "brew",
		"name_prefix": "酿酒位",
		"counts": [2, 2, 3]
	},
	"workshop": {
		"type": "engineering",
		"name_prefix": "工程位",
		"counts": [2, 2, 3]
	},
	"blacksmith": {
		"type": "forge",
		"name_prefix": "锻造位",
		"counts": [2, 2, 3]
	},
	"dining_hall": {
		"type": "dining_kitchen_station",
		"name_prefix": "灶台",
		"counts": [2, 2, 3],
		"secondary_type": "dining_seat",
		"secondary_counts": [10, 10, 10]
	},
	"clinic": {
		"type": "clinic_doctor_station",
		"name_prefix": "诊疗位",
		"counts": [2, 2, 2],
		"secondary_type": "clinic_patient_bed",
		"secondary_counts": [2, 3, 4]
	},
	"stable": {
		"type": "horse_care",
		"name_prefix": "照料位",
		"counts": [2, 2, 3]
	},
	"garden": {
		"type": "farm",
		"name_prefix": "耕作位",
		"counts": [2, 2, 3]
	}
}


func _init() -> void:
	var main_scene := load(MAIN_SCENE) as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	if building_system == null or resource_system == null:
		_fail("Required building systems are missing")
		return

	for resource_id in ["wood", "stone", "iron"]:
		var capacity := int(resource_system.get_resource_capacity(resource_id))
		var current := int(resource_system.get_resource(resource_id))
		var fill_amount := capacity - current
		if fill_amount > 0 and not resource_system.add_resource(resource_id, fill_amount):
			_fail("Failed to fill %s to its current storage capacity" % resource_id)
			return

	for raw_building_id in BUILDING_CURVES.keys():
		var building_id := str(raw_building_id)
		var curve: Dictionary = BUILDING_CURVES[building_id]
		if not _verify_level(building_system, building_id, curve, 1):
			return
		if not _verify_two_workers_and_full_rejection(building_system, building_id, str(curve.get("type", ""))):
			return

		for target_level in [2, 3]:
			if not building_system.upgrade_building(building_id):
				_fail("%s failed to start level-%d upgrade" % [building_id, target_level])
				return
			building_system._on_logical_time_tick(1000000.0, 1.0)
			if int(building_system.get_building(building_id).get("level", 0)) != target_level:
				_fail("%s did not complete level-%d upgrade" % [building_id, target_level])
				return
			if not _verify_level(building_system, building_id, curve, target_level):
				return

	print("T0104 initial dual workstations and upgrade curves verification passed.")
	quit(0)


func _verify_level(building_system: Node, building_id: String, curve: Dictionary, level: int) -> bool:
	var building: Dictionary = building_system.get_building(building_id)
	var workstations: Array = building.get("workstations", [])
	var station_type := str(curve.get("type", ""))
	var expected_counts: Array = curve.get("counts", [])
	var expected_count := int(expected_counts[level - 1])
	var stations := _stations_of_type(workstations, station_type)
	if stations.size() != expected_count:
		_fail("%s level %d expected %d main workstations, got %d" % [
			building_id, level, expected_count, stations.size()
		])
		return false
	if not _verify_unique_ids_and_numbered_names(
		stations,
		str(curve.get("name_prefix", "")),
		building_id,
		level
	):
		return false

	var secondary_type := str(curve.get("secondary_type", ""))
	if not secondary_type.is_empty():
		var secondary_counts: Array = curve.get("secondary_counts", [])
		var expected_secondary := int(secondary_counts[level - 1])
		var actual_secondary := _stations_of_type(workstations, secondary_type).size()
		if actual_secondary != expected_secondary:
			_fail("%s level %d expected %d %s positions, got %d" % [
				building_id, level, expected_secondary, secondary_type, actual_secondary
			])
			return false
	return true


func _verify_two_workers_and_full_rejection(
	building_system: Node,
	building_id: String,
	station_type: String
) -> bool:
	var claimant_a := "veteran_deputy_01"
	var claimant_b := "stableman_01"
	var claimant_c := "cook_01"
	var claim_a: Dictionary = building_system.claim_workstation(building_id, claimant_a, station_type)
	var claim_b: Dictionary = building_system.claim_workstation(building_id, claimant_b, station_type)
	if not bool(claim_a.get("ok", false)) or not bool(claim_b.get("ok", false)):
		_fail("%s should accept two simultaneous main-workstation claims" % building_id)
		return false
	if str(claim_a.get("workstation_id", "")) == str(claim_b.get("workstation_id", "")):
		_fail("%s assigned the same workstation to two claimants" % building_id)
		return false
	var claim_c: Dictionary = building_system.claim_workstation(building_id, claimant_c, station_type)
	if bool(claim_c.get("ok", false)) or str(claim_c.get("reason", "")) != "no_free_workstation":
		_fail("%s should reject the third level-one claimant" % building_id)
		return false
	building_system.release_workstation(
		building_id,
		claimant_a,
		str(claim_a.get("workstation_id", ""))
	)
	building_system.release_workstation(
		building_id,
		claimant_b,
		str(claim_b.get("workstation_id", ""))
	)
	return true


func _verify_unique_ids_and_numbered_names(
	stations: Array,
	name_prefix: String,
	building_id: String,
	level: int
) -> bool:
	var seen_ids := {}
	for index in range(stations.size()):
		var station: Dictionary = stations[index]
		var workstation_id := str(station.get("id", ""))
		if workstation_id.is_empty() or seen_ids.has(workstation_id):
			_fail("%s level %d has an empty or duplicate workstation id" % [building_id, level])
			return false
		seen_ids[workstation_id] = true
		var expected_name := "%s%d" % [name_prefix, index + 1]
		if str(station.get("name", "")) != expected_name:
			_fail("%s level %d expected '%s', got '%s'" % [
				building_id, level, expected_name, str(station.get("name", ""))
			])
			return false
	return true


func _stations_of_type(workstations: Array, station_type: String) -> Array:
	var result: Array = []
	for raw_workstation in workstations:
		if raw_workstation is Dictionary and str(raw_workstation.get("type", "")) == station_type:
			result.append(raw_workstation)
	return result


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
