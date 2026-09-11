extends RefCounted

## Opt-in, bounded observation only. Section times may nest; never sum them.
const MAX_SAMPLES := 3600
const MONITORS := {
	"process_ms": Performance.TIME_PROCESS,
	"physics_ms": Performance.TIME_PHYSICS_PROCESS,
	"navigation_ms": Performance.TIME_NAVIGATION_PROCESS,
	"draw_calls": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,
	"primitives": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME,
	"nodes": Performance.OBJECT_NODE_COUNT,
	"static_memory_bytes": Performance.MEMORY_STATIC,
}

var active := true
var _started_usec := Time.get_ticks_usec()
var _previous_frame_usec := 0
var _duration_usec := 30000000
var _samples: Dictionary = {}
var _dropped_samples: Dictionary = {}
var _metadata: Dictionary = {}


func configure(duration_seconds: float, metadata: Dictionary) -> void:
	_duration_usec = int(clampf(duration_seconds, 1.0, 60.0) * 1000000.0)
	_metadata = metadata.duplicate(true)


func record(section: StringName, elapsed_usec: int) -> void:
	if active:
		_append(section, float(elapsed_usec) / 1000.0)


func sample_frame(enemy_count: int, gameplay_paused: bool) -> void:
	if not active:
		return
	var now := Time.get_ticks_usec()
	if _previous_frame_usec > 0:
		_append("frame_ms", float(now - _previous_frame_usec) / 1000.0)
	_previous_frame_usec = now
	for key: String in MONITORS:
		var value := Performance.get_monitor(MONITORS[key])
		_append(key, value * 1000.0 if key.ends_with("_ms") else value)
	_append("enemy_count", enemy_count)
	_append("paused", 1.0 if gameplay_paused else 0.0)
	if now - _started_usec >= _duration_usec:
		active = false


func _append(key: StringName, value: float) -> void:
	if not _samples.has(key):
		_samples[key] = []
	var values: Array = _samples[key]
	if values.size() < MAX_SAMPLES:
		values.append(value)
	else:
		_dropped_samples[key] = int(_dropped_samples.get(key, 0)) + 1


func snapshot(include_samples: bool = false) -> Dictionary:
	var result := {"active": active, "metadata": _metadata.duplicate(true), "metrics": {},
		"sample_cap_per_metric": MAX_SAMPLES, "dropped_samples": _dropped_samples.duplicate()}
	for key in _samples:
		var values: Array = _samples[key].duplicate()
		values.sort()
		if values.is_empty():
			continue
		var total := 0.0
		var long_frames := 0
		for value: float in values:
			total += value
			if value > 33.3333:
				long_frames += 1
		result.metrics[key] = {
			"count": values.size(), "mean": total / values.size(),
			"min": values[0], "p50": values[ceili(values.size() * 0.5) - 1],
			"p95": values[ceili(values.size() * 0.95) - 1],
			"p99": values[ceili(values.size() * 0.99) - 1], "max": values[-1],
		}
		if str(key) == "frame_ms":
			result.metrics[key]["over_33ms_percent"] = 100.0 * long_frames / values.size()
	if include_samples:
		result["raw_samples"] = _samples.duplicate(true)
	return result
