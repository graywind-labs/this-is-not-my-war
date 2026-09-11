class_name HorseAppearance
extends RefCounted


const DEFAULT_COAT_COLOR := Color("#9B6846")
const BASE_ALBEDO_META := "horse_appearance_base_albedo"


static func parse_coat_color(raw_color: Variant) -> Color:
	if raw_color is Color:
		return raw_color
	var color_text := str(raw_color).strip_edges()
	return Color.from_string(color_text, DEFAULT_COAT_COLOR) if Color.html_is_valid(color_text) else DEFAULT_COAT_COLOR


static func apply_coat_color(model: Node3D, raw_color: Variant) -> int:
	if model == null:
		return 0
	var tint := parse_coat_color(raw_color)
	var tinted_surface_count := 0
	for raw_mesh in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := raw_mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source := mesh_instance.get_active_material(surface_index)
			if not source is BaseMaterial3D:
				continue
			var base_color := (source as BaseMaterial3D).albedo_color
			if source.has_meta(BASE_ALBEDO_META):
				var stored: Variant = source.get_meta(BASE_ALBEDO_META)
				if stored is Color:
					base_color = stored
			var copy := (source as BaseMaterial3D).duplicate() as BaseMaterial3D
			copy.resource_local_to_scene = true
			copy.set_meta(BASE_ALBEDO_META, base_color)
			var luminance := base_color.r * 0.2126 + base_color.g * 0.7152 + base_color.b * 0.0722
			var shade := clampf(0.42 + luminance * 0.9, 0.18, 1.15)
			copy.albedo_color = Color(tint.r * shade, tint.g * shade, tint.b * shade, base_color.a)
			mesh_instance.set_surface_override_material(surface_index, copy)
			tinted_surface_count += 1
	return tinted_surface_count
