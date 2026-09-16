class_name DoorPassageQueueArea
extends Area3D


const ACTOR_BODY_COLLISION_MASK := 2

var queue_id := ""
var building_id := ""
var _token_count := 8
var _range_size := Vector3(2.8, 2.8, 3.0)
var _release_grace_seconds := 0.12
var _entries: Array[Dictionary] = []
var _pending_release_seconds: Dictionary = {}
var _arrival_sequence := 0


func configure(next_queue_id: String, next_building_id: String, config: Dictionary) -> void:
	queue_id = next_queue_id
	building_id = next_building_id
	_token_count = maxi(1, int(config.get("token_count", 8)))
	_range_size = Vector3(
		maxf(0.1, float(config.get("range_width", 2.6))),
		maxf(0.1, float(config.get("range_height", 2.8))),
		maxf(0.1, float(config.get("range_depth", 3.0)))
	)
	_release_grace_seconds = maxf(0.0, float(config.get("release_grace_seconds", 0.12)))


func _ready() -> void:
	collision_layer = 0
	collision_mask = ACTOR_BODY_COLLISION_MASK
	monitoring = true
	monitorable = false
	add_to_group("building_door_passage_queue")
	var collision := CollisionShape3D.new()
	collision.name = "QueueRange"
	var shape := BoxShape3D.new()
	shape.size = _range_size
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(true)


func _exit_tree() -> void:
	for entry in _entries:
		var actor := _get_entry_actor(entry)
		if actor != null:
			actor.clear_door_queue_state(queue_id)
	_entries.clear()
	_pending_release_seconds.clear()


func _physics_process(delta: float) -> void:
	var changed := _remove_invalid_entries()
	for raw_instance_id in _pending_release_seconds.keys():
		var instance_id := int(raw_instance_id)
		var remaining := float(_pending_release_seconds.get(raw_instance_id, 0.0)) - delta
		if remaining > 0.0:
			_pending_release_seconds[raw_instance_id] = remaining
			continue
		_pending_release_seconds.erase(raw_instance_id)
		if _is_instance_still_overlapping(instance_id):
			continue
		changed = _remove_entry(instance_id) or changed
	if changed:
		_refresh_tokens()


func _on_body_entered(body: Node3D) -> void:
	if not _supports_door_queue(body):
		return
	var instance_id := body.get_instance_id()
	_pending_release_seconds.erase(instance_id)
	if _find_entry_index(instance_id) >= 0:
		return
	_arrival_sequence += 1
	_entries.append({
		"instance_id": instance_id,
		"actor": weakref(body),
		"actor_id": str(body.get_door_queue_actor_id()),
		"arrival_sequence": _arrival_sequence,
	})
	_refresh_tokens()


func _on_body_exited(body: Node3D) -> void:
	var instance_id := body.get_instance_id()
	if _find_entry_index(instance_id) < 0:
		return
	if _release_grace_seconds <= 0.0:
		if _remove_entry(instance_id):
			_refresh_tokens()
		return
	_pending_release_seconds[instance_id] = _release_grace_seconds


func _supports_door_queue(body: Node) -> bool:
	return (
		body != null
		and body.has_method("get_door_queue_actor_id")
		and body.has_method("set_door_queue_state")
		and body.has_method("clear_door_queue_state")
	)


func _refresh_tokens() -> void:
	for index in range(_entries.size()):
		var entry := _entries[index]
		var actor := _get_entry_actor(entry)
		if actor == null:
			continue
		var token_number := index + 1 if index < _token_count else 0
		actor.set_door_queue_state(queue_id, token_number, index > 0)


func _remove_entry(instance_id: int) -> bool:
	var index := _find_entry_index(instance_id)
	if index < 0:
		return false
	var actor := _get_entry_actor(_entries[index])
	if actor != null:
		actor.clear_door_queue_state(queue_id)
	_entries.remove_at(index)
	_pending_release_seconds.erase(instance_id)
	return true


func _remove_invalid_entries() -> bool:
	var changed := false
	for index in range(_entries.size() - 1, -1, -1):
		if _get_entry_actor(_entries[index]) == null:
			_pending_release_seconds.erase(int(_entries[index].get("instance_id", 0)))
			_entries.remove_at(index)
			changed = true
	return changed


func _find_entry_index(instance_id: int) -> int:
	for index in range(_entries.size()):
		if int(_entries[index].get("instance_id", 0)) == instance_id:
			return index
	return -1


func _get_entry_actor(entry: Dictionary) -> Node:
	var actor_ref: WeakRef = entry.get("actor") as WeakRef
	if actor_ref == null:
		return null
	var actor: Variant = actor_ref.get_ref()
	return actor as Node if is_instance_valid(actor) else null


func _is_instance_still_overlapping(instance_id: int) -> bool:
	for body in get_overlapping_bodies():
		if is_instance_valid(body) and body.get_instance_id() == instance_id:
			return true
	return false


func debug_get_snapshot() -> Dictionary:
	var entry_snapshots: Array[Dictionary] = []
	for index in range(_entries.size()):
		var entry := _entries[index]
		var actor := _get_entry_actor(entry)
		entry_snapshots.append({
			"actor_id": str(entry.get("actor_id", "")),
			"instance_id": int(entry.get("instance_id", 0)),
			"arrival_sequence": int(entry.get("arrival_sequence", 0)),
			"token_number": index + 1 if index < _token_count else 0,
			"overflow": index >= _token_count,
			"paused": index > 0,
			"valid": actor != null,
		})
	return {
		"queue_id": queue_id,
		"building_id": building_id,
		"token_count": _token_count,
		"range_size": _range_size,
		"entry_count": _entries.size(),
		"held_token_count": mini(_entries.size(), _token_count),
		"overflow_count": maxi(0, _entries.size() - _token_count),
		"entries": entry_snapshots,
	}
