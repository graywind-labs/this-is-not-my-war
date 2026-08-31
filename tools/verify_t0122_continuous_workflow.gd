extends SceneTree


const NPC_IDS: Array[String] = [
	"veteran_deputy_01",
	"stableman_01",
	"cook_01",
	"gardener_01",
	"blacksmith_01",
	"engineer_01",
	"priest_01",
	"doctor_01"
]

const RECRUIT_BY_WAVE := {
	1: ["veteran_deputy_01", "cook_01"],
	2: ["veteran_deputy_01", "cook_01", "stableman_01"],
	3: ["veteran_deputy_01", "cook_01", "stableman_01", "blacksmith_01", "engineer_01"],
	4: ["veteran_deputy_01", "cook_01", "stableman_01", "blacksmith_01", "engineer_01", "gardener_01"],
	5: ["veteran_deputy_01", "cook_01", "stableman_01", "blacksmith_01", "engineer_01", "gardener_01", "doctor_01"]
}

const WEAPON_PLAN := {
	"veteran_deputy_01": {"wave": 1, "weapon": "sword_shield"},
	"cook_01": {"wave": 1, "weapon": "polearm"},
	"stableman_01": {"wave": 2, "weapon": "bow"},
	"blacksmith_01": {"wave": 3, "weapon": "sword_shield"},
	"engineer_01": {"wave": 3, "weapon": "crossbow"},
	"gardener_01": {"wave": 4, "weapon": "polearm"},
	"doctor_01": {"wave": 5, "weapon": "bow"}
}

const ARMOR_PLAN := [
	{"wave": 3, "npc_id": "veteran_deputy_01", "armor": "iron_helmet", "slot": "helmet"},
	{"wave": 3, "npc_id": "blacksmith_01", "armor": "iron_helmet", "slot": "helmet"},
	{"wave": 4, "npc_id": "veteran_deputy_01", "armor": "mail_chest", "slot": "chest"},
	{"wave": 4, "npc_id": "veteran_deputy_01", "armor": "iron_bracers", "slot": "bracers"},
	{"wave": 4, "npc_id": "blacksmith_01", "armor": "iron_bracers", "slot": "bracers"},
	{"wave": 4, "npc_id": "veteran_deputy_01", "armor": "iron_greaves", "slot": "greaves"},
	{"wave": 5, "npc_id": "cook_01", "armor": "iron_helmet", "slot": "helmet"},
	{"wave": 5, "npc_id": "cook_01", "armor": "iron_greaves", "slot": "greaves"}
]

const BLACKSMITH_QUEUE := [
	{"wave": 1, "recipe": "craft_polearm", "item": "item_polearm", "count": 1},
	# Ada's initial sword-and-shield is already an asset; W3 requires a second
	# copy for Glenn, so the cumulative asset target is two.
	{"wave": 3, "recipe": "craft_sword_shield", "item": "item_sword_shield", "count": 2},
	{"wave": 3, "recipe": "craft_iron_helmet", "item": "item_iron_helmet", "count": 2},
	{"wave": 4, "recipe": "craft_polearm", "item": "item_polearm", "count": 2},
	{"wave": 4, "recipe": "craft_mail_chest", "item": "item_mail_chest", "count": 1},
	{"wave": 4, "recipe": "craft_iron_bracers", "item": "item_iron_bracers", "count": 2},
	{"wave": 4, "recipe": "craft_iron_greaves", "item": "item_iron_greaves", "count": 1},
	{"wave": 5, "recipe": "craft_iron_greaves", "item": "item_iron_greaves", "count": 2},
	{"wave": 5, "recipe": "craft_iron_helmet", "item": "item_iron_helmet", "count": 3}
]

const WORKSHOP_QUEUE := [
	{"wave": 1, "recipe": "craft_wall_arrow_tower", "item": "item_wall_arrow_tower", "count": 1},
	{"wave": 2, "recipe": "craft_bow", "item": "item_bow", "count": 1},
	{"wave": 3, "recipe": "craft_crossbow", "item": "item_crossbow", "count": 1},
	{"wave": 3, "recipe": "craft_wall_ballista", "item": "item_wall_ballista", "count": 1},
	{"wave": 4, "recipe": "craft_wall_arrow_tower", "item": "item_wall_arrow_tower", "count": 2},
	{"wave": 5, "recipe": "craft_bow", "item": "item_bow", "count": 2},
	{"wave": 5, "recipe": "craft_wall_arrow_tower", "item": "item_wall_arrow_tower", "count": 3}
]

const DEVICE_PLAN := [
	{"wave": 1, "device": "wall_arrow_tower", "slot": "main_hall_slot_03"},
	{"wave": 3, "device": "wall_ballista", "slot": "wall_slot_01"},
	{"wave": 4, "device": "wall_arrow_tower", "slot": "wall_slot_02"},
	{"wave": 5, "device": "wall_arrow_tower", "slot": "main_hall_slot_04"}
]

const ITEM_TO_RECIPE := {
	"item_polearm": "craft_polearm",
	"item_sword_shield": "craft_sword_shield",
	"item_iron_helmet": "craft_iron_helmet",
	"item_mail_chest": "craft_mail_chest",
	"item_iron_bracers": "craft_iron_bracers",
	"item_iron_greaves": "craft_iron_greaves",
	"item_bow": "craft_bow",
	"item_crossbow": "craft_crossbow",
	"item_wall_ballista": "craft_wall_ballista",
	"item_wall_arrow_tower": "craft_wall_arrow_tower"
}

const DEVICE_ITEM_BY_ID := {
	"wall_ballista": "item_wall_ballista",
	"wall_arrow_tower": "item_wall_arrow_tower"
}

var scenario := "natural"
var systems := {}
var npc_nodes: Array[Node] = []
var planning_wave := 1
var deployment_wave := 1
var upgrade_wave := 1
var active_wave := 0
var last_cleared_wave := 0
var alarm_days := {}
var trade_windows := {}
var boundary_keys := {}
var battle_reports: Array[Dictionary] = []
var transaction_totals := {"wine_sold": 0, "money_earned": 0, "money_spent": 0, "bought": {}}
var action_completion_counts := {}
var last_action_results := {}
var peak_piety := 0.0
var failure_messages: Array[String] = []


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.trim_prefix("--scenario=")
	if not ["natural", "focused"].has(scenario):
		_fail("Unknown T0122 scenario: %s" % scenario)
		return

	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	root.add_child(main_scene.instantiate())
	await process_frame
	await physics_frame

	if not _resolve_systems():
		return
	_prepare_isolated_player_replay()
	print("T0122 continuous replay started: scenario=%s start=day1 06:00 end=day7 18:00" % scenario)

	var guard := 0
	while not bool(systems.game_state.get("game_over")) and _absolute_game_seconds() < _day_seconds(7, 20, 0):
		guard += 1
		if guard > 20000:
			_fail("Continuous replay exceeded its simulation guard")
			return
		_player_decisions()
		var x1_step := _uses_x1_step()
		var game_delta := 60.0 if x1_step else _get_normal_game_step()
		var real_delta := game_delta / (60.0 if x1_step else 240.0)
		_step_npc_movement(real_delta)
		if not systems.time.debug_advance_game_seconds(game_delta):
			_fail("Time advance failed before the expected terminal state")
			return
		if guard % 120 == 0:
			await process_frame
		_capture_action_completions()
		_capture_battle_transition()
		peak_piety = maxf(peak_piety, _get_piety())

	_finalize_report()


func _resolve_systems() -> bool:
	systems = {
		"time": root.get_node_or_null("Main/Systems/TimeSystem"),
		"npc": root.get_node_or_null("Main/Systems/NPCSystem"),
		"needs": root.get_node_or_null("Main/Systems/NPCNeedsSystem"),
		"action": root.get_node_or_null("Main/Systems/ActionSystem"),
		"crafting": root.get_node_or_null("Main/Systems/CraftingSystem"),
		"resource": root.get_node_or_null("Main/Systems/ResourceSystem"),
		"merchant": root.get_node_or_null("Main/Systems/MerchantSystem"),
		"building": root.get_node_or_null("Main/Systems/BuildingSystem"),
		"equipment": root.get_node_or_null("Main/Systems/EquipmentSystem"),
		"horse": root.get_node_or_null("Main/Systems/HorseSystem"),
		"device": root.get_node_or_null("Main/Systems/DefenseDeviceSystem"),
		"combat": root.get_node_or_null("Main/Systems/CombatSystem"),
		"piety": root.get_node_or_null("Main/Systems/PietySystem"),
		"llm": root.get_node_or_null("Main/Systems/LLMBridge"),
		"daily_plan": root.get_node_or_null("Main/Systems/DailyPlanSystem"),
		"reflection": root.get_node_or_null("Main/Systems/DailyReflectionSystem"),
		"game_state": root.get_node_or_null("/root/GameState"),
		"event_bus": root.get_node_or_null("/root/EventBus")
	}
	for system_id in systems:
		if systems[system_id] == null:
			_fail("Missing system for continuous replay: %s" % system_id)
			return false
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		_fail("Missing NPC scene root")
		return false
	for child in npc_root.get_children():
		if child.has_meta("npc_id"):
			npc_nodes.append(child)
	return npc_nodes.size() == NPC_IDS.size()


func _prepare_isolated_player_replay() -> void:
	# The headless replay replaces LLM day planning with deterministic player macro
	# orders. It still uses the real movement, actions, needs, crafting, trade,
	# buildings, equipment, horses, devices and scheduled combat systems.
	systems.daily_plan.set_auto_execution_enabled(false)
	var day_callable := Callable(systems.daily_plan, "_on_day_started")
	if systems.event_bus.day_started.is_connected(day_callable):
		systems.event_bus.day_started.disconnect(day_callable)
	var reflection_tick := Callable(systems.reflection, "_on_logical_time_tick")
	if systems.event_bus.logical_time_tick.is_connected(reflection_tick):
		systems.event_bus.logical_time_tick.disconnect(reflection_tick)
	var reflection_event := Callable(systems.reflection, "_on_event_recorded")
	if systems.event_bus.event_recorded.is_connected(reflection_event):
		systems.event_bus.event_recorded.disconnect(reflection_event)
	systems.time.set_process(false)
	systems.time.set_paused(false)
	systems.time.set_time_scale(4.0)
	for npc_id in NPC_IDS:
		last_action_results[npc_id] = str(systems.npc.get_npc_state(npc_id).get("last_action_result", ""))
	_try_set_crafting_targets()


func _player_decisions() -> void:
	var day := int(systems.game_state.current_day)
	var hour := int(systems.game_state.current_hour)
	var minute := int(systems.game_state.current_minute)
	# Production has to look beyond the immediately arriving wave. Otherwise the
	# 29 workshop stages required by W3 cannot physically fit into the single day
	# between W2 and W3. The horizon mirrors a player who reads the five-wave
	# schedule, but procurement still happens only during the merchant window.
	if day <= 1:
		planning_wave = 1
	elif day <= 3:
		planning_wave = 3
	elif day == 4:
		planning_wave = 4
	else:
		planning_wave = 5
	deployment_wave = clampi(day - 2, 1, 5)
	upgrade_wave = clampi(day - 1, 1, 5)

	_handle_schedule_boundary(day, hour, minute)
	if hour >= 10 and hour < 16:
		var trade_key := "%d:%d" % [day, hour]
		if not trade_windows.has(trade_key):
			trade_windows[trade_key] = true
			_trade_and_procure(day)
	_try_start_repairs()
	_try_start_upgrades()
	_try_recruit_and_prepare(day, hour, minute)
	_try_deploy_devices()
	if _is_work_window(hour, minute) and active_wave == 0:
		if scenario == "focused" and last_cleared_wave > 0 and day < 7:
			_assign_evening_recovery_if_idle()
		_assign_work_if_idle()
		if scenario == "focused" and last_cleared_wave > 0 and day >= 7:
			_assign_evening_recovery_if_idle()
	elif scenario == "focused" and hour == 18 and active_wave == 0 and last_cleared_wave > 0:
		_assign_evening_recovery_if_idle()
	elif hour >= 19 and hour < 22 and active_wave == 0:
		if scenario == "focused" and day == 6 and last_cleared_wave >= 4:
			_assign_final_wave_workshop_overtime_if_idle()
		_assign_evening_recovery_if_idle()
	elif _focused_recovery_overtime(day, hour) and active_wave == 0:
		_assign_evening_recovery_if_idle()
		_assign_sleep_if_idle(["doctor_01", "priest_01"])
	elif (hour >= 22 or hour < 6) and active_wave == 0:
		_assign_sleep_if_idle()


func _handle_schedule_boundary(day: int, hour: int, minute: int) -> void:
	var boundary := ""
	if minute == 0 and (hour == 6 or (scenario == "focused" and day == 7 and hour == 5)):
		boundary = "wake"
	elif hour == 12 and minute == 0:
		boundary = "lunch"
	elif hour == 17 and minute == 0 and scenario != "focused":
		boundary = "rest"
	elif hour == 17 and minute == 36 and scenario == "focused":
		boundary = "rest"
	elif hour == 22 and minute == 0:
		boundary = "sleep"
	if boundary.is_empty():
		return
	var key := "%d:%s" % [day, boundary]
	if boundary_keys.has(key):
		return
	boundary_keys[key] = true
	for npc_id in NPC_IDS:
		if not bool(systems.npc.get_npc_state(npc_id).get("unconscious", false)):
			systems.action.interrupt_npc_action(npc_id, "t0122_%s" % boundary, true)
	if boundary == "lunch":
		for npc_id in NPC_IDS:
			if systems.npc.can_npc_act(npc_id):
				systems.action.debug_assign_eat(npc_id)


func _is_work_window(hour: int, minute: int) -> bool:
	if scenario == "focused" and int(systems.game_state.current_day) == 7 and hour >= 5 and hour < 12:
		return true
	if hour >= 7 and hour < 12:
		return true
	if scenario == "focused":
		return (
			(hour == 12 and minute >= 20)
			or (hour >= 13 and hour < 17)
			or (hour == 17 and minute < 36)
		)
	return hour >= 13 and hour < 17


func _uses_x1_step() -> bool:
	if active_wave > 0 or systems.combat.get_active_enemy_count() > 0:
		return true
	var hour := int(systems.game_state.current_hour)
	var minute := int(systems.game_state.current_minute)
	if hour == 17 and minute >= 36:
		return true
	if scenario == "focused" and _any_npc_moving() and (_is_work_window(hour, minute) or hour == 12):
		return true
	return false


func _get_normal_game_step() -> float:
	var hour := int(systems.game_state.current_hour)
	if (hour >= 22 or hour < 6) and not _any_npc_moving():
		return 1800.0
	return 240.0


func _any_npc_moving() -> bool:
	for npc_node in npc_nodes:
		if bool(npc_node.get("_is_moving")):
			return true
	return false


func _step_npc_movement(real_seconds: float) -> void:
	for npc_node in npc_nodes:
		if bool(npc_node.get("_is_moving")):
			npc_node.call("_process", real_seconds)


func _assign_work_if_idle() -> void:
	_try_set_crafting_targets()
	_try_assign_crafting("blacksmith_01", "blacksmith", BLACKSMITH_QUEUE)
	_try_assign_crafting("engineer_01", "workshop", WORKSHOP_QUEUE)
	# The final-wave focused line deliberately reallocates the gardener and priest
	# into the second production slots. This is the intended hard-wave decision:
	# it trades away farming and prayer instead of receiving free production.
	if scenario == "focused" and int(systems.game_state.current_day) >= 7:
		_try_assign_first_available_crafting_helper(
			["gardener_01", "veteran_deputy_01", "stableman_01", "priest_01"],
			"blacksmith",
			BLACKSMITH_QUEUE
		)
		_try_assign_first_available_crafting_helper(
			["priest_01", "stableman_01", "veteran_deputy_01", "gardener_01"],
			"workshop",
			WORKSHOP_QUEUE
		)

	if _is_idle_and_able("cook_01"):
		var meal_target := 8
		if systems.resource.get_resource("meal") < meal_target:
			systems.action.debug_assign_work("cook_01", "dining_hall")
		elif systems.resource.get_resource("grain") >= 1:
			systems.action.debug_assign_work("cook_01", "tavern")

	if _is_idle_and_able("gardener_01") and systems.resource.get_resource("grain") < 24:
		systems.action.debug_assign_work("gardener_01", "garden")
	if _is_idle_and_able("stableman_01"):
		if systems.resource.get_resource("grain") < 12:
			systems.action.debug_assign_work("stableman_01", "garden")
		else:
			systems.action.debug_assign_work("stableman_01", "stable")


func _try_set_crafting_targets() -> void:
	_set_next_target("blacksmith", BLACKSMITH_QUEUE)
	_set_next_target("workshop", WORKSHOP_QUEUE)


func _set_next_target(building_id: String, queue: Array) -> void:
	var next_recipe := ""
	for entry in queue:
		if int(entry.get("wave", 99)) > planning_wave:
			continue
		if _asset_count(str(entry.get("item", ""))) < int(entry.get("count", 0)):
			next_recipe = str(entry.get("recipe", ""))
			break
	var current := str(systems.crafting.get_project_snapshot(building_id).get("target_recipe_id", ""))
	if current != next_recipe:
		systems.crafting.set_target(building_id, next_recipe, true)


func _try_assign_crafting(npc_id: String, building_id: String, _queue: Array) -> void:
	if not _is_idle_and_able(npc_id):
		return
	var project: Dictionary = systems.crafting.get_project_snapshot(building_id)
	if str(project.get("target_recipe_id", "")).is_empty():
		return
	var eligibility: Dictionary = systems.crafting.can_start_work_cycle(building_id, npc_id)
	if bool(eligibility.get("ok", false)):
		systems.action.debug_assign_work(npc_id, building_id)


func _try_assign_first_available_crafting_helper(
	candidate_ids: Array[String],
	building_id: String,
	queue: Array
) -> void:
	var project: Dictionary = systems.crafting.get_project_snapshot(building_id)
	if str(project.get("target_recipe_id", "")).is_empty():
		return
	for npc_id in candidate_ids:
		if not _is_idle_and_able(npc_id):
			continue
		_try_assign_crafting(npc_id, building_id, queue)
		if not _is_idle_and_able(npc_id):
			return


func _assign_final_wave_workshop_overtime_if_idle() -> void:
	# The fourth-wave aftermath is the real final production squeeze. Keep the
	# clinic running, but use the workshop's second slot with whoever is still on
	# their feet; this is paid for with that NPC's recovery/prayer time.
	_try_set_crafting_targets()
	_try_assign_crafting("engineer_01", "workshop", WORKSHOP_QUEUE)
	_try_assign_first_available_crafting_helper(
		["stableman_01", "gardener_01", "veteran_deputy_01", "cook_01", "priest_01"],
		"workshop",
		WORKSHOP_QUEUE
	)


func _assign_evening_recovery_if_idle() -> void:
	if _is_idle_and_able("doctor_01"):
		var target_id := _first_unconscious_npc("doctor_01")
		if not target_id.is_empty() and systems.resource.get_resource("money") >= 4:
			systems.action.debug_assign_heal_assist("doctor_01", target_id)
		elif _has_injured_conscious_recruit() and systems.resource.get_resource("money") >= 4:
			systems.action.debug_assign_action("doctor_01", "work_clinic_doctor")
	_assign_clinic_patients_if_idle()
	if _is_idle_and_able("priest_01"):
		var target_id := _first_unconscious_npc("priest_01")
		if not target_id.is_empty() and systems.resource.get_resource("money") >= 8:
			systems.action.debug_assign_heal_assist("priest_01", target_id)
		else:
			systems.action.debug_assign_action("priest_01", "pray_at_chapel")


func _has_injured_conscious_recruit() -> bool:
	for npc_id in NPC_IDS:
		var npc: Dictionary = systems.npc.get_npc(npc_id)
		var state: Dictionary = systems.npc.get_npc_state(npc_id)
		if (
			bool(npc.get("recruited", false))
			and not bool(state.get("unconscious", false))
			and int(state.get("hp", 0)) < int(state.get("max_hp", 0))
		):
			return true
	return false


func _assign_clinic_patients_if_idle() -> void:
	var candidates: Array[Dictionary] = []
	for npc_id in NPC_IDS:
		if not _is_idle_and_able(npc_id):
			continue
		var npc: Dictionary = systems.npc.get_npc(npc_id)
		var state: Dictionary = systems.npc.get_npc_state(npc_id)
		if not bool(npc.get("recruited", false)):
			continue
		var hp := int(state.get("hp", 0))
		var max_hp := maxi(1, int(state.get("max_hp", 1)))
		if hp >= max_hp:
			continue
		candidates.append({"npc_id": npc_id, "ratio": float(hp) / float(max_hp)})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return float(left.get("ratio", 1.0)) < float(right.get("ratio", 1.0))
	)
	var assigned_count := 0
	for candidate in candidates:
		if assigned_count >= 2:
			break
		if systems.resource.get_resource("money") < 4:
			break
		if systems.action.debug_assign_action(str(candidate.get("npc_id", "")), "receive_clinic_treatment"):
			assigned_count += 1


func _assign_sleep_if_idle(excluded_npc_ids: Array[String] = []) -> void:
	for npc_id in NPC_IDS:
		if excluded_npc_ids.has(npc_id):
			continue
		if _is_idle_and_able(npc_id):
			systems.action.debug_assign_sleep(npc_id)


func _focused_recovery_overtime(day: int, hour: int) -> bool:
	if scenario != "focused":
		return false
	var is_overtime_window := (day == 6 and hour >= 22) or (day == 7 and hour < 6)
	if not is_overtime_window:
		return false
	for npc_id in ["blacksmith_01", "engineer_01"]:
		if bool(systems.npc.get_npc_state(npc_id).get("unconscious", false)):
			return true
	return false


func _first_unconscious_npc(exclude_id: String) -> String:
	# Restore the two bottleneck producers before front-line fighters. This is a
	# deliberate, visible post-battle decision a competent player can make.
	var priorities := [
		"blacksmith_01", "engineer_01", "veteran_deputy_01", "cook_01",
		"stableman_01", "gardener_01", "doctor_01", "priest_01"
	]
	# Spread two healers across two critical workers before stacking them. This
	# restores both production lines sooner after the fourth-wave spike.
	for maximum_helpers in [0, 1]:
		for npc_id in priorities:
			if npc_id == exclude_id:
				continue
			if not bool(systems.npc.get_npc_state(npc_id).get("unconscious", false)):
				continue
			var helper_count: int = systems.action.get_healing_helpers_for_target(npc_id).size()
			if helper_count <= maximum_helpers:
				return npc_id
	return ""


func _is_idle_and_able(npc_id: String) -> bool:
	if not systems.npc.can_npc_act(npc_id):
		return false
	return str(systems.npc.get_npc_state(npc_id).get("current_action", "")) == "idle"


func _trade_and_procure(day: int) -> void:
	if not systems.merchant.is_merchant_present():
		return
	var wine := int(systems.resource.get_resource("wine"))
	if wine > 0:
		var sell_result: Dictionary = systems.merchant.sell_resource("wine", wine)
		if bool(sell_result.get("ok", false)):
			transaction_totals.wine_sold += wine
			transaction_totals.money_earned += wine * 4

	var required := _remaining_material_need(planning_wave)
	# A normal player retains a small treatment buffer. The focused route spends
	# down to a smaller reserve to test the upper production bound.
	var reserve_money := 8 if scenario == "focused" else 12
	for resource_id in ["iron", "wood", "stone", "grain"]:
		var target := int(required.get(resource_id, 0))
		if resource_id == "grain":
			target = maxi(target, 18)
		var deficit := maxi(0, target - int(systems.resource.get_resource(resource_id)))
		if deficit <= 0:
			continue
		var offer: Dictionary = systems.merchant.get_buy_offer(resource_id)
		var price := int(offer.get("unit_price", 0))
		var affordable := maxi(0, (int(systems.resource.get_resource("money")) - reserve_money) / maxi(1, price))
		var amount := mini(deficit, affordable)
		if amount <= 0:
			continue
		var buy_result: Dictionary = systems.merchant.buy_resource(resource_id, amount)
		if bool(buy_result.get("ok", false)):
			transaction_totals.money_spent += amount * price
			var bought: Dictionary = transaction_totals.bought
			bought[resource_id] = int(bought.get(resource_id, 0)) + amount


func _remaining_material_need(wave: int) -> Dictionary:
	var required := {"wood": 0, "stone": 0, "iron": 0, "grain": 0}
	for queue in [BLACKSMITH_QUEUE, WORKSHOP_QUEUE]:
		for entry in queue:
			if int(entry.get("wave", 99)) > wave:
				continue
			var missing := maxi(0, int(entry.get("count", 0)) - _asset_count(str(entry.get("item", ""))))
			if missing <= 0:
				continue
			_add_recipe_remaining_cost(required, str(entry.get("recipe", "")), missing)
	_add_building_remaining_cost(required, wave)
	_add_repair_costs(required)
	return required


func _add_recipe_remaining_cost(required: Dictionary, recipe_id: String, missing_count: int) -> void:
	var recipe: Dictionary = systems.crafting.get_recipe(recipe_id)
	var completed_stages := 0
	var building_id := str(recipe.get("building_id", ""))
	var project: Dictionary = systems.crafting.get_project_snapshot(building_id)
	if str(project.get("target_recipe_id", "")) == recipe_id:
		completed_stages = int(project.get("completed_stages", 0))
	var stages: Array = recipe.get("stages", [])
	for copy_index in range(missing_count):
		for stage_index in range(stages.size()):
			if copy_index == 0 and stage_index < completed_stages:
				continue
			var cost: Dictionary = stages[stage_index].get("cost", {})
			_add_cost(required, cost)


func _add_building_remaining_cost(required: Dictionary, wave: int) -> void:
	var targets := {"wall": 2 if wave >= 3 else 1, "main_hall": 3 if wave >= 5 else 1}
	if scenario == "focused" and wave >= 4:
		targets["blacksmith"] = 2
		targets["workshop"] = 2
	for building_id in targets:
		var building: Dictionary = systems.building.get_building(building_id)
		var level := int(building.get("level", 1))
		var target := int(targets[building_id])
		var upgrade: Dictionary = building.get("upgrade", {})
		var effects: Dictionary = upgrade.get("level_effects", {})
		for next_level in range(level + 1, target + 1):
			var effect: Dictionary = effects.get(str(next_level), {})
			_add_cost(required, effect.get("cost", upgrade.get("cost", {})))


func _add_repair_costs(required: Dictionary) -> void:
	for building_id in systems.building.get_building_ids():
		var quote: Dictionary = systems.building.get_repair_quote(str(building_id))
		_add_cost(required, quote.get("cost", {}))


func _add_cost(total: Dictionary, cost: Dictionary) -> void:
	for resource_id in cost:
		if total.has(resource_id):
			total[resource_id] = int(total.get(resource_id, 0)) + int(cost[resource_id])


func _try_start_repairs() -> void:
	if active_wave > 0:
		return
	for building_id in systems.building.get_building_ids():
		var id := str(building_id)
		var building: Dictionary = systems.building.get_building(id)
		if int(building.get("hp", 0)) >= int(building.get("max_hp", 0)):
			continue
		if systems.building.can_repair_building(id):
			systems.building.repair_building(id)


func _try_start_upgrades() -> void:
	if active_wave > 0:
		return
	var targets := {"wall": 2 if upgrade_wave >= 3 else 1, "main_hall": 3 if upgrade_wave >= 5 else 1}
	if scenario == "focused" and planning_wave >= 4:
		targets["blacksmith"] = 2
		targets["workshop"] = 2
	for building_id in ["wall", "main_hall", "blacksmith", "workshop"]:
		if not targets.has(building_id):
			continue
		var building: Dictionary = systems.building.get_building(building_id)
		if int(building.get("level", 1)) < int(targets[building_id]) and systems.building.can_upgrade_building(building_id):
			systems.building.upgrade_building(building_id)


func _try_recruit_and_prepare(day: int, hour: int, minute: int) -> void:
	if day < 3 or day > 7 or hour < 17:
		return
	var wave := day - 2
	for npc_id in RECRUIT_BY_WAVE.get(wave, []):
		systems.npc.set_npc_recruited(str(npc_id), true)
	_try_equip_loadout(wave)
	_try_assign_horses(wave)
	if hour == 17 and minute >= 40 and not alarm_days.has(day):
		alarm_days[day] = true
		for npc_id in RECRUIT_BY_WAVE.get(wave, []):
			var unit_type := str(systems.equipment.get_npc_unit_type(str(npc_id)))
			var strategy := "max_output" if ["archer", "crossbowman", "mounted_ranged"].has(unit_type) else "attack"
			systems.combat.set_npc_combat_strategy(str(npc_id), strategy, "private", "t0122_continuous")
		var alarm_result: Dictionary = systems.combat.trigger_combat_alarm("t0122_continuous")
		var expected_count := (RECRUIT_BY_WAVE.get(wave, []) as Array).size()
		if int(alarm_result.get("eligible_count", 0)) != expected_count:
			_record_observation_once("W%d alarm eligible=%d expected=%d" % [wave, int(alarm_result.get("eligible_count", 0)), expected_count])


func _try_equip_loadout(wave: int) -> void:
	for npc_id in WEAPON_PLAN:
		var plan: Dictionary = WEAPON_PLAN[npc_id]
		if int(plan.get("wave", 99)) > wave:
			continue
		var equipment: Dictionary = systems.equipment.get_equipment_snapshot(npc_id)
		if not (equipment.get("main_weapon", {}) as Dictionary).is_empty():
			continue
		var weapon_def: Dictionary = systems.equipment.get_weapon_def(str(plan.get("weapon", "")))
		if systems.resource.get_resource(str(weapon_def.get("source_resource_id", ""))) <= 0:
			continue
		var result: Dictionary = systems.equipment.equip_npc_main_weapon(npc_id, str(plan.get("weapon", "")), "private")
		if not bool(result.get("ok", false)):
			_record_observation_once("W%d weapon equip failed for %s: %s" % [wave, npc_id, str(result.get("error", result.get("reason", "equip_failed")))])
	for plan in ARMOR_PLAN:
		if int(plan.get("wave", 99)) > wave:
			continue
		var npc_id := str(plan.get("npc_id", ""))
		var slot := str(plan.get("slot", ""))
		var equipment: Dictionary = systems.equipment.get_equipment_snapshot(npc_id)
		if not (equipment.get(slot, {}) as Dictionary).is_empty():
			continue
		var armor_def: Dictionary = systems.equipment.get_armor_def(str(plan.get("armor", "")))
		if systems.resource.get_resource(str(armor_def.get("source_resource_id", ""))) <= 0:
			continue
		var result: Dictionary = systems.equipment.equip_npc_armor(npc_id, slot, str(plan.get("armor", "")), "private")
		if not bool(result.get("ok", false)):
			_record_observation_once("W%d armor equip failed %s/%s" % [wave, npc_id, slot])


func _try_assign_horses(wave: int) -> void:
	if wave < 2:
		return
	for npc_id in ["veteran_deputy_01", "stableman_01"]:
		if not systems.horse.get_assigned_horse_for_npc(npc_id).is_empty():
			continue
		var available: Array = systems.horse.get_available_horses_for_npc(npc_id)
		if available.is_empty():
			continue
		var horse_id := str((available[0] as Dictionary).get("horse_id", ""))
		systems.horse.assign_horse_to_npc(npc_id, horse_id, "private")


func _try_deploy_devices() -> void:
	for plan in DEVICE_PLAN:
		if int(plan.get("wave", 99)) > deployment_wave:
			continue
		var slot_id := str(plan.get("slot", ""))
		if not systems.device.get_deployment_for_slot(slot_id).is_empty():
			continue
		var device_id := str(plan.get("device", ""))
		var eligibility: Dictionary = systems.device.get_deploy_eligibility(device_id, slot_id)
		if not bool(eligibility.get("ok", false)):
			continue
		var result: Dictionary = systems.device.deploy_device(device_id, slot_id)
		if not bool(result.get("ok", false)):
			_record_observation_once("Device deployment failed %s/%s: %s" % [device_id, slot_id, JSON.stringify(result)])


func _asset_count(item_id: String) -> int:
	var count := int(systems.resource.get_resource(item_id))
	for npc_id in NPC_IDS:
		var equipment: Dictionary = systems.equipment.get_equipment_snapshot(npc_id)
		for slot_id in ["main_weapon", "helmet", "chest", "bracers", "greaves"]:
			var item: Dictionary = equipment.get(slot_id, {})
			if str(item.get("source_resource_id", "")) == item_id:
				count += 1
	for deployment in systems.device.get_deployments():
		var device_id := str(deployment.get("device_id", ""))
		if str(DEVICE_ITEM_BY_ID.get(device_id, "")) == item_id:
			count += 1
	return count


func _capture_action_completions() -> void:
	for npc_id in NPC_IDS:
		var result := str(systems.npc.get_npc_state(npc_id).get("last_action_result", ""))
		if result == str(last_action_results.get(npc_id, "")):
			continue
		last_action_results[npc_id] = result
		if result.begins_with("completed_"):
			action_completion_counts[result] = int(action_completion_counts.get(result, 0)) + 1


func _capture_battle_transition() -> void:
	var enemy_count := int(systems.combat.get_active_enemy_count())
	var schedule: Dictionary = systems.combat.get_wave_schedule_snapshot()
	var triggered: Array = schedule.get("triggered_wave_numbers", [])
	if active_wave == 0 and enemy_count > 0 and not triggered.is_empty():
		active_wave = int(triggered[-1])
		battle_reports.append(_make_wave_report(active_wave, "start"))
	elif active_wave > 0 and enemy_count == 0:
		battle_reports.append(_make_wave_report(active_wave, "end"))
		print("T0122 W%d end: %s" % [active_wave, JSON.stringify(battle_reports[-1])])
		last_cleared_wave = active_wave
		active_wave = 0


func _make_wave_report(wave: int, phase: String) -> Dictionary:
	var unconscious := 0
	var recruited := 0
	var hp_total := 0
	for npc_id in NPC_IDS:
		var npc: Dictionary = systems.npc.get_npc(npc_id)
		var state: Dictionary = systems.npc.get_npc_state(npc_id)
		if bool(npc.get("recruited", false)):
			recruited += 1
			hp_total += int(state.get("hp", 0))
			if bool(state.get("unconscious", false)):
				unconscious += 1
	var main_hall: Dictionary = systems.building.get_building("main_hall")
	var wall: Dictionary = systems.building.get_building("wall")
	return {
		"wave": wave,
		"phase": phase,
		"day": int(systems.game_state.current_day),
		"time": "%02d:%02d" % [int(systems.game_state.current_hour), int(systems.game_state.current_minute)],
		"enemies": int(systems.combat.get_active_enemy_count()),
		"recruited": recruited,
		"unconscious": unconscious,
		"friendly_hp": hp_total,
		"devices": systems.device.get_active_defense_targets().size(),
		"main_hall_hp": int(main_hall.get("hp", 0)),
		"wall_hp": int(wall.get("hp", 0)),
		"money": int(systems.resource.get_resource("money")),
		"grain": int(systems.resource.get_resource("grain")),
		"meal": int(systems.resource.get_resource("meal")),
		"wine": int(systems.resource.get_resource("wine")),
		"build": _build_counts()
	}


func _build_counts() -> Dictionary:
	return {
		"weapons": _equipped_weapon_count(),
		"armor": _equipped_armor_count(),
		"horses": int(systems.horse.get_horse_counts_snapshot().get("assigned", 0)),
		"ballista": _asset_count("item_wall_ballista"),
		"arrow_tower": _asset_count("item_wall_arrow_tower"),
		"wall_level": int(systems.building.get_building("wall").get("level", 0)),
		"main_hall_level": int(systems.building.get_building("main_hall").get("level", 0)),
		"blacksmith_level": int(systems.building.get_building("blacksmith").get("level", 0)),
		"workshop_level": int(systems.building.get_building("workshop").get("level", 0))
	}


func _equipped_weapon_count() -> int:
	var count := 0
	for npc_id in NPC_IDS:
		if not (systems.equipment.get_equipment_snapshot(npc_id).get("main_weapon", {}) as Dictionary).is_empty():
			count += 1
	return count


func _equipped_armor_count() -> int:
	var count := 0
	for npc_id in NPC_IDS:
		var equipment: Dictionary = systems.equipment.get_equipment_snapshot(npc_id)
		for slot_id in ["helmet", "chest", "bracers", "greaves"]:
			if not (equipment.get(slot_id, {}) as Dictionary).is_empty():
				count += 1
	return count


func _get_piety() -> float:
	if systems.piety.has_method("get_current_piety"):
		return float(systems.piety.get_current_piety())
	var snapshot: Dictionary = systems.piety.get_piety_snapshot() if systems.piety.has_method("get_piety_snapshot") else {}
	return float(snapshot.get("piety", snapshot.get("current_piety", 0.0)))


func _record_observation_once(message: String) -> void:
	if not failure_messages.has(message):
		failure_messages.append(message)


func _finalize_report() -> void:
	var final_report := {
		"scenario": scenario,
		"result": str(systems.game_state.game_result),
		"reason": str(systems.game_state.game_over_reason),
		"day": int(systems.game_state.current_day),
		"time": "%02d:%02d" % [int(systems.game_state.current_hour), int(systems.game_state.current_minute)],
		"resources": {
			"money": systems.resource.get_resource("money"),
			"grain": systems.resource.get_resource("grain"),
			"meal": systems.resource.get_resource("meal"),
			"wine": systems.resource.get_resource("wine"),
			"wood": systems.resource.get_resource("wood"),
			"stone": systems.resource.get_resource("stone"),
			"iron": systems.resource.get_resource("iron")
		},
		"build": _build_counts(),
		"transactions": transaction_totals,
		"action_completions": action_completion_counts,
		"peak_piety": peak_piety,
		"waves": battle_reports,
		"observations": failure_messages
	}
	print("T0122_FINAL %s" % JSON.stringify(final_report))
	if scenario == "focused":
		if str(systems.game_state.game_result) != "victory":
			_fail("T0122 continuous focused replay did not reach five-wave victory")
			return
		if battle_reports.size() != 10:
			_fail("T0122 focused replay did not capture five complete battles")
			return
		var fifth_start := _find_wave_report(5, "start")
		var fifth_build: Dictionary = fifth_start.get("build", {})
		if (
			int(fifth_build.get("weapons", 0)) < 7
			or int(fifth_build.get("armor", 0)) < 8
			or int(fifth_start.get("devices", 0)) < 4
			or int(fifth_build.get("horses", 0)) < 2
			or int(fifth_build.get("main_hall_level", 0)) < 3
			or int(fifth_build.get("wall_level", 0)) < 2
		):
			_fail("T0122 focused replay won without reaching the confirmed fifth-wave build")
			return
	else:
		for wave in range(1, 4):
			if _find_wave_report(wave, "end").is_empty():
				_fail("T0122 natural replay failed before clearing the three baseline waves")
				return
		if str(systems.game_state.game_result) != "failure" or str(systems.game_state.game_over_reason) != "main_hall_destroyed":
			_fail("T0122 natural replay should expose the W4/W5 strategy wall through the sole failure condition")
			return
		if _find_wave_report(4, "start").is_empty():
			_fail("T0122 natural replay reached its strategy wall before the intended fourth wave")
			return
	print("T0122 continuous workflow verification passed: scenario=%s" % scenario)
	_shutdown_test_requests()
	quit(0)


func _find_wave_report(wave: int, phase: String) -> Dictionary:
	for report in battle_reports:
		if int(report.get("wave", 0)) == wave and str(report.get("phase", "")) == phase:
			return report
	return {}


func _absolute_game_seconds() -> int:
	return _day_seconds(
		int(systems.game_state.current_day),
		int(systems.game_state.current_hour),
		int(systems.game_state.current_minute)
	)


func _day_seconds(day: int, hour: int, minute: int) -> int:
	return (day - 1) * 86400 + hour * 3600 + minute * 60


func _fail(message: String) -> void:
	push_error(message)
	_shutdown_test_requests()
	quit(1)


func _shutdown_test_requests() -> void:
	if systems.has("llm") and systems.llm != null and systems.llm.has_method("_shutdown_async_requests"):
		systems.llm.call("_shutdown_async_requests", "t0122_replay_complete")
