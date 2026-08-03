class_name CostCalc
## 낙찰 후 부대비용 계산. 모든 수치는 data/cost_rules.json이 소유한다.

static func is_house(kind: String, rules: Dictionary) -> bool:
	return kind in rules.get("house_kinds", [])


static func acq_tax_rate(bid: int, house: bool, rules: Dictionary) -> float:
	var r: Dictionary = rules["acquisition_tax"]
	if not house:
		return r["non_house"]
	if bid <= 600_000_000:
		return r["house_under_600m"]
	if bid > 900_000_000:
		return r["house_over_900m"]
	# 6~9억 주택 누진: (가액 × 2/3억 − 3) / 100
	return (bid * 2.0 / 300_000_000.0 - 3.0) / 100.0


## [{name, amount}] 목록 반환
static func breakdown(a: Dictionary, bid: int, rules: Dictionary) -> Array:
	var items: Array = []
	var house := is_house(a["kind"], rules)
	var acq_rate := acq_tax_rate(bid, house, rules)
	items.append({"name": "취득세 (%.2f%%)" % (acq_rate * 100), "amount": int(bid * acq_rate)})

	var edu: Dictionary = rules["local_edu_tax"]
	var edu_rate: float = acq_rate * edu["house_factor_of_acq"] if house else edu["non_house_rate"]
	items.append({"name": "지방교육세", "amount": int(bid * edu_rate)})

	var rural: Dictionary = rules["rural_special_tax"]
	if not house or a["area_m2"] > rural["house_exempt_under_m2"]:
		items.append({"name": "농어촌특별세", "amount": int(bid * rural["rate"])})

	var reg: Dictionary = rules["registration_cost"]
	items.append({"name": "등기·법무 비용", "amount": maxi(int(bid * reg["rate"]), int(reg["min_amount"]))})

	items.append({"name": "인지세", "amount": int(rules["stamp_tax"]["amount"])})

	if int(a.get("unpaid_mgmt_fee", 0)) > 0:
		items.append({"name": "미납 관리비 인수", "amount": int(a["unpaid_mgmt_fee"])})

	# 단순화: 대항력 있는 임차인의 보증금은 전액 인수로 처리 (배당 반영은 추후)
	if a.get("tenant_opposing_power", false) and int(a.get("tenant_deposit", 0)) > 0:
		items.append({"name": "임차인 보증금 인수 (대항력)", "amount": int(a["tenant_deposit"])})

	return items


static func total(items: Array) -> int:
	var t := 0
	for i in items:
		t += int(i["amount"])
	return t


## 명도 선택지 [{key, label, cost, months, note}]
static func eviction_options(a: Dictionary, rules: Dictionary) -> Array:
	var e: Dictionary = rules["eviction"].get(a.get("occupancy", "공실"), rules["eviction"]["공실"])
	var nego := int(e["negotiate"])
	var has_dividend := false
	for tn in a.get("tenants", []):
		if tn.get("dividend_demand", false):
			has_dividend = true
	var nego_note := ""
	if has_dividend and nego > 0:
		nego = int(nego * float(rules.get("dividend_negotiate_factor", 1.0)))
		nego_note = "배당 임차인 — 명도확인서가 협상 카드 (이사비 절감)"
	return [
		{"key": "negotiate", "label": "이사비 협상", "cost": nego, "months": int(e["months_negotiate"]), "note": nego_note},
		{"key": "enforce", "label": "인도명령·강제집행", "cost": int(e["enforce"]), "months": int(e["months_enforce"]), "note": "잔금 후 6개월 내 신청 필수"},
	]
