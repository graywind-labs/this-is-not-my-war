class_name SyntyKnightArmorExtractor
extends RefCounted


const SOURCE_SCENE_PATH := "res://assets/3d/synty/t0130_pilot/SK_Knights_Dark_01.fbx"
const HELMET_CLEARANCE_SCALE := Vector3(1.05, 1.04, 1.05)
const UNDER_ARMOR_INSET := 0.025
const ARM_BONES := {
	"clavicle_l": true, "upperarm_l": true, "lowerarm_l": true, "hand_l": true,
	"clavicle_r": true, "upperarm_r": true, "lowerarm_r": true, "hand_r": true,
}
const LEG_BONES := {
	"thigh_l": true, "calf_l": true, "foot_l": true, "ball_l": true, "toes_l": true,
	"thigh_r": true, "calf_r": true, "foot_r": true, "ball_r": true, "toes_r": true,
}
const TORSO_BONES := {
	"pelvis": true, "spine_01": true, "spine_02": true, "spine_03": true, "neck_01": true,
}
const HEAD_BONES := {"head": true}
const TARGET_ARM_BONES := {
	"LeftShoulder": true, "LeftUpperArm": true, "LeftLowerArm": true, "LeftHand": true,
	"RightShoulder": true, "RightUpperArm": true, "RightLowerArm": true, "RightHand": true,
}
const TARGET_LEG_BONES := {
	"LeftUpperLeg": true, "LeftLowerLeg": true, "LeftFoot": true, "LeftToes": true,
	"RightUpperLeg": true, "RightLowerLeg": true, "RightFoot": true, "RightToes": true,
}
const TARGET_TORSO_BONES := {
	"Hips": true, "Spine": true, "Chest": true, "UpperChest": true, "Neck": true,
}
const TARGET_HEAD_BONES := {"Head": true, "Neck": true}


static func extract_slot_meshes(source_mesh: ArrayMesh, source_skeleton: Skeleton3D) -> Dictionary:
	if source_mesh == null or source_skeleton == null or source_mesh.get_surface_count() < 1:
		return {}
	var arrays := source_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if vertices.is_empty() or indices.size() < 3 or bones.is_empty() or weights.is_empty():
		return {}
	var component_data := _build_component_data(vertices, indices)
	var main_root := int(component_data.get("main_root", -1))
	var helmet_root := int(component_data.get("helmet_root", -1))
	var triangle_roots: PackedInt32Array = component_data.get("triangle_roots", PackedInt32Array())
	var slot_indices := {
		"helmet": PackedInt32Array(),
		"chest": PackedInt32Array(),
		"bracers": PackedInt32Array(),
		"greaves": PackedInt32Array(),
	}
	var influences_per_vertex := maxi(1, bones.size() / vertices.size())
	for triangle_index in indices.size() / 3:
		var triangle_start := triangle_index * 3
		var component_root := triangle_roots[triangle_index]
		var target_slot := ""
		if component_root == helmet_root:
			target_slot = "helmet"
		elif component_root == main_root:
			var centroid := (
				vertices[indices[triangle_start]]
				+ vertices[indices[triangle_start + 1]]
				+ vertices[indices[triangle_start + 2]]
			) / 3.0
			var scores := _triangle_region_scores(
				indices,
				triangle_start,
				bones,
				weights,
				influences_per_vertex,
				source_skeleton
			)
			var arm_score := float(scores.get("arm", 0.0))
			var leg_score := float(scores.get("leg", 0.0))
			var torso_score := float(scores.get("torso", 0.0))
			var head_score := float(scores.get("head", 0.0))
			# Include hips, thighs, knees, shins and armored boots. Low pelvis-weighted
			# skirt triangles belong to the lower-body set rather than the breastplate.
			if (leg_score >= 0.26 or centroid.y < 0.80) and centroid.y < 1.02:
				target_slot = "greaves"
			# Several central cuirass triangles are weighted to the clavicles in the
			# source knight. Spatially claim the body core before the arm rule so a
			# chest-only loadout remains a complete chest instead of relying on the
			# bracer slot to fill it back in.
			elif (
				centroid.y >= 0.66
				and centroid.y <= 1.43
				and absf(centroid.x) <= 0.62
				and head_score < 0.15
				and (absf(centroid.x) <= 0.38 or torso_score >= 0.45)
			):
				target_slot = "chest"
			# The knight's articulated shoulder plates and gauntlets share the arm
			# chains. Keep the remaining shoulder-to-hand assembly as one skinned slot.
			elif arm_score >= 0.34 and centroid.y >= 0.82:
				target_slot = "bracers"
		if target_slot.is_empty():
			continue
		var filtered: PackedInt32Array = slot_indices[target_slot]
		filtered.append(indices[triangle_start])
		filtered.append(indices[triangle_start + 1])
		filtered.append(indices[triangle_start + 2])
		slot_indices[target_slot] = filtered
	var result := {}
	for slot in slot_indices:
		var filtered_indices: PackedInt32Array = slot_indices[slot]
		if filtered_indices.is_empty():
			continue
		var slot_arrays: Array = arrays.duplicate(true)
		slot_arrays[Mesh.ARRAY_INDEX] = filtered_indices
		if slot == "helmet":
			slot_arrays[Mesh.ARRAY_VERTEX] = _inflate_helmet_vertices(vertices, filtered_indices)
		var extracted := ArrayMesh.new()
		extracted.resource_name = "SyntyKnight%sArmor" % str(slot).to_pascal_case()
		extracted.add_surface_from_arrays(source_mesh.surface_get_primitive_type(0), slot_arrays)
		extracted.surface_set_material(0, source_mesh.surface_get_material(0))
		extracted.surface_set_name(0, "SyntyKnight%s" % str(slot).to_pascal_case())
		result[slot] = extracted
	return result


static func duplicate_remapped_skin(source_skin: Skin, bone_map: Dictionary) -> Skin:
	if source_skin == null:
		return null
	var remapped := source_skin.duplicate(true) as Skin
	for bind_index in remapped.get_bind_count():
		var source_name := str(remapped.get_bind_name(bind_index))
		if bone_map.has(source_name):
			remapped.set_bind_name(bind_index, StringName(str(bone_map[source_name])))
	return remapped


static func build_character_mesh_with_armor_occlusion(
	source_mesh: ArrayMesh,
	target_skeleton: Skeleton3D,
	visible_slots: Array
) -> ArrayMesh:
	if source_mesh == null or target_skeleton == null or visible_slots.is_empty():
		return source_mesh
	var slot_set := {}
	for raw_slot in visible_slots:
		slot_set[str(raw_slot)] = true
	var rebuilt := ArrayMesh.new()
	var inset_any := false
	var removed_any := false
	for surface_index in source_mesh.get_surface_count():
		var arrays := source_mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty() or indices.size() < 3 or bones.is_empty() or weights.is_empty():
			rebuilt.add_surface_from_arrays(source_mesh.surface_get_primitive_type(surface_index), arrays)
			rebuilt.surface_set_material(rebuilt.get_surface_count() - 1, source_mesh.surface_get_material(surface_index))
			continue
		var influences_per_vertex := maxi(1, bones.size() / vertices.size())
		var inset_vertices := {}
		var filtered_indices := PackedInt32Array()
		for triangle_start in range(0, indices.size(), 3):
			var centroid := (
				vertices[indices[triangle_start]]
				+ vertices[indices[triangle_start + 1]]
				+ vertices[indices[triangle_start + 2]]
			) / 3.0
			var scores := _triangle_target_region_scores(
				indices,
				triangle_start,
				bones,
				weights,
				influences_per_vertex,
				 target_skeleton
			)
			if slot_set.has("helmet"):
				var max_y := maxf(
					vertices[indices[triangle_start]].y,
					maxf(vertices[indices[triangle_start + 1]].y, vertices[indices[triangle_start + 2]].y)
				)
				var face_window := (
					centroid.z >= 0.16
					and centroid.y >= 1.42
					and centroid.y <= 1.62
					and absf(centroid.x) <= 0.30
				)
				var remove_headwear := (
					max_y >= 1.66
					or (not face_window and centroid.y >= 1.30)
				)
				if remove_headwear:
					removed_any = true
					continue
			var should_inset := false
			if slot_set.has("hide_lower_robe"):
				var remove_lower_robe := (
					centroid.y >= 0.02
					and centroid.y <= 0.96
					and absf(centroid.x) <= 0.72
					and float(scores.get("arm", 0.0)) < 0.20
				)
				if remove_lower_robe:
					removed_any = true
					continue
			# Do not delete triangles beneath armor: authored clothes and exposed body
			# share one skinned surface, so deletion also removes the abdomen, upper arm
			# or neck. Pull only the covered layer slightly inward. It keeps a complete
			# body-shaped liner in gaps while preventing coplanar armor flicker.
			if slot_set.has("bracers"):
				should_inset = (
					float(scores.get("arm", 0.0)) >= 0.28
					and centroid.y >= 0.78
					and absf(centroid.x) >= 0.30
				)
			if not should_inset and slot_set.has("chest"):
				should_inset = (
					centroid.y >= 0.66
					and centroid.y <= 1.20
					and absf(centroid.x) <= 0.62
					and (float(scores.get("torso", 0.0)) >= 0.10 or absf(centroid.x) <= 0.48)
				)
			if not should_inset and slot_set.has("greaves"):
				should_inset = (
					(float(scores.get("leg", 0.0)) >= 0.24 or centroid.y < 0.80)
					and centroid.y < 1.03
				)
			if should_inset:
				for corner in 3:
					inset_vertices[indices[triangle_start + corner]] = true
			filtered_indices.append(indices[triangle_start])
			filtered_indices.append(indices[triangle_start + 1])
			filtered_indices.append(indices[triangle_start + 2])
		arrays[Mesh.ARRAY_INDEX] = filtered_indices
		if not inset_vertices.is_empty() and normals.size() == vertices.size():
			var adjusted_vertices := vertices.duplicate()
			for raw_vertex_index in inset_vertices:
				var vertex_index := int(raw_vertex_index)
				var normal := normals[vertex_index]
				if not normal.is_zero_approx():
					adjusted_vertices[vertex_index] -= normal.normalized() * UNDER_ARMOR_INSET
			arrays[Mesh.ARRAY_VERTEX] = adjusted_vertices
			inset_any = true
		rebuilt.add_surface_from_arrays(source_mesh.surface_get_primitive_type(surface_index), arrays)
		rebuilt.surface_set_material(rebuilt.get_surface_count() - 1, source_mesh.surface_get_material(surface_index))
		rebuilt.surface_set_name(rebuilt.get_surface_count() - 1, source_mesh.surface_get_name(surface_index))
	return rebuilt if inset_any or removed_any else source_mesh


static func _build_component_data(vertices: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	var parent: Array[int] = []
	parent.resize(vertices.size())
	for vertex_index in vertices.size():
		parent[vertex_index] = vertex_index
	for triangle_start in range(0, indices.size(), 3):
		_union(parent, indices[triangle_start], indices[triangle_start + 1])
		_union(parent, indices[triangle_start], indices[triangle_start + 2])
	var coincident := {}
	for vertex_index in vertices.size():
		var vertex := vertices[vertex_index]
		var key := Vector3i(
			roundi(vertex.x * 10000.0),
			roundi(vertex.y * 10000.0),
			roundi(vertex.z * 10000.0)
		)
		if coincident.has(key):
			_union(parent, vertex_index, int(coincident[key]))
		else:
			coincident[key] = vertex_index
	var triangle_roots := PackedInt32Array()
	var component_stats := {}
	for triangle_start in range(0, indices.size(), 3):
		var root_index := _find(parent, indices[triangle_start])
		triangle_roots.append(root_index)
		var stats: Dictionary = component_stats.get(root_index, {
			"triangles": 0,
			"min_y": INF,
			"max_y": -INF,
		})
		stats["triangles"] = int(stats["triangles"]) + 1
		for corner in 3:
			var y := vertices[indices[triangle_start + corner]].y
			stats["min_y"] = minf(float(stats["min_y"]), y)
			stats["max_y"] = maxf(float(stats["max_y"]), y)
		component_stats[root_index] = stats
	var ranked_roots: Array = component_stats.keys()
	ranked_roots.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((component_stats[a] as Dictionary)["triangles"]) > int((component_stats[b] as Dictionary)["triangles"])
	)
	var main_root := int(ranked_roots[0]) if not ranked_roots.is_empty() else -1
	var helmet_root := -1
	for root_value in ranked_roots:
		var root_index := int(root_value)
		if root_index == main_root:
			continue
		var stats := component_stats[root_index] as Dictionary
		if int(stats["triangles"]) >= 100 and float(stats["min_y"]) > 1.0:
			helmet_root = root_index
			break
	return {
		"main_root": main_root,
		"helmet_root": helmet_root,
		"triangle_roots": triangle_roots,
	}


static func _triangle_region_scores(
	indices: PackedInt32Array,
	triangle_start: int,
	bones: PackedInt32Array,
	weights: PackedFloat32Array,
	influences_per_vertex: int,
	skeleton: Skeleton3D
) -> Dictionary:
	var scores := {"arm": 0.0, "leg": 0.0, "torso": 0.0, "head": 0.0}
	for corner in 3:
		var vertex_index := indices[triangle_start + corner]
		for influence in influences_per_vertex:
			var packed_index := vertex_index * influences_per_vertex + influence
			if packed_index >= weights.size() or weights[packed_index] <= 0.0001:
				continue
			var bone_index := bones[packed_index]
			if bone_index < 0 or bone_index >= skeleton.get_bone_count():
				continue
			var bone_name := str(skeleton.get_bone_name(bone_index))
			var weight := weights[packed_index] / 3.0
			if ARM_BONES.has(bone_name):
				scores["arm"] = float(scores["arm"]) + weight
			elif LEG_BONES.has(bone_name):
				scores["leg"] = float(scores["leg"]) + weight
			elif TORSO_BONES.has(bone_name):
				scores["torso"] = float(scores["torso"]) + weight
			elif HEAD_BONES.has(bone_name):
				scores["head"] = float(scores["head"]) + weight
	return scores


static func _triangle_target_region_scores(
	indices: PackedInt32Array,
	triangle_start: int,
	bones: PackedInt32Array,
	weights: PackedFloat32Array,
	influences_per_vertex: int,
	skeleton: Skeleton3D
) -> Dictionary:
	var scores := {"arm": 0.0, "leg": 0.0, "torso": 0.0, "head": 0.0}
	for corner in 3:
		var vertex_index := indices[triangle_start + corner]
		for influence in influences_per_vertex:
			var packed_index := vertex_index * influences_per_vertex + influence
			if packed_index >= weights.size() or weights[packed_index] <= 0.0001:
				continue
			var bone_index := bones[packed_index]
			if bone_index < 0 or bone_index >= skeleton.get_bone_count():
				continue
			var bone_name := str(skeleton.get_bone_name(bone_index))
			var weight := weights[packed_index] / 3.0
			if TARGET_ARM_BONES.has(bone_name):
				scores["arm"] = float(scores["arm"]) + weight
			elif TARGET_LEG_BONES.has(bone_name):
				scores["leg"] = float(scores["leg"]) + weight
			elif TARGET_TORSO_BONES.has(bone_name):
				scores["torso"] = float(scores["torso"]) + weight
			if TARGET_HEAD_BONES.has(bone_name):
				scores["head"] = float(scores["head"]) + weight
	return scores


static func _inflate_helmet_vertices(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var inflated := vertices.duplicate()
	var used := {}
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	for vertex_index in indices:
		if used.has(vertex_index):
			continue
		used[vertex_index] = true
		min_v = min_v.min(vertices[vertex_index])
		max_v = max_v.max(vertices[vertex_index])
	var center := (min_v + max_v) * 0.5
	for raw_vertex_index in used:
		var vertex_index := int(raw_vertex_index)
		var delta := vertices[vertex_index] - center
		inflated[vertex_index] = center + delta * HELMET_CLEARANCE_SCALE
	return inflated


static func _find(parent: Array[int], value: int) -> int:
	if parent[value] != value:
		parent[value] = _find(parent, parent[value])
	return parent[value]


static func _union(parent: Array[int], a: int, b: int) -> void:
	var root_a := _find(parent, a)
	var root_b := _find(parent, b)
	if root_a != root_b:
		parent[root_b] = root_a
