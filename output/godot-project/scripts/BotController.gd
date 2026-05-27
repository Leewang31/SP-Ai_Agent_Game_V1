extends CharacterBody3D

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  상수
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
const MOVE_SPEED     : float = 5.0
const JUMP_VELOCITY  : float = 4.5
const GRAVITY        : float = 9.8
const FALL_DURATION  : float = 2.5   # die 애니(65f/24fps ≈ 2.7s)
const DIR_CHANGE_MIN : float = 1.5
const DIR_CHANGE_MAX : float = 3.5
const JUMP_MIN       : float = 2.0
const JUMP_MAX       : float = 5.0

const MODEL_PATH  : String = "res://assets/penguin.glb"
const MODEL_SCALE : float  = 0.65
const MODEL_Y     : float  = -1.0
const LOOP_ANIMS  : Array  = ["Penguin_Idle", "Penguin_Move", "Penguin_Run"]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  노드 / 변수
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var jump_timer : Timer = $JumpTimer

var _move_dir  : Vector3       = Vector3.ZERO
var _is_fallen : bool          = false
var _dir_timer : float         = 0.0
var _anim      : AnimationPlayer = null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  초기화
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _ready() -> void:
	add_to_group("bots")
	jump_timer.timeout.connect(_on_jump_timer_timeout)
	_change_direction()
	_start_jump_timer()
	_spawn_penguin()

func _spawn_penguin() -> void:
	var res := load(MODEL_PATH)
	if not res:
		return
	var model : Node3D = res.instantiate()
	model.name               = "PenguinModel"
	model.rotation_degrees.y = 180.0
	model.scale              = Vector3.ONE * MODEL_SCALE
	model.position.y         = MODEL_Y
	add_child(model)

	_anim = _find_anim_player(model)
	if not _anim:
		return

	for anim_name in LOOP_ANIMS:
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  물리 처리
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _physics_process(delta: float) -> void:
	if _is_fallen:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	_dir_timer -= delta
	if _dir_timer <= 0.0:
		_change_direction()

	velocity.x = _move_dir.x * MOVE_SPEED
	velocity.z = _move_dir.z * MOVE_SPEED

	# 이동 방향으로 회전 (펭귄 모델이 180° 보정이 되어 있으므로 그대로 사용)
	if _move_dir.length() > 0.1:
		look_at(global_position + _move_dir, Vector3.UP)

	move_and_slide()

func _change_direction() -> void:
	var angle  := randf() * TAU
	_move_dir   = Vector3(cos(angle), 0.0, sin(angle))
	_dir_timer  = randf_range(DIR_CHANGE_MIN, DIR_CHANGE_MAX)

func _start_jump_timer() -> void:
	jump_timer.wait_time = randf_range(JUMP_MIN, JUMP_MAX)
	jump_timer.one_shot  = true
	jump_timer.start()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  피격 / 사망
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func take_hit() -> void:
	if _is_fallen:
		return
	_is_fallen = true
	velocity   = Vector3.ZERO
	_play_anim("Penguin_Die")
	get_tree().create_timer(FALL_DURATION).timeout.connect(queue_free)

func _on_jump_timer_timeout() -> void:
	if not _is_fallen and is_on_floor():
		velocity.y = JUMP_VELOCITY
	_start_jump_timer()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  애니메이션 헬퍼
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _play_anim(anim_name: String) -> void:
	if not _anim or not _anim.has_animation(anim_name):
		return
	if _anim.current_animation == anim_name:
		return
	_anim.play(anim_name)
