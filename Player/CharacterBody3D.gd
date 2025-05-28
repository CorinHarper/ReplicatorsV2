extends CharacterBody3D

@export_group("Movement Settings")
@export var WALK_SPEED = 5.0
@export var SPRINT_SPEED = 8.0
@export var JUMP_VELOCITY = 4.5
@export var ACCELERATION = 15.0
@export var DECELERATION = 20.0
@export var AIR_CONTROL = 0.3

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


@onready var head = $Head
@onready var ray_cast = %RayCast3D

func _process(delta):
	# Check if raycast is colliding with something
	if ray_cast.is_colliding():
		var collider = ray_cast.get_collider()
		
		# Check if the collider is an Area3D
	
		# Check if the Area3D belongs to a button (you might want to use groups here)
		var interactable = collider.get_parent()
		if interactable.is_in_group("interactable"):
	
			# Show a prompt to press E (optional)
			# $PromptUI.visible = true
			
			# Check for E key press
			if Input.is_action_just_pressed("interact"):  # Define this in Project Settings > Input Map
				interactable.interact()


func _ready():
	# Lock mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	# Add the gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get movement input direction
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Transform input direction based on player's orientation
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Get current horizontal velocity
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	
	# Set target speed based on sprint
#	var target_speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var target_speed = WALK_SPEED	
	# Handle acceleration and deceleration
	if direction:
		# Calculate target velocity
		var target_velocity = direction * target_speed
		
		# Apply different acceleration based on ground/air state
		var accel = ACCELERATION if is_on_floor() else (ACCELERATION * AIR_CONTROL)
		
		# Interpolate current horizontal velocity towards target
		horizontal_velocity = horizontal_velocity.lerp(target_velocity, accel * delta)
	else:
		# Apply deceleration when no input
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, DECELERATION * delta)
	
	# Apply horizontal velocity
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	
	move_and_slide()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
