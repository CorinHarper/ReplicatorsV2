extends Camera3D

# Export variables for easy tweaking in the editor
@export var follow_distance: float = 1.0
@export var follow_height: float = .50
@export var position_smoothness: float = 5.0
@export var rotation_smoothness: float = 5.0
@onready var target = %SpiderBot

func _physics_process(delta):
	if not target:
		return
	
	# Calculate the target position based on SpiderBot's transform
	# Position the camera behind and above the SpiderBot
	var target_transform = target.global_transform
	var offset = target_transform.basis.z * follow_distance + Vector3.UP * follow_height
	var target_position = target.global_position + offset
	
	# Smoothly interpolate position
	global_position = global_position.lerp(target_position, position_smoothness * delta)
	
	# Smoothly interpolate rotation to match SpiderBot's rotation
	var target_rotation = target.global_rotation
	global_rotation = global_rotation.lerp(target_rotation, rotation_smoothness * delta)
	
	# Alternative: If you want the camera to look at the SpiderBot instead of matching rotation
	# Uncomment the following lines and comment out the rotation lerp above
	# var look_at_position = target.global_position + Vector3.UP * 2.0  # Look slightly above center
	# look_at(look_at_position, Vector3.UP)
