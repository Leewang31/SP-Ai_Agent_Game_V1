# Game Exit Screens — Design Spec

**Date:** 2026-06-01  
**Scope:** 승리 화면, ESC 설정창, 사망 화면  
**Status:** Approved

---

## 확정된 공통 스타일

모든 화면에 **Frosted Glass 오버레이** 적용.
- 배경: `rgba(10, 20, 15, 0.72)` + `backdrop-filter: blur(14px)`
- 테두리: `rgba(255, 255, 255, 0.14)` 1px
- 모서리: `border-radius: 16px`
- 그림자: `box-shadow: 0 8px 32px rgba(0,0,0,0.4)`

Godot 구현 시 `CanvasLayer` + `Panel` + `StyleBoxFlat`으로 근사치 구현 (Godot 4는 backdrop-filter 미지원 → 반투명 패널로 대체).

---

## ① 승리 화면

### 트리거
- `GameManager._check_win_condition()` — 마지막 원격 플레이어 사망/퇴장 시

### 레이아웃
- 화면 중앙 Frosted Glass 패널
- 트로피 이모지 (🏆) + "승리!" 타이틀
- 부제: "최후의 1인으로 살아남았습니다"
- 통계 2줄 (생존 시간 / 처치 수)
- 버튼: **로비로 돌아가기** (초록 primary)

### 동작
- 패널 표시 시 마우스 캡처 해제 (`Input.MOUSE_MODE_VISIBLE`)
- "로비로 돌아가기" → `NetworkManager.leave_room()` → `get_tree().change_scene_to_file("res://scenes/Lobby.tscn")`
- 승리 화면 표시 중 키보드/마우스 게임 입력 차단 (PlayerController 비활성화)

### 통계 데이터
- 생존 시간: `NetworkManager.game_start_received` 시그널 수신 시점을 `GameManager`가 `Time.get_ticks_msec()`으로 기록 → 승리 시 차이 계산
- 처치 수: `PlayerController._do_attack()` 성공 시 카운터 증가

---

## ② ESC 설정창

### 트리거
- `PlayerController._input()` — ESC 키 (`ui_cancel`) 입력 시
- 기존 ESC 동작(마우스 캡처 토글) 대체

### 레이아웃
- 화면 중앙 Frosted Glass 패널 (세로형, 너비 약 240px)
- 타이틀: "설정"
- 마우스 감도 슬라이더 (HSlider, 0.001 ~ 0.010, 기본 0.003)
- 버튼: **계속하기** (반투명 secondary)
- 버튼: **게임 나가기** (빨간 danger — `rgba(239,68,68,0.2)` 배경, `#f87171` 텍스트)

### 동작
- 설정창 열릴 때: `Input.MOUSE_MODE_VISIBLE`, 게임 물리 일시정지 (`get_tree().paused = true`)
- 계속하기: 설정창 닫기, `Input.MOUSE_MODE_CAPTURED`, 일시정지 해제
- 게임 나가기: `NetworkManager.leave_room()` → Lobby 씬으로 이동
- ESC 재입력 시 설정창 닫기 (토글)
- 감도 슬라이더 변경 즉시 `PlayerController.MOUSE_SENSITIVITY` 반영

### 참고
- `MOUSE_SENSITIVITY`는 현재 `const`로 선언됨 → `var`로 변경 필요
- `get_tree().paused = true` 적용 시 `NetworkManager`와 `HUD`의 `process_mode`를 `PROCESS_MODE_ALWAYS`로 설정해야 WebSocket poll과 입력 처리가 유지됨

---

## ③ 사망 화면

### 트리거
- `PlayerController.die()` 호출 시

### 레이아웃
- **상단**: 작은 배지 `💀 사망` (붉은 반투명, 중앙 상단 고정)
- **하단**: 얇은 바 (Frosted Glass, 상단 붉은 테두리 1px)
  - 좌: "사망했습니다" + "다른 플레이어를 관전 중..." 부제
  - 우: **게임 나가기** 버튼 (danger 스타일)
- 게임 월드는 계속 렌더링 (카메라 자유 이동 가능)

### 동작
- `die()` 호출 시: 마우스 캡처 해제, 사망 UI 표시
- 카메라 제어: 죽은 후에도 SpringArm3D 마우스 회전 유지 (위치 이동만 차단)
- 게임 나가기: `NetworkManager.leave_room()` → Lobby 씬으로 이동
- 사망 화면에서 ESC 눌러도 설정창 열리지 않음 (나가기 버튼만 제공)

---

## 공통 동작 규칙

| 화면 | 마우스 모드 | 물리 일시정지 | ESC 동작 |
|------|-----------|------------|---------|
| 승리 | VISIBLE | 아니오 | 무시 |
| 설정창 | VISIBLE | 예 | 닫기 |
| 사망 | VISIBLE | 아니오 | 무시 |

---

## Godot 구현 구조

```
Main.tscn
└── HUD (CanvasLayer)
    ├── WinScreen (Control) — 기본 hidden
    │   └── Panel + VBoxContainer (트로피, 텍스트, 버튼)
    ├── PauseMenu (Control) — 기본 hidden
    │   └── Panel + VBoxContainer (타이틀, 슬라이더, 버튼들)
    └── DeathHUD (Control) — 기본 hidden
        ├── DeathBadge (Panel, 상단 중앙 앵커)
        └── DeathBar (Panel, 하단 앵커)
```

- `HUD.gd` 신규 스크립트 — 세 화면 show/hide 제어
- `GameManager.gd` — 승리 판정 시 `HUD.show_win_screen(stats)` 호출
- `PlayerController.gd` — `die()` 시 `HUD.show_death_screen()`, ESC 시 `HUD.toggle_pause_menu()`

---

## 미구현 / 추후 고려

- 승리 화면 파티클 효과 (confetti) — Phase 2
- 사망 후 관전 카메라 자동 전환 (다른 생존 플레이어 추적) — Phase 2
- 볼륨 슬라이더 — Phase 2
- 조작키 안내 — Phase 2
