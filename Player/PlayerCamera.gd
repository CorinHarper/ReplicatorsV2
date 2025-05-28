extends Camera3D

@export_group("Camera Settings")
@export var mouse_sensitivity = 0.003
@export var vertical_limit = deg_to_rad(89)  # Prevent camera from flipping

# Camera state
var rotation_input = Vector2.ZERO

func _ready():	
	# Start with captured mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Accumulate the rotation input
		rotation_input.y -= event.relative.y * mouse_sensitivity
		
		# Clamp the vertical rotation to prevent flipping
		rotation_input.y = clamp(rotation_input.y, -vertical_limit, vertical_limit)
		
		# Apply rotations
		# Horizontal rotation goes to the parent (player body)
		get_parent().rotate_y(-event.relative.x * mouse_sensitivity)
		# Vertical rotation is applied to the camera
		rotation.x = rotation_input.y
	
	# Toggle mouse capture with Escape
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Optional: Add a function to reset camera rotation
func reset_camera():
	rotation_input = Vector2.ZERO
	rotation.x = 0
	get_parent().rotation.y = 0
