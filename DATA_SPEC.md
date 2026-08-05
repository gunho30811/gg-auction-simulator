# 데이터 스펙 — 게임이 쓰는 물건 데이터 형식

**현재 상태**: `data/auctions.json` 에 실제 낙찰 물건 **100건**이 들어가 있습니다.
낙찰 목록 xlsx(5,288건) + 지지옥션 상세 API로 자동 생성되며, 재생성은 사내 스크립트로 합니다.
`data/sample_auctions.json` 은 형식 참고용 예시로 남겨둡니다.

아래 표의 **자동** 표시는 API에서 그대로 채워지는 필드, **미해결**은 아직 소스가 없는 필드입니다.

## 물건 데이터 (필수 필드)

| 필드 | 타입 | 설명 | 예시 |
|---|---|---|---|
| `case_no` | string | 사건번호 | `"2024타경12345"` |
| `court` | string | 법원 | `"서울중앙지방법원"` |
| `kind` | string | 물건 종류 (`아파트`/`다세대`/`오피스텔`/`상가`/`토지` 등) | `"아파트"` |
| `address` | string | 소재지 (공개 범위는 지지옥션 판단 — 동까지만 등 마스킹 가능) | `"서울 서초구 반포동"` |
| `area_m2` | number | 전용면적(㎡) — 농특세 85㎡ 기준 판정에 사용 | `84.9` |
| `appraisal_price` | int | 감정가 (원) | `950000000` |
| `min_price` | int | 최저매각가격 (원) | `608000000` |
| `fail_count` | int | 유찰 횟수 | `1` |
| `sale_date` | string | 매각기일 `YYYY-MM-DD` | `"2024-05-13"` |
| `winning_bid` | int | **실제 낙찰가 (원)** — 게임의 핵심 | `823500000` |
| `bidder_count` | int | 응찰자 수 | `7` |
| `market_price` | int | 당시 시세 (원) — 손익 정산 기준. **미해결**: 상세 API에 없어 현재는 감정가를 대입 중 | `900000000` |
| `images` | string[] | 사진 파일명 배열 (`data/images/`, 폭 1100px·q80로 축소 저장) | `["0701-2024...-0001_1.jpg"]` |
| `mul_no` | int | 물건번호 — 입찰표·입찰봉투에 기재 | `1` |
| `kind_tax` | string | `usage_taxonomy.json` 의 잎 이름 (지역·용도 선택 필터용). 화면 표시는 `kind` | `"단독주택"` |

## 점유·권리 관계 (명도/인수 비용 계산용)

| 필드 | 타입 | 설명 |
|---|---|---|
| `occupancy` | string | `"소유자점유"` / `"임차인점유"` / `"공실"` / `"유치권신고"` |
| `tenant_deposit` | int | 임차인 보증금 (원, 없으면 0) |
| `tenant_opposing_power` | bool | 대항력 있는 임차인 여부 (보증금 인수 여부 판정) |
| `unpaid_mgmt_fee` | int | 미납 관리비 (원, 없으면 0) — 공용부분 인수분 |
| `notes` | string | 특이사항 (게임 내 "주의사항" 카드로 노출) |

## 감정평가·권리분석 요소 (게임의 '조사' 단계에 사용)

| 필드 | 타입 | 설명 |
|---|---|---|
| `built_date` | string | 사용승인일 `YYYY-MM-DD` (연식 표시) |
| `land_share_m2` | number | 대지권 면적(㎡) |
| `base_rights_date` | string | 말소기준권리 설정일 (최선순위 근저당 등) — 대항력 판정 퀴즈의 핵심 |
| `base_rights_kind` | string | 말소기준권리 종류 (`근저당권` 등) |
| `tenants` | array | 임차인 목록: `{label(익명화), deposit, move_in(전입일), fixed_date(확정일자), dividend_demand(배당요구 여부), note}` |
| `comps` | array | 거래사례비교 자료: `{label, price, date}` — 감정평가서의 사례 데이터 |
| `price_index_note` | string | 시점수정용 가격지수 코멘트 (감정평가서 Ⅲ장) |
| `site_notes` | string | 현장조사(임장) 정보 — '현장조사' 탭에서 공개 |

※ `tenants.label`은 "임차인 A" 식으로 자동 익명화됩니다. 임차인·채무자·낙찰자·채권자 **실명은 저장하지 않습니다** (퍼블릭 저장소).

## 자동/미해결 정리

**API에서 자동으로 채워짐** — case_no, mul_no, court, address, area_m2, land_share_m2,
appraisal_price, min_price, fail_count, sale_date, **winning_bid**, **bidder_count**, **second_bid**,
images, occupancy, tenant_deposit, tenant_opposing_power, unpaid_mgmt_fee,
base_rights_date/kind, tenants, site_notes

**아직 소스 없음 (지지옥션 확인 필요)**

| 필드 | 게임에서 쓰는 곳 | 현재 처리 |
|---|---|---|
| `market_price` | 손익 정산·시세 분석 범위 | **감정가로 대체** — 실거래 시세 API/필드를 알려주시면 교체 |
| `comps` | '실거래·시세' 탭 | 빈 배열 (탭에 "자료 없음") |
| `price_index_note` | 같은 탭의 가격지수 코멘트 | 빈 값 |
| `built_date` | 연식 표시 | 빈 값 (표시 생략) |

## 있으면 좋은 것 (선택)

- `second_bid` (int): 차순위 입찰가 — "간발의 차" 연출용
- 지역/평형별 시세 추이 — 난이도·시나리오 설계용
- 명도 난이도 관련 실무 데이터 (강제집행까지 간 비율 등) — 명도 이벤트 확률 튜닝용

## 비용 규칙 검수 요청

`data/cost_rules.json`에 취득세·지방교육세·농특세·법무비용·명도비용 추정 규칙을 넣어두었습니다.
**실무와 다른 부분을 직접 고쳐주시거나 알려주시면** 됩니다 — 수치는 전부 이 파일에만 있고 코드에는 없습니다.

## 수량

- 프로토타입: 30~50건이면 충분 (사진 포함)
- 정식: 지역·물건종류·난이도 다양하게 수백 건 이상이면 좋음
