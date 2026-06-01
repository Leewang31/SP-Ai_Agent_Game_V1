extends Node3D

# 맵 전체를 map.glb로 표현. 물리 콜리전은 코드로 생성(바닥/벽).
const MAP_SIZE       : float  = 80.0
const WALL_HEIGHT    : float  = 3.0
const WALL_THICKNESS : float  = 0.5
const MAP_SCENE      : String = "res://assets/map.glb"

func _ready() -> void:
	_load_visual_map()
	_create_collision_floor()
	_create_collision_walls()

# ── 시각 맵 로드 ─────────────────────────────────────────────────────
func _load_visual_map() -> void:
	var res := load(MAP_SCENE)
	if not res:
		push_warning("[MapGenerator] map.glb 로드 실패 — 경로: " + MAP_SCENE)
		return
	var inst : Node3D = res.instantiate()
	inst.name = "MapVisual"
	add_child(inst)

# ── 투명 바닥 콜리전 (플레이어 낙하 방지) ────────────────────────────
func _create_collision_floor() -> void:
	var body  := StaticBody3D.new()
	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(MAP_SIZE, 0.2, MAP_SIZE)
	col.shape  = shape
	body.add_child(col)
	body.position.y = -0.1
	add_child(body)

# ── 투명 경계벽 콜리전 (맵 이탈 방지) ───────────────────────────────
func _create_collision_walls() -> void:
	var half := MAP_SIZE / 2.0
	var walls : Array[Dictionary] = [
		{"pos": Vector3(0,    WALL_HEIGHT / 2.0,  half), "size": Vector3(MAP_SIZE,       WALL_HEIGHT, WALL_THICKNESS)},
		{"pos": Vector3(0,    WALL_HEIGHT / 2.0, -half), "size": Vector3(MAP_SIZE,       WALL_HEIGHT, WALL_THICKNESS)},
		{"pos": Vector3( half, WALL_HEIGHT / 2.0, 0),    "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, MAP_SIZE)},
		{"pos": Vector3(-half, WALL_HEIGHT / 2.0, 0),    "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, MAP_SIZE)},
	]
	for w in walls:
		var body  := StaticBody3D.new()
		var col   := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = w["size"]
		col.shape  = shape
		body.position = w["pos"]
		body.add_child(col)
		add_child(body)
