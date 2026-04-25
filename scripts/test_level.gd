extends Node2D

# Main scene coordinator. World/building rendering is handled by the WorldGen
# child (world_gen.tscn). This script manages the HUD flow and username prompt.

const USERNAME_PROMPT_WIDTH := 420.0
const USERNAME_PROMPT_HEIGHT := 190.0
const USERNAME_PROMPT_BACKGROUND := Color(0.0, 0.0, 0.0, 0.55)
const USERNAME_PROMPT_ERROR_COLOR := Color(1.0, 0.72, 0.72, 1.0)
const MOVE_ACTION_LEFT := &"move_left"
const MOVE_ACTION_RIGHT := &"move_right"
const MOVE_ACTION_UP := &"move_up"
const MOVE_ACTION_DOWN := &"move_down"
const MOBILE_NAV_PAD_SIZE := 192.0
const MOBILE_NAV_BUTTON_HEIGHT := 60.0
const MOBILE_NAV_BUTTON_GAP := 6
const MOBILE_NAV_HALF_BUTTON_WIDTH := (MOBILE_NAV_PAD_SIZE - MOBILE_NAV_BUTTON_GAP) * 0.5

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var hud_root: Control = $CanvasLayer/HudRoot
@onready var hud_bottom_row: HBoxContainer = $CanvasLayer/HudRoot/HudMargin/HudVBox/BottomRow
@onready var player: CharacterBody2D = $WorldGen/Player

var _hud_controls_column: VBoxContainer
var _username_badge: PanelContainer
var _username_badge_label: Label
var _username_overlay: Control
var _username_input: LineEdit
var _username_error_label: Label
var _mobile_navigation_root: Control
var _pressed_mobile_navigation_actions: Dictionary = {}


func _ready() -> void:
	_build_hud_controls_column()
	_build_username_badge()
	_build_mobile_navigation()
	_build_username_prompt()
	_refresh_mobile_navigation_visibility()
	Callable(self, "_show_username_prompt_if_needed").call_deferred()


func _exit_tree() -> void:
	_release_mobile_navigation_actions()


func _build_hud_controls_column() -> void:
	_hud_controls_column = VBoxContainer.new()
	_hud_controls_column.name = "HudControlsColumn"
	_hud_controls_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_controls_column.add_theme_constant_override("separation", 12)
	hud_bottom_row.add_child(_hud_controls_column)


func _build_username_badge() -> void:
	_username_badge = PanelContainer.new()
	_username_badge.name = "UsernameBadge"
	_username_badge.visible = false
	_username_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_controls_column.add_child(_username_badge)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 14)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_right", 14)
	content_margin.add_theme_constant_override("margin_bottom", 8)
	_username_badge.add_child(content_margin)

	_username_badge_label = Label.new()
	_username_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content_margin.add_child(_username_badge_label)


func _build_mobile_navigation() -> void:
	_mobile_navigation_root = PanelContainer.new()
	_mobile_navigation_root.name = "MobileNavigationRoot"
	_mobile_navigation_root.visible = false
	_hud_controls_column.add_child(_mobile_navigation_root)

	var pad := VBoxContainer.new()
	pad.custom_minimum_size = Vector2(MOBILE_NAV_PAD_SIZE, MOBILE_NAV_PAD_SIZE)
	pad.add_theme_constant_override("separation", MOBILE_NAV_BUTTON_GAP)
	_mobile_navigation_root.add_child(pad)

	pad.add_child(_create_mobile_navigation_button("UP", MOVE_ACTION_UP, Vector2(MOBILE_NAV_PAD_SIZE, MOBILE_NAV_BUTTON_HEIGHT)))

	var middle_row := HBoxContainer.new()
	middle_row.add_theme_constant_override("separation", MOBILE_NAV_BUTTON_GAP)
	pad.add_child(middle_row)

	middle_row.add_child(_create_mobile_navigation_button("LEFT", MOVE_ACTION_LEFT, Vector2(MOBILE_NAV_HALF_BUTTON_WIDTH, MOBILE_NAV_BUTTON_HEIGHT)))
	middle_row.add_child(_create_mobile_navigation_button("RIGHT", MOVE_ACTION_RIGHT, Vector2(MOBILE_NAV_HALF_BUTTON_WIDTH, MOBILE_NAV_BUTTON_HEIGHT)))

	pad.add_child(_create_mobile_navigation_button("DOWN", MOVE_ACTION_DOWN, Vector2(MOBILE_NAV_PAD_SIZE, MOBILE_NAV_BUTTON_HEIGHT)))


func _create_mobile_navigation_button(label: String, action: StringName, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.keep_pressed_outside = true
	button.custom_minimum_size = minimum_size
	button.button_down.connect(_on_mobile_navigation_button_down.bind(action))
	button.button_up.connect(_on_mobile_navigation_button_up.bind(action))
	return button


func _build_username_prompt() -> void:
	_username_overlay = Control.new()
	_username_overlay.name = "UsernameOverlay"
	_username_overlay.visible = false
	_username_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_username_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.add_child(_username_overlay)

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
	_refresh_mobile_navigation_visibility()
	if is_visible:
		_release_mobile_navigation_actions()
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


func _refresh_mobile_navigation_visibility() -> void:
	if _mobile_navigation_root == null:
		return
	var should_show := _is_mobile_navigation_available() and not _username_overlay.visible
	_mobile_navigation_root.visible = should_show
	if not should_show:
		_release_mobile_navigation_actions()


func _is_mobile_navigation_available() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()


func _on_mobile_navigation_button_down(action: StringName) -> void:
	if _pressed_mobile_navigation_actions.has(action):
		return
	_pressed_mobile_navigation_actions[action] = true
	Input.action_press(action)


func _on_mobile_navigation_button_up(action: StringName) -> void:
	if not _pressed_mobile_navigation_actions.has(action):
		return
	_pressed_mobile_navigation_actions.erase(action)
	Input.action_release(action)


func _release_mobile_navigation_actions() -> void:
	for action in _pressed_mobile_navigation_actions.keys():
		Input.action_release(action)
	_pressed_mobile_navigation_actions.clear()
