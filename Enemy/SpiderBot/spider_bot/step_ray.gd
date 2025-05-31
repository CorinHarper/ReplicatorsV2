extends RayCast3D

signal collision_changed(leg_name: String, is_colliding: bool)

@export var step_target: Node3D
var was_colliding: bool = false
var is_grounded: bool = true
var default_pos: Vector3  # Store default position of step target relative to ray

func _ready():
	# Store the default LOCAL position of step target relative to this ray
	if step_target:
		default_pos = step_target.position
		print("Step Ray ", name, " default local offset: ", default_pos)

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
		# When falling, position step target at default offset from ray
		if step_target:
					# Also move the step target to stay with the IK target
			step_target.global_position = to_global(default_pos)

			# Convert local offset to global position
			#var target_global_pos = to_local(default_local_offset)
			#step_target.global_position = lerp(step_target.global_position, target_global_pos, 5.0 * delta)

func set_grounded(grounded: bool):
	is_grounded = grounded
	if grounded:
		# Re-enable the ray when grounded
		#enabled = true
		# Reset collision state to prevent false signals
		was_colliding = false
	else:
		# Disable the ray when falling
		#enabled = false
		was_colliding = false
