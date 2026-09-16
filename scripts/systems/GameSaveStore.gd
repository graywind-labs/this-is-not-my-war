class_name GameSaveStore
extends RefCounted

const ROOT_PATH := "user://saves"
const ARCHIVES_PATH := ROOT_PATH + "/archives"
const INDEX_PATH := ROOT_PATH + "/index.json"
const INDEX_SCHEMA := "wave_checkpoint_index_v1"
const META_SCHEMA := "wave_checkpoint_meta_v1"
const STATE_SCHEMA := "wave_checkpoint_state_v1"
const SAVE_VERSION := 1
const THUMBNAIL_FILENAME := "thumbnail.webp"
const SLOT_IDS: Array[String] = [
	"quick_0", "slot_01", "slot_02", "slot_03", "slot_04", "slot_05",
	"slot_06", "slot_07", "slot_08", "slot_09", "slot_10",
]
static var _storage_root_override := ""


static func set_storage_root_for_tests(path: String) -> void:
	_storage_root_override = path.trim_suffix("/")


static func clear_storage_root_override() -> void:
	_storage_root_override = ""


static func create_archive_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	return "archive_%s" % bytes.hex_encode()


static func get_point_dir(archive_id: String, restore_point: String) -> String:
	return "%s/archives/%s/%s" % [_storage_root(), _safe_id(archive_id), _normalize_point(restore_point)]


static func write_checkpoint(
	archive_id: String,
	restore_point: String,
	state: Dictionary,
	meta_fields: Dictionary,
	thumbnail_bytes: PackedByteArray = PackedByteArray()
) -> Dictionary:
	if archive_id.is_empty():
		return {"ok": false, "reason": "archive_id_missing"}
	var point := _normalize_point(restore_point)
	var directory := get_point_dir(archive_id, point)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if mkdir_error != OK:
		return {"ok": false, "reason": "save_directory_failed", "error": mkdir_error}
	var state_copy := state.duplicate(true)
	state_copy["schema"] = STATE_SCHEMA
	state_copy["save_version"] = SAVE_VERSION
	state_copy["archive_id"] = archive_id
	var state_text := JSON.stringify(state_copy, "\t")
	var parsed_state: Variant = JSON.parse_string(state_text)
	if not parsed_state is Dictionary:
		return {"ok": false, "reason": "state_not_json_serializable"}
	var state_hash := state_text.sha256_text()
	var meta := meta_fields.duplicate(true)
	meta["schema"] = META_SCHEMA
	meta["save_version"] = SAVE_VERSION
	meta["archive_id"] = archive_id
	meta["restore_point"] = point
	meta["state_sha256"] = state_hash
	meta["saved_unix_time"] = int(Time.get_unix_time_from_system())
	meta["has_thumbnail"] = not thumbnail_bytes.is_empty()
	meta["thumbnail_sha256"] = _sha256_bytes(thumbnail_bytes) if not thumbnail_bytes.is_empty() else ""
	var state_result := _write_text_atomic(directory + "/state.json", state_text)
	if not bool(state_result.get("ok", false)):
		return state_result
	var thumbnail_path := directory + "/" + THUMBNAIL_FILENAME
	var thumbnail_result := {"ok": true, "written": false, "path": thumbnail_path}
	if thumbnail_bytes.is_empty():
		_remove_file_if_present(thumbnail_path)
	else:
		thumbnail_result = _write_bytes_atomic(thumbnail_path, thumbnail_bytes)
		if not bool(thumbnail_result.get("ok", false)):
			meta["has_thumbnail"] = false
			_remove_file_if_present(thumbnail_path)
	var meta_result := _write_text_atomic(directory + "/meta.json", JSON.stringify(meta, "\t"))
	if not bool(meta_result.get("ok", false)):
		return meta_result
	return {
		"ok": true,
		"archive_id": archive_id,
		"restore_point": point,
		"meta": meta,
		"path": directory,
		"thumbnail_written": bool(thumbnail_result.get("written", false)),
		"thumbnail_error": "" if bool(thumbnail_result.get("ok", false)) else str(thumbnail_result.get("reason", "thumbnail_write_failed")),
	}


static func inspect_restore_point(archive_id: String, restore_point: String) -> Dictionary:
	var point := _normalize_point(restore_point)
	var directory := get_point_dir(archive_id, point)
	var meta_result := _read_json(directory + "/meta.json")
	if not bool(meta_result.get("ok", false)):
		return {"ok": false, "occupied": false, "archive_id": archive_id, "restore_point": point, "reason": str(meta_result.get("reason", "meta_missing"))}
	var meta: Dictionary = meta_result["data"]
	var result := meta.duplicate(true)
	var thumbnail_path := directory + "/" + THUMBNAIL_FILENAME
	var thumbnail_declared := bool(meta.get("has_thumbnail", false))
	var thumbnail_exists := FileAccess.file_exists(thumbnail_path)
	var thumbnail_error := ""
	if thumbnail_declared and not thumbnail_exists:
		thumbnail_error = "thumbnail_missing"
	elif thumbnail_declared:
		var thumbnail_bytes := FileAccess.get_file_as_bytes(thumbnail_path)
		var expected_thumbnail_hash := str(meta.get("thumbnail_sha256", ""))
		if expected_thumbnail_hash.is_empty() or _sha256_bytes(thumbnail_bytes) != expected_thumbnail_hash:
			thumbnail_error = "thumbnail_checksum_mismatch"
	result["has_thumbnail"] = thumbnail_declared and thumbnail_exists and thumbnail_error.is_empty()
	result["thumbnail_path"] = thumbnail_path
	result["thumbnail_error"] = thumbnail_error
	result["occupied"] = true
	result["ok"] = false
	result["loadable"] = false
	if str(meta.get("schema", "")) != META_SCHEMA:
		result["reason"] = "meta_schema_mismatch"
		return result
	if str(meta.get("archive_id", "")) != archive_id or str(meta.get("restore_point", "")) != point:
		result["reason"] = "meta_identity_mismatch"
		return result
	var version := int(meta.get("save_version", 0))
	if version > SAVE_VERSION:
		result["reason"] = "save_version_too_new"
		return result
	if version <= 0:
		result["reason"] = "save_version_invalid"
		return result
	var state_result := _read_text(directory + "/state.json")
	if not bool(state_result.get("ok", false)):
		result["reason"] = str(state_result.get("reason", "state_missing"))
		return result
	var state_text := str(state_result.get("text", ""))
	if state_text.sha256_text() != str(meta.get("state_sha256", "")):
		result["reason"] = "state_checksum_mismatch"
		return result
	var parsed: Variant = JSON.parse_string(state_text)
	if not parsed is Dictionary or str((parsed as Dictionary).get("schema", "")) != STATE_SCHEMA:
		result["reason"] = "state_schema_mismatch"
		return result
	var parsed_state: Dictionary = parsed
	var state_version := int(parsed_state.get("save_version", 0))
	if state_version > SAVE_VERSION:
		result["reason"] = "save_version_too_new"
		return result
	if state_version <= 0:
		result["reason"] = "save_version_invalid"
		return result
	if str(parsed_state.get("archive_id", "")) != archive_id:
		result["reason"] = "state_identity_mismatch"
		return result
	result["ok"] = true
	result["loadable"] = true
	result["reason"] = ""
	result["state"] = (parsed as Dictionary).duplicate(true)
	return result


static func list_slot_records() -> Array[Dictionary]:
	var index := read_index()
	var mappings: Dictionary = index.get("slots", {}) if index.get("slots", {}) is Dictionary else {}
	var result: Array[Dictionary] = []
	for slot_id in SLOT_IDS:
		var mapping: Dictionary = mappings.get(slot_id, {}) if mappings.get(slot_id, {}) is Dictionary else {}
		var archive_id := str(mapping.get("archive_id", ""))
		var record := {
			"slot_id": slot_id,
			"quick": slot_id == "quick_0",
			"display_name": str(mapping.get("display_name", "快速检查点" if slot_id == "quick_0" else "存档槽位 %s" % slot_id.trim_prefix("slot_"))),
			"archive_id": archive_id,
			"occupied": not archive_id.is_empty(),
			"auto": {}, "manual": {},
		}
		if not archive_id.is_empty():
			record["auto"] = inspect_restore_point(archive_id, "auto")
			record["manual"] = inspect_restore_point(archive_id, "manual")
		result.append(record)
	return result


static func pin_auto_to_slot(active_archive_id: String, slot_id: String, display_name: String) -> Dictionary:
	if not SLOT_IDS.has(slot_id):
		return {"ok": false, "reason": "unknown_slot"}
	var source := inspect_restore_point(active_archive_id, "auto")
	if not bool(source.get("loadable", false)):
		return {"ok": false, "reason": "automatic_checkpoint_unavailable"}
	var index := read_index()
	var mappings: Dictionary = index.get("slots", {}) if index.get("slots", {}) is Dictionary else {}
	var existing: Dictionary = mappings.get(slot_id, {}) if mappings.get(slot_id, {}) is Dictionary else {}
	var target_archive_id := str(existing.get("archive_id", ""))
	var active_already_mapped_elsewhere := false
	for raw_slot_id in mappings.keys():
		var raw_mapping: Dictionary = mappings[raw_slot_id] if mappings[raw_slot_id] is Dictionary else {}
		if str(raw_slot_id) != slot_id and str(raw_mapping.get("archive_id", "")) == active_archive_id:
			active_already_mapped_elsewhere = true
			break
	if target_archive_id != active_archive_id:
		target_archive_id = create_archive_id() if active_already_mapped_elsewhere or not target_archive_id.is_empty() else active_archive_id
	if target_archive_id != active_archive_id:
		var clone_result := _copy_restore_point(active_archive_id, "auto", target_archive_id, "auto")
		if not bool(clone_result.get("ok", false)):
			return clone_result
	var manual_result := _copy_restore_point(target_archive_id, "auto", target_archive_id, "manual", display_name)
	if not bool(manual_result.get("ok", false)):
		return manual_result
	mappings[slot_id] = {"archive_id": target_archive_id, "display_name": display_name.strip_edges()}
	index["slots"] = mappings
	index["last_active_archive_id"] = target_archive_id
	var index_result := write_index(index)
	if not bool(index_result.get("ok", false)):
		return index_result
	return {"ok": true, "slot_id": slot_id, "archive_id": target_archive_id, "manual": inspect_restore_point(target_archive_id, "manual")}


static func delete_slot(slot_id: String) -> Dictionary:
	var index := read_index()
	var mappings: Dictionary = index.get("slots", {}) if index.get("slots", {}) is Dictionary else {}
	if not mappings.has(slot_id):
		return {"ok": true, "deleted": false, "slot_id": slot_id}
	var removed_mapping: Dictionary = mappings.get(slot_id, {}) if mappings.get(slot_id, {}) is Dictionary else {}
	var removed_archive_id := str(removed_mapping.get("archive_id", ""))
	mappings.erase(slot_id)
	index["slots"] = mappings
	if str(index.get("last_active_archive_id", "")) == removed_archive_id:
		var still_referenced := false
		for mapping_value in mappings.values():
			var mapping: Dictionary = mapping_value if mapping_value is Dictionary else {}
			if str(mapping.get("archive_id", "")) == removed_archive_id:
				still_referenced = true
				break
		if not still_referenced:
			index["last_active_archive_id"] = ""
	var result := write_index(index)
	result["deleted"] = bool(result.get("ok", false))
	result["slot_id"] = slot_id
	return result


static func set_last_active_archive(archive_id: String) -> Dictionary:
	var index := read_index()
	index["last_active_archive_id"] = archive_id
	return write_index(index)


static func get_last_active_archive_id() -> String:
	return str(read_index().get("last_active_archive_id", ""))


static func read_thumbnail_bytes(archive_id: String, restore_point: String) -> PackedByteArray:
	var path := get_point_dir(archive_id, restore_point) + "/" + THUMBNAIL_FILENAME
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)


static func read_index() -> Dictionary:
	var result := _read_json(_storage_root() + "/index.json")
	if not bool(result.get("ok", false)):
		return {"schema": INDEX_SCHEMA, "version": SAVE_VERSION, "slots": {}, "last_active_archive_id": ""}
	var index: Dictionary = result["data"]
	if str(index.get("schema", "")) != INDEX_SCHEMA:
		return {"schema": INDEX_SCHEMA, "version": SAVE_VERSION, "slots": {}, "last_active_archive_id": ""}
	return index


static func write_index(index: Dictionary) -> Dictionary:
	var value := index.duplicate(true)
	value["schema"] = INDEX_SCHEMA
	value["version"] = SAVE_VERSION
	if not value.get("slots", {}) is Dictionary:
		value["slots"] = {}
	return _write_text_atomic(_storage_root() + "/index.json", JSON.stringify(value, "\t"))


static func _copy_restore_point(source_archive_id: String, source_point: String, target_archive_id: String, target_point: String, display_name: String = "") -> Dictionary:
	var source := inspect_restore_point(source_archive_id, source_point)
	if not bool(source.get("loadable", false)):
		return {"ok": false, "reason": "source_checkpoint_invalid"}
	var meta := source.duplicate(true)
	meta.erase("state")
	meta.erase("ok")
	meta.erase("loadable")
	meta.erase("occupied")
	meta.erase("reason")
	if not display_name.strip_edges().is_empty():
		meta["display_name"] = display_name.strip_edges()
	meta["copied_from_archive_id"] = source_archive_id
	meta["copied_from_restore_point"] = _normalize_point(source_point)
	var thumbnail_bytes := read_thumbnail_bytes(source_archive_id, source_point)
	return write_checkpoint(target_archive_id, target_point, source["state"], meta, thumbnail_bytes)


static func _write_text_atomic(path: String, text: String) -> Dictionary:
	var parent := path.get_base_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent))
	if mkdir_error != OK:
		return {"ok": false, "reason": "parent_directory_failed", "error": mkdir_error}
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "temp_open_failed", "error": FileAccess.get_open_error()}
	file.store_string(text)
	file.flush()
	file.close()
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var backup_path := path + ".bak"
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.rename_absolute(absolute_path, absolute_backup)
		if backup_error != OK:
			return {"ok": false, "reason": "replace_backup_failed", "error": backup_error}
	var rename_error := DirAccess.rename_absolute(absolute_temp, absolute_path)
	if rename_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		return {"ok": false, "reason": "replace_rename_failed", "error": rename_error}
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	return {"ok": true, "path": path}


static func _write_bytes_atomic(path: String, bytes: PackedByteArray) -> Dictionary:
	var parent := path.get_base_dir()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent))
	if mkdir_error != OK:
		return {"ok": false, "reason": "thumbnail_parent_directory_failed", "error": mkdir_error}
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "thumbnail_temp_open_failed", "error": FileAccess.get_open_error()}
	file.store_buffer(bytes)
	file.flush()
	file.close()
	var replace_result := _replace_temp_file(path, temp_path, "thumbnail")
	if bool(replace_result.get("ok", false)):
		replace_result["written"] = true
	return replace_result


static func _replace_temp_file(path: String, temp_path: String, reason_prefix: String) -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var backup_path := path + ".bak"
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.rename_absolute(absolute_path, absolute_backup)
		if backup_error != OK:
			return {"ok": false, "reason": "%s_replace_backup_failed" % reason_prefix, "error": backup_error}
	var rename_error := DirAccess.rename_absolute(absolute_temp, absolute_path)
	if rename_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		return {"ok": false, "reason": "%s_replace_rename_failed" % reason_prefix, "error": rename_error}
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	return {"ok": true, "path": path}


static func _remove_file_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode()


static func _read_json(path: String) -> Dictionary:
	var text_result := _read_text(path)
	if not bool(text_result.get("ok", false)):
		return text_result
	var parsed: Variant = JSON.parse_string(str(text_result.get("text", "")))
	if not parsed is Dictionary:
		return {"ok": false, "reason": "json_invalid", "path": path}
	return {"ok": true, "data": (parsed as Dictionary).duplicate(true), "path": path}


static func _read_text(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "file_missing", "path": path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "file_open_failed", "path": path, "error": FileAccess.get_open_error()}
	var text := file.get_as_text()
	file.close()
	return {"ok": true, "text": text, "path": path}


static func _normalize_point(value: String) -> String:
	return "manual" if value == "manual" else "auto"


static func _storage_root() -> String:
	return _storage_root_override if not _storage_root_override.is_empty() else ROOT_PATH


static func _safe_id(value: String) -> String:
	var result := ""
	for character in value:
		if character.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			result += character
	return result
