class_name RateDisplayFormatter
extends RefCounted

const MINUTE_SECONDS := 60.0
const HOUR_SECONDS := 3600.0
const MINUTE_DISPLAY_THRESHOLD := 0.01
const RATE_EPSILON := 0.0000001


static func format_positive_rate(rate_per_game_second: float, display_scale: float = 1.0) -> String:
	var scaled_rate := maxf(0.0, rate_per_game_second * display_scale)
	if scaled_rate <= RATE_EPSILON:
		return ""
	var per_minute := scaled_rate * MINUTE_SECONDS
	if per_minute + RATE_EPSILON >= MINUTE_DISPLAY_THRESHOLD:
		return "+%s/min" % _format_number(per_minute)
	return "+%s/h" % _format_number(scaled_rate * HOUR_SECONDS)


static func _format_number(value: float) -> String:
	var text := "%.2f" % value
	while text.ends_with("0"):
		text = text.left(text.length() - 1)
	if text.ends_with("."):
		text = text.left(text.length() - 1)
	return text
