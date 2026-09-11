class_name MountedPresentationReference
extends RefCounted


# NPCDevLab is the visual acceptance surface for these production values. Main
# and the lab must both consume this reference instead of maintaining copies.
const HORSE_SCENE_PATH := "res://assets/3d/quaternius/animals/merchant_horse.glb"
const VISIBLE_FORWARD_LOCAL := Vector3.BACK

const FRIENDLY_HORSE_ROOT_POSITION := Vector3(0.0, 0.13, 0.0)
const FRIENDLY_HORSE_SCALE := Vector3(0.50, 0.39, 0.46)
const FRIENDLY_RIDER_ROOT_OFFSET := Vector3(0.0, 1.30, 0.35)


static func get_friendly_rider_root_offset(visible_forward: Vector3) -> Vector3:
	return orient_local_offset_to_visible_forward(FRIENDLY_RIDER_ROOT_OFFSET, visible_forward)


static func orient_local_offset_to_visible_forward(local_offset: Vector3, visible_forward: Vector3) -> Vector3:
	var flat_forward := Vector3(visible_forward.x, 0.0, visible_forward.z)
	if flat_forward.length_squared() <= 0.0001:
		flat_forward = VISIBLE_FORWARD_LOCAL
	flat_forward = flat_forward.normalized()
	var flat_right := Vector3.UP.cross(flat_forward).normalized()
	return (
		flat_right * local_offset.x
		+ Vector3.UP * local_offset.y
		+ flat_forward * local_offset.z
	)

# EnemyMountedArtView is itself shared by Main and NPCDevLab. Keep its accepted
# proportions explicit here so future edits cannot silently fork either scene.
const ENEMY_HORSE_LOCAL_POSITION := Vector3(0.0, 0.025, 0.0)
const ENEMY_HORSE_SCALE := Vector3(0.46, 0.36, 0.42)
