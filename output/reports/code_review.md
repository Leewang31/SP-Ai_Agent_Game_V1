# Code Review — MVP Day 1 (실행 가능 여부)

## 결과 요약
- 판정: ⚠️ 조건부 실행 가능
- 치명적 이슈: 1건
- 경고: 1건

---

## 파일별 체크 결과

### project.godot
- [✅] `config_version=5` 존재
- [✅] `run/main_scene="res://scenes/Main.tscn"` 존재
- [✅] WASD 입력 맵 정의 존재 (`move_forward` W=87, `move_backward` S=83, `move_left` A=65, `move_right` D=68)
- [✅] `jump` 입력 맵 정의 존재 (Space=32)

### Main.tscn
- [✅] `[gd_scene format=3 ...]` 헤더 존재
- [✅] 루트 노드 `Main` (Node3D) 존재
- [✅] `Player` 노드 (CharacterBody3D) 존재
- [✅] `Player`에 `PlayerController.gd` 스크립트 연결 (`ext_resource id="1_plctrl"` 참조)
- [✅] `Floor` StaticBody3D + CollisionShape3D 존재
- [✅] Camera3D 존재 (`Player/SpringArm3D/Camera3D`)
- [❌] `load_steps` 불일치: 선언값 `30`, 실제 리소스 수 `15` (ext_resource 1개 + sub_resource 14개)
- 특이사항: `Sky_sky001` sub_resource가 선언되었으나 `Environment_env001`에서 참조되지 않음 (sky 미연결)

### PlayerController.gd
- [✅] `extends CharacterBody3D`
- [✅] `_physics_process(delta)` 함수 존재
- [✅] `move_and_slide()` 호출 존재
- [✅] `is_on_floor()` 호출 존재 (중력 처리 및 점프 조건)
- [✅] `Input.is_action_just_pressed("jump")` 사용
- [✅] `Input.get_vector(...)` 사용 (`_get_input_direction()` 내부)
- [✅] `$SpringArm3D` 참조가 씬 트리의 `Player/SpringArm3D` 노드 이름과 일치
- [✅] `camera.current = true` 사용 시 `@onready var camera` 선언 확인됨

---

## 치명적 이슈 목록

### [CRITICAL-1] Main.tscn — `load_steps` 값 불일치
- **위치:** `Main.tscn` 1행 `[gd_scene load_steps=30 ...]`
- **내용:** `load_steps=30`으로 선언되어 있으나, 실제 선언된 리소스는 ext_resource 1개 + sub_resource 14개 = **총 15개**
- **영향:** Godot 4 엔진은 `load_steps` 값이 실제 리소스 수보다 클 경우 로딩 중 오류 또는 경고를 발생시킬 수 있으며, 일부 빌드 환경에서 씬 로딩 실패로 이어질 수 있음
- **수정 방법:** `load_steps=30` → `load_steps=15` 로 변경

---

## 경고 목록

### [WARN-1] Main.tscn — `Sky_sky001` sub_resource 미사용
- **위치:** `Main.tscn` 12~13행
- **내용:** `[sub_resource type="Sky" id="Sky_sky001"]`가 선언되어 있으나, `Environment_env001`의 `sky` 프로퍼티에서 참조되지 않음 (`sky_material = null` 상태)
- **영향:** 씬 실행 자체는 가능하나, Sky 리소스가 실제로 사용되지 않아 하늘 배경이 Sky 설정 없이 기본값으로 렌더링됨. 데드 리소스로 씬 파일에 불필요하게 남아있음
- **권고:** `Sky_sky001`을 사용하려면 `Environment_env001`에 `sky = SubResource("Sky_sky001")` 추가. 사용하지 않는다면 해당 sub_resource 선언 제거

---

## 수정 권고사항

### 필수 수정 (치명적 이슈 해결)
- `/scenes/Main.tscn` 1행: `load_steps=30` → `load_steps=15` 로 변경
  ```
  [gd_scene load_steps=15 format=3 uid="uid://main1234"]
  ```

### 선택 수정 (경고 해결)
- `Sky_sky001` sub_resource 제거 또는 `Environment_env001`에 연결
  - 제거 시: `[sub_resource type="Sky" id="Sky_sky001"]` 블록 삭제 후 `load_steps=14`로 추가 조정
  - 연결 시: `Environment_env001` 블록에 `sky = SubResource("Sky_sky001")` 추가
