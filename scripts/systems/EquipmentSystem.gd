extends Node

const WEAPON_DEFS_FILE := "weapon_defs.json"
const ARMOR_DEFS_FILE := "armor_defs.json"
const MOUNT_DEFS_FILE := "mount_defs.json"

const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const HORSE_SYSTEM_PATH := "/root/Main/Systems/HorseSystem"

const PLAYER_ACTOR_ID := "guard_officer"
const DEFAULT_VISIBILITY := "local_public"
const DEPRECATED_FORMAL_INVENTORY_IDS: Array[String] = [
	"weapons", "armor", "defense_devices", "horse_readiness"
]

const SLOT_MAIN_WEAPON := "main_weapon"
const SLOT_HELMET := "helmet"
const SLOT_CHEST := "chest"
const SLOT_BRACERS := "bracers"
const SLOT_GREAVES := "greaves"
const SLOT_MOUNT := "mount"

const ARMOR_SLOTS: Array[String] = [SLOT_HELMET, SLOT_CHEST, SLOT_BRACERS, SLOT_GREAVES]
const EQUIPMENT_SLOTS: Array[String] = [
	SLOT_MAIN_WEAPON, SLOT_HELMET, SLOT_CHEST, SLOT_BRACERS, SLOT_GREAVES, SLOT_MOUNT
]

const UNIT_NON_COMBAT := "non_combat"
const UNIT_MELEE_INFANTRY := "melee_infantry"
const UNIT_POLEARM_INFANTRY := "polearm_infantry"
const UNIT_ARCHER := "archer"
const UNIT_CROSSBOWMAN := "crossbowman"
const UNIT_CAVALRY := "cavalry"
const UNIT_MOUNTED_RANGED := "mounted_ranged"

var _weapon_defs: Dictionary = {}
var _armor_defs: Dictionary = {}
var _mount_defs: Dictionary = {}
var _weapon_order: Array[String] = []
var _armor_order_by_slot: Dictionary = {}
var _mount_order: Array[String] = []


func _ready() -> void:
	initialize()


func initialize() -> void:
	_weapon_defs.clear()
	_armor_defs.clear()
	_mount_defs.clear()
	_weapon_order.clear()
	_armor_order_by_slot.clear()
	_mount_order.clear()

	_load_weapon_defs()
	_load_armor_defs()
	_load_mount_defs()
	_apply_initial_equipment_from_profiles()


func get_weapon_ids() -> Array[String]:
	return _weapon_order.duplicate()


func get_armor_ids(slot: String = "") -> Array[String]:
	var normalized_slot := _normalize_slot_id(slot)
	if normalized_slot.is_empty():
		var result: Array[String] = []
		for armor_slot in ARMOR_SLOTS:
			for armor_id in _armor_order_by_slot.get(armor_slot, []):
				result.append(str(armor_id))
		return result
	var result: Array[String] = []
	for armor_id in _armor_order_by_slot.get(normalized_slot, []):
		result.append(str(armor_id))
	return result


func get_mount_ids() -> Array[String]:
	return _mount_order.duplicate()


func get_armor_slot_ids() -> Array[String]:
	return ARMOR_SLOTS.duplicate()


func get_weapon_def(weapon_id: String) -> Dictionary:
	return _weapon_defs.get(weapon_id, {}).duplicate(true)


func get_armor_def(armor_id: String) -> Dictionary:
	return _armor_defs.get(armor_id, {}).duplicate(true)


func get_mount_def(mount_id: String) -> Dictionary:
	return _mount_defs.get(mount_id, {}).duplicate(true)


func get_equipment_snapshot(npc_id: String) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		return {}
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return {}
	var equipment: Dictionary = npc.get("equipment", {})
	return _normalize_equipment(equipment)


func equip_npc_main_weapon(
	npc_id: String,
	weapon_id: String,
	visibility: String = DEFAULT_VISIBILITY
) -> Dictionary:
	return _equip_npc_item(npc_id, SLOT_MAIN_WEAPON, weapon_id, "weapon", visibility)


func equip_npc_armor(
	npc_id: String,
	slot: String,
	armor_id: String = "",
	visibility: String = DEFAULT_VISIBILITY
) -> Dictionary:
	var normalized_slot := _normalize_slot_id(slot)
	if not ARMOR_SLOTS.has(normalized_slot):
		return _failure("invalid_armor_slot", "盔甲部位无效。")
	var resolved_armor_id := armor_id
	if resolved_armor_id.is_empty():
		var slot_options: Array = _armor_order_by_slot.get(normalized_slot, [])
		if slot_options.is_empty():
			return _failure("armor_not_configured", "该盔甲部位没有可用装备。")
		resolved_armor_id = str(slot_options[0])
	return _equip_npc_item(npc_id, normalized_slot, resolved_armor_id, "armor", visibility)


func equip_npc_mount(
	npc_id: String,
	horse_id: String = "",
	visibility: String = DEFAULT_VISIBILITY
) -> Dictionary:
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or not horse_system.has_method("assign_horse_to_npc"):
		return _failure("horse_system_missing", "马匹系统不可用，不能分配坐骑。")
	var raw_result: Variant = horse_system.call("assign_horse_to_npc", npc_id, horse_id, visibility)
	if raw_result is Dictionary:
		return (raw_result as Dictionary).duplicate(true)
	return _failure("horse_assignment_failed", "马匹系统未返回合法分配结果。")


func set_npc_horse_mount(
	npc_id: String,
	horse_snapshot: Dictionary,
	visibility: String = DEFAULT_VISIBILITY,
	record_event: bool = true
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc") or not npc_system.has_method("set_npc_equipment_slot"):
		return _failure("npc_system_missing", "NPC 系统装备接口不可用。")
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return _failure("unknown_npc", "NPC 不存在。")
	if not bool(npc.get("recruited", false)):
		return _failure("npc_not_recruited", "只有已入伍 NPC 可以分配马匹。")
	var states: Dictionary = npc.get("states", {}) if npc.get("states", {}) is Dictionary else {}
	if bool(states.get("escaped", false)):
		return _failure("npc_escaped", "逃离的 NPC 不能分配马匹。")
	var equipment := _normalize_equipment(npc.get("equipment", {}))
	if (equipment.get(SLOT_MAIN_WEAPON, {}) as Dictionary).is_empty():
		return _failure("main_weapon_required", "NPC 必须先装备主武器才能分配马匹。")

	var horse_id := str(horse_snapshot.get("horse_id", horse_snapshot.get("id", ""))).strip_edges()
	if horse_id.is_empty():
		return _failure("invalid_horse", "马匹引用缺少唯一 horse_id。")
	var horse_name := str(horse_snapshot.get("name", horse_snapshot.get("horse_name", horse_id))).strip_edges()
	var mount_definition_id := str(horse_snapshot.get("mount_definition_id", "riding_horse"))
	var mount_definition := get_mount_def(mount_definition_id)
	if mount_definition.is_empty():
		return _failure("mount_not_configured", "没有可用坐骑定义。")

	var previous_item: Dictionary = equipment.get(SLOT_MOUNT, {})
	if str(previous_item.get("horse_id", "")) == horse_id:
		return {
			"ok": true,
			"changed": false,
			"npc_id": npc_id,
			"slot": SLOT_MOUNT,
			"horse_id": horse_id,
			"equipment": equipment,
			"unit_type": determine_unit_type(equipment),
			"unit_type_label": get_unit_type_label(determine_unit_type(equipment))
		}

	var next_item := _make_equipped_item(SLOT_MOUNT, "mount", mount_definition)
	next_item["horse_id"] = horse_id
	next_item["horse_name"] = horse_name
	next_item["name"] = horse_name
	if not npc_system.set_npc_equipment_slot(npc_id, SLOT_MOUNT, next_item):
		return _failure("equipment_write_failed", "写入 NPC 马匹引用失败。")

	var next_equipment := get_equipment_snapshot(npc_id)
	var unit_type := determine_unit_type(next_equipment)
	var event := {}
	if record_event:
		event = _log_equipment_event(
			npc_id,
			"equipment_changed" if not previous_item.is_empty() else "equipment_given",
			SLOT_MOUNT,
			"mount",
			next_item,
			previous_item,
			"",
			unit_type,
			visibility
		)
	var strategy_result := _normalize_combat_strategy_after_equipment_change(npc_id, SLOT_MOUNT, visibility, true)
	return {
		"ok": true,
		"changed": true,
		"npc_id": npc_id,
		"slot": SLOT_MOUNT,
		"horse_id": horse_id,
		"horse_name": horse_name,
		"equipment": next_equipment,
		"previous_equipment": previous_item.duplicate(true),
		"unit_type": unit_type,
		"unit_type_label": get_unit_type_label(unit_type),
		"combat_strategy": strategy_result,
		"event": event
	}


func clear_npc_horse_mount(
	npc_id: String,
	visibility: String = DEFAULT_VISIBILITY,
	reason: String = "horse_unassigned",
	record_event: bool = true
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc") or not npc_system.has_method("set_npc_equipment_slot"):
		return _failure("npc_system_missing", "NPC 系统装备接口不可用。")
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return _failure("unknown_npc", "NPC 不存在。")
	var equipment := _normalize_equipment(npc.get("equipment", {}))
	var previous_item: Dictionary = equipment.get(SLOT_MOUNT, {})
	if previous_item.is_empty():
		return {
			"ok": true,
			"changed": false,
			"npc_id": npc_id,
			"slot": SLOT_MOUNT,
			"reason": reason,
			"equipment": equipment
		}
	if not npc_system.set_npc_equipment_slot(npc_id, SLOT_MOUNT, {}):
		return _failure("equipment_write_failed", "清除 NPC 马匹引用失败。")

	var next_equipment := get_equipment_snapshot(npc_id)
	var unit_type := determine_unit_type(next_equipment)
	var event := {}
	if record_event:
		event = _log_equipment_event(
			npc_id,
			"equipment_changed",
			SLOT_MOUNT,
			"mount",
			{"id": "", "name": "未分配马匹", "slot": SLOT_MOUNT, "kind": "mount"},
			previous_item,
			"",
			unit_type,
			visibility
		)
	var strategy_result := _normalize_combat_strategy_after_equipment_change(npc_id, SLOT_MOUNT, visibility, true)
	return {
		"ok": true,
		"changed": true,
		"npc_id": npc_id,
		"slot": SLOT_MOUNT,
		"reason": reason,
		"horse_id": str(previous_item.get("horse_id", "")),
		"horse_name": str(previous_item.get("horse_name", previous_item.get("name", ""))),
		"equipment": next_equipment,
		"previous_equipment": previous_item.duplicate(true),
		"unit_type": unit_type,
		"unit_type_label": get_unit_type_label(unit_type),
		"combat_strategy": strategy_result,
		"event": event
	}


func unequip_npc_slot(
	npc_id: String,
	slot: String,
	visibility: String = DEFAULT_VISIBILITY,
	reason: String = "player_unequip"
) -> Dictionary:
	var normalized_slot := _normalize_slot_id(slot)
	if not EQUIPMENT_SLOTS.has(normalized_slot):
		return _failure("invalid_equipment_slot", "装备部位无效。")
	if normalized_slot == SLOT_MOUNT:
		var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
		if horse_system == null or not horse_system.has_method("unassign_horse_from_npc"):
			return _failure("horse_system_missing", "马匹系统不可用，不能解除马匹分配。")
		var raw_horse_result: Variant = horse_system.call(
			"unassign_horse_from_npc",
			npc_id,
			reason,
			visibility
		)
		if raw_horse_result is Dictionary:
			return (raw_horse_result as Dictionary).duplicate(true)
		return _failure("horse_unassignment_failed", "马匹系统未返回合法解除结果。")

	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc") or not npc_system.has_method("set_npc_equipment_slot"):
		return _failure("npc_system_missing", "NPC 系统装备接口不可用。")
	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return _failure("unknown_npc", "NPC 不存在。")
	var equipment := _normalize_equipment(npc.get("equipment", {}))
	var previous_item: Dictionary = equipment.get(normalized_slot, {})
	if previous_item.is_empty():
		return {
			"ok": true,
			"changed": false,
			"npc_id": npc_id,
			"slot": normalized_slot,
			"reason": reason,
			"equipment": equipment
		}

	var resource_id := str(previous_item.get("source_resource_id", ""))
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if not resource_id.is_empty() and (
		resource_system == null or not resource_system.has_method("add_resource")
	):
		return _failure("resource_system_missing", "资源系统不可用，不能安全归还装备。")
	if not npc_system.set_npc_equipment_slot(npc_id, normalized_slot, {}):
		return _failure("equipment_write_failed", "卸下 NPC 装备失败。")
	if not resource_id.is_empty() and not resource_system.add_resource(resource_id, 1):
		npc_system.set_npc_equipment_slot(npc_id, normalized_slot, previous_item)
		return _failure("inventory_return_failed", "装备库存归还失败。")

	var horse_result := {}
	if normalized_slot == SLOT_MAIN_WEAPON:
		horse_result = _unassign_horse_after_main_weapon_removed(npc_id, visibility)
		if not bool(horse_result.get("ok", false)):
			if not resource_id.is_empty() and resource_system.has_method("spend_resources"):
				resource_system.spend_resources({resource_id: 1})
			npc_system.set_npc_equipment_slot(npc_id, normalized_slot, previous_item)
			return _failure("horse_unassignment_failed", "马匹自动解绑失败，主武器未被收回。")

	var next_equipment := get_equipment_snapshot(npc_id)
	var unit_type := determine_unit_type(next_equipment)
	var event := _log_equipment_event(
		npc_id,
		"equipment_changed",
		normalized_slot,
		_get_item_kind_for_slot(normalized_slot),
		{"id": "", "name": "未装备%s" % get_slot_label(normalized_slot), "slot": normalized_slot},
		previous_item,
		resource_id,
		unit_type,
		visibility
	)
	var strategy_result := _normalize_combat_strategy_after_equipment_change(
		npc_id,
		normalized_slot,
		visibility,
		true
	)
	return {
		"ok": true,
		"changed": true,
		"npc_id": npc_id,
		"slot": normalized_slot,
		"reason": reason,
		"returned_resource_id": resource_id,
		"returned_amount": 1 if not resource_id.is_empty() else 0,
		"equipment": next_equipment,
		"previous_equipment": previous_item.duplicate(true),
		"unit_type": unit_type,
		"unit_type_label": get_unit_type_label(unit_type),
		"horse_unassignment": horse_result,
		"combat_strategy": strategy_result,
		"event": event
	}


func determine_unit_type(equipment: Variant) -> String:
	var normalized := _normalize_equipment(equipment)
	var main_weapon: Dictionary = normalized.get(SLOT_MAIN_WEAPON, {})
	if main_weapon.is_empty():
		return UNIT_NON_COMBAT

	var has_mount := not (normalized.get(SLOT_MOUNT, {}) as Dictionary).is_empty()
	var weapon_type := str(main_weapon.get("type", ""))
	var weapon_class := str(main_weapon.get("weapon_class", ""))
	if has_mount:
		if weapon_type == "ranged" or ["bow", "crossbow"].has(weapon_class):
			return UNIT_MOUNTED_RANGED
		return UNIT_CAVALRY

	match weapon_class:
		"polearm":
			return UNIT_POLEARM_INFANTRY
		"bow":
			return UNIT_ARCHER
		"crossbow":
			return UNIT_CROSSBOWMAN
		_:
			return UNIT_MELEE_INFANTRY


func get_npc_unit_type(npc_id: String) -> String:
	return determine_unit_type(get_equipment_snapshot(npc_id))


func get_unit_type_label(unit_type: String) -> String:
	match unit_type:
		UNIT_MELEE_INFANTRY:
			return "近战步兵"
		UNIT_POLEARM_INFANTRY:
			return "长杆步兵"
		UNIT_ARCHER:
			return "弓箭兵"
		UNIT_CROSSBOWMAN:
			return "弩兵"
		UNIT_CAVALRY:
			return "近战骑兵"
		UNIT_MOUNTED_RANGED:
			return "骑射单位"
		_:
			return "非战斗人员 / 避战单位"


func get_npc_unit_type_label(npc_id: String) -> String:
	return get_unit_type_label(get_npc_unit_type(npc_id))


func get_unit_type_snapshot(npc_id: String) -> Dictionary:
	var equipment := get_equipment_snapshot(npc_id)
	var main_weapon: Dictionary = equipment.get(SLOT_MAIN_WEAPON, {})
	var mount: Dictionary = equipment.get(SLOT_MOUNT, {})
	var unit_type := determine_unit_type(equipment)
	return {
		"npc_id": npc_id,
		"unit_type": unit_type,
		"unit_type_label": get_unit_type_label(unit_type),
		"has_main_weapon": not main_weapon.is_empty(),
		"main_weapon_id": str(main_weapon.get("id", "")),
		"main_weapon_name": str(main_weapon.get("name", "")),
		"weapon_type": str(main_weapon.get("type", "")),
		"weapon_class": str(main_weapon.get("weapon_class", "")),
		"has_mount": not mount.is_empty(),
		"mount_id": str(mount.get("id", "")),
		"mount_name": str(mount.get("name", "")),
		"horse_id": str(mount.get("horse_id", "")),
		"horse_name": str(mount.get("horse_name", mount.get("name", ""))),
		"equipment": equipment
	}


func debug_equip_weapon(npc_id: String, weapon_id: String, visibility: String = DEFAULT_VISIBILITY) -> Dictionary:
	return equip_npc_main_weapon(npc_id, weapon_id, visibility)


func debug_equip_armor(npc_id: String, slot: String, visibility: String = DEFAULT_VISIBILITY) -> Dictionary:
	return equip_npc_armor(npc_id, slot, "", visibility)


func debug_equip_mount(npc_id: String, visibility: String = DEFAULT_VISIBILITY) -> Dictionary:
	return equip_npc_mount(npc_id, "", visibility)


func _equip_npc_item(
	npc_id: String,
	slot: String,
	item_id: String,
	item_kind: String,
	visibility: String
) -> Dictionary:
	if item_kind == "mount" or slot == SLOT_MOUNT:
		return _failure("horse_system_required", "马匹必须通过 HorseSystem 分配，不能作为库存装备。")
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc") or not npc_system.has_method("set_npc_equipment_slot"):
		return _failure("npc_system_missing", "NPC 系统装备接口不可用。")

	var npc: Dictionary = npc_system.get_npc(npc_id)
	if npc.is_empty():
		return _failure("unknown_npc", "NPC 不存在。")
	if not bool(npc.get("recruited", false)):
		return _failure("npc_not_recruited", "只有已入伍 NPC 可以由守备官直接分配装备。")
	var states: Dictionary = npc.get("states", {})
	if bool(states.get("escaped", false)):
		return _failure("npc_escaped", "逃离的 NPC 不能再分配装备。")

	var definition := _get_item_def(item_kind, item_id)
	if definition.is_empty():
		return _failure("unknown_equipment", "装备定义不存在。")
	var expected_slot := _normalize_slot_id(str(definition.get("equipment_slot", definition.get("slot", slot))))
	if expected_slot != slot:
		return _failure("slot_mismatch", "装备不能放入这个部位。")

	var current_equipment := _normalize_equipment(npc.get("equipment", {}))
	var previous_item: Dictionary = current_equipment.get(slot, {})
	if str(previous_item.get("id", "")) == item_id:
		var unchanged_strategy_result := _normalize_combat_strategy_after_equipment_change(npc_id, slot, visibility, false)
		return {
			"ok": true,
			"changed": false,
			"npc_id": npc_id,
			"slot": slot,
			"equipment": current_equipment,
			"unit_type": determine_unit_type(current_equipment),
			"unit_type_label": get_unit_type_label(determine_unit_type(current_equipment)),
			"combat_strategy": unchanged_strategy_result
		}

	var resource_id := str(definition.get("source_resource_id", ""))
	if DEPRECATED_FORMAL_INVENTORY_IDS.has(resource_id):
		return _failure("deprecated_inventory", "旧聚合库存不能再用于正式装备结算。")
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_id.is_empty() or resource_system == null or not resource_system.has_method("spend_resources"):
		return _failure("resource_system_missing", "资源系统不可用。")
	if not resource_system.spend_resources({resource_id: 1}):
		return _failure("not_enough_inventory", "%s库存不足。" % _get_resource_name(resource_id))

	var next_item := _make_equipped_item(slot, item_kind, definition)
	var set_ok: bool = npc_system.set_npc_equipment_slot(npc_id, slot, next_item)
	if not set_ok:
		resource_system.add_resource(resource_id, 1)
		return _failure("equipment_write_failed", "写入 NPC 装备失败。")

	var previous_resource_id := str(previous_item.get("source_resource_id", ""))
	if not previous_resource_id.is_empty() and resource_system.has_method("add_resource"):
		resource_system.add_resource(previous_resource_id, 1)

	var next_equipment := get_equipment_snapshot(npc_id)
	var unit_type := determine_unit_type(next_equipment)
	var event_type := "equipment_changed" if not previous_item.is_empty() else "equipment_given"
	var event := _log_equipment_event(
		npc_id,
		event_type,
		slot,
		item_kind,
		next_item,
		previous_item,
		resource_id,
		unit_type,
		visibility
	)
	var strategy_result := _normalize_combat_strategy_after_equipment_change(npc_id, slot, visibility, true)

	return {
		"ok": true,
		"changed": true,
		"npc_id": npc_id,
		"slot": slot,
		"equipment": next_equipment,
		"previous_equipment": previous_item.duplicate(true),
		"resource_id": resource_id,
		"unit_type": unit_type,
		"unit_type_label": get_unit_type_label(unit_type),
		"combat_strategy": strategy_result,
		"event": event
	}


func _load_weapon_defs() -> void:
	var loaded_defs := _load_array_file(WEAPON_DEFS_FILE)
	for raw_definition in loaded_defs:
		var definition: Dictionary = raw_definition if raw_definition is Dictionary else {}
		var id := str(definition.get("id", ""))
		if id.is_empty():
			push_warning("Skipped weapon definition with empty id.")
			continue
		definition["equipment_slot"] = SLOT_MAIN_WEAPON
		if not definition.has("source_resource_id"):
			definition["source_resource_id"] = "item_%s" % id
		if not definition.has("weapon_class"):
			definition["weapon_class"] = id
		_weapon_defs[id] = definition.duplicate(true)
		_weapon_order.append(id)


func _load_armor_defs() -> void:
	var loaded_defs := _load_array_file(ARMOR_DEFS_FILE)
	for raw_definition in loaded_defs:
		var definition: Dictionary = raw_definition if raw_definition is Dictionary else {}
		var id := str(definition.get("id", ""))
		var slot := _normalize_slot_id(str(definition.get("slot", "")))
		if id.is_empty() or not ARMOR_SLOTS.has(slot):
			push_warning("Skipped invalid armor definition: %s" % JSON.stringify(definition))
			continue
		if not definition.has("source_resource_id"):
			definition["source_resource_id"] = "item_%s" % id
		definition["slot"] = slot
		_armor_defs[id] = definition.duplicate(true)
		if not _armor_order_by_slot.has(slot):
			_armor_order_by_slot[slot] = []
		(_armor_order_by_slot[slot] as Array).append(id)


func _load_mount_defs() -> void:
	var loaded_defs := _load_array_file(MOUNT_DEFS_FILE)
	for raw_definition in loaded_defs:
		var definition: Dictionary = raw_definition if raw_definition is Dictionary else {}
		var id := str(definition.get("id", ""))
		if id.is_empty():
			push_warning("Skipped mount definition with empty id.")
			continue
		definition["slot"] = SLOT_MOUNT
		definition.erase("source_resource_id")
		_mount_defs[id] = definition.duplicate(true)
		_mount_order.append(id)


func _apply_initial_equipment_from_profiles() -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_ids") or not npc_system.has_method("get_npc") or not npc_system.has_method("set_npc_equipment_slot"):
		push_error("EquipmentSystem requires NPCSystem initial equipment interfaces.")
		return

	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var profile: Dictionary = npc_system.get_npc(npc_id)
		var initial_equipment: Dictionary = profile.get("initial_equipment", {}) if profile.get("initial_equipment", {}) is Dictionary else {}
		if initial_equipment.is_empty():
			continue
		var current_equipment := _normalize_equipment(profile.get("equipment", {}))
		for slot in EQUIPMENT_SLOTS:
			if current_equipment.has(slot):
				continue
			if slot == SLOT_MOUNT:
				# Horses are runtime entities owned by HorseSystem, never anonymous story items.
				continue
			var item_id := str(initial_equipment.get(slot, "")).strip_edges()
			if item_id.is_empty():
				continue
			var item_kind := _get_item_kind_for_slot(slot)
			var definition := _get_item_def(item_kind, item_id)
			if definition.is_empty():
				push_warning("Skipped unknown initial equipment %s for NPC %s." % [item_id, npc_id])
				continue
			var expected_slot := _normalize_slot_id(str(definition.get("equipment_slot", definition.get("slot", slot))))
			if expected_slot != slot:
				push_warning("Skipped initial equipment %s for NPC %s because slot %s does not match %s." % [item_id, npc_id, expected_slot, slot])
				continue
			# Story loadouts are part of the initial world state, not a player inventory transfer.
			# They therefore hydrate from the canonical definition without spending resources
			# or recording an equipment_given interaction event.
			if npc_system.set_npc_equipment_slot(npc_id, slot, _make_equipped_item(slot, item_kind, definition)):
				current_equipment[slot] = definition.duplicate(true)


func _load_array_file(file_name: String) -> Array:
	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		push_error("EquipmentSystem requires ConfigLoader autoload.")
		return []
	var loaded: Variant = config_loader.load_data_file(file_name, [])
	if not loaded is Array:
		push_error("Equipment definitions must be a JSON array: %s" % file_name)
		return []
	return loaded


func _get_item_def(item_kind: String, item_id: String) -> Dictionary:
	match item_kind:
		"weapon":
			return get_weapon_def(item_id)
		"armor":
			return get_armor_def(item_id)
		"mount":
			return get_mount_def(item_id)
		_:
			return {}


func _get_item_kind_for_slot(slot: String) -> String:
	if slot == SLOT_MAIN_WEAPON:
		return "weapon"
	if ARMOR_SLOTS.has(slot):
		return "armor"
	if slot == SLOT_MOUNT:
		return "mount"
	return ""


func _make_equipped_item(slot: String, item_kind: String, definition: Dictionary) -> Dictionary:
	var item := definition.duplicate(true)
	item["id"] = str(definition.get("id", ""))
	item["name"] = str(definition.get("name", item.get("id", "")))
	item["slot"] = slot
	item["kind"] = item_kind
	var source_resource_id := str(definition.get("source_resource_id", ""))
	if source_resource_id.is_empty():
		item.erase("source_resource_id")
	else:
		item["source_resource_id"] = source_resource_id
	return item


func _normalize_equipment(raw_equipment: Variant) -> Dictionary:
	var source: Dictionary = raw_equipment if raw_equipment is Dictionary else {}
	var normalized := {}
	for slot in EQUIPMENT_SLOTS:
		var item: Dictionary = source.get(slot, {}) if source.get(slot, {}) is Dictionary else {}
		if not item.is_empty():
			normalized[slot] = item.duplicate(true)
	return normalized


func _normalize_slot_id(slot: String) -> String:
	match slot:
		"head":
			return SLOT_HELMET
		"body":
			return SLOT_CHEST
		"arms":
			return SLOT_BRACERS
		"legs":
			return SLOT_GREAVES
		_:
			return slot


func _log_equipment_event(
	npc_id: String,
	event_type: String,
	slot: String,
	item_kind: String,
	item: Dictionary,
	previous_item: Dictionary,
	resource_id: String,
	unit_type: String,
	visibility: String
) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("record_player_interaction"):
		return {}
	var normalized_visibility := "private" if visibility == "private" else DEFAULT_VISIBILITY
	return memory_system.record_player_interaction(npc_id, event_type, {
		"slot": slot,
		"slot_name": get_slot_label(slot),
		"equipment_kind": item_kind,
		"equipment_id": str(item.get("id", "")),
		"equipment_name": str(item.get("name", "装备")),
		"previous_equipment_id": str(previous_item.get("id", "")),
		"previous_equipment_name": str(previous_item.get("name", "")),
		"resource_id": resource_id,
		"unit_type": unit_type,
		"unit_type_label": get_unit_type_label(unit_type),
		"importance": 55
	}, normalized_visibility)


func _normalize_combat_strategy_after_equipment_change(
	npc_id: String,
	slot: String,
	visibility: String,
	force_default: bool
) -> Dictionary:
	if not [SLOT_MAIN_WEAPON, SLOT_MOUNT].has(slot):
		return {}
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("normalize_npc_combat_strategy"):
		return {}
	return combat_system.normalize_npc_combat_strategy(npc_id, "equipment_changed", visibility, force_default)


func _unassign_horse_after_main_weapon_removed(npc_id: String, visibility: String) -> Dictionary:
	var equipment := get_equipment_snapshot(npc_id)
	if (equipment.get(SLOT_MOUNT, {}) as Dictionary).is_empty():
		return {"ok": true, "changed": false, "reason": "no_horse_assigned"}
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or not horse_system.has_method("unassign_horse_from_npc"):
		return _failure("horse_system_missing", "马匹系统不可用。")
	var raw_result: Variant = horse_system.call(
		"unassign_horse_from_npc",
		npc_id,
		"main_weapon_removed",
		visibility
	)
	if raw_result is Dictionary:
		return (raw_result as Dictionary).duplicate(true)
	return _failure("horse_unassignment_failed", "马匹系统未返回合法解除结果。")


func get_slot_label(slot: String) -> String:
	match slot:
		SLOT_MAIN_WEAPON:
			return "主武器"
		SLOT_HELMET:
			return "头盔"
		SLOT_CHEST:
			return "胸甲"
		SLOT_BRACERS:
			return "腕甲"
		SLOT_GREAVES:
			return "腿甲"
		SLOT_MOUNT:
			return "坐骑"
		_:
			return slot


func _get_resource_name(resource_id: String) -> String:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system != null and resource_system.has_method("get_resource_name"):
		return str(resource_system.get_resource_name(resource_id))
	return resource_id


func _failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "changed": false, "error": code, "message": message}
