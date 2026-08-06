extends SceneTree
## headless 스모크 테스트: godot --headless -s res://tests/smoke.gd
## 조사 → 퀴즈 → 입찰 → 개찰 세리머니 → 잔금 → 명도 → 정산 → 다음 물건 전 구간 호출
## 물건 데이터가 바뀌어도 돌도록 수치는 auctions[0]에서 가져온다.

func _initialize() -> void:
	await _check_setup()

	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	var a: Dictionary = main.auctions[0]
	assert(main.photo.texture != null, "물건 사진(원본 JPEG)이 디코드되어야 함")
	assert(main.photo.texture.get_width() > 100, "사진이 제대로 된 크기여야 함")
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
	assert(main.reveal_line != null and is_instance_valid(main.reveal_line),
		"개찰 뒤 금액 직선이 떠 있어야 함")

	main.action_row.visible = false
	main._pay_balance(bid)
	await create_timer(1.8).timeout  # '명도 발생' 임팩트 컷이 지나가길 기다린다
	if str(a.get("occupancy", "공실")) != "공실":
		# 점유 물건이면 명도 선택지가 뜨고, 공실이면 _pay_balance 안에서 정산까지 끝난다
		assert(main.action_row.visible, "점유 물건은 명도 선택지가 보여야 함")
		main.action_row.visible = false
		main._settle_won(bid, 1_000_000, "이사비 협상", 1)
	await create_timer(5.5).timeout  # 한 줄씩 정산
	assert(main.next_btn.visible, "정산 후 다음 버튼이 보여야 함")
	assert(main.wins == 1, "낙찰 1건 기록")

	# 칭호·스토리: 한 건 끝내면 칭호가 붙고, 결말 문구가 준비돼 있어야 한다
	var g: Node = root.get_node("/root/Game")
	assert(not g.earned.is_empty(), "낙찰 한 건이면 칭호가 하나는 붙어야 함")
	assert(g.stat("cases_done") == 1.0 and g.stat("wins") == 1.0, "누적 통계가 쌓여야 함")
	for key in ["won_profit", "lost_curse", "passed_right", "forfeit"]:
		assert(g.line("outcome", key) != "", "결말 문구 '%s' 가 있어야 함" % key)
	assert(not g.chapter_at(1).is_empty(), "1번째 물건 챕터가 있어야 함")

	main._on_next()
	assert(main.idx == 1, "다음 물건으로 이동")

	print("SMOKE OK")
	quit(0)


## 입찰 준비 화면: 계열 → 종 → 용도 3단 선택이 실제 물건 수와 맞물리는지
func _check_setup() -> void:
	var setup: Control = load("res://scenes/setup.tscn").instantiate()
	root.add_child(setup)
	await process_frame

	var leaves: Array = []
	for series in setup.taxonomy.values():
		for jong in series.values():
			leaves.append_array(jong)
	for a in setup.auctions:
		assert(str(a["kind"]) in leaves, "물건 용도 '%s' 가 usage_taxonomy에 없음" % a["kind"])

	# 진행 축: 목적 → 난이도
	var game: Node = root.get_node("/root/Game")  # -s 모드에선 autoload 전역이 안 잡힘
	setup._reselect(setup.purpose_opt, "내 집 마련")
	setup._refresh_axes()
	assert(game.purpose == "내 집 마련", "목적이 반영되어야 함")
	var by_purpose: Array = game.filter_auctions(setup.auctions)
	assert(by_purpose.size() > 0, "목적으로 걸러진 물건이 있어야 함")
	for a in by_purpose:
		assert(game.purpose_of(a) == "내 집 마련", "다른 목적 물건이 섞이면 안 됨")

	setup._reselect(setup.diff_opt, "위험")
	setup._refresh_axes()
	for a in game.filter_auctions(setup.auctions):
		assert(game.difficulty_of(a) == "위험", "다른 난이도가 섞이면 안 됨")
	setup._reselect(setup.purpose_opt, "")
	setup._reselect(setup.diff_opt, "")
	setup._refresh_axes()

	# 상세 용도 필터(지지옥션 분류)를 펴야 용도로 고를 수 있다
	setup.detail_btn.button_pressed = true
	setup._toggle_detail(true)
	setup.series_opt.select(1)  # 주거시설
	setup._refresh_jong()
	setup._reselect(setup.jong_opt, "공동주택")
	setup._refresh_kind()
	var kinds: Array = []
	for i in setup.kind_opt.get_item_count():
		kinds.append(setup.kind_opt.get_item_text(i))
	assert(kinds.any(func(t: String) -> bool: return t.begins_with("아파트 (")),
		"공동주택 용도 목록에 아파트가 있어야 함: %s" % str(kinds))

	setup._reselect(setup.kind_opt, "아파트")
	setup._refresh()
	assert(game.kinds == ["아파트"], "용도를 고르면 그 용도만 필터에 들어가야 함")
	assert(game.filter_auctions(setup.auctions).size() > 0, "아파트 물건이 걸러져 나와야 함")

	# 라운드 물건 수 — 고른 만큼만 뽑혀야 한다
	setup.round_opt.select(0)  # 10건
	setup._refresh()
	assert(game.round_size == 10, "라운드 물건 수가 반영되어야 함")
	assert(game.shuffled_for_play(setup.auctions).size() == 10, "라운드 수만큼만 나와야 함")
	setup.round_opt.select(5)  # 제한 없음
	setup._refresh()
	assert(game.shuffled_for_play(setup.auctions).size() == setup.auctions.size(),
		"제한 없음이면 전부 나와야 함")

	# 등장 순서가 매번 달라야 한다
	var a1: Array = game.shuffled_for_play(setup.auctions)
	var a2: Array = game.shuffled_for_play(setup.auctions)
	assert(a1[0] != a2[0] or a1[1] != a2[1], "섞을 때마다 순서가 달라야 함")
	setup.round_opt.select(1)  # 20건으로 되돌림

	setup.queue_free()
	game.kinds = []
	game.region = []
	game.purpose = ""
	game.difficulty = ""
	game.round_size = 20
	await process_frame
