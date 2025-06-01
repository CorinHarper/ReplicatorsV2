extends Node


signal movement_input(direction: Vector3, turn: float, pitch: float)
signal jump_requested()
signal mouse_mode_toggle()

# Camera/Input Settings
@export_group("Camera Controls")
@export var mouse_sensitivity: float = 0.005
@export var pitch_sensitivity: float = 0.005
@export var pitch_min: float = -85.0
@export var pitch_max: float = 85.0
@export var capture_mouse: bool = true

var mouse_delta_x: float = 0.0
var mouse_delta_y: float = 0.0
var current_pitch: float = 0.0

func _ready():
	if capture_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		mouse_delta_x = event.relative.x
		mouse_delta_y = event.relative.y
	
	if event.is_action_pressed("ui_cancel"):
		mouse_mode_toggle.emit()
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event.is_action_pressed("jump"):
		jump_requested.emit()

func _process(_delta):
	# Calculate movement direction
	var forward = Input.get_axis('ui_down', 'ui_up')
	var strafe = Input.get_axis('ui_left', 'ui_right')
	var movement_vector: Vector3 = Vector3(strafe,0.0,forward) 

	# Calculate turn amount
	var turn_amount = -mouse_delta_x * mouse_sensitivity
	
	# Update pitch
	var pitch_amount = -mouse_delta_y * pitch_sensitivity

	current_pitch += pitch_amount
	current_pitch = clamp(current_pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))
	
	# Emit movement data
	movement_input.emit(movement_vector, turn_amount, current_pitch)
	
	# Reset mouse deltas
	mouse_delta_x = 0.0
	mouse_delta_y = 0.0

func get_current_pitch() -> float:
	return current_pitch

func reset_pitch():
	current_pitch = 0.0
