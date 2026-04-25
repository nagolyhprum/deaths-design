extends GutTest

const GameParamsScript := preload("res://scripts/game_params.gd")


func test_load_from_query_string_parses_all_supported_fields() -> void:
	var params = autofree(GameParamsScript.new())

	params.load_from_query_string(
		"?username=Casey&color=green&speed=3.5&ref=https%3A%2F%2Farcade.example%2Fplay"
	)

	assert_eq(params.username, "Casey")
	assert_true(params.has_player_color)
	assert_true(params.player_color.is_equal_approx(Color(0.0, 1.0, 0.0, 1.0)))
	assert_true(params.has_speed)
	assert_eq(params.speed_meters_per_second, 3.5)
	assert_eq(params.referrer_url, "https://arcade.example/play")
	assert_eq(params.get_parameter("username"), "Casey")


func test_load_from_query_string_accepts_hex_colors_and_plus_decoding() -> void:
	var params = autofree(GameParamsScript.new())

	params.load_from_query_string("?username=Jane+Doe&color=ff0&ref=lobby+screen")

	assert_eq(params.username, "Jane Doe")
	assert_true(params.has_player_color)
	assert_true(params.player_color.is_equal_approx(Color(1.0, 1.0, 0.0, 1.0)))
	assert_eq(params.referrer_url, "lobby screen")


func test_invalid_values_fall_back_to_safe_defaults() -> void:
	var params = autofree(GameParamsScript.new())

	params.load_from_query_string("?color=unknown&speed=fast")

	assert_false(params.has_player_color)
	assert_false(params.player_color.is_equal_approx(Color.WHITE))
	assert_eq(params.player_color.a, 1.0)
	assert_false(params.has_speed)
	assert_eq(params.speed_meters_per_second, 0.0)
	assert_eq(params.username, "")
	assert_eq(params.referrer_url, "")


func test_load_from_query_string_marks_parameters_as_loaded_without_a_username() -> void:
	var params = autofree(GameParamsScript.new())

	params.load_from_query_string("")

	assert_true(params.has_loaded_query_parameters)
	assert_false(params.has_username())
	assert_false(params.player_color.is_equal_approx(Color.WHITE))


func test_set_username_updates_the_global_username_and_query_parameters() -> void:
	var params = autofree(GameParamsScript.new())

	params.load_from_query_string("?ref=lobby")
	params.set_username("  Logan  ")

	assert_eq(params.username, "Logan")
	assert_true(params.has_username())
	assert_eq(params.get_parameter("username"), "Logan")
	assert_eq(params.get_parameter("ref"), "lobby")


func test_set_username_clears_the_username_parameter_when_blank() -> void:
	var params = autofree(GameParamsScript.new())

	params.load_from_query_string("?username=Casey")
	params.set_username("   ")

	assert_eq(params.username, "")
	assert_false(params.has_username())
	assert_false(params.has_parameter("username"))
	assert_eq(params.get_parameter("username", "missing"), "missing")


func test_build_portal_2026_url_uses_current_global_values() -> void:
	var params = autofree(GameParamsScript.new())

	params.username = "levelsio"
	params.speed_meters_per_second = 5.0
	params.player_color = Color(1.0, 0.0, 0.0, 1.0)

	assert_eq(
		params.build_portal_2026_url(),
		"https://vibej.am/portal/2026?username=levelsio&color=red&speed=5"
	)


func test_build_portal_2026_url_serializes_non_named_colors_as_hex() -> void:
	var params = autofree(GameParamsScript.new())

	params.load_from_query_string("?username=Jane+Doe&color=123456&speed=3.5")

	assert_eq(
		params.build_portal_2026_url(),
		"https://vibej.am/portal/2026?username=Jane%20Doe&color=123456&speed=3.5"
	)
