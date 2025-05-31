extends CharacterBody3D

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
@export var body_length: float = 1.0  # Approximate length of spider body

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

# Ground detection
signal grounded_state_changed(is_grounded: bool)
var is_grounded: bool = true
@export var fall_alignment_speed: float = 5.0

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

	grounded_state_changed.connect(_on_grounded_state_changed)
	
func _input(event):
	if event is InputEventMouseMotion:
		mouse_delta_x = event.relative.x
		mouse_delta_y = event.relative.y
	
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	# Handle user input first (rotation only)
	_handle_rotation(delta)
	
	# Check if any leg is touching ground
	_update_grounded_state()
	
	# Calculate movement velocity
	var dir = Input.get_axis('ui_down', 'ui_up')
	var forward = -transform.basis.z
	velocity.x = forward.x * dir * move_speed
	velocity.z = forward.z * dir * move_speed
	
	# Apply gravity
	if not is_grounded:
		velocity.y -= gravity_strength * delta
		velocity.y = max(velocity.y, -terminal_velocity)
		_align_to_gravity(delta)
	else:
		# Small downward velocity to keep grounded
		velocity.y = -0.5
		_align_to_terrain(delta)
	
	# Move using CharacterBody3D's physics
	move_and_slide()
	
	# Apply visual pitch AFTER physics
	_apply_visual_pitch()

func _handle_rotation(delta):
	# Horizontal turning only - no transform manipulation
	var turn_amount = -mouse_delta_x * mouse_sensitivity
	turn_amount = clamp(turn_amount, -max_turn_speed * delta, max_turn_speed * delta)
	rotate_y(turn_amount)  # Use rotate_y instead of rotate_object_local
	
	# Update terrain basis to match current rotation
	terrain_basis = transform.basis
	
	# Update pitch angle (visual only)
	var pitch_amount = -mouse_delta_y * pitch_sensitivity
	current_pitch += pitch_amount
	current_pitch = clamp(current_pitch, deg_to_rad(pitch_min), deg_to_rad(pitch_max))
	
	# Reset mouse deltas
	mouse_delta_x = 0.0
	mouse_delta_y = 0.0

func _apply_visual_pitch():
	# Only apply pitch visually to child nodes, not the CharacterBody3D itself
	# This prevents physics conflicts
	if has_node("Armature"):
		var armature = $Armature
		var pitch_quaternion = Quaternion(Vector3.RIGHT, current_pitch)
		armature.transform.basis = Basis(pitch_quaternion)

func _align_to_terrain(delta):
	if not is_grounded:
		return
		
	# Use global positions for plane calculations
	var plane1 = Plane(bl_leg.global_position, fl_leg.global_position, fr_leg.global_position)
	var plane2 = Plane(fr_leg.global_position, br_leg.global_position, bl_leg.global_position)
	var avg_normal = ((plane1.normal + plane2.normal) / 2).normalized()
	
	# Only apply terrain alignment visually to child nodes
	if has_node("Armature"):
		var armature = $Armature
		var target_basis = _basis_from_normal_for_terrain(avg_normal, terrain_basis)
		
		# Smooth transition
		var current_basis = armature.transform.basis
		armature.transform.basis = lerp(current_basis, target_basis, move_speed * 2 * delta).orthonormalized()
		
		# Apply pitch on top of terrain alignment
		var pitch_quaternion = Quaternion(armature.transform.basis.x.normalized(), current_pitch)
		armature.transform.basis = Basis(pitch_quaternion) * armature.transform.basis

func _basis_from_normal_for_terrain(normal: Vector3, current_terrain_basis: Basis) -> Basis:
	var result = Basis()
	# Use the terrain basis forward direction
	result.x = normal.cross(current_terrain_basis.z)
	result.y = normal
	result.z = result.x.cross(normal)
	
	result = result.orthonormalized()
	
	return result
	
func _update_grounded_state():
	var previous_grounded = is_grounded

	if is_grounded:
		# When grounded, lose ground contact if NO legs are touching
		is_grounded = collision_states.values().any(func(colliding): return colliding)
	else:
		# When airborne, use is_on_floor() OR leg collision
		if is_on_floor() or collision_states.values().any(func(colliding): return colliding):
			is_grounded = true
			
	# Emit signal if state changed
	if previous_grounded != is_grounded:
		grounded_state_changed.emit(is_grounded)

func _align_to_gravity(delta):
	# Only apply gravity alignment to visual components
	if not has_node("Armature"):
		return
		
	var armature = $Armature
	var forward = -transform.basis.z
	
	# Create upright basis
	var target_basis = Basis()
	target_basis.y = Vector3.UP
	forward.y = 0
	forward = forward.normalized()
	
	if forward.length() < 0.1:
		forward = -transform.basis.x
		forward.y = 0
		forward = forward.normalized()
	
	target_basis.z = -forward
	target_basis.x = target_basis.y.cross(target_basis.z)
	target_basis = target_basis.orthonormalized()
	
	# Apply to armature only
	armature.transform.basis = lerp(armature.transform.basis, target_basis, fall_alignment_speed * delta).orthonormalized()

func _on_collision_changed(leg_name: String, is_colliding: bool):
	collision_states[leg_name] = is_colliding

func _on_grounded_state_changed(grounded: bool):
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
