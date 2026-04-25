extends Node

const NAMED_PLAYER_COLORS := {
	"red": Color(1.0, 0.0, 0.0, 1.0),
	"green": Color(0.0, 1.0, 0.0, 1.0),
	"yellow": Color(1.0, 1.0, 0.0, 1.0),
}
const HEX_DIGITS := "0123456789abcdef"

signal query_parameters_loaded

var raw_query_string := ""
var query_parameters := {}
var username := ""
var referrer_url := ""
var speed_meters_per_second := 0.0
var has_speed := false
var player_color := Color.WHITE
var has_player_color := false
var has_loaded_query_parameters := false


func _ready() -> void:
	refresh_from_startup()


func refresh_from_startup() -> void:
	load_from_query_string(_get_startup_query_string())


func load_from_query_string(query_string: String) -> void:
	_reset()
	raw_query_string = query_string.strip_edges()
	if not raw_query_string.is_empty():
		var trimmed_query := raw_query_string
		if trimmed_query.begins_with("?"):
			trimmed_query = trimmed_query.substr(1)

		for pair in trimmed_query.split("&", false):
			if pair.is_empty():
				continue

			var key_value := pair.split("=", true, 1)
			var key := _decode_query_component(key_value[0]).strip_edges()
			if key.is_empty():
				continue

			var value := ""
			if key_value.size() > 1:
				value = _decode_query_component(key_value[1]).strip_edges()
			query_parameters[key] = value

	_apply_normalized_values()
	has_loaded_query_parameters = true
	query_parameters_loaded.emit()


func has_parameter(name: String) -> bool:
	return query_parameters.has(name)


func get_parameter(name: String, default_value: Variant = "") -> Variant:
	return query_parameters.get(name, default_value)


func has_username() -> bool:
	return not username.is_empty()


func set_username(value: String) -> void:
	username = value.strip_edges()
	if username.is_empty():
		query_parameters.erase("username")
		return
	query_parameters["username"] = username


func to_dictionary() -> Dictionary:
	return {
		"raw_query_string": raw_query_string,
		"query_parameters": query_parameters.duplicate(),
		"username": username,
		"referrer_url": referrer_url,
		"speed_meters_per_second": speed_meters_per_second,
		"has_speed": has_speed,
		"player_color": player_color,
		"has_player_color": has_player_color,
	}


func _apply_normalized_values() -> void:
	username = String(query_parameters.get("username", "")).strip_edges()
	referrer_url = String(query_parameters.get("ref", "")).strip_edges()

	var speed_text := String(query_parameters.get("speed", "")).strip_edges()
	if not speed_text.is_empty() and speed_text.is_valid_float():
		speed_meters_per_second = maxf(speed_text.to_float(), 0.0)
		has_speed = true

	var color_text := String(query_parameters.get("color", "")).strip_edges()
	var color_result := _parse_player_color(color_text)
	if color_result.get("ok", false):
		player_color = color_result["color"]
		has_player_color = true


func _reset() -> void:
	raw_query_string = ""
	query_parameters = {}
	username = ""
	referrer_url = ""
	speed_meters_per_second = 0.0
	has_speed = false
	player_color = _generate_default_player_color()
	has_player_color = false
	has_loaded_query_parameters = false


func _get_startup_query_string() -> String:
	if OS.has_feature("web"):
		return _get_web_query_string()
	return _get_command_line_query_string()


func _get_web_query_string() -> String:
	return str(JavaScriptBridge.eval("window.location.search", true))


func _get_command_line_query_string() -> String:
	var query_parts: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("?"):
			return arg
		if arg.contains("=") and not arg.begins_with("-"):
			query_parts.append(arg)

	if query_parts.is_empty():
		return ""
	return "&".join(query_parts)


func _decode_query_component(component: String) -> String:
	return component.replace("+", " ").uri_decode()


func _parse_player_color(value: String) -> Dictionary:
	var normalized := value.to_lower()
	if normalized.is_empty():
		return {"ok": false}
	if NAMED_PLAYER_COLORS.has(normalized):
		return {
			"ok": true,
			"color": NAMED_PLAYER_COLORS[normalized],
		}

	var hex_value := normalized
	if hex_value.begins_with("#"):
		hex_value = hex_value.substr(1)
	if not _is_valid_hex_color(hex_value):
		return {"ok": false}

	return {
		"ok": true,
		"color": _color_from_hex(hex_value),
	}


func _is_valid_hex_color(value: String) -> bool:
	if value.length() not in [3, 4, 6, 8]:
		return false

	for character in value:
		if HEX_DIGITS.find(character) == -1:
			return false
	return true


func _color_from_hex(value: String) -> Color:
	var expanded := value
	if value.length() == 3 or value.length() == 4:
		expanded = ""
		for character in value:
			expanded += character + character

	var alpha := 1.0
	if expanded.length() == 8:
		alpha = float(_hex_byte(expanded.substr(6, 2))) / 255.0

	return Color(
		float(_hex_byte(expanded.substr(0, 2))) / 255.0,
		float(_hex_byte(expanded.substr(2, 2))) / 255.0,
		float(_hex_byte(expanded.substr(4, 2))) / 255.0,
		alpha
	)


func _hex_byte(value: String) -> int:
	return _hex_digit(value.substr(0, 1)) * 16 + _hex_digit(value.substr(1, 1))


func _hex_digit(value: String) -> int:
	return HEX_DIGITS.find(value.to_lower())


func _generate_default_player_color() -> Color:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return Color.from_hsv(
		rng.randf(),
		rng.randf_range(0.55, 0.8),
		rng.randf_range(0.85, 1.0),
		1.0
	)
