extends Node

signal velocity_changed(velocity: Vector3)

@export_group("Movement Settings")
@export var move_acceleration: float = 10.0
@export var strafe_acceleration: float = 8.0
@export var friction: float = 2.0
@export var max_move_speed: float = 2.0
@export var max_strafe_speed: float = 2.0

var velocity: Vector3 = Vector3.ZERO  # Local velocity (x=strafe, z=forward)
var is_active: bool = true

@export var air_control_factor: float = 0.3  # How much control you have in the air (0-1)

var is_grounded: bool = true  # Track grounded state separately from active

func apply_movement(delta: float, input_move: float, input_strafe: float, current_basis: Basis) -> Vector3:
	"""Calculate and return the movement displacement for this frame"""
	if not is_active:
		return Vector3.ZERO
	
	# Reduce input influence when airborne
	var control_factor = 1.0 if is_grounded else air_control_factor
	
	# Calculate desired acceleration based on input
	var acceleration = Vector3.ZERO
	acceleration.x = input_strafe * strafe_acceleration * control_factor
	acceleration.z = -input_move * move_acceleration * control_factor
	
	# Apply acceleration to velocity
	velocity += acceleration * delta
	
	# Apply friction only when grounded
	if is_grounded:
		# Apply friction when no input
		if abs(input_strafe) < 0.01 and abs(velocity.x) > 0.01:
			velocity.x -= sign(velocity.x) * min(abs(velocity.x), friction * delta)
		
		if abs(input_move) < 0.01 and abs(velocity.z) > 0.01:
			velocity.z -= sign(velocity.z) * min(abs(velocity.z), friction * delta)
	
	# Clamp velocity to max speeds
	velocity.x = clamp(velocity.x, -max_strafe_speed, max_strafe_speed)
	velocity.z = clamp(velocity.z, -max_move_speed, max_move_speed)
	
	velocity_changed.emit(velocity)
	
	# Convert local velocity to world space displacement
	var world_velocity = current_basis * velocity
	return world_velocity * delta

func set_grounded(grounded: bool):
	"""Update grounded state without resetting velocity"""
	is_grounded = grounded
	

func reset_velocity():
	"""Reset velocity when needed"""
	velocity = Vector3.ZERO
	velocity_changed.emit(velocity)

func set_active(active: bool):
	"""Enable/disable movement calculations"""
	is_active = active
	if not active:
		reset_velocity()
