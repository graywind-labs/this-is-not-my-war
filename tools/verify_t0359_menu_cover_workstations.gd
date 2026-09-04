extends SceneTree


const MAIN_MENU_SCENE := preload("res://scenes/frontend/MainMenu.tscn")
const EXPECTED_BINDINGS := {
	"priest_01": "chapel_altar_with_cross",
	"doctor_01": "clinic_desk_and_seated_study",
	"cook_01": "active_dining_cauldron_with_food_and_steam",
	"gardener_01": "formal_garden_bed",
	"blacksmith_01": "formal_blacksmith_anvil",
	"engineer_01": "formal_mechanism_workbench",
	"stableman_01": "existing_cover_horse",
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var menu := MAIN_MENU_SCENE.instantiate() as Control
	root.add_child(menu)
	for _frame in range(100):
		await process_frame
	var cover := menu.find_child("AnimatedMenuCover", true, false) as Node3D
	if cover == null:
		_fail("Formal MainMenu did not instantiate the animated cover")
		return
	var set_root := cover.get_node("Set") as Node3D
	var snapshot := cover.call("get_preview_snapshot") as Dictionary
	var bindings := snapshot.get("workstation_bindings", {}) as Dictionary
	if int(snapshot.get("workstation_count", 0)) != 7 or bindings.size() != EXPECTED_BINDINGS.size():
		_fail("Cover workstation count changed: %s" % snapshot)
		return
	if str(snapshot.get("workstation_source", "")) != "existing_formal_fixture_assets":
		_fail("Cover no longer declares the formal fixture asset source: %s" % snapshot)
		return
	for npc_id in EXPECTED_BINDINGS:
		var binding := bindings.get(npc_id, {}) as Dictionary
		if str(binding.get("kind", "")) != str(EXPECTED_BINDINGS[npc_id]):
			_fail("Missing or incorrect workstation binding for %s: %s" % [npc_id, binding])
			return

	var altar := cover.find_child("MarcelChapelAltar", true, false) as Node3D
	var clinic_desk := cover.find_child("LinaClinicDesk", true, false) as Node3D
	var clinic_chair := cover.find_child("LinaClinicChair", true, false) as Node3D
	var cauldron := cover.find_child("BrunoActiveCauldron", true, false) as Node3D
	var garden_bed := cover.find_child("IvoGardenBed", true, false) as Node3D
	var anvil := cover.find_child("GlenAnvil", true, false) as Node3D
	var workbench := cover.find_child("OwenEngineeringWorkbench", true, false) as Node3D
	if altar == null or clinic_desk == null or clinic_chair == null or cauldron == null or garden_bed == null or anvil == null or workbench == null:
		_fail("One or more profession workstation nodes are missing")
		return
	if altar.find_child("CrossStem", true, false) == null or altar.find_child("CrossArm", true, false) == null:
		_fail("Marcel altar is missing its formal cross")
		return
	if clinic_desk.find_child("MedicalCloth", true, false) == null or clinic_desk.find_child("MedicineBottle", true, false) == null:
		_fail("Lina clinic desk is missing its formal medical dressing")
		return
	if garden_bed.find_child("CultivatedSoil", true, false) == null or garden_bed.find_child("Crop01", true, false) == null:
		_fail("Ivo garden bed is missing soil or crops")
		return
	if anvil.find_child("AnvilStump", true, false) == null or not (anvil.find_child("HotMetal", true, false) as MeshInstance3D).visible:
		_fail("Glen anvil is missing its support or active workpiece")
		return
	if workbench.find_child("PartsTray", true, false) == null or workbench.find_child("MechanismGear01", true, false) == null:
		_fail("Owen workbench is missing mechanism work props")
		return

	var pot_steam := cauldron.find_child("PotSteam", true, false) as GPUParticles3D
	var food_visuals := cauldron.find_child("FoodVisuals", true, false) as Node3D
	if pot_steam == null or not pot_steam.emitting or food_visuals == null or not food_visuals.visible or food_visuals.find_child("StewSurface", true, false) == null:
		_fail("Bruno cauldron is not active with food and steam")
		return

	var characters := set_root.get_node("Characters") as Node3D
	var lina := characters.get_node("doctor_01") as Node3D
	var lina_snapshot := lina.call("debug_get_snapshot") as Dictionary
	if str(lina_snapshot.get("desired_state", "")) != "seated_study" or str(lina_snapshot.get("spatial_attachment_pose", "")) != "seated_study" or not bool(lina_snapshot.get("medical_book_visible", false)):
		_fail("Lina is not using the formal seated study pose and book: %s" % lina_snapshot)
		return
	if absf(lina.position.y - 0.5) > 0.02:
		_fail("Lina no longer uses the formal clinic occupant height: %s" % lina.position)
		return

	for npc_id in EXPECTED_BINDINGS:
		var character := characters.get_node(npc_id) as Node3D
		var character_snapshot := character.call("debug_get_snapshot") as Dictionary
		var target_local: Vector3 = (bindings[npc_id] as Dictionary).get("target", Vector3.ZERO)
		var desired := set_root.to_global(target_local) - character.global_position
		desired.y = 0.0
		var facing: Vector3 = character_snapshot.get("target_facing_direction", Vector3.ZERO)
		facing.y = 0.0
		if desired.length_squared() <= 0.0001 or facing.length_squared() <= 0.0001 or desired.normalized().dot(facing.normalized()) < 0.98:
			_fail("%s is not facing its action target: desired=%s facing=%s" % [npc_id, desired, facing])
			return

	var ada := characters.get_node("veteran_deputy_01") as Node3D
	var war_table := set_root.get_node("StoryProps/WarTable") as Node3D
	if Vector2(ada.position.x, ada.position.z).distance_to(Vector2(7.0, 6.0)) > 0.001 or absf(ada.position.y) > 0.02 or absf(ada.rotation_degrees.y - 168.0) > 0.01:
		_fail("Ada staging changed unexpectedly: pos=%s yaw=%s" % [ada.position, ada.rotation_degrees.y])
		return
	if not war_table.position.is_equal_approx(Vector3(8.2, 0.0, 4.0)):
		_fail("War table staging changed unexpectedly: %s" % war_table.position)
		return
	if set_root.get_node_or_null("StableHorse") == null:
		_fail("Toma action target horse is missing")
		return

	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("stop_music"):
		audio_manager.call("stop_music", 0.0)
	menu.queue_free()
	for _frame in range(20):
		await process_frame
	print("T0359_MENU_COVER_WORKSTATIONS_PASS bindings=7 ada=unchanged food_steam=active lina=seated")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
