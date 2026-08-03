extends Control
## 낙찰자의 여정: 조사(시세 범위 좁히기·권리분석·임장) → 입찰(보증금) → 개찰 세리머니
## → 낙찰 시 잔금/포기 결정 → 명도 선택 → 한 줄씩 정산 → 3축 별점

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
var cash_shown := START_CASH
var wins := 0
var stars_total := 0
var finished := false
var img_idx := 0
var busy := false

# 물건별 조사 상태
var quiz_state := 0  # 0=미응답 1=정답 2=오답
var seen_tabs := {}
var views: PackedStringArray = []  # 액자 표시 목록: [일러스트, 실사...]

var sfx := {}
var sfx_player: AudioStreamPlayer

var cash_label: Label
var photo: TextureRect
var photo_caption: Label
var info: RichTextLabel
var tab_row: HBoxContainer
var detail: RichTextLabel
var quiz_row: HBoxContainer
var action_row: HBoxContainer
var range_label: Label
var bid_row: HBoxContainer
var bid_edit: LineEdit
var bid_preview: Label
var result: RichTextLabel
var court: TextureRect
var dim: ColorRect
var content: HBoxContainer
var call_bubble: PanelContainer
var call_label: Label
var next_btn: Button
var speech: Label
var frame_panel: PanelContainer


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


func _update_cash() -> void:
	Juice.count(cash_label, cash_shown, cash, func(v: int) -> void:
		cash_label.text = "보유 자금  " + fmt(v))
	if cash != cash_shown:
		Juice.punch(cash_label)
	cash_shown = cash


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
	Juice.button(b)


func _make_rich(font_size := 17) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_font_size_override("bold_font_size", font_size)
	r.add_theme_color_override("default_color", Color("e6e6ee"))
	return r


func _build_ui() -> void:
	# 1인칭 경매 법정 배경 (art_src/render_courtroom.py 렌더)
	court = TextureRect.new()
	court.texture = load("res://assets/art/courtroom.png")
	court.set_anchors_preset(Control.PRESET_FULL_RECT)
	court.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	court.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(court)
	dim = ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.07, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_make_dust()

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0)
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

	content = HBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	# 액자 (사진 프레임)
	var frame_box := VBoxContainer.new()
	frame_box.add_theme_constant_override("separation", 6)
	content.add_child(frame_box)
	frame_panel = PanelContainer.new()
	var frame := frame_panel
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

	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	action_row.visible = false
	scroll_box.add_child(action_row)

	range_label = Label.new()
	range_label.add_theme_color_override("font_color", COL_MUTED)
	right.add_child(range_label)

	bid_row = HBoxContainer.new()
	bid_row.add_theme_constant_override("separation", 8)
	right.add_child(bid_row)
	for quick in [["최저가", "min"], ["분석 하한", "lo"], ["분석 상한", "hi"]]:
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
	pass_btn.pressed.connect(func() -> void: _ceremony(0, true))
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
	jiji.texture = load("res://assets/characters/jiji3d.png")
	jiji.custom_minimum_size = Vector2(88, 88)
	jiji.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	jiji.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	footer.add_child(jiji)
	jiji.pivot_offset = Vector2(44, 60)
	var idle := jiji.create_tween().set_loops()
	idle.tween_property(jiji, "rotation", 0.05, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle.tween_property(jiji, "rotation", -0.05, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _card(COL_CARD, COL_GOLD, 14))
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(bubble)
	speech = Label.new()
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speech.add_theme_color_override("font_color", Color("efe3c2"))
	bubble.add_child(speech)

	# 집행관 호명 말풍선 (단상 위, 개찰 때만)
	var call_center := CenterContainer.new()
	call_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	call_center.offset_top = 70
	call_center.offset_bottom = 200
	call_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(call_center)
	call_bubble = PanelContainer.new()
	var cb := _card(Color(0.08, 0.09, 0.14, 0.92), COL_GOLD, 18, 2)
	cb.set_content_margin_all(20)
	cb.content_margin_left = 34
	cb.content_margin_right = 34
	call_bubble.add_theme_stylebox_override("panel", cb)
	call_bubble.visible = false
	call_center.add_child(call_bubble)
	call_label = Label.new()
	call_label.add_theme_font_size_override("font_size", 30)
	call_label.add_theme_color_override("font_color", Color("f5e6bd"))
	call_bubble.add_child(call_label)


## 금가루 부유 파티클 — 공간에 깊이감
func _make_dust() -> void:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for x in 12:
		for y in 12:
			var d := Vector2(x - 5.5, y - 5.5).length() / 5.5
			img.set_pixel(x, y, Color(1.0, 0.85, 0.5, clampf(1.0 - d, 0.0, 1.0) * 0.5))
	var p := CPUParticles2D.new()
	p.texture = ImageTexture.create_from_image(img)
	p.amount = 26
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(700, 400)
	p.position = Vector2(640, 430)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.3
	p.modulate = Color(1, 1, 1, 0.4)
	add_child(p)


## 액자 유사 3D 틸트 — 마우스를 따라 기울어짐
func _process(_dt: float) -> void:
	if frame_panel == null:
		return
	var r := frame_panel.get_global_rect()
	frame_panel.pivot_offset = frame_panel.size / 2.0
	if r.has_point(get_global_mouse_position()):
		var m := (get_global_mouse_position() - r.position) / r.size - Vector2(0.5, 0.5)
		frame_panel.rotation = lerpf(frame_panel.rotation, m.x * 0.05, 0.15)
		frame_panel.scale = frame_panel.scale.lerp(Vector2(1.025, 1.025), 0.15)
	else:
		frame_panel.rotation = lerpf(frame_panel.rotation, 0.0, 0.12)
		frame_panel.scale = frame_panel.scale.lerp(Vector2.ONE, 0.12)


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img else null


## 물건 종류별 3D 렌더 일러스트 (제작: art_src/render_props.py)
func _art_for(kind: String) -> String:
	if kind == "아파트":
		return "res://assets/art/apt.png"
	if kind in ["다세대", "연립", "단독주택", "주택", "빌라"]:
		return "res://assets/art/villa.png"
	if kind in ["상가", "오피스텔", "근린시설", "근린상가"]:
		return "res://assets/art/shop.png"
	return "res://assets/art/land.png"


func _view_caption() -> String:
	if views.size() == 1:
		return "일러스트"
	if img_idx == views.size() - 1:
		return "일러스트 (클릭해서 처음으로)"
	return "실사 %d/%d (클릭해서 넘기기)" % [img_idx + 1, views.size() - 1]


func _next_photo() -> void:
	if views.size() < 2:
		return
	_play("click")
	img_idx = (img_idx + 1) % views.size()
	photo.texture = _load_tex(views[img_idx])
	photo_caption.text = _view_caption()


func _deposit(a: Dictionary) -> int:
	return int(int(a["min_price"]) * float(rules.get("bid_deposit_rate", 0.1)))


## 조사할수록 좁아지는 시세 분석 범위 (정답은 절대 직접 노출하지 않음)
func _analysis_range(a: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(a["case_no"])
	var center := int(int(a["market_price"]) * rng.randf_range(0.96, 1.04))
	var widths := [0.25, 0.15, 0.10, 0.06]
	var w: float = widths[clampi(seen_tabs.size(), 0, 3)]
	return [int(center * (1.0 - w)), int(center * (1.0 + w))]


func _update_range() -> void:
	var r := _analysis_range(auctions[idx])
	range_label.text = "내 시세 분석: %s ~ %s  (조사 %d/3 — 조사할수록 좁아져요)" % [fmt(r[0]), fmt(r[1]), seen_tabs.size()]


func _show_auction() -> void:
	if idx >= auctions.size():
		_show_end()
		return
	var a: Dictionary = auctions[idx]
	_update_cash()
	quiz_state = 0
	seen_tabs = {}

	img_idx = 0
	views.clear()
	for f in a.get("images", []):
		views.append(IMG_DIR + f)  # 실사 먼저 — 시각적 임팩트
	views.append(_art_for(a.get("kind", "")))
	photo.texture = _load_tex(views[0])
	photo_caption.text = _view_caption()

	var age := ""
	if a.get("built_date", "") != "":
		age = " | %s년 사용승인" % a["built_date"].substr(0, 4)
	info.text = ("[b]%s — %s[/b]  [color=%s](%d / %d)[/color]\n%s | %s\n전용 %.1f㎡ | 대지권 %.1f㎡%s | 점유: %s\n\n" +
		"감정가: [b][color=%s]%s[/color][/b]\n최저매각가격: [b][color=%s]%s[/color][/b]  (유찰 %d회)\n" +
		"입찰보증금(최저가 10%%): [b]%s[/b] — 낙찰 후 잔금 포기 시 몰수!\n매각기일: %s") % [
		a["case_no"], a["kind"], MUTED, idx + 1, auctions.size(),
		a["court"], a["address"], a["area_m2"], a.get("land_share_m2", 0.0), age, a["occupancy"],
		GOLD, fmt(int(a["appraisal_price"])), GOLD, fmt(int(a["min_price"])),
		int(a["fail_count"]), fmt(_deposit(a)), a["sale_date"]]

	detail.text = "[color=%s]입찰 전에 위 탭으로 조사하세요. 조사한 만큼 시세 분석 범위가 좁아지고, 권리 함정이 보입니다.[/color]" % MUTED
	quiz_row.visible = false
	action_row.visible = false
	_update_range()
	_say("입찰 전 조사가 반이에요. 조사를 건너뛰면 분석 범위가 넓어서 감으로 쓰게 돼요!")

	bid_edit.clear()
	bid_preview.text = ""
	bid_row.visible = true
	result.visible = false
	next_btn.visible = false
	busy = false


func _show_tab(which: String) -> void:
	if busy:
		return
	_play("click")
	seen_tabs[which] = true
	_update_range()
	var a: Dictionary = auctions[idx]
	quiz_row.visible = false
	match which:
		"comps":
			var t := "[b]■ 실거래·시세[/b]\n입찰가의 기준은 감정가가 아니라 '지금 시세'예요. 감정 시점은 과거입니다.\n\n"
			for c in a.get("comps", []):
				t += "  · %s — [color=%s]%s[/color] (%s)\n" % [c["label"], GOLD, fmt(int(c["price"])), c["date"]]
			if a.get("comps", []).is_empty():
				t += "  (사례 자료 없음)\n"
			if a.get("price_index_note", "") != "":
				t += "  · 가격지수: %s\n" % a["price_index_note"]
			t += "\n[color=%s]→ 위 사례와 지수로 내 분석 범위가 좁아졌어요 (아래 확인).[/color]" % MUTED
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
				t += "미납 관리비: [color=%s]%s[/color] (공용부분은 매수인 인수 — 판례상 최근 3년)\n" % [GOLD, fmt(int(a["unpaid_mgmt_fee"]))]
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
	var r := _analysis_range(a)
	var v := 0
	match kind:
		"min": v = int(a["min_price"])
		"lo": v = maxi(r[0], int(a["min_price"]))
		"hi": v = maxi(r[1], int(a["min_price"]))
	var man := ceili(v / 10_000.0)  # 내림하면 최저가 미만(무효)이 될 수 있어 올림
	bid_edit.text = str(man)
	bid_preview.text = fmt(man * 10_000)


func _on_bid() -> void:
	if busy:
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
	if bid >= int(a["appraisal_price"]) * 5:
		bid_preview.text = "입찰가를 다시 확인하세요 — '0' 하나 더 쓰면 보증금 몰수입니다!"
		_play("wrong")
		return
	_ceremony(bid, false)


## 개찰 세리머니: UI가 걷히고 법정이 줌인 — 집행관이 단상에서 금액을 호명
func _ceremony(my_bid: int, passed: bool) -> void:
	busy = true
	bid_row.visible = false
	quiz_row.visible = false
	action_row.visible = false
	var a: Dictionary = auctions[idx]
	var actual := int(a["winning_bid"])
	var n := maxi(int(a["bidder_count"]), 1)

	var others: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(a["case_no"]) + 7
	for i in n - 1:
		others.append(int(rng.randf_range(float(int(a["min_price"])), float(actual)) / 10_000.0) * 10_000)
	if others.size() > 0 and int(a.get("second_bid", 0)) > 0:
		others[0] = int(a["second_bid"])
	others.append(actual)
	others.sort()
	while others.size() > 4:
		others.pop_front()  # 호명은 상위 4명만

	var nicks: Array = ["강남 큰손", "이사비 전문 꾼", "첫 임장 새내기", "은퇴자금 방어전", "옆동네 중개사", "조용한 법인"]
	var entries: Array = []
	for amt in others:
		entries.append({"amt": amt, "who": nicks[rng.randi() % nicks.size()], "mine": false})
	if not passed:
		entries.append({"amt": my_bid, "who": "나 (지지)", "mine": true})
	entries.sort_custom(func(x, y) -> bool: return x["amt"] < y["amt"])

	# 법정 뷰로 전환: UI 걷고, 어둠 걷고, 단상으로 천천히 줌인
	content.visible = false
	range_label.visible = false
	result.visible = false
	court.pivot_offset = court.size * Vector2(0.5, 0.45)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "color:a", 0.08, 0.6)
	tw.tween_property(court, "scale", Vector2(1.14, 1.14), 6.0).set_trans(Tween.TRANS_SINE)
	_call("지금부터 %s 개찰을 시작하겠습니다." % a["case_no"])
	_say("두구두구...")
	await get_tree().create_timer(1.3).timeout

	for i in entries.size():
		var e: Dictionary = entries[i]
		if i == entries.size() - 1:
			_call("마지막 봉투입니다.")
			await get_tree().create_timer(1.0).timeout
		_play("click")
		_call("%s — %s!" % [e["who"], fmt(int(e["amt"]))])
		await get_tree().create_timer(0.9).timeout

	var top: Dictionary = entries[entries.size() - 1]
	_play("gavel")
	Juice.shake(self)
	_call("최고가 %s — %s 님, 낙찰!" % [fmt(int(top["amt"])), top["who"]])
	await get_tree().create_timer(1.2).timeout

	# UI 복귀
	var back := create_tween().set_parallel(true)
	back.tween_property(dim, "color:a", 0.6, 0.45)
	back.tween_property(court, "scale", Vector2.ONE, 0.45)
	call_bubble.visible = false
	content.visible = true
	range_label.visible = true

	if passed:
		_settle_passed()
	elif my_bid > actual:
		_decision(my_bid)
	else:
		_settle_lost(my_bid)


func _call(msg: String) -> void:
	call_bubble.visible = true
	call_label.text = msg
	Juice.punch(call_bubble)


## 낙찰! — 잔금을 낼 것인가, 보증금을 버릴 것인가
func _decision(bid: int) -> void:
	var a: Dictionary = auctions[idx]
	var items := CostCalc.breakdown(a, bid, rules)
	var tot := CostCalc.total(items)
	var evict := CostCalc.eviction_options(a, rules)
	var evict_min := mini(int(evict[0]["cost"]), int(evict[1]["cost"]))
	var dep := _deposit(a)

	var txt := "\n[color=%s][b]★ 최고가매수신고인![/b][/color] 내 입찰가: [b]%s[/b]\n" % [GOLD, fmt(bid)]
	txt += "[color=%s]감정가 %s | 최저가 %s[/color]\n\n" % [MUTED, fmt(int(a["appraisal_price"])), fmt(int(a["min_price"]))]
	txt += "[b]잔금 납부 전 최종 점검[/b] (매각허가 후 약 40일 내 납부)\n"
	txt += "  세금·등기 등 부대비용: %s\n" % fmt(tot)
	txt += "  예상 명도비: %s~\n" % fmt(evict_min)
	var r := _analysis_range(a)
	txt += "  내 시세 분석: %s ~ %s\n\n" % [fmt(r[0]), fmt(r[1])]
	txt += "잔금을 포기하면 보증금 [color=salmon]%s[/color]을 몰수당합니다." % fmt(dep)
	result.text = txt
	_say("낙찰 축하해요! 그런데... 정산이 남았죠. 잔금, 내실 건가요?")

	_actions([
		{"label": "잔금 납부하기", "primary": true, "cb": func() -> void: _pay_balance(bid)},
		{"label": "포기 (보증금 %s 몰수)" % fmt(dep), "primary": false, "cb": func() -> void: _forfeit(bid)},
	])


func _actions(defs: Array) -> void:
	for c in action_row.get_children():
		c.queue_free()
	for d in defs:
		var b := Button.new()
		b.text = d["label"]
		_style_button(b, d["primary"])
		b.pressed.connect(func() -> void:
			action_row.visible = false
			d["cb"].call())
		action_row.add_child(b)
	action_row.visible = true


func _pay_balance(bid: int) -> void:
	_play("click")
	var a: Dictionary = auctions[idx]
	if int(rules["eviction"].get(a.get("occupancy", "공실"), {}).get("negotiate", 0)) == 0 \
			and int(rules["eviction"].get(a.get("occupancy", "공실"), {}).get("enforce", 0)) == 0:
		_settle_won(bid, 0, "공실 — 즉시 인도", 0)
		return
	var opts := CostCalc.eviction_options(a, rules)
	var txt := "\n[b]명도 — 점유자(%s)를 내보내야 합니다[/b]\n" % a["occupancy"]
	for o in opts:
		txt += "  · %s: %s, 약 %d개월%s\n" % [o["label"], fmt(int(o["cost"])), int(o["months"]),
			("  ← " + o["note"]) if o["note"] != "" else ""]
	result.text = txt
	_say("명도는 돈이냐 시간이냐의 선택이에요. 배당받는 임차인은 명도확인서가 필요해서 협상이 쉽죠.")
	_actions([
		{"label": "%s (%s)" % [opts[0]["label"], fmt(int(opts[0]["cost"]))], "primary": true,
			"cb": func() -> void: _negotiate(bid, opts)},
		{"label": "%s (%s)" % [opts[1]["label"], fmt(int(opts[1]["cost"]))], "primary": false,
			"cb": func() -> void: _settle_won(bid, int(opts[1]["cost"]), opts[1]["label"], int(opts[1]["months"]))},
	])


## 명도 협상 — 랜덤 사건: 점유자가 이사비 증액을 요구할 수 있다
func _negotiate(bid: int, opts: Array) -> void:
	var a: Dictionary = auctions[idx]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(a["case_no"]) + 77
	var cost := int(opts[0]["cost"])
	if cost > 0 and rng.randf() < 0.35:
		var demand := int(cost * 1.8 / 10_000) * 10_000
		result.text = "\n[b]협상 난항![/b] 점유자: \"이사비 [color=%s]%s[/color]는 주셔야 나갑니다.\"" % [GOLD, fmt(demand)]
		Juice.pop_in(result)
		_play("wrong")
		_say("버티기에 들어갔네요. 여기서 밀리면 계속 올라가요. 어떻게 할까요?")
		_actions([
			{"label": "요구 수락 (%s)" % fmt(demand), "primary": false,
				"cb": func() -> void: _settle_won(bid, demand, "이사비 협상 (증액 수락)", int(opts[0]["months"]) + 1)},
			{"label": "협상 결렬 — 강제집행 (%s)" % fmt(int(opts[1]["cost"])), "primary": true,
				"cb": func() -> void: _settle_won(bid, int(opts[1]["cost"]), opts[1]["label"], int(opts[1]["months"]))},
		])
		return
	if cost > 0:
		_say("점유자가 순순히 도장을 찍었어요. 협상 성공!")
	_settle_won(bid, cost, opts[0]["label"], int(opts[0]["months"]))


func _forfeit(bid: int) -> void:
	var a: Dictionary = auctions[idx]
	var dep := _deposit(a)
	cash -= dep
	var market := int(a["market_price"])
	var full_net := market - bid - CostCalc.total(CostCalc.breakdown(a, bid, rules)) \
		- mini(int(CostCalc.eviction_options(a, rules)[0]["cost"]), int(CostCalc.eviction_options(a, rules)[1]["cost"]))
	var good := full_net < -dep
	var txt := "\n[b]잔금 포기[/b] — 보증금 [color=salmon]-%s[/color] 몰수. 재매각 절차로 넘어가며, 나는 재입찰 금지.\n" % fmt(dep)
	if good:
		txt += "[color=lightgreen]손절 성공: 잔금을 냈다면 약 %s 손해였어요. 몰수가 오히려 쌌습니다.[/color]\n" % fmt(full_net)
		_say("아프지만 옳은 결정! 실전에서도 낙찰 후 함정을 발견하면 보증금을 버리는 게 나을 때가 있어요.")
		_play("correct")
	else:
		txt += "[color=salmon]아까운 포기: 잔금을 냈다면 약 %s 손익이었어요.[/color]\n" % fmt(full_net)
		_say("이 물건은 진행해도 괜찮았어요. 조사가 부족하면 낙찰하고도 겁이 나죠.")
		_play("lose")
	_finish_case(txt, "forfeit", bid, 0, full_net)


func _settle_won(bid: int, evict_cost: int, evict_label: String, months: int) -> void:
	_play("click")
	busy = true
	var a: Dictionary = auctions[idx]
	wins += 1
	var items := CostCalc.breakdown(a, bid, rules)
	var market := int(a["market_price"])
	var tot := CostCalc.total(items) + evict_cost
	var net := market - bid - tot
	cash += net

	result.text = "\n[b]정산[/b] — 낙찰가 %s, 명도: %s (%d개월)\n" % [fmt(bid), evict_label, months]
	var lines: Array = []
	for it in items:
		lines.append("  %s: -%s" % [it["name"], fmt(int(it["amount"]))])
	if evict_cost > 0:
		lines.append("  명도비 (%s): -%s" % [evict_label, fmt(evict_cost)])
	lines.append("  [b]총 취득원가: %s[/b]" % fmt(bid + tot))
	lines.append("  시세 매각: +%s" % fmt(market))
	for line in lines:
		await get_tree().create_timer(0.4).timeout
		_play("click")
		result.text += line + "\n"
	await get_tree().create_timer(0.5).timeout
	var color := "lightgreen" if net >= 0 else "salmon"
	var txt := "[color=%s][b]순손익: %s%s[/b][/color]\n" % [color, "+" if net >= 0 else "", fmt(net)]
	_play("win" if net >= 0 else "lose")
	if net >= 0:
		get_tree().create_timer(0.7).timeout.connect(_play.bind("coin"))
		Juice.stars_burst(self, Vector2(size.x * 0.62, size.y * 0.45))
	_update_cash()
	_say("낙~찰! 수익까지 완벽해요!" if net >= 0 else "낙찰은 됐지만 정산하면 손해예요. 인수 금액과 세금까지 계산했어야 해요!")
	_finish_case(txt, "won", bid, net, net)


func _settle_lost(bid: int) -> void:
	var a: Dictionary = auctions[idx]
	var actual := int(a["winning_bid"])
	var diff := actual - bid
	var acc := 100.0 - absf(bid - actual) * 100.0 / actual
	var would_net := int(a["market_price"]) - actual - CostCalc.total(CostCalc.breakdown(a, actual, rules))
	var txt := "\n[b]패찰[/b] — 실제 낙찰가 [color=%s]%s[/color], 차액 [b]%s[/b] (정확도 %.1f%%)\n" % [
		GOLD, fmt(actual), fmt(diff), acc]
	txt += "낙찰가율: 감정가 대비 %.1f%% | 응찰 %d명\n" % [actual * 100.0 / int(a["appraisal_price"]), int(a["bidder_count"])]
	if would_net < 0:
		txt += "[color=%s]실제 낙찰자는 정산하면 약 %s 손해 — 무리하지 않은 당신이 이겼습니다.[/color]\n" % [MUTED, fmt(would_net)]
		_say("이건 승자의 저주 물건이었어요. 패찰이 곧 수익이죠!")
	else:
		txt += "[color=%s]실제 낙찰자 예상 손익: 약 +%s[/color]\n" % [MUTED, fmt(would_net)]
		_say("%s만 더 썼으면 내 물건이었네요. 다음엔 분석 범위 상단을 노려봐요!" % fmt(diff))
	_play("lose")
	_finish_case(txt, "lost", bid, 0, would_net)


func _settle_passed() -> void:
	var a: Dictionary = auctions[idx]
	var actual := int(a["winning_bid"])
	var would_net := int(a["market_price"]) - actual - CostCalc.total(CostCalc.breakdown(a, actual, rules))
	var txt := "\n[b]입찰 포기[/b] — 실제 낙찰가 [color=%s]%s[/color] (감정가 대비 %.1f%%, 응찰 %d명)\n" % [
		GOLD, fmt(actual), actual * 100.0 / int(a["appraisal_price"]), int(a["bidder_count"])]
	if would_net < 0:
		txt += "[color=lightgreen]좋은 판단 — 낙찰자는 정산하면 약 %s 손해였을 물건.[/color]\n" % fmt(would_net)
		_say("함정을 피했네요. 프로다워요!")
		_play("correct")
	else:
		txt += "[color=salmon]아까운 패스 — 낙찰자는 약 +%s 수익.[/color]\n" % fmt(would_net)
		_say("신중한 것도 실력이지만, 이건 기회였어요.")
		_play("lose")
	_finish_case(txt, "passed", 0, 0, would_net)


## 3축 별점: 조사 완전성 / 분석 정확도 / 재무 판단
func _finish_case(txt: String, kind: String, bid: int, net: int, would_net: int) -> void:
	var a: Dictionary = auctions[idx]
	var actual := int(a["winning_bid"])
	var tenants: Array = a.get("tenants", [])
	var inv: bool = seen_tabs.size() >= 3 and (tenants.is_empty() or quiz_state == 1)
	var ana := false
	var fin := false
	match kind:
		"won":
			ana = absf(bid - actual) <= actual * 0.10
			fin = net >= 0
		"lost":
			ana = absf(bid - actual) <= actual * 0.10
			fin = bid <= _analysis_range(a)[1]
		"passed":
			ana = would_net < 0
			fin = would_net < 0
		"forfeit":
			ana = false
			fin = would_net < -_deposit(a)
	var stars := int(inv) + int(ana) + int(fin)
	stars_total += stars
	txt += "\n판단 평가:  조사 %s   분석 %s   재무 %s" % [_star(inv), _star(ana), _star(fin)]
	if stars == 3:
		txt += "   [color=%s][b]— 완벽한 판단![/b][/color]" % GOLD
		Juice.stars_burst(self, Vector2(size.x * 0.5, size.y * 0.6), 16)
		_say("조사·분석·재무 전부 완벽! 이게 프로의 입찰이에요.")
	result.text += txt
	Juice.pop_in(result)
	next_btn.visible = true
	busy = false


func _star(on: bool) -> String:
	return "[color=%s]★[/color]" % GOLD if on else "[color=%s]☆[/color]" % MUTED


func _on_next() -> void:
	if busy:
		return
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
	range_label.text = ""
	photo.texture = null
	photo_caption.text = ""
	bid_row.visible = false
	quiz_row.visible = false
	action_row.visible = false
	result.visible = false
	next_btn.text = "다시 시작"
	next_btn.visible = true
	_play("win" if grade in ["S", "A"] else "lose")
	_say("등급 %s! 수고했어요. 조사 → 판단 → 입찰 → 정산, 실전 경매도 똑같아요." % grade)


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
