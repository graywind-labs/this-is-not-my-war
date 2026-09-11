extends SceneTree


const FAR_TARGET := Vector3(250.0, 73.0, -180.0)


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	for _index in range(6):
		await process_frame

	var piety_system := root.get_node_or_null("Main/Systems/PietySystem")
	var hud := root.get_node_or_null("Main/UI/HUD")
	if piety_system == null or hud == null:
		_fail("T0163 runtime dependencies are missing")
		return

	var targeting: Dictionary = piety_system.get_targeting_snapshot()
	if str(targeting.get("scope", "")) != "unbounded_ground_plane_except_buildings" or targeting.has("bounds"):
		_fail("Meteor targeting still exposes a bounded station contract: %s" % JSON.stringify(targeting))
		return
	if not bool(piety_system.is_target_position_allowed(FAR_TARGET)):
		_fail("A finite target outside the former station rectangle must be allowed")
		return

	piety_system.debug_fill_piety()
	var cast: Dictionary = piety_system.request_meteor_cast(FAR_TARGET)
	if not bool(cast.get("ok", false)):
		_fail("Far-away meteor cast was rejected: %s" % JSON.stringify(cast))
		return
	var target: Dictionary = cast.get("target_position", {})
	if (
		not is_equal_approx(float(target.get("x", 0.0)), FAR_TARGET.x)
		or not is_equal_approx(float(target.get("z", 0.0)), FAR_TARGET.z)
		or not is_equal_approx(float(target.get("y", -1.0)), float(targeting.get("ground_y", 0.0)))
		or not is_zero_approx(float(piety_system.get_current_piety()))
	):
		_fail("Far target was not preserved and normalized correctly: %s" % JSON.stringify(cast))
		return

	piety_system.debug_fill_piety()
	var invalid: Dictionary = piety_system.request_meteor_cast(Vector3(NAN, 0.0, 0.0))
	if str(invalid.get("error", "")) != "invalid_target" or not is_equal_approx(float(piety_system.get_current_piety()), float(piety_system.get_max_piety())):
		_fail("Malformed target must still be rejected without spending piety: %s" % JSON.stringify(invalid))
		return

	hud._set_meteor_target_valid(false)
	var hint := hud.find_child("MeteorTargetHint", true, false) as Label
	if hint == null or "驿站地表内" in hint.text:
		_fail("HUD still instructs the player to target inside the station")
		return

	print("T0163 unbounded meteor ground targeting verification passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
