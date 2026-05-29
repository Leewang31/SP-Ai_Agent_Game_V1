# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  RemotePlayer.gd
#  역할    : 원격 플레이어 위치 수신 + 선형 보간으로 부드러운 이동 표시.
#            GameManager가 position_received 시그널 수신 시 동적 스폰.
#  연결 노드: GameManager (스폰/해제), NetworkManager (위치 데이터 공급)
#  주요 시그널: 없음 (위치 수신은 GameManager를 통해 update_position 호출)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class_name RemotePlayer
extends CharacterBody3D

# ─── 상수 ────────────────────────────────────────
const MODEL_PATH  : String = "res://assets/penguin.glb"
const MODEL_SCALE : float  = 0.65
const MODEL_Y     : float  = -1.0
const LERP_SPEED  : float  = 10.0

# ─── 변수 ────────────────────────────────────────
var player_id    : String  = ""
var alive        : bool    = true

var _target_pos  : Vector3 = Vector3.ZERO
var _initialized : bool    = false  # 첫 위치 수신 전까지 숨김
var _anim        : AnimationPlayer = null

# ─── 초기화 ──────────────────────────────────────
func _ready() -> void:
	add_to_group("remote_players")
	visible = false  # 첫 위치 수신 전까지 숨김 (원점 순간이동 방지)
	_spawn_penguin()

func _spawn_penguin() -> void:
	var res := load(MODEL_PATH)
	if not res:
		push_warning("[RemotePlayer] penguin.glb 로드 실패 – MODEL_PATH: " + MODEL_PATH)
		return

	var model : Node3D = res.instantiate()
	model.name               = "PenguinModel"
	model.rotation_degrees.y = 180.0        # Blender -Y → Godot +Z 보정
	model.scale              = Vector3.ONE * MODEL_SCALE
	model.position.y         = MODEL_Y      # 발 위치를 캡슐 하단에 맞춤
	add_child(model)

	# AnimationPlayer 탐색
	_anim = _find_anim_player(model)
	if not _anim:
		push_warning("[RemotePlayer] AnimationPlayer를 GLB 안에서 찾지 못했습니다")
		return

	# 루프 애니메이션 설정
	for anim_name in ["Penguin_Idle", "Penguin_Move", "Penguin_Run"]:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

	_play_anim("Penguin_Move")

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null

# ─── 물리 처리 ────────────────────────────────────

## 매 물리 프레임마다 목표 위치로 선형 보간 이동
func _physics_process(delta: float) -> void:
	global_position = global_position.lerp(_target_pos, LERP_SPEED * delta)

# ─── 공개 API ─────────────────────────────────────

## GameManager가 NetworkManager 시그널 수신 후 호출.
## queue_free()는 GameManager가 담당 — 이 함수는 위치/상태 갱신만.
func update_position(pos: Vector3, is_alive: bool) -> void:
	if not _initialized:
		# 첫 수신: 보간 없이 순간이동 후 표시
		global_position = pos
		_target_pos     = pos
		_initialized    = true
		visible         = true
	else:
		_target_pos = pos

	alive = is_alive
	if not alive:
		_play_anim("Penguin_Die")

# ─── 내부 유틸 ────────────────────────────────────
func _play_anim(anim_name: String) -> void:
	if not _anim:
		return
	if not _anim.has_animation(anim_name):
		return
	if _anim.current_animation == anim_name:
		return
	_anim.play(anim_name)
