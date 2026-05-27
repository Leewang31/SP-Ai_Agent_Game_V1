extends CharacterBody3D

const MOVE_SPEED     : float = 5.0
const JUMP_VELOCITY  : float = 4.5
const GRAVITY        : float = 9.8
const FALL_DURATION  : float = 1.0
const DIR_CHANGE_MIN : float = 1.5
const DIR_CHANGE_MAX : float = 3.5
const JUMP_MIN       : float = 2.0
const JUMP_MAX       : float = 5.0

@onready var jump_timer : Timer = $JumpTimer
@onready var mesh       : MeshInstance3D = $MeshInstance3D

var _move_dir  : Vector3 = Vector3.ZERO
var _is_fallen : bool    = false
var _dir_timer : float   = 0.0

func _ready() -> void:
	add_to_group("bots")
	jump_timer.timeout.connect(_on_jump_timer_timeout)
	_change_direction()
	_start_jump_timer()

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

	move_and_slide()

func _change_direction() -> void:
	var angle := randf() * TAU
	_move_dir = Vector3(cos(angle), 0.0, sin(angle))
	_dir_timer = randf_range(DIR_CHANGE_MIN, DIR_CHANGE_MAX)

func _start_jump_timer() -> void:
	jump_timer.wait_time = randf_range(JUMP_MIN, JUMP_MAX)
	jump_timer.one_shot = true
	jump_timer.start()

func take_hit() -> void:
	if _is_fallen:
		return
	_is_fallen = true
	velocity = Vector3.ZERO
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.15)
	mesh.material_override = mat
	get_tree().create_timer(FALL_DURATION).timeout.connect(queue_free)

func _on_jump_timer_timeout() -> void:
	if not _is_fallen and is_on_floor():
		velocity.y = JUMP_VELOCITY
	_start_jump_timer()
