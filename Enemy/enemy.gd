extends CharacterBody3D

@export var speed: float = 3.0
@export var rotation_speed: float = 5.0
@export var link_traversal_speed: float = 1  # Speed when crossing links
var player: Node3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var debug_color: DebugColorComponent = $DebugColorComponent

# State colors
const COLOR_FOLLOWING = Color.GREEN
const COLOR_NO_PATH = Color.RED
const COLOR_TRAVERSING_LINK = Color.BLUE

# Link traversal statea
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

func _physics_process(delta):
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
	else:
		debug_color.set_color(COLOR_FOLLOWING)
	
	if nav_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	var next_path_position = nav_agent.get_next_path_position()
	var direction = (next_path_position - global_position).normalized()
	
	# Handle rotation
	if direction.length() > 0.1:
		var target_basis = Basis.looking_at(direction, Vector3.UP)
		basis = basis.slerp(target_basis, rotation_speed * delta)
	
	var desired_velocity = direction * speed
	
	if nav_agent.avoidance_enabled:
		nav_agent.velocity = desired_velocity
	else:
		_on_velocity_computed(desired_velocity)

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
		basis = Basis.looking_at(link_direction, Vector3.UP)

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
	
	# Clear velocity during link traversal
	velocity = Vector3.ZERO
	move_and_slide()

func _on_velocity_computed(safe_velocity: Vector3):
	# Only apply velocity if not traversing a link
	if not is_traversing_link:
		velocity = safe_velocity
		move_and_slide()
