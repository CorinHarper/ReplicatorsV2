extends RayCast3D

signal grounded_state_changed(is_grounded: bool)

@export var require_center_ray_for_landing: bool = true
@export var wall_traversal_enabled: bool = true  # NEW
@export var surface_angle_threshold: float = 60.0  # Degrees from UP to consider "ground"

# References to leg rays (will be populated from parent)
var leg_rays: Dictionary = {}

# Reference to alignment ray manager for wall detection
var alignment_ray_manager: Node3D  # NEW

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
	
	# NEW: Get reference to alignment ray manager
	alignment_ray_manager = get_node_or_null("../AlignmentRayManager")

func _process(_delta):
	update_grounded_state()

func update_grounded_state():
	"""Main grounded state logic with wall traversal support"""
	was_grounded = is_grounded
	
	if is_grounded:
		# When grounded, lose ground contact if NO legs are touching
		is_grounded = _any_leg_touching()
		
		# NEW: If wall traversal enabled, also check if we're on a wall
		if wall_traversal_enabled and alignment_ray_manager:
			is_grounded = is_grounded or _is_on_traversable_surface()
	else:
		# When airborne, regain ground contact based on settings
		if require_center_ray_for_landing:
			# Check if center ray hits a traversable surface
			is_grounded = is_colliding() and _is_surface_traversable(get_collision_normal())
		else:
			# Can regain ground if any leg touches OR center ray hits traversable surface
			is_grounded = (is_colliding() and _is_surface_traversable(get_collision_normal())) or _any_leg_touching()
		
		# NEW: Wall landing support
		if wall_traversal_enabled and not is_grounded and alignment_ray_manager:
			# Check if alignment rays indicate we're near a wall we can land on
			if _can_land_on_wall():
				is_grounded = true
	
	# Emit signal if state changed
	if was_grounded != is_grounded:
		grounded_state_changed.emit(is_grounded)

func _any_leg_touching() -> bool:
	"""Check if any leg ray is colliding"""
	for is_colliding in collision_states.values():
		if is_colliding:
			return true
	return false

func _is_surface_traversable(normal: Vector3) -> bool:
	"""Check if a surface normal represents a traversable surface"""
	if not wall_traversal_enabled:
		# Original behavior - only near-horizontal surfaces
		var angle_from_up = rad_to_deg(acos(normal.dot(Vector3.UP)))
		return angle_from_up <= 45.0  # Traditional ground threshold
	else:
		# With wall traversal - any surface within threshold
		var angle_from_up = rad_to_deg(acos(abs(normal.dot(Vector3.UP))))
		return angle_from_up <= surface_angle_threshold

func _is_on_traversable_surface() -> bool:
	"""Check if spider is currently on a traversable surface (including walls)"""
	if not alignment_ray_manager:
		return false
	
	# Check if enough rays are hitting surfaces
	var hitting_count = alignment_ray_manager.get_hitting_ray_count()
	return hitting_count >= 2  # At least 2 rays must be hitting

func _can_land_on_wall() -> bool:
	"""Check if spider can land on a nearby wall while airborne"""
	if not alignment_ray_manager:
		return false
	
	# Get alignment normal and check if we have enough surface contact
	var hitting_count = alignment_ray_manager.get_hitting_ray_count()
	if hitting_count < 3:  # Need at least 3 rays for stable wall landing
		return false
	
	# Get the average normal from alignment rays
	var alignment_normal = alignment_ray_manager.get_alignment_normal(false)
	
	# Check if the surface is traversable
	return _is_surface_traversable(alignment_normal)

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
