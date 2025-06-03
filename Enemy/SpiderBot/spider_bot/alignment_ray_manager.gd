extends Node3D

signal alignment_normal_calculated(normal: Vector3, confidence: float)

@export_group("Ray Configuration")
@export var ray_length: float = 0.5  # Should match spider leg reach
@export var grounded_weight: float = 0.3  # How much alignment rays affect grounded alignment (0-1)
@export var debug_draw: bool = false

# Ray references
var front_ray: RayCast3D
var back_ray: RayCast3D
var left_ray: RayCast3D
var right_ray: RayCast3D
var ground_ray: RayCast3D

# Collision tracking
var ray_hits: Dictionary = {
	"front": false,
	"back": false,
	"left": false,
	"right": false,
	"ground": false
}

var ray_normals: Dictionary = {
	"front": Vector3.UP,
	"back": Vector3.UP,
	"left": Vector3.UP,
	"right": Vector3.UP,
	"ground": Vector3.UP
}

func _ready():
	# Create the alignment rays
	_create_alignment_rays()
	
	# Get reference to existing ground ray
	ground_ray = get_node_or_null("GroundRay")
	
	if debug_draw:
		set_physics_process(true)

func _create_alignment_rays():
	# Front Ray - points forward
	front_ray = RayCast3D.new()
	front_ray.name = "FrontRay"
	front_ray.target_position = Vector3(0, 0, -ray_length)
	front_ray.enabled = true
	add_child(front_ray)
	
	# Back Ray - points backward
	back_ray = RayCast3D.new()
	back_ray.name = "BackRay"
	back_ray.target_position = Vector3(0, 0, ray_length)
	back_ray.enabled = true
	add_child(back_ray)
	
	# Left Ray - points left
	left_ray = RayCast3D.new()
	left_ray.name = "LeftRay"
	left_ray.target_position = Vector3(-ray_length, 0, 0)
	left_ray.enabled = true
	add_child(left_ray)
	
	# Right Ray - points right
	right_ray = RayCast3D.new()
	right_ray.name = "RightRay"
	right_ray.target_position = Vector3(ray_length, 0, 0)
	right_ray.enabled = true
	add_child(right_ray)
	
	print("Alignment rays created with length: ", ray_length)

func update_ray_data():
	"""Update collision data for all rays"""
	# Update each ray's hit status and normal
	_update_single_ray(front_ray, "front")
	_update_single_ray(back_ray, "back")
	_update_single_ray(left_ray, "left")
	_update_single_ray(right_ray, "right")
	
	if ground_ray:
		_update_single_ray(ground_ray, "ground")

func _update_single_ray(ray: RayCast3D, key: String):
	"""Update hit status and normal for a single ray"""
	if ray and ray.is_colliding():
		ray_hits[key] = true
		ray_normals[key] = ray.get_collision_normal()
	else:
		ray_hits[key] = false
		ray_normals[key] = Vector3.UP  # Default to up when not hitting

func get_alignment_normal(is_grounded: bool) -> Vector3:
	"""Calculate the alignment normal based on ray hits"""
	update_ray_data()
	
	var total_normal = Vector3.ZERO
	var hit_count = 0
	var confidence = 0.0
	
	if is_grounded:
		# When grounded, use ground ray as primary with weighted contribution from alignment rays
		if ray_hits["ground"]:
			total_normal += ray_normals["ground"]
			hit_count += 1
		
		# Add weighted contribution from alignment rays
		var alignment_contribution = Vector3.ZERO
		var alignment_hits = 0
		
		for key in ["front", "back", "left", "right"]:
			if ray_hits[key]:
				alignment_contribution += ray_normals[key]
				alignment_hits += 1
		
		if alignment_hits > 0:
			alignment_contribution = alignment_contribution.normalized()
			total_normal += alignment_contribution * grounded_weight
			hit_count += grounded_weight  # Weighted contribution to hit count
	else:
		# When airborne, use all rays equally
		for key in ray_hits:
			if ray_hits[key]:
				total_normal += ray_normals[key]
				hit_count += 1
	
	# Calculate final normal and confidence
	if hit_count > 0:
		total_normal = total_normal.normalized()
		confidence = float(hit_count) / 5.0  # Max 5 rays
	else:
		total_normal = Vector3.UP  # Default to up if no hits
		confidence = 0.0
	
	alignment_normal_calculated.emit(total_normal, confidence)
	return total_normal

func get_hitting_ray_count() -> int:
	"""Get number of rays currently hitting something"""
	var count = 0
	for hitting in ray_hits.values():
		if hitting:
			count += 1
	return count

func is_any_alignment_ray_hitting() -> bool:
	"""Check if any alignment ray (not ground ray) is hitting"""
	return ray_hits["front"] or ray_hits["back"] or ray_hits["left"] or ray_hits["right"]

func _physics_process(_delta):
	if debug_draw:
		_debug_draw_rays()

func _debug_draw_rays():
	"""Debug visualization of rays and normals"""
	# This would need DebugDraw3D or similar for runtime visualization
	# For now, just print status when it changes
	pass
