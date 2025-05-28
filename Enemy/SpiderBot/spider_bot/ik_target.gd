# Changes to ik_target.gd:

extends Marker3D

@export var step_target: Node3D
var step_distance: float = .3
var step_speed: float = .05
@export var adjacent_target: Node3D
@export var opposite_target: Node3D

var is_stepping := false
var is_grounded: bool = true
var default_offset: Vector3
@export var retract_speed: float = 1.0

func _ready():
	# Store the default offset from owner (spider bot) to this IK target
	if owner:
		default_offset = owner.to_local(global_position)

func _process(delta):
	if is_grounded:
		# Normal stepping behavior when grounded
		if !is_stepping && !adjacent_target.is_stepping && abs(global_position.distance_to(step_target.global_position)) > step_distance:
			step()
			opposite_target.step()
	else:
		# When falling, move step target to default position relative to spider
		if step_target and owner:
			var target_global_pos = owner.to_global(default_offset)
			step_target.global_position = lerp(step_target.global_position, target_global_pos, retract_speed * delta)

func step():
	var target_pos = step_target.global_position
	var half_way = (global_position + step_target.global_position) / 2
	is_stepping = true
	
	var t = get_tree().create_tween()
	t.tween_property(self, "global_position", half_way + owner.basis.y * 0.2, step_speed)
	t.tween_property(self, "global_position", target_pos, step_speed)
	t.tween_callback(func(): is_stepping = false)

func set_grounded(grounded: bool):
	is_grounded = grounded
	# Kill any active tweens when falling
	if not grounded:
		is_stepping = false
		get_tree().create_tween().kill()  # Kill any active tween
