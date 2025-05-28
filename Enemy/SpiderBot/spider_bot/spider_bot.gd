extends Node3D

@export var move_speed: float = 1.0
@export var turn_speed: float = 3.0
@export var ground_offset: float = 0.15
@export var gravity_strength: float = -9.8
@export var terminal_velocity: float = 100.0
@export var mouse_sensitivity: float = 0.005
@export var capture_mouse: bool = true
@export var max_turn_speed: float = 2.0
@export var pitch_min: float = -85.0  # Reduced from 90 to prevent gimbal lock
@export var pitch_max: float = 85.0   # Reduced from 90 to prevent gimbal lock
@export var pitch_sensitivity: float = 0.005

@onready var fl_leg = $FrontLeftIKTarget
@onready var fr_leg = $FrontRightIKTarget
@onready var bl_leg = $BackLeftIKTarget
@onready var br_leg = $BackRightIKTarget

@onready var fl_ray = $StepTargetContainer/FrontLeftRay
@onready var fr_ray = $StepTargetContainer/FrontRightRay
@onready var bl_ray = $StepTargetContainer/BackLeftRay
@onready var br_ray = $StepTargetContainer/BackRightRay

var collision_states = {
	"FrontLeftRay": false,
	"FrontRightRay": false,
	"BackLeftRay": false,
	"BackRightRay": false
}

var vertical_velocity: float = 0.0
var is_grounded: bool = true
var mouse_delta_x: float = 0.0
var mouse_delta_y: float = 0.0
var current_pitch: float = 0.0

# Store the terrain-aligned basis separately
var terrain_basis: Basis

func _ready():
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

func _input(event):
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
	
	# Apply visual pitch as the final step
	_apply_visual_pitch()

func _handle_movement(delta):
	# Forward/backward movement
	var dir = Input.get_axis('ui_down', 'ui_up')
	translate(Vector3(0, 0, -dir) * move_speed * delta)
	
	# Horizontal turning
	var turn_amount = -mouse_delta_x * mouse_sensitivity
	turn_amount = clamp(turn_amount, -max_turn_speed * delta, max_turn_speed * delta)
	rotate_object_local(Vector3.UP, turn_amount)
	
	# Update terrain basis to include the rotation
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
	
	# Position adjustment
	var avg = (fl_leg.position + fr_leg.position + bl_leg.position + br_leg.position) / 4
	var target_pos = avg + transform.basis.y * ground_offset
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
	var temp_state: bool = false
	for key in collision_states: 
		if collision_states[key] == true:
			temp_state = true
	is_grounded = temp_state

func _apply_gravity(delta):
	vertical_velocity += gravity_strength * delta
	vertical_velocity = min(vertical_velocity, terminal_velocity)
	translate(to_global(Vector3.DOWN) * vertical_velocity * delta)

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
