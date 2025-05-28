extends CharacterBody3D

# Navigation properties
@export var speed: float = 3.0
@export var rotation_speed: float = 5.0
@export var link_traversal_speed: float = 1.0
var player: Node3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var debug_color: DebugColorComponent = $DebugColorComponent

# Spider IK properties
@export var move_speed: float = 5.0
@export var turn_speed: float = 1.0
@export var ground_offset: float = 1.0
@onready var fl_leg = $FrontLeftIKTarget
@onready var fr_leg = $FrontRightIKTarget
@onready var bl_leg = $BackLeftIKTarget
@onready var br_leg = $BackRightIKTarget

# State colors
const COLOR_FOLLOWING = Color.GREEN
const COLOR_NO_PATH = Color.RED
const COLOR_TRAVERSING_LINK = Color.BLUE

# Link traversal state
var is_traversing_link: bool = false
var link_start_position: Vector3
var link_end_position: Vector3
var link_progress: float = 0.0

func _ready():
	player = get_tree().get_first_node_in_group("Player")
	
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	nav_agent.link_reached.connect(_on_link_reached)
	
	nav_agent.target_desired_distance = 1.0
	nav_agent.radius = 0.5
	nav_agent.path_desired_distance = 0.5
	
	# Debug navigation map
	call_deferred("_check_navigation")

func _check_navigation():
	var nav_map = nav_agent.get_navigation_map()
	print("Navigation map active: ", NavigationServer3D.map_is_active(nav_map))
	print("Navigation layers: ", nav_agent.navigation_layers)

func _process(delta):
	# Handle IK and terrain following (preserve original spider logic)
	_handle_ik_and_terrain(delta)
	
	# Handle navigation movement
	_handle_navigation_movement(delta)

func _handle_ik_and_terrain(delta):
	# Original spider IK logic - calculate terrain following
	var plane1 = Plane(bl_leg.global_position, fl_leg.global_position, fr_leg.global_position)
	var plane2 = Plane(fr_leg.global_position, br_leg.global_position, bl_leg.global_position)
	var avg_normal = ((plane1.normal + plane2.normal) / 2).normalized()
	
	# Preserve the current scale before modifying the basis
	var current_scale = transform.basis.get_scale()
	
	var target_basis = basis_from_normal(avg_normal)
	transform.basis = lerp(transform.basis, target_basis, move_speed * delta).orthonormalized()
	
	# Reapply the scale after basis calculation
	transform.basis = transform.basis.scaled(current_scale)
	
	var avg = (fl_leg.position + fr_leg.position + bl_leg.position + br_leg.position) / 4
	var target_pos = avg + transform.basis.y * ground_offset
	var distance = transform.basis.y.dot(target_pos - position)
	position = lerp(position, position + transform.basis.y * distance, move_speed * delta)

func _handle_navigation_movement(delta):
	if not player:
		debug_color.set_color(COLOR_NO_PATH)
		return
	
	# Handle link traversal separately
	if is_traversing_link:
		_handle_link_traversal(delta)
		return
	
	# Normal navigation
	nav_agent.target_position = player.global_position
	
	# Set color based on path status
	if nav_agent.is_navigation_finished() or not nav_agent.is_target_reachable():
		debug_color.set_color(COLOR_NO_PATH)
		return
	else:
		debug_color.set_color(COLOR_FOLLOWING)
	
	var next_path_position = nav_agent.get_next_path_position()
	var navigation_direction = (next_path_position - global_position).normalized()
	
	# Convert navigation direction to spider leg movement
	_apply_navigation_to_spider_movement(navigation_direction, delta)

func _apply_navigation_to_spider_movement(nav_direction: Vector3, delta: float):
	# Calculate forward/backward movement based on navigation direction
	# Convert world direction to local direction relative to spider's transform
	var local_direction = transform.basis.inverse() * nav_direction
	
	# Extract forward/backward component (local Z axis)
	var forward_input = -local_direction.z  # Negative because forward is -Z in Godot
	
	# Extract left/right turning component (local X axis)
	var turn_input = local_direction.x
	
	# Apply movement the same way as the original spider controller
	translate(Vector3(0, 0, -forward_input) * move_speed * delta)
	
	# Apply turning
	rotate_object_local(Vector3.UP, turn_input * turn_speed * delta)

func _on_link_reached(details: Dictionary):
	print("Link reached! Details: ", details)
	
	# Start link traversal
	is_traversing_link = true
	link_start_position = details.link_entry_position
	link_end_position = details.link_exit_position
	link_progress = 0.0
	
	debug_color.set_color(COLOR_TRAVERSING_LINK)
	
	# Optional: Face the link direction immediately
	var link_direction = (link_end_position - link_start_position).normalized()
	if link_direction.length() > 0.1:
		# Convert to spider's rotation system
		var local_link_dir = transform.basis.inverse() * link_direction
		var turn_amount = atan2(local_link_dir.x, -local_link_dir.z)
		rotate_object_local(Vector3.UP, turn_amount)

func _handle_link_traversal(delta: float):
	# Calculate progress along the link
	var link_distance = link_start_position.distance_to(link_end_position)
	var movement_distance = link_traversal_speed * delta
	
	if link_distance > 0:
		link_progress += movement_distance / link_distance
	
	# Move along the link path
	if link_progress >= 1.0:
		# Link traversal complete
		global_position = link_end_position
		is_traversing_link = false
		link_progress = 0.0
		
		# Resume normal navigation
		debug_color.set_color(COLOR_FOLLOWING)
		print("Link traversal completed")
	else:
		# Interpolate position along link
		global_position = link_start_position.lerp(link_end_position, link_progress)
		
		# Apply spider movement during link traversal
		var link_direction = (link_end_position - link_start_position).normalized()
		var local_direction = transform.basis.inverse() * link_direction
		var forward_input = -local_direction.z
		translate(Vector3(0, 0, -forward_input) * move_speed * delta)
	
	# Clear velocity during link traversal
	velocity = Vector3.ZERO
	move_and_slide()

func _on_velocity_computed(safe_velocity: Vector3):
	# Not used anymore since we're letting the IK system handle positioning
	pass

func basis_from_normal(normal: Vector3) -> Basis:
	var result = Basis()
	result.x = normal.cross(transform.basis.z)
	result.y = normal
	result.z = transform.basis.x.cross(normal)
	result = result.orthonormalized()
	# Scale is now handled separately in _handle_ik_and_terrain()
	
	return result
