extends SceneTree


const EXPECTED_NAMES := [
	"工械坊", "小教堂", "小诊所", "马厩", "宿舍", "主厅", "食堂",
	"菜园", "酒窖", "训练场", "铁匠铺", "仓库", "正门", "后门",
]


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	for _index in range(8):
		await process_frame
		await physics_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var rig := root.get_node_or_null("Main/CameraRig") as Node3D
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if controller == null or rig == null or camera == null:
		_fail("T0164 runtime dependencies are missing")
		return
	controller.set_process(false)

	var snapshot: Dictionary = controller.debug_get_building_name_label_snapshot()
	var labels: Array = snapshot.get("labels", [])
	if int(snapshot.get("label_count", 0)) != EXPECTED_NAMES.size():
		_fail("Expected 12 building labels and 2 gate labels: %s" % JSON.stringify(snapshot))
		return
	var seen := {}
	for raw_label in labels:
		var label: Dictionary = raw_label
		var text := str(label.get("text", ""))
		if not EXPECTED_NAMES.has(text) or text.contains("·") or int(label.get("font_size", 0)) != 38 or not bool(label.get("is_building_name", false)):
			_fail("Building name label contract mismatch: %s" % JSON.stringify(label))
			return
		seen[text] = true
	if seen.size() != EXPECTED_NAMES.size():
		_fail("Building/gate names are missing or duplicated: %s" % JSON.stringify(seen))
		return

	# Hold the camera still beyond the delay and fade duration.
	controller._process(0.01)
	for _index in range(25):
		controller._process(0.1)
	snapshot = controller.debug_get_building_name_label_snapshot()
	if float(snapshot.get("alpha", 1.0)) > 0.0001 or not _all_label_alphas(snapshot, 0.0):
		_fail("Building names did not fade fully while the camera was idle: %s" % JSON.stringify(snapshot))
		return

	# Any rig movement starts the fast reveal and the idle grace period keeps it going.
	rig.global_position.x += 0.5
	controller._process(0.01)
	for _index in range(10):
		controller._process(0.02)
	snapshot = controller.debug_get_building_name_label_snapshot()
	if float(snapshot.get("alpha", 0.0)) < 0.999 or not _all_label_alphas(snapshot, 1.0):
		_fail("Building names did not reveal quickly after camera movement: %s" % JSON.stringify(snapshot))
		return

	# Zoom changes Camera3D local position and must use the same reveal path.
	for _index in range(25):
		controller._process(0.1)
	camera.position *= 0.96
	controller._process(0.01)
	for _index in range(10):
		controller._process(0.02)
	snapshot = controller.debug_get_building_name_label_snapshot()
	if float(snapshot.get("alpha", 0.0)) < 0.999:
		_fail("Building names did not reveal after camera zoom")
		return

	print("T0164 building name cleanup and camera-motion fade verification passed.")
	quit(0)


func _all_label_alphas(snapshot: Dictionary, expected: float) -> bool:
	for raw_label in snapshot.get("labels", []):
		var label: Dictionary = raw_label
		if (
			not is_equal_approx(float(label.get("text_alpha", -1.0)), expected)
			or not is_equal_approx(float(label.get("outline_alpha", -1.0)), expected)
		):
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
