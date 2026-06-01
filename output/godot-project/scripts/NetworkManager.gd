# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  NetworkManager.gd
#  역할    : AutoLoad 싱글톤. Supabase Realtime WebSocket 연결 관리.
#            Phoenix channel 프로토콜(phx_join / broadcast / heartbeat) 처리.
#  연결 노드: (AutoLoad 전역 싱글톤 — 씬 트리 독립)
#  주요 시그널:
#    position_received(player_id, pos, alive) — 원격 플레이어 위치 수신
#    player_killed(target_id)                 — 특정 플레이어 사망 알림
#    player_left(player_id)                   — 원격 플레이어 퇴장 (미래 확장용)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
extends Node

# ─── 시그널 ───────────────────────────────────────
signal position_received(player_id: String, pos: Vector3, rot_y: float, alive: bool)
signal player_killed(target_id: String)
signal player_left(player_id: String)
signal player_list_updated(players: Array)
signal game_start_received
signal host_left_received

# ─── 상수 ────────────────────────────────────────
const SUPABASE_ANON_KEY : String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndncXh2dmZicW9paWNsbWdqYWRhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAwMzE3NTYsImV4cCI6MjA5NTYwNzc1Nn0.9GtMYNvclgleKkBA-68LH2V16HZdkrUkSKj2QBAerhU"
const SUPABASE_WS_URL   : String = "wss://wgqxvvfbqoiiclmgjada.supabase.co/realtime/v1/websocket?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndncXh2dmZicW9paWNsbWdqYWRhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAwMzE3NTYsImV4cCI6MjA5NTYwNzc1Nn0.9GtMYNvclgleKkBA-68LH2V16HZdkrUkSKj2QBAerhU&vsn=1.0.0"

const HEARTBEAT_INTERVAL : float = 30.0

# ─── 변수 ────────────────────────────────────────
var room_code        : String          = ""
var local_player_id  : String          = ""

var _ws              : WebSocketPeer   = null
var _ref_counter     : int             = 0
var _heartbeat_timer : float           = 0.0
var _connected       : bool            = false

var _my_nickname      : String     = ""
var _my_is_host       : bool       = false
var _presence_tracked : bool       = false
var _current_players  : Dictionary = {}

# ─── 초기화 ──────────────────────────────────────
func _ready() -> void:
	# local_player_id는 세션마다 고유한 값으로 생성
	local_player_id = str(randi()) + str(Time.get_ticks_msec())

# ─── 공개 API ─────────────────────────────────────

## WS 연결 후 Supabase Realtime 채널 join
func join_room(p_room_code: String) -> void:
	room_code = p_room_code
	_ws = WebSocketPeer.new()

	_ws.handshake_headers = PackedStringArray([
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY
	])

	var err := _ws.connect_to_url(SUPABASE_WS_URL, TLSOptions.client())
	if err != OK:
		push_error("[NetworkManager] WebSocket 연결 실패: " + str(err))
		return

	_connected  = false
	_heartbeat_timer = 0.0
	print("[NetworkManager] WS 연결 시도: room=" + room_code)

## 게임 시작 이벤트 브로드캐스트 (호스트가 호출)
func send_game_start() -> void:
	if not _connected:
		return
	_ref_counter += 1
	var msg : Dictionary = {
		"topic":   "realtime:game-room-" + room_code,
		"event":   "broadcast",
		"payload": {"event": "game_start", "payload": {}},
		"ref":     str(_ref_counter)
	}
	_send_json(msg)

## 방장 퇴장 알림 브로드캐스트 (방 폭파)
func send_host_left() -> void:
	if not _connected:
		return
	_ref_counter += 1
	var msg : Dictionary = {
		"topic":   "realtime:game-room-" + room_code,
		"event":   "broadcast",
		"payload": {"event": "host_left", "payload": {}},
		"ref":     str(_ref_counter)
	}
	_send_json(msg)

## 특정 플레이어를 죽이는 kill 이벤트 브로드캐스트
func send_kill(target_player_id: String) -> void:
	if not _connected:
		return
	_ref_counter += 1
	var msg : Dictionary = {
		"topic":   "realtime:game-room-" + room_code,
		"event":   "broadcast",
		"payload": {
			"event": "kill",
			"payload": {
				"killer_id": local_player_id,
				"target_id": target_player_id
			}
		},
		"ref": str(_ref_counter)
	}
	_send_json(msg)

## 내 위치+회전을 Broadcast로 전송 (100ms마다 PlayerController가 호출)
func send_position(pos: Vector3, rot_y: float, alive: bool) -> void:
	if not _connected:
		return

	_ref_counter += 1
	var msg : Dictionary = {
		"topic":   "realtime:game-room-" + room_code,
		"event":   "broadcast",
		"payload": {
			"event": "pos",
			"payload": {
				"id":    local_player_id,
				"x":     pos.x,
				"y":     pos.y,
				"z":     pos.z,
				"rot_y": rot_y,
				"alive": alive
			}
		},
		"ref": str(_ref_counter)
	}
	_send_json(msg)

## Presence 정보(닉네임, 호스트 여부)와 함께 룸에 참여
func join_room_with_presence(p_room_code: String, nickname: String, is_host: bool) -> void:
	_my_nickname      = nickname
	_my_is_host       = is_host
	_presence_tracked = false
	_current_players  = {}
	join_room(p_room_code)

## 현재 대기실 참가자 수 반환 (LobbyManager가 방 존재 확인에 사용)
func get_current_player_count() -> int:
	return _current_players.size()

## WebSocket 연결 종료
func leave_room() -> void:
	if _ws == null:
		return
	room_code         = ""
	_connected        = false
	_presence_tracked = false
	_current_players.clear()
	_ws.close()
	_ws = null
	print("[NetworkManager] WS 연결 종료")

# ─── 내부 처리 ────────────────────────────────────

func _process(delta: float) -> void:
	if _ws == null:
		return

	_ws.poll()

	var state := _ws.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				_on_ws_connected()

			# 수신 메시지 처리
			while _ws.get_available_packet_count() > 0:
				var raw   := _ws.get_packet()
				var text  := raw.get_string_from_utf8()
				_parse_message(text)

			# Heartbeat 타이머
			_heartbeat_timer += delta
			if _heartbeat_timer >= HEARTBEAT_INTERVAL:
				_heartbeat_timer = 0.0
				_send_heartbeat()

		WebSocketPeer.STATE_CLOSING:
			pass  # 닫히는 중 — 무시

		WebSocketPeer.STATE_CLOSED:
			var code   := _ws.get_close_code()
			var reason := _ws.get_close_reason()
			push_warning("[NetworkManager] WS 닫힘 code=%d reason=%s" % [code, reason])
			_connected = false
			_ws = null

## WS 연결 완료 시 Phoenix phx_join 전송
func _on_ws_connected() -> void:
	print("[NetworkManager] WS 연결 성공. 채널 join: game-room-" + room_code)
	_ref_counter += 1
	var join_msg : Dictionary = {
		"topic":   "realtime:game-room-" + room_code,
		"event":   "phx_join",
		"payload": {
			"config": {
				"broadcast": {"self": true},
				"presence":  {"key": local_player_id}
			}
		},
		"ref": str(_ref_counter)
	}
	_send_json(join_msg)

## 30초 주기 Heartbeat 전송 (연결 유지)
func _send_heartbeat() -> void:
	_ref_counter += 1
	var hb : Dictionary = {
		"topic":   "phoenix",
		"event":   "heartbeat",
		"payload": {},
		"ref":     str(_ref_counter)
	}
	_send_json(hb)

## Presence track 이벤트 전송 — phx_reply ok 수신 후 1회 호출
## + Broadcast lobby_announce 동시 전송 (Presence 누락 대비 폴백)
func _send_presence_track() -> void:
	if _my_nickname.is_empty() or not _connected:
		return
	_ref_counter += 1
	var msg : Dictionary = {
		"topic":   "realtime:game-room-" + room_code,
		"event":   "presence",
		"payload": {
			"event": "track",
			"payload": {
				"nickname":  _my_nickname,
				"is_host":   _my_is_host,
				"player_id": local_player_id
			}
		},
		"ref": str(_ref_counter)
	}
	_send_json(msg)
	_send_lobby_announce()

## 내 정보를 Broadcast로 알림 (Presence 누락 폴백 + 핸드셰이크)
func _send_lobby_announce() -> void:
	if _my_nickname.is_empty() or not _connected:
		return
	_ref_counter += 1
	var announce : Dictionary = {
		"topic":   "realtime:game-room-" + room_code,
		"event":   "broadcast",
		"payload": {
			"event": "lobby_announce",
			"payload": {
				"player_id": local_player_id,
				"nickname":  _my_nickname,
				"is_host":   _my_is_host
			}
		},
		"ref": str(_ref_counter)
	}
	_send_json(announce)

## presence_diff 처리 — joins/leaves 반영
func _update_presence_from_diff(diff: Dictionary) -> void:
	var joins  : Dictionary = diff.get("joins",  {})
	var leaves : Dictionary = diff.get("leaves", {})
	for pid in joins:
		var metas : Array = joins[pid].get("metas", [])
		if metas.is_empty():
			continue
		var meta : Dictionary = metas[0]
		_current_players[pid] = {
			"player_id": meta.get("player_id", pid),
			"nickname":  meta.get("nickname",  ""),
			"is_host":   meta.get("is_host",   false)
		}
	for pid in leaves:
		_current_players.erase(pid)

## 수신 메시지 파싱 — Phoenix 이벤트 전체 처리
func _parse_message(text: String) -> void:
	var json := JSON.new()
	if json.parse(text) != OK:
		return

	var data  : Dictionary = json.get_data()
	var event : String     = data.get("event", "")

	match event:
		"phx_reply":
			var status : String = data.get("payload", {}).get("status", "")
			if status == "ok" and not _presence_tracked and not _my_nickname.is_empty():
				_presence_tracked = true
				_send_presence_track()

		"presence_state":
			_current_players.clear()
			var payload : Dictionary = data.get("payload", {})
			for pid in payload:
				var metas : Array = payload[pid].get("metas", [])
				if metas.is_empty():
					continue
				var meta : Dictionary = metas[0]
				_current_players[pid] = {
					"player_id": meta.get("player_id", pid),
					"nickname":  meta.get("nickname",  ""),
					"is_host":   meta.get("is_host",   false)
				}
			player_list_updated.emit(_current_players.values())

		"presence_diff":
			_update_presence_from_diff(data.get("payload", {}))
			player_list_updated.emit(_current_players.values())

		"broadcast":
			var outer_payload : Dictionary = data.get("payload", {})
			var ev            : String     = outer_payload.get("event", "")
			var inner         : Dictionary = outer_payload.get("payload", {})
			match ev:
				"pos":
					var pid : String = str(inner.get("id", ""))
					if pid.is_empty() or pid == local_player_id:
						return
					var pos := Vector3(
						float(inner.get("x", 0.0)),
						float(inner.get("y", 0.0)),
						float(inner.get("z", 0.0))
					)
					var rot_y := float(inner.get("rot_y", 0.0))
					position_received.emit(pid, pos, rot_y, bool(inner.get("alive", true)))
				"kill":
					var target_id : String = str(inner.get("target_id", ""))
					if not target_id.is_empty():
						player_killed.emit(target_id)
				"game_start":
					game_start_received.emit()
				"host_left":
					host_left_received.emit()
				"lobby_announce":
					var pid : String = str(inner.get("player_id", ""))
					if pid.is_empty() or pid == local_player_id:
						return
					var is_new : bool = not _current_players.has(pid)
					_current_players[pid] = {
						"player_id": pid,
						"nickname":  inner.get("nickname",  ""),
						"is_host":   inner.get("is_host",   false)
					}
					player_list_updated.emit(_current_players.values())
					# 처음 보는 플레이어면 내 정보도 알려줌 (핸드셰이크 — 1회만)
					if is_new:
						_send_lobby_announce()

## JSON 직렬화 후 WS 전송
func _send_json(data: Dictionary) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var text := JSON.stringify(data)
	_ws.send_text(text)
