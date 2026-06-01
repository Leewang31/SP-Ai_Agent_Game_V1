# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  GameManager.gd
#  역할    : 게임 전체 흐름 관리. 봇 스폰, 원격 플레이어 동적 스폰/해제,
#            승리 조건 판정.
#  연결 노드: NetworkManager (AutoLoad 싱글톤)
#  주요 시그널:
#    NetworkManager.position_received → _on_position_received
#    NetworkManager.player_left       → _on_player_left
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
extends Node

const BOT_COUNT   : int   = 10
const SPAWN_AREA  : float = 20.0
const BOT_SCENE           = preload("res://scenes/Bot.tscn")
const REMOTE_PLAYER_SCENE = preload("res://scripts/RemotePlayer.gd")

var _remote_players   : Dictionary = {}  # player_id (String) -> RemotePlayer 노드
var _game_started     : bool       = false
var _ever_seen_players : int       = 0   # 한 번이라도 접속한 원격 플레이어 수
var _game_start_time : int = 0

func _ready() -> void:
	_game_start_time = Time.get_ticks_msec()
	_spawn_bots()
	NetworkManager.position_received.connect(_on_position_received)
	NetworkManager.player_killed.connect(_on_player_killed)
	NetworkManager.player_left.connect(_on_player_left)

# ─── 봇 스폰 ─────────────────────────────────────
func _spawn_bots() -> void:
	for i in BOT_COUNT:
		var bot : CharacterBody3D = BOT_SCENE.instantiate()
		bot.position = Vector3(
			randf_range(-SPAWN_AREA, SPAWN_AREA),
			1.0,
			randf_range(-SPAWN_AREA, SPAWN_AREA)
		)
		get_parent().call_deferred("add_child", bot)

# ─── 공개 API ─────────────────────────────────────

## 특정 방 코드로 Supabase Realtime 채널에 참가
func join_room(room_code: String) -> void:
	NetworkManager.join_room(room_code)

# ─── NetworkManager 시그널 핸들러 ─────────────────

## 원격 플레이어 위치 수신 시 호출.
## 처음 수신된 player_id면 RemotePlayer 노드를 동적 스폰.
func _on_position_received(player_id: String, pos: Vector3, rot_y: float, alive: bool) -> void:
	if not _remote_players.has(player_id):
		var rp := CharacterBody3D.new()
		rp.set_script(REMOTE_PLAYER_SCENE)
		rp.player_id = player_id
		add_child(rp)
		_remote_players[player_id] = rp
		_ever_seen_players += 1
		if _ever_seen_players >= 1:  # 상대 1명 이상 만나면 게임 시작
			_game_started = true

	_remote_players[player_id].update_position(pos, rot_y, alive)

## kill 이벤트 수신 — 타겟 RemotePlayer 제거 + 승리 판정
func _on_player_killed(target_id: String) -> void:
	if not _remote_players.has(target_id):
		return
	_remote_players[target_id].queue_free()
	_remote_players.erase(target_id)
	_check_win_condition()

## 원격 플레이어 퇴장 (미래 확장 — phx_leave 파싱 시 사용)
func _on_player_left(player_id: String) -> void:
	if _remote_players.has(player_id):
		_remote_players[player_id].queue_free()
		_remote_players.erase(player_id)
	_check_win_condition()

# ─── 승리 조건 ────────────────────────────────────

## 게임이 시작된 후 원격 플레이어가 모두 사라지면 승리
func _check_win_condition() -> void:
	if not _game_started:
		return
	if not _remote_players.is_empty():
		return
	var elapsed_sec : float = (Time.get_ticks_msec() - _game_start_time) / 1000.0
	var player := get_parent().get_node_or_null("Player")
	var kills  : int = player.kill_count if player else 0
	var hud    := get_parent().get_node_or_null("HUD")
	if hud:
		hud.show_win_screen(elapsed_sec, kills)
