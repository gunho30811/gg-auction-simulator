# 아트 에셋 스펙 — 외주/AI 생성 발주용

현재 게임의 SVG 플레이스홀더를 프로급 일러스트로 교체하기 위한 발주 문서.
파일만 같은 이름으로 교체하면 게임에 바로 반영된다 (코드 수정 불필요, PNG도 지원).

## 스타일 가이드

- **톤**: 밝고 귀여운 캐주얼 (레퍼런스: 쿠키런·메이플스토리풍 SD 캐릭터, 통통한 비율, 두꺼운 라운드 실루엣)
- **팔레트**: 게임 UI가 다크네이비(#12141c) + 골드(#e0b95e)이므로, 에셋은 따뜻한 크림·파스텔 톤에 골드 포인트
- **렌더**: 소프트 셰이딩(2.5D 느낌의 볼륨감), 두꺼운 외곽선 없이 부드러운 경계, 은은한 림라이트
- **배경**: 투명 (알파 PNG)

## 필요 에셋 목록

### 1. 캐릭터 '지지' (경매 도우미) — 최우선
| 파일 | 내용 | 크기 |
|---|---|---|
| `assets/characters/jiji.png` | 기본 (미소, 의사봉 든 정장 여성, 원형 배지 구도) | 1024×1024 |
| `assets/characters/jiji_happy.png` | 축하 표정 (낙찰 시) | 1024×1024 |
| `assets/characters/jiji_worry.png` | 걱정 표정 (함정 경고 시) | 1024×1024 |

### 2. 경쟁 입찰자 (개찰 장면) — SD 반신
| 파일 | 컨셉 | 크기 |
|---|---|---|
| `assets/art/bidder1.png` | 모자 쓴 중년 아저씨 (강남 큰손) | 512×512 |
| `assets/art/bidder2.png` | 안경 할머니 (은퇴자금 방어전) | 512×512 |
| `assets/art/bidder3.png` | 정장+넥타이 남성 (조용한 법인) | 512×512 |
| `assets/art/bidder4.png` | 갈색 머리 청년 (첫 임장 새내기) | 512×512 |
| +2종 추가 환영 (이사비 전문 꾼, 옆동네 중개사) | | |

### 3. 물건 종류 일러스트 (사진 없는 물건의 액자 표시 + 카드 아이콘)
| 파일 | 내용 | 크기 |
|---|---|---|
| `assets/art/apt.png` | 귀여운 아파트 단지 | 1024×1024 |
| `assets/art/villa.png` | 빌라/다세대 | 1024×1024 |
| `assets/art/shop.png` | 상가 건물 | 1024×1024 |
| `assets/art/land.png` | 토지 (매각 표지판) | 1024×1024 |

### 4. 키비주얼 (타이틀·스팀 상점)
- 타이틀 배경: 경매 법정에 캐릭터들이 앉아있는 와이드 일러스트, 1920×1080
- 스팀 캡슐 이미지 세트: 616×353, 231×87, 460×215 (스팀 규격)

## AI 생성 시 프롬프트 힌트

"cute chibi Korean office worker girl holding auction gavel, navy suit with gold ribbon,
soft 3D-like rendering, warm rim light, pastel palette with gold accents, circular badge
composition, game character portrait, transparent background" — 캐릭터 시트로 4방향/표정 3종 요청

## 교체 방법

같은 경로에 PNG를 넣고 SVG를 지우면 끝. 코드가 경로만 참조하므로
`jiji.svg → jiji.png`처럼 확장자가 바뀌면 `scripts/` 내 해당 경로 문자열만 수정 (총 3곳).
