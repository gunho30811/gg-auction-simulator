# GG 경매 시뮬레이터 (가제)

지지옥션 실데이터 기반 법원경매 시뮬레이션 게임 (Steam 출시 목표).
실제 과거 경매 물건에 입찰해보고, 실제 낙찰가와 비교하고, 취득세·명도비용·인수 보증금까지
실제와 동일한 비용 구조로 손익을 정산한다.

## 실행 (개발)

1. `tools\Godot_v4.7.1-stable_win64.exe` 실행 → `project.godot` 열기 → F5
2. 또는 터미널: `tools\Godot_v4.7.1-stable_win64_console.exe --path .`

## 빌드 (exe)

```
tools\Godot_v4.7.1-stable_win64_console.exe --headless --export-release "Windows Desktop" build\GG-Auction-Simulator.exe
```
(최초 1회 export templates 설치 필요 — `%APPDATA%\Godot\export_templates\4.7.1.stable\`)

## 구조

- `data/sample_auctions.json` — 물건 데이터 (형식: `DATA_SPEC.md`). 실데이터로 교체하면 끝
- `data/cost_rules.json` — 세율·비용 규칙 (수치는 전부 여기, 코드에 없음. 지지옥션 검수 대상)
- `data/images/` — 물건 사진 (감정평가서 PDF에서 추출)
- `data/raw_pdfs/` — 원본 PDF (감정평가서, 매각물건명세서)
- `scripts/cost_calc.gd` — 부대비용 계산 엔진
- `scripts/main.gd` — 게임 루프 + UI
- `assets/characters/jiji.svg` — 도우미 캐릭터 '지지'

## 개발 룰

`CLAUDE.md` 참조 (Ponytail 최소 코드 원칙 + 도메인 규칙).
