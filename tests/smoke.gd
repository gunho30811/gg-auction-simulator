extends SceneTree
## headless 스모크 테스트: godot --headless -s res://tests/smoke.gd
## 조사 탭 → 퀴즈 → 입찰 → 개찰 → 다음 물건까지 전 구간 호출

func _initialize() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	main._show_tab("comps")
	main._show_tab("rights")
	main._answer_quiz(true)
	assert(main.quiz_state == 1, "실물건 1번: 대항력 있음 → '인수' 가 정답이어야 함")
	main._show_tab("site")

	main._quick_bid("min")
	var bid: int = main.bid_edit.text.to_int() * 10_000
	assert(bid >= int(main.auctions[0]["min_price"]), "최저가 버튼이 무효 입찰가를 만들면 안 됨")

	main._on_bid()
	await create_timer(2.5).timeout
	assert(main.result.visible, "개찰 후 결과가 보여야 함")
	assert(main.next_btn.visible, "결과 후 다음 버튼이 보여야 함")

	main._on_next()
	assert(main.idx == 1, "다음 물건으로 넘어가야 함")

	print("SMOKE OK")
	quit(0)
