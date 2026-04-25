extends Node2D

# Main scene coordinator. World/building rendering is handled by the WorldGen
# child (world_gen.tscn). This script manages viewport-responsive UI layout.

const BASE_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const INSTRUCTIONS_FONT_SIZE := 18
const USERNAME_BADGE_FONT_SIZE := 18
const USERNAME_BADGE_MARGIN := Vector2(24.0, 20.0)
const USERNAME_PROMPT_WIDTH := 420.0
const USERNAME_PROMPT_HEIGHT := 190.0
const USERNAME_PROMPT_BACKGROUND := Color(0.0, 0.0, 0.0, 0.55)
const USERNAME_PROMPT_ERROR_COLOR := Color(1.0, 0.72, 0.72, 1.0)

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var instructions: Label = $CanvasLayer/Instructions
@onready var player: CharacterBody2D = $WorldGen/Player

var _username_badge: PanelContainer
var _username_badge_label: Label
var _username_overlay: Control
var _username_input: LineEdit
var _username_error_label: Label


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_build_username_badge()
	_build_username_prompt()
	_layout_hud()
	Callable(self, "_show_username_prompt_if_needed").call_deferred()


func _on_viewport_size_changed() -> void:
	_layout_hud()


func _layout_hud() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return

	var scale := maxf(viewport_size.x / BASE_VIEWPORT_SIZE.x, 0.25)
	instructions.position = Vector2(24.0, 20.0) * scale
	instructions.add_theme_font_size_override(
		"font_size", maxi(int(INSTRUCTIONS_FONT_SIZE * scale), 10)
	)
	_username_badge_label.add_theme_font_size_override(
		"font_size", maxi(int(USERNAME_BADGE_FONT_SIZE * scale), 10)
	)

	var badge_size := _username_badge.get_combined_minimum_size()
	_username_badge.size = badge_size
	_username_badge.position = viewport_size - badge_size - USERNAME_BADGE_MARGIN * scale


func _build_username_badge() -> void:
	_username_badge = PanelContainer.new()
	_username_badge.name = "UsernameBadge"
	_username_badge.visible = false
	canvas_layer.add_child(_username_badge)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 14)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_right", 14)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	_username_badge.add_child(content_margin)

	_username_badge_label = Label.new()
	_username_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content_margin.add_child(_username_badge_label)


func _build_username_prompt() -> void:
	_username_overlay = Control.new()
	_username_overlay.name = "UsernameOverlay"
	_username_overlay.visible = false
	_username_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_username_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(_username_overlay)

	var blocker := ColorRect.new()
	blocker.color = USERNAME_PROMPT_BACKGROUND
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_username_overlay.add_child(blocker)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -USERNAME_PROMPT_WIDTH * 0.5
	panel.offset_top = -USERNAME_PROMPT_HEIGHT * 0.5
	panel.offset_right = USERNAME_PROMPT_WIDTH * 0.5
	panel.offset_bottom = USERNAME_PROMPT_HEIGHT * 0.5
	_username_overlay.add_child(panel)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_top", 20)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(content_margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content_margin.add_child(content)

	var title := Label.new()
	title.text = "Who's playing?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var prompt := Label.new()
	prompt.text = "Enter your name to keep going."
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(prompt)

	_username_input = LineEdit.new()
	_username_input.placeholder_text = "Name"
	_username_input.text_submitted.connect(_on_username_text_submitted)
	_username_input.text_changed.connect(_on_username_text_changed)
	content.add_child(_username_input)

	_username_error_label = Label.new()
	_username_error_label.text = "Please enter a name before continuing."
	_username_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_username_error_label.modulate = USERNAME_PROMPT_ERROR_COLOR
	_username_error_label.visible = false
	content.add_child(_username_error_label)

	var continue_button := Button.new()
	continue_button.text = "Continue"
	continue_button.pressed.connect(_on_username_continue_pressed)
	content.add_child(continue_button)


func _show_username_prompt_if_needed() -> void:
	if not GameParams.has_loaded_query_parameters:
		await GameParams.query_parameters_loaded
	_refresh_username_badge()
	if GameParams.has_username():
		return
	_set_username_prompt_visible(true)


func _set_username_prompt_visible(is_visible: bool) -> void:
	_username_overlay.visible = is_visible
	player.set_physics_process(not is_visible)
	if is_visible:
		_username_input.text = GameParams.username
		_username_error_label.visible = false
		Callable(_username_input, "grab_focus").call_deferred()
		Callable(_username_input, "select_all").call_deferred()
		return
	_username_input.release_focus()


func _on_username_continue_pressed() -> void:
	_submit_username()


func _on_username_text_submitted(_new_text: String) -> void:
	_submit_username()


func _on_username_text_changed(_new_text: String) -> void:
	_username_error_label.visible = false


func _submit_username() -> void:
	var submitted_username := _username_input.text.strip_edges()
	if submitted_username.is_empty():
		_username_error_label.visible = true
		_username_input.grab_focus()
		return
	GameParams.set_username(submitted_username)
	_refresh_username_badge()
	_set_username_prompt_visible(false)


func _refresh_username_badge() -> void:
	_username_badge_label.text = GameParams.username
	_username_badge_label.add_theme_color_override("font_color", GameParams.player_color)
	_username_badge.visible = GameParams.has_username()
	_layout_hud()
