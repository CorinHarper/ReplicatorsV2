class_name DebugColorComponent
extends Node

@export var mesh_instance_path: NodePath = "MeshInstance3D"
@export var enabled: bool = true

var mesh_instance: MeshInstance3D
var original_material: StandardMaterial3D
var debug_material: StandardMaterial3D

func _ready():
	if enabled:
		call_deferred("_setup_debug_materials")

func _setup_debug_materials():
	# Try to find the MeshInstance3D
	mesh_instance = get_node(mesh_instance_path) if mesh_instance_path != NodePath() else null
	
	# If path didn't work, try to find it as a child of parent
	if not mesh_instance:
		mesh_instance = get_parent().get_node("MeshInstance3D")
	
	if not mesh_instance:
		push_error("DebugColorComponent: No MeshInstance3D found at path: " + str(mesh_instance_path))
		enabled = false
		return
	
	# Store original material
	if mesh_instance.get_surface_override_material(0):
		original_material = mesh_instance.get_surface_override_material(0).duplicate()
	else:
		# Create a new material if none exists
		original_material = StandardMaterial3D.new()
		original_material.albedo_color = Color.WHITE
	
	# Create debug material
	debug_material = original_material.duplicate()
	mesh_instance.set_surface_override_material(0, debug_material)

func set_color(color: Color):
	if enabled and debug_material:
		debug_material.albedo_color = color

func reset_color():
	if enabled and original_material and mesh_instance:
		mesh_instance.set_surface_override_material(0, original_material.duplicate())

func disable():
	enabled = false
	reset_color()

func enable():
	enabled = true
	_setup_debug_materials()
