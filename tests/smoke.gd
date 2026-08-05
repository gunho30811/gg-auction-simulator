extends SceneTree
## headless 스모크 테스트: godot --headless -s res://tests/smoke.gd
## 조사 → 퀴즈 → 입찰 → 개찰 세리머니 → 잔금 → 명도 → 정산 → 다음 물건 전 구간 호출
## 물건 데이터가 바뀌어도 돌도록 수치는 auctions[0]에서 가져온다.

func _initialize() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	var a: Dictionary = main.auctions[0]
	main._show_tab("comps")
	main._show_tab("rights")
	if not (a.get("tenants", []) as Array).is_empty():
		main._answer_quiz(bool(a.get("tenant_opposing_power", false)))
		assert(main.quiz_state == 1, "대항력 정답이 맞아야 함")
	main._show_tab("site")
	assert(main.seen_tabs.size() == 3, "조사 3종 기록")

	main._quick_bid("min")
	assert(main.bid_edit.text.to_int() * 10_000 >= int(a["min_price"]),
		"최저가 버튼이 무효 입찰가를 만들면 안 됨")

	# 낙찰 시나리오: 실제 낙찰가보다 1,000만원 높게 입찰 (bid_edit 단위는 만원)
	var bid: int = int(a["winning_bid"]) + 10_000_000
	main.event_override = "none"  # 법률 랜덤 이벤트 차단 (결정적 테스트)
	main.bid_edit.text = str(bid / 10_000)
	main._on_bid()  # 기일입찰표 열림
	await process_frame
	assert(main.form_layer != null, "기일입찰표가 표시되어야 함")
	main._stamp()                 # 날인
	main._on_form_btn()           # 보증금 봉투
	await create_timer(0.5).timeout
	main._on_form_btn()           # 입찰봉투 (3D 플립 + 스르륵 ~2초)
	await create_timer(2.6).timeout
	main._on_form_btn()           # 수취증 + 투함 → 개찰
	await create_timer(33.0).timeout  # 투함 연출 + 개찰 세리머니 + 매각결정기일
	assert(main.action_row.visible, "낙찰 후 잔금/포기 선택지가 보여야 함")

	main.action_row.visible = false
	main._pay_balance(bid)
	if str(a.get("occupancy", "공실")) != "공실":
		assert(main.action_row.visible, "점유 물건은 명도 선택지가 보여야 함")

	main.action_row.visible = false
	main._settle_won(bid, 1_000_000, "이사비 협상", 1)
	await create_timer(5.5).timeout  # 한 줄씩 정산
	assert(main.next_btn.visible, "정산 후 다음 버튼이 보여야 함")
	assert(main.wins == 1, "낙찰 1건 기록")

	main._on_next()
	assert(main.idx == 1, "다음 물건으로 이동")

	print("SMOKE OK")
	quit(0)
