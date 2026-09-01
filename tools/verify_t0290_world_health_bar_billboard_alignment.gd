extends SceneTree

const WORLD_HEALTH_BAR := preload("res://scripts/world/WorldHealthBar3D.gd")


func _init() -> void:
	var rotated_parent := Node3D.new()
	rotated_parent.rotation.y = deg_to_rad(-135.0)
	root.add_child(rotated_parent)

	var bar := WORLD_HEALTH_BAR.new() as WorldHealthBar3D
	rotated_parent.add_child(bar)
	bar.configure_size(2.4, 0.18)
	await process_frame

	for sample in [[150, 150], [75, 150], [30, 150], [0, 150]]:
		var hp := int(sample[0])
		var max_hp := int(sample[1])
		bar.set_health(hp, max_hp, true)
		var snapshot: Dictionary = bar.get_debug_snapshot()
		var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
		var expected_width := 2.4 * ratio
		var expected_offset := -2.4 * (1.0 - ratio) * 0.5
		if not is_equal_approx(float(snapshot.get("ratio", -1.0)), ratio):
			_fail("World bar ratio mismatch: %s" % snapshot)
			return
		if not is_equal_approx(float(snapshot.get("fill_width", -1.0)), expected_width):
			_fail("World bar fill width mismatch: %s" % snapshot)
			return
		if not (snapshot.get("fill_position", Vector3.INF) as Vector3).is_equal_approx(Vector3.ZERO):
			_fail("Fill billboard origin moved away from Track: %s" % snapshot)
			return
		if not (snapshot.get("track_position", Vector3.INF) as Vector3).is_equal_approx(Vector3.ZERO):
			_fail("Track billboard origin is not stable: %s" % snapshot)
			return
		var center_offset: Vector3 = snapshot.get("fill_center_offset", Vector3.INF)
		if not is_equal_approx(center_offset.x, expected_offset) or not is_zero_approx(center_offset.y) or not is_zero_approx(center_offset.z):
			_fail("Fill mesh center offset mismatch: %s" % snapshot)
			return
		if hp == 0 and bool(snapshot.get("fill_visible", true)):
			_fail("Zero-HP fill remained visible: %s" % snapshot)
			return

	var track := bar.get_node_or_null("Track") as MeshInstance3D
	var fill := bar.get_node_or_null("Fill") as MeshInstance3D
	if track == null or fill == null or not track.global_position.is_equal_approx(fill.global_position):
		_fail("Rotated parent produced different Track / Fill world origins.")
		return

	print("T0290 world health bar billboard alignment verification passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
