extends Node


func load_json(path: String, default_value: Variant = {}) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Config file not found: %s" % path)
		return default_value

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open config file: %s" % path)
		return default_value

	var text := file.get_as_text()
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("Failed to parse JSON config %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return default_value

	return json.data


func load_data_file(file_name: String, default_value: Variant = {}) -> Variant:
	return load_json("res://data/%s" % file_name, default_value)

