extends SceneTree


const SLOT_NAMES := ["MainWeapon", "Helmet", "Chest", "Bracers", "Greaves", "Mount"]
const EQUIPPED_ITEMS := {
	"main_weapon": "sword_shield",
	"helmet": "iron_helmet",
	"chest": "mail_chest",
	"bracers": "iron_bracers",
	"greaves": "iron_greaves",
	"mount": "horse_chestnut_wind",
}
const FORBIDDEN_TEXT := ["开发装备台", "文字占位库存", "已穿戴", "只在战斗模式显示"]

var _failures: Array[String] = []


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/debug/NPCDevLab.tscn") as PackedScene
	_check(packed != null, "NPCDevLab scene should load")
	if packed == null:
		_finish()
		return
	var lab := packed.instantiate()
	root.add_child(lab)
	for _frame in 10:
		await process_frame
	var panel := lab.find_child("EquipmentPanel", true, false) as PanelContainer
	_check(panel != null, "EquipmentPanel should exist")
	if panel == null:
		_finish()
		return
	_check(panel.size.x <= 320.5 and panel.size.y <= 332.5, "icon-only panel should not retain the old text rows or width")
	_check(_panel_text(panel).is_empty(), "equipment panel should not contain standalone labels")
	_assert_empty_slots(panel)

	for slot in EQUIPPED_ITEMS:
		lab.call("debug_equip", slot, str(EQUIPPED_ITEMS[slot]))
	await process_frame
	_assert_equipped_slots(panel)
	_assert_centerline_slots(panel)
	_check(_panel_text(panel).is_empty(), "equipped panel should stay free of title and status labels")

	lab.call("debug_select_unit", "enemy:raider_mounted_archer")
	await process_frame
	var enemy_weapon := panel.find_child("MainWeaponSlotButton", true, false) as Button
	var enemy_mount := panel.find_child("MountSlotButton", true, false) as Button
	_check(enemy_weapon != null and enemy_weapon.disabled and enemy_weapon.text.is_empty() and enemy_weapon.icon != null, "enemy fixed weapon should remain a read-only icon")
	_check(enemy_mount != null and enemy_mount.disabled and enemy_mount.text.is_empty() and enemy_mount.icon != null, "enemy fixed mount should resolve to a read-only icon")
	for forbidden in FORBIDDEN_TEXT:
		_check(not _panel_text(panel).contains(forbidden), "forbidden panel copy remained: %s" % forbidden)
	_finish()


func _assert_empty_slots(panel: Control) -> void:
	for slot_name in SLOT_NAMES:
		var button := panel.find_child("%sSlotButton" % slot_name, true, false) as Button
		_check(button != null, "%s slot should exist" % slot_name)
		if button == null:
			continue
		_check(button.text == "+", "%s empty slot should show only plus" % slot_name)
		_check(button.icon == null, "%s empty slot should have no icon" % slot_name)
		_check(not button.tooltip_text.is_empty(), "%s slot should keep its label in Tooltip" % slot_name)


func _assert_equipped_slots(panel: Control) -> void:
	for slot_name in SLOT_NAMES:
		var button := panel.find_child("%sSlotButton" % slot_name, true, false) as Button
		_check(button != null, "%s equipped slot should exist" % slot_name)
		if button == null:
			continue
		_check(button.text.is_empty(), "%s equipped slot should not show text" % slot_name)
		_check(button.icon != null, "%s equipped slot should show its configured icon" % slot_name)
		_check(button.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER, "%s equipped icon should be horizontally centered" % slot_name)
		_check(button.vertical_icon_alignment == VERTICAL_ALIGNMENT_CENTER, "%s equipped icon should be vertically centered" % slot_name)


func _assert_centerline_slots(panel: Control) -> void:
	var silhouette := panel.find_child("TwoHeadSilhouette", true, false) as Control
	_check(silhouette != null, "equipment silhouette should exist")
	if silhouette == null:
		return
	var center_x := silhouette.global_position.x + silhouette.size.x * 0.5
	for slot_name in ["Helmet", "Chest", "Greaves", "Mount"]:
		var button := panel.find_child("%sSlotButton" % slot_name, true, false) as Button
		if button == null:
			continue
		var button_center_x := button.global_position.x + button.size.x * 0.5
		_check(is_equal_approx(button_center_x, center_x), "%s slot should share the silhouette centerline" % slot_name)


func _panel_text(panel: Control) -> String:
	var result := ""
	for raw_label in panel.find_children("*", "Label", true, false):
		result += str((raw_label as Label).text)
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0175_EQUIPMENT_PANEL_ICONS PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0175_EQUIPMENT_PANEL_ICONS FAIL count=%d" % _failures.size())
	quit(1)
