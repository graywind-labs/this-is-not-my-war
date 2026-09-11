extends Node

signal recipe_catalog_loaded(recipe_count: int)
signal project_changed(building_id: String, project_snapshot: Dictionary)
signal pending_outputs_changed(building_id: String, pending_snapshot: Dictionary)
signal work_cycle_progress_changed(building_id: String, npc_id: String, progress: float)

const CRAFTING_RECIPES_FILE := "crafting_recipes.json"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const ACTION_SYSTEM_PATH := "/root/Main/Systems/ActionSystem"
const EQUIPMENT_SYSTEM_PATH := "/root/Main/Systems/EquipmentSystem"
const DEFENSE_DEVICE_SYSTEM_PATH := "/root/Main/Systems/DefenseDeviceSystem"
const SPECIAL_STATE_SECTION := "production"
const PROGRESS_EPSILON := 0.000001
const SUPPORTED_BUILDING_IDS := ["blacksmith", "workshop"]
const EXPECTED_RECIPE_IDS := [
	"craft_iron_helmet",
	"craft_iron_bracers",
	"craft_polearm",
	"craft_iron_greaves",
	"craft_sword_shield",
	"craft_mail_chest",
	"craft_bow",
	"craft_crossbow",
	"craft_wall_ballista",
	"craft_wall_arrow_tower"
]

var _recipes: Dictionary = {}
var _recipe_ids_by_building: Dictionary = {}
var _projects: Dictionary = {}
var _initial_projects: Dictionary = {}
var _pending_outputs: Dictionary = {}
var _latest_pending_output_item_ids: Dictionary = {}
var _active_cycles: Dictionary = {}
var _stage_commit_locks: Dictionary = {}
var _pending_collection_locks: Dictionary = {}
var _load_errors: Array[String] = []
var _initialized := false


func _ready() -> void:
	initialize()


func initialize() -> void:
	_recipes.clear()
	_recipe_ids_by_building.clear()
	_projects.clear()
	_initial_projects.clear()
	_pending_outputs.clear()
	_latest_pending_output_item_ids.clear()
	_active_cycles.clear()
	_stage_commit_locks.clear()
	_pending_collection_locks.clear()
	_load_errors.clear()
	_initialized = false

	for raw_building_id in SUPPORTED_BUILDING_IDS:
		var building_id := str(raw_building_id)
		_recipe_ids_by_building[building_id] = []
		_projects[building_id] = _make_empty_project(building_id)
		_pending_outputs[building_id] = {}
		_latest_pending_output_item_ids[building_id] = ""
		_active_cycles[building_id] = {}

	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		_record_load_error("CraftingSystem requires ConfigLoader autoload.")
		return

	var loaded_data: Variant = config_loader.load_data_file(CRAFTING_RECIPES_FILE, {})
	var raw_recipes: Variant = loaded_data
	if loaded_data is Dictionary:
		raw_recipes = loaded_data.get("recipes", [])
	if not raw_recipes is Array:
		_record_load_error("Crafting recipes must be an array or a dictionary containing recipes.")
		return

	for raw_recipe in raw_recipes:
		if not raw_recipe is Dictionary:
			_record_load_error("Skipped crafting recipe because it is not a dictionary.")
			continue
		var recipe := _normalize_recipe(raw_recipe)
		if recipe.is_empty():
			continue
		var recipe_id := str(recipe.get("id", ""))
		if _recipes.has(recipe_id):
			_record_load_error("Duplicate crafting recipe id: %s" % recipe_id)
			continue
		_recipes[recipe_id] = recipe
		var building_id := str(recipe.get("building_id", ""))
		if bool(recipe.get("available", true)):
			var building_recipe_ids: Array = _recipe_ids_by_building.get(building_id, [])
			building_recipe_ids.append(recipe_id)
			_recipe_ids_by_building[building_id] = building_recipe_ids

	for raw_building_id in SUPPORTED_BUILDING_IDS:
		var building_id := str(raw_building_id)
		var building_recipe_ids: Array = _recipe_ids_by_building.get(building_id, [])
		building_recipe_ids.sort_custom(_compare_recipe_ids)
		_recipe_ids_by_building[building_id] = building_recipe_ids

	_validate_expected_catalog()
	if loaded_data is Dictionary:
		_apply_initial_projects(loaded_data.get("initial_projects", []))
	_initialized = _load_errors.is_empty()
	recipe_catalog_loaded.emit(_recipes.size())
	publish_all_special_states()


func get_recipe_ids_for_building(building_id: String) -> Array[String]:
	var result: Array[String] = []
	for raw_recipe_id in _recipe_ids_by_building.get(building_id, []):
		result.append(str(raw_recipe_id))
	return result


func get_recipe(recipe_id: String) -> Dictionary:
	if not _recipes.has(recipe_id):
		return {}
	return (_recipes[recipe_id] as Dictionary).duplicate(true)


func get_recipes_for_building(building_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe_id in get_recipe_ids_for_building(building_id):
		var recipe := get_recipe(recipe_id)
		if not recipe.is_empty():
			result.append(recipe)
	return result


func get_project_snapshot(building_id: String) -> Dictionary:
	if not _projects.has(building_id):
		return {}

	var project: Dictionary = _projects[building_id]
	var target_recipe_id := str(project.get("target_recipe_id", ""))
	var recipe := get_recipe(target_recipe_id)
	var total_stages := int(project.get("total_stages", 0))
	var completed_stages := clampi(int(project.get("completed_stages", 0)), 0, total_stages)
	var current_stage := _get_stage(recipe, completed_stages)
	var active_workers := _get_active_worker_snapshots(building_id, int(project.get("revision", 0)), target_recipe_id)
	var partial_progress := _calculate_partial_progress(active_workers, total_stages - completed_stages)
	var progress := 0.0
	if total_stages > 0:
		progress = clampf((float(completed_stages) + partial_progress) / float(total_stages), 0.0, 1.0)

	return {
		"building_id": building_id,
		"target_recipe_id": target_recipe_id,
		"recipe_id": target_recipe_id,
		"target_item_id": str(project.get("target_item_id", "")),
		"target_name": str(project.get("target_name", "")),
		"revision": int(project.get("revision", 0)),
		"project_revision": int(project.get("revision", 0)),
		"completed_stages": completed_stages,
		"total_stages": total_stages,
		"current_stage_index": completed_stages + 1 if not current_stage.is_empty() else 0,
		"current_stage_id": str(current_stage.get("id", "")),
		"current_stage_name": str(current_stage.get("name", "")),
		"current_stage_cost": (current_stage.get("cost", {}) as Dictionary).duplicate(true),
		"progress": progress,
		"partial_progress": partial_progress,
		"active_workers": active_workers,
		"stock_amount": _get_stock_amount(str(project.get("target_item_id", ""))),
		"pending_outputs": get_pending_outputs(building_id),
		"pending_output_total": get_pending_output_total(building_id),
		"target_pending_amount": int(get_pending_outputs(building_id).get(str(project.get("target_item_id", "")), 0))
	}


func get_all_project_snapshots() -> Dictionary:
	var snapshots := {}
	for raw_building_id in SUPPORTED_BUILDING_IDS:
		var building_id := str(raw_building_id)
		snapshots[building_id] = get_project_snapshot(building_id)
	return snapshots


func get_pending_outputs(building_id: String) -> Dictionary:
	if not _pending_outputs.has(building_id):
		return {}
	return (_pending_outputs[building_id] as Dictionary).duplicate(true)


func get_pending_output_total(building_id: String) -> int:
	var total := 0
	for amount in get_pending_outputs(building_id).values():
		total += maxi(0, int(amount))
	return total


func get_latest_pending_output_item_id(building_id: String) -> String:
	var item_id := str(_latest_pending_output_item_ids.get(building_id, ""))
	if item_id.is_empty() or int(get_pending_outputs(building_id).get(item_id, 0)) <= 0:
		return ""
	return item_id


func get_latest_pending_output_entry(building_id: String) -> Dictionary:
	var item_id := get_latest_pending_output_item_id(building_id)
	if item_id.is_empty():
		return {}
	var presentation := get_output_item_presentation(item_id)
	return {
		"building_id": building_id,
		"item_id": item_id,
		"name": str(presentation.get("name", item_id)),
		"amount": maxi(0, int(get_pending_outputs(building_id).get(item_id, 0)))
	}


func get_pending_output_entries(building_id: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var pending := get_pending_outputs(building_id)
	for raw_item_id in pending.keys():
		var item_id := str(raw_item_id)
		var amount := maxi(0, int(pending[raw_item_id]))
		if amount <= 0:
			continue
		var presentation := get_output_item_presentation(item_id)
		entries.append({
			"building_id": building_id,
			"item_id": item_id,
			"resource_id": item_id,
			"name": str(presentation.get("name", item_id)),
			"icon_path": str(presentation.get("icon_path", "")),
			"amount": amount,
			"ui_order": int(presentation.get("ui_order", 9999))
		})
	entries.sort_custom(_compare_pending_entries)
	return entries


func debug_complete_product(building_id: String, recipe_id: String) -> Dictionary:
	if not _pending_outputs.has(building_id):
		return {"ok": false, "reason": "unsupported_building", "building_id": building_id, "recipe_id": recipe_id}
	var recipe := get_recipe(recipe_id)
	if recipe.is_empty():
		return {"ok": false, "reason": "unknown_recipe", "building_id": building_id, "recipe_id": recipe_id}
	if not bool(recipe.get("available", true)):
		return {"ok": false, "reason": "recipe_unavailable", "building_id": building_id, "recipe_id": recipe_id}
	if str(recipe.get("building_id", "")) != building_id:
		return {"ok": false, "reason": "recipe_building_mismatch", "building_id": building_id, "recipe_id": recipe_id}
	var item_id := str(recipe.get("output_item_id", ""))
	var amount := maxi(1, int(recipe.get("output_amount", 1)))
	if item_id.is_empty():
		return {"ok": false, "reason": "recipe_output_missing", "building_id": building_id, "recipe_id": recipe_id}
	var pending: Dictionary = _pending_outputs.get(building_id, {})
	pending[item_id] = int(pending.get(item_id, 0)) + amount
	_pending_outputs[building_id] = pending
	_latest_pending_output_item_ids[building_id] = item_id
	_publish_special_state(building_id)
	pending_outputs_changed.emit(building_id, get_pending_outputs(building_id))
	return {
		"ok": true,
		"reason": "debug_product_completed",
		"building_id": building_id,
		"recipe_id": recipe_id,
		"item_id": item_id,
		"amount": amount,
		"pending_outputs": get_pending_outputs(building_id),
		"latest_pending_output": get_latest_pending_output_entry(building_id),
	}


func get_output_item_presentation(item_id: String) -> Dictionary:
	var fallback_name := item_id
	var fallback_order := 9999
	for recipe_id in _recipes.keys():
		var recipe: Dictionary = _recipes[recipe_id]
		if str(recipe.get("output_item_id", "")) != item_id:
			continue
		fallback_name = str(recipe.get("name", item_id))
		fallback_order = int(recipe.get("ui_order", 9999))
		break

	var equipment_system := get_node_or_null(EQUIPMENT_SYSTEM_PATH)
	if equipment_system != null:
		for weapon_id in equipment_system.get_weapon_ids() if equipment_system.has_method("get_weapon_ids") else []:
			var weapon: Dictionary = equipment_system.get_weapon_def(str(weapon_id))
			if str(weapon.get("source_resource_id", "")) == item_id:
				return {"name": str(weapon.get("name", fallback_name)), "icon_path": str(weapon.get("icon", "")), "ui_order": fallback_order}
		for armor_id in equipment_system.get_armor_ids() if equipment_system.has_method("get_armor_ids") else []:
			var armor: Dictionary = equipment_system.get_armor_def(str(armor_id))
			if str(armor.get("source_resource_id", "")) == item_id:
				return {"name": str(armor.get("name", fallback_name)), "icon_path": str(armor.get("icon", "")), "ui_order": fallback_order}

	var defense_device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
	if defense_device_system != null and defense_device_system.has_method("get_device_ids"):
		for device_id in defense_device_system.get_device_ids():
			var device: Dictionary = defense_device_system.get_device_definition(str(device_id))
			var inventory_cost: Dictionary = device.get("inventory_cost", {}) if device.get("inventory_cost", {}) is Dictionary else {}
			if not inventory_cost.has(item_id):
				continue
			var presentation: Dictionary = device.get("presentation", {}) if device.get("presentation", {}) is Dictionary else {}
			return {"name": str(device.get("name", fallback_name)), "icon_path": str(presentation.get("icon", "")), "ui_order": fallback_order}
	return {"name": fallback_name, "icon_path": "", "ui_order": fallback_order}


func collect_pending_outputs(building_id: String) -> Dictionary:
	var result := {
		"ok": false,
		"reason": "unknown",
		"building_id": building_id,
		"collected_resources": {},
		"collected_entries": [],
		"remaining_pending_outputs": get_pending_outputs(building_id)
	}
	if not _pending_outputs.has(building_id):
		result["reason"] = "unsupported_building"
		return result
	if bool(_pending_collection_locks.get(building_id, false)) or bool(_stage_commit_locks.get(building_id, false)):
		result["reason"] = "pending_output_commit_in_progress"
		return result
	var collected := get_pending_outputs(building_id)
	if collected.is_empty():
		result["reason"] = "no_pending_outputs"
		return result
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null:
		result["reason"] = "resource_system_unavailable"
		return result
	if not resource_system.has_method("add_resources"):
		result["reason"] = "resource_system_atomic_add_unavailable"
		return result
	if resource_system.has_method("can_store_resources") and not bool(resource_system.call("can_store_resources", collected)):
		result["reason"] = "output_inventory_capacity"
		return result

	_pending_collection_locks[building_id] = true
	var collected_entries := get_pending_output_entries(building_id)
	var committed := bool(resource_system.call("add_resources", collected))
	if not committed:
		_pending_collection_locks[building_id] = false
		result["reason"] = "output_inventory_commit_failed"
		return result

	var remaining: Dictionary = _pending_outputs[building_id]
	for raw_item_id in collected.keys():
		var item_id := str(raw_item_id)
		var next_amount := maxi(0, int(remaining.get(item_id, 0)) - int(collected[raw_item_id]))
		if next_amount <= 0:
			remaining.erase(item_id)
		else:
			remaining[item_id] = next_amount
	_pending_outputs[building_id] = remaining
	_latest_pending_output_item_ids[building_id] = ""
	_pending_collection_locks[building_id] = false
	var snapshot := get_project_snapshot(building_id)
	_publish_special_state(building_id)
	project_changed.emit(building_id, snapshot.duplicate(true))
	pending_outputs_changed.emit(building_id, get_pending_outputs(building_id))
	result["ok"] = true
	result["reason"] = "pending_outputs_collected"
	result["collected_resources"] = collected.duplicate(true)
	result["collected_entries"] = collected_entries.duplicate(true)
	result["remaining_pending_outputs"] = get_pending_outputs(building_id)
	result["project"] = snapshot
	return result


func set_target(building_id: String, recipe_id: String, force: bool = false) -> Dictionary:
	if not _projects.has(building_id):
		return _target_result(false, "unsupported_building", building_id, recipe_id)

	var normalized_recipe_id := recipe_id.strip_edges()
	var next_recipe := {}
	if not normalized_recipe_id.is_empty():
		next_recipe = get_recipe(normalized_recipe_id)
		if next_recipe.is_empty():
			return _target_result(false, "unknown_recipe", building_id, normalized_recipe_id)
		if not bool(next_recipe.get("available", true)):
			return _target_result(false, "recipe_unavailable", building_id, normalized_recipe_id)
		if str(next_recipe.get("building_id", "")) != building_id:
			return _target_result(false, "recipe_building_mismatch", building_id, normalized_recipe_id)

	var project: Dictionary = _projects[building_id]
	var previous_recipe_id := str(project.get("target_recipe_id", ""))
	if previous_recipe_id == normalized_recipe_id:
		var unchanged_result := _target_result(true, "target_unchanged", building_id, normalized_recipe_id)
		unchanged_result["changed"] = false
		unchanged_result["project"] = get_project_snapshot(building_id)
		return unchanged_result

	var previous_snapshot := get_project_snapshot(building_id)
	var completed_stages := int(project.get("completed_stages", 0))
	var partial_progress := float(previous_snapshot.get("partial_progress", 0.0))
	var requires_confirmation := completed_stages > 0 or partial_progress > PROGRESS_EPSILON
	if requires_confirmation and not force:
		var confirmation_result := _target_result(false, "confirmation_required", building_id, normalized_recipe_id)
		confirmation_result["confirmation_required"] = true
		confirmation_result["previous_project"] = previous_snapshot
		confirmation_result["discarded_completed_stages"] = completed_stages
		confirmation_result["discarded_partial_progress"] = partial_progress
		return confirmation_result

	var interrupted_npc_ids := _get_active_cycle_npc_ids(building_id)
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if action_system != null and action_system.has_method("interrupt_work_actions_for_building"):
		var interrupted_actions: Variant = action_system.call(
			"interrupt_work_actions_for_building",
			building_id,
			["work_blacksmith", "work_workshop"],
			"crafting_target_changed"
		)
		if interrupted_actions is Array:
			for raw_npc_id in interrupted_actions:
				var npc_id := str(raw_npc_id)
				if not interrupted_npc_ids.has(npc_id):
					interrupted_npc_ids.append(npc_id)
	interrupted_npc_ids.sort()
	var next_revision := int(project.get("revision", 0)) + 1
	_projects[building_id] = {
		"building_id": building_id,
		"target_recipe_id": normalized_recipe_id,
		"target_item_id": str(next_recipe.get("output_item_id", "")),
		"target_name": str(next_recipe.get("name", "")),
		"revision": next_revision,
		"completed_stages": 0,
		"total_stages": (next_recipe.get("stages", []) as Array).size()
	}
	_active_cycles[building_id] = {}

	var snapshot := get_project_snapshot(building_id)
	_publish_special_state(building_id)
	project_changed.emit(building_id, snapshot.duplicate(true))

	var reason := "target_cleared" if normalized_recipe_id.is_empty() else "target_selected"
	var result := _target_result(true, reason, building_id, normalized_recipe_id)
	result["changed"] = true
	result["confirmation_required"] = false
	result["forced"] = force
	result["previous_project"] = previous_snapshot
	result["project"] = snapshot
	result["discarded_completed_stages"] = completed_stages
	result["discarded_partial_progress"] = partial_progress
	result["interrupted_npc_ids"] = interrupted_npc_ids
	result["previous_revision"] = int(previous_snapshot.get("project_revision", 0))
	result["project_revision"] = next_revision
	return result


func can_start_work_cycle(building_id: String, npc_id: String = "") -> Dictionary:
	var result := _work_cycle_result(false, "unknown", building_id, npc_id)
	if not _projects.has(building_id):
		result["reason"] = "unsupported_building"
		return result
	if bool(_stage_commit_locks.get(building_id, false)):
		result["reason"] = "stage_commit_in_progress"
		return result

	var project := get_project_snapshot(building_id)
	var recipe_id := str(project.get("target_recipe_id", ""))
	if recipe_id.is_empty():
		result["reason"] = "crafting_target_missing"
		result["project"] = project
		return result

	var recipe := get_recipe(recipe_id)
	if recipe.is_empty() or str(recipe.get("building_id", "")) != building_id:
		result["reason"] = "invalid_current_recipe"
		result["project"] = project
		return result

	var current_stage_cost: Dictionary = project.get("current_stage_cost", {})
	if int(project.get("current_stage_index", 0)) <= 0:
		result["reason"] = "invalid_current_stage"
		result["project"] = project
		return result

	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null:
		result["reason"] = "resource_system_unavailable"
		result["project"] = project
		return result
	if not _resource_exists(resource_system, str(project.get("target_item_id", ""))):
		result["reason"] = "output_inventory_missing"
		result["project"] = project
		return result
	if not bool(resource_system.call("can_afford", current_stage_cost)):
		result["reason"] = "insufficient_stage_resources"
		result["required_resources"] = current_stage_cost.duplicate(true)
		result["project"] = project
		return result

	result["ok"] = true
	result["reason"] = "ok"
	result["project_revision"] = int(project.get("project_revision", 0))
	result["recipe_id"] = recipe_id
	result["target_item_id"] = str(project.get("target_item_id", ""))
	result["target_name"] = str(project.get("target_name", ""))
	result["stage_index"] = int(project.get("current_stage_index", 0))
	result["stage_id"] = str(project.get("current_stage_id", ""))
	result["stage_name"] = str(project.get("current_stage_name", ""))
	result["stage_cost"] = current_stage_cost.duplicate(true)
	result["input_resources"] = current_stage_cost.duplicate(true)
	result["completed_stages"] = int(project.get("completed_stages", 0))
	result["total_stages"] = int(project.get("total_stages", 0))
	result["project"] = project
	return result


func set_work_cycle_progress(
	building_id: String,
	project_revision: int,
	npc_id: String,
	progress: float
) -> Dictionary:
	var result := _work_cycle_result(false, "unknown", building_id, npc_id)
	if npc_id.is_empty():
		result["reason"] = "npc_id_missing"
		return result
	if not _projects.has(building_id):
		result["reason"] = "unsupported_building"
		return result

	var project: Dictionary = _projects[building_id]
	if str(project.get("target_recipe_id", "")).is_empty():
		result["reason"] = "crafting_target_missing"
		return result
	if int(project.get("revision", 0)) != project_revision:
		result["reason"] = "project_revision_mismatch"
		result["current_project_revision"] = int(project.get("revision", 0))
		return result

	var normalized_progress := clampf(progress, 0.0, 1.0)
	var cycles: Dictionary = _active_cycles.get(building_id, {})
	cycles[npc_id] = {
		"npc_id": npc_id,
		"project_revision": project_revision,
		"recipe_id": str(project.get("target_recipe_id", "")),
		"progress": normalized_progress
	}
	_active_cycles[building_id] = cycles

	work_cycle_progress_changed.emit(building_id, npc_id, normalized_progress)
	result["ok"] = true
	result["reason"] = "progress_updated"
	result["project_revision"] = project_revision
	result["recipe_id"] = str(project.get("target_recipe_id", ""))
	result["progress"] = normalized_progress
	result["project"] = get_project_snapshot(building_id)
	return result


func clear_work_cycle_progress(
	building_id: String,
	npc_id: String,
	project_revision: int = -1
) -> Dictionary:
	var result := _work_cycle_result(false, "unknown", building_id, npc_id)
	if not _active_cycles.has(building_id):
		result["reason"] = "unsupported_building"
		return result
	var cycles: Dictionary = _active_cycles[building_id]
	if not cycles.has(npc_id):
		result["ok"] = true
		result["reason"] = "cycle_not_registered"
		result["project"] = get_project_snapshot(building_id)
		return result
	var cycle: Dictionary = cycles[npc_id]
	if project_revision >= 0 and int(cycle.get("project_revision", -1)) != project_revision:
		result["reason"] = "project_revision_mismatch"
		result["current_cycle_revision"] = int(cycle.get("project_revision", -1))
		return result
	cycles.erase(npc_id)
	_active_cycles[building_id] = cycles
	work_cycle_progress_changed.emit(building_id, npc_id, 0.0)
	result["ok"] = true
	result["reason"] = "cycle_cleared"
	result["project"] = get_project_snapshot(building_id)
	return result


func complete_stage(
	building_id: String,
	project_revision: int,
	npc_id: String = ""
) -> Dictionary:
	var result := _complete_stage_result(false, "unknown", building_id, project_revision, npc_id)
	if not _projects.has(building_id):
		result["reason"] = "unsupported_building"
		return result
	if bool(_stage_commit_locks.get(building_id, false)):
		result["reason"] = "stage_commit_in_progress"
		return result

	var project: Dictionary = _projects[building_id]
	result["project"] = get_project_snapshot(building_id)
	var current_revision := int(project.get("revision", 0))
	result["current_project_revision"] = current_revision
	if project_revision != current_revision:
		result["reason"] = "project_revision_mismatch"
		return result

	var recipe_id := str(project.get("target_recipe_id", ""))
	result["recipe_id"] = recipe_id
	result["target_item_id"] = str(project.get("target_item_id", ""))
	if recipe_id.is_empty():
		result["reason"] = "crafting_target_missing"
		return result
	var recipe := get_recipe(recipe_id)
	if recipe.is_empty() or str(recipe.get("building_id", "")) != building_id:
		result["reason"] = "invalid_current_recipe"
		return result

	var completed_stages := int(project.get("completed_stages", 0))
	var stages: Array = recipe.get("stages", [])
	if completed_stages < 0 or completed_stages >= stages.size():
		result["reason"] = "invalid_current_stage"
		return result
	var stage: Dictionary = stages[completed_stages]
	var stage_cost: Dictionary = stage.get("cost", {})
	var completed_stage := {
		"index": completed_stages + 1,
		"id": str(stage.get("id", "")),
		"name": str(stage.get("name", "")),
		"cost": stage_cost.duplicate(true)
	}
	var product_completed := completed_stages + 1 >= stages.size()
	var pending_output_resources := {}
	if product_completed:
		pending_output_resources[str(recipe.get("output_item_id", ""))] = int(recipe.get("output_amount", 1))

	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null:
		result["reason"] = "resource_system_unavailable"
		result["required_resources"] = stage_cost.duplicate(true)
		return result
	if not bool(resource_system.call("can_afford", stage_cost)):
		result["reason"] = "insufficient_stage_resources"
		result["required_resources"] = stage_cost.duplicate(true)
		return result
	if product_completed and not _resource_exists(resource_system, str(recipe.get("output_item_id", ""))):
		result["reason"] = "output_inventory_missing"
		return result

	_stage_commit_locks[building_id] = true
	if not bool(resource_system.call("spend_resources", stage_cost)):
		_stage_commit_locks[building_id] = false
		result["reason"] = "stage_resource_commit_failed"
		result["required_resources"] = stage_cost.duplicate(true)
		return result

	if product_completed:
		var output_item_id := str(recipe.get("output_item_id", ""))
		var output_amount := int(recipe.get("output_amount", 1))
		var pending: Dictionary = _pending_outputs.get(building_id, {})
		pending[output_item_id] = int(pending.get(output_item_id, 0)) + output_amount
		_pending_outputs[building_id] = pending
		_latest_pending_output_item_ids[building_id] = output_item_id

	var updated_project := project.duplicate(true)
	updated_project["completed_stages"] = 0 if product_completed else completed_stages + 1
	_projects[building_id] = updated_project
	_remove_active_cycle_if_revision_matches(building_id, npc_id, project_revision)
	_stage_commit_locks[building_id] = false

	var snapshot := get_project_snapshot(building_id)
	_publish_special_state(building_id)
	project_changed.emit(building_id, snapshot.duplicate(true))
	if product_completed:
		pending_outputs_changed.emit(building_id, get_pending_outputs(building_id))
	if not npc_id.is_empty():
		work_cycle_progress_changed.emit(building_id, npc_id, 0.0)

	result["ok"] = true
	result["reason"] = "product_completed" if product_completed else "stage_completed"
	result["recipe_id"] = recipe_id
	result["target_item_id"] = str(recipe.get("output_item_id", ""))
	result["target_name"] = str(recipe.get("name", ""))
	result["input_resources"] = stage_cost.duplicate(true)
	result["output_resources"] = {}
	result["pending_output_resources"] = pending_output_resources.duplicate(true)
	result["pending_output_entries"] = get_pending_output_entries(building_id) if product_completed else []
	result["completed_stage"] = completed_stage
	result["product_completed"] = product_completed
	result["project"] = snapshot
	return result


func get_building_special_state(building_id: String) -> Dictionary:
	if not _projects.has(building_id):
		return {}
	return {SPECIAL_STATE_SECTION: get_production_special_state(building_id)}


func get_production_special_state(building_id: String) -> Dictionary:
	var project := get_project_snapshot(building_id)
	if project.is_empty():
		return {}
	return {
		"target_item_id": str(project.get("target_item_id", "")),
		"target_name": str(project.get("target_name", "")),
		"completed_stages": int(project.get("completed_stages", 0)),
		"total_stages": int(project.get("total_stages", 0)),
		"current_stage_index": int(project.get("current_stage_index", 0)),
		"current_stage_name": str(project.get("current_stage_name", ""))
	}


func publish_all_special_states() -> void:
	for raw_building_id in SUPPORTED_BUILDING_IDS:
		_publish_special_state(str(raw_building_id))


func debug_get_snapshot() -> Dictionary:
	var recipes_snapshot := {}
	for recipe_id in _recipes.keys():
		recipes_snapshot[str(recipe_id)] = get_recipe(str(recipe_id))
	return {
		"initialized": _initialized,
		"config_file": CRAFTING_RECIPES_FILE,
		"recipe_count": _recipes.size(),
		"expected_recipe_count": EXPECTED_RECIPE_IDS.size(),
		"recipe_ids_by_building": _recipe_ids_by_building.duplicate(true),
		"recipes": recipes_snapshot,
		"initial_projects": _initial_projects.duplicate(true),
		"projects": get_all_project_snapshots(),
		"pending_outputs": _pending_outputs.duplicate(true),
		"latest_pending_output_item_ids": _latest_pending_output_item_ids.duplicate(true),
		"active_cycles": _active_cycles.duplicate(true),
		"stage_commit_locks": _stage_commit_locks.duplicate(true),
		"pending_collection_locks": _pending_collection_locks.duplicate(true),
		"load_errors": _load_errors.duplicate()
	}


func get_debug_snapshot() -> Dictionary:
	return debug_get_snapshot()


func _normalize_recipe(raw_recipe: Dictionary) -> Dictionary:
	var recipe_id := str(raw_recipe.get("id", "")).strip_edges()
	var recipe_name := str(raw_recipe.get("name", "")).strip_edges()
	var building_id := str(raw_recipe.get("building_id", "")).strip_edges()
	var output_item_id := str(raw_recipe.get("output_item_id", "")).strip_edges()
	var output_amount := int(raw_recipe.get("output_amount", 1))
	if recipe_id.is_empty() or recipe_name.is_empty() or building_id.is_empty() or output_item_id.is_empty():
		_record_load_error("Crafting recipe is missing id, name, building_id, or output_item_id: %s" % recipe_id)
		return {}
	if not SUPPORTED_BUILDING_IDS.has(building_id):
		_record_load_error("Unsupported crafting building for %s: %s" % [recipe_id, building_id])
		return {}
	if output_amount != 1:
		_record_load_error("Current crafting contract requires output_amount=1: %s" % recipe_id)
		return {}

	var raw_stages: Variant = raw_recipe.get("stages", [])
	if not raw_stages is Array or raw_stages.is_empty():
		_record_load_error("Crafting recipe must contain at least one stage: %s" % recipe_id)
		return {}
	var stages: Array[Dictionary] = []
	var stage_ids := {}
	for raw_stage in raw_stages:
		if not raw_stage is Dictionary:
			_record_load_error("Crafting recipe %s contains a non-dictionary stage." % recipe_id)
			return {}
		var stage_id := str(raw_stage.get("id", "")).strip_edges()
		var stage_name := str(raw_stage.get("name", "")).strip_edges()
		if stage_id.is_empty() or stage_name.is_empty() or stage_ids.has(stage_id):
			_record_load_error("Crafting recipe %s has an empty or duplicate stage id: %s" % [recipe_id, stage_id])
			return {}
		var load_error_count := _load_errors.size()
		var normalized_cost := _normalize_stage_cost(raw_stage.get("cost", {}), recipe_id, stage_id)
		if _load_errors.size() > load_error_count:
			return {}
		stage_ids[stage_id] = true
		stages.append({
			"id": stage_id,
			"name": stage_name,
			"cost": normalized_cost
		})

	return {
		"id": recipe_id,
		"name": recipe_name,
		"building_id": building_id,
		"output_item_id": output_item_id,
		"output_amount": output_amount,
		"available": bool(raw_recipe.get("available", true)),
		"ui_order": int(raw_recipe.get("ui_order", 0)),
		"stages": stages
	}


func _normalize_stage_cost(raw_cost: Variant, recipe_id: String, stage_id: String) -> Dictionary:
	if not raw_cost is Dictionary:
		_record_load_error("Crafting stage cost must be a dictionary: %s/%s" % [recipe_id, stage_id])
		return {}
	var normalized_cost := {}
	for raw_resource_id in raw_cost.keys():
		var resource_id := str(raw_resource_id).strip_edges()
		var amount := int(raw_cost[raw_resource_id])
		if resource_id.is_empty() or amount <= 0:
			_record_load_error("Crafting stage has an invalid cost: %s/%s" % [recipe_id, stage_id])
			return {}
		normalized_cost[resource_id] = amount
	return normalized_cost


func _validate_expected_catalog() -> void:
	for raw_recipe_id in EXPECTED_RECIPE_IDS:
		var recipe_id := str(raw_recipe_id)
		if not _recipes.has(recipe_id):
			_record_load_error("Missing required crafting recipe: %s" % recipe_id)
	for raw_recipe_id in _recipes.keys():
		var recipe_id := str(raw_recipe_id)
		if not EXPECTED_RECIPE_IDS.has(recipe_id):
			_record_load_error("Unexpected crafting recipe outside the frozen Demo catalog: %s" % recipe_id)


func _apply_initial_projects(raw_initial_projects: Variant) -> void:
	if not raw_initial_projects is Array:
		_record_load_error("Crafting initial_projects must be an array.")
		return
	for raw_entry in raw_initial_projects:
		if not raw_entry is Dictionary:
			_record_load_error("Crafting initial project must be a dictionary.")
			continue
		var building_id := str(raw_entry.get("building_id", "")).strip_edges()
		var recipe_id := str(raw_entry.get("recipe_id", "")).strip_edges()
		var completed_stages := int(raw_entry.get("completed_stages", 0))
		var recipe := get_recipe(recipe_id)
		if not _projects.has(building_id):
			_record_load_error("Unsupported crafting initial project building: %s" % building_id)
			continue
		if recipe.is_empty() or str(recipe.get("building_id", "")) != building_id:
			_record_load_error("Invalid crafting initial project recipe: %s/%s" % [building_id, recipe_id])
			continue
		var stages: Array = recipe.get("stages", [])
		if completed_stages <= 0 or completed_stages >= stages.size():
			_record_load_error("Crafting initial project completed_stages must leave an unfinished product: %s" % recipe_id)
			continue
		var calculated_investment := {}
		for stage_index in range(completed_stages):
			var stage: Dictionary = stages[stage_index]
			var stage_cost: Dictionary = stage.get("cost", {})
			for raw_resource_id in stage_cost.keys():
				var resource_id := str(raw_resource_id)
				calculated_investment[resource_id] = int(calculated_investment.get(resource_id, 0)) + int(stage_cost[raw_resource_id])
		var declared_investment := _normalize_stage_cost(
			raw_entry.get("invested_resources", {}),
			"initial_project",
			recipe_id
		)
		if declared_investment != calculated_investment:
			_record_load_error("Crafting initial project investment does not match completed stage costs: %s" % recipe_id)
			continue
		var initial_project := {
			"building_id": building_id,
			"target_recipe_id": recipe_id,
			"target_item_id": str(recipe.get("output_item_id", "")),
			"target_name": str(recipe.get("name", "")),
			"revision": 1,
			"completed_stages": completed_stages,
			"total_stages": stages.size(),
			"invested_resources": calculated_investment.duplicate(true),
			"source": str(raw_entry.get("source", "pre_game_investment"))
		}
		_projects[building_id] = initial_project.duplicate(true)
		_initial_projects[building_id] = initial_project.duplicate(true)


func _make_empty_project(building_id: String) -> Dictionary:
	return {
		"building_id": building_id,
		"target_recipe_id": "",
		"target_item_id": "",
		"target_name": "",
		"revision": 0,
		"completed_stages": 0,
		"total_stages": 0
	}


func _get_stage(recipe: Dictionary, completed_stages: int) -> Dictionary:
	if recipe.is_empty():
		return {}
	var stages: Array = recipe.get("stages", [])
	if completed_stages < 0 or completed_stages >= stages.size():
		return {}
	if not stages[completed_stages] is Dictionary:
		return {}
	return (stages[completed_stages] as Dictionary).duplicate(true)


func _get_active_worker_snapshots(
	building_id: String,
	project_revision: int,
	recipe_id: String
) -> Array[Dictionary]:
	var workers: Array[Dictionary] = []
	var cycles: Dictionary = _active_cycles.get(building_id, {})
	for raw_npc_id in cycles.keys():
		var cycle: Dictionary = cycles[raw_npc_id]
		if int(cycle.get("project_revision", -1)) != project_revision:
			continue
		if str(cycle.get("recipe_id", "")) != recipe_id:
			continue
		workers.append({
			"npc_id": str(raw_npc_id),
			"project_revision": project_revision,
			"progress": clampf(float(cycle.get("progress", 0.0)), 0.0, 1.0)
		})
	workers.sort_custom(_compare_active_workers)
	return workers


func _calculate_partial_progress(active_workers: Array[Dictionary], remaining_stages: int) -> float:
	if remaining_stages <= 0:
		return 0.0
	var total := 0.0
	for worker in active_workers:
		total += clampf(float(worker.get("progress", 0.0)), 0.0, 1.0)
	return clampf(total, 0.0, float(remaining_stages))


func _get_active_cycle_npc_ids(building_id: String) -> Array[String]:
	var npc_ids: Array[String] = []
	var cycles: Dictionary = _active_cycles.get(building_id, {})
	for raw_npc_id in cycles.keys():
		npc_ids.append(str(raw_npc_id))
	npc_ids.sort()
	return npc_ids


func _remove_active_cycle_if_revision_matches(
	building_id: String,
	npc_id: String,
	project_revision: int
) -> void:
	if npc_id.is_empty():
		return
	var cycles: Dictionary = _active_cycles.get(building_id, {})
	if not cycles.has(npc_id):
		return
	var cycle: Dictionary = cycles[npc_id]
	if int(cycle.get("project_revision", -1)) != project_revision:
		return
	cycles.erase(npc_id)
	_active_cycles[building_id] = cycles


func _resource_exists(resource_system: Node, resource_id: String) -> bool:
	if resource_id.is_empty():
		return false
	if not resource_system.has_method("get_resource_definition"):
		return true
	var definition: Variant = resource_system.call("get_resource_definition", resource_id)
	return definition is Dictionary and not definition.is_empty()


func _get_stock_amount(resource_id: String) -> int:
	if resource_id.is_empty():
		return 0
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null or not _resource_exists(resource_system, resource_id):
		return 0
	return int(resource_system.call("get_resource", resource_id))


func _publish_special_state(building_id: String) -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("set_building_special_state_section"):
		return
	building_system.call(
		"set_building_special_state_section",
		building_id,
		SPECIAL_STATE_SECTION,
		get_production_special_state(building_id)
	)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("crafting_state_changed"):
		event_bus.emit_signal("crafting_state_changed", building_id)


func _target_result(ok: bool, reason: String, building_id: String, recipe_id: String) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"building_id": building_id,
		"requested_recipe_id": recipe_id,
		"confirmation_required": false
	}


func _work_cycle_result(ok: bool, reason: String, building_id: String, npc_id: String) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"building_id": building_id,
		"npc_id": npc_id,
		"project_revision": -1,
		"recipe_id": "",
		"target_item_id": "",
		"stage_cost": {},
		"input_resources": {}
	}


func _complete_stage_result(
	ok: bool,
	reason: String,
	building_id: String,
	project_revision: int,
	npc_id: String
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"building_id": building_id,
		"npc_id": npc_id,
		"project_revision": project_revision,
		"recipe_id": "",
		"target_item_id": "",
		"input_resources": {},
		"output_resources": {},
		"pending_output_resources": {},
		"pending_output_entries": [],
		"completed_stage": {},
		"product_completed": false
	}


func _compare_recipe_ids(a: String, b: String) -> bool:
	var recipe_a: Dictionary = _recipes.get(a, {})
	var recipe_b: Dictionary = _recipes.get(b, {})
	var order_a := int(recipe_a.get("ui_order", 0))
	var order_b := int(recipe_b.get("ui_order", 0))
	if order_a == order_b:
		return a < b
	return order_a < order_b


func _compare_active_workers(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("npc_id", "")) < str(b.get("npc_id", ""))


func _compare_pending_entries(a: Dictionary, b: Dictionary) -> bool:
	var order_a := int(a.get("ui_order", 9999))
	var order_b := int(b.get("ui_order", 9999))
	if order_a == order_b:
		return str(a.get("item_id", "")) < str(b.get("item_id", ""))
	return order_a < order_b


func _record_load_error(message: String) -> void:
	_load_errors.append(message)
	push_error(message)
