extends Node

signal velocity_changed(velocity: Vector3)
signal falling_alignment_needed(delta: float)

@export_group("Physics Settings")
@export var gravity_strength: float = 9.8
@export var terminal_velocity: float = 100.0
@export var fall_alignment_speed: float = 5.0

var velocity: Vector3 = Vector3.ZERO  # Full 3D velocity vector
var is_active: bool = false

func apply_physics(delta: float, current_transform: Transform3D) -> Vector3:
	"""Calculate and return the total displacement for this frame"""
	if not is_active:
		return Vector3.ZERO
	
	# Apply gravity to velocity (always in world DOWN direction)
	velocity += Vector3.DOWN * gravity_strength * delta
	
	# Clamp vertical component to terminal velocity
	if velocity.y > terminal_velocity:
		velocity.y = terminal_velocity
	
	velocity_changed.emit(velocity)
	
	# Return the displacement to apply
	return velocity * delta

func reset_velocity():
	"""Reset velocity when grounded"""
	velocity = Vector3.ZERO
	velocity_changed.emit(velocity)

func set_active(active: bool):
	"""Enable/disable physics calculations"""
	is_active = active
	if not active:
		reset_velocity()

func add_jump_impulse(strength: float, direction: Vector3):
	"""Add jump impulse in the given direction"""
	velocity += direction.normalized() * strength
	velocity_changed.emit(velocity)

func should_align_to_gravity() -> bool:
	"""Check if fall alignment should be applied"""
	if not is_active:
		return false
	
	# Check if we're falling by seeing if velocity has a significant downward component
	# and we're past the peak of the jump
	var downward_velocity = velocity.dot(Vector3.DOWN)
	return downward_velocity > 0.1  # Moving in the same direction as gravity
