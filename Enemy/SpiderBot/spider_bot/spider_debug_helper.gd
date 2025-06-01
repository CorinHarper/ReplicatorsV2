# Debug helper - attach to spider bot temporarily
extends Node

@export var enable_debug: bool = true
@export var print_interval: float = 0.5

var time_since_last_print: float = 0.0
var spider: Node3D
var gravity_handler: Node
var alignment_manager: Node3D
var ground_ray: RayCast3D

func _ready():
	spider = get_parent()
	gravity_handler = spider.get_node_or_null("GravityHandler")
	alignment_manager = spider.get_node_or_null("AlignmentRayManager")
	ground_ray = spider.get_node_or_null("Armature/AlignmentRayManager/GroundRay")

func _process(delta):
	if not enable_debug:
		return
		
	time_since_last_print += delta
	if time_since_last_print >= print_interval:
		time_since_last_print = 0.0
		print_debug_info()

func print_debug_info():
	print("\n=== Spider Debug Info ===")
	print("Is Grounded: ", spider.is_grounded)
	print("Is Jumping: ", spider.is_jumping)
	print("Can Jump: ", spider.can_jump)
	
	if gravity_handler:
		print("Gravity Active: ", gravity_handler.is_active)
		print("Velocity: ", gravity_handler.velocity)
		print("Should Align to Gravity: ", gravity_handler.should_align_to_gravity())
	
	if alignment_manager:
		print("Hitting Rays: ", alignment_manager.get_hitting_ray_count())
		print("Ray Hits: ", alignment_manager.ray_hits)
	
	if ground_ray:
		print("Ground Ray Hitting: ", ground_ray.is_colliding())
		print("Leg Touch Count: ", ground_ray.get_touching_legs_count())
	
	print("Global Position Y: ", spider.global_position.y)
	print("========================\n")
