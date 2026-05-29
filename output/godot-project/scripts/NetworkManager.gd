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
signal position_received(player_id: String, pos: Vector3, alive: bool)
signal player_killed(target_id: String)
signal player_left(player_id: String)

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

# ─── 초기화 ──────────────────────────────────────
func _ready() -> void:
	# local_player_id는 세션마다 고유한 값으로 생성
	local_player_id = str(randi()) + str(Time.get_ticks_msec())

# ─── 공개 API ─────────────────────────────────────

## WS 연결 후 Supabase Realtime 채널 join
func join_room(p_room_code: String) -> void:
	room_code = p_room_code
	_ws = WebSocketPeer.new()

	var headers : PackedStringArray = PackedStringArray([
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY
	])

	var err := _ws.connect_to_url(SUPABASE_WS_URL, TLSOptions.client_unsafe(), headers)
	if err != OK:
		push_error("[NetworkManager] WebSocket 연결 실패: " + str(err))
		return

	_connected  = false
	_heartbeat_timer = 0.0
	print("[NetworkManager] WS 연결 시도: room=" + room_code)

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

## 내 위치를 Broadcast로 전송 (100ms마다 PlayerController가 호출)
func send_position(pos: Vector3, alive: bool) -> void:
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
				"alive": alive
			}
		},
		"ref": str(_ref_counter)
	}
	_send_json(msg)

## WebSocket 연결 종료
func leave_room() -> void:
	if _ws == null:
		return
	room_code    = ""
	_connected   = false
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
				"broadcast": {"self": true}
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

## 수신 메시지 파싱 — event=="broadcast" && payload.event=="pos" 처리
func _parse_message(text: String) -> void:
	var json := JSON.new()
	var err  := json.parse(text)
	if err != OK:
		push_warning("[NetworkManager] JSON 파싱 실패: " + text)
		return

	var data : Dictionary = json.get_data()

	# broadcast 이벤트만 처리
	if data.get("event", "") != "broadcast":
		return

	var outer_payload : Dictionary = data.get("payload", {})
	var ev : String = outer_payload.get("event", "")
	var inner : Dictionary = outer_payload.get("payload", {})

	match ev:
		"pos":
			var pid : String = str(inner.get("id", ""))
			if pid == local_player_id:
				return
			var pos := Vector3(
				float(inner.get("x", 0.0)),
				float(inner.get("y", 0.0)),
				float(inner.get("z", 0.0))
			)
			var alive : bool = bool(inner.get("alive", true))
			position_received.emit(pid, pos, alive)

		"kill":
			var target_id : String = str(inner.get("target_id", ""))
			if target_id.is_empty():
				return
			player_killed.emit(target_id)

## JSON 직렬화 후 WS 전송
func _send_json(data: Dictionary) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var text := JSON.stringify(data)
	_ws.send_text(text)
