# Architecture Review — 작업 목표 #001: 펭귄 기본 프로토타입

> 범위: 50×50 맵, 펭귄 플레이어(캡슐), 봇 10마리, Shift 달리기, 우클릭 공격, 점프

---

## 1. 씬 트리 구조

### Main.tscn (전면 재구성)

```
res://scenes/Main.tscn
└── Node3D  (이름: Main, 루트)
    ├── WorldEnvironment
    ├── DirectionalLight3D
    ├── MapGenerator  [Node3D]          # script: MapGenerator.gd — 맵 코드 생성
    ├── Player  [CharacterBody3D]       # script: PlayerController.gd
    │   ├── MeshInstance3D              # CapsuleMesh (펭귄 플레이스홀더)
    │   ├── CollisionShape3D            # CapsuleShape3D
    │   └── SpringArm3D
    │       └── Camera3D
    └── GameManager  [Node]             # script: GameManager.gd — 봇 스폰
```

### Bot.tscn (신규 — 별도 씬)

```
res://scenes/Bot.tscn
└── CharacterBody3D  (이름: Bot)        # script: BotController.gd
    ├── MeshInstance3D                  # CapsuleMesh (플레이어와 동일 외형)
    ├── CollisionShape3D                # CapsuleShape3D
    └── JumpTimer  [Timer]              # 무작위 점프 주기 타이머
```

**씬 수: 2개** (`Main.tscn`, `Bot.tscn`)

---

## 2. 스크립트 목록

| 파일 | 연결 노드 | 경로 | 핵심 책임 |
|------|-----------|------|-----------|
| `PlayerController.gd` | Player (CharacterBody3D) | `res://scripts/PlayerController.gd` | WASD 이동, Shift 달리기, 스페이스 점프, 우클릭 공격 |
| `BotController.gd` | Bot (CharacterBody3D) | `res://scripts/BotController.gd` | 무작위 이동, 점프, take_hit() 처리 |
| `MapGenerator.gd` | MapGenerator (Node3D) | `res://scripts/MapGenerator.gd` | 50×50 바닥 + 4면 경계 벽 코드 생성 |
| `GameManager.gd` | GameManager (Node) | `res://scripts/GameManager.gd` | Bot.tscn 10회 인스턴스화 + 랜덤 배치 |

---

## 3. 공유 상수 (수치 확정)

| 상수 | 값 | 적용 대상 |
|------|----|----------|
| `MOVE_SPEED` | `5.0` m/s | 플레이어 = 봇 (동일) |
| `SPRINT_MULTIPLIER` | `1.8` | 플레이어만 |
| `JUMP_VELOCITY` | `4.5` m/s | 플레이어 = 봇 (동일) |
| `GRAVITY` | `9.8` m/s² | 플레이어 = 봇 |
| `ATTACK_RANGE` | `2.0` m | PlayerController |
| `BOT_FALL_DURATION` | `2.0` 초 | BotController |
| `BOT_COUNT` | `10` | GameManager |
| `MAP_SIZE` | `50.0` m | MapGenerator |
| `WALL_HEIGHT` | `3.0` m | MapGenerator |
| `WALL_THICKNESS` | `0.5` m | MapGenerator |

---

## 4. 스크립트별 핵심 시그니처

### PlayerController.gd

```gdscript
extends CharacterBody3D

const MOVE_SPEED        : float = 5.0
const SPRINT_MULTIPLIER : float = 1.8
const JUMP_VELOCITY     : float = 4.5
const GRAVITY           : float = 9.8
const ATTACK_RANGE      : float = 2.0
const CAM_DISTANCE      : float = 6.0
const MOUSE_SENSITIVITY : float = 0.003
const CAM_PITCH_MIN     : float = -1.22
const CAM_PITCH_MAX     : float =  0.35

@onready var spring_arm : SpringArm3D = $SpringArm3D

func _ready() -> void
# SpringArm 초기화, 마우스 캡처

func _input(event: InputEvent) -> void
# 마우스 회전 처리, ESC 마우스 모드 토글, 우클릭 감지 → _do_attack()

func _physics_process(delta: float) -> void
# 중력, 점프, 이동 (Shift 달리기 적용), move_and_slide()

func _get_input_direction() -> Vector2
# Input.get_vector(move_left, move_right, move_backward, move_forward).normalized()

func _do_attack() -> void
# get_tree().get_nodes_in_group("bots") 순회
# 거리 < ATTACK_RANGE 인 봇에 take_hit() 호출
```

### BotController.gd

```gdscript
extends CharacterBody3D

const MOVE_SPEED      : float = 5.0   # PlayerController.MOVE_SPEED와 동일 수치
const JUMP_VELOCITY   : float = 4.5   # PlayerController.JUMP_VELOCITY와 동일 수치
const GRAVITY         : float = 9.8
const FALL_DURATION   : float = 2.0
const DIR_CHANGE_MIN  : float = 1.5   # 방향 변경 최소 간격 (초)
const DIR_CHANGE_MAX  : float = 3.5   # 방향 변경 최대 간격 (초)
const JUMP_MIN        : float = 2.0   # 점프 최소 간격 (초)
const JUMP_MAX        : float = 5.0   # 점프 최대 간격 (초)

@onready var jump_timer : Timer = $JumpTimer

var _move_dir   : Vector3 = Vector3.ZERO
var _is_fallen  : bool    = false
var _dir_timer  : float   = 0.0

func _ready() -> void
# add_to_group("bots"), _change_direction(), jump_timer 시작

func _physics_process(delta: float) -> void
# fallen 상태면 조기 return
# 중력, 이동, 방향 타이머, move_and_slide()

func _change_direction() -> void
# 랜덤 XZ 방향 벡터 생성 → _move_dir 갱신
# _dir_timer = randf_range(DIR_CHANGE_MIN, DIR_CHANGE_MAX)

func take_hit() -> void
# _is_fallen = true, velocity = ZERO
# get_tree().create_timer(FALL_DURATION).timeout → queue_free()

func _on_jump_timer_timeout() -> void
# is_on_floor() 이면 velocity.y = JUMP_VELOCITY
# jump_timer.wait_time = randf_range(JUMP_MIN, JUMP_MAX), start()
```

### MapGenerator.gd

```gdscript
extends Node3D

const MAP_SIZE       : float = 50.0
const WALL_HEIGHT    : float = 3.0
const WALL_THICKNESS : float = 0.5

func _ready() -> void
# _create_floor(), _create_walls()

func _create_floor() -> void
# StaticBody3D + BoxMesh(MAP_SIZE, 0.1, MAP_SIZE) + BoxShape3D 코드 생성 후 add_child

func _create_walls() -> void
# 4면(North/South/East/West) 각각 StaticBody3D + BoxMesh + BoxShape3D 생성
# 위치: ±MAP_SIZE/2 경계
```

### GameManager.gd

```gdscript
extends Node

const BOT_COUNT  : int   = 10
const SPAWN_AREA : float = 20.0   # 맵 중앙 기준 랜덤 스폰 범위 (±20m)

@export var bot_scene : PackedScene

func _ready() -> void
# _spawn_bots()

func _spawn_bots() -> void
# BOT_COUNT번 반복:
#   bot = bot_scene.instantiate()
#   bot.position = Vector3(randf_range(-SPAWN_AREA, SPAWN_AREA), 1.0, randf_range(-SPAWN_AREA, SPAWN_AREA))
#   get_parent().add_child(bot)
```

---

## 5. 입력 맵 추가 항목 (project.godot)

기존 입력 맵에 아래 2개 추가:

| 액션명 | 입력 | 비고 |
|--------|------|------|
| `sprint` | Left Shift (physical_keycode=4194325) | 달리기 |
| `attack` | Mouse Button Right (button_index=2) | 우클릭 공격 |

---

## 6. 시스템 간 소통 방식

- **공격 판정**: PlayerController → `get_tree().get_nodes_in_group("bots")` → `take_hit()` 직접 호출
  - 이유: 단순 프로토타입. Signal 구독 대비 코드 복잡도 ↓
- **봇 스폰**: GameManager → `bot_scene.instantiate()` → `get_parent().add_child(bot)`
  - 이유: 씬 인스턴스화 후 Main 씬 트리에 직접 편입. Autoload 불필요.
- **팀 간 소통**: Signal 없음. 단방향 호출만 사용.

---

## 7. 디렉토리 구조 (최종)

```
res://
├── project.godot
├── scenes/
│   ├── Main.tscn          # 전면 재구성
│   └── Bot.tscn           # 신규
└── scripts/
    ├── PlayerController.gd # 기존 → Shift 달리기 + 우클릭 공격 추가
    ├── BotController.gd    # 전면 재작성
    ├── MapGenerator.gd     # 신규
    └── GameManager.gd      # 신규
```

---

## 8. 주요 설계 결정

1. **MapGenerator 코드 생성 방식** — `_ready()`에서 StaticBody3D를 코드로 생성. 씬 파일에 박아두지 않아 맵 크기 수정이 상수 하나로 가능.
2. **Bot.tscn 분리** — GameManager가 PackedScene으로 인스턴스화. 봇 수 변경 시 GameManager 상수만 수정.
3. **그룹 "bots"** — BotController._ready()에서 `add_to_group("bots")`. 공격 판정 시 get_nodes_in_group으로 O(N) 탐색. 봇 10마리 수준에서 성능 문제 없음.
4. **fallen 상태** — `_is_fallen` 플래그로 이동/점프 차단. create_timer(2.0) 후 queue_free. 간단하고 안전.
5. **Main.tscn 재구성** — 기존 20×20 맵/벽 노드 제거. MapGenerator가 코드로 대체 생성.
