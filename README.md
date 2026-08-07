# GG 경매 시뮬레이터 (가제)

지지옥션의 **실제 법원경매 과거 데이터**로 만드는 부동산 경매 시뮬레이션 게임 (Steam 출시 목표).

법정 방청석에 1인칭으로 앉아 물건을 조사하고 입찰가를 써낸 뒤, **실제로 있었던 낙찰 결과**와
비교당한다. 낙찰되면 취득세·명도비용·인수 보증금까지 실제와 동일한 비용 구조로 손익을 정산한다.

> 이 게임은 **감정평가사가 아니라 실제 경매 입찰자**를 위한 것이다.
> "얼마에 써야 하는가"와 "무엇을 놓치면 물리는가"를 실제 사례로 배우는 게 목적이다.

| | |
|---|---|
| 엔진 | Godot 4.7.1 (gl_compatibility), GDScript |
| 물건 | **4,501건** (실제 낙찰 완료 사건) |
| 사진 | **8,983장** (법원 감정평가 사진) |
| 실거래 시세 | 4,184건 (93%) — 국토교통부 실거래가 |
| 2순위 입찰가 | 1,615건 (법원 확정값) |
| 법률 돌발 이벤트 | 46종 · 칭호 35종 · 스토리 132줄 |

---

## ⚠ 이 저장소만으로는 데이터를 다시 만들 수 없다

**게임을 실행하는 데 필요한 것은 전부 들어 있다.** 클론하고 Godot으로 열면 4,501건이 그대로 돈다.

하지만 **데이터를 새로 수집하거나 갱신하려면 저장소에 없는 것들이 필요하다.**
아래 항목은 사내 API 정보·개인정보·인증키를 담고 있어 퍼블릭 저장소에서 의도적으로 제외했다.

### 없으면 데이터 갱신이 불가능한 것

| 항목 | 내용 | 없으면 |
|---|---|---|
| `tools_import/*.py` (21개) | **데이터 파이프라인 전체.** 지지옥션 API 수집, 실거래 매칭, 실명 마스킹, 검사기 | 수집·갱신 불가. API 역설계를 처음부터 다시 해야 함 |
| `tools_import/API_SPEC.md` | 실측으로 검증한 지지옥션 상세 API 스펙 | 파라미터 규칙(0패딩 등)을 다시 알아내야 함 |
| `tools_import/.molit_key` | 공공데이터포털 서비스키 | 실거래 시세 수집 불가 |
| `낙찰_용도_시도(10건).xlsx` | 낙찰 완료 물건 5,288건 목록 (수집의 출발점) | 어떤 사건을 받아야 할지 모름 |
| `tools_import/out/molit`, `out/openapi` | 국토부에서 받아둔 실거래 원자료 (137MB) | 재수집 가능하나 rt.molit은 **하루 100건 제한**이라 며칠 소요 |
| `data/raw_pdfs/` | 원본 감정평가서·매각물건명세서 | 실명 포함이라 제외. 대조 검수 시 필요 |
| `tools_import/ref/` | 실제 법정·입찰표 참고 사진 | 아트 재작업 시 근거 자료 |

**이 묶음은 별도로 백업되어 있다.** 사내 보관본을 받아 `tools_import/` 에 풀면 파이프라인이 그대로 동작한다.
백업 안의 `BACKUP_README.md` 에 복원 절차가 있다.

### 없어도 되는 것 (자동 생성)

`.godot/`(임포트 캐시) · `build/`(빌드 산출물) · `art_src/renders/`(중간 렌더, 최종 PNG는 저장소에 있음) · `__pycache__/`

---

## 실행

### 개발 (에디터)
```
tools\Godot_v4.7.1-stable_win64.exe        →  project.godot 열기  →  F5
```

### 스모크 테스트 (변경 후 반드시)
```
tools\Godot_v4.7.1-stable_win64_console.exe --headless -s res://tests/smoke.gd
```
`SMOKE OK` 가 나와야 한다. 준비 화면 필터부터 정산·칭호까지 전 구간을 검사한다.

### 빌드
```
taskkill /F /IM GG-Auction-Simulator.exe /T
tools\Godot_v4.7.1-stable_win64_console.exe --headless --export-release "Windows Desktop" build\GG-Auction-Simulator.exe
```
실행 중인 exe가 있으면 PCK 임베딩이 실패하므로 **반드시 먼저 종료**할 것.
최초 1회 export templates 설치 필요 (`%APPDATA%\Godot\export_templates\4.7.1.stable\`).

**엔진은 저장소에 없다.** `tools/` 아래에 Godot 4.7.1과 Blender 4.5.9를 직접 두어야 한다.

---

## 구조

### 게임 코드 (`scripts/`)
| 파일 | 역할 |
|---|---|
| `main.gd` | 게임 루프 전부 — 조사·입찰·개찰·정산·이벤트·평가표 (2,100줄) |
| `game_state.gd` | autoload `Game`. 설정·필터·칭호 누적·스토리 조회 |
| `setup.gd` | 입찰 준비 화면 (자본금·목적·난이도·지역 선택) |
| `cost_calc.gd` | 취득세·명도비 계산 (**수치는 전부 JSON에서 로드**) |
| `juice.gd` | 연출 헬퍼 (팝인·펀치·흔들림·별 파티클) |

UI는 씬이 아니라 **코드로 생성**한다. `.tscn` 은 스크립트를 붙이는 껍데기다.

### 데이터 (`data/`) — 수치는 코드가 아니라 여기가 소유한다
| 파일 | 내용 |
|---|---|
| `auctions.json` | 물건 4,501건. 형식은 `DATA_SPEC.md` |
| `cost_rules.json` | 취득세·지방교육세·농특세·등기·명도비·보증금율 — **지지옥션 검수 대상** |
| `usage_taxonomy.json` | 용도 4계열 / 15종 / 40종. **잎 이름이 `auctions.kind` 와 정확히 일치해야 함** |
| `play_axes.json` | 진행 축 — 목적 4종, 난이도 정의, 시장 등장 비중 |
| `legal_events.json` | 법률 돌발 이벤트 46종 |
| `titles.json` / `story.json` | 칭호 35종 / 스토리 텍스트 132줄 |
| `images/` | 물건 사진 8,983장 (640px). Godot 임포트를 거치지 않고 원본 JPEG 그대로 팩에 들어간다 |

### 아트 (`art_src/`) — Blender 헤드리스로 전부 코드 생성
```
blender.exe -b -P art_src/render_courtroom.py -- "C:/game/assets/art/courtroom.png" crowd
blender.exe -b -P art_src/render_char.py -- mover "C:/game/art_src/renders/char_mover_raw.png"
py art_src/postfx.py art_src/renders/char_mover_raw.png assets/art/char_mover.png 512
```
`blocklib.py` 가 공용 라이브러리(재질·조명·카메라·SD 캐릭터). 색은 `blocklib.srgb("#ffa33f")` 로 넣어야
화면에서 뽑은 색과 일치한다 (Blender는 선형 색공간).

효과음·음성도 코드 생성이다 — 파이썬 `wave`/`struct` 합성 + Edge TTS(`ko-KR-InJoonNeural`).
저작권 문제가 없다.

---

## 데이터 파이프라인

원천 3개를 합쳐 `data/auctions.json` 을 만든다.

1. **낙찰 목록 xlsx** — 낙찰 완료 물건 5,288건 (시도/법원코드/사건번호/물건SEQ/입찰일자/용도)
2. **지지옥션 상세 API** — 감정가·최저가·낙찰가·응찰자 수·2순위·임차인 대항력·말소기준권리·사진
3. **국토교통부 실거래가** — 시세. 오픈API(키 필요) + 실거래가공개시스템(키 불필요, 하루 100건)

전량 재생성 순서는 `docs/DIARY.md` 4절에 있다. 매일 04:17에 Windows 작업 스케줄러
`GG실거래가` 가 실거래를 조금씩 더 받는다.

### 데이터를 건드렸다면 반드시
```
py tools_import/check_pii.py       # 실명이 남았는지 (실패 시 종료코드 1)
py tools_import/check_events.py    # 이벤트 발동률·죽은 카드
tools\...console.exe --headless -s res://tests/smoke.gd
```
`site_notes` 같은 자유 서술문에는 **채무자·소유자·임차인 실명이 그대로 들어온다.**
마스킹하지 않고 커밋하면 개인정보가 공개된다. `scrub_names.py` 는 **한 번만** 돌릴 것
(이미 마스킹된 결과 위에 또 돌리면 기준이 흔들려 일반 단어까지 지운다 — 실제로 사고가 났었다).

---

## 문서

| | |
|---|---|
| `CLAUDE.md` | 개발 규칙 (Ponytail 최소 코드 원칙 + 도메인 규칙) |
| **`docs/DIARY.md`** | **작업 기록장 — 이어받을 때 여기부터.** 현재 상태·파이프라인·지난 실수·열려 있는 결정 |
| `DATA_SPEC.md` | 물건 데이터 형식 |
| `docs/research/` | 스팀 게임 분석 · 커뮤니티 분석 · 손맛 기법 (에이전트 리서치 결과) |
| `docs/ART_SPEC.md` | 아트 방향 |

---

## 알려진 제약·주의

- **세이브 없음.** 껐다 켜면 처음부터. 칭호 누적도 세션 한정
- **git 이력에 실명이 남아 있다.** 현재 파일은 정리됐지만 과거 커밋에는 남아 있다
- **사진 저작권 확인 필요.** 감정평가사 촬영 내부 사진은 파노라마의 자유가 적용되지 않는다.
  출시 전 법무 검토가 필요하다
- 헤드리스로는 GPU 렌더가 안 되므로 **화면 캡처 검증이 불가능**하다
- `market_price` 는 국토부 실거래 중앙값 × 면적으로 계산한 추정치다. 출처는 물건마다
  `market_source` 에 남아 있고 게임 화면에도 표시된다
