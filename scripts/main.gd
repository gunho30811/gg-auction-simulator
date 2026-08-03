extends Control
## 게임 루프: 조사(실거래·권리분석·현장) → 입찰 → 개찰 연출 → 실제 결과와 비교 → 비용 정산 → 판단 별점

const START_CASH := 2_000_000_000
const IMG_DIR := "res://data/images/"
const SFX_NAMES := ["click", "gavel", "win", "lose", "correct", "wrong", "coin"]

const COL_BG := Color("12141c")
const COL_CARD := Color("1b1e2a")
const COL_EDGE := Color("2b3044")
const COL_GOLD := Color("e0b95e")
const COL_MUTED := Color("9aa0b4")
const GOLD := "#e0b95e"
const MUTED := "#9aa0b4"

var auctions: Array
var rules: Dictionary
var idx := 0
var cash := START_CASH
var wins := 0
var stars_total := 0
var finished := false
var img_idx := 0
var opening := false

# 물건별 조사 상태
var quiz_state := 0  # 0=미응답 1=정답 2=오답
var seen_tabs := {}

var sfx := {}
var sfx_player: AudioStreamPlayer

var cash_label: Label
var photo: TextureRect
var photo_caption: Label
var info: RichTextLabel
var tab_row: HBoxContainer
var detail: RichTextLabel
var quiz_row: HBoxContainer
var bid_row: HBoxContainer
var bid_edit: LineEdit
var bid_preview: Label
var result: RichTextLabel
var next_btn: Button
var speech: Label


func _ready() -> void:
	auctions = JSON.parse_string(FileAccess.get_file_as_string("res://data/sample_auctions.json"))
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/cost_rules.json"))
	for n in SFX_NAMES:
		sfx[n] = load("res://assets/sfx/%s.wav" % n)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = -6.0
	add_child(sfx_player)
	_build_ui()
	_show_auction()


func _play(name: String) -> void:
	sfx_player.stream = sfx[name]
	sfx_player.play()


func _card(bg: Color, edge: Color, radius := 12, border := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = edge
	s.set_content_margin_all(14)
	return s


func _style_button(b: Button, primary: bool) -> void:
	var bg := COL_GOLD if primary else COL_CARD
	var normal := _card(bg, COL_GOLD if primary else COL_EDGE, 8, 1)
	normal.set_content_margin_all(9)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("f0cd7a") if primary else Color("242a3c")
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("c9a44b") if primary else Color("161927")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	var fc := Color("1a1508") if primary else Color("e6e6ee")
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, fc)


func _make_rich(font_size := 17) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_font_size_override("bold_font_size", font_size)
	r.add_theme_color_override("default_color", Color("e6e6ee"))
	return r


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_BG
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)
	var title := Label.new()
	title.text = "GG 경매 시뮬레이터"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COL_GOLD)
	header.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "지지옥션 실데이터 기반"
	subtitle.add_theme_color_override("font_color", COL_MUTED)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(subtitle)
	var cash_card := PanelContainer.new()
	cash_card.add_theme_stylebox_override("panel", _card(COL_CARD, COL_GOLD, 10))
	header.add_child(cash_card)
	cash_label = Label.new()
	cash_label.add_theme_font_size_override("font_size", 18)
	cash_label.add_theme_color_override("font_color", COL_GOLD)
	cash_card.add_child(cash_label)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	# 액자 (사진 프레임)
	var frame_box := VBoxContainer.new()
	frame_box.add_theme_constant_override("separation", 6)
	content.add_child(frame_box)
	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("efe7d4")
	frame_style.set_border_width_all(12)
	frame_style.border_color = Color("4a3222")
	frame_style.set_content_margin_all(14)
	frame_style.shadow_size = 12
	frame_style.shadow_color = Color(0, 0, 0, 0.45)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame_box.add_child(frame)
	photo = TextureRect.new()
	photo.custom_minimum_size = Vector2(380, 285)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_next_photo())
	frame.add_child(photo)
	photo_caption = Label.new()
	photo_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	photo_caption.add_theme_color_override("font_color", COL_MUTED)
	frame_box.add_child(photo_caption)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	content.add_child(right)

	var info_card := PanelContainer.new()
	info_card.add_theme_stylebox_override("panel", _card(COL_CARD, COL_EDGE))
	info_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(info_card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_card.add_child(scroll)
	var scroll_box := VBoxContainer.new()
	scroll_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_box.add_theme_constant_override("separation", 10)
	scroll.add_child(scroll_box)

	info = _make_rich()
	scroll_box.add_child(info)

	# 조사 탭
	tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	scroll_box.add_child(tab_row)
	for tab in [["comps", "실거래·시세"], ["rights", "권리분석"], ["site", "현장조사"]]:
		var b := Button.new()
		b.text = tab[1]
		_style_button(b, false)
		b.pressed.connect(_show_tab.bind(tab[0]))
		tab_row.add_child(b)

	detail = _make_rich(16)
	scroll_box.add_child(detail)

	quiz_row = HBoxContainer.new()
	quiz_row.add_theme_constant_override("separation", 8)
	quiz_row.visible = false
	scroll_box.add_child(quiz_row)
	for q in [["인수된다 (내가 떠안음)", true], ["소멸된다 (배당으로 정리)", false]]:
		var b := Button.new()
		b.text = q[0]
		_style_button(b, false)
		b.pressed.connect(_answer_quiz.bind(q[1]))
		quiz_row.add_child(b)

	result = _make_rich()
	result.visible = false
	scroll_box.add_child(result)

	# 입찰 행 (빠른 버튼 + 직접 입력)
	bid_row = HBoxContainer.new()
	bid_row.add_theme_constant_override("separation", 8)
	right.add_child(bid_row)
	for quick in [["최저가", "min"], ["감정가 80%", "a80"], ["감정가", "a100"]]:
		var b := Button.new()
		b.text = quick[0]
		_style_button(b, false)
		b.pressed.connect(_quick_bid.bind(quick[1]))
		bid_row.add_child(b)
	bid_edit = LineEdit.new()
	bid_edit.placeholder_text = "만원 단위"
	bid_edit.custom_minimum_size.x = 140
	bid_edit.text_changed.connect(func(t: String) -> void:
		bid_preview.text = fmt(t.replace(",", "").to_int() * 10_000))
	bid_edit.text_submitted.connect(func(_t: String) -> void: _on_bid())
	bid_row.add_child(bid_edit)
	bid_preview = Label.new()
	bid_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bid_preview.add_theme_color_override("font_color", COL_GOLD)
	bid_row.add_child(bid_preview)
	var bid_btn := Button.new()
	bid_btn.text = "입찰하기"
	bid_btn.pressed.connect(_on_bid)
	_style_button(bid_btn, true)
	bid_row.add_child(bid_btn)
	var pass_btn := Button.new()
	pass_btn.text = "패스"
	pass_btn.pressed.connect(func() -> void: _open_bids(0, true))
	_style_button(pass_btn, false)
	bid_row.add_child(pass_btn)

	next_btn = Button.new()
	next_btn.text = "다음 물건 ▶"
	next_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	next_btn.visible = false
	next_btn.pressed.connect(_on_next)
	_style_button(next_btn, true)
	right.add_child(next_btn)

	# 캐릭터 '지지' + 말풍선
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)
	var jiji := TextureRect.new()
	jiji.texture = load("res://assets/characters/jiji.svg")
	jiji.custom_minimum_size = Vector2(88, 88)
	jiji.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	jiji.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	footer.add_child(jiji)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _card(COL_CARD, COL_GOLD, 14))
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(bubble)
	speech = Label.new()
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speech.add_theme_color_override("font_color", Color("efe3c2"))
	bubble.add_child(speech)


func _load_tex(file: String) -> Texture2D:
	var path := IMG_DIR + file
	if ResourceLoader.exists(path):
		return load(path)
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img else null


func _next_photo() -> void:
	var imgs: Array = auctions[idx].get("images", [])
	if imgs.size() < 2:
		return
	_play("click")
	img_idx = (img_idx + 1) % imgs.size()
	photo.texture = _load_tex(imgs[img_idx])
	photo_caption.text = "사진 %d/%d (클릭해서 넘기기)" % [img_idx + 1, imgs.size()]


func _show_auction() -> void:
	if idx >= auctions.size():
		_show_end()
		return
	var a: Dictionary = auctions[idx]
	cash_label.text = "보유 자금  %s" % fmt(cash)
	quiz_state = 0
	seen_tabs = {}

	img_idx = 0
	var imgs: Array = a.get("images", [])
	photo.texture = _load_tex(imgs[0]) if imgs.size() > 0 else null
	photo_caption.text = ("사진 1/%d (클릭해서 넘기기)" % imgs.size()) if imgs.size() > 1 else ("" if imgs.size() == 1 else "사진 준비중")

	var age := ""
	if a.get("built_date", "") != "":
		age = " | %s년 사용승인" % a["built_date"].substr(0, 4)
	info.text = ("[b]%s — %s[/b]  [color=%s](%d / %d)[/color]\n%s | %s\n전용 %.1f㎡ | 대지권 %.1f㎡%s | 점유: %s\n\n" +
		"감정가: [b][color=%s]%s[/color][/b]\n최저매각가격: [b][color=%s]%s[/color][/b]  (유찰 %d회)\n매각기일: %s") % [
		a["case_no"], a["kind"], MUTED, idx + 1, auctions.size(),
		a["court"], a["address"], a["area_m2"], a.get("land_share_m2", 0.0), age, a["occupancy"],
		GOLD, fmt(int(a["appraisal_price"])), GOLD, fmt(int(a["min_price"])),
		int(a["fail_count"]), a["sale_date"]]

	detail.text = "[color=%s]입찰 전에 위 탭으로 조사하세요 — 실거래로 시세를 가늠하고, 권리분석으로 인수 위험을 판단하고, 현장조사로 상태를 확인합니다.[/color]" % MUTED
	quiz_row.visible = false
	_say("입찰 전 조사가 반이에요. 실거래·권리분석·현장조사 탭을 눌러보세요!")

	bid_edit.clear()
	bid_preview.text = ""
	bid_row.visible = true
	result.visible = false
	next_btn.visible = false
	opening = false


func _show_tab(which: String) -> void:
	_play("click")
	seen_tabs[which] = true
	var a: Dictionary = auctions[idx]
	quiz_row.visible = false
	match which:
		"comps":
			var t := "[b]■ 실거래·시세 (거래사례비교법)[/b]\n감정평가사는 인근 유사물건의 실거래에 시점보정을 해서 가치를 산정해요.\n\n"
			for c in a.get("comps", []):
				t += "  · %s — [color=%s]%s[/color] (%s)\n" % [c["label"], GOLD, fmt(int(c["price"])), c["date"]]
			if a.get("comps", []).is_empty():
				t += "  (사례 자료 없음)\n"
			if a.get("price_index_note", "") != "":
				t += "  · 가격지수: %s\n" % a["price_index_note"]
			t += "\n[color=%s]→ 이 사례들로 '지금 시세'를 스스로 추정해보세요. 감정가는 과거 기준시점의 값입니다.[/color]" % MUTED
			detail.text = t
		"rights":
			var t := "[b]■ 권리분석 (매각물건명세서)[/b]\n말소기준권리: [b]%s %s 설정[/b]\n" % [a.get("base_rights_date", "?"), a.get("base_rights_kind", "")]
			var tenants: Array = a.get("tenants", [])
			if tenants.is_empty():
				t += "\n등재된 임차인 없음 — 낙찰 시 모든 권리는 말소됩니다. 깨끗한 물건이에요."
				detail.text = t
			else:
				for tn in tenants:
					t += "\n[b]%s[/b]\n  보증금 [color=%s]%s[/color] | 전입 %s | 확정일자 %s | 배당요구 %s\n" % [
						tn["label"], GOLD, fmt(int(tn["deposit"])), tn["move_in"], tn["fixed_date"],
						"O" if tn.get("dividend_demand", false) else "X"]
					if tn.get("note", "") != "":
						t += "  ※ %s\n" % tn["note"]
				if quiz_state == 0:
					t += "\n[b][color=%s]Q. 이 임차인의 보증금, 낙찰자에게 인수될까요?[/color][/b]\n(힌트: 전입일과 말소기준권리 설정일을 비교하세요)" % GOLD
					quiz_row.visible = true
				else:
					t += "\n" + _quiz_explain(a)
				detail.text = t
		"site":
			var t := "[b]■ 현장조사 (임장)[/b]\n"
			t += "점유 현황: %s\n" % a["occupancy"]
			if int(a.get("unpaid_mgmt_fee", 0)) > 0:
				t += "미납 관리비: [color=%s]%s[/color] (공용부분은 매수인 인수)\n" % [GOLD, fmt(int(a["unpaid_mgmt_fee"]))]
			if a.get("site_notes", "") != "":
				t += "%s\n" % a["site_notes"]
			if a.get("notes", "") != "":
				t += "[color=orange]※ %s[/color]" % a["notes"]
			detail.text = t


func _quiz_explain(a: Dictionary) -> String:
	var tn: Dictionary = a["tenants"][0]
	var opposing := bool(a.get("tenant_opposing_power", false))
	var verdict := "[color=salmon][b]인수됩니다[/b][/color]" if opposing else "[color=lightgreen][b]소멸합니다[/b][/color]"
	var reason := ""
	if opposing:
		reason = "전입일(%s)이 말소기준권리(%s)보다 [b]빠르므로 대항력이 있어요[/b]. 배당으로 전액 변제되지 않으면 잔액을 낙찰자가 떠안습니다." % [tn["move_in"], a["base_rights_date"]]
	else:
		reason = "전입일(%s)이 말소기준권리(%s)보다 [b]늦어 대항력이 없어요[/b]. 보증금은 배당 절차에서 정리되고 낙찰자가 인수하지 않습니다." % [tn["move_in"], a["base_rights_date"]]
	var grade := "정답!" if quiz_state == 1 else "오답 —"
	return "[b]%s[/b] 보증금은 %s\n%s" % [grade, verdict, reason]


func _answer_quiz(said_assumed: bool) -> void:
	var a: Dictionary = auctions[idx]
	var truth := bool(a.get("tenant_opposing_power", false))
	quiz_state = 1 if said_assumed == truth else 2
	_play("correct" if quiz_state == 1 else "wrong")
	_say("정확해요! 권리분석이 몸에 배셨네요." if quiz_state == 1 else "아쉬워요. 전입일이 말소기준권리보다 빠른지만 보면 돼요!")
	_show_tab("rights")


func _quick_bid(kind: String) -> void:
	_play("click")
	var a: Dictionary = auctions[idx]
	var v := 0
	match kind:
		"min": v = int(a["min_price"])
		"a80": v = int(int(a["appraisal_price"]) * 0.8)
		"a100": v = int(a["appraisal_price"])
	var man := ceili(v / 10_000.0)  # 내림하면 최저가 미만(무효)이 될 수 있어 올림
	bid_edit.text = str(man)
	bid_preview.text = fmt(man * 10_000)


func _on_bid() -> void:
	if opening:
		return
	var bid := bid_edit.text.replace(",", "").to_int() * 10_000
	var a: Dictionary = auctions[idx]
	if bid < int(a["min_price"]):
		bid_preview.text = "최저매각가격 미만 — 입찰 무효!"
		_play("wrong")
		return
	if bid > cash:
		bid_preview.text = "보유 자금 초과!"
		_play("wrong")
		return
	_open_bids(bid, false)


func _open_bids(bid: int, passed: bool) -> void:
	opening = true
	bid_row.visible = false
	quiz_row.visible = false
	result.visible = true
	if passed:
		result.text = "[color=%s]입찰을 포기하고 개찰을 지켜봅니다...[/color]" % MUTED
	else:
		result.text = "[color=%s]입찰표 제출 완료. 개찰 중...[/color]" % MUTED
		_play("click")
	_say("두구두구...")
	await get_tree().create_timer(1.4).timeout
	_play("gavel")
	await get_tree().create_timer(0.5).timeout
	_reveal(bid, passed)
	opening = false


func _case_costs(a: Dictionary, price: int) -> int:
	return CostCalc.total(CostCalc.breakdown(a, price, rules))


func _reveal(bid: int, passed: bool) -> void:
	var a: Dictionary = auctions[idx]
	var actual := int(a["winning_bid"])
	var market := int(a["market_price"])
	var txt := "실제 낙찰가: [b][color=%s]%s[/color][/b]  (응찰자 %d명, 감정가 대비 %.1f%%)\n" % [
		GOLD, fmt(actual), int(a["bidder_count"]), actual * 100.0 / int(a["appraisal_price"])]
	if int(a.get("second_bid", 0)) > 0:
		txt += "차순위: %s\n" % fmt(int(a["second_bid"]))

	# 판단 별점: 퀴즈(1) + 판단(2)
	var stars := 0
	if a.get("tenants", []).is_empty():
		stars += 1
	elif quiz_state == 1:
		stars += 1

	if passed:
		var would_net := market - actual - _case_costs(a, actual)
		if would_net < 0:
			stars += 2
			txt += "\n[b]패스[/b] — 좋은 판단! 실제 낙찰자는 정산하면 [color=salmon]%s 손해[/color]였을 물건이에요." % fmt(would_net)
			_say("함정을 피했네요. 프로다워요!")
			_play("correct")
		else:
			txt += "\n[b]패스[/b] — 실제 낙찰자는 정산 후 [color=lightgreen]약 %s 수익[/color]을 봤어요. 아까웠네요!" % fmt(would_net)
			_say("신중한 것도 실력이지만, 이건 기회였어요.")
			_play("lose")
	elif bid > actual:
		wins += 1
		var items := CostCalc.breakdown(a, bid, rules)
		var tot := CostCalc.total(items)
		var net := market - bid - tot
		cash += net
		if net >= 0:
			stars += 2
		txt += "\n[color=%s][b]★ 낙찰![/b][/color] 내 입찰가: [b]%s[/b]\n\n[b]부대비용 정산[/b]\n" % [GOLD, fmt(bid)]
		for it in items:
			txt += "  %s: %s\n" % [it["name"], fmt(int(it["amount"]))]
		txt += "  [b]부대비용 합계: %s[/b]\n\n" % fmt(tot)
		txt += "시세(매각 가정): %s\n" % fmt(market)
		var color := "lightgreen" if net >= 0 else "salmon"
		txt += "[color=%s][b]순손익: %s%s[/b][/color]\n" % [color, "+" if net >= 0 else "", fmt(net)]
		cash_label.text = "보유 자금  %s" % fmt(cash)
		_say("낙~찰! 수익까지 완벽해요!" if net >= 0 else "낙찰은 됐지만 정산하면 손해예요. 인수 금액과 세금까지 계산했어야 해요!")
		_play("win" if net >= 0 else "lose")
		if net >= 0:
			_play_delayed("coin", 0.8)
	else:
		txt += "\n[b]패찰[/b] — 내 입찰가 %s로는 부족했어요." % fmt(bid)
		var would_net := market - actual - _case_costs(a, actual)
		if would_net < 0:
			stars += 2
			txt += "\n[color=%s]하지만 실제 낙찰가로는 %s 손해였을 물건 — 무리하지 않은 게 정답![/color]" % [MUTED, fmt(would_net)]
		_say("아쉽네요! 실전에선 1만원 차이로도 갈려요.")
		_play("lose")

	stars_total += stars
	txt += "\n이번 판단 평가: [color=%s]%s%s[/color]" % [GOLD, "★".repeat(stars), "☆".repeat(3 - stars)]
	result.text = txt
	next_btn.visible = true


func _play_delayed(name: String, sec: float) -> void:
	get_tree().create_timer(sec).timeout.connect(_play.bind(name))


func _on_next() -> void:
	_play("click")
	if finished:
		idx = 0
		cash = START_CASH
		wins = 0
		stars_total = 0
		finished = false
		next_btn.text = "다음 물건 ▶"
		_show_auction()
		return
	idx += 1
	_show_auction()


func _show_end() -> void:
	finished = true
	var net := cash - START_CASH
	var max_stars := auctions.size() * 3
	var ratio := float(stars_total) / max_stars
	var grade := "S" if ratio >= 0.8 else ("A" if ratio >= 0.6 else ("B" if ratio >= 0.4 else "C"))
	var color := "lightgreen" if net >= 0 else "salmon"
	info.text = ("[b]라운드 종료[/b]\n\n낙찰 %d건 / 전체 %d건\n판단 별점: [color=%s]%d / %d[/color]\n" +
		"최종 자산: [b][color=%s]%s[/color][/b]\n[color=%s][b]총 손익: %s%s[/b][/color]\n\n" +
		"[b]최종 등급: [color=%s]%s[/color][/b]") % [
		wins, auctions.size(), GOLD, stars_total, max_stars,
		GOLD, fmt(cash), color, "+" if net >= 0 else "", fmt(net), GOLD, grade]
	detail.text = ""
	photo.texture = null
	photo_caption.text = ""
	bid_row.visible = false
	quiz_row.visible = false
	result.visible = false
	next_btn.text = "다시 시작"
	next_btn.visible = true
	_play("win" if grade in ["S", "A"] else "lose")
	_say("등급 %s! 수고했어요. 조사 → 판단 → 입찰, 실전 경매도 똑같아요." % grade)


func _say(msg: String) -> void:
	speech.text = msg


static func fmt(n: int) -> String:
	var sign := "-" if n < 0 else ""
	n = absi(n)
	var eok := n / 100_000_000
	var man := (n % 100_000_000) / 10_000
	var rest := n % 10_000
	var parts: PackedStringArray = []
	if eok > 0:
		parts.append("%d억" % eok)
	if man > 0:
		parts.append("%s만" % _comma(man))
	if rest > 0 or parts.is_empty():
		parts.append(_comma(rest))
	return sign + " ".join(parts) + "원"


static func _comma(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
