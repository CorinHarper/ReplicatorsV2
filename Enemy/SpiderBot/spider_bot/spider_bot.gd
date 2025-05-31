extends Node3D

@export var move_speed: float = 1.0
@export var turn_speed: float = 3.0
@export var ground_offset: float = 0.15
@export var gravity_strength: float = 9.8
@export var terminal_velocity: float = 100.0
@export var mouse_sensitivity: float = 0.005
@export var capture_mouse: bool = true
@export var max_turn_speed: float = 2.0
@export var pitch_min: float = -85.0
@export var pitch_max: float = 85.0
@export var pitch_sensitivity: float = 0.005
# New exports for pitch compensation
@export var pitch_compensation_factor: float = 0.5  # How much to lift/lower based on pitch
@export var body_length: float = .3  # Approximate length of spider body

@onready var fl_leg = $FrontLeftIKTarget
@onready var fr_leg = $FrontRightIKTarget
@onready var bl_leg = $BackLeftIKTarget
@onready var br_leg = $BackRightIKTarget

@onready var fl_ray = $StepTargetContainer/FrontLeftRay
@onready var fr_ray = $StepTargetContainer/FrontRightRay
@onready var bl_ray = $StepTargetContainer/BackLeftRay
@onready var br_ray = $StepTargetContainer/BackRightRay

# Jump variables
@export var jump_strength: float = 5.0
var can_jump: bool = true
var is_jumping: bool = false

# Add AnimationPlayer reference with other @onready vars
@onready var animation_player = $AnimationPlayer

var collision_states = {
	"FrontLeftRay": false,
	"FrontRightRay": false,
	"BackLeftRay": false,
	"BackRightRay": false
}

# Ground detection ray
signal grounded_state_changed(is_grounded: bool)
@onready var ground_ray = $GroundRay
var ground_ray_colliding: bool = false
var vertical_velocity: float = 0.0
var is_grounded: bool = true
@export var fall_alignment_speed: float = 5.0

var mouse_delta_x: float = 0.0
var mouse_delta_y: float = 0.0
var current_pitch: float = 0.0

# Store the terrain-aligned basis separately
var terrain_basis: Basis

func _ready():
	Engine.time_scale = 1.0
	# Initialize terrain basis
	terrain_basis = transform.basis
	
	if fl_ray:
		fl_ray.collision_changed.connect(_on_collision_changed)
	if fr_ray:
		fr_ray.collision_changed.connect(_on_collision_changed)
	if bl_ray:
		bl_ray.collision_changed.connect(_on_collision_changed)
	if br_ray:
		br_ray.collision_changed.connect(_on_collision_changed)
	
	if capture_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	grounded_state_changed.connect(_on_grounded_state_changed)
	
func _input(event):
		# Add this to the existing _input function
	if event.is_action_pressed("jump") and can_jump and is_grounded:
		# need to implement something that starts jumping 
		pass
		
	if event is InputEventMouseMotion:
		mouse_delta_x = event.relative.x
		mouse_delta_y = event.relative.y
	
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta):
	# Reset to terrain basis before any calculations
	transform.basis = terrain_basis
	
	# Handle user input
	_handle_movement(delta)
	
	# Check if any leg is touching ground
	_update_grounded_state()
	
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
	# Forward/backward movement
	var dir = Input.get_axis('ui_down', 'ui_up')
	translate(Vector3(0, 0, -dir) * move_speed * delta)
	
	# Horizontal turning
	var turn_amount = -mouse_delta_x * mouse_sensitivity
	turn_amount = clamp(turn_amount, -max_turn_speed * delta, max_turn_speed * delta)
	rotate_object_local(Vector3.UP, turn_amount)
	
	# Update terrain basis to include the rotation (only if grounded)
	if is_grounded:
		terrain_basis = transform.basis
	
	# Update pitch angle
	var pitch_amount = -mouse_delta_y * pitch_sensitivity
	current_pitch += pitch_amount
	current_pitch = clamp(current_pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))
	
	# Reset mouse deltas
	mouse_delta_x = 0.0
	mouse_delta_y = 0.0

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
	
func _update_grounded_state():
	var previous_grounded = is_grounded

	if is_grounded:
		# When grounded, lose ground contact if NO legs are touching
		is_grounded = collision_states.values().any(func(colliding): return colliding)
	else:
		# When airborne, only regain ground contact via ground ray
		if ground_ray and ground_ray.is_colliding():
			is_grounded = true
			# When regaining ground, update terrain basis to current orientation
			terrain_basis = transform.basis
			
	# Emit signal if state changed
	if previous_grounded != is_grounded:
		grounded_state_changed.emit(is_grounded)


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

func _on_collision_changed(leg_name: String, is_colliding: bool):
	collision_states[leg_name] = is_colliding

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
	
	if is_grounded == true: 
		print("break")
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
