extends SceneTree

const LLM_BRIDGE_SCRIPT := preload("res://scripts/systems/LLMBridge.gd")
const MEMORY_SYSTEM_SCRIPT := preload("res://scripts/systems/MemorySystem.gd")
const PRIMARY_NPC_ID := "veteran_deputy_01"
const ALTERNATE_NPC_ID := "cook_01"
const PRIMARY_ENEMY_ID := "raider_sword"
const ALTERNATE_ENEMY_ID := "raider_polearm"
const PRIMARY_WEAPON_ID := "sword_shield"
const ALTERNATE_WEAPON_ID := "polearm"
const PRIMARY_HORSE_ID := "horse_chestnut_wind"
const ALTERNATE_HORSE_ID := "horse_gray_mane"
const DEVICE_ID := "wall_ballista"
const EVENT_TYPES: Array[String] = [
	"attack_made",
	"damage_taken",
	"building_damaged",
	"defense_device_triggered",
	"horse_damaged"
]

var _canonical_names: Dictionary = {}


func _init() -> void:
	if not _load_canonical_names():
		return
	var bridge := LLM_BRIDGE_SCRIPT.new()
	root.add_child(bridge)
	await process_frame
	for event_type in EVENT_TYPES:
		if not _verify_event_type(bridge, event_type):
			return
	if not _verify_key_isolation_matrix(bridge):
		return
	if not _verify_authoritative_memory_untouched(bridge):
		return
	if not _verify_narrative_boundary(bridge):
		return
	print("T0306 memory aggregation verification passed: 5/5 types merged only on identical critical keys; narrative boundary preserved.")
	quit(0)


func _load_canonical_names() -> bool:
	var npc_profiles: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npc_profiles.json"))
	var weapon_defs: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon_defs.json"))
	var building_defs: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_defs.json"))
	var enemy_waves: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_waves.json"))
	var horse_defs: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/horse_defs.json"))
	var defense_defs: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/defense_device_defs.json"))
	if not npc_profiles is Array or not weapon_defs is Array or not building_defs is Array or not enemy_waves is Array:
		return _fail("canonical NPC/weapon/building/enemy definition files are invalid")
	if not horse_defs is Dictionary or not defense_defs is Dictionary:
		return _fail("canonical horse/defense-device definition files are invalid")
	for entry in npc_profiles as Array:
		_register_canonical_name("npc", entry, "id")
	for entry in weapon_defs as Array:
		_register_canonical_name("weapon", entry, "id")
	for entry in building_defs as Array:
		_register_canonical_name("building", entry, "id")
	for wave in enemy_waves as Array:
		if not wave is Dictionary:
			continue
		for enemy in (wave as Dictionary).get("enemies", []):
			_register_canonical_name("enemy", enemy, "enemy_type_id")
	var horse_template_names: Dictionary = {}
	for template in (horse_defs as Dictionary).get("horse_templates", []):
		if template is Dictionary:
			horse_template_names[str((template as Dictionary).get("template_id", ""))] = str((template as Dictionary).get("name", ""))
	for horse in (horse_defs as Dictionary).get("initial_horses", []):
		if not horse is Dictionary:
			continue
		var horse_id := str((horse as Dictionary).get("horse_id", ""))
		var template_id := str((horse as Dictionary).get("template_id", ""))
		_canonical_names["horse:%s" % horse_id] = str(horse_template_names.get(template_id, ""))
	for device in (defense_defs as Dictionary).get("devices", []):
		_register_canonical_name("device", device, "id")
	var required_keys := [
		"npc:%s" % PRIMARY_NPC_ID,
		"npc:%s" % ALTERNATE_NPC_ID,
		"enemy:%s" % PRIMARY_ENEMY_ID,
		"enemy:%s" % ALTERNATE_ENEMY_ID,
		"weapon:%s" % PRIMARY_WEAPON_ID,
		"weapon:%s" % ALTERNATE_WEAPON_ID,
		"horse:%s" % PRIMARY_HORSE_ID,
		"horse:%s" % ALTERNATE_HORSE_ID,
		"device:%s" % DEVICE_ID,
		"building:wall",
		"building:main_hall"
	]
	for key in required_keys:
		if str(_canonical_names.get(key, "")).is_empty():
			return _fail("canonical display name is missing for %s" % key)
	print("CANONICAL_NAMES: %s / %s / %s / %s / %s / %s loaded from formal data." % [
		_name("npc", PRIMARY_NPC_ID),
		_name("horse", PRIMARY_HORSE_ID),
		_name("horse", ALTERNATE_HORSE_ID),
		_name("enemy", PRIMARY_ENEMY_ID),
		_name("weapon", PRIMARY_WEAPON_ID),
		_name("device", DEVICE_ID)
	])
	return true


func _register_canonical_name(category: String, raw_entry: Variant, id_field: String) -> void:
	if not raw_entry is Dictionary:
		return
	var entry: Dictionary = raw_entry
	var entry_id := str(entry.get(id_field, ""))
	var display_name := str(entry.get("name", ""))
	if not entry_id.is_empty() and not display_name.is_empty():
		_canonical_names["%s:%s" % [category, entry_id]] = display_name


func _name(category: String, entry_id: String) -> String:
	return str(_canonical_names.get("%s:%s" % [category, entry_id], ""))


func _verify_event_type(bridge: Node, event_type: String) -> bool:
	var raw_events: Array = [
		_build_event(event_type, 0, false),
		_build_event(event_type, 1, false),
		_build_event(event_type, 2, false),
		_build_event(event_type, 3, true)
	]
	var raw_snapshot := JSON.stringify(raw_events)
	var report: Dictionary = bridge.debug_build_memory_projection_report(raw_events, "experienced")
	var projection: Array = report.get("projection", [])
	if JSON.stringify(raw_events) != raw_snapshot:
		return _fail("%s mutated the raw event fixture" % event_type)
	if int(report.get("raw_count", 0)) != 4 or int(report.get("projected_count", 0)) != 2:
		return _fail("%s expected raw=4 projected=2, got %s" % [event_type, JSON.stringify(report)])
	if projection.size() != 2:
		return _fail("%s projection size mismatch" % event_type)
	var aggregate: Dictionary = projection[0]
	var distinct: Dictionary = projection[1]
	var details: Dictionary = aggregate.get("details", {})
	var aggregation: Dictionary = details.get("aggregation", {})
	if int(aggregation.get("event_count", 0)) != 3:
		return _fail("%s aggregate did not retain event_count=3" % event_type)
	if not is_equal_approx(float(aggregation.get("total_damage", -1)), 20.0):
		return _fail("%s aggregate did not retain total_damage=20" % event_type)
	if not is_equal_approx(float(aggregation.get("hp_before_first", -1)), 100.0):
		return _fail("%s aggregate did not retain first HP=100" % event_type)
	if not is_equal_approx(float(aggregation.get("hp_after_last", -1)), 80.0):
		return _fail("%s aggregate did not retain last HP=80" % event_type)
	if not is_equal_approx(float(aggregation.get("lowest_hp", -1)), 80.0):
		return _fail("%s aggregate did not retain lowest HP=80" % event_type)
	if str(aggregation.get("first_time", "")) != "10:00:00" or str(aggregation.get("last_time", "")) != "10:00:02":
		return _fail("%s aggregate lost first/last time" % event_type)
	if int(aggregate.get("importance", 0)) != 75:
		return _fail("%s aggregate did not retain max importance" % event_type)
	for dynamic_key in ["damage", "damage_after_defense", "hp_before", "hp_after", "defeated"]:
		if details.has(dynamic_key):
			return _fail("%s aggregate kept conflicting per-hit field %s" % [event_type, dynamic_key])
	if details.get(_critical_field(event_type), null) != _critical_value(event_type, false):
		return _fail("%s aggregate lost its critical field" % event_type)
	var distinct_details: Dictionary = distinct.get("details", {})
	if distinct_details.has("aggregation"):
		return _fail("%s incorrectly aggregated the distinct critical-key event" % event_type)
	if distinct_details.get(_critical_field(event_type), null) != _critical_value(event_type, true):
		return _fail("%s distinct event lost its changed critical field" % event_type)
	if event_type == "damage_taken" and not is_equal_approx(float(aggregation.get("total_damage_after_defense", -1)), 17.0):
		return _fail("damage_taken lost total_damage_after_defense=17")
	if ["attack_made", "defense_device_triggered"].has(event_type) and not bool(aggregation.get("defeated_any", false)):
		return _fail("%s aggregate lost its terminal defeated flag" % event_type)
	print("TYPE %s" % event_type)
	print("  BEFORE[4]: %s" % JSON.stringify(_summaries(raw_events), "  "))
	print("  AFTER[2]: %s" % JSON.stringify(_projected_comparison(projection), "  "))
	print("  PROJECTION_CHARS: %d -> %d" % [
		JSON.stringify(_compact_without_aggregation(bridge, raw_events)).length(),
		JSON.stringify(projection).length()
	])
	print("  KEY_CHECK: %s=%s stayed separate from %s" % [
		_critical_field(event_type),
		str(_critical_value(event_type, false)),
		str(_critical_value(event_type, true))
	])
	return true


func _verify_key_isolation_matrix(bridge: Node) -> bool:
	var cases: Array = [
		["attack_made", "attacker"],
		["attack_made", "target"],
		["attack_made", "location"],
		["attack_made", "visibility"],
		["attack_made", "day"],
		["damage_taken", "damage_source"],
		["horse_damaged", "horse_id"]
	]
	for raw_case in cases:
		var event_type := str(raw_case[0])
		var changed_key := str(raw_case[1])
		var first := _build_event(event_type, 0, false)
		var second := _build_event(event_type, 1, false)
		_mutate_isolation_key(second, changed_key)
		var projection: Array = bridge.build_memory_event_projection([first, second], "experienced")
		if projection.size() != 2:
			return _fail("%s incorrectly merged events with different %s" % [event_type, changed_key])
		for projected in projection:
			var details: Dictionary = (projected as Dictionary).get("details", {})
			if details.has("aggregation"):
				return _fail("%s created an aggregate despite different %s" % [event_type, changed_key])
	print("KEY_MATRIX: attacker, target, location, visibility, day, damage_source, and horse_id differences all stayed separate.")
	return true


func _mutate_isolation_key(event: Dictionary, changed_key: String) -> void:
	var payload: Dictionary = event.get("payload", {})
	match changed_key:
		"attacker":
			event["subject_npc_id"] = ALTERNATE_NPC_ID
			event["actor_ids"] = [ALTERNATE_NPC_ID]
			payload["attacker_npc_id"] = ALTERNATE_NPC_ID
			payload["attacker_name"] = _name("npc", ALTERNATE_NPC_ID)
		"target":
			event["target_ids"] = [PRIMARY_NPC_ID, ALTERNATE_ENEMY_ID]
			payload["target_enemy_id"] = ALTERNATE_ENEMY_ID
			payload["target_enemy_name"] = _name("enemy", ALTERNATE_ENEMY_ID)
		"location":
			event["location_id"] = "main_hall"
		"visibility":
			event["visibility"] = "private"
		"day":
			event["day"] = 2
		"damage_source":
			event["actor_ids"] = [ALTERNATE_ENEMY_ID]
			payload["damage_source"] = ALTERNATE_ENEMY_ID
		"horse_id":
			event["target_ids"] = [PRIMARY_NPC_ID, ALTERNATE_HORSE_ID]
			payload["horse_id"] = ALTERNATE_HORSE_ID
			payload["horse_name"] = _name("horse", ALTERNATE_HORSE_ID)
	event["payload"] = payload


func _verify_authoritative_memory_untouched(bridge: Node) -> bool:
	var memory_system := MEMORY_SYSTEM_SCRIPT.new()
	memory_system.name = "MemorySystemFixture"
	root.add_child(memory_system)
	for index in range(4):
		memory_system.add_event(_build_event("attack_made", index, index == 3))
	var before: Dictionary = memory_system.get_npc_short_term_memory(PRIMARY_NPC_ID)
	var ids_before: Dictionary = memory_system.get_npc_short_term_memory_ids(PRIMARY_NPC_ID)
	var before_json := JSON.stringify(before)
	var ids_json := JSON.stringify(ids_before)
	var projection: Array = bridge.build_memory_event_projection(before.get("event_log", []), "experienced")
	var after: Dictionary = memory_system.get_npc_short_term_memory(PRIMARY_NPC_ID)
	var ids_after: Dictionary = memory_system.get_npc_short_term_memory_ids(PRIMARY_NPC_ID)
	if int(before.get("event_count", 0)) != 4 or projection.size() != 2:
		return _fail("authoritative fixture expected archive=4 and LLM projection=2")
	if JSON.stringify(after) != before_json or JSON.stringify(ids_after) != ids_json:
		return _fail("LLM projection changed authoritative event records, IDs, payloads, or order")
	print("ARCHIVE_CHECK: authoritative event_log stayed 4 byte-equivalent records with identical IDs/payload/order; LLM projection was 2.")
	return true


func _verify_narrative_boundary(bridge: Node) -> bool:
	var first := _build_event("attack_made", 0, false)
	var second := _build_event("attack_made", 1, false)
	var boundary := {
		"event_id": "boundary",
		"day": 1,
		"time": "10:00:01",
		"type": "combat_ended",
		"subject_npc_id": PRIMARY_NPC_ID,
		"actor_ids": [PRIMARY_NPC_ID],
		"target_ids": ["wave_01"],
		"location_id": "plaza",
		"visibility": "local_public",
		"importance": 80,
		"summary": "第一场交战结束。",
		"payload": {"wave_id": "wave_01"}
	}
	var projection: Array = bridge.build_memory_event_projection([first, boundary, second], "experienced")
	if projection.size() != 3:
		return _fail("non-whitelisted narrative boundary was crossed by aggregation")
	if (projection[0] as Dictionary).get("details", {}).has("aggregation"):
		return _fail("event before narrative boundary was unexpectedly aggregated")
	print("BOUNDARY_CHECK: attack_made + combat_ended + same-key attack_made stayed 3 records.")
	return true


func _build_event(event_type: String, index: int, distinct_key: bool) -> Dictionary:
	var damage_values := [5, 7, 8, 9]
	var hp_before_values := [100, 95, 88, 71]
	var hp_after_values := [95, 88, 80, 62]
	var payload := _base_payload(event_type, distinct_key)
	payload["damage"] = damage_values[index]
	payload["hp_before"] = hp_before_values[index]
	payload["hp_after"] = hp_after_values[index]
	if event_type == "damage_taken":
		payload["damage_after_defense"] = [4, 6, 7, 8][index]
	if ["attack_made", "defense_device_triggered"].has(event_type):
		payload["defeated"] = index == 2
	var actors := [PRIMARY_ENEMY_ID] if ["damage_taken", "building_damaged", "horse_damaged"].has(event_type) else [PRIMARY_NPC_ID]
	if event_type == "defense_device_triggered":
		actors = ["guard_officer", DEVICE_ID]
	var targets := _target_ids(event_type)
	return {
		"event_id": "%s_%d" % [event_type, index],
		"day": 1,
		"time": "10:00:%02d" % index,
		"type": event_type,
		"subject_npc_id": _subject_id(event_type),
		"actor_ids": actors,
		"target_ids": targets,
		"location_id": "plaza",
		"visibility": "local_public",
		"importance": 75 if index == 2 else 55,
		"summary": _raw_summary(event_type, damage_values[index], hp_before_values[index], hp_after_values[index], payload),
		"payload": payload
	}


func _base_payload(event_type: String, distinct_key: bool) -> Dictionary:
	match event_type:
		"attack_made":
			var weapon_id := ALTERNATE_WEAPON_ID if distinct_key else PRIMARY_WEAPON_ID
			return {
				"attacker_npc_id": PRIMARY_NPC_ID, "attacker_name": _name("npc", PRIMARY_NPC_ID),
				"target_type": "enemy", "target_enemy_id": PRIMARY_ENEMY_ID, "target_enemy_name": _name("enemy", PRIMARY_ENEMY_ID),
				"weapon_id": weapon_id, "weapon_name": _name("weapon", weapon_id),
				"required_skill": "长杆" if distinct_key else "剑盾", "weapon_skill": 4, "strength": 4, "base_damage": 5.0,
				"strength_multiplier": 1.2, "raw_attack_power": 6.0, "attack_speed_multiplier": 1.0,
				"attack_interval": 1.0, "target_defense": 2.0
			}
		"damage_taken":
			return {
				"damage_source": PRIMARY_ENEMY_ID, "interaction_kind": "ranged" if distinct_key else "melee",
				"event_text": "敌军攻击", "attack_prompt": "压制守军", "raw_attack_power": 9.0, "target_defense": 2.0
			}
		"building_damaged":
			var building_id := "main_hall" if distinct_key else "wall"
			return {
				"building_id": building_id,
				"building_name": _name("building", building_id), "damage_source": PRIMARY_ENEMY_ID
			}
		"defense_device_triggered":
			return {
				"deployment_id": "deploy_02" if distinct_key else "deploy_01", "device_id": DEVICE_ID,
				"device_name": _name("device", DEVICE_ID), "slot_id": "wall_slot_01", "target_enemy_id": PRIMARY_ENEMY_ID,
				"target_enemy_name": _name("enemy", PRIMARY_ENEMY_ID)
			}
		"horse_damaged":
			return {
				"target_npc_id": PRIMARY_NPC_ID, "horse_id": PRIMARY_HORSE_ID, "horse_name": _name("horse", PRIMARY_HORSE_ID),
				"share_ratio": 0.75 if distinct_key else 0.5, "enemy_id": PRIMARY_ENEMY_ID, "enemy_name": _name("enemy", PRIMARY_ENEMY_ID)
			}
	return {}


func _target_ids(event_type: String) -> Array[String]:
	match event_type:
		"attack_made": return [PRIMARY_NPC_ID, PRIMARY_ENEMY_ID]
		"damage_taken": return [PRIMARY_NPC_ID, "plaza"]
		"building_damaged": return ["wall", "plaza"]
		"defense_device_triggered": return [PRIMARY_ENEMY_ID, "wall_slot_01"]
		"horse_damaged": return [PRIMARY_NPC_ID, PRIMARY_HORSE_ID]
	return []


func _subject_id(event_type: String) -> String:
	if event_type == "building_damaged": return PRIMARY_ENEMY_ID
	if event_type == "defense_device_triggered": return "guard_officer"
	return PRIMARY_NPC_ID


func _raw_summary(event_type: String, damage: int, hp_before: int, hp_after: int, payload: Dictionary) -> String:
	match event_type:
		"attack_made": return "%s攻击了%s，造成%d点伤害。" % [str(payload.get("attacker_name", "NPC")), str(payload.get("target_enemy_name", "敌人")), damage]
		"damage_taken": return "%s受到%s造成的%d点伤害，HP 从%d降到%d。" % [_name("npc", PRIMARY_NPC_ID), _name("enemy", PRIMARY_ENEMY_ID), damage, hp_before, hp_after]
		"building_damaged": return "%s攻击了%s，造成%d点建筑伤害，HP 从%d降到%d。" % [_name("enemy", PRIMARY_ENEMY_ID), str(payload.get("building_name", "建筑")), damage, hp_before, hp_after]
		"defense_device_triggered": return "守备官部署的%s攻击了%s，造成%d点伤害。" % [str(payload.get("device_name", "防御器械")), str(payload.get("target_enemy_name", "敌人")), damage]
		"horse_damaged": return "%s骑乘的%s承受了%d点伤害，HP 从%d降到%d。" % [_name("npc", PRIMARY_NPC_ID), str(payload.get("horse_name", "马匹")), damage, hp_before, hp_after]
	return event_type


func _critical_field(event_type: String) -> String:
	match event_type:
		"attack_made": return "weapon_id"
		"damage_taken": return "interaction_kind"
		"building_damaged": return "building_id"
		"defense_device_triggered": return "deployment_id"
		"horse_damaged": return "share_ratio"
	return ""


func _critical_value(event_type: String, distinct: bool) -> Variant:
	match event_type:
		"attack_made": return ALTERNATE_WEAPON_ID if distinct else PRIMARY_WEAPON_ID
		"damage_taken": return "ranged" if distinct else "melee"
		"building_damaged": return "main_hall" if distinct else "wall"
		"defense_device_triggered": return "deploy_02" if distinct else "deploy_01"
		"horse_damaged": return 0.75 if distinct else 0.5
	return null


func _summaries(events: Array) -> Array[String]:
	var result: Array[String] = []
	for event in events:
		result.append(str((event as Dictionary).get("summary", "")))
	return result


func _compact_without_aggregation(bridge: Node, events: Array) -> Array:
	var result: Array = []
	for event in events:
		result.append(bridge.build_compact_memory_event(event as Dictionary))
	return result


func _projected_comparison(events: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		var projected: Dictionary = event
		var details: Dictionary = projected.get("details", {})
		result.append({
			"summary": projected.get("summary", ""),
			"critical_field": details.get(_critical_field(str(projected.get("type", ""))), null),
			"aggregation": details.get("aggregation", null)
		})
	return result


func _fail(message: String) -> bool:
	push_error("T0306 verification failed: %s" % message)
	quit(1)
	return false
