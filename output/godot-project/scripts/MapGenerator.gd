extends Node3D

const MAP_SIZE       : float = 80.0
const WALL_HEIGHT    : float = 3.0
const WALL_THICKNESS : float = 0.5

# 장애물 에셋 경로
const TREE_A    : String = "res://assets/tree_a.glb"
const TREE_B    : String = "res://assets/tree_b.glb"
const ROCK      : String = "res://assets/rock_large.glb"
const BUSH      : String = "res://assets/bush_dense.glb"
const LOW_WALL  : String = "res://assets/low_wall.glb"
const SHED      : String = "res://assets/shed.glb"

# 장애물 배치 설정
const TREE_A_COUNT    : int   = 16
const TREE_B_COUNT    : int   = 8
const ROCK_COUNT      : int   = 10
const BUSH_COUNT      : int   = 12
const LOW_WALL_COUNT  : int   = 7
const SHED_COUNT      : int   = 2

# 맵 중앙 개방 구역 반경 (봇 군집 이동 공간)
const CENTER_CLEAR_RADIUS : float = 14.0
# 스폰 구역 보호 반경
const SPAWN_CLEAR_RADIUS  : float = 8.0

func _ready() -> void:
	_create_floor()
	_create_walls()
	_place_obstacles()

func _create_floor() -> void:
	var body      := StaticBody3D.new()
	var mesh_inst := MeshInstance3D.new()
	var col       := CollisionShape3D.new()
	var mesh      := BoxMesh.new()
	var shape     := BoxShape3D.new()

	mesh.size  = Vector3(MAP_SIZE, 0.1, MAP_SIZE)
	shape.size = Vector3(MAP_SIZE, 0.1, MAP_SIZE)
	mesh_inst.mesh = mesh

	# 잔디 색상
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.48, 0.18)
	mat.roughness    = 1.0
	mesh_inst.material_override = mat

	col.shape = shape
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

func _place_obstacles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337  # 고정 시드 — 매번 동일한 맵

	var placed : Array[Vector2] = []

	_spawn_asset(TREE_A,   TREE_A_COUNT,   rng, placed, 2.5)
	_spawn_asset(TREE_B,   TREE_B_COUNT,   rng, placed, 3.0)
	_spawn_asset(ROCK,     ROCK_COUNT,     rng, placed, 1.8)
	_spawn_asset(BUSH,     BUSH_COUNT,     rng, placed, 1.5)
	_spawn_asset(LOW_WALL, LOW_WALL_COUNT, rng, placed, 2.5)
	_spawn_asset(SHED,     SHED_COUNT,     rng, placed, 5.0)

func _spawn_asset(path: String, count: int, rng: RandomNumberGenerator,
		placed: Array[Vector2], min_gap: float) -> void:
	var res := load(path)
	if not res:
		push_warning("[MapGenerator] 로드 실패: " + path)
		return

	var half   := MAP_SIZE / 2.0 - 3.0
	var placed_count := 0
	var attempts     := 0

	while placed_count < count and attempts < count * 20:
		attempts += 1
		var x := rng.randf_range(-half, half)
		var z := rng.randf_range(-half, half)
		var pos2 := Vector2(x, z)

		# 중앙 개방 구역 제외
		if pos2.length() < CENTER_CLEAR_RADIUS:
			continue
		# 플레이어 기본 스폰 위치(0,0) 근처 제외
		if pos2.length() < SPAWN_CLEAR_RADIUS:
			continue
		# 기존 오브젝트와 간격 확인
		var too_close := false
		for p in placed:
			if pos2.distance_to(p) < min_gap:
				too_close = true
				break
		if too_close:
			continue

		placed.append(pos2)
		placed_count += 1

		var inst : Node3D = res.instantiate()
		inst.position = Vector3(x, 0.0, z)
		inst.rotation.y = rng.randf_range(0.0, TAU)
		# 약간의 크기 변화로 자연스러움 추가
		var scale_f := rng.randf_range(0.85, 1.15)
		inst.scale   = Vector3(scale_f, scale_f, scale_f)
		add_child(inst)
