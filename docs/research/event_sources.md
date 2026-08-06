# 돌발 이벤트 카드 출처 대조표 (검수용)

`data/legal_events.json`에 **추가된** 카드 24장의 원 사연과 출처.
원재료는 `docs/research/community.md`의 "B. 실제 경매판에서 건진 소재" 46개다.
실명·단지명·지번은 모두 지웠고, 사연의 **구조와 교훈만** 가져왔다.

카드에 적힌 금액(`effects.cash`)과 시세 배율(`effects.market_factor`)은
기존 22장과 동일하게 **플레이 밸런스용 임시 수치**이며 지지옥션 검수 대상이다.
세율(취득세·양도세)에 연동되는 수치는 카드에 넣지 않았다 — `cost_rules.json`이 소유한다.

## bid_day (입찰 당일) — 5장

| 카드 id | B-번호 | 출처 URL | 원 사연 요약 |
|---|---|---|---|
| `digit_check` | B-1 | https://www.hankyung.com/article/2026061726051 | 감정가 15억대 아파트에 17억을 쓰려던 응찰자가 0을 하나 더 붙여 172억에 낙찰, 보증금 전액 몰수. 기사는 이런 자릿수 오기가 "한 달에 한 번꼴"이며 매각불허가 사유가 아니라 구제 불가라고 전한다. |
| `deposit_check` | B-4 | https://brunch.co.kr/@thebridge/64 , https://alzaapt.tistory.com/52 | 법정 참관기에 보증금을 현금으로 잘못 내 무효 처리된 장면이 있다. 보증금은 최저매각가격의 10%이고 1원이라도 모자라면 최고가를 써도 무효이며, 재매각 물건은 특별매각조건으로 보증금이 상향된다. |
| `tie_bid_extra` | B-3 | https://www.easylaw.go.kr/CSP/CnpClsMainBtr.laf?csmSeq=306&ccfNo=3&cciNo=2&cnpClsNo=2 , https://brunch.co.kr/@thebridge/64 | 최고가가 같으면 그 입찰자들만 그 자리에서 추가입찰하고, 또 같으면 추첨한다. 서부지법에서 실제로 두 명이 새 입찰표를 받아 재입찰한 목격담. |
| `crowded_court` | B-6 | https://v.daum.net/v/UKZtDRTNvf | 시골 농지(211㎡)가 7차례 유찰된 뒤 인근 산단 개발이 확정되자 그해 최다인 255명이 응찰했다. (지명·면적은 카드에서 삭제) |
| `proxy_bidder` | B-24 | https://www.incheontoday.com/news/articleView.html?idxno=305395 | 경매 강의로 수강생을 모아 "확실한 물건"이라며 대리입찰을 유도하고, 일부러 최고가로 써서 차액을 빼돌린 사건. 피해자 다수. (실명·회사명 미사용) |

## confirmation (매각결정기일) — 4장

| 카드 id | B-번호 | 출처 URL | 원 사연 요약 |
|---|---|---|---|
| `land_right_missing` | B-11 | https://www.ra-quant.com/content/auction-condo-land-rights | 대지권 미등기는 절차 지연형(안전)과 권리 흠결형(위험) 두 종류이고, 판별법은 감정평가서에 대지권 값이 포함됐는지 한 줄이다. 흠결형이면 대지 소유자가 건물 매도청구·사용료 청구를 할 수 있다. |
| `dividend_withdrawn` | B-32 | https://wanbong.co.kr/blog/8692fd24-c47a-4e51-bc83-aecb1b7ee8f7/ | 선순위 임차인 보증금이 배당으로 정리될 줄 알았는데 임차인이 배당요구를 철회해 그대로 인수분이 됐다. 구제 타이밍은 매각허가 전 불허가 신청, 대금납부 전 허가결정 취소신청(민집 127조) 두 번뿐. |
| `prior_provisional_reg` | B-8 | https://brunch.co.kr/@withyoulawyer/454 , https://www.mk.co.kr/news/economy/10864792 | 말소기준권리보다 앞선 소유권이전청구권 가등기는 경매로 소멸하지 않고, 가등기권자가 본등기를 하면 낙찰자의 소유권이전등기가 직권 말소된다. 잔금·배당 전후로 구제 수단이 갈린다. |
| `loan_approved` | B-19 대칭 / A-11 | https://brunch.co.kr/@887f85639c994c0/32 (정서) , 기존 `loan_denied` 카드의 반대면 | community.md A-11: 낙찰 후 이벤트가 전부 처벌이면 "낙찰이 벌처럼" 느껴진다는 지적. 기존 `loan_denied`(대출 거부)의 짝으로, 사전 상담을 해둔 경우의 정상 진행을 카드화. |

## possession (잔금 후 명도 전) — 15장

| 카드 id | B-번호 | 출처 URL | 원 사연 요약 |
|---|---|---|---|
| `mgmt_fee_claim` | B-12 | https://auctionguide.tistory.com/15 | 낙찰자가 승계하는 체납 관리비는 공용부분 원금 3년치까지이고 연체료는 승계 대상이 아니다(대법원 판례). 그런데 현장에서는 관리사무소가 전액을 요구하며 단전·출입 통제로 압박하는 일이 흔하다. |
| `mgmt_office_fair` | B-12 뒤집기 / A-11 | https://auctionguide.tistory.com/15 | 같은 소재의 정상 케이스 — 관리사무소가 공용/전용·원금/연체료를 스스로 구분해 공용부분 원금만 청구하는 경우. 긍정 카드로 덱 균형을 맞추기 위해 추가. |
| `coffee_tenant` | B-19 + B-18 | https://brunch.co.kr/@887f85639c994c0/32 , https://brunch.co.kr/@887f85639c994c0/29 | 명도확인서를 들고 처음 찾아갈 때 "긴장되고 떨렸는데" 임차인이 오히려 커피를 사주며 배당 절차를 물었고, 손해를 봤음에도 웃으며 작별했다. "결혼자금이었던 보증금"은 B-18의 한 줄 사정에서 가져왔다. |
| `release_letter_first` | B-27 + B-38 | https://sanisanee.com/281 , https://auctionskill.com/eviction-completion-check-problems-cases/ | 배당받는 임차인은 낙찰자의 명도확인서·인감증명서가 있어야 배당금을 받는다. 미리 써주면 배당만 받고 버티는 사고가 반복된다 — 현장 룰은 동시이행. "수험생 시간표"는 B-18의 한 줄 사정. |
| `elderly_occupant` | B-39 | https://www.clien.net/service/board/park/17935839 | 낙찰 후 가보니 자녀가 방치한 80대 치매 어르신이 혼자 거주 중이었고, 낙찰자는 강제집행 대신 공공 주거지원 제도를 알아봐 이주처를 마련해 명도를 끝냈다. |
| `stubborn_occupant` | B-16 + B-18 | https://probably-useful.tistory.com/entry/경매-두-번째-경매-낙찰-후기-4편-쉽지-않은-명도-과정 | 점유자가 "나는 협의 이런 거 싫다, 난 막무가내니까 알아서 해라"로 나왔고, 글쓴이가 꼽은 최대 실수는 잔금 납부 당일 인도명령을 신청하지 않아 협상 카드가 없었던 것. "어린이 자전거"는 B-18의 한 줄 사정. |
| `enforcement_quote` | B-17 | https://brunch.co.kr/@wallaroo/27 , https://house114.co.kr/gyeongmae-nakchal-myeongdo-procedure-negotiation-tips/ | 18평 기준 강제집행 견적 약 450만원(노무·보관·운송·열쇠공)인데 실제로는 대부분 그보다 훨씬 낮은 이사비로 합의된다. 실무 룰은 "강제집행 비용을 상한선으로 이사비를 책정"하고, 인도명령 송달 단계에서 90% 이상이 합의된다. |
| `no_road_access` | B-7 | https://www.lawtalk.co.kr/videos/40270 , https://v.daum.net/v/20240625030505641 | 낙찰 후 앞 도로 소유자가 통행료를 요구하고 길을 막겠다고 통보한 분쟁. 감정가의 24%까지 떨어진 시골 주택은 명세서에 "지적도상 도로가 연결되지 않는 맹지"라고 이미 적혀 있었다. |
| `statutory_superficies` | B-9 | https://brunch.co.kr/@13b1dee5bc7942a/650 | 토지를 낙찰받았더니 건물주가 "10년 넘게 재산세를 냈다"며 법정지상권을 주장했으나, 법원은 근저당 설정 당시 토지·건물 소유자가 달랐다는 이유로 성립을 부정했다(1심 승소, 항소심 확정). |
| `senior_tenant_assumed` | B-14 | https://auctionskill.com/tenant-opposability-deposit-liability/ | 말소기준권리보다 전입일이 빠른 임차인은 대항력이 있어 배당으로 못 받은 보증금을 낙찰자가 인수한다. 가장 흔한 초보 실수는 등기부만 보고 판단하는 것 — 대항력은 전입세대열람원에만 보인다. |
| `biz_reg_tenant` | B-33 | https://money-insight.com/부동산-경매-공매-권리분석-실패/ | 명세서에 '임차인 없음'이던 상가에 실제로는 사업자등록+확정일자를 갖춘 임차인이 영업 중이었고, 명도합의금을 지급했다. 상가 대항력 요건은 전입신고가 아니라 건물 인도+사업자등록. |
| `unlisted_occupant` | B-34 | https://kisstheguitar.com/경매-주의사항/ | 전입세대열람으로 "점유자 없음"을 확인하고 입찰했는데 실제로는 외국인이 거주 중이었다. 외국인 등록은 주민등록과 별도 체계라 열람원에 잡히지 않는다. |
| `hoarder_cleanup` | B-41 + B-38 | https://www.mowatool.com/calculators/life/estate-cleanup-cost , https://auctionskill.com/eviction-completion-check-problems-cases/ | "짐 다 뺐어요"를 믿고 이사비를 줬는데 짐이 그대로 남아 있던 사례, 그리고 저장강박·유품정리 특수청소 비용 데이터(평당 인건비 + 폐기물 톤당 단가). 고독사 소재는 톤 문제로 카드에서 제외했다. |
| `lien_proved_false` | B-13 | https://www.hankyung.com/article/202509260387i , https://spendwisely.tistory.com/53 | 허위 유치권 소송이 5년간 1,134건. 유치권은 법원 신고만으로 경매정보에 자동 고지되어 경쟁을 위축시키고, 실무 해설은 신고된 유치권의 80~90%가 허위이거나 요건 결여로 본다. 개시결정 후 점유는 매수인에게 대항 불가. |
| `partition_timeline` | B-10 | https://www.auctionsuit.com/co-ownership-partition-lawsuit-auction-case/ , https://a.infovuee.com/entry/공유물-분할청구소송-투자-실패 | 단독주택 지분을 낙찰받아 부당이득반환 → 공유물분할청구 → 형식적 경매로 가는 데 4년 이상. 반대 사례에서는 18개월간 판결이 안 나는 사이 관리비·재산세·법률비용이 누적돼 투자금보다 큰 손실을 봤다. |

## 의도적으로 만들지 않은 소재

| 소재 | 이유 |
|---|---|
| 민법 제580조 제2항 담보책임(누수·균열 하자) | community.md 부록 3에서 자료 상충으로 **판단 보류**. 지지옥션 법률 검수 전까지 카드화 금지. |
| B-21 취득세 다주택 중과 / B-42 단기 양도세 70% | 세율 수치는 `cost_rules.json`이 소유해야 한다(CLAUDE.md). 이벤트 카드가 세율을 들고 있으면 안 됨. |
| B-22 물딱지(재개발 조합원 자격) | 부록 3 — 출처가 일반 매매를 다루고 경매 낙찰 시 취급이 확인되지 않음. |
| B-45 토지거래허가구역 매도 제약 | 엔진에 매도(엑싯) 단계가 없다. 스테이지가 생기면 그때. |
| B-26 차순위매수신고 / B-1 자릿수 오기의 실제 발동 | `bid_day` 이벤트는 개찰 **전**에 발동하고 입찰가를 바꿀 수단이 없어, 판정에 영향을 주는 카드로는 만들 수 없다. 지금은 관찰·교육용 중립 카드로만 넣었다. |

## 엔진 쪽 확인 필요 (카드 문제 아님)

- `cond: { "share_sale": true }`는 `data/auctions.json`에 `share_sale` 필드가 **하나도 없어** 현재 항상 false다.
  기존 `coowner_preempt`와 신규 `partition_timeline` 두 장이 이 때문에 발동하지 않는다.
  지분 물건에 `share_sale: true`를 채우면 두 장 모두 살아난다.
- `cond.kinds`의 `"토지"`, `"농지"`, `"근린시설"`, `"빌라"`는 실데이터에 존재하지 않는 종별이다
  (기존 `farmland_cert`·`grave_found`·`violation_building`이 사용 중 — 그만큼 발동 범위가 좁아져 있다).
  실제 종별은 `대지 / 전 / 답 / 과수원 / 임야 / 잡종지`이며, 신규 카드는 이 값만 사용했다.
