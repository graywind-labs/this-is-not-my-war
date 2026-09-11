class_name MerchantWagon
extends ActorMotionBody

const ARRIVAL_REQUEST := "merchant_arrival"
const DEPARTURE_REQUEST := "merchant_departure"

@onready var visual_root: Node3D = $VisualRoot
@onready var trade_bubble: Node3D = $TradeBubble

var driver_art: Node3D
var _last_planar_direction := Vector3(0.0, 0.0, -1.0)


func _ready() -> void:
	super._ready()
	configure_profile("merchant_wagon")
	trade_bubble.visible = false
	var hotspot := trade_bubble.get_node_or_null("TradeBubbleArea") as Area3D
	if hotspot != null:
		hotspot.set_meta("merchant_hotspot", true)
		hotspot.input_ray_pickable = false
	if visual_root.has_method("get_driver_art"):
		driver_art = visual_root.call("get_driver_art") as Node3D
	if driver_art != null:
		if driver_art.has_method("debug_force_animation_state"):
			driver_art.call("debug_force_animation_state", "vehicle_seated")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if planar_velocity.length_squared() > 0.02:
		_last_planar_direction = planar_velocity.normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-_last_planar_direction.x, -_last_planar_direction.z), clampf(delta * 4.0, 0.0, 1.0))
		_set_travel_animation(true, planar_velocity.length(), delta)
	else:
		_set_travel_animation(false, 0.0, delta)


func set_trade_available(available: bool) -> void:
	trade_bubble.visible = available
	var hotspot := trade_bubble.get_node_or_null("TradeBubbleArea") as Area3D
	if hotspot != null:
		hotspot.input_ray_pickable = available
		var shape := hotspot.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape != null:
			shape.disabled = not available


func get_wagon_snapshot() -> Dictionary:
	var snapshot := debug_get_motion_snapshot()
	snapshot["trade_bubble_visible"] = trade_bubble.visible
	if visual_root.has_method("debug_get_art_snapshot"):
		snapshot.merge(visual_root.call("debug_get_art_snapshot") as Dictionary, true)
	snapshot["authority_role"] = "physical_presence_and_presentation_only"
	return snapshot


func get_world_feedback_anchor_position() -> Vector3:
	if (
		is_instance_valid(driver_art)
		and driver_art.has_method("has_attachment_socket")
		and bool(driver_art.call("has_attachment_socket", "Head"))
		and driver_art.has_method("get_attachment_global_position")
	):
		return (driver_art.call("get_attachment_global_position", "Head") as Vector3) + Vector3.UP * 0.55
	return trade_bubble.global_position


func _set_travel_animation(moving: bool, speed: float, delta: float) -> void:
	if visual_root.has_method("set_travel_state"):
		visual_root.call("set_travel_state", moving, speed, delta)
