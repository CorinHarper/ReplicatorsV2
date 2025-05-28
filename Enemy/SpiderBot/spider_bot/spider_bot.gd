extends Node3D

@export var mouse_sensitivity: float = 0.005  # Adjust this to control turn sensitivity
@export var capture_mouse: bool = true  # Whether to capture/hide the mouse cursor
var mouse_delta_x: float = 0.0

@export var move_speed: float = 2.5
@export var max_turn_speed: float = 3.0  # Radians per second

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
	
	# Capture mouse if enabled
	if capture_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		mouse_delta_x = event.relative.x
	
	# Toggle mouse capture with ESC
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
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
	
	# Calculate turn amount and clamp it
	var turn_amount = -mouse_delta_x * mouse_sensitivity
	turn_amount = clamp(turn_amount, -max_turn_speed * delta, max_turn_speed * delta)
	
	rotate_object_local(Vector3.UP, turn_amount)
	
	mouse_delta_x = 0.0
	

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
