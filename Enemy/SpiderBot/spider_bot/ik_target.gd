# Fixed ik_target.gd with proper falling behavior

extends Marker3D

@export var step_target: Node3D
var step_distance: float = .3
var step_speed: float = .05
@export var adjacent_target: Node3D
@export var opposite_target: Node3D

var is_stepping := false
var is_grounded: bool = true
var default_local_position: Vector3  # Store the initial local position relative to owner
@export var retract_speed: float = .05

func _ready():
	# Store the initial local position relative to the spider bot
	# Since top_level = true, we need to convert global position to local
	if owner:
		default_local_position = owner.to_local(global_position)
		print("IK Target ", name, " default local position: ", default_local_position)

func _process(delta):
	if is_grounded:
		# Normal stepping behavior when grounded
		if !is_stepping && !adjacent_target.is_stepping && abs(global_position.distance_to(step_target.global_position)) > step_distance:
			step()
			opposite_target.step()
	else:
		# When falling, move IK target to its default position underneath the spider
		if owner:
			fall()
			# Convert local position back to global based on spider's current transform
		#	var target_global_pos = owner.to_global(default_local_position)
		#	global_position = lerp(global_position, target_global_pos, retract_speed * delta)
			
			# Also move the step target to stay with the IK target
		#	if step_target:
			

func step():
	var target_pos = step_target.global_position
	var half_way = (global_position + step_target.global_position) / 2
	is_stepping = true
	
	var t = get_tree().create_tween()
	t.tween_property(self, "global_position", half_way + owner.basis.y * 0.2, step_speed)
	t.tween_property(self, "global_position", target_pos, step_speed)
	t.tween_callback(func(): is_stepping = false)
	
func fall():
	var target_pos = step_target.global_position
	#var half_way = (global_position + step_target.global_position) / 2
	#is_stepping = true
	
	var t = get_tree().create_tween()
	#t.tween_property(self, "global_position", half_way + owner.basis.y * 1.0, retract_speed)
	t.tween_property(self, "global_position", target_pos, retract_speed)
	#t.tween_callback(func(): is_stepping = false)

func set_grounded(grounded: bool):
	print("IK Target ", name, " grounded state changed to: ", grounded)
	is_grounded = grounded
	# Kill any active tweens when falling
	if not grounded:
		is_stepping = false
		var tween = get_tree().create_tween()
		if tween:
			tween.kill()
