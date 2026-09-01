extends Control

const EVENT_BUS_PATH := "/root/EventBus"
const HORSE_SYSTEM_PATH := "/root/Main/Systems/HorseSystem"

@onready var building_completion_dialog: AcceptDialog = %BuildingCompletionDialog
@onready var horse_birth_naming_dialog: AcceptDialog = %HorseBirthNamingDialog
@onready var horse_birth_prompt_label: Label = %HorseBirthPromptLabel
@onready var horse_name_input: LineEdit = %HorseNameInput
@onready var horse_name_validation_label: Label = %HorseNameValidationLabel

var _alert_queue: Array[Dictionary] = []
var _current_alert: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	building_completion_dialog.confirmed.connect(_on_building_completion_closed)
	building_completion_dialog.close_requested.connect(_on_building_completion_closed)
	horse_birth_naming_dialog.confirmed.connect(_on_horse_birth_name_confirmed)
	horse_birth_naming_dialog.close_requested.connect(_on_horse_birth_close_requested)
	horse_name_input.text_changed.connect(_on_horse_name_text_changed)
	horse_birth_naming_dialog.register_text_enter(horse_name_input)
	var event_bus := get_node_or_null(EVENT_BUS_PATH)
	if event_bus == null:
		return
	if event_bus.has_signal("building_job_completed"):
		event_bus.building_job_completed.connect(_on_building_job_completed)
	if event_bus.has_signal("horse_birth_naming_requested"):
		event_bus.horse_birth_naming_requested.connect(_on_horse_birth_naming_requested)


func _on_building_job_completed(building_id: String, job_type: String, result: Dictionary) -> void:
	if not ["repair", "upgrade"].has(job_type):
		return
	_alert_queue.append({
		"kind": "building",
		"building_id": building_id,
		"job_type": job_type,
		"result": result.duplicate(true),
	})
	_show_next_alert()


func _on_horse_birth_naming_requested(request: Dictionary) -> void:
	if not bool(request.get("ok", false)) or str(request.get("request_id", "")).is_empty():
		return
	_alert_queue.append({
		"kind": "horse_birth",
		"request": request.duplicate(true),
	})
	_show_next_alert()


func _show_next_alert() -> void:
	if not _current_alert.is_empty() or _alert_queue.is_empty():
		return
	_current_alert = _alert_queue.pop_front()
	match str(_current_alert.get("kind", "")):
		"building":
			var result: Dictionary = _current_alert.get("result", {})
			var building_name := str(result.get("building_name", _current_alert.get("building_id", "建筑")))
			var completion_text := "修复完成" if str(_current_alert.get("job_type", "")) == "repair" else "升级完成"
			building_completion_dialog.dialog_text = "%s%s。" % [building_name, completion_text]
			building_completion_dialog.popup_centered()
		"horse_birth":
			var request: Dictionary = _current_alert.get("request", {})
			horse_name_validation_label.text = ""
			horse_name_input.text = str(request.get("default_name", "小马"))
			horse_birth_naming_dialog.popup_centered()
			horse_name_input.call_deferred("grab_focus")
			horse_name_input.call_deferred("select_all")
		_:
			_current_alert.clear()
			call_deferred("_show_next_alert")


func _on_building_completion_closed() -> void:
	if str(_current_alert.get("kind", "")) != "building":
		return
	_current_alert.clear()
	call_deferred("_show_next_alert")


func _on_horse_birth_name_confirmed() -> void:
	if str(_current_alert.get("kind", "")) != "horse_birth":
		return
	var request: Dictionary = _current_alert.get("request", {})
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or not horse_system.has_method("confirm_pending_foal_name"):
		horse_name_validation_label.text = "马匹系统不可用，暂时无法完成命名。"
		return
	var result: Dictionary = horse_system.call(
		"confirm_pending_foal_name",
		str(request.get("request_id", "")),
		horse_name_input.text
	)
	if not bool(result.get("ok", false)):
		horse_name_validation_label.text = str(result.get("message", "命名失败，请重新输入。"))
		return
	horse_birth_naming_dialog.hide()
	_current_alert.clear()
	call_deferred("_show_next_alert")


func _on_horse_birth_close_requested() -> void:
	if str(_current_alert.get("kind", "")) != "horse_birth":
		return
	horse_name_validation_label.text = "请先为小马命名。"
	call_deferred("_reopen_horse_birth_dialog")


func _reopen_horse_birth_dialog() -> void:
	if str(_current_alert.get("kind", "")) != "horse_birth":
		return
	if not horse_birth_naming_dialog.visible:
		horse_birth_naming_dialog.popup_centered()
		horse_name_input.grab_focus()


func _on_horse_name_text_changed(_text: String) -> void:
	horse_name_validation_label.text = ""


func debug_get_snapshot() -> Dictionary:
	return {
		"current_kind": str(_current_alert.get("kind", "")),
		"queued_count": _alert_queue.size(),
		"building_dialog_visible": building_completion_dialog.visible,
		"building_dialog_text": building_completion_dialog.dialog_text,
		"building_button_text": building_completion_dialog.get_ok_button().text,
		"horse_dialog_visible": horse_birth_naming_dialog.visible,
		"horse_dialog_text": horse_birth_prompt_label.text,
		"horse_name": horse_name_input.text,
		"horse_name_max_length": horse_name_input.max_length,
		"horse_validation_text": horse_name_validation_label.text,
	}
