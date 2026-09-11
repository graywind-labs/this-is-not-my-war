extends SceneTree


const ICON_SIZE := Vector2i(512, 512)
var _failures: Array[String] = []


func _init() -> void:
	var icons := _collect_icons()
	var category_corner_colors := {}
	_check(icons.size() == 34, "Expected 34 configured icons, got %d" % icons.size())
	var unique_paths := {}
	for entry in icons:
		var icon_path := str(entry.get("path", ""))
		var category := str(entry.get("category", ""))
		_check(not icon_path.is_empty(), "Empty icon path in %s" % category)
		_check(not unique_paths.has(icon_path), "Duplicate icon path: %s" % icon_path)
		unique_paths[icon_path] = true
		_check(FileAccess.file_exists(icon_path), "Missing icon file: %s" % icon_path)
		_check(ResourceLoader.exists(icon_path), "Icon is not importable: %s" % icon_path)
		var image := Image.load_from_file(ProjectSettings.globalize_path(icon_path))
		_check(image != null and not image.is_empty(), "Icon image cannot be read: %s" % icon_path)
		if image == null or image.is_empty():
			continue
		_check(image.get_size() == ICON_SIZE, "Icon is not 512x512: %s" % icon_path)
		var actual := image.get_pixel(0, 0)
		if not category_corner_colors.has(category):
			category_corner_colors[category] = actual
		else:
			var expected: Color = category_corner_colors[category]
			var color_delta := absf(actual.r - expected.r) + absf(actual.g - expected.g) + absf(actual.b - expected.b)
			_check(color_delta < 0.025, "Inconsistent category background: %s" % icon_path)
	var category_names := category_corner_colors.keys()
	for first_index in category_names.size():
		for second_index in range(first_index + 1, category_names.size()):
			var first: Color = category_corner_colors[category_names[first_index]]
			var second: Color = category_corner_colors[category_names[second_index]]
			var separation := absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)
			_check(separation > 0.12, "Category backgrounds are not visually distinct")
	await _verify_runtime_consumers()
	if _failures.is_empty():
		print("T0174_ITEM_ICONS PASS count=%d" % icons.size())
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("T0174_ITEM_ICONS FAIL count=%d" % _failures.size())
		quit(1)


func _collect_icons() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _read_json_array("res://data/weapon_defs.json"):
		result.append({"category": "weapon", "path": str((item as Dictionary).get("icon", ""))})
	for item in _read_json_array("res://data/armor_defs.json"):
		result.append({"category": "armor", "path": str((item as Dictionary).get("icon", ""))})
	var horse_defs := _read_json_dictionary("res://data/horse_defs.json")
	for item in horse_defs.get("horse_templates", []):
		result.append({"category": "horse", "path": str((item as Dictionary).get("icon", ""))})
	var device_defs := _read_json_dictionary("res://data/defense_device_defs.json")
	for item in device_defs.get("devices", []):
		var presentation := (item as Dictionary).get("presentation", {}) as Dictionary
		result.append({"category": "defense_device", "path": str(presentation.get("icon", ""))})
	return result


func _verify_runtime_consumers() -> void:
	var dev_lab := (load("res://scenes/debug/NPCDevLab.tscn") as PackedScene).instantiate()
	root.add_child(dev_lab)
	for _frame in 8:
		await process_frame
	dev_lab.call("_open_equipment_picker", "main_weapon")
	await process_frame
	var picker := dev_lab.find_child("EquipmentPicker", true, false) as Control
	_check(picker != null and picker.visible, "NPCDevLab picker did not open")
	var icon_button_count := 0
	if picker != null:
		for raw_button in picker.find_children("*", "Button", true, false):
			var button := raw_button as Button
			if button.icon != null:
				icon_button_count += 1
	_check(icon_button_count == 4, "NPCDevLab weapon picker did not load four icons")
	dev_lab.queue_free()
	await process_frame
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for _frame in 8:
		await process_frame
	var horse_system := main.get_node_or_null("Systems/HorseSystem")
	if horse_system != null:
		var horses: Array = horse_system.call("get_horses_snapshot")
		_check(not horses.is_empty(), "Main has no horse snapshots")
		for raw_horse in horses:
			_check(not str((raw_horse as Dictionary).get("icon", "")).is_empty(), "Horse snapshot lost template icon")
	else:
		_check(false, "HorseSystem unavailable")
	main.queue_free()
	await process_frame


func _read_json_array(path: String) -> Array:
	var value: Variant = _read_json(path)
	return value if value is Array else []


func _read_json_dictionary(path: String) -> Dictionary:
	var value: Variant = _read_json(path)
	return value if value is Dictionary else {}


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return value


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
