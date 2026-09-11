extends SceneTree


func _init() -> void:
	var wagon_scene := load("res://scenes/world/MerchantWagon.tscn") as PackedScene
	if wagon_scene == null:
		_fail("T0132-P7 MerchantWagon.tscn could not be loaded")
		return
	var wagon := wagon_scene.instantiate()
	root.add_child(wagon)
	for _frame in 5:
		await process_frame

	var snapshot: Dictionary = wagon.get_wagon_snapshot()
	if str(snapshot.get("art_revision", "")) != "t0132_p7r" or str(snapshot.get("visual_identity", "")) != "dual_horse_loaded_covered_trade_cart":
		_fail("Merchant wagon is not using the T0132-P7R covered dual-horse art contract")
		return
	if int(snapshot.get("horse_count", 0)) != 2:
		_fail("Merchant wagon must use exactly two horses")
		return
	if int(snapshot.get("wheel_count", 0)) != 4 or int(snapshot.get("axle_count", 0)) != 2:
		_fail("Merchant wagon must use a coherent four-wheel, two-axle chassis")
		return
	if int(snapshot.get("cargo_item_count", 0)) < 18 or int(snapshot.get("bed_sideboard_count", 0)) < 4:
		_fail("Merchant cart is not visibly full or is missing its rectangular cargo bed")
		return
	if int(snapshot.get("rein_segment_count", 0)) != 4:
		_fail("Paired reins are not connected through both hands to both horses")
		return
	if float(snapshot.get("left_hand_to_rein_distance", 1.0)) > 0.03 or float(snapshot.get("right_hand_to_rein_distance", 1.0)) > 0.03:
		_fail("Merchant hands are not attached to the reins")
		return
	if str(snapshot.get("driver_appearance_id", "")) != "merchant_shopkeeper_chibi_v1" or not bool(snapshot.get("driver_source_ready", false)):
		_fail("Merchant is not the dedicated Synty two-head shopkeeper")
		return
	if str(snapshot.get("driver_state", "")) != "vehicle_seated":
		_fail("Merchant is not seated in the dedicated driving pose")
		return
	if bool(snapshot.get("presentation_inventory_authority", true)) or str(snapshot.get("authority_role", "")) != "physical_presence_and_presentation_only":
		_fail("Merchant visuals must remain presentation-only")
		return
	if int(snapshot.get("canopy_surface_count", 0)) != 2 or int(snapshot.get("canopy_rib_count", 0)) != 5 or int(snapshot.get("canopy_support_post_count", 0)) != 8:
		_fail("Merchant canopy is missing its cargo canvas, driver awning, bows, or support posts")
		return
	if int(snapshot.get("canopy_front_brace_count", 0)) != 2:
		_fail("Driver awning is missing its paired cantilever braces")
		return
	if float(snapshot.get("canopy_half_width", 99.0)) > 1.25 or float(snapshot.get("canopy_peak_y", 0.0)) < 3.2:
		_fail("Merchant canopy width or arch height violates the audited envelope")
		return
	if float(snapshot.get("driver_canopy_extension", 0.0)) < 1.2 or float(snapshot.get("canopy_front_z", 0.0)) >= -2.0:
		_fail("Merchant canopy does not extend far enough over the driver")
		return
	if bool(snapshot.get("canopy_has_collision", true)):
		_fail("Merchant canopy must remain presentation-only")
		return
	var trade_bubble := wagon.get_node("TradeBubble") as Node3D
	if trade_bubble.position.y - float(snapshot.get("canopy_peak_y", 99.0)) < 0.55:
		_fail("Trade marker does not clear the new canopy ridge")
		return

	var left_horse := wagon.get_node_or_null("VisualRoot/Horses/LeftHorse") as Node3D
	var right_horse := wagon.get_node_or_null("VisualRoot/Horses/RightHorse") as Node3D
	if left_horse == null or right_horse == null:
		_fail("Paired horse nodes are missing")
		return
	if not is_equal_approx(left_horse.position.x, -right_horse.position.x) or not is_equal_approx(left_horse.position.z, right_horse.position.z) or not is_equal_approx(left_horse.rotation.y, right_horse.rotation.y):
		_fail("Horses are not symmetrically aligned in one forward direction")
		return
	var wheels := wagon.get_node_or_null("VisualRoot/Wheels")
	if wheels == null or wheels.get_child_count() != 4:
		_fail("Four-wheel hierarchy is missing")
		return
	for wheel in wheels.get_children():
		if wheel.get_child_count() < 10:
			_fail("A cart wheel is missing rim, hub, or spokes")
			return
	var horse_shape := (wagon.get_node("HorseBodyCollision") as CollisionShape3D).shape as BoxShape3D
	var carriage_shape := (wagon.get_node("CarriageBodyCollision") as CollisionShape3D).shape as BoxShape3D
	var navigation_agent := wagon.get_node("NavigationAgent3D") as NavigationAgent3D
	if horse_shape.size.x > 2.7 or carriage_shape.size.x > 2.7 or navigation_agent.radius > 1.5:
		_fail("Double-horse wagon collision envelope no longer fits the five-metre rear gate")
		return

	var source := FileAccess.get_file_as_string("res://scenes/world/MerchantWagon.tscn")
	if source.contains("warehouse_wagon.glb") or source.contains("GlenArtView"):
		_fail("Obsolete full-wagon or Glen driver layering remains in MerchantWagon.tscn")
		return
	print("T0132-P7R formal covered merchant wagon verification passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
