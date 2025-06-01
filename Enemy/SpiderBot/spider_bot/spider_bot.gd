extends Node3D
# Add AnimationPlayer reference with other @onready vars
@onready var state_machine = $AnimationTree["parameters/playback"]

@onready var fl_leg = $FrontLeftIKTarget
@onready var fr_leg = $FrontRightIKTarget
@onready var bl_leg = $BackLeftIKTarget
@onready var br_leg = $BackRightIKTarget

@onready var fl_ray = $StepTargetContainer/FrontLeftRay
@onready var fr_ray = $StepTargetContainer/FrontRightRay
@onready var bl_ray = $StepTargetContainer/BackLeftRay
@onready var br_ray = $StepTargetContainer/BackRightRay

# Movement Settings
@export_group("Movement")
@export var strafe_speed: float = .5
@export var move_speed: float = 1.0
@export var turn_speed: float = 3.0
@export var max_turn_speed: float = 2.0

# Ground Alignment Settings
@export_group("Ground Alignment")
@export var ground_offset: float = 0.15
@export var body_length: float = .3
@export var pitch_compensation_factor: float = 0.5
@export var fall_alignment_speed: float = 5.0

# Physics Settings
@export_group("Physics")
@export var gravity_strength: float = 9.8
@export var terminal_velocity: float = 100.0
@export var jump_strength: float = 1.0

# Movement input values from handler
var input_move_dir: float = 0.0
var input_strafe_dir: float = 0.0
var input_turn_amount: float = 0.0


# Jump variables

var jump_pressed: bool = false
@export var can_jump: bool = true
@export var is_jumping: bool = false



@onready var movement_input_handler = $MovementInputHandler



# Ground detection ray
@onready var ground_ray: RayCast3D = $StepTargetContainer/GroundRay
var vertical_velocity: float = 0.0
var is_grounded: bool = true


var mouse_delta_x: float = 0.0
var mouse_delta_y: float = 0.0
var current_pitch: float = 0.0

# Store the terrain-aligned basis separately
var terrain_basis: Basis


func _ready():
	Engine.time_scale = 1.0
	# Initialize terrain basis
	terrain_basis = transform.basis

		# Set up ground detection through the ground ray
	if ground_ray and ground_ray.has_method("setup_leg_rays"):
		ground_ray.setup_leg_rays($StepTargetContainer)
		ground_ray.grounded_state_changed.connect(_on_grounded_state_changed)
	# Connect to movement input handler signals

	movement_input_handler.movement_input.connect(_on_movement_input)
	movement_input_handler.jump_requested.connect(_on_jump_requested)
		
func _on_movement_input(movement_vector: Vector3,turn_amount: float, pitch: float):
	current_pitch = pitch
	input_move_dir = movement_vector.z
	input_strafe_dir = movement_vector.x
	input_turn_amount = turn_amount

func _on_jump_requested():
	if can_jump and is_grounded:
		state_machine.travel("fall")
		
		
func _process(delta):
	# Update pitch from input handler
	if movement_input_handler:
		current_pitch = movement_input_handler.get_current_pitch()
	
	# Reset to terrain basis before any calculations
	transform.basis = terrain_basis
	
	# Handle user input
	_handle_movement(delta)
	
	# Keep local grounded state synced with ground ray
	if ground_ray and ground_ray.has_method("get_grounded_state"):
		is_grounded = ground_ray.get_grounded_state()
	
	# Apply gravity if not grounded
	if not is_grounded:
		_apply_gravity(delta)
	else:
		vertical_velocity = 0.0
	
	# Only do terrain alignment if grounded
	if is_grounded == true:
		_align_to_terrain(delta)
	
	# Apply visual pitch as the final step - but only if grounded
	# When falling, the gravity alignment takes precedence
	if is_grounded:
		_apply_visual_pitch()

func _handle_movement(delta):
	# Apply movement
	translate(Vector3(0, 0, -input_move_dir) * move_speed * delta)
	translate(Vector3(input_strafe_dir, 0, 0) * strafe_speed * delta)
	
	# Apply rotation
	var turn_amount = clamp(input_turn_amount, -max_turn_speed * delta, max_turn_speed * delta)
	rotate_object_local(Vector3.UP, turn_amount)
	
	# Update terrain basis to include the rotation (only if grounded)
	if is_grounded:
		terrain_basis = transform.basis
		
		

func _apply_visual_pitch():
	# Use quaternion rotation to avoid gimbal lock
	var pitch_quaternion = Quaternion(terrain_basis.x.normalized(), current_pitch)
	transform.basis = Basis(pitch_quaternion) * terrain_basis

func _align_to_terrain(delta):
	# Use global positions for plane calculations
	var plane1 = Plane(bl_leg.global_position, fl_leg.global_position, fr_leg.global_position)
	var plane2 = Plane(fr_leg.global_position, br_leg.global_position, bl_leg.global_position)
	var avg_normal = ((plane1.normal + plane2.normal) / 2).normalized()
	
	# Calculate target basis using the current terrain basis
	var target_basis = _basis_from_normal_for_terrain(avg_normal, terrain_basis)
	terrain_basis = lerp(terrain_basis, target_basis, (move_speed * 5) * delta).orthonormalized()
	
	# Apply the terrain basis (without pitch)
	transform.basis = terrain_basis
	
	# Position adjustment with pitch compensation
	var avg = (fl_leg.position + fr_leg.position + bl_leg.position + br_leg.position) / 4
	var base_offset = ground_offset
	
	# Calculate additional height needed based on pitch
	# When looking up (negative pitch), raise the spider
	# When looking down (positive pitch), raise the spider
	var pitch_height_offset = abs(sin(current_pitch)) * body_length * pitch_compensation_factor
	
	var total_offset = base_offset + pitch_height_offset
	var target_pos = avg + transform.basis.y * total_offset
	var distance = transform.basis.y.dot(target_pos - position)
	position = lerp(position, position + transform.basis.y * distance, move_speed * delta)

func _basis_from_normal_for_terrain(normal: Vector3, current_terrain_basis: Basis) -> Basis:
	var result = Basis()
	# Use the terrain basis forward direction, not the pitched transform
	result.x = normal.cross(current_terrain_basis.z)
	result.y = normal
	result.z = result.x.cross(normal)
	
	result = result.orthonormalized()
	result.x *= scale.x 
	result.y *= scale.y 
	result.z *= scale.z 
	
	return result
	

func _apply_gravity(delta):
	# Increase downward velocity
	vertical_velocity += gravity_strength * delta
	# Clamp to terminal velocity
	vertical_velocity = min(vertical_velocity, terminal_velocity)
	
	# Apply gravity in GLOBAL world down direction
	global_position += Vector3.DOWN * vertical_velocity * delta
	
	# Align spider to fall "feet down"
	_align_to_gravity(delta)
	
func _align_to_gravity(delta):
	# Get current forward direction (negative Z in local space)
	var forward = -transform.basis.z
	
	# Create a new basis that's upright but maintains forward direction
	var target_basis = Basis()
	target_basis.y = Vector3.UP
	# Remove any vertical component from forward direction
	forward.y = 0
	forward = forward.normalized()
	
	# If forward is too small (spider was facing straight up/down), use a default
	if forward.length() < 0.1:
		forward = -transform.basis.x  # Use right direction as fallback
		forward.y = 0
		forward = forward.normalized()
	
	target_basis.z = -forward
	target_basis.x = target_basis.y.cross(target_basis.z)
	target_basis = target_basis.orthonormalized()
	
	# Apply scale
	target_basis.x *= scale.x
	target_basis.y *= scale.y
	target_basis.z *= scale.z
	
	# Smoothly rotate towards upright orientation
	terrain_basis = lerp(terrain_basis, target_basis, fall_alignment_speed * delta).orthonormalized()
	transform.basis = terrain_basis



func _basis_from_normal(normal: Vector3) -> Basis:
	var result = Basis()
	result.x = normal.cross(transform.basis.z)
	result.y = normal
	result.z = transform.basis.x.cross(normal)
	
	result = result.orthonormalized()
	result.x *= scale.x 
	result.y *= scale.y 
	result.z *= scale.z 
	
	return result

func _on_grounded_state_changed(grounded: bool):
	# When regaining ground from airborne, update terrain basis
	if grounded and not is_grounded:
		terrain_basis = transform.basis
	
	is_grounded = grounded  # Update local state
	
	# Notify all IK targets about grounding state
	if fl_leg:
		fl_leg.set_grounded(grounded)
	if fr_leg:
		fr_leg.set_grounded(grounded)
	if bl_leg:
		bl_leg.set_grounded(grounded)
	if br_leg:
		br_leg.set_grounded(grounded)
	
	# Also notify the rays
	if fl_ray and fl_ray.has_method("set_grounded"):
		fl_ray.set_grounded(grounded)
	if fr_ray and fr_ray.has_method("set_grounded"):
		fr_ray.set_grounded(grounded)
	if bl_ray and bl_ray.has_method("set_grounded"):
		bl_ray.set_grounded(grounded)
	if br_ray and br_ray.has_method("set_grounded"):
		br_ray.set_grounded(grounded)

# Getter for current pitch - used by StepTargetContainer
func _get_current_pitch() -> float:
	return current_pitch

# Getter for terrain basis - used by StepTargetContainer
func _get_terrain_basis() -> Basis:
	return terrain_basis
	
func _jump():
	if is_jumping == true and can_jump == true:
		vertical_velocity = -jump_strength
		can_jump = false
		
		# Force ungrounded through the ground ray
		if ground_ray and ground_ray.has_method("force_ungrounded"):
			ground_ray.force_ungrounded()
