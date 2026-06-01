extends Node3D

const MAP_SIZE       : float  = 80.0
const WALL_HEIGHT    : float  = 3.0
const WALL_THICKNESS : float  = 0.5
const MAP_SCENE      : String = "res://assets/map.glb"

# 코드로 콜리전 이미 생성 → 중복 스킵
const NO_COLLISION : Array[String] = [
	"Ground", "Wall_N", "Wall_S", "Wall_E", "Wall_W",
	# 크라운·덤불은 관통 허용 (플레이 방해 방지)
	"TreeA_Crown0", "TreeA_Crown1", "TreeA_Crown2",
	"TreeB_Crown1", "TreeB_Crown2",
	"Bush",
	# 지붕은 스킵 (플레이어가 올라갈 수 없는 영역)
	"Roof", "RoofMesh", "RoofMesh.001",
]

func _ready() -> void:
	_load_visual_map()
	_create_collision_floor()
	_create_collision_walls()

# ── 시각 맵 로드 + 장애물 콜리전 ────────────────────────────────────
func _load_visual_map() -> void:
	var res := load(MAP_SCENE)
	if not res:
		push_warning("[MapGenerator] map.glb 로드 실패 — 경로: " + MAP_SCENE)
		return
	var inst : Node3D = res.instantiate()
	inst.name = "MapVisual"
	add_child(inst)
	# 씬 트리 등록 완료 후 콜리전 생성
	_add_obstacle_collision.call_deferred(inst)

func _add_obstacle_collision(root: Node) -> void:
	_traverse_collision(root)

func _traverse_collision(node: Node) -> void:
	if node is MeshInstance3D and node.name not in NO_COLLISION:
		node.create_convex_collision()
	for child in node.get_children():
		_traverse_collision(child)

# ── 투명 바닥 콜리전 ─────────────────────────────────────────────────
func _create_collision_floor() -> void:
	var body  := StaticBody3D.new()
	var col   := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(MAP_SIZE, 0.2, MAP_SIZE)
	col.shape  = shape
	body.add_child(col)
	body.position.y = -0.1
	add_child(body)

# ── 투명 경계벽 콜리전 ───────────────────────────────────────────────
func _create_collision_walls() -> void:
	var half := MAP_SIZE / 2.0
	var walls : Array[Dictionary] = [
		{"pos": Vector3(0,     WALL_HEIGHT/2.0,  half), "size": Vector3(MAP_SIZE,       WALL_HEIGHT, WALL_THICKNESS)},
		{"pos": Vector3(0,     WALL_HEIGHT/2.0, -half), "size": Vector3(MAP_SIZE,       WALL_HEIGHT, WALL_THICKNESS)},
		{"pos": Vector3( half, WALL_HEIGHT/2.0,  0),    "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, MAP_SIZE)},
		{"pos": Vector3(-half, WALL_HEIGHT/2.0,  0),    "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, MAP_SIZE)},
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
