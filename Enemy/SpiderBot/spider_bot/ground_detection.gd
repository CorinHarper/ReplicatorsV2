extends RayCast3D

signal grounded_state_changed(is_grounded: bool)

@export var require_center_ray_for_landing: bool = true

# References to leg rays (will be populated from parent)
var leg_rays: Dictionary = {}

# Collision tracking
var collision_states: Dictionary = {
	"FrontLeftRay": false,
	"FrontRightRay": false,
	"BackLeftRay": false,
	"BackRightRay": false
}

var is_grounded: bool = true
var was_grounded: bool = true

func setup_leg_rays(step_target_container: Node3D):
	"""Connect to all leg rays in the step target container"""
	# Find all rays in the container
	leg_rays["FrontLeftRay"] = step_target_container.get_node("FrontLeftRay")
	leg_rays["FrontRightRay"] = step_target_container.get_node("FrontRightRay")
	leg_rays["BackLeftRay"] = step_target_container.get_node("BackLeftRay")
	leg_rays["BackRightRay"] = step_target_container.get_node("BackRightRay")
	
	# Connect to their collision signals
	for ray_name in leg_rays:
		var ray = leg_rays[ray_name]
		if ray and ray.has_signal("collision_changed"):
			ray.collision_changed.connect(_on_leg_collision_changed)

func _process(_delta):
	update_grounded_state()

func update_grounded_state():
	"""Main grounded state logic"""
	was_grounded = is_grounded
	
	if is_grounded:
		# When grounded, lose ground contact if NO legs are touching
		is_grounded = _any_leg_touching()
	else:
		# When airborne, regain ground contact based on settings
		if require_center_ray_for_landing:
			# Only regain ground via this center ground ray
			is_grounded = is_colliding()
		else:
			# Can regain ground if any leg touches OR center ray hits
			is_grounded = is_colliding() or _any_leg_touching()
	
	# Emit signal if state changed
	if was_grounded != is_grounded:
		grounded_state_changed.emit(is_grounded)

func _any_leg_touching() -> bool:
	"""Check if any leg ray is colliding"""
	for is_colliding in collision_states.values():
		if is_colliding:
			return true
	return false

func _on_leg_collision_changed(leg_name: String, is_colliding: bool):
	"""Handle collision state changes from leg rays"""
	collision_states[leg_name] = is_colliding

func force_ungrounded():
	"""Force the system to ungrounded state (used for jumping)"""
	is_grounded = false
	grounded_state_changed.emit(false)

func get_grounded_state() -> bool:
	"""Get current grounded state"""
	return is_grounded

func get_touching_legs_count() -> int:
	"""Get number of legs currently touching ground"""
	var count = 0
	for is_colliding in collision_states.values():
		if is_colliding:
			count += 1
	return count
