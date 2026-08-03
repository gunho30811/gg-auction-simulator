extends SceneTree
## headless 스모크 테스트: godot --headless -s res://tests/smoke.gd
## 조사 → 퀴즈 → 입찰 → 개찰 세리머니 → 잔금 → 명도 → 정산 → 다음 물건 전 구간 호출

func _initialize() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	main._show_tab("comps")
	main._show_tab("rights")
	main._answer_quiz(true)
	assert(main.quiz_state == 1, "실물건 1번: 대항력 있음 → '인수'가 정답이어야 함")
	main._show_tab("site")
	assert(main.seen_tabs.size() == 3, "조사 3종 기록")

	main._quick_bid("min")
	assert(main.bid_edit.text.to_int() * 10_000 >= int(main.auctions[0]["min_price"]),
		"최저가 버튼이 무효 입찰가를 만들면 안 됨")

	# 낙찰 시나리오: 실제 낙찰가(3,150만)보다 높게 입찰
	main.bid_edit.text = "5000"
	main._on_bid()
	await create_timer(18.0).timeout  # 개찰 세리머니 (사건번호+순위 음성 발표 포함)
	assert(main.action_row.visible, "낙찰 후 잔금/포기 선택지가 보여야 함")

	main.action_row.visible = false
	main._pay_balance(50_000_000)
	assert(main.action_row.visible, "점유 물건은 명도 선택지가 보여야 함")

	main.action_row.visible = false
	main._settle_won(50_000_000, 1_000_000, "이사비 협상", 1)
	await create_timer(5.5).timeout  # 한 줄씩 정산
	assert(main.next_btn.visible, "정산 후 다음 버튼이 보여야 함")
	assert(main.wins == 1, "낙찰 1건 기록")

	main._on_next()
	assert(main.idx == 1, "다음 물건으로 이동")

	print("SMOKE OK")
	quit(0)
