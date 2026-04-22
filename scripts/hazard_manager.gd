class_name HazardManager
extends Node

# Runtime hazard state machine. Register as an autoload singleton.
#
# Each hazard tile goes through: IDLE → WARNING → TRIGGERED → reset to IDLE.
#
# Generation populates the registry via register_hazard(). The player controller
# (or a coordinator) calls player_near_hazard() / player_on_hazard() each frame.
# On death, reset_all() restores all hazards to IDLE for the respawn.
#
# ⚠️ MANUAL EDITOR STEP REQUIRED — wire hazard signals in the game scene:
#   HazardManager.hazard_triggered.connect(_on_hazard_triggered)  → kill the player
#   HazardManager.hazard_warning.connect(_on_hazard_warning)      → play warning fx
#   HazardManager.hazard_reset.connect(_on_hazard_reset)          → hide warning fx
#
# The signal-bus pattern keeps HazardManager decoupled from the player scene.

enum HazardState {
	IDLE,
	WARNING,
	TRIGGERED,
	RESET_PENDING,
}

# Per-cell hazard state.
var _states: Dictionary = {}       # Vector2i → HazardState
var _hazard_types: Dictionary = {} # Vector2i → TileMeta.HazardType
var _reset_modes: Dictionary = {}  # Vector2i → String ("respawn", "checkpoint", "never")
var _trigger_radii: Dictionary = {}# Vector2i → int

signal hazard_warning(cell: Vector2i, hazard_type: int)
signal hazard_triggered(cell: Vector2i, hazard_type: int)
signal hazard_reset(cell: Vector2i)


# Called during building generation to register each placed hazard.
func register_hazard(
	cell:           Vector2i,
	hazard_type:    int,
	trigger_radius: int  = 1,
	reset_mode:     String = "respawn"
) -> void:
	_states[cell]        = HazardState.IDLE
	_hazard_types[cell]  = hazard_type
	_trigger_radii[cell] = trigger_radius
	_reset_modes[cell]   = reset_mode


# Call this when the player's tile position is within warning range but not yet
# inside the trigger radius. Transitions IDLE → WARNING.
func player_near_hazard(cell: Vector2i) -> void:
	if not _states.has(cell):
		return
	if _states[cell] == HazardState.IDLE:
		_states[cell] = HazardState.WARNING
		hazard_warning.emit(cell, _hazard_types.get(cell, TileMeta.HazardType.NONE))


# Call this when the player is within the trigger radius. Transitions to TRIGGERED
# and emits the signal that kills the player.
func player_on_hazard(cell: Vector2i) -> void:
	if not _states.has(cell):
		return
	var s: HazardState = _states[cell]
	if s == HazardState.IDLE or s == HazardState.WARNING:
		_states[cell] = HazardState.TRIGGERED
		hazard_triggered.emit(cell, _hazard_types.get(cell, TileMeta.HazardType.NONE))


# Returns the current HazardState for a cell (-1 if not registered).
func get_state(cell: Vector2i) -> int:
	return _states.get(cell, -1)


# Returns the HazardType for a cell (NONE if not registered).
func get_hazard_type(cell: Vector2i) -> int:
	return _hazard_types.get(cell, TileMeta.HazardType.NONE)


# Returns all registered hazard cells.
func get_all_hazard_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for k in _states.keys():
		cells.append(k as Vector2i)
	return cells


# Reset a single hazard to IDLE. Use after a "checkpoint" reset_mode hazard resolves.
func reset_hazard(cell: Vector2i) -> void:
	if _states.has(cell):
		_states[cell] = HazardState.IDLE
		hazard_reset.emit(cell)


# Reset all hazards to IDLE. Call on player respawn.
func reset_all() -> void:
	for cell in _states.keys().duplicate():
		var mode: String = _reset_modes.get(cell, "respawn")
		if mode != "never":
			_states[cell] = HazardState.IDLE
			hazard_reset.emit(cell as Vector2i)


# Clear the registry entirely. Call when loading a new building / new game.
func clear() -> void:
	_states.clear()
	_hazard_types.clear()
	_reset_modes.clear()
	_trigger_radii.clear()
