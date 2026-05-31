# 로비 시스템 설계

**날짜:** 2026-05-31
**상태:** 승인됨
**관련 파일:** `scenes/Lobby.tscn`, `scripts/LobbyManager.gd`, `scripts/NetworkManager.gd`

---

## 목표

`join_room("TEST")` 하드코딩을 제거하고, 실제 플레이어가 닉네임을 입력하고 방을 만들거나 참가할 수 있는 로비 시스템을 구현한다.

---

## 씬 구조

```
scenes/
├── Lobby.tscn      ← 신규 (시작 씬으로 변경)
└── Main.tscn       ← 기존 유지

scripts/
├── LobbyManager.gd ← 신규
└── NetworkManager.gd ← 수정 (Presence + game_start 추가)
```

`Lobby.tscn`은 씬 전환 없이 Control 패널 show/hide로 3가지 상태를 전환한다.

---

## 화면 흐름

```
[MenuPanel]          [JoinPanel]         [WaitingPanel]
닉네임 입력      →   코드 4자리 입력   →   참가자 목록
방 만들기 버튼       확인 버튼               룸코드 표시
방 참가 버튼                                (방장만) 게임 시작 버튼
```

1. **방 만들기:** 랜덤 4글자 코드 생성 → `join_room_with_presence()` → WaitingPanel
2. **방 참가:** JoinPanel에서 코드 입력 → `join_room_with_presence()` → WaitingPanel
3. **게임 시작:** 방장 클릭 → `send_game_start()` → 모든 클라이언트 `Main.tscn` 로드

---

## LobbyManager.gd

### 상태

```gdscript
enum State { MENU, JOIN_INPUT, WAITING }

var current_state : State  = State.MENU
var is_host       : bool   = false
var my_nickname   : String = ""
var room_code     : String = ""
```

### 주요 함수

| 함수 | 설명 |
|------|------|
| `_on_create_pressed()` | 4글자 코드 생성 → `join_room_with_presence()` |
| `_on_join_pressed()` | JoinPanel 표시 |
| `_on_join_confirm()` | 입력 코드로 `join_room_with_presence()` |
| `_on_start_pressed()` | 방장만 호출 — `send_game_start()` |
| `_on_player_list_updated(players)` | 대기실 참가자 목록 UI 갱신 |
| `_on_game_start_received()` | `Main.tscn` 로드 |

### 룸코드 생성

```gdscript
func _generate_code() -> String:
    const CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ"  # I, O 제외 (혼동 방지)
    var code = ""
    for i in 4:
        code += CHARS[randi() % CHARS.length()]
    return code
```

---

## NetworkManager.gd 수정사항

### 추가 시그널

```gdscript
signal player_list_updated(players: Array)  # [{nickname, is_host, id}]
signal game_start_received
```

### 추가 함수

```gdscript
## 닉네임·호스트 여부를 Presence 메타데이터로 전송하며 채널 참가
func join_room_with_presence(room_code: String, nickname: String, is_host: bool) -> void

## 방장 전용 — game_start 이벤트 브로드캐스트
func send_game_start() -> void
```

### Supabase Presence 메타데이터 형식

```json
{
  "nickname": "펭귄킬러",
  "is_host": true,
  "player_id": "52251489..."
}
```

### 수신 이벤트 추가

`_parse_message()` 내 match 블록에 추가:

```gdscript
"game_start":
    game_start_received.emit()
```

Presence sync 수신 시 → `player_list_updated` 시그널 발행.

---

## GameManager.gd 수정사항

- `_ready()`에서 `join_room("TEST")` 제거
- NetworkManager 연결은 LobbyManager가 game_start 후 씬 전환 시 이미 완료된 상태

---

## project.godot 수정사항

```ini
run/main_scene="res://scenes/Lobby.tscn"
```

---

## 에러 처리

| 상황 | 처리 방식 |
|------|----------|
| 닉네임 공백 | 방 만들기/참가 버튼 비활성화 |
| 코드 4글자 미만 | 확인 버튼 비활성화 |
| WS 연결 실패 | "연결 실패" 라벨 표시 + 재시도 버튼 |
| 존재하지 않는 방 참가 | 채널 join 후 3초 내 Presence에 자신만 보이면 → "방이 없습니다" 안내 후 MenuPanel 복귀 |

---

## 구현 대상 파일

| 파일 | 작업 |
|------|------|
| `scenes/Lobby.tscn` | 신규 생성 |
| `scripts/LobbyManager.gd` | 신규 생성 |
| `scripts/NetworkManager.gd` | 수정 (Presence, game_start) |
| `scripts/GameManager.gd` | 수정 (join_room 제거) |
| `project.godot` | 시작 씬 변경 |

---

## 범위 외 (이번 구현 제외)

- 최대 인원 제한 UI
- 비밀번호 방
- 방 목록 브라우저
- 채팅 기능
