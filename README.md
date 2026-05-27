# 🐧 동물 숨기 (Animal Hide Game)

Claude Code 멀티에이전트 파이프라인으로 개발 중인 3D 숨바꼭질 게임.  
기획팀 → 디자인팀 → 개발팀 → 리뷰팀 순서로 AI 에이전트가 협업하여 코드를 생성합니다.

---

## 🎮 게임 소개

플레이어와 봇이 동일한 펭귄 외형으로 50×50 맵에서 숨바꼭질을 벌이는 3D 게임입니다.  
봇을 찾아 공격하면 쓰러지고, 봇들은 맵을 자유롭게 돌아다닙니다.

---

## 🕹️ 조작키

| 키 | 동작 |
|----|------|
| `W A S D` | 이동 |
| `Shift` + 이동 | 달리기 (속도 ×1.8) |
| `Space` | 점프 |
| `Q` | 공격 (2m 이내 봇 적중) |
| `ESC` | 마우스 커서 토글 |
| 마우스 | 카메라 회전 |

---

## ⚙️ 게임 스펙

| 항목 | 값 |
|------|----|
| 맵 크기 | 50 × 50 m |
| 봇 수 | 10마리 |
| 기본 이동 속도 | 5.0 m/s (플레이어 = 봇 동일) |
| 달리기 속도 | 9.0 m/s (플레이어만) |
| 점프 속도 | 4.5 m/s (플레이어 = 봇 동일) |
| 공격 범위 | 반경 2 m |
| 피격 후 제거 | 1초 |

---

## 📁 프로젝트 구조

```
animal-hide-game/
├── CLAUDE.md                    # 메인 에이전트 (PM·오케스트레이터) 설정
├── 게임_기획_명세서.md            # 게임 기획 문서
├── output/
│   ├── godot-project/           # Godot 4 프로젝트
│   │   ├── project.godot
│   │   ├── scenes/
│   │   │   ├── Main.tscn        # 메인 씬
│   │   │   └── Bot.tscn         # 봇 씬
│   │   └── scripts/
│   │       ├── PlayerController.gd
│   │       ├── BotController.gd
│   │       ├── MapGenerator.gd
│   │       └── GameManager.gd
│   ├── reports/                 # 기획·아키텍처·리뷰 문서
│   └── logs/                    # 작업 이력 및 에스컬레이션 로그
└── .claude/
    ├── agents/                  # 기획·디자인·개발·리뷰팀 에이전트
    └── skills/                  # 코드 생성·분석 스킬
```

---

## 🚀 실행 방법

**요구사항:** Godot 4.6 이상

```bash
# 방법 1 — Godot Editor에서 열기
# output/godot-project/project.godot 를 Godot Editor로 열기

# 방법 2 — CLI
godot --path output/godot-project
```

---

## 🤖 멀티에이전트 파이프라인

이 프로젝트는 Claude Code 기반 멀티에이전트 시스템으로 개발됩니다.

```
사용자
  │
  ▼
메인 에이전트 (PM · CLAUDE.md)
  ├── 기획팀  → feature_list.md, parsed_spec.json
  ├── 디자인팀 → architecture_review.md
  ├── 개발팀  → GDScript 코드 생성
  └── 리뷰팀  → code_review.md
```

---

## 📋 개발 이력

| 버전 | 내용 |
|------|------|
| MVP Day 1 | 큐브 플레이어 + 20×20 맵 기본 이동 |
| 프로토타입 #001 | 펭귄(캡슐) 플레이어·봇 10마리, 50×50 맵, 공격·달리기·점프 |

---

## 🌿 브랜치 전략

| 브랜치 | 용도 |
|--------|------|
| `main` | 안정 버전 |
| `dev` | 개발 작업 |
