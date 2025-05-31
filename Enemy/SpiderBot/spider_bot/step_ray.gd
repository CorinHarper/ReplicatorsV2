extends RayCast3D

signal collision_changed(leg_name: String, is_colliding: bool)

@export var step_target: Node3D
var was_colliding: bool = false
var is_grounded: bool = true
var default_offset: Vector3

func _ready():
	# Store default LOCAL position of step target relative to spider bot
	if step_target and owner:
		# Convert step target's global position to local position relative to owner (spider)
		default_offset = owner.to_local(step_target.global_position)

func _physics_process(delta):
	if is_grounded:
		# Normal ray behavior when grounded
		var is_currently_colliding = is_colliding()
		
		if is_currently_colliding:
			var hit_point = get_collision_point()
			step_target.global_position = hit_point
		
		# Emit signal only when collision state changes
		if is_currently_colliding != was_colliding:
			was_colliding = is_currently_colliding
			collision_changed.emit(self.name, is_currently_colliding)
	else:
		# When falling, lerp step target to default position
		if step_target and owner:
			# Use the ray's global position as the target for the step target
			# This keeps the step target directly below the ray
			step_target.global_position = lerp(step_target.global_position, global_position, 3.0 * delta)

func set_grounded(grounded: bool):
	is_grounded = grounded
	if grounded:
		# Re-enable the ray when grounded
		enabled = true
		# Reset collision state to prevent false signals
		was_colliding = false
	else:
		# Disable the ray when falling
		enabled = false
		was_colliding = false
