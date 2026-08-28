extends SceneTree


const EXPECTED_LOADOUTS := {
	"veteran_deputy_01": {"weapon": "sword_shield", "full_armor": true, "horse": "horse_chestnut_wind", "unit_type": "cavalry"},
	"cook_01": {"weapon": "sword_shield", "full_armor": false, "horse": "", "unit_type": "melee_infantry"},
	"gardener_01": {"weapon": "polearm", "full_armor": true, "horse": "", "unit_type": "polearm_infantry"},
	"blacksmith_01": {"weapon": "polearm", "full_armor": false, "horse": "horse_gray_mane", "unit_type": "cavalry"},
	"priest_01": {"weapon": "crossbow", "full_armor": false, "horse": "", "unit_type": "crossbowman"},
	"doctor_01": {"weapon": "bow", "full_armor": true, "horse": "", "unit_type": "archer"},
	"stableman_01": {"weapon": "bow", "full_armor": false, "horse": "horse_gm_bay_runner", "unit_type": "mounted_ranged"},
	"engineer_01": {"weapon": "crossbow", "full_armor": true, "horse": "horse_gm_black_mane", "unit_type": "mounted_ranged"},
}
const ARMOR_IDS := {
	"helmet": "iron_helmet",
	"chest": "mail_chest",
	"bracers": "iron_bracers",
	"greaves": "iron_greaves",
}


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	for _index in range(6):
		await physics_frame

	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	if gm_window == null or npc_system == null or equipment_system == null or horse_system == null or resource_system == null or combat_system == null:
		_fail("T0161 verification dependencies are missing")
		return
	var button := gm_window.find_child("RecruitAndEquipAllButton", true, false) as Button
	if button == null or button.text != "一键征召&配装":
		_fail("GM NPC section does not expose the one-click recruit/equip button")
		return
	if int(horse_system.get_horse_count()) != 2:
		_fail("T0161 must begin from the two configured story horses")
		return

	button.pressed.emit()
	await process_frame
	if not _assert_expected_loadouts(npc_system, equipment_system, horse_system):
		return
	if int(horse_system.get_horse_count()) != 4:
		_fail("One-click loadout must ensure exactly four available test horses")
		return
	for debug_horse_id in ["horse_gm_bay_runner", "horse_gm_black_mane"]:
		var debug_horse: Dictionary = horse_system.get_horse_snapshot(debug_horse_id)
		if not bool(debug_horse.get("debug_created", false)) or not bool(debug_horse.get("is_adult", false)):
			_fail("Configured GM horse was not created as an adult debug horse: %s" % debug_horse_id)
			return

	var stable_snapshot_before_repeat: Dictionary = horse_system.get_horse_state_snapshot()
	var inventory_before_repeat: Dictionary = resource_system.get_resource_snapshot()
	button.pressed.emit()
	await process_frame
	if horse_system.get_horse_state_snapshot() != stable_snapshot_before_repeat:
		_fail("Repeated GM preset click changed or duplicated horse state")
		return
	if resource_system.get_resource_snapshot() != inventory_before_repeat:
		_fail("Repeated GM preset click changed inventory")
		return
	if not _assert_expected_loadouts(npc_system, equipment_system, horse_system):
		return
	var idempotent_result: Dictionary = equipment_system.debug_apply_combat_loadout_preset()
	if not bool(idempotent_result.get("ok", false)) or bool(idempotent_result.get("changed", true)) or not bool(idempotent_result.get("already_applied", false)):
		_fail("Applied GM preset did not return an idempotent snapshot: %s" % JSON.stringify(idempotent_result))
		return

	var alarm_result: Dictionary = combat_system.trigger_combat_alarm("t0161_loadout_formation")
	if not bool(alarm_result.get("ok", false)) or int(alarm_result.get("rallied_count", 0)) != 8:
		_fail("All eight preset NPCs did not answer the alarm: %s" % JSON.stringify(alarm_result))
		return
	var row_counts := {}
	for raw_rally in combat_system.get_active_rallies():
		var row := str((raw_rally as Dictionary).get("formation_row", ""))
		row_counts[row] = int(row_counts.get(row, 0)) + 1
	if row_counts != {"melee_front": 2, "ranged_rear": 2, "cavalry_left": 2, "cavalry_right": 2}:
		_fail("Preset force did not produce the expected T0160 formation: %s" % JSON.stringify(row_counts))
		return

	print("T0161 GM one-click recruitment and eight-NPC loadout verification passed.")
	quit(0)


func _assert_expected_loadouts(npc_system: Node, equipment_system: Node, horse_system: Node) -> bool:
	var assigned_horse_ids := {}
	for raw_npc_id in EXPECTED_LOADOUTS.keys():
		var npc_id := str(raw_npc_id)
		var expected: Dictionary = EXPECTED_LOADOUTS[npc_id]
		var npc: Dictionary = npc_system.get_npc(npc_id)
		if not bool(npc.get("recruited", false)):
			_fail("Preset NPC was not recruited: %s" % npc_id)
			return false
		var equipment: Dictionary = equipment_system.get_equipment_snapshot(npc_id)
		if str((equipment.get("main_weapon", {}) as Dictionary).get("id", "")) != str(expected.get("weapon", "")):
			_fail("Preset weapon mismatch for %s: %s" % [npc_id, JSON.stringify(equipment)])
			return false
		for raw_slot in ARMOR_IDS.keys():
			var slot := str(raw_slot)
			var expected_armor_id := str(ARMOR_IDS[slot]) if bool(expected.get("full_armor", false)) else ""
			if str((equipment.get(slot, {}) as Dictionary).get("id", "")) != expected_armor_id:
				_fail("Preset armor mismatch for %s/%s: %s" % [npc_id, slot, JSON.stringify(equipment)])
				return false
		var horse_id := str((equipment.get("mount", {}) as Dictionary).get("horse_id", ""))
		if horse_id != str(expected.get("horse", "")):
			_fail("Preset horse mismatch for %s: %s" % [npc_id, JSON.stringify(equipment)])
			return false
		if not horse_id.is_empty():
			if assigned_horse_ids.has(horse_id):
				_fail("Preset horse was assigned twice: %s" % horse_id)
				return false
			assigned_horse_ids[horse_id] = true
			if str(horse_system.get_horse_snapshot(horse_id).get("assigned_npc_id", "")) != npc_id:
				_fail("HorseSystem assignment mismatch for %s" % npc_id)
				return false
		if str(equipment_system.get_npc_unit_type(npc_id)) != str(expected.get("unit_type", "")):
			_fail("Preset unit type mismatch for %s" % npc_id)
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
