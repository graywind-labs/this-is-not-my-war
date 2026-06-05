extends CanvasLayer


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var focus_owner := get_viewport().gui_get_focus_owner()
	if not focus_owner is Control:
		return

	var focused_control := focus_owner as Control
	if not _is_text_input(focused_control):
		return

	var hovered_control := get_viewport().gui_get_hovered_control()
	if hovered_control != null and _is_same_input_area(hovered_control, focused_control):
		return

	focused_control.release_focus()


func _is_text_input(control: Control) -> bool:
	return control is LineEdit or control is TextEdit


func _is_same_input_area(clicked_control: Control, focused_control: Control) -> bool:
	if clicked_control == focused_control:
		return true

	if _is_ancestor_of(focused_control, clicked_control):
		return true

	var clicked_spin := _find_parent_spin_box(clicked_control)
	if clicked_spin != null and _is_ancestor_of(clicked_spin, focused_control):
		return true

	var focused_spin := _find_parent_spin_box(focused_control)
	if focused_spin != null and _is_ancestor_of(focused_spin, clicked_control):
		return true

	return false


func _find_parent_spin_box(control: Control) -> SpinBox:
	var current: Node = control
	while current != null:
		if current is SpinBox:
			return current as SpinBox
		current = current.get_parent()
	return null


func _is_ancestor_of(ancestor: Node, node: Node) -> bool:
	var current: Node = node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false
