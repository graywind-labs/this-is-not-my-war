extends PanelContainer

const NPCPortraitViewport = preload("res://scripts/ui/NPCPortraitViewport.gd")

const VICTORY_GOLD := Color("#e8c875")
const VICTORY_TEXT := Color("#fff0bd")
const VICTORY_MUTED := Color("#c8b98d")
const FAILURE_SILVER := Color("#a8adb2")
const FAILURE_TEXT := Color("#d8d8d4")
const FAILURE_MUTED := Color("#8d9296")

var _title_label: Label
var _wave_label: Label
var _time_value: Label
var _ending_title_value: Label
var _theme_value: Label
var _cards: VBoxContainer
var _scroll: ScrollContainer
var _result := "failure"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_view()


func present(result: String, settlement_snapshot: Dictionary) -> void:
	_result = result
	_apply_result_theme()
	_title_label.text = "胜 利" if result == "victory" else "失 败"
	_wave_label.text = "守住 %d 波敌人" % _get_survived_wave_count(result, settlement_snapshot)
	_time_value.text = _format_time()

	var epilogue: Dictionary = (
		settlement_snapshot.get("epilogue", {})
		if settlement_snapshot.get("epilogue", {}) is Dictionary
		else {}
	)
	var epilogue_status := str(epilogue.get("status", ""))
	var pending := epilogue_status.is_empty() or epilogue_status == "pending"
	_ending_title_value.text = (
		"尚待书写" if pending else str(epilogue.get("ending_title", "未题名")).strip_edges()
	)
	_theme_value.text = (
		"战地记录整理中……"
		if pending
		else str(epilogue.get("station_coda", "余音仍留在驿站的旧墙之间。")).strip_edges()
	)
	_rebuild_npc_cards(settlement_snapshot, pending)
	visible = true
	move_to_front()


func _build_view() -> void:
	anchor_left = 1.0 / 6.0
	anchor_top = 1.0 / 6.0
	anchor_right = 5.0 / 6.0
	anchor_bottom = 5.0 / 6.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	var outer_margin := MarginContainer.new()
	outer_margin.name = "EpilogueOuterMargin"
	outer_margin.add_theme_constant_override("margin_left", 34)
	outer_margin.add_theme_constant_override("margin_top", 22)
	outer_margin.add_theme_constant_override("margin_right", 34)
	outer_margin.add_theme_constant_override("margin_bottom", 24)
	add_child(outer_margin)

	var content := VBoxContainer.new()
	content.name = "EpilogueContent"
	content.add_theme_constant_override("separation", 10)
	outer_margin.add_child(content)

	var ornament := Label.new()
	ornament.name = "EpilogueTopOrnament"
	ornament.text = "—  ✦  —"
	ornament.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ornament.add_theme_font_size_override("font_size", 18)
	content.add_child(ornament)

	_title_label = Label.new()
	_title_label.name = "GameOverTitleLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 54)
	_title_label.add_theme_constant_override("outline_size", 8)
	content.add_child(_title_label)

	_wave_label = Label.new()
	_wave_label.name = "GameOverWaveLabel"
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_size_override("font_size", 16)
	content.add_child(_wave_label)

	var divider := HSeparator.new()
	divider.name = "EpilogueHeaderDivider"
	content.add_child(divider)

	var metadata := HBoxContainer.new()
	metadata.name = "EpilogueMetadata"
	metadata.add_theme_constant_override("separation", 12)
	content.add_child(metadata)
	_time_value = _add_metadata_field(metadata, "时间", "--", 0.72, true)
	_ending_title_value = _add_metadata_field(metadata, "结局标题", "--", 0.92, false)
	_theme_value = _add_metadata_field(metadata, "主题", "--", 1.8, false)

	_scroll = ScrollContainer.new()
	_scroll.name = "EpilogueScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_scroll)

	_cards = VBoxContainer.new()
	_cards.name = "NPCEndingCards"
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 18)
	_scroll.add_child(_cards)


func _add_metadata_field(parent: HBoxContainer, caption: String, value: String, stretch: float, show_caption: bool) -> Label:
	var field := PanelContainer.new()
	field.name = "%sField" % caption
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_stretch_ratio = stretch
	field.custom_minimum_size.y = 92.0
	parent.add_child(field)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	field.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(column)
	if show_caption:
		var caption_label := Label.new()
		caption_label.name = "MetadataCaption"
		caption_label.text = caption
		caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption_label.add_theme_font_size_override("font_size", 14)
		column.add_child(caption_label)
	var value_label := Label.new()
	value_label.name = "%sValue" % caption
	value_label.text = value
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var value_font_size := 20
	if caption == "结局标题":
		value_font_size = 26
	elif caption == "主题":
		value_font_size = 21
	value_label.add_theme_font_size_override("font_size", value_font_size)
	column.add_child(value_label)
	return value_label


func _rebuild_npc_cards(settlement_snapshot: Dictionary, pending: bool) -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	var npcs: Dictionary = (
		settlement_snapshot.get("npcs", {})
		if settlement_snapshot.get("npcs", {}) is Dictionary
		else {}
	)
	var items: Array = npcs.get("items", []) if npcs.get("items", []) is Array else []
	for index in range(items.size()):
		var item: Dictionary = items[index] if items[index] is Dictionary else {}
		var card := _build_npc_card(item, pending, index)
		_cards.add_child(card)
		var portrait := card.find_child("EndingPortrait", true, false)
		if portrait != null and portrait.has_method("show_npc"):
			portrait.show_npc(str(item.get("id", "")), true)
	if items.is_empty():
		var empty := Label.new()
		empty.text = "没有留下人物记录。"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 18)
		empty.custom_minimum_size.y = 120.0
		_cards.add_child(empty)
	_scroll.scroll_vertical = 0


func _build_npc_card(item: Dictionary, pending: bool, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "NPCEndingCard_%s" % str(item.get("id", index))
	card.custom_minimum_size = Vector2(0.0, 380.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_style(index))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	margin.add_child(row)

	var portrait_column := CenterContainer.new()
	portrait_column.name = "EndingPortraitColumn"
	portrait_column.custom_minimum_size.x = 280.0
	portrait_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_column.size_flags_stretch_ratio = 1.0
	row.add_child(portrait_column)
	var portrait := NPCPortraitViewport.new()
	portrait.name = "EndingPortrait"
	portrait.custom_minimum_size = Vector2(190.0, 350.0)
	portrait.add_theme_stylebox_override("panel", _make_portrait_style())
	portrait_column.add_child(portrait)

	var story_column := VBoxContainer.new()
	story_column.name = "EndingStory"
	story_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_column.size_flags_stretch_ratio = 2.0
	story_column.add_theme_constant_override("separation", 9)
	row.add_child(story_column)

	var name_label := Label.new()
	name_label.name = "NPCNameLabel"
	var personal_title := str(item.get("ending_title", "")).strip_edges()
	name_label.text = str(item.get("name", item.get("id", "")))
	if not pending and not personal_title.is_empty():
		name_label.text += " · 《%s》" % personal_title
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", _accent_color())
	story_column.add_child(name_label)

	var status_row := HBoxContainer.new()
	status_row.name = "NPCFinalStatus"
	status_row.add_theme_constant_override("separation", 8)
	story_column.add_child(status_row)
	status_row.add_child(_make_status_chip(_get_escape_status_text(item)))
	status_row.add_child(_make_status_chip("已入伍" if bool(item.get("recruited", false)) else "未入伍"))

	var story := Label.new()
	story.name = "NPCFateStory"
	story.text = "战地记录整理中……" if pending else str(item.get("fate_summary", "此后的故事没有留下记录。"))
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	story.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story.add_theme_font_size_override("font_size", 17)
	story.add_theme_color_override("font_color", _body_color())
	story.add_theme_constant_override("line_spacing", 6)
	story_column.add_child(story)
	return card


func _make_status_chip(text: String) -> Label:
	var chip := Label.new()
	chip.text = "  %s  " % text
	chip.add_theme_font_size_override("font_size", 13)
	chip.add_theme_color_override("font_color", _muted_color())
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.11, 0.58) if _result == "victory" else Color(0.08, 0.085, 0.09, 0.72)
	style.border_color = Color(_accent_color(), 0.46)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	chip.add_theme_stylebox_override("normal", style)
	return chip


func _get_escape_status_text(item: Dictionary) -> String:
	if not bool(item.get("escaped", false)):
		return "未逃离驿站"
	match str(item.get("escape_circumstance", "")):
		"before_fall_voluntary":
			return "失守前主动逃离"
		"after_fall_forced":
			return "失守后被迫撤离"
		_:
			return "已逃离驿站"


func _apply_result_theme() -> void:
	var style := StyleBoxFlat.new()
	if _result == "victory":
		style.bg_color = Color("#17130c")
		style.border_color = VICTORY_GOLD
	else:
		style.bg_color = Color("#111316")
		style.border_color = Color("#666b70")
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.82)
	style.shadow_size = 18
	add_theme_stylebox_override("panel", style)
	_title_label.add_theme_color_override("font_color", _accent_color())
	_title_label.add_theme_color_override("font_outline_color", Color(0.03, 0.025, 0.02, 0.95))
	_wave_label.add_theme_color_override("font_color", _muted_color())
	_time_value.add_theme_color_override("font_color", _body_color())
	_ending_title_value.add_theme_color_override("font_color", _accent_color())
	_theme_value.add_theme_color_override("font_color", _body_color())
	var ornament := find_child("EpilogueTopOrnament", true, false) as Label
	if ornament != null:
		ornament.add_theme_color_override("font_color", Color(_accent_color(), 0.8))
	for field_name in ["时间Field", "结局标题Field", "主题Field"]:
		var field := find_child(field_name, true, false) as PanelContainer
		if field != null:
			field.add_theme_stylebox_override("panel", _make_metadata_style())
	for caption in find_children("MetadataCaption", "Label", true, false):
		(caption as Label).add_theme_color_override("font_color", _muted_color())


func _make_card_style(index: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if _result == "victory":
		style.bg_color = Color("#211b10") if index % 2 == 0 else Color("#1c180f")
		style.border_color = Color(VICTORY_GOLD, 0.48)
	else:
		style.bg_color = Color("#1a1c1f") if index % 2 == 0 else Color("#16181b")
		style.border_color = Color(FAILURE_SILVER, 0.32)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style


func _make_metadata_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#241d10") if _result == "victory" else Color("#1b1d20")
	style.border_color = Color(_accent_color(), 0.34)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style


func _make_portrait_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0e0c08") if _result == "victory" else Color("#0c0d0f")
	style.border_color = Color(_accent_color(), 0.58)
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	return style


func _accent_color() -> Color:
	return VICTORY_TEXT if _result == "victory" else FAILURE_SILVER


func _body_color() -> Color:
	return VICTORY_TEXT if _result == "victory" else FAILURE_TEXT


func _muted_color() -> Color:
	return VICTORY_MUTED if _result == "victory" else FAILURE_MUTED


func _format_time() -> String:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return "--"
	return "第 %d 天  %02d:%02d:%02d" % [
		int(game_state.get("game_over_day")),
		int(game_state.get("game_over_hour")),
		int(game_state.get("game_over_minute")),
		int(game_state.get("game_over_second"))
	]


func _get_survived_wave_count(result: String, settlement_snapshot: Dictionary) -> int:
	if result == "victory":
		return maxi(0, int(settlement_snapshot.get("wave_number", 5)))
	var combat_system := get_node_or_null("/root/Main/Systems/CombatSystem")
	if combat_system == null or not combat_system.has_method("get_wave_schedule_snapshot"):
		return 0
	var schedule: Dictionary = combat_system.get_wave_schedule_snapshot()
	var triggered: Array = schedule.get("triggered_wave_numbers", []) if schedule.get("triggered_wave_numbers", []) is Array else []
	var survived := triggered.size()
	if int(schedule.get("active_enemy_count", 0)) > 0:
		survived -= 1
	return maxi(0, survived)


func debug_get_layout_snapshot() -> Dictionary:
	return {
		"result": _result,
		"theme_variant": "victory_gold" if _result == "victory" else "failure_gray",
		"title": _title_label.text if _title_label != null else "",
		"wave_subtitle": _wave_label.text if _wave_label != null else "",
		"metadata_values": ["时间", "结局标题", "主题"],
		"visible_metadata_captions": ["时间"],
		"viewport_fraction": Vector2(2.0 / 3.0, 2.0 / 3.0),
		"card_count": _cards.get_child_count() if _cards != null else 0,
		"scroll_vertical_enabled": _scroll != null,
		"card_portrait_ratio": "1:2",
		"shows_reason": false,
		"shows_resources": false,
		"shows_npc_heading": false
	}
