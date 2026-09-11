extends SceneTree

const ASSET_PATHS: PackedStringArray = [
	"res://assets/3d/synty/t0130_pilot/SK_Fantasy_MalePeasant_01.fbx",
	"res://assets/3d/synty/t0130_pilot/SK_Knights_Dark_01.fbx",
	"res://assets/3d/synty/t0130_pilot/Prop_Hammer_01.fbx",
	"res://assets/3d/synty/t0130_pilot/Prop_Sword_01.fbx",
	"res://assets/3d/synty/t0130_pilot/Prop_ShieldKnight_01.fbx",
	"res://assets/3d/kaykit/animations/rig_medium/Rig_Medium_MovementBasic.glb",
	"res://assets/3d/kaykit/animations/rig_medium/Rig_Medium_General.glb",
	"res://assets/3d/kaykit/animations/rig_medium/Rig_Medium_Simulation.glb",
	"res://assets/3d/kaykit/animations/rig_medium/Rig_Medium_Tools.glb",
	"res://assets/3d/kaykit/animations/rig_medium/Rig_Medium_CombatMelee.glb",
]


func _initialize() -> void:
	for asset_path in ASSET_PATHS:
		inspect_asset(asset_path)
	quit()


func inspect_asset(asset_path: String) -> void:
	print("\n=== %s ===" % asset_path)
	var packed := load(asset_path) as PackedScene
	if packed == null:
		push_error("Could not load %s" % asset_path)
		return
	var root := packed.instantiate()
	inspect_node(root, "")
	root.free()


func inspect_node(node: Node, indent: String) -> void:
	print("%s%s <%s>" % [indent, node.name, node.get_class()])
	if node is Skeleton3D:
		var skeleton := node as Skeleton3D
		var bones: PackedStringArray = []
		for bone_index in skeleton.get_bone_count():
			bones.append(String(skeleton.get_bone_name(bone_index)))
		print("%s  bones[%d]=%s" % [indent, bones.size(), ",".join(bones)])
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var mesh := mesh_instance.mesh
			print("%s  aabb=%s surfaces=%d skin=%s skeleton_path=%s" % [indent, mesh.get_aabb(), mesh.get_surface_count(), mesh_instance.skin, mesh_instance.skeleton])
			for surface_index in mesh.get_surface_count():
				var material := mesh.surface_get_material(surface_index)
				print("%s  material[%d]=%s" % [indent, surface_index, material])
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		print("%s  animations=%s" % [indent, ",".join(player.get_animation_list())])
	for child in node.get_children():
		inspect_node(child, indent + "  ")
