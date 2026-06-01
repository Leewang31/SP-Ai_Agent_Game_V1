extends CharacterBody3D

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  상수
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
const MOVE_SPEED        : float = 5.0
const SPRINT_MULTIPLIER : float = 1.8
const JUMP_VELOCITY     : float = 4.5
const GRAVITY           : float = 9.8
const ATTACK_RANGE      : float = 2.0
const CAM_DISTANCE      : float = 6.0
var mouse_sensitivity : float = 0.003
const CAM_PITCH_MIN     : float = -1.22
const CAM_PITCH_MAX     : float =  0.35

const MODEL_PATH  : String = "res://assets/penguin.glb"
const MODEL_SCALE : float  = 0.65
const MODEL_Y     : float  = -1.0

# 루프 재생할 애니메이션 목록
const LOOP_ANIMS  : Array  = ["Penguin_Idle", "Penguin_Move", "Penguin_Run"]

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  상태 정의
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
enum State { IDLE, MOVE, RUN, ATTACK, DIE }

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  노드 참조
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@onready var spring_arm : SpringArm3D = $SpringArm3D

var _state : State         = State.IDLE
var _anim  : AnimationPlayer = null

# 네트워크 위치 전송 타이머
var kill_count   : int   = 0
var _net_timer   : float = 0.0
const NET_INTERVAL : float = 0.1  # 100ms

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  초기화
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _ready() -> void:
	spring_arm.spring_length = CAM_DISTANCE
	spring_arm.rotation.x    = deg_to_rad(-25.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_spawn_penguin()
	NetworkManager.player_killed.connect(_on_player_killed)

func _on_player_killed(target_id: String) -> void:
	if target_id == NetworkManager.local_player_id:
		die()

func _spawn_penguin() -> void:
	var res := load(MODEL_PATH)
	if not res:
		push_warning("[Player] penguin.glb 로드 실패 – MODEL_PATH: " + MODEL_PATH)
		return

	var model : Node3D = res.instantiate()
	model.name               = "PenguinModel"
	model.rotation_degrees.y = 180.0        # Blender -Y → Godot +Z 보정
	model.scale              = Vector3.ONE * MODEL_SCALE
	model.position.y         = MODEL_Y      # 발 위치를 캡슐 하단에 맞춤
	add_child(model)

	# AnimationPlayer 탐색 (GLB 내부 경로가 버전마다 다를 수 있음)
	_anim = _find_anim_player(model)
	if not _anim:
		push_warning("[Player] AnimationPlayer를 GLB 안에서 찾지 못했습니다")
		return

	# 루프 애니메이션 설정
	for anim_name in LOOP_ANIMS:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

	# 공격 애니메이션 종료 콜백
	_anim.animation_finished.connect(_on_anim_finished)
	_play_anim("Penguin_Idle")

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  입력
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _input(event: InputEvent) -> void:
	if _state == State.DIE:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, CAM_PITCH_MIN, CAM_PITCH_MAX)
	elif event.is_action_pressed("ui_cancel") and not event.is_echo():
		var hud := get_parent().get_node_or_null("HUD")
		if hud:
			hud.toggle_pause_menu()
	elif event.is_action_pressed("attack") and not event.is_echo():
		_do_attack()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  물리 처리
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _physics_process(delta: float) -> void:
	if _state == State.DIE:
		return

	# 중력
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# 점프
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 이동
	var input_dir   := _get_input_dir()
	var is_sprint   := Input.is_action_pressed("sprint")
	var forward     := -transform.basis.z
	var right       := transform.basis.x
	var move_dir    := (forward * input_dir.y + right * input_dir.x)
	var speed       := MOVE_SPEED * (SPRINT_MULTIPLIER if is_sprint else 1.0)
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	move_and_slide()

	# 애니메이션 상태 갱신 (공격 중이 아닐 때)
	if _state != State.ATTACK:
		_update_state(input_dir, is_sprint)

	# 네트워크 위치 전송 (100ms 간격)
	_net_timer += delta
	if _net_timer >= NET_INTERVAL:
		_net_timer = 0.0
		if NetworkManager.room_code != "":
			NetworkManager.send_position(global_position, rotation.y, _state != State.DIE)

func _get_input_dir() -> Vector2:
	return Input.get_vector(
		"move_left", "move_right", "move_backward", "move_forward"
	).normalized()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  애니메이션 상태 머신
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
func _update_state(input_dir: Vector2, sprint: bool) -> void:
	var new_state := State.IDLE
	if input_dir.length() > 0.1:
		new_state = State.RUN if sprint else State.MOVE
	if new_state == _state:
		return
	_state = new_state
	_play_anim(_anim_name(_state))

func _do_attack() -> void:
	if _state == State.ATTACK:
		return
	_state = State.ATTACK
	_play_anim("Penguin_Attack")

	# 봇 타격
	for bot in get_tree().get_nodes_in_group("bots"):
		if global_position.distance_to(bot.global_position) <= ATTACK_RANGE:
			if bot.has_method("take_hit"):
				bot.take_hit()
			break

	# 원격 플레이어 타격: kill 이벤트 브로드캐스트 → 피격자 클라이언트가 자신을 die()
	# NOTE: 서버 권위 없이 공격자 클라이언트를 신뢰하는 구조. MVP 한계.
	for remote in get_tree().get_nodes_in_group("remote_players"):
		if global_position.distance_to(remote.global_position) <= ATTACK_RANGE:
			NetworkManager.send_kill(remote.player_id)
			kill_count += 1
			break

func die() -> void:
	if _state == State.DIE:
		return
	_state = State.DIE
	velocity = Vector3.ZERO
	_play_anim("Penguin_Die")
	var hud := get_parent().get_node_or_null("HUD")
	if hud:
		hud.show_death_screen()

func _on_anim_finished(anim_name: String) -> void:
	if anim_name == "Penguin_Attack":
		_state = State.IDLE
		_play_anim("Penguin_Idle")

func _play_anim(anim_name: String) -> void:
	if not _anim:
		return
	if not _anim.has_animation(anim_name):
		push_warning("[Player] 애니메이션 없음: " + anim_name)
		return
	if _anim.current_animation == anim_name:
		return
	_anim.play(anim_name)

func _anim_name(state: State) -> String:
	match state:
		State.IDLE:   return "Penguin_Idle"
		State.MOVE:   return "Penguin_Move"
		State.RUN:    return "Penguin_Run"
		State.ATTACK: return "Penguin_Attack"
		State.DIE:    return "Penguin_Die"
	return "Penguin_Idle"
