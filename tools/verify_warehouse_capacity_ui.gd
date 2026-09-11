extends SceneTree


const LIMITED_CAPACITIES_LEVEL_1 := {
	"grain": 120,
	"meal": 120,
	"wine": 60,
	"wood": 120,
	"stone": 120,
	"iron": 120
}
const LIMITED_CAPACITIES_LEVEL_2 := {
	"grain": 180,
	"meal": 180,
	"wine": 90,
	"wood": 180,
	"stone": 180,
	"iron": 180
}
const LIMITED_RESOURCE_ORDER: Array[String] = ["grain", "meal", "wine", "wood", "stone", "iron"]
const NORMAL_FILL := "71865aff"
const DANGER_FILL := "a7433bff"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel")
	var hud := root.get_node_or_null("Main/UI/HUD")
	if (
		resource_system == null
		or building_system == null
		or building_panel == null
		or hud == null
	):
		_fail("Warehouse capacity verification nodes not found")
		return

	if not _verify_capacities(resource_system, LIMITED_CAPACITIES_LEVEL_1):
		return
	if int(resource_system.get_resource_capacity("money")) != -1:
		_fail("Money must remain outside warehouse capacity")
		return

	var grain_before := int(resource_system.get_resource("grain"))
	var grain_remaining := int(resource_system.get_resource_remaining_capacity("grain"))
	if (
		grain_remaining <= 0
		or not bool(resource_system.add_resource("grain", grain_remaining))
		or int(resource_system.get_resource("grain")) != 120
	):
		_fail("A limited resource must be able to fill exactly to its capacity")
		return
	if (
		bool(resource_system.add_resource("grain", 1))
		or int(resource_system.get_resource("grain")) != 120
	):
		_fail("A positive resource addition must be rejected atomically above capacity")
		return
	if bool(resource_system.add_resources({"grain": 1, "money": 2})):
		_fail("A multi-resource addition must reject the whole batch when one item overflows")
		return
	if int(resource_system.get_resource("money")) != 30:
		_fail("Rejected multi-resource addition changed an unlimited resource")
		return
	if not bool(resource_system.add_resource("grain", grain_before - 120)):
		_fail("Failed to restore grain after the authority-capacity check")
		return

	building_panel.show_building("warehouse")
	await process_frame
	await process_frame
	await process_frame
	var capacity_label := building_panel.find_child(
		"WarehouseCapacityLabel",
		true,
		false
	) as Label
	var storage_section := building_panel.find_child("WarehouseStorageSection", true, false) as VBoxContainer
	var storage_list := building_panel.find_child("WarehouseStorageList", true, false) as VBoxContainer
	if capacity_label == null or storage_section == null or storage_list == null or not storage_section.visible:
		_fail("Warehouse building panel did not show its storage section")
		return
	if capacity_label.text != "储存状况" or capacity_label.text.contains("储存上限"):
		_fail("Warehouse storage heading mismatch: %s" % capacity_label.text)
		return
	var level_1_snapshot: Array = resource_system.get_warehouse_capacity_snapshot()
	if storage_list.get_child_count() != LIMITED_RESOURCE_ORDER.size():
		_fail("Warehouse storage list should contain exactly six resource rows")
		return
	for index in LIMITED_RESOURCE_ORDER.size():
		var resource_id := LIMITED_RESOURCE_ORDER[index]
		var item: Dictionary = level_1_snapshot[index]
		var row := building_panel.find_child("WarehouseStorageRow_%s" % resource_id, true, false) as VBoxContainer
		var storage_label := building_panel.find_child("WarehouseStorageLabel_%s" % resource_id, true, false) as Label
		var progress := building_panel.find_child("WarehouseStorageProgress_%s" % resource_id, true, false) as ProgressBar
		var fill := progress.get_theme_stylebox("fill") as StyleBoxFlat if progress != null else null
		if (
			row == null
			or storage_label == null
			or progress == null
			or row.get_index() != index
			or storage_label.text != "%s %d/%d" % [str(item.get("name", "")), int(item.get("amount", 0)), int(item.get("capacity", 0))]
			or int(progress.value) != int(item.get("amount", 0))
			or int(progress.max_value) != int(item.get("capacity", 0))
			or bool(progress.get_meta("danger_state", true))
			or fill == null
			or fill.bg_color.to_html(true) != NORMAL_FILL
		):
			_fail("Warehouse storage row mismatch: %s" % resource_id)
			return

	var grain_progress := building_panel.find_child("WarehouseStorageProgress_grain", true, false) as ProgressBar
	var grain_storage_label := building_panel.find_child("WarehouseStorageLabel_grain", true, false) as Label
	if not bool(resource_system.add_resource("grain", 96 - grain_before)):
		_fail("Failed to set grain to the near-full threshold")
		return
	await process_frame
	var grain_fill := grain_progress.get_theme_stylebox("fill") as StyleBoxFlat
	if grain_storage_label.text != "粮食 96/120" or not bool(grain_progress.get_meta("danger_state", false)) or grain_fill == null or grain_fill.bg_color.to_html(true) != DANGER_FILL:
		_fail("Warehouse storage bar did not turn red at 80 percent")
		return
	if not bool(resource_system.add_resource("grain", -1)):
		_fail("Failed to lower grain below the near-full threshold")
		return
	await process_frame
	grain_fill = grain_progress.get_theme_stylebox("fill") as StyleBoxFlat
	if grain_storage_label.text != "粮食 95/120" or bool(grain_progress.get_meta("danger_state", true)) or grain_fill == null or grain_fill.bg_color.to_html(true) != NORMAL_FILL:
		_fail("Warehouse storage bar did not return to green below 80 percent")
		return
	if not bool(resource_system.add_resource("grain", grain_before - 95)):
		_fail("Failed to restore grain after storage-bar verification")
		return
	await process_frame

	building_panel.show_building("main_hall")
	await process_frame
	if storage_section.visible:
		_fail("Warehouse storage section remained visible for another building")
		return
	building_panel.show_building("warehouse")
	await process_frame

	var grain_label := hud.find_child("GrainResourceLabel", true, false) as Label
	var wine_label := hud.find_child("WineResourceLabel", true, false) as Label
	var money_label := hud.find_child("MoneyResourceLabel", true, false) as Label
	var grain_icon := hud.get_node_or_null("ResourceStrip/GrainResourceItem/Icon") as TextureRect
	var wine_icon := hud.get_node_or_null("ResourceStrip/WineResourceItem/Icon") as TextureRect
	var money_icon := hud.get_node_or_null("ResourceStrip/MoneyResourceItem/Icon") as TextureRect
	if (
		grain_label == null
		or wine_label == null
		or money_label == null
		or grain_icon == null
		or wine_icon == null
		or money_icon == null
		or grain_icon.tooltip_text != "粮食\n仓库储存上限：120"
		or wine_icon.tooltip_text != "酒\n仓库储存上限：60"
		or money_icon.tooltip_text != "金钱"
		or grain_icon.mouse_filter != Control.MOUSE_FILTER_STOP
		or grain_label.mouse_filter != Control.MOUSE_FILTER_IGNORE
	):
		_fail("Top-left resource hover capacity hints are incomplete")
		return

	if not bool(building_system.upgrade_building("warehouse")):
		_fail("Warehouse level-2 upgrade failed to start")
		return
	building_system._on_logical_time_tick(999999.0, 1.0)
	await process_frame
	await process_frame
	await process_frame
	if int(building_system.get_building("warehouse").get("level", 0)) != 2:
		_fail("Warehouse upgrade did not complete")
		return
	if not _verify_capacities(resource_system, LIMITED_CAPACITIES_LEVEL_2):
		return
	if (
		grain_storage_label.text != "粮食 %d/180" % grain_before
		or int(grain_progress.max_value) != 180
		or str((building_panel.find_child("WarehouseStorageLabel_wine", true, false) as Label).text) != "酒 0/90"
		or grain_icon.tooltip_text != "粮食\n仓库储存上限：180"
		or wine_icon.tooltip_text != "酒\n仓库储存上限：90"
	):
		_fail("Warehouse panel or HUD hover hints did not refresh after the upgrade")
		return

	print(
		"Warehouse capacity authority and UI verification passed: "
		+ "six limited resources, per-resource storage bars, 80-percent warning, level-1/2 refresh, "
		+ "and top-left hover hints."
	)
	quit(0)


func _verify_capacities(resource_system: Node, expected: Dictionary) -> bool:
	var snapshot: Array = resource_system.get_warehouse_capacity_snapshot()
	if snapshot.size() != expected.size():
		_fail("Warehouse capacity snapshot should contain exactly six bulk resources")
		return false
	for raw_resource_id in expected.keys():
		var resource_id := str(raw_resource_id)
		if int(resource_system.get_resource_capacity(resource_id)) != int(expected[resource_id]):
			_fail("Unexpected capacity for %s" % resource_id)
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
