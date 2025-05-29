extends Node3D

@export var offset: float = 5.0

@onready var parent = get_parent_node_3d()
@onready var previous_position = parent.global_position

func _process(delta):
	var velocity = parent.global_position - previous_position
	global_position = parent.global_position + velocity * offset
	
	previous_position = parent.global_position
	
	# Compensate ONLY for parent's pitch to keep rays pointing at consistent angles
	if parent and parent.has_method("_get_current_pitch") and parent.has_method("_get_terrain_basis"):
		var parent_pitch = parent._get_current_pitch()
		var terrain_basis = parent._get_terrain_basis()
		
		# Simply use the terrain basis - it already has the correct yaw but no pitch
		global_transform.basis = terrain_basis
