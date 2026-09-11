extends RefCounted

const NPC_ANCHOR_HEIGHT := 4.25
const ENEMY_ANCHOR_HEIGHT := 2.95
const HORSE_ANCHOR_HEIGHT := 2.75
const BUILDING_ANCHOR_HEIGHT := 3.0
const DEFENSE_DEVICE_ANCHOR_HEIGHT := 2.35
const MERCHANT_ANCHOR_HEIGHT := 0.0
const RESOURCE_ICON_PATHS := {
	"money": "res://assets/ui/resource_icons/money.svg",
	"grain": "res://assets/ui/resource_icons/grain.svg",
	"meal": "res://assets/ui/resource_icons/meal.svg",
	"wine": "res://assets/ui/resource_icons/wine.svg",
	"wood": "res://assets/ui/resource_icons/wood.svg",
	"stone": "res://assets/ui/resource_icons/stone.svg",
	"iron": "res://assets/ui/resource_icons/iron.svg"
}


static func make_resource_entry(
	resource_system: Node,
	resource_id: String,
	amount: int,
	color_role: String
) -> Dictionary:
	if resource_id.is_empty() or amount == 0:
		return {}
	var display_name := resource_id
	if resource_system != null and resource_system.has_method("get_resource_name"):
		display_name = str(resource_system.get_resource_name(resource_id))
	return {
		"kind": "resource",
		"id": resource_id,
		"display_name": display_name,
		"amount": amount,
		"color_role": color_role,
		"icon_path": str(RESOURCE_ICON_PATHS.get(resource_id, ""))
	}


static func make_value_entry(
	display_name: String,
	amount: Variant,
	color_role: String,
	suffix: String = ""
) -> Dictionary:
	if display_name.is_empty() or is_zero_approx(float(amount)):
		return {}
	return {
		"kind": "value",
		"display_name": display_name,
		"amount": amount,
		"color_role": color_role,
		"suffix": suffix
	}


static func make_number_entry(amount: Variant, color_role: String) -> Dictionary:
	if is_zero_approx(float(amount)):
		return {}
	return {
		"kind": "number",
		"display_name": "",
		"amount": amount,
		"color_role": color_role
	}


static func make_resource_transaction_entries(
	resource_system: Node,
	input_resources: Dictionary,
	output_resources: Dictionary
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for raw_resource_id in input_resources.keys():
		var entry := make_resource_entry(
			resource_system,
			str(raw_resource_id),
			-absi(int(input_resources[raw_resource_id])),
			"consume"
		)
		if not entry.is_empty():
			entries.append(entry)
	for raw_resource_id in output_resources.keys():
		var entry := make_resource_entry(
			resource_system,
			str(raw_resource_id),
			absi(int(output_resources[raw_resource_id])),
			"gain"
		)
		if not entry.is_empty():
			entries.append(entry)
	return entries


static func append_growth_entries(entries: Array[Dictionary], growth_result: Dictionary) -> void:
	if growth_result.is_empty():
		return
	var growth_results: Array[Dictionary] = [growth_result]
	append_growth_batch_entry(entries, growth_results)


static func append_growth_batch_entry(
	entries: Array[Dictionary],
	growth_results: Array[Dictionary]
) -> void:
	var components: Array[Dictionary] = []
	var text_parts: Array[String] = []
	var experience_gained := 0
	var skill_points_gained := 0
	for growth_result in growth_results:
		if growth_result.is_empty():
			continue
		_append_growth_component(
			components,
			text_parts,
			str(growth_result.get("skill_name", "")),
			int(growth_result.get("amount", 0))
		)
		experience_gained += int(growth_result.get("experience_gained", 0))
		skill_points_gained += int(growth_result.get("skill_points_gained", 0))
	_append_growth_component(
		components,
		text_parts,
		"经验",
		experience_gained
	)
	_append_growth_component(
		components,
		text_parts,
		"技能点",
		skill_points_gained
	)
	if components.is_empty():
		return
	entries.append({
		"kind": "growth_summary",
		"display_name": str(components[0].get("display_name", "成长")),
		"amount": components[0].get("amount", 0),
		"color_role": "growth",
		"text_override": "　".join(text_parts),
		"components": components
	})


static func _append_growth_component(
	components: Array[Dictionary],
	text_parts: Array[String],
	display_name: String,
	amount: int
) -> void:
	if display_name.is_empty() or amount == 0:
		return
	components.append({
		"display_name": display_name,
		"amount": amount,
		"color_role": "growth"
	})
	text_parts.append("%s %s%d" % [display_name, "+" if amount > 0 else "", amount])


static func emit_npc(
	context: Node,
	npc_id: String,
	channel: String,
	entries: Array[Dictionary],
	replace_channel: bool = false
) -> void:
	var fallback_position: Variant = null
	if context != null:
		var npc_system := context.get_node_or_null("/root/Main/Systems/NPCSystem")
		if npc_system != null and npc_system.has_method("get_npc_world_position"):
			fallback_position = npc_system.get_npc_world_position(npc_id)
	emit_anchor(
		context,
		"npc",
		npc_id,
		NPC_ANCHOR_HEIGHT,
		channel,
		entries,
		replace_channel,
		fallback_position
	)


static func emit_hp_change(
	context: Node,
	anchor_type: String,
	anchor_id: String,
	hp_before: Variant,
	hp_after: Variant,
	fallback_world_position: Variant = null,
	prefer_fallback_position: bool = false,
	anchor_height: float = -1.0
) -> void:
	var actual_delta := float(hp_after) - float(hp_before)
	if is_zero_approx(actual_delta):
		return
	var is_damage := actual_delta < 0.0
	var entry := make_number_entry(actual_delta, "damage" if is_damage else "heal")
	if entry.is_empty():
		return
	emit_anchor(
		context,
		anchor_type,
		anchor_id,
		_get_default_anchor_height(anchor_type) if anchor_height < 0.0 else anchor_height,
		"damage" if is_damage else "healing",
		[entry],
		is_damage,
		fallback_world_position,
		prefer_fallback_position,
		not is_damage
	)


static func emit_anchor(
	context: Node,
	anchor_type: String,
	anchor_id: String,
	anchor_height: float,
	channel: String,
	entries: Array[Dictionary],
	replace_channel: bool = false,
	fallback_world_position: Variant = null,
	prefer_fallback_position: bool = false,
	merge_channel: bool = false
) -> void:
	if context == null or anchor_type.is_empty() or anchor_id.is_empty() or entries.is_empty():
		return
	var event_bus := context.get_node_or_null("/root/EventBus")
	if event_bus == null or not event_bus.has_signal("world_feedback_requested"):
		return
	event_bus.world_feedback_requested.emit({
		"anchor_type": anchor_type,
		"anchor_id": anchor_id,
		"anchor_height": anchor_height,
		"fallback_world_position": fallback_world_position,
		"prefer_fallback_position": prefer_fallback_position,
		"channel": channel,
		"replace_channel": replace_channel,
		"merge_channel": merge_channel,
		"entries": entries.duplicate(true)
	})


static func find_world_position(values: Dictionary) -> Variant:
	for key in ["hit_world_position", "impact_world_position", "contact_world_position", "collision_position", "world_position", "target_position"]:
		var position: Variant = values.get(key, null)
		if position is Vector3:
			return position
		if position is Dictionary and (position as Dictionary).has("x") and (position as Dictionary).has("z"):
			return Vector3(
				float((position as Dictionary).get("x", 0.0)),
				float((position as Dictionary).get("y", 0.0)),
				float((position as Dictionary).get("z", 0.0))
			)
	return null


static func _get_default_anchor_height(anchor_type: String) -> float:
	match anchor_type:
		"npc":
			return NPC_ANCHOR_HEIGHT
		"enemy":
			return ENEMY_ANCHOR_HEIGHT
		"horse":
			return HORSE_ANCHOR_HEIGHT
		"building":
			return BUILDING_ANCHOR_HEIGHT
		"defense_device":
			return DEFENSE_DEVICE_ANCHOR_HEIGHT
		"merchant":
			return MERCHANT_ANCHOR_HEIGHT
	return 2.5
