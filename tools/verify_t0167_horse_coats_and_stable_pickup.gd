extends SceneTree


const GLEN_ID := "blacksmith_01"
const GRAY_HORSE_ID := "horse_gray_mane"
const MAX_PHYSICS_FRAMES := 3000
const GRAY_TEMPLATE_IDS := [
	"gray_mane", "snow_star", "frost_hoof", "silver_bell", "ash_tail",
	"moon_frost", "iron_cloud", "mist_step"
]


func _init() -> void:
	if not _verify_template_palette():
		return
	if not _verify_pickup_contract():
		return

	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	for _index in range(8):
		await physics_frame

	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if equipment_system == null or horse_system == null or npc_system == null or combat_system == null:
		_fail("T0167 runtime dependencies are missing")
		return
	if time_system != null and time_system.has_method("set_paused"):
		time_system.set_paused(false)

	var preset: Dictionary = equipment_system.debug_apply_combat_loadout_preset()
	if not bool(preset.get("ok", false)):
		_fail("Could not apply the eight-NPC combat preset: %s" % JSON.stringify(preset))
		return
	var assigned_gray: Dictionary = horse_system.get_horse_snapshot(GRAY_HORSE_ID)
	if str(assigned_gray.get("assigned_npc_id", "")) != GLEN_ID:
		_fail("Glen was not assigned Gray Mane: %s" % JSON.stringify(assigned_gray))
		return

	var alarm: Dictionary = combat_system.trigger_combat_alarm("t0167_glen_gray_mane_pickup")
	if not bool(alarm.get("ok", false)):
		_fail("Could not trigger Glen's pickup rally: %s" % JSON.stringify(alarm))
		return
	await physics_frame

	var waiting_horse: Dictionary = horse_system.get_horse_snapshot(GRAY_HORSE_ID)
	var movement: Dictionary = waiting_horse.get("movement_state", {})
	var pickup_position: Vector3 = movement.get("target_position", Vector3.ZERO)
	var horse_position: Vector3 = waiting_horse.get("world_position", Vector3.ZERO)
	if (
		str(movement.get("phase", "")) != "waiting_for_rider_at_stable"
		or str(movement.get("pickup_source", "")) != "stable_slot_open_side"
		or int(movement.get("navigation_path_point_count", 0)) < 2
	):
		_fail("Gray Mane did not expose a reachable open-side pickup route: %s" % JSON.stringify(waiting_horse))
		return
	var pickup_distance := Vector2(pickup_position.x - horse_position.x, pickup_position.z - horse_position.z).length()
	if pickup_distance < 1.15 or pickup_distance > 2.35:
		_fail("Gray Mane pickup point is not beside its actual stall: %.3f" % pickup_distance)
		return

	var raw_start: Variant = npc_system.get_npc_world_position(GLEN_ID)
	var start_position: Vector3 = raw_start if raw_start is Vector3 else Vector3.ZERO
	var best_distance := start_position.distance_to(pickup_position)
	var mounted := false
	var rallied := false
	for _frame in range(MAX_PHYSICS_FRAMES):
		await physics_frame
		var raw_position: Variant = npc_system.get_npc_world_position(GLEN_ID)
		if raw_position is Vector3:
			best_distance = minf(best_distance, (raw_position as Vector3).distance_to(pickup_position))
		var state: Dictionary = npc_system.get_npc_state(GLEN_ID)
		if bool(state.get("combat_mounted", false)):
			mounted = true
		var rally := _find_rally(combat_system.get_active_rallies(), GLEN_ID)
		if str(rally.get("status", "")) == "rallied":
			rallied = true
			break

	if not mounted:
		_fail("Glen remained blocked at a stable partition; best pickup distance %.3f" % best_distance)
		return
	if not rallied:
		_fail("Glen mounted Gray Mane but did not resume the reserved front-gate formation")
		return
	var ridden_gray: Dictionary = horse_system.get_horse_snapshot(GRAY_HORSE_ID)
	if str(ridden_gray.get("location", "")) != "ridden" or str(ridden_gray.get("ridden_by_npc_id", "")) != GLEN_ID:
		_fail("Mounted state did not retain Gray Mane's identity: %s" % JSON.stringify(ridden_gray))
		return

	print("T0167 natural horse coats and Glen open-side stable pickup verification passed.")
	quit(0)


func _verify_template_palette() -> bool:
	var defs := _load_json("res://data/horse_defs.json")
	var templates: Array = defs.get("horse_templates", [])
	if templates.size() != 24:
		_fail("Horse template pool must retain 24 identities")
		return false
	var ids := {}
	var names := {}
	var colors := {}
	for raw_template in templates:
		if not raw_template is Dictionary:
			_fail("Horse template entry is not an object")
			return false
		var template: Dictionary = raw_template
		var template_id := str(template.get("template_id", ""))
		var horse_name := str(template.get("name", ""))
		var coat_name := str(template.get("coat_name", ""))
		var color_text := str(template.get("coat_color", ""))
		if template_id.is_empty() or horse_name.is_empty() or coat_name.is_empty() or not Color.html_is_valid(color_text):
			_fail("Horse template identity/color is incomplete: %s" % JSON.stringify(template))
			return false
		if ids.has(template_id) or names.has(horse_name) or colors.has(color_text):
			_fail("Horse templates must keep unique IDs, names and exact colors: %s" % JSON.stringify(template))
			return false
		ids[template_id] = true
		names[horse_name] = true
		colors[color_text] = true
		var coat := Color.from_string(color_text, Color.WHITE)
		var luminance := coat.get_luminance()
		if luminance < 0.12 or luminance > 0.82:
			_fail("Horse coat lies outside a natural readable luminance range: %s" % JSON.stringify(template))
			return false
		if GRAY_TEMPLATE_IDS.has(template_id):
			var channel_span := maxf(coat.r, maxf(coat.g, coat.b)) - minf(coat.r, minf(coat.g, coat.b))
			if coat.r < coat.b or channel_span > 0.16:
				_fail("Gray-family coat must be low-saturation and warm/neutral, not cement blue-gray: %s" % JSON.stringify(template))
				return false
	var gray: Dictionary = _find_template(templates, "gray_mane")
	if str(gray.get("name", "")) != "灰鬃" or str(gray.get("coat_name", "")) != "暖烟灰" or str(gray.get("coat_color", "")) != "#645447":
		_fail("Gray Mane's audited warm-gray identity drifted: %s" % JSON.stringify(gray))
		return false
	return true


func _verify_pickup_contract() -> bool:
	var defs := _load_json("res://data/building_fixture_layouts.json")
	var stable: Dictionary = (defs.get("buildings", {}) as Dictionary).get("stable", {})
	var pickup_ids := {}
	for raw_fixture in stable.get("fixtures", []):
		if not raw_fixture is Dictionary:
			continue
		var fixture: Dictionary = raw_fixture
		var horse_anchor: Dictionary = fixture.get("horse_anchor", {})
		if horse_anchor.is_empty():
			continue
		var anchor_id := str(horse_anchor.get("id", ""))
		var center := _to_vector2(horse_anchor.get("center", []))
		var pickup := _to_vector2(horse_anchor.get("pickup_center", []))
		var opening_side := str(fixture.get("opening_side", ""))
		var distance := center.distance_to(pickup)
		var open_side_ok := pickup.x > center.x if opening_side == "right" else pickup.x < center.x
		if anchor_id.is_empty() or pickup_ids.has(anchor_id) or distance < 1.2 or distance > 2.3 or not open_side_ok:
			_fail("Invalid stable pickup contract: %s" % JSON.stringify(fixture))
			return false
		pickup_ids[anchor_id] = true
	if pickup_ids.size() != 8:
		_fail("All eight stable slots must expose open-side pickup centers")
		return false
	return true


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _find_template(templates: Array, template_id: String) -> Dictionary:
	for raw_template in templates:
		if raw_template is Dictionary and str((raw_template as Dictionary).get("template_id", "")) == template_id:
			return (raw_template as Dictionary).duplicate(true)
	return {}


func _find_rally(entries: Array, npc_id: String) -> Dictionary:
	for raw_entry in entries:
		if raw_entry is Dictionary and str((raw_entry as Dictionary).get("npc_id", "")) == npc_id:
			return (raw_entry as Dictionary).duplicate(true)
	return {}


func _to_vector2(raw_value: Variant) -> Vector2:
	if raw_value is Array and (raw_value as Array).size() >= 2:
		return Vector2(float(raw_value[0]), float(raw_value[1]))
	return Vector2(INF, INF)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
