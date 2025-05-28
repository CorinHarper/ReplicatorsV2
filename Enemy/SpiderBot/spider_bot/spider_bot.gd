extends Node3D

@export var move_speed: float = 2.5
@export var turn_speed: float = 1.0
@export var ground_offset: float = 1.0
@export var gravity_strength: float = 9.8
@export var terminal_velocity: float = 10.0

@onready var fl_leg = $FrontLeftIKTarget
@onready var fr_leg = $FrontRightIKTarget
@onready var bl_leg = $BackLeftIKTarget
@onready var br_leg = $BackRightIKTarget

# References to step rays - adjust these paths to match your scene structure
@onready var fl_ray = $StepTargetContainer/FrontLeftRay  # Adjust path as needed
@onready var fr_ray = $StepTargetContainer/FrontRightRay  # Adjust path as needed
@onready var bl_ray = $StepTargetContainer/BackLeftRay  # Adjust path as needed
@onready var br_ray = $StepTargetContainer/BackRightRay  # Adjust path as needed

# Collision tracking
var collision_states = {
	"FrontLeftRay": false,
	"FrontRightRay": false,
	"BackLeftRay": false,
	"BackRightRay": false
}

var vertical_velocity: float = 0.0
var is_grounded: bool = true

func _ready():
	# Connect collision signals from step rays
	if fl_ray:
		fl_ray.collision_changed.connect(_on_collision_changed)
	if fr_ray:
		fr_ray.collision_changed.connect(_on_collision_changed)
	if bl_ray:
		bl_ray.collision_changed.connect(_on_collision_changed)
	if br_ray:
		br_ray.collision_changed.connect(_on_collision_changed)

func _process(delta):
	# Handle user input FIRST, before terrain alignment
	_handle_movement(delta)
	
	# Check if any leg is touching ground
	_update_grounded_state()
	
	# Apply gravity if not grounded
	if not is_grounded:
		_apply_gravity(delta)
	else:
		vertical_velocity = 0.0  # Reset vertical velocity when grounded
	
	# Only do terrain alignment if grounded
	if is_grounded == true:
		_align_to_terrain(delta)

func _update_grounded_state():
	var temp_state: bool = false
	for key in collision_states: 
		if collision_states[key] == true:
				temp_state = true
	is_grounded = temp_state #collision_states.values().any(func(colliding): return colliding)

func _apply_gravity(delta):
	# Increase downward velocity
	vertical_velocity += gravity_strength * delta
	# Clamp to terminal velocity
	vertical_velocity = min(vertical_velocity, terminal_velocity)
	
	# Apply gravity in world down direction
	translate(Vector3.DOWN * vertical_velocity * delta)

func _align_to_terrain(delta):
	var plane1 = Plane(bl_leg.global_position, fl_leg.global_position, fr_leg.global_position)
	var plane2 = Plane(fr_leg.global_position, br_leg.global_position, bl_leg.global_position)
	var avg_normal = ((plane1.normal + plane2.normal) / 2).normalized()
	
	var target_basis = _basis_from_normal(avg_normal)
	transform.basis = lerp(transform.basis, target_basis, (move_speed * 2) * delta).orthonormalized()
	
	var avg = (fl_leg.position + fr_leg.position + bl_leg.position + br_leg.position) / 4
	var target_pos = avg + transform.basis.y * ground_offset
	var distance = transform.basis.y.dot(target_pos - position)
	position = lerp(position, position + transform.basis.y * distance, move_speed * delta)

func _handle_movement(delta):
	var dir = Input.get_axis('ui_down', 'ui_up')
	translate(Vector3(0, 0, -dir) * move_speed * delta)
	
	var a_dir = Input.get_axis('ui_right', 'ui_left')
	rotate_object_local(Vector3.UP, a_dir * turn_speed * delta)
	


func _on_collision_changed(leg_name: String, is_colliding: bool):
	collision_states[leg_name] = is_colliding
	print("Leg ", leg_name, " collision: ", is_colliding)  # Debug print - remove if not needed

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
