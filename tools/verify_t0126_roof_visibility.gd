extends SceneTree


func _init() -> void:
	var sandbox_scene := load("res://scenes/art/ArtSandbox.tscn") as PackedScene
	if sandbox_scene == null:
		_fail("ArtSandbox.tscn failed to load")
		return

	var sandbox := sandbox_scene.instantiate()
	root.add_child(sandbox)
	await process_frame
	await process_frame
	await process_frame

	var controller := sandbox.get_node_or_null("RoofVisibilityController")
	var smithy := sandbox.get_node_or_null("BuildingViews/SmithyView")
	var clinic := sandbox.get_node_or_null("BuildingViews/ClinicView")
	if controller == null or smithy == null or clinic == null:
		_fail("Roof controller and both reusable building views must exist")
		return

	for required_path in [
		"Exterior", "Roof", "Interior", "Interior/WorkstationMarkers",
		"UpgradeVisuals", "EntryMarker", "ExitMarker", "InteriorTrigger",
		"StaticCollision", "ClickArea", "DamageFXMounts"
	]:
		if smithy.get_node_or_null(required_path) == null:
			_fail("BuildingArtView contract node missing: %s" % required_path)
			return

	var near_snapshot: Dictionary = controller.debug_apply_distance(18.0)
	if not _validate_common_snapshot(near_snapshot):
		return
	var near_views: Array = near_snapshot.get("views", [])
	if not is_equal_approx(float(near_views[0].get("roof_opacity", -1.0)), 0.06):
		_fail("Smithy roof did not reach configured near opacity")
		return
	if not is_equal_approx(float(near_views[1].get("roof_opacity", -1.0)), 0.12):
		_fail("Clinic roof did not reach configured near opacity")
		return
	if not bool(near_views[0].get("roof_shadow_enabled", false)) or int(near_views[0].get("roof_shadow_proxy_count", 0)) <= 0:
		_fail("Transparent roof must preserve its opaque silhouette through a shadows-only proxy")
		return
	if bool(near_views[0].get("visible_shell_meshes_cast_shadow", true)):
		_fail("Transparent visible meshes must not duplicate the persistent shadow proxy")
		return

	var mid_snapshot: Dictionary = controller.debug_apply_distance(25.0)
	var mid_views: Array = mid_snapshot.get("views", [])
	var smithy_mid := float(mid_views[0].get("roof_opacity", -1.0))
	var clinic_mid := float(mid_views[1].get("roof_opacity", -1.0))
	if not (smithy_mid > 0.06 and smithy_mid < 1.0 and clinic_mid > 0.12 and clinic_mid < 1.0):
		_fail("Mid zoom should smoothly interpolate both roofs")
		return
	if is_equal_approx(smithy_mid, clinic_mid):
		_fail("Per-building thresholds should produce distinct opacity at the same distance")
		return

	var far_snapshot: Dictionary = controller.debug_apply_distance(40.0)
	for view in far_snapshot.get("views", []):
		if not is_equal_approx(float(view.get("roof_opacity", -1.0)), 1.0):
			_fail("Far zoom should restore an opaque roof")
			return
		if not bool(view.get("roof_shadow_enabled", false)):
			_fail("Opaque roof should restore its shadow")
			return

	var reversed_snapshot: Dictionary = controller.debug_apply_distance(18.0)
	var reversed_views: Array = reversed_snapshot.get("views", [])
	if not is_equal_approx(float(reversed_views[0].get("roof_opacity", -1.0)), 0.06):
		_fail("Roof fade must be reversible")
		return
	if not _validate_common_snapshot(reversed_snapshot):
		return

	print("T0126 roof visibility verification passed.")
	quit(0)


func _validate_common_snapshot(snapshot: Dictionary) -> bool:
	var views: Array = snapshot.get("views", [])
	if views.size() != 2:
		_fail("Expected two registered building views")
		return false
	for view in views:
		if int(view.get("roof_mesh_count", 0)) <= 0:
			_fail("Roof view has no render mesh")
			return false
		for key in [
			"exterior_visible", "interior_visible", "static_collision_enabled",
			"click_area_enabled", "interior_trigger_enabled"
		]:
			if not bool(view.get(key, false)):
				_fail("Roof transparency changed or lost required contract state: %s" % key)
				return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
