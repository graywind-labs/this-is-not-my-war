extends SceneTree

const SPECIFIC_ITEM_IDS := [
	"item_sword_shield",
	"item_polearm",
	"item_bow",
	"item_crossbow",
	"item_iron_helmet",
	"item_mail_chest",
	"item_iron_bracers",
	"item_iron_greaves",
	"item_wall_ballista",
	"item_wall_arrow_tower"
]
const LEGACY_AGGREGATE_IDS := ["weapons", "armor", "defense_devices", "horse_readiness"]


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var gm_button := root.get_node_or_null("Main/UI/GMPanel/GMButton") as Button
	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as PanelContainer
	var llm_usage_summary_label := gm_window.find_child("LLMUsageSummaryLabel", true, false) as Label
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var daily_reflection_system := root.get_node_or_null("Main/Systems/DailyReflectionSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var horse_birth_dialog := root.get_node_or_null("Main/UI/MilestoneAlertPresenter/HorseBirthNamingDialog") as AcceptDialog
	var piety_ready_dialog := root.get_node_or_null("Main/UI/MilestoneAlertPresenter/PietyReadyDialog") as AcceptDialog
	var piety_system := root.get_node_or_null("Main/Systems/PietySystem")
	var roof_visibility_controller := root.get_node_or_null("Main/Presentation/RoofVisibilityController")
	var station_layout_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var spatial_save_system := root.get_node_or_null("Main/Systems/SpatialSaveSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var game_state := root.get_node_or_null("GameState")
	if (
		gm_panel == null
		or gm_button == null
		or gm_window == null
		or llm_usage_summary_label == null
		or resource_system == null
		or building_system == null
		or npc_system == null
		or action_system == null
		or memory_system == null
		or llm_bridge == null
		or equipment_system == null
		or daily_plan_system == null
		or daily_reflection_system == null
		or combat_system == null
		or crafting_system == null
		or horse_system == null
		or horse_birth_dialog == null
		or piety_system == null
		or roof_visibility_controller == null
		or station_layout_controller == null
		or spatial_save_system == null
		or time_system == null
		or game_state == null
	):
		push_error("GM verification required nodes not found")
		quit(1)
		return

	# Keep this broad UI/command regression offline and deterministic. The dedicated
	# real-provider suites own real LLM acceptance; an unsupported scheme makes any
	# accidental request fail synchronously into the explicit rule/template path.
	if llm_bridge.has_method("set_backend_base_url"):
		llm_bridge.set_backend_base_url("gm-verify-invalid://backend")
	llm_bridge.request_timeout_seconds = 0.2

	if not gm_panel.visible:
		push_error("GMPanel should be visible while GM_ENABLED is true")
		quit(1)
		return
	if gm_button.text != "GM":
		push_error("GM button was not created")
		quit(1)
		return
	for epilogue_control_name in [
		"TriggerEpilogueVictoryButton",
		"TriggerEpilogueFailureButton",
		"RefreshEpilogueStatusButton",
		"EpilogueStatusLabel"
	]:
		if gm_window.find_child(epilogue_control_name, true, false) == null:
			push_error("GM epilogue acceptance section is missing %s" % epilogue_control_name)
			quit(1)
			return
	for required_dialogue_button in [
		"MoraleEncouragementMockButton",
		"OpenMoraleEncouragementDialogueButton",
		"CombatStrategyDialogueMockButton",
		"OpenCombatStrategyDialogueButton",
		"WorkEncouragementDialogueMockButton",
		"OpenWorkEncouragementDialogueButton",
		"RecruitmentAcceptPreviewButton",
		"RecruitmentRejectPreviewButton",
		"RecruitmentNonePreviewButton",
		"MoraleBoostPreviewButton",
		"MoraleNonePreviewButton",
		"MoraleEscapePreviewButton",
		"WorkBoostPreviewButton",
		"WorkNonePreviewButton",
		"WorkEscapePreviewButton",
		"StrategyChangePreviewButton",
		"StrategyKeepPreviewButton",
		"ClearDialogueBuffsButton",
		"StartEscapePreviewButton",
		"EscapeStayPreviewButton",
		"EscapeLeavePreviewButton"
	]:
		if gm_window.find_child(required_dialogue_button, true, false) == null:
			push_error("GM AI dialogue section is missing %s" % required_dialogue_button)
			quit(1)
			return
	var roof_snapshot_button := gm_window.find_child("RoofVisibilitySnapshotButton", true, false) as Button
	if roof_snapshot_button == null:
		push_error("GM building section should expose the roof visibility snapshot")
		quit(1)
		return
	for preview_level in [1, 2, 3]:
		var workshop_preview_button := gm_window.find_child("WorkshopArtLevel%dButton" % preview_level, true, false) as Button
		if workshop_preview_button == null:
			push_error("GM building section should expose workshop art level %d" % preview_level)
			quit(1)
			return
	for preview_level in [1, 2]:
		var chapel_preview_button := gm_window.find_child("ChapelArtLevel%dButton" % preview_level, true, false) as Button
		if chapel_preview_button == null:
			push_error("GM building section should expose chapel art level %d" % preview_level)
			quit(1)
			return
	for preview_level in [1, 2, 3]:
		var clinic_preview_button := gm_window.find_child("ClinicArtLevel%dButton" % preview_level, true, false) as Button
		if clinic_preview_button == null:
			push_error("GM building section should expose clinic art level %d" % preview_level)
			quit(1)
			return
	for preview_level in [1, 2, 3]:
		var dining_hall_preview_button := gm_window.find_child("DiningHallArtLevel%dButton" % preview_level, true, false) as Button
		if dining_hall_preview_button == null:
			push_error("GM building section should expose dining hall art level %d" % preview_level)
			quit(1)
			return
	for preview_level in [1, 2]:
		var dormitory_preview_button := gm_window.find_child("DormitoryArtLevel%dButton" % preview_level, true, false) as Button
		if dormitory_preview_button == null:
			push_error("GM building section should expose dormitory art level %d" % preview_level)
			quit(1)
			return
	for preview_level in [1, 2, 3]:
		var tavern_preview_button := gm_window.find_child("TavernArtLevel%dButton" % preview_level, true, false) as Button
		if tavern_preview_button == null:
			push_error("GM building section should expose tavern art level %d" % preview_level)
			quit(1)
			return
	for preview_level in [1, 2, 3]:
		var garden_preview_button := gm_window.find_child("GardenArtLevel%dButton" % preview_level, true, false) as Button
		if garden_preview_button == null:
			push_error("GM building section should expose garden art level %d" % preview_level)
			quit(1)
			return
	for preview_level in [1, 2, 3]:
		var training_ground_preview_button := gm_window.find_child("TrainingGroundArtLevel%dButton" % preview_level, true, false) as Button
		if training_ground_preview_button == null:
			push_error("GM building section should expose training-ground art level %d" % preview_level)
			quit(1)
			return
	for preview_level in [1, 2, 3]:
		var stable_preview_button := gm_window.find_child("StableArtLevel%dButton" % preview_level, true, false) as Button
		if stable_preview_button == null:
			push_error("GM building section should expose stable art level %d" % preview_level)
			quit(1)
			return
	for preview_level in [1, 2, 3, 4, 5, 6]:
		var main_hall_preview_button := gm_window.find_child("MainHallArtLevel%dButton" % preview_level, true, false) as Button
		if main_hall_preview_button == null:
			push_error("GM building section should expose main-hall art level %d" % preview_level)
			quit(1)
			return
	var layout_preview_button := gm_window.find_child("StationLayoutPreviewButton", true, false) as Button
	if layout_preview_button == null:
		push_error("GM building section should expose the staged formal layout preview")
		quit(1)
		return
	var formal_spatial_save_button := gm_window.find_child("FormalSpatialSaveButton", true, false) as Button
	var formal_spatial_load_button := gm_window.find_child("FormalSpatialLoadButton", true, false) as Button
	if formal_spatial_save_button == null or formal_spatial_load_button == null:
		push_error("GM building section should expose A5-P8 spatial save/load")
		quit(1)
		return
	var motion_sandbox_button := gm_window.find_child("ActorMotionSandboxButton", true, false) as Button
	if motion_sandbox_button == null:
		push_error("GM building section should expose the independent actor motion sandbox")
		quit(1)
		return
	var npc_dev_lab_button := gm_window.find_child("NPCDevLabButton", true, false) as Button
	if npc_dev_lab_button == null:
		push_error("GM building section should replace the fixed character sandbox with NPCDevLab")
		quit(1)
		return
	for removed_button_name in [
		"GlenNavigationPilotButton", "ClinicDoctorNavigationPilotButton",
		"ClinicBedNavigationPilotButton", "DormitoryNavigationPilotButton",
		"DiningNavigationPilotButton", "ChapelNavigationPilotButton",
		"StableNavigationPilotButton"
	]:
		if gm_window.find_child(removed_button_name, true, false) != null:
			push_error("GM panel should remove superseded navigation pilot button %s" % removed_button_name)
			quit(1)
			return
	var formal_stable_work_button := gm_window.find_child("FormalStableWorkButton", true, false) as Button
	if formal_stable_work_button == null:
		push_error("GM building section should expose Toma's actual formal stable-work cycle")
		quit(1)
		return
	var formal_dining_work_button := gm_window.find_child("FormalDiningWorkButton", true, false) as Button
	if formal_dining_work_button == null:
		push_error("GM building section should expose Bruno's actual formal dining-hall work cycle")
		quit(1)
		return
	var formal_clinic_doctor_button := gm_window.find_child("FormalClinicDoctorButton", true, false) as Button
	var formal_clinic_patient_button := gm_window.find_child("FormalClinicPatientButton", true, false) as Button
	if formal_clinic_doctor_button == null or formal_clinic_patient_button == null:
		push_error("GM building section should expose Lina's formal clinic duty and Bruno's patient-bed route")
		quit(1)
		return
	var formal_training_instructor_button := gm_window.find_child("FormalTrainingInstructorButton", true, false) as Button
	var formal_training_student_button := gm_window.find_child("FormalTrainingStudentButton", true, false) as Button
	if formal_training_instructor_button == null or formal_training_student_button == null:
		push_error("GM building section should expose Ada's formal instructor route and Glen's trainee route")
		quit(1)
		return
	var formal_chapel_prayer_button := gm_window.find_child("FormalChapelPrayerButton", true, false) as Button
	var formal_chapel_leader_button := gm_window.find_child("FormalChapelLeaderButton", true, false) as Button
	if formal_chapel_prayer_button == null or formal_chapel_leader_button == null:
		push_error("GM building section should expose Ivo's formal prayer route and Marcel's altar route")
		quit(1)
		return
	var formal_blacksmith_work_button := gm_window.find_child("FormalBlacksmithWorkButton", true, false) as Button
	if formal_blacksmith_work_button == null:
		push_error("GM manufacturing section should expose Glen's actual formal blacksmith-work cycle")
		quit(1)
		return
	var formal_workshop_work_button := gm_window.find_child("FormalWorkshopWorkButton", true, false) as Button
	if formal_workshop_work_button == null:
		push_error("GM manufacturing section should expose Owen's actual formal workshop-work cycle")
		quit(1)
		return
	var formal_enemy_attack_button := gm_window.find_child("FormalSecondWaveButton", true, false) as Button
	if formal_enemy_attack_button == null:
		push_error("GM combat section should expose the C3-P6 formal second-wave slice")
		quit(1)
		return
	gm_panel._execute_command("roof_visibility")
	var roof_snapshot: Dictionary = roof_visibility_controller.debug_get_snapshot()
	if not bool(roof_snapshot.get("camera_available", false)):
		push_error("Main roof visibility snapshot should resolve CameraRig/Camera3D")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("smithy_art_level <1|2|3>"):
		push_error("GM help should expose the smithy art preview command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("workshop_art_level <1|2|3>"):
		push_error("GM help should expose the workshop art preview command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("chapel_art_level <1|2>"):
		push_error("GM help should expose the chapel art preview command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("clinic_art_level <1|2|3>"):
		push_error("GM help should expose the clinic art preview command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("dining_hall_art_level <1|2|3>"):
		push_error("GM help should expose the dining hall art preview command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("dormitory_art_level <1|2>"):
		push_error("GM help should expose the dormitory art preview command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("tavern_art_level <1|2|3>"):
		push_error("GM help should expose the tavern art preview command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("garden_art_level <1|2|3>"):
		push_error("GM help should expose the garden art preview command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("training_ground_art_level <1|2|3>"):
		push_error("GM help should expose the training-ground art preview command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("stable_art_level <1|2|3>"):
		push_error("GM help should expose the stable art preview command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("main_hall_art_level <1|2|3|4|5|6>"):
		push_error("GM help should expose the main-hall art preview command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("station_layout [preview|legacy|snapshot]"):
		push_error("GM help should expose the staged station layout preview command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("motion_sandbox"):
		push_error("GM help should expose the independent actor motion sandbox command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("formal_nav_pilot [glen|clinic_doctor|clinic_bed|dormitory_bed|dining_seat|chapel_prayer_seat|stable_care|stop|snapshot]"):
		push_error("GM help should expose the combined formal-navigation pilot command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("formal_stable_work [run|stop|snapshot]"):
		push_error("GM help should expose the actual formal stable-work command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("formal_dining_work [run|stop|snapshot]"):
		push_error("GM help should expose the actual formal dining-hall work command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("formal_clinic_work [doctor|patient|stop|snapshot]"):
		push_error("GM help should expose the actual formal clinic service command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("formal_training_work [instructor|student|stop|snapshot]"):
		push_error("GM help should expose the actual formal training command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("formal_chapel_work [leader|prayer|stop|snapshot]"):
		push_error("GM help should expose the actual formal chapel command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("formal_workshop_work [run|stop|snapshot]"):
		push_error("GM help should expose the actual formal workshop-work command")
		quit(1)
		return
	if not str(gm_panel._help_text()).contains("formal_second_wave_slice [run|stop|snapshot]"):
		push_error("GM help should expose the formal second-wave slice command")
		quit(1)
		return
	gm_panel._execute_command("station_layout preview")
	var layout_preview_snapshot: Dictionary = station_layout_controller.debug_get_layout_snapshot()
	if not bool(layout_preview_snapshot.get("preview_enabled", false)):
		push_error("GM station_layout preview should activate the formal static layout camera")
		quit(1)
		return
	gm_panel._execute_command("station_layout legacy")
	var layout_restore_snapshot: Dictionary = station_layout_controller.debug_get_layout_snapshot()
	if bool(layout_restore_snapshot.get("preview_enabled", true)):
		push_error("GM station_layout legacy should restore the stable gameplay camera")
		quit(1)
		return
	gm_panel._execute_command("smithy_art_level 3")
	var smithy_art_view := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/Blacksmith/BlacksmithArt"
	)
	if (
		smithy_art_view == null
		or not bool((smithy_art_view.get_art_slice_snapshot() as Dictionary).get("level_3_visible", false))
		or int(building_system.get_building("blacksmith").get("level", 0)) != 1
	):
		push_error("GM smithy art preview should expose level 3 visuals without changing authority")
		quit(1)
		return
	gm_panel._execute_command("smithy_art_level 1")
	gm_panel._execute_command("chapel_art_level 2")
	var chapel_art_view := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/Chapel/ChapelArt"
	)
	var chapel_art_snapshot: Dictionary = (
		chapel_art_view.get_art_slice_snapshot() as Dictionary
		if chapel_art_view != null
		else {}
	)
	if (
		chapel_art_view == null
		or not bool(chapel_art_snapshot.get("level_2_visible", false))
		or bool(chapel_art_snapshot.get("level_3_exists", true))
		or int(building_system.get_building("chapel").get("level", 0)) != 1
	):
		push_error("GM chapel art preview should expose level 2 visuals without changing authority")
		quit(1)
		return
	gm_panel._execute_command("chapel_art_level 1")
	gm_panel._execute_command("clinic_art_level 3")
	var clinic_art_view := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/Clinic/ClinicArt"
	)
	var clinic_art_snapshot: Dictionary = (
		clinic_art_view.get_art_slice_snapshot() as Dictionary
		if clinic_art_view != null
		else {}
	)
	if (
		clinic_art_view == null
		or not bool(clinic_art_snapshot.get("level_2_visible", false))
		or not bool(clinic_art_snapshot.get("level_3_visible", false))
		or int(clinic_art_snapshot.get("available_treatment_bed_count", 0)) != 4
		or int(building_system.get_building("clinic").get("level", 0)) != 1
	):
		push_error("GM clinic art preview should expose level 3 visuals and four beds without changing authority")
		quit(1)
		return
	gm_panel._execute_command("clinic_art_level 1")
	gm_panel._execute_command("dining_hall_art_level 3")
	var dining_hall_art_view := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/DiningHall/DiningHallArt"
	)
	var dining_hall_art_snapshot: Dictionary = (
		dining_hall_art_view.get_art_slice_snapshot() as Dictionary
		if dining_hall_art_view != null
		else {}
	)
	if (
		dining_hall_art_view == null
		or not bool(dining_hall_art_snapshot.get("level_2_visible", false))
		or not bool(dining_hall_art_snapshot.get("level_3_visible", false))
		or int(dining_hall_art_snapshot.get("available_kitchen_station_count", 0)) != 3
		or int(dining_hall_art_snapshot.get("available_dining_seat_count", 0)) != 10
		or int(building_system.get_building("dining_hall").get("level", 0)) != 1
	):
		push_error("GM dining hall art preview should expose level 3 visuals, three kitchens and ten fixed seats without changing authority")
		quit(1)
		return
	gm_panel._execute_command("dining_hall_art_level 1")
	gm_panel._execute_command("dormitory_art_level 2")
	var dormitory_art_view := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/Dormitory/DormitoryArt"
	)
	var dormitory_art_snapshot: Dictionary = (
		dormitory_art_view.get_art_slice_snapshot() as Dictionary
		if dormitory_art_view != null
		else {}
	)
	if (
		dormitory_art_view == null
		or not bool(dormitory_art_snapshot.get("level_2_visible", false))
		or int(dormitory_art_snapshot.get("available_bed_count", 0)) != 10
		or int(dormitory_art_snapshot.get("assigned_bed_count", 0)) != 8
		or int(building_system.get_building("dormitory").get("level", 0)) != 1
	):
		push_error("GM dormitory art preview should expose level 2 while preserving ten fixed beds and Lv.1 authority")
		quit(1)
		return
	gm_panel._execute_command("dormitory_art_level 1")
	gm_panel._execute_command("tavern_art_level 3")
	var tavern_art_view := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/Tavern/TavernArt"
	)
	var tavern_art_snapshot: Dictionary = (
		tavern_art_view.get_art_slice_snapshot() as Dictionary
		if tavern_art_view != null
		else {}
	)
	if (
		tavern_art_view == null
		or not bool(tavern_art_snapshot.get("level_2_visible", false))
		or not bool(tavern_art_snapshot.get("level_3_visible", false))
		or int(tavern_art_snapshot.get("available_brew_station_count", 0)) != 3
		or int(tavern_art_snapshot.get("active_fixture_visual_count", 0)) != 6
		or int(building_system.get_building("tavern").get("level", 0)) != 1
	):
		push_error("GM tavern art preview should expose level 3 visuals and three brewing positions without changing authority")
		quit(1)
		return
	gm_panel._execute_command("tavern_art_level 1")
	gm_panel._execute_command("garden_art_level 3")
	var garden_art_view := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/Garden/GardenArt"
	)
	var garden_art_snapshot: Dictionary = (
		garden_art_view.get_art_slice_snapshot() as Dictionary
		if garden_art_view != null
		else {}
	)
	if (
		garden_art_view == null
		or not bool(garden_art_snapshot.get("level_2_visible", false))
		or not bool(garden_art_snapshot.get("level_3_visible", false))
		or int(garden_art_snapshot.get("available_farm_station_count", 0)) != 3
		or int(garden_art_snapshot.get("active_fixture_visual_count", 0)) != 9
		or int(building_system.get_building("garden").get("level", 0)) != 1
	):
		push_error("GM garden art preview should expose level 3 visuals and three farm plots without changing authority")
		quit(1)
		return
	gm_panel._execute_command("garden_art_level 1")
	gm_panel._execute_command("training_ground_art_level 3")
	var training_ground_art_view := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/TrainingGround/TrainingGroundArt"
	)
	var training_ground_art_snapshot: Dictionary = (
		training_ground_art_view.get_art_slice_snapshot() as Dictionary
		if training_ground_art_view != null
		else {}
	)
	if (
		training_ground_art_view == null
		or not bool(training_ground_art_snapshot.get("level_2_visible", false))
		or not bool(training_ground_art_snapshot.get("level_3_visible", false))
		or int(training_ground_art_snapshot.get("available_instructor_station_count", 0)) != 2
		or int(training_ground_art_snapshot.get("available_student_station_count", 0)) != 4
		or int(training_ground_art_snapshot.get("active_fixture_visual_count", 0)) != 10
		or int(building_system.get_building("training_ground").get("level", 0)) != 1
	):
		push_error("GM training-ground art preview should expose level 3 visuals and 2+4 positions without changing authority")
		quit(1)
		return
	gm_panel._execute_command("training_ground_art_level 1")
	gm_panel._execute_command("stable_art_level 3")
	var stable_art_view := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/Stable/StableArt"
	)
	var stable_art_snapshot: Dictionary = (
		stable_art_view.get_art_slice_snapshot() as Dictionary
		if stable_art_view != null
		else {}
	)
	if (
		stable_art_view == null
		or not bool(stable_art_snapshot.get("level_2_visible", false))
		or not bool(stable_art_snapshot.get("level_3_visible", false))
		or int(stable_art_snapshot.get("available_care_station_count", 0)) != 3
		or int(stable_art_snapshot.get("active_fixture_visual_count", 0)) != 9
		or int(stable_art_snapshot.get("visible_real_horse_count", 0)) != 2
		or int(building_system.get_building("stable").get("level", 0)) != 1
	):
		push_error("GM stable art preview should expose level 3 dressing and real horses without changing authority")
		quit(1)
		return
	gm_panel._execute_command("stable_art_level 1")
	gm_panel._execute_command("main_hall_art_level 6")
	var main_hall_art_view := root.get_node_or_null(
		"Main/WorldRoot/FormalStationLayout/BuildingRoots/MainHall/MainHallArt"
	)
	var main_hall_art_snapshot: Dictionary = (
		main_hall_art_view.get_art_slice_snapshot() as Dictionary
		if main_hall_art_view != null
		else {}
	)
	if (
		main_hall_art_view == null
		or int(main_hall_art_snapshot.get("building_level", 0)) != 6
		or int(main_hall_art_snapshot.get("active_fixture_visual_count", 0)) != 7
		or int(main_hall_art_snapshot.get("active_fixture_collision_count", 0)) != 7
		or int(building_system.get_building("main_hall").get("level", 0)) != 1
	):
		push_error("GM main-hall art preview should expose level 6 dressing and seven fixtures without changing authority")
		quit(1)
		return
	gm_panel._execute_command("main_hall_art_level 1")
	if gm_window.visible:
		push_error("GM window should be hidden before the GM button is pressed")
		quit(1)
		return

	gm_button.pressed.emit()
	if not gm_window.visible:
		push_error("GM button did not open the GM window")
		quit(1)
		return
	gm_panel._on_llm_usage_response_received({
		"ok": true,
		"body": {
			"summary": {
				"provider_usage": {
					"session": {
						"input_tokens": 1234,
						"output_tokens": 56,
						"total_tokens": 1290,
						"estimated_cost_cny": 0.1234
					},
					"daily": {
						"estimated_cost_cny": 3.21
					},
					"daily_limit_cny": 20.0
				}
			}
		}
	})
	if (
		"1,290 tokens" not in llm_usage_summary_label.text
		or "今日：¥3.2100 / ¥20.00" not in llm_usage_summary_label.text
	):
		push_error("GM top usage summary did not render session tokens and daily CNY budget")
		quit(1)
		return
	if not _panel_inside_viewport(gm_window, gm_panel._get_usable_viewport_size()):
		push_error("GM window should stay inside the viewport after opening. panel=%s viewport=%s" % [
			str(gm_window.get_global_rect()),
			str(gm_panel._get_usable_viewport_size())
		])
		quit(1)
		return
	if not _panel_tracks_button(gm_window, gm_button):
		push_error("GM window should open near the GM button")
		quit(1)
		return
	var viewport_size: Vector2 = gm_panel._get_usable_viewport_size()
	gm_button.position = Vector2(
		maxf(0.0, viewport_size.x - gm_button.size.x - 4.0),
		maxf(0.0, viewport_size.y - gm_button.size.y - 4.0)
	)
	gm_panel._position_panel_near_button()
	await process_frame
	if not _panel_inside_viewport(gm_window, viewport_size):
		push_error("GM window should remain inside the viewport when the GM button is near the edge")
		quit(1)
		return
	var repair_building_select := gm_window.find_child("RepairBuildingSelect", true, false) as OptionButton
	var assist_repair_button := gm_window.find_child("AssistRepairButton", true, false) as Button
	var formal_repair_stop_button := gm_window.find_child("FormalRepairAssistStopButton", true, false) as Button
	var formal_repair_snapshot_button := gm_window.find_child("FormalRepairAssistSnapshotButton", true, false) as Button
	if repair_building_select == null or assist_repair_button == null or formal_repair_stop_button == null or formal_repair_snapshot_button == null:
		push_error("GM formal repair controls should include run, stop, snapshot, and target selection")
		quit(1)
		return
	var upgrade_building_select := gm_window.find_child("UpgradeBuildingSelect", true, false) as OptionButton
	var assist_upgrade_button := gm_window.find_child("AssistUpgradeButton", true, false) as Button
	var formal_upgrade_stop_button := gm_window.find_child("FormalUpgradeAssistStopButton", true, false) as Button
	var formal_upgrade_snapshot_button := gm_window.find_child("FormalUpgradeAssistSnapshotButton", true, false) as Button
	if upgrade_building_select == null or assist_upgrade_button == null or formal_upgrade_stop_button == null or formal_upgrade_snapshot_button == null:
		push_error("GM formal upgrade controls should include run, stop, snapshot, and target selection")
		quit(1)
		return
	var heal_target_select := gm_window.find_child("HealTargetSelect", true, false) as OptionButton
	var assist_heal_button := gm_window.find_child("AssistHealButton", true, false) as Button
	var formal_heal_stop_button := gm_window.find_child("FormalHealAssistStopButton", true, false) as Button
	var formal_heal_snapshot_button := gm_window.find_child("FormalHealAssistSnapshotButton", true, false) as Button
	if heal_target_select == null or assist_heal_button == null or formal_heal_stop_button == null or formal_heal_snapshot_button == null:
		push_error("GM formal healing controls should include run, stop, snapshot, and target selection")
		quit(1)
		return
	var action_select := gm_window.find_child("ActionSelect", true, false) as OptionButton
	var common_npc_select := gm_window.find_child("CommonNpcSelect", true, false) as OptionButton
	var formal_action_npc_select := gm_window.find_child("FormalActionNpcSelect", true, false) as OptionButton
	var ai_npc_select := gm_window.find_child("AINpcSelect", true, false) as OptionButton
	var formal_action_location_select := gm_window.find_child("FormalActionLocationSelect", true, false) as OptionButton
	var assign_action_button := gm_window.find_child("AssignActionButton", true, false) as Button
	var formal_visit_button := gm_window.find_child("FormalVisitLocationButton", true, false) as Button
	var formal_visit_stop_button := gm_window.find_child("FormalVisitLocationStopButton", true, false) as Button
	var formal_dialogue_target_select := gm_window.find_child("FormalNpcDialogueTargetSelect", true, false) as OptionButton
	var formal_dialogue_button := gm_window.find_child("FormalNpcDialogueButton", true, false) as Button
	var formal_dialogue_stop_button := gm_window.find_child("FormalNpcDialogueStopButton", true, false) as Button
	if common_npc_select == null or formal_action_npc_select == null or ai_npc_select == null:
		push_error("GM common, formal-action, and AI-info tabs should expose three independent NPC selectors")
		quit(1)
		return
	if formal_action_location_select == null or action_select == null or assign_action_button == null:
		push_error("GM formal action controls should expose NPC, location, action selectors, and assign button")
		quit(1)
		return
	if (
		formal_visit_button == null
		or formal_visit_stop_button == null
		or formal_dialogue_target_select == null
		or formal_dialogue_button == null
		or formal_dialogue_stop_button == null
	):
		push_error("GM formal visit/dialogue controls should expose visible targets and run/stop buttons")
		quit(1)
		return
	for npc_id in npc_system.get_npc_ids():
		if not _select_option_by_id(formal_action_npc_select, str(npc_id)):
			push_error("GM formal action NPC selector should include %s" % str(npc_id))
			quit(1)
			return
		if not _select_option_by_id(ai_npc_select, str(npc_id)):
			push_error("GM AI-info NPC selector should include %s" % str(npc_id))
			quit(1)
			return
	if not _select_option_by_id(common_npc_select, "cook_01"):
		push_error("GM common NPC selector should include cook_01")
		quit(1)
		return
	if not _select_option_by_id(formal_action_npc_select, "gardener_01"):
		push_error("GM formal action NPC selector should include gardener_01")
		quit(1)
		return
	if not _select_option_by_id(ai_npc_select, "doctor_01"):
		push_error("GM AI-info NPC selector should include doctor_01")
		quit(1)
		return
	if (
		str(common_npc_select.get_item_metadata(common_npc_select.selected)) != "cook_01"
		or str(formal_action_npc_select.get_item_metadata(formal_action_npc_select.selected)) != "gardener_01"
		or str(ai_npc_select.get_item_metadata(ai_npc_select.selected)) != "doctor_01"
	):
		push_error("GM tab-specific NPC selectors should preserve independent selections")
		quit(1)
		return
	var happy_preview_button := gm_window.find_child("DialogueEmotionHappyPreviewButton", true, false) as Button
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	if happy_preview_button == null or npc_panel == null:
		push_error("GM AI-info routing verification requires the happy preview and NPC panel")
		quit(1)
		return
	happy_preview_button.pressed.emit()
	await process_frame
	if str(npc_panel._current_npc_id) != "doctor_01":
		push_error("GM AI-info emotion preview should target the AI-info selector, not another tab")
		quit(1)
		return
	if (
		str(common_npc_select.get_item_metadata(common_npc_select.selected)) != "cook_01"
		or str(formal_action_npc_select.get_item_metadata(formal_action_npc_select.selected)) != "gardener_01"
	):
		push_error("Running an AI-info command should not mutate other tabs' NPC selections")
		quit(1)
		return
	if _select_option_by_id(action_select, "attend_mass"):
		push_error("GM action selector should not expose removed attend_mass")
		quit(1)
		return
	if not _select_option_by_id(action_select, "pray_at_chapel"):
		push_error("GM action selector should expose merged pray_at_chapel")
		quit(1)
		return
	for invalid_direct_action_id in [
		"talk_to_npc", "visit_location", "assist_repair", "assist_upgrade", "assist_heal",
		"seek_guard_officer", "escaping_station", "escape_intervention_dialogue", "talk_to_guard_officer"
	]:
		if _select_option_by_id(action_select, invalid_direct_action_id):
			push_error("GM direct action selector should hide target/system action: %s" % invalid_direct_action_id)
			quit(1)
			return
	if not _select_option_by_id(formal_action_location_select, "chapel"):
		push_error("GM formal action location selector should include chapel")
		quit(1)
		return
	npc_system.update_npc_state("gardener_01", {"wine": 1})
	if not action_system.debug_assign_action("gardener_01", "drink_wine"):
		push_error("Failed to prepare an active daily action for GM replacement")
		quit(1)
		return
	if str(action_system.get_runtime_action_snapshot("gardener_01").get("phase", "")) != "active":
		push_error("GM replacement fixture should begin with an active daily action")
		quit(1)
		return
	if not _select_option_by_id(action_select, "lead_mass"):
		push_error("GM direct action selector should expose ability-gated lead_mass")
		quit(1)
		return
	assign_action_button.pressed.emit()
	if action_system.get_runtime_action_id("gardener_01") != "drink_wine":
		push_error("An ineligible GM action should preserve the selected NPC's prior valid action")
		quit(1)
		return
	if not _select_option_by_id(action_select, "pray_at_chapel"):
		push_error("GM action selector should still expose pray_at_chapel after the ability-gate check")
		quit(1)
		return
	assign_action_button.pressed.emit()
	if action_system.get_runtime_action_id("gardener_01") != "pray_at_chapel":
		push_error("GM formal action buttons should command the NPC selected on the formal-action tab")
		quit(1)
		return
	if action_system.get_runtime_action_id("cook_01") == "pray_at_chapel":
		push_error("GM formal action buttons should not read the hidden common-tab NPC selection")
		quit(1)
		return
	action_system.interrupt_npc_action("gardener_01", "gm_formal_action_selector_verified", true)
	time_system.set_paused(false)
	npc_system.update_npc_state("gardener_01", {"wine": 1})
	if not action_system.debug_assign_action("gardener_01", "drink_wine"):
		push_error("Failed to prepare active action before GM formal visit replacement")
		quit(1)
		return
	formal_visit_button.pressed.emit()
	await process_frame
	if action_system.get_runtime_action_id("gardener_01") != "visit_location":
		push_error("GM formal visit should replace the selected NPC's active daily action")
		quit(1)
		return
	formal_visit_stop_button.pressed.emit()
	await process_frame
	npc_system.update_npc_state("gardener_01", {"wine": 1})
	if not action_system.debug_assign_action("gardener_01", "drink_wine"):
		push_error("Failed to prepare active action before GM formal dialogue replacement")
		quit(1)
		return
	if not _select_option_by_id(formal_dialogue_target_select, "stableman_01"):
		push_error("GM formal dialogue target selector should include stableman_01")
		quit(1)
		return
	formal_dialogue_button.pressed.emit()
	await process_frame
	if action_system.get_runtime_action_id("gardener_01") != "talk_to_npc":
		push_error("GM formal NPC dialogue should replace the speaker's active daily action")
		quit(1)
		return
	formal_dialogue_stop_button.pressed.emit()
	await process_frame
	var dialogue_stopped_state: Dictionary = npc_system.get_npc_state("gardener_01")
	if (
		str(dialogue_stopped_state.get("current_location", "")).begins_with("dialogue_target_")
		or str(dialogue_stopped_state.get("current_action", "")).contains("dialogue_target_")
	):
		push_error("Stopping a GM formal dialogue should not retain its synthetic movement target")
		quit(1)
		return
	for redundant_text in ["工作", "当教官", "当受训者", "吃饭", "睡觉"]:
		if _has_button_text(gm_window, redundant_text):
			push_error("GM action section should not keep redundant '%s' button" % redundant_text)
			quit(1)
			return
	if not _select_option_by_id(repair_building_select, "wall"):
		push_error("GM repair target selector should include wall")
		quit(1)
		return
	if not _select_option_by_id(upgrade_building_select, "main_hall"):
		push_error("GM upgrade target selector should include main_hall")
		quit(1)
		return
	var equipment_weapon_select := gm_window.find_child("EquipmentWeaponSelect", true, false) as OptionButton
	var equipment_armor_slot_select := gm_window.find_child("EquipmentArmorSlotSelect", true, false) as OptionButton
	if equipment_weapon_select == null or equipment_armor_slot_select == null:
		push_error("GM equipment controls should include weapon and armor slot selectors")
		quit(1)
		return
	var resource_select := gm_window.find_child("ResourceSelect", true, false) as OptionButton
	var crafting_building_select := gm_window.find_child("CraftingBuildingSelect", true, false) as OptionButton
	var crafting_recipe_select := gm_window.find_child("CraftingRecipeSelect", true, false) as OptionButton
	var horse_select := gm_window.find_child("HorseSelect", true, false) as OptionButton
	if resource_select == null or crafting_building_select == null or crafting_recipe_select == null or horse_select == null:
		push_error("GM crafting/horse controls should expose resource, building, recipe and horse selectors")
		quit(1)
		return
	for item_id in SPECIFIC_ITEM_IDS:
		if not _select_option_by_id(resource_select, item_id):
			push_error("GM resource selector should include concrete item inventory: %s" % item_id)
			quit(1)
			return
	for aggregate_id in LEGACY_AGGREGATE_IDS:
		if _select_option_by_id(resource_select, aggregate_id):
			push_error("GM resource selector should hide deprecated aggregate inventory: %s" % aggregate_id)
			quit(1)
			return
	if not _select_option_by_id(crafting_building_select, "blacksmith"):
		push_error("GM crafting building selector should include blacksmith")
		quit(1)
		return
	gm_panel._fill_crafting_recipe_select()
	if not _select_option_by_id(crafting_recipe_select, "craft_iron_helmet"):
		push_error("GM crafting recipe selector should include blacksmith recipes")
		quit(1)
		return
	if not _select_option_by_id(horse_select, "horse_chestnut_wind"):
		push_error("GM horse selector should include the configured initial horses")
		quit(1)
		return
	if _has_button_text(gm_window, "装备坐骑"):
		push_error("GM panel should replace the deprecated generic mount button with horse assignment")
		quit(1)
		return
	var recruit_button := gm_window.find_child("RecruitNpcButton", true, false) as Button
	if recruit_button == null:
		push_error("GM NPC section should include a recruit button")
		quit(1)
		return
	var recruit_and_equip_all_button := gm_window.find_child("RecruitAndEquipAllButton", true, false) as Button
	if recruit_and_equip_all_button == null or recruit_and_equip_all_button.text != "一键征召&配装":
		push_error("GM quick actions should include the one-click recruit/equip preset button")
		quit(1)
		return
	if recruit_and_equip_all_button.get_parent().name != "GMQuickActions":
		push_error("One-click recruit/equip must stay in the fixed quick-actions row")
		quit(1)
		return
	var quick_ancestor: Node = recruit_and_equip_all_button.get_parent()
	while quick_ancestor != null and quick_ancestor != gm_window:
		if quick_ancestor is ScrollContainer:
			push_error("One-click recruit/equip should be visible without scrolling")
			quit(1)
			return
		quick_ancestor = quick_ancestor.get_parent()
	var section_tabs := gm_window.find_child("GMSectionTabs", true, false) as TabContainer
	if section_tabs == null or section_tabs.get_tab_count() != 5:
		push_error("GM panel should expose five focused section tabs")
		quit(1)
		return
	for expected_tab in ["常用", "世界建筑", "制造马匹", "正式行动", "AI信息"]:
		if section_tabs.find_child(expected_tab, false, false) == null:
			push_error("GM panel is missing tab %s" % expected_tab)
			quit(1)
			return
	var generate_plan_button := gm_window.find_child("GeneratePlanButton", true, false) as Button
	var execute_plan_button := gm_window.find_child("ExecutePlanButton", true, false) as Button
	var show_plan_button := gm_window.find_child("ShowPlanButton", true, false) as Button
	var revise_plan_button := gm_window.find_child("RevisePlanButton", true, false) as Button
	if generate_plan_button == null or execute_plan_button == null or show_plan_button == null or revise_plan_button == null:
		push_error("GM NPC section should include daily plan and reevaluation buttons")
		quit(1)
		return
	var reflect_npc_button := gm_window.find_child("ReflectNpcButton", true, false) as Button
	var long_memory_button := gm_window.find_child("LongMemoryButton", true, false) as Button
	var last_reflection_button := gm_window.find_child("LastReflectionButton", true, false) as Button
	if reflect_npc_button == null or long_memory_button == null or last_reflection_button == null:
		push_error("GM NPC section should include daily reflection buttons")
		quit(1)
		return
	if not _select_option_by_id(equipment_weapon_select, "bow"):
		push_error("GM weapon selector should include bow")
		quit(1)
		return
	if not _select_option_by_id(equipment_armor_slot_select, "chest"):
		push_error("GM armor selector should include chest")
		quit(1)
		return
	var combat_wave_select := gm_window.find_child("CombatWaveSelect", true, false) as OptionButton
	var spawn_selected_wave_button := gm_window.find_child("SpawnSelectedWaveButton", true, false) as Button
	var trigger_next_wave_button := gm_window.find_child("TriggerNextWaveButton", true, false) as Button
	var step_enemy_ai_button := gm_window.find_child("StepEnemyAIButton", true, false) as Button
	if gm_window.find_child("SpawnFirstWaveButton", true, false) != null:
		push_error("GM panel should remove the duplicate first-wave-only button")
		quit(1)
		return
	if combat_wave_select == null or spawn_selected_wave_button == null or trigger_next_wave_button == null or step_enemy_ai_button == null:
		push_error("GM combat section should include wave selector, generic spawn, next-wave and enemy AI step buttons")
		quit(1)
		return
	if not _select_option_by_id(combat_wave_select, "1"):
		push_error("GM combat wave selector should include wave 1")
		quit(1)
		return
	combat_system.debug_clear_enemies()
	spawn_selected_wave_button.pressed.emit()
	await process_frame
	var gm_spawn_result: Dictionary = combat_system.get_last_spawn_result()
	if (
		not bool(gm_spawn_result.get("ok", false))
		or str(gm_spawn_result.get("spawn_stage_id", "")) != "gm_front_gate_enemy_spawn_zone"
		or not bool(gm_spawn_result.get("spawn_near_front_gate", false))
		or not bool(gm_spawn_result.get("spawn_in_gm_staging_zone", false))
	):
		push_error("GM enemy spawn should use the dedicated front-gate staging zone: %s" % JSON.stringify(gm_spawn_result))
		quit(1)
		return
	var enemy_route: Dictionary = station_layout_controller.get_enemy_route_world()
	var front_gate_position := Vector3.ZERO
	for raw_stage in enemy_route.get("stages", []):
		var route_stage := raw_stage as Dictionary
		if str(route_stage.get("id", "")) == "front_gate":
			front_gate_position = route_stage.get("position", Vector3.ZERO)
			break
	for enemy_id in combat_system.get_active_enemy_ids():
		var enemy: Dictionary = combat_system.get_enemy(str(enemy_id))
		var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
		var gate_distance := enemy_position.distance_to(front_gate_position)
		if gate_distance < 25.0 or gate_distance > 50.0:
			push_error("GM enemy should spawn in the yellow-box staging band: %s at %s (gate distance %.2f)" % [enemy_id, enemy_position, gate_distance])
			quit(1)
			return
	combat_system.debug_clear_enemies()
	var fourth_wave_result: Dictionary = combat_system.debug_spawn_wave(4, true, true)
	if (
		not bool(fourth_wave_result.get("ok", false))
		or int(fourth_wave_result.get("spawned_count", 0)) != 36
		or str(fourth_wave_result.get("spawn_stage_id", "")) != "gm_front_gate_enemy_spawn_zone"
	):
		push_error("GM fourth wave should spawn all 36 enemies in the dedicated staging zone: %s" % JSON.stringify(fourth_wave_result))
		quit(1)
		return
	for enemy_id in combat_system.get_active_enemy_ids():
		var enemy: Dictionary = combat_system.get_enemy(str(enemy_id))
		var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
		var gate_distance := enemy_position.distance_to(front_gate_position)
		if gate_distance < 25.0 or gate_distance > 50.0:
			push_error("GM fourth-wave enemy left the staging band: %s at %s (gate distance %.2f)" % [enemy_id, enemy_position, gate_distance])
			quit(1)
			return
	combat_system.debug_clear_enemies()
	var normal_spawn_result: Dictionary = combat_system.spawn_wave(1, true, "verify_normal_spawn_unchanged")
	if (
		not bool(normal_spawn_result.get("ok", false))
		or str(normal_spawn_result.get("spawn_stage_id", "")) != "spawn"
		or bool(normal_spawn_result.get("spawn_near_front_gate", true))
	):
		push_error("Normal wave spawn should remain at the distant route start: %s" % JSON.stringify(normal_spawn_result))
		quit(1)
		return
	combat_system.debug_clear_enemies()
	var fill_piety_button := gm_window.find_child("FillPietyButton", true, false) as Button
	var piety_snapshot_button := gm_window.find_child("PietySnapshotButton", true, false) as Button
	if fill_piety_button == null or piety_snapshot_button == null:
		push_error("GM combat section should expose piety fill and meteor snapshot controls")
		quit(1)
		return
	fill_piety_button.pressed.emit()
	await process_frame
	if not bool(piety_system.is_ready_to_cast()):
		push_error("GM fill-piety button did not charge the meteor ability")
		quit(1)
		return
	if piety_ready_dialog == null or not piety_ready_dialog.visible:
		push_error("GM fill-piety button did not open the formal ready alert")
		quit(1)
		return
	piety_ready_dialog.get_ok_button().pressed.emit()
	await process_frame
	gm_panel._execute_command("piety_set 25")
	if not is_equal_approx(float(piety_system.get_current_piety()), 25.0):
		push_error("GM piety_set command failed")
		quit(1)
		return
	gm_panel._execute_command("piety_snapshot")
	if not str(gm_panel._help_text()).contains("piety_fill"):
		push_error("GM help should expose piety and meteor verification commands")
		quit(1)
		return

	var money_before := int(resource_system.get_resource("money"))
	gm_panel._execute_command("add_resource money 3")
	if int(resource_system.get_resource("money")) != money_before + 3:
		push_error("GM add_resource command failed")
		quit(1)
		return

	var helmet_stock_before := int(resource_system.get_resource("item_iron_helmet"))
	resource_system.add_resource("iron", 2)
	gm_panel._execute_command("craft_target blacksmith craft_iron_helmet")
	var blacksmith_project: Dictionary = crafting_system.get_project_snapshot("blacksmith")
	if str(blacksmith_project.get("target_recipe_id", "")) != "craft_iron_helmet":
		push_error("GM craft_target command should set the blacksmith project")
		quit(1)
		return
	gm_panel._execute_command("craft_stage blacksmith gm_verify")
	blacksmith_project = crafting_system.get_project_snapshot("blacksmith")
	if int(blacksmith_project.get("completed_stages", 0)) != 1:
		push_error("GM craft_stage command should complete exactly one stage")
		quit(1)
		return
	gm_panel._execute_command("craft_snapshot blacksmith")
	var helmet_recipe: Dictionary = crafting_system.get_recipe("craft_iron_helmet")
	var helmet_stage_count := (helmet_recipe.get("stages", []) as Array).size()
	for _stage_index in range(1, helmet_stage_count):
		gm_panel._execute_command("craft_stage blacksmith gm_verify")
	if int(resource_system.get_resource("item_iron_helmet")) != helmet_stock_before or int(crafting_system.get_pending_outputs("blacksmith").get("item_iron_helmet", 0)) != 1:
		push_error("GM craft_stage should place the concrete finished item in building pending outputs")
		quit(1)
		return
	var helmet_collection: Dictionary = crafting_system.collect_pending_outputs("blacksmith")
	if not bool(helmet_collection.get("ok", false)) or int(resource_system.get_resource("item_iron_helmet")) != helmet_stock_before + 1:
		push_error("Collecting the GM-crafted helmet should transfer it into concrete inventory")
		quit(1)
		return
	blacksmith_project = crafting_system.get_project_snapshot("blacksmith")
	if int(blacksmith_project.get("completed_stages", -1)) != 0:
		push_error("Completed crafting product should retain the target and reset integer stages")
		quit(1)
		return

	var wall_before := int(building_system.get_building("wall").get("hp", 0))
	gm_panel._execute_command("damage_building wall 5")
	if int(building_system.get_building("wall").get("hp", 0)) != maxi(0, wall_before - 5):
		push_error("GM damage_building command failed")
		quit(1)
		return
	if not building_system.repair_building("wall"):
		push_error("Failed to start wall repair for GM assist test")
		quit(1)
		return
	if bool(npc_system.get_npc("priest_01").get("recruited", false)):
		push_error("Priest should start unrecruited for GM recruit test")
		quit(1)
		return
	if not _select_option_by_id(gm_panel._npc_select, "priest_01"):
		push_error("GM NPC selector should include priest_01")
		quit(1)
		return
	recruit_button.pressed.emit()
	await process_frame
	if not bool(npc_system.get_npc("priest_01").get("recruited", false)):
		push_error("GM recruit button should set selected NPC recruited")
		quit(1)
		return
	var priest_order: Dictionary = npc_system.debug_publish_npc_order("priest_01", "协助守备。")
	if not bool(priest_order.get("ok", false)):
		push_error("GM-recruited NPC should be able to receive orders")
		quit(1)
		return
	if not _select_option_by_id(formal_action_npc_select, "engineer_01"):
		push_error("GM formal action NPC selector should include engineer_01")
		quit(1)
		return
	if not npc_system.debug_enter_location_immediately("engineer_01", "plaza"):
		push_error("Failed to place engineer at plaza for GM assist test")
		quit(1)
		return
	npc_system.update_npc_state("engineer_01", {"wine": 1})
	if not action_system.debug_assign_action("engineer_01", "drink_wine"):
		push_error("Failed to prepare engineer active action before GM repair replacement")
		quit(1)
		return
	assist_repair_button.pressed.emit()
	await process_frame
	var gm_formal_repair: Dictionary = npc_system.get_formal_workstation_action_snapshot("engineer_01")
	var gm_formal_repair_session: Dictionary = gm_formal_repair.get("session", {}) if gm_formal_repair.get("session", {}) is Dictionary else {}
	if not bool(gm_formal_repair.get("active", false)) or str(gm_formal_repair_session.get("building_id", "")) != "wall":
		push_error("GM assist repair button did not create the selected formal exterior session")
		quit(1)
		return
	if int(building_system.get_repair_status("wall").get("helper_count", 0)) != 0:
		push_error("GM formal repair committed a helper before physical arrival")
		quit(1)
		return
	formal_repair_snapshot_button.pressed.emit()
	formal_repair_stop_button.pressed.emit()
	await process_frame
	if bool(npc_system.get_formal_workstation_action_snapshot("engineer_01").get("active", false)):
		push_error("GM formal repair stop left its session active")
		quit(1)
		return
	if not building_system.upgrade_building("main_hall"):
		push_error("Failed to start main-hall upgrade for GM assist test")
		quit(1)
		return
	if not _select_option_by_id(formal_action_npc_select, "doctor_01"):
		push_error("GM formal action NPC selector should include doctor_01")
		quit(1)
		return
	if not npc_system.debug_enter_location_immediately("doctor_01", "plaza"):
		push_error("Failed to place doctor at plaza for GM assist upgrade test")
		quit(1)
		return
	npc_system.update_npc_state("doctor_01", {"wine": 1})
	if not action_system.debug_assign_action("doctor_01", "drink_wine"):
		push_error("Failed to prepare doctor active action before GM upgrade replacement")
		quit(1)
		return
	if str(action_system.get_runtime_action_snapshot("doctor_01").get("phase", "")) != "active":
		push_error("Doctor should be in an active daily action before GM upgrade replacement")
		quit(1)
		return
	assist_upgrade_button.pressed.emit()
	await process_frame
	var gm_upgrade_formal: Dictionary = npc_system.get_formal_workstation_action_snapshot("doctor_01")
	var gm_upgrade_session: Dictionary = gm_upgrade_formal.get("session", {}) if gm_upgrade_formal.get("session", {}) is Dictionary else {}
	if (
		not bool(gm_upgrade_formal.get("active", false))
		or str(gm_upgrade_session.get("action_id", "")) != "assist_upgrade"
		or str(gm_upgrade_session.get("building_id", "")) != "main_hall"
		or str(gm_upgrade_session.get("service_kind", "")) != "upgrade"
		or int(building_system.get_upgrade_status("main_hall").get("helper_count", 0)) != 0
	):
		push_error("GM assist upgrade button did not start a pending formal construction route")
		quit(1)
		return
	formal_upgrade_snapshot_button.pressed.emit()
	formal_upgrade_stop_button.pressed.emit()
	await process_frame
	if bool(npc_system.get_formal_workstation_action_snapshot("doctor_01").get("active", false)):
		push_error("GM formal upgrade stop left its session active")
		quit(1)
		return
	npc_system.update_npc_state("doctor_01", {"wine": 1})
	if not action_system.debug_assign_action("doctor_01", "drink_wine"):
		push_error("Failed to prepare active action for invalid-upgrade preservation")
		quit(1)
		return
	if not _select_option_by_id(upgrade_building_select, "clinic"):
		push_error("GM upgrade target selector should include clinic")
		quit(1)
		return
	assist_upgrade_button.pressed.emit()
	await process_frame
	if action_system.get_runtime_action_id("doctor_01") != "drink_wine":
		push_error("Invalid GM upgrade command should preserve the NPC's prior valid action")
		quit(1)
		return
	action_system.interrupt_npc_action("doctor_01", "gm_invalid_upgrade_preservation_verified", true)
	if (
		not npc_system.debug_enter_location_immediately("doctor_01", "plaza")
		or not npc_system.debug_enter_location_immediately("cook_01", "plaza")
		or not _select_option_by_id(heal_target_select, "cook_01")
	):
		push_error("Failed to prepare GM formal healing target")
		quit(1)
		return
	npc_system.debug_damage_npc("cook_01", 999, "local_public")
	npc_system.update_npc_state("doctor_01", {"wine": 1})
	if not action_system.debug_assign_action("doctor_01", "drink_wine"):
		push_error("Failed to prepare doctor active action before GM healing replacement")
		quit(1)
		return
	var gm_heal_money_before := int(resource_system.get_resource("money"))
	assist_heal_button.pressed.emit()
	await process_frame
	var gm_heal_formal: Dictionary = npc_system.get_formal_healing_approach_snapshot("doctor_01")
	if (
		not bool(gm_heal_formal.get("active", false))
		or str(gm_heal_formal.get("target_npc_id", "")) != "cook_01"
		or not action_system.get_healing_helpers_for_target("cook_01").is_empty()
		or int(resource_system.get_resource("money")) != gm_heal_money_before
	):
		push_error("GM assist heal button did not start a zero-charge pending formal approach")
		quit(1)
		return
	formal_heal_snapshot_button.pressed.emit()
	formal_heal_stop_button.pressed.emit()
	await process_frame
	if bool(npc_system.get_formal_healing_approach_snapshot("doctor_01").get("active", false)):
		push_error("GM formal healing stop left its session active")
		quit(1)
		return
	npc_system.debug_advance_unconscious_recovery("cook_01", 999999.0)

	gm_panel._execute_command("set_time 2 9 10 11")
	gm_panel._execute_command("time_snapshot")
	if (
		int(game_state.current_day) != 2
		or int(game_state.current_hour) != 9
		or int(game_state.current_minute) != 10
		or int(game_state.current_second) != 11
	):
		push_error("GM set_time command failed")
		quit(1)
		return

	gm_panel._execute_command("enter_location cook_01 dining_hall")
	var cook_state: Dictionary = npc_system.get_npc_state("cook_01")
	if str(cook_state.get("current_location", "")) != "dining_hall":
		push_error("GM enter_location command failed")
		quit(1)
		return

	var event_count_before := int(memory_system.get_event_count())
	gm_panel._execute_command("give_money cook_01 2 local_public")
	if int(memory_system.get_event_count()) <= event_count_before:
		push_error("GM give_money command did not write an event")
		quit(1)
		return

	gm_panel._execute_command("attack_npc stableman_01 150 local_public")
	var stableman_state: Dictionary = npc_system.get_npc_state("stableman_01")
	if int(stableman_state.get("hp", -1)) != 0 or not bool(stableman_state.get("unconscious", false)):
		push_error("GM attack_npc command should deduct HP and set unconscious")
		quit(1)
		return
	var stableman_revive_hp := int(ceil(float(stableman_state.get("max_hp", 100)) * 0.3))
	var stableman_recovery_seconds := int(ceil(float(stableman_revive_hp) * 3600.0 / 2.0))
	gm_panel._execute_command("recover_npc stableman_01 %d" % stableman_recovery_seconds)
	stableman_state = npc_system.get_npc_state("stableman_01")
	if int(stableman_state.get("hp", -1)) != stableman_revive_hp or bool(stableman_state.get("unconscious", true)):
		push_error("GM recover_npc command should advance natural recovery and revive NPC")
		quit(1)
		return

	gm_panel._execute_command("plaza_notice Verify GM panel")
	var plaza_snapshot: Dictionary = memory_system.debug_get_location_snapshot("plaza")
	if str(plaza_snapshot.get("current_notice", "")) != "Verify GM panel":
		push_error("GM plaza_notice command failed")
		quit(1)
		return

	gm_panel._execute_command("memory cook_01")
	gm_panel._execute_command("location plaza")
	gm_panel._execute_command("events")
	gm_panel._execute_command("publish_order veteran_deputy_01 Hold the gate")
	if str(npc_system.get_current_order("veteran_deputy_01").get("text", "")) != "Hold the gate":
		push_error("GM publish_order command failed")
		quit(1)
		return
	gm_panel._execute_command("order veteran_deputy_01")
	gm_panel._execute_command("plan_request")
	if not str(gm_panel._help_text()).contains("dialogue_carryover"):
		push_error("GM help should expose the daily-plan dialogue carryover snapshot")
		quit(1)
		return
	gm_panel._execute_command("dialogue_carryover")
	gm_panel._execute_command("plan_generate veteran_deputy_01")
	gm_panel._execute_command("plan_generate_rule veteran_deputy_01")
	if npc_system.get_npc_plan("veteran_deputy_01").size() != 24:
		push_error("GM plan_generate_rule command should write a deterministic 24-hour plan")
		quit(1)
		return
	gm_panel._execute_command("plan veteran_deputy_01")
	gm_panel._execute_command("plan_execute veteran_deputy_01")
	gm_panel._execute_command("plan_revise veteran_deputy_01 gm_manual")
	var plan_result: Dictionary = daily_plan_system.get_last_reevaluation_result()
	if str(plan_result.get("npc_id", "")) != "veteran_deputy_01":
		push_error("GM plan_revise command should update DailyPlanSystem reevaluation result")
		quit(1)
		return
	action_system.interrupt_npc_action("veteran_deputy_01", "gm_plan_verify_cleanup")
	llm_bridge.debug_build_npc_context("veteran_deputy_01", "gm_verify")
	gm_panel._execute_command("last_order_injection")
	var injection: Dictionary = llm_bridge.get_last_npc_context_injection()
	if str(injection.get("npc_id", "")) != "veteran_deputy_01" or str(injection.get("current_order", {}).get("text", "")) != "Hold the gate":
		push_error("GM last_order_injection command did not expose the latest current_order")
		quit(1)
		return
	gm_panel._execute_command("station_context")
	var station_context: Dictionary = llm_bridge.debug_build_station_context()
	if (
		(station_context.get("building_roster", []) as Array).is_empty()
		or (station_context.get("work_mode_actions", []) as Array).is_empty()
		or (station_context.get("basic_resource_reserves", []) as Array).size() != 5
		or (station_context.get("station_rules", []) as Array).is_empty()
	):
		push_error("GM station_context command did not expose the expanded station context")
		quit(1)
		return

	var cook_diary_count_before := (
		npc_system.get_npc_long_memory("cook_01").get("diary", []) as Array
	).size()
	gm_panel._execute_command("reflect_npc cook_01 force")
	if not await _wait_for_reflection(
		npc_system,
		llm_bridge,
		"cook_01",
		cook_diary_count_before + 1
	):
		quit(1)
		return
	var cook_long_memory: Dictionary = npc_system.get_npc_long_memory("cook_01")
	if (cook_long_memory.get("diary", []) as Array).is_empty():
		push_error("GM reflect_npc command should write a diary entry")
		quit(1)
		return
	gm_panel._execute_command("long_memory cook_01")
	var long_memory_output := str(gm_panel._result_text.text)
	if not long_memory_output.contains("\"confidence\"") or not long_memory_output.contains("\"time\""):
		push_error("GM long_memory must retain raw confidence/time metadata even when NPCPanel hides it")
		quit(1)
		return
	gm_panel._execute_command("reflection_result")
	var reflection_result: Dictionary = daily_reflection_system.get_last_reflection_result()
	if str(reflection_result.get("npc_id", "")) != "cook_01":
		push_error("GM reflection_result should expose the latest reflection result")
		quit(1)
		return

	resource_system.add_resource("item_bow", 2)
	resource_system.add_resource("item_mail_chest", 1)
	gm_panel._execute_command("equip_weapon veteran_deputy_01 bow local_public")
	if str(equipment_system.get_npc_unit_type("veteran_deputy_01")) != "archer":
		push_error("GM equip_weapon command should equip bow and classify archer")
		quit(1)
		return
	gm_panel._execute_command("equip_armor veteran_deputy_01 chest local_public")
	if str(npc_system.get_npc("veteran_deputy_01").get("equipment", {}).get("chest", {}).get("id", "")) != "mail_chest":
		push_error("GM equip_armor command should equip chest armor")
		quit(1)
		return
	var horse_id := "horse_chestnut_wind"
	var horse_before: Dictionary = horse_system.get_horse_snapshot(horse_id)
	gm_panel._execute_command("horse_snapshot %s" % horse_id)
	gm_panel._execute_command("horse_damage %s 5" % horse_id)
	var horse_after_damage: Dictionary = horse_system.get_horse_snapshot(horse_id)
	if float(horse_after_damage.get("hp", 0.0)) >= float(horse_before.get("hp", 0.0)):
		push_error("GM horse_damage command should apply damage through HorseSystem")
		quit(1)
		return
	var satiety_before_advance := float(horse_after_damage.get("satiety", 0.0))
	gm_panel._execute_command("horse_advance 60")
	if float(horse_system.get_horse_snapshot(horse_id).get("satiety", 0.0)) >= satiety_before_advance:
		push_error("GM horse_advance command should advance horse ecology")
		quit(1)
		return
	var horse_count_before_birth := int(horse_system.get_horse_count())
	gm_panel._execute_command("horse_birth")
	if int(horse_system.get_horse_count()) != horse_count_before_birth or horse_system.get_pending_birth_snapshot().is_empty() or not horse_birth_dialog.visible:
		push_error("GM horse_birth command should open the formal naming flow before insertion")
		quit(1)
		return
	horse_birth_dialog.get_ok_button().pressed.emit()
	await process_frame
	if int(horse_system.get_horse_count()) != horse_count_before_birth + 1:
		push_error("GM horse_birth naming confirmation should insert one official foal")
		quit(1)
		return
	gm_panel._execute_command("horse_assign veteran_deputy_01 %s local_public" % horse_id)
	if str(equipment_system.get_npc_unit_type("veteran_deputy_01")) != "mounted_ranged":
		push_error("GM horse_assign command should assign a concrete horse and update unit type")
		quit(1)
		return
	if str(horse_system.get_horse_snapshot(horse_id).get("assigned_npc_id", "")) != "veteran_deputy_01":
		push_error("GM horse_assign should update the HorseSystem assignment fact")
		quit(1)
		return
	gm_panel._execute_command("horse_unassign veteran_deputy_01 local_public")
	if not str(horse_system.get_horse_snapshot(horse_id).get("assigned_npc_id", "")).is_empty():
		push_error("GM horse_unassign should clear the concrete horse assignment")
		quit(1)
		return
	if str(equipment_system.get_npc_unit_type("veteran_deputy_01")) != "archer":
		push_error("GM horse_unassign should clear the NPC mount projection")
		quit(1)
		return
	gm_panel._execute_command("unit_type veteran_deputy_01")
	gm_panel._execute_command("clear_enemies")
	time_system.set_time_scale(4.0)
	gm_panel._execute_command("spawn_wave 1")
	if combat_system.get_active_enemy_count() <= 0:
		push_error("GM spawn_wave command should spawn enemies")
		quit(1)
		return
	if not time_system.has_time_slowdown("combat_enemy_presence") or absf(float(time_system.get_effective_time_scale()) - (1.0 / 60.0)) > 0.001:
		push_error("GM-spawned enemies should force TimeSystem to one game second per real second")
		quit(1)
		return
	gm_panel._execute_command("enemies")
	gm_panel._execute_command("time_snapshot")
	gm_panel._execute_command("step_enemies 1")
	if (combat_system.debug_get_combat_snapshot().get("enemy_targets", []) as Array).is_empty():
		push_error("GM step_enemies command should expose enemy target state")
		quit(1)
		return
	gm_panel._execute_command("clear_enemies")
	if time_system.has_time_slowdown("combat_enemy_presence") or absf(float(time_system.get_effective_time_scale()) - 4.0) > 0.001:
		push_error("GM clear_enemies should release combat 1:1 slowdown and restore player speed")
		quit(1)
		return
	time_system.set_time_scale(1.0)
	gm_panel._execute_command("escape_npc priest_01")
	var priest_escape: Dictionary = npc_system.get_npc_state("priest_01").get("escape_intent", {})
	if str(priest_escape.get("status", "")) != "escaping":
		push_error("GM escape_npc command should start station escape")
		quit(1)
		return

	if not await _wait_for_llm_cleanup(llm_bridge):
		quit(1)
		return
	# The startup/planning verification above may intentionally leave gameplay paused.
	# Unpause and clear startup-plan work before asserting that a GM-assigned runtime
	# action starts immediately. Startup LLM timing must not decide this assertion.
	time_system.set_paused(false)
	action_system.interrupt_npc_action("veteran_deputy_01", "gm_verify_training_setup")
	_get_npc_node(npc_system, "veteran_deputy_01").set("move_speed", 5.0)
	if not npc_system.debug_enter_location_immediately("veteran_deputy_01", "training_ground"):
		push_error("Failed to place veteran at training ground for GM training test")
		quit(1)
		return
	gm_panel._execute_command("train_instructor veteran_deputy_01")
	if not await _wait_for_active(action_system, time_system, "veteran_deputy_01", "work_training_instructor"):
		push_error("GM train_instructor command should route the instructor to a real station")
		quit(1)
		return
	npc_system.set_npc_recruited("stableman_01", true)
	resource_system.add_resource("item_bow", 1)
	var stableman_weapon: Dictionary = equipment_system.equip_npc_main_weapon("stableman_01", "bow", "private")
	if not bool(stableman_weapon.get("ok", false)):
		push_error("Failed to equip stableman for GM training test")
		quit(1)
		return
	action_system.interrupt_npc_action("stableman_01", "gm_verify_training_setup")
	_get_npc_node(npc_system, "stableman_01").set("move_speed", 5.0)
	if not npc_system.debug_enter_location_immediately("stableman_01", "training_ground"):
		push_error("Failed to place stableman at training ground for GM training test")
		quit(1)
		return
	gm_panel._execute_command("train_student stableman_01")
	if not await _wait_for_active(action_system, time_system, "stableman_01", "receive_weapon_training"):
		push_error("GM train_student command should route the student to a real practice slot")
		quit(1)
		return

	if action_system.get_action_ids().has("work_repair_wall"):
		push_error("GM action list should not expose fixed wall repair action")
		quit(1)
		return

	print("GM panel verification passed.")
	quit(0)


func _select_option_by_id(select: OptionButton, expected_id: String) -> bool:
	if select == null:
		return false
	for index in range(select.get_item_count()):
		if str(select.get_item_metadata(index)) == expected_id:
			select.select(index)
			return true
	return false


func _has_button_text(root_node: Node, text: String) -> bool:
	for child in root_node.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.text == text:
			return true
	return false


func _wait_until_action_result(npc_system: Node, npc_id: String, expected_result: String) -> bool:
	for frame in range(600):
		await process_frame
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("last_action_result", "")) == expected_result:
			return true
	return false


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _wait_for_active(action_system: Node, time_system: Node, npc_id: String, action_id: String, max_frames: int = 1800) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == action_id:
			return true
	return false


func _wait_for_reflection(
	npc_system: Node,
	llm_bridge: Node,
	npc_id: String,
	expected_diary_count: int
) -> bool:
	for _step in range(300):
		await create_timer(0.01).timeout
		var diary: Array = npc_system.get_npc_long_memory(npc_id).get("diary", [])
		var runtime: Dictionary = llm_bridge.debug_get_llm_runtime_snapshot()
		if diary.size() == expected_diary_count and int(runtime.get("async_request_count", 0)) == 0:
			return true
	push_error("Timed out waiting for GM async reflection")
	return false


func _wait_for_llm_cleanup(llm_bridge: Node) -> bool:
	for _step in range(300):
		await create_timer(0.01).timeout
		if int(llm_bridge.debug_get_llm_runtime_snapshot().get("async_request_count", 0)) == 0:
			return true
	push_error("Timed out waiting for GM LLM async cleanup")
	return false


func _panel_tracks_button(panel: Control, button: Control) -> bool:
	var panel_rect := panel.get_global_rect()
	var button_rect := button.get_global_rect()
	var below := (
		absf(panel_rect.position.x - button_rect.position.x) <= 2.0
		and absf(panel_rect.position.y - (button_rect.end.y + 8.0)) <= 2.0
	)
	var above := (
		absf(panel_rect.position.x - button_rect.position.x) <= 2.0
		and absf(panel_rect.end.y - (button_rect.position.y - 8.0)) <= 2.0
	)
	var right := absf(panel_rect.position.x - (button_rect.end.x + 8.0)) <= 2.0
	var left := absf(panel_rect.end.x - (button_rect.position.x - 8.0)) <= 2.0
	return below or above or right or left


func _panel_inside_viewport(panel: Control, viewport_size: Vector2) -> bool:
	var panel_rect := panel.get_global_rect()
	return (
		panel_rect.position.x >= 0.0
		and panel_rect.position.y >= 0.0
		and panel_rect.position.x + panel_rect.size.x <= viewport_size.x + 1.0
		and panel_rect.position.y + panel_rect.size.y <= viewport_size.y + 1.0
	)
