extends Control
## 게임 루프: 물건 보기(액자 사진) → 입찰 → 실제 낙찰가와 비교 → 비용 정산

const START_CASH := 2_000_000_000
const IMG_DIR := "res://data/images/"

const COL_BG := Color("12141c")
const COL_CARD := Color("1b1e2a")
const COL_EDGE := Color("2b3044")
const COL_GOLD := Color("e0b95e")
const COL_MUTED := Color("9aa0b4")
const GOLD := "#e0b95e"

var auctions: Array
var rules: Dictionary
var idx := 0
var cash := START_CASH
var wins := 0
var finished := false
var img_idx := 0

var cash_label: Label
var photo: TextureRect
var photo_caption: Label
var info: RichTextLabel
var bid_row: HBoxContainer
var bid_edit: LineEdit
var bid_preview: Label
var result: RichTextLabel
var next_btn: Button
var speech: Label


func _ready() -> void:
	auctions = JSON.parse_string(FileAccess.get_file_as_string("res://data/sample_auctions.json"))
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/cost_rules.json"))
	_build_ui()
	_show_auction()


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
	normal.set_content_margin_all(10)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
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


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_BG
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)
	var title := Label.new()
	title.text = "GG 경매 시뮬레이터"
	title.add_theme_font_size_override("font_size", 30)
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
	cash_label.add_theme_font_size_override("font_size", 19)
	cash_label.add_theme_color_override("font_color", COL_GOLD)
	cash_card.add_child(cash_label)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 22)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	# 액자 (사진 프레임)
	var frame_box := VBoxContainer.new()
	frame_box.add_theme_constant_override("separation", 8)
	content.add_child(frame_box)
	var frame := PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("efe7d4")
	frame_style.set_border_width_all(12)
	frame_style.border_color = Color("4a3222")
	frame_style.set_content_margin_all(16)
	frame_style.shadow_size = 12
	frame_style.shadow_color = Color(0, 0, 0, 0.45)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame_box.add_child(frame)
	photo = TextureRect.new()
	photo.custom_minimum_size = Vector2(420, 320)
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
	right.add_theme_constant_override("separation", 12)
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
	scroll.add_child(scroll_box)

	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.add_theme_font_size_override("normal_font_size", 17)
	info.add_theme_font_size_override("bold_font_size", 17)
	info.add_theme_color_override("default_color", Color("e6e6ee"))
	scroll_box.add_child(info)

	result = RichTextLabel.new()
	result.bbcode_enabled = true
	result.fit_content = true
	result.add_theme_font_size_override("normal_font_size", 17)
	result.add_theme_font_size_override("bold_font_size", 17)
	result.add_theme_color_override("default_color", Color("e6e6ee"))
	result.visible = false
	scroll_box.add_child(result)

	bid_row = HBoxContainer.new()
	bid_row.add_theme_constant_override("separation", 10)
	right.add_child(bid_row)
	var bid_label := Label.new()
	bid_label.text = "입찰가 (만원):"
	bid_row.add_child(bid_label)
	bid_edit = LineEdit.new()
	bid_edit.placeholder_text = "예: 3000 = 3,000만원"
	bid_edit.custom_minimum_size.x = 200
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
	pass_btn.pressed.connect(func() -> void: _reveal(0, true))
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
	jiji.custom_minimum_size = Vector2(96, 96)
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
	img_idx = (img_idx + 1) % imgs.size()
	photo.texture = _load_tex(imgs[img_idx])
	photo_caption.text = "사진 %d/%d (클릭해서 넘기기)" % [img_idx + 1, imgs.size()]


func _show_auction() -> void:
	if idx >= auctions.size():
		_show_end()
		return
	var a: Dictionary = auctions[idx]
	cash_label.text = "보유 자금  %s" % fmt(cash)

	img_idx = 0
	var imgs: Array = a.get("images", [])
	photo.texture = _load_tex(imgs[0]) if imgs.size() > 0 else null
	photo_caption.text = ("사진 1/%d (클릭해서 넘기기)" % imgs.size()) if imgs.size() > 1 else ("" if imgs.size() == 1 else "사진 준비중")

	var warn := ""
	if a.get("notes", "") != "":
		warn = "\n[color=orange]주의: %s[/color]" % a["notes"]
	info.text = ("[b]%s — %s[/b]  [color=#9aa0b4](%d / %d)[/color]\n%s | %s\n전용 %.1f㎡ | 점유: %s\n\n" +
		"감정가: [b][color=%s]%s[/color][/b]\n최저매각가격: [b][color=%s]%s[/color][/b]  (유찰 %d회)\n매각기일: %s%s") % [
		a["case_no"], a["kind"], idx + 1, auctions.size(),
		a["court"], a["address"], a["area_m2"], a["occupancy"],
		GOLD, fmt(int(a["appraisal_price"])), GOLD, fmt(int(a["min_price"])),
		int(a["fail_count"]), a["sale_date"], warn]

	if a.get("tenant_opposing_power", false):
		_say("잠깐! 대항력 있는 임차인이 있어요. 보증금 %s을 인수하게 될 수 있으니 그만큼 싸게 써야 해요!" % fmt(int(a.get("tenant_deposit", 0))))
	elif a.get("occupancy", "") == "유치권신고":
		_say("유치권 신고가 있는 물건이에요. 명도가 오래 걸리고 비용이 커질 수 있어요.")
	else:
		_say("감정가와 시세, 유찰 횟수를 보고 적정 입찰가를 정해보세요. 최저매각가격 미만은 무효예요!")

	bid_edit.clear()
	bid_preview.text = ""
	bid_row.visible = true
	result.visible = false
	next_btn.visible = false


func _on_bid() -> void:
	var bid := bid_edit.text.replace(",", "").to_int() * 10_000
	var a: Dictionary = auctions[idx]
	if bid < int(a["min_price"]):
		bid_preview.text = "최저매각가격 미만 — 입찰 무효!"
		return
	if bid > cash:
		bid_preview.text = "보유 자금 초과!"
		return
	_reveal(bid, false)


func _reveal(bid: int, passed: bool) -> void:
	var a: Dictionary = auctions[idx]
	var actual := int(a["winning_bid"])
	var txt := "실제 낙찰가: [b][color=%s]%s[/color][/b]  (응찰자 %d명, 감정가 대비 %.1f%%)\n" % [
		GOLD, fmt(actual), int(a["bidder_count"]), actual * 100.0 / int(a["appraisal_price"])]
	if int(a.get("second_bid", 0)) > 0:
		txt += "차순위: %s\n" % fmt(int(a["second_bid"]))

	if passed:
		txt += "\n입찰을 포기했습니다."
		_say("때로는 안 사는 게 버는 거죠. 다음 물건 볼까요?")
	elif bid > actual:
		wins += 1
		var items := CostCalc.breakdown(a, bid, rules)
		var tot := CostCalc.total(items)
		var net := int(a["market_price"]) - bid - tot
		cash += net
		txt += "\n[color=%s][b]★ 낙찰![/b][/color] 내 입찰가: [b]%s[/b]\n\n[b]부대비용 정산[/b]\n" % [GOLD, fmt(bid)]
		for it in items:
			txt += "  %s: %s\n" % [it["name"], fmt(int(it["amount"]))]
		txt += "  [b]부대비용 합계: %s[/b]\n\n" % fmt(tot)
		txt += "시세(매각 가정): %s\n" % fmt(int(a["market_price"]))
		var color := "lightgreen" if net >= 0 else "salmon"
		txt += "[color=%s][b]순손익: %s%s[/b][/color]" % [color, "+" if net >= 0 else "", fmt(net)]
		cash_label.text = "보유 자금  %s" % fmt(cash)
		_say("낙~찰! 축하해요!" if net >= 0 else "낙찰은 됐는데... 비용 정산하니 손해네요. 세금과 인수 금액까지 계산하고 입찰해야 해요!")
	else:
		txt += "\n[b]패찰[/b] — 내 입찰가 %s로는 부족했습니다." % fmt(bid)
		_say("아쉽네요! 실제 낙찰자는 %s까지 썼어요." % fmt(actual))

	result.text = txt
	result.visible = true
	bid_row.visible = false
	next_btn.visible = true


func _on_next() -> void:
	if finished:
		idx = 0
		cash = START_CASH
		wins = 0
		finished = false
		next_btn.text = "다음 물건 ▶"
		_show_auction()
		return
	idx += 1
	_show_auction()


func _show_end() -> void:
	finished = true
	var net := cash - START_CASH
	var color := "lightgreen" if net >= 0 else "salmon"
	info.text = ("[b]라운드 종료[/b]\n\n낙찰 %d건 / 전체 %d건\n최종 자산: [b][color=%s]%s[/color][/b]\n" +
		"[color=%s][b]총 손익: %s%s[/b][/color]") % [
		wins, auctions.size(), GOLD, fmt(cash), color, "+" if net >= 0 else "", fmt(net)]
	photo.texture = null
	photo_caption.text = ""
	bid_row.visible = false
	result.visible = false
	next_btn.text = "다시 시작"
	next_btn.visible = true
	_say("수고했어요! 실전 경매도 이렇게 꼼꼼하게 따져보면 어렵지 않아요.")


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
