extends Node3D

const MAP_SIZE       : float = 50.0
const WALL_HEIGHT    : float = 3.0
const WALL_THICKNESS : float = 0.5

func _ready() -> void:
	_create_floor()
	_create_walls()

func _create_floor() -> void:
	var body      := StaticBody3D.new()
	var mesh_inst := MeshInstance3D.new()
	var col       := CollisionShape3D.new()
	var mesh      := BoxMesh.new()
	var shape     := BoxShape3D.new()

	mesh.size  = Vector3(MAP_SIZE, 0.1, MAP_SIZE)
	shape.size = Vector3(MAP_SIZE, 0.1, MAP_SIZE)
	mesh_inst.mesh = mesh
	col.shape      = shape
	body.add_child(mesh_inst)
	body.add_child(col)
	add_child(body)

func _create_walls() -> void:
	var half := MAP_SIZE / 2.0
	var walls : Array[Dictionary] = [
		{"pos": Vector3(0,    WALL_HEIGHT / 2.0,  half), "size": Vector3(MAP_SIZE,       WALL_HEIGHT, WALL_THICKNESS)},
		{"pos": Vector3(0,    WALL_HEIGHT / 2.0, -half), "size": Vector3(MAP_SIZE,       WALL_HEIGHT, WALL_THICKNESS)},
		{"pos": Vector3( half, WALL_HEIGHT / 2.0, 0),    "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, MAP_SIZE)},
		{"pos": Vector3(-half, WALL_HEIGHT / 2.0, 0),    "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, MAP_SIZE)},
	]
	for w in walls:
		var body      := StaticBody3D.new()
		var mesh_inst := MeshInstance3D.new()
		var col       := CollisionShape3D.new()
		var mesh      := BoxMesh.new()
		var shape     := BoxShape3D.new()

		mesh.size      = w["size"]
		shape.size     = w["size"]
		mesh_inst.mesh = mesh
		col.shape      = shape
		body.position  = w["pos"]
		body.add_child(mesh_inst)
		body.add_child(col)
		add_child(body)
