extends RayCast3D

signal collision_changed(leg_name: String, is_colliding: bool)

@export var step_target: Node3D
var was_colliding: bool = false

func _physics_process(delta):
	var is_currently_colliding = is_colliding()
	var hit_point = get_collision_point()
	
	if hit_point:
		step_target.global_position = hit_point
	
	# Emit signal only when collision state changes
	if is_currently_colliding != was_colliding:
		collision_changed.emit(self.name, is_currently_colliding)
		was_colliding = is_currently_colliding
