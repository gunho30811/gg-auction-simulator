# 손맛·연출 기법 — 우리가 아직 안 쓰는 것

조사일 2026-08-06 · 대상 `scripts/main.gd` (1962줄), `scripts/juice.gd` · Godot 4.7 / gl_compatibility

## 요약 (5줄 이내)

1. 지금 가장 급한 건 **새 연출이 아니라 스킵·속도 설정**이다. `_ceremony()` 한 번이 약 9.4초 강제 대기이고, 20물건 라운드면 개찰만 3분 이상을 못 건너뛴다.
2. 개찰의 긴장은 **금액을 억→만→원 순으로 끊어 공개**하고 **결과 직전 300ms 무음 + 로우패스 스윕**을 넣으면 코드 30줄로 몇 배가 된다. 새 에셋이 필요 없다.
3. 오디오가 통째로 비어 있다 — 버스 분리·볼륨 설정·피치 랜덤화·BGM/앰비언스가 전부 없고, `sfx_player` 하나라서 효과음끼리 서로를 끊는다.
4. `lightgreen`/`salmon` 손익 색은 남성 플레이어 약 5%에게 구분되지 않는다. ▲▼ 기호와 색약 안전 팔레트로 바꾸면 스팀 접근성 태그 2개가 공짜로 붙는다.
5. 이미 11가지 연출이 한 순간에 동시 발사되고 있다. 실증 연구는 이 지점부터 **더 넣으면 오히려 성적과 이해도가 떨어진다**고 말한다 — 다음 수는 추가가 아니라 **분산·순차화**다.

---

## 기법 목록

임팩트 높고 비용 낮은 순.

---

### 1. 연출 스킵 · 속도 설정 (`_beat()` 단일 관문)

- **출처**: [Game Accessibility Guidelines — Offer a means to bypass gameplay elements](https://gameaccessibilityguidelines.com/offer-a-means-to-bypass-gameplay-elements-that-arent-part-of-the-core-mechanic-via-settings-or-in-game-skip-option/) · [Include an option to adjust the game speed](https://gameaccessibilityguidelines.com/include-an-option-to-adjust-the-game-speed/) · [AbleGamers APX — Bypass / Slow It Down](https://accessible.games/accessible-player-experiences/) · [Steamworks Accessibility Features](https://partner.steamgames.com/doc/accessibility_features)
- **무엇인가**: 반복되는 연출은 첫 회에만 온전히 보여주고, 그 뒤로는 클릭 한 번으로 즉시 끝내거나 전역 속도 설정으로 줄인다. 설정은 **저장돼서 매 라운드 다시 누르지 않아도 돼야** 한다.
- **우리 게임 어디에**: `_ceremony()`의 `await get_tree().create_timer(...)`가 7군데, `_confirmation()` 2군데, `_show_event()` 1군데, `_settle_won()`의 정산 행 루프, `_second_bidder()`, `_impact()` 2군데 — **전부**. 현재 `Game.simple_bid`(기일입찰표 생략)만 있고 개찰·정산은 못 건너뛴다.
- **Godot 4 구현 방법**: 대기를 한 함수로 모으고 그 안에서만 속도·스킵을 판정한다. 새 클래스 없음.

```gdscript
# game_state.gd — 설정 하나만 추가
var fx_speed := 1.0   # 1.0 보통 / 0.45 빠름 / 0.0 즉시

# main.gd
var _skip := false
var _last_skip_ms := 0

func _unhandled_input(e: InputEvent) -> void:
	if busy and (e.is_action_pressed("ui_accept") or (e is InputEventMouseButton and e.pressed)):
		_skip = true
		_last_skip_ms = Time.get_ticks_msec()

## 모든 연출 대기는 여기를 지난다 — 속도 설정 반영 + 아무 입력으로 건너뛰기
func _beat(sec: float) -> void:
	var left := sec * Game.fx_speed
	while left > 0.0 and not _skip:
		left -= get_process_delta_time()
		await get_tree().process_frame

func _on_next() -> void:
	if busy or Time.get_ticks_msec() - _last_skip_ms < 200:
		return   # 스킵 클릭이 '다음 물건'까지 눌러버리는 사고 방지
	...
```

`_ceremony()` 시작에서 `_skip = false`, 각 호명 루프 안에서도 한 명 공개마다 `_skip = false`로 되돌리면 **한 번 누르면 현재 단계만, 계속 누르면 전부** 라는 표준 동작이 된다. `await get_tree().create_timer(x).timeout` → `await _beat(x)` 일괄 치환.
gl_compatibility 무관 (렌더러와 상관없음).

- **임팩트 / 비용**: 상 / 하

---

### 2. 금액 단계 공개 — 억 → 만 → 원

- **출처**: [Slot machine near-miss design (staged reveal, delayed final symbol)](https://www.casinocenter.com/slot-machine-psychology-how-the-near-miss-effect-drives-player-behavior-in-online-gaming/) · [Designing Game Feel: A Survey §III-E](https://arxiv.org/pdf/2011.09201)
- **무엇인가**: 결과 숫자를 한 번에 던지지 않고 자릿수 덩어리로 쪼개 순차 공개하고, **마지막 덩어리 앞에서만 3배 길게 뜸을 들인다**. 플레이어가 자기 운명을 점진적으로 계산하게 만드는 장치.
- **우리 게임 어디에**: `_ceremony()`의 `_call("%d순위 — %s, %s!" % [rank, e["who"], fmt(int(e["amt"]))])`. 지금은 이름과 금액이 동시에 통째로 뜬다. 특히 **마지막(최고가) 봉투**에 적용하면 효과가 가장 크다. `_settle_lost()`의 실제 낙찰가 공개도 후보.
- **Godot 4 구현 방법**: 우리 `fmt()`가 이미 억/만/원으로 끊어주므로 한국어와 자연스럽게 맞는다.

```gdscript
## 금액을 억 → 만 → 원 순서로 끊어 공개. 마지막 덩어리 앞에서 뜸을 들인다.
func _call_amount(who: String, rank: int, amount: int) -> void:
	var eok := amount / 100_000_000
	var man := (amount % 100_000_000) / 10_000
	var steps: Array[String] = []
	if eok > 0:
		steps.append("%d억 …" % eok)
	if man > 0:
		steps.append(("%d억 %s만 …" % [eok, _comma(man)]) if eok > 0 else ("%s만 …" % _comma(man)))
	steps.append(fmt(amount) + "!")
	for i in steps.size():
		if i == steps.size() - 1:
			await _beat(0.55)                       # ← 여기서만 길게
		call_label.text = "%d순위 — %s, %s" % [rank, who, steps[i]]
		call_bubble.visible = true
		_play("click")
		Juice.punch(call_bubble, 1.05 if i < steps.size() - 1 else 1.16)
		await _beat(0.22)
```

`_call()`을 그대로 두고 이 함수를 옆에 두면 기존 호출부는 안 건드려도 된다.
gl_compatibility 무관.

- **임팩트 / 비용**: 상 / 하

---

### 3. 효과음 피치 랜덤화 + 폴리포닉 재생

- **출처**: [What Features Influence Impact Feel? §C2.1 (round-robin / auditory fatigue)](https://arxiv.org/pdf/2208.06155) · [AudioStreamRandomizer](https://docs.godotengine.org/en/stable/classes/class_audiostreamrandomizer.html) · [AudioStreamPlaybackPolyphonic](https://docs.godotengine.org/en/stable/classes/class_audiostreamplaybackpolyphonic.html)
- **무엇인가**: 같은 효과음을 수백 번 듣게 되는 게임에서 매번 **완전히 동일한 파형**은 청각 피로를 만든다. ±6% 피치 랜덤화만으로 체감이 크게 달라진다.
- **우리 게임 어디에**: `_play()` 한 함수. `click`은 `_show_tab`·`_quick_bid`·`_next_photo`·`_on_next`·`_pack_deposit_env`·정산 행마다 울린다. 추가로 **지금 `sfx_player` 하나라 `_play("tear")` 직후 `_play("stamp")`가 앞 소리를 끊는다** — `_take_receipt_and_drop()`에서 실제로 발생하는 문제.
- **Godot 4 구현 방법**: 폴리포닉으로 바꾸면 피치 랜덤화와 겹침 재생이 동시에 해결되고 호출부는 오히려 짧아진다.

```gdscript
# _ready() — sfx_player 생성부 교체
sfx_player = AudioStreamPlayer.new()
sfx_player.stream = AudioStreamPolyphonic.new()
add_child(sfx_player)
sfx_player.play()
_sfx_pb = sfx_player.get_stream_playback() as AudioStreamPlaybackPolyphonic

var _sfx_pb: AudioStreamPlaybackPolyphonic

func _play(name: String, db := -4.0, pitch := 0.0) -> void:
	if sfx[name] == null:
		return
	_sfx_pb.play_stream(sfx[name], 0.0, db,
		pitch if pitch > 0.0 else randf_range(0.94, 1.06))
```

`gavel`·`nakchal` 같은 "한 번뿐인 큰 소리"는 `_play("nakchal", -4.0, 1.0)`으로 피치 고정.
gl_compatibility 무관 (오디오는 렌더러 독립).

- **임팩트 / 비용**: 상 / 하

---

### 4. 결과 직전 300ms 무음 + 로우패스 스윕

- **출처**: [The Importance of Silence and Pause in Impact Sounds](https://atomikfalconstudios.com/article/the-importance-of-silence-and-pause-in-enhancing-projectile-impact-sounds/) · [Creating Tension with Sound Effects](https://duendesounds.com/creating-tension-with-sound-effects/) · [AudioEffectFilter](https://docs.godotengine.org/en/stable/classes/class_audioeffectfilter.html)
- **무엇인가**: 임팩트 직전에 **모든 소리를 끊는다**. 그리고 그 앞 구간은 로우패스 컷오프를 20000→400Hz로 내려 세상이 좁아지는 느낌을 만들고, 결과 순간에 다시 열어 해방감을 준다. 필터 오토메이션 하나가 효과음 세 개 역할을 한다.
- **우리 게임 어디에**: `_ceremony()`의 `drum_player.stop()` 직후, `_play("nakchal")` 직전. 지금은 드럼롤이 그냥 멈추고 바로 스팅어가 붙는다.
- **Godot 4 구현 방법**: 버스를 만들고(`Master`/`Music`/`SFX`/`Voice`) `Music`에 로우패스를 얹는다. 버스 분리는 스팀 `Custom Volume Controls` 태그의 전제조건이기도 하다.

```gdscript
# _ready()에서 1회
func _make_buses() -> void:
	for n in ["Music", "SFX", "Voice"]:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, n)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 20000.0
	lp.db = AudioEffectFilter.FILTER_18DB   # 기본 6dB/oct는 스윕이 안 들린다
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), lp)

func _muffle(to_hz: float, dur: float) -> void:
	var lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(
		AudioServer.get_bus_index("Music"), 0)
	create_tween().tween_method(func(hz: float) -> void: lp.cutoff_hz = hz,
		lp.cutoff_hz, to_hz, dur)

# _ceremony() — 마지막 봉투 호명 직전
_muffle(400.0, 1.2)
drum_player.stop()
var mi := AudioServer.get_bus_index("Music")
AudioServer.set_bus_mute(mi, true)
await _beat(0.3)                # ← 완전 무음 300ms
AudioServer.set_bus_mute(mi, false)
_muffle(20000.0, 0.4)
_play("nakchal", -4.0, 1.0)
```

`drum_player.bus = "Music"`, `voice_player.bus = "Voice"`, `sfx_player.bus = "SFX"`로 배선.
gl_compatibility 무관.

- **임팩트 / 비용**: 상 / 하

---

### 5. 히트스톱 (결과 크기에 비례하는 정지)

- **출처**: [Designing Game Feel: A Survey §III-C](https://arxiv.org/pdf/2011.09201) · [What Features Influence Impact Feel? (Guilty Gear Xrd 7~10프레임)](https://arxiv.org/pdf/2208.06155) · [SceneTree.create_timer ignore_time_scale](https://docs.godotengine.org/en/stable/classes/class_scenetree.html)
- **무엇인가**: 임팩트 순간 시간을 거의 멈춘다. 실무 범위는 40~80ms(2~6프레임). **정지 길이 자체를 사건의 크기 함수로 만들면**, 플레이어는 숫자를 읽기 전에 정지 길이로 결과 규모를 먼저 느낀다.
- **우리 게임 어디에**: `_stamp()`의 도장 접촉 프레임, `_ceremony()`의 `_play("nakchal")` 순간, `_impact()`의 `Juice.shake` 직전. 특히 낙찰 순간에 `abs(내 입찰가 − 실제 낙찰가) / 실제` 로 정지 길이를 스케일.
- **Godot 4 구현 방법**: `ignore_time_scale = true`가 핵심 — 안 주면 복귀 타이머 자체가 느려져서 영영 안 돌아온다.

```gdscript
## 임팩트 정지. sec는 0.05(스침) ~ 0.25(대사건)
func _hitstop(sec := 0.09) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(sec, true, false, true).timeout  # ← 4번째 인자
	Engine.time_scale = 1.0

# _ceremony() 낙찰 순간
_play("nakchal", -4.0, 1.0)
await _hitstop(0.06 + clampf(absf(my_bid - actual) / float(actual), 0.0, 0.2))
Juice.kick(self, Vector2.UP, 16.0)   # 기법 7
```

주의: `Engine.time_scale`은 **오디오에 영향을 주지 않는다**(의도한 대로 — 스팅어는 정상 속도로 계속 간다). 완전 0은 문서상 비권장, 0.05 사용.
gl_compatibility 무관.

- **임팩트 / 비용**: 상 / 하

---

### 6. 색만으로 정보 전달 금지 — ▲▼ + 색약 안전 팔레트

- **출처**: [GAG — no essential information by colour alone](https://gameaccessibilityguidelines.com/ensure-no-essential-information-is-conveyed-by-a-fixed-colour-alone/) · [Okabe & Ito](https://jfly.uni-koeln.de/color/) · [Paul Tol colour schemes](https://sronpersonalpages.nl/~pault/) · [Steamworks — Color Alternatives / Contrast Controls](https://partner.steamgames.com/doc/accessibility_features)
- **무엇인가**: 적록색약은 **아시아권 남성 5%**. 손익을 초록/빨강으로만 표시하면 20명 중 1명은 못 읽는다. 게다가 한국 금융 관행은 서구와 반대(빨강=상승)라 색 자체가 중의적이다. 기호·부호·단어로 이중 부호화한다.
- **우리 게임 어디에**: `_settle_won()`의 `var color := "lightgreen" if net >= 0 else "salmon"`, `_forfeit()`·`_withdrawn()`·`_settle_passed()`·`_show_end()`의 같은 패턴, `_quiz_explain()`의 `salmon`/`lightgreen`.
- **Godot 4 구현 방법**: 상수 두 개 추가 + `▲/▼` 붙이기. Paul Tol high-contrast 3색은 **회색조로도 구분되는** 유일한 조합이라 스크린샷·저가 모니터에서도 안전하다.

```gdscript
const COL_UP := "#DDAA33"      # 이익 (Tol high-contrast)
const COL_DOWN := "#BB5566"    # 손실
const COL_NEUTRAL := "#004488"

# _settle_won()
var txt := "[color=%s][b]%s 순손익: %s%s[/b][/color]\n" % [
	COL_UP if net >= 0 else COL_DOWN,
	"▲" if net >= 0 else "▼",
	"+" if net >= 0 else "", fmt(net)]
```

`_bar()`의 `■/□`는 이미 모양으로 구분되므로 그대로 좋다.
gl_compatibility 무관.

- **임팩트 / 비용**: 상 / 하

---

### 7. 방향성 킥 — 무작위 흔들림 대신 의미 있는 축

- **출처**: [The Art of Screenshake — Jan Willem Nijman](https://theengineeringofconsciousexperience.com/jan-willem-nijman-vlambeer-the-art-of-screenshake/) · [Designing Game Feel §III-B-1 (Guilty Gear Xrd: 내려찍기는 수직, 베기는 수평)](https://arxiv.org/pdf/2011.09201)
- **무엇인가**: 무작위 진동이 아니라 **힘의 반대 방향으로 밀렸다가 돌아오는** 변위. "무슨 일이 있었나"가 아니라 "어느 쪽으로 맞았나"를 전달한다. 같은 예산으로 정보량이 늘어난다.
- **우리 게임 어디에**: `_ceremony()` 낙찰 순간(`Juice.shake(self, 10.0)`)을 **위쪽 킥**으로, `_settle_lost()`·`_forfeit()`은 **아래쪽 킥**으로. `_stamp()`의 `Juice.shake(paper_panel, 9.0, 0.25)`는 도장이 위에서 내려오므로 **아래쪽 킥**이 맞다.
- **Godot 4 구현 방법**: `juice.gd`에 `shake` 옆에 12줄 추가. 기존 `_tween_for`/`_j_origin` 규약 그대로 재사용.

```gdscript
# juice.gd
## 방향성 킥 — 흔들림과 달리 '어느 쪽으로 맞았는지'를 전달한다
static func kick(c: Control, dir: Vector2, amount := 14.0) -> void:
	var origin: Vector2 = c.get_meta("_j_origin") if c.has_meta("_j_origin") else c.position
	c.set_meta("_j_origin", origin)
	var tw := _tween_for(c, "_j_kick")
	tw.tween_property(c, "position", origin + dir.normalized() * amount, 0.05) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position", origin, 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
```

주의: `shake`와 `kick`이 같은 `_j_origin`을 공유하므로 **동시에 걸면 안 된다**(둘 중 하나만).
gl_compatibility 무관.

- **임팩트 / 비용**: 상 / 하

---

### 8. 1~2프레임 흰색 플래시 (요소 단위)

- **출처**: [The Art of Screenshake](https://theengineeringofconsciousexperience.com/jan-willem-nijman-vlambeer-the-art-of-screenshake/) · [Designing Game Feel §III-B-6](https://arxiv.org/pdf/2011.09201)
- **무엇인가**: 전체 화면 오버레이가 아니라 **맞은 요소 하나만** 1~2프레임 순백으로 날린다. 우리 `_impact()`의 색 띠와 완전히 다른 층위 — 저건 화면, 이건 사물.
- **우리 게임 어디에**: `_ceremony()` 낙찰자 스프라이트(`e["spr"]`)가 `Juice.punch(spr, 1.3)` 되는 순간, `_stamp()`의 도장 접촉 프레임, `_finish_case()`에서 S/A 등급 나올 때 `result` 패널.
- **Godot 4 구현 방법**: `modulate`에 1.0 초과 값을 넣으면 곱연산이라 밝게 타서 흰색으로 클램프된다. gl_compatibility는 2D HDR 미지원이라 오히려 정확히 흰색에서 멈춘다 — 우리가 원하는 결과.

```gdscript
# juice.gd
## 1~2프레임 화이트아웃 — 실시간 프레임 기준이라 time_scale 무시
static func flash(c: CanvasItem, frames := 2) -> void:
	var m := c.modulate
	c.modulate = Color(5, 5, 5, m.a)
	await c.get_tree().create_timer(frames / 60.0, true, false, true).timeout
	c.modulate = m
```

⚠️ 광과민성: 이 플래시는 반드시 **기법 21의 `화면 번쩍임` 토글**을 통과해야 한다. 면적을 341×256px 이하로 유지하면 WCAG 3-flash 규정 자체가 적용 대상에서 빠진다.
gl_compatibility: `modulate`는 코어 CanvasItem 속성. 완전 지원.

- **임팩트 / 비용**: 중상 / 하

---

### 9. 지지 말풍선 타자기 (`visible_ratio`)

- **출처**: [Label.visible_ratio](https://docs.godotengine.org/en/stable/classes/class_label.html) · [GAG — allow players to progress through text at their own pace](https://gameaccessibilityguidelines.com/allow-players-to-progress-through-text-prompts-at-their-own-pace/)
- **무엇인가**: 텍스트를 한 번에 갈아끼우지 않고 글자 단위로 흘린다. 캐릭터가 "지금 말하고 있다"는 인상이 생기고, 플레이어 시선이 말풍선으로 끌린다.
- **우리 게임 어디에**: `_say()` — 지금은 `speech.text = msg` 한 줄이라 지지의 대사가 소리 없이 순간 교체된다. `_show_auction()`·`_answer_quiz()`·`_decision()` 등 30군데 이상에서 호출된다.
- **Godot 4 구현 방법**: `Label`에 `visible_ratio`가 있으므로 `RichTextLabel`로 바꿀 필요가 없다. 재트리거 시 이전 타이핑을 끊어야 하므로 `juice.gd`의 `_tween_for` 규약을 재사용.

```gdscript
# juice.gd
## 타자기 — 재호출 시 이전 타이핑을 끊고 새로 시작
static func type(l: Label) -> void:
	l.visible_ratio = 0.0
	_tween_for(l, "_j_type").tween_property(l, "visible_ratio", 1.0,
		clampf(l.text.length() * 0.022, 0.2, 1.4))

# main.gd
func _say(msg: String) -> void:
	speech.text = msg
	Juice.type(speech)
```

`Game.fx_speed == 0.0`(즉시 모드)면 `speech.visible_ratio = 1.0`로 건너뛴다. **자동으로 다음 화면으로 넘어가면 안 된다** — 텍스트는 플레이어가 닫을 때까지 남아야 한다(GAG Basic).
gl_compatibility 무관.

- **임팩트 / 비용**: 중상 / 하

---

### 10. RichTextLabel 내장 BBCode 이펙트

- **출처**: [BBCode in RichTextLabel](https://docs.godotengine.org/en/stable/tutorials/ui/bbcode_in_richtextlabel.html)
- **무엇인가**: 엔진이 이미 `[shake rate=20 level=5]`, `[pulse freq=1.0 color=#ffffff40 ease=-2.0]`, `[wave amp=50 freq=5]`, `[tornado]`, `[fade]`, `[rainbow]`를 내장하고 있다. 우리는 `[b]`·`[color]`만 쓰고 있다.
- **우리 게임 어디에**: `result`·`info`·`detail` 전부 `bbcode_enabled = true`인 `RichTextLabel`이다. `_settle_lost()`의 실제 낙찰가에 `[pulse]`, `_forfeit()`의 "보증금 몰수"에 `[shake]`, `_finish_case()`의 새 칭호 이름에 `[wave]`.
- **Godot 4 구현 방법**: 문자열만 바꾸면 끝. 코드 추가 0줄.

```gdscript
# _settle_lost() — 실제 낙찰가를 맥동시켜 시선 고정
txt += "\n[b]패찰[/b] — 실제 낙찰가 [pulse freq=1.6 color=#ffffff30][color=%s]%s[/color][/pulse]" % [GOLD, fmt(actual)]

# _forfeit()
txt += "\n[b]잔금 포기[/b] — [shake rate=18 level=4][color=%s]보증금 %s 몰수[/color][/shake]\n" % [COL_DOWN, fmt(dep)]

# _title_lines() — 새 칭호
t += "  [wave amp=22 freq=4][color=%s][b]%s[/b][/color][/wave] (T%d) — %s\n" % [GOLD, g["name"], int(g["tier"]), g["desc"]]
```

⚠️ 흔들리는 텍스트는 난독·전정기관 이슈가 있으므로 **`연출 강도` 설정이 '낮음'이면 태그를 빼는** 분기가 필요하다(문자열 조립 시 한 줄).
gl_compatibility: CPU 텍스트 셰이핑. 완전 지원. Noto Sans KR과도 문제 없음.

- **임팩트 / 비용**: 중상 / 하

---

### 11. 정산 행 계단식 공개 + 마지막 줄 홀드 + 상승 피치

- **출처**: [Game UI Animation — stagger, don't sequence](https://gamineai.com/blog/game-ui-animation-creating-smooth-engaging-interface-transitions) · [Slot machine escalating sound](https://www.casinocenter.com/slot-machine-psychology-how-the-near-miss-effect-drives-player-behavior-in-online-gaming/)
- **무엇인가**: 목록은 등간격으로 흘리되 **결론 행 직전에만 한 박 쉬고**, 틱 사운드는 행마다 반음씩 올린다. 오디오가 올라가다 멈추는 순간이 곧 긴장이다.
- **우리 게임 어디에**: `_settle_won()`의 `for line in lines:` 루프. 지금은 0.18초 등간격에 같은 `click`이 반복되고 순손익도 그냥 이어 붙는다.
- **Godot 4 구현 방법**:

```gdscript
# _settle_won() 정산 행 루프 교체
for i in lines.size():
	await _beat(0.16)
	_play("click", -6.0, 1.0 + i * 0.045)   # 행마다 반음씩 위로
	result.text += lines[i] + "\n"
await _beat(0.55)                            # ← 순손익 앞 한 박
_play("win" if net >= 0 else "lose", -4.0, 1.0)
```

- **임팩트 / 비용**: 중상 / 하

---

### 12. `dim` ColorRect 재활용 — 비네트 셰이더

- **출처**: [Canvas item shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html) · [The Book of Shaders (Godot 포팅, MIT)](https://github.com/jayaarrgh/BookOfShaders-Godot)
- **무엇인가**: 화면 가장자리를 어둡게 눌러 시선을 중앙으로 모은다. 개찰 순간에 비네트를 강하게 조이면 "세상이 좁아지는" 느낌이 나온다.
- **우리 게임 어디에**: `_build_ui()`의 `dim` (`ColorRect`, 전체 화면, 이미 존재). 새 노드 없이 `dim.material`만 붙이면 되고, `_ceremony()`의 `tw.tween_property(dim, "color:a", 0.08, 0.6)`와 같은 자리에서 셰이더 uniform을 트윈한다.
- **Godot 4 구현 방법**: **화면을 읽지 않는 순수 절차형 셰이더**라 백버퍼 복사 비용이 0이고 gl_compatibility에서 100% 안전하다.

```glsl
// assets/shaders/vignette.gdshader
shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.5;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.02, 1.0);
void fragment() {
	float d = distance(UV, vec2(0.5)) * 1.414;
	COLOR = vec4(tint.rgb, smoothstep(0.42, 1.0, d) * amount);
}
```

```gdscript
# _build_ui() — dim 생성 직후
var vm := ShaderMaterial.new()
vm.shader = load("res://assets/shaders/vignette.gdshader")
dim.material = vm

# _ceremony() — 법정 뷰 전환할 때 조인다
create_tween().tween_method(
	func(v: float) -> void: vm.set_shader_parameter("amount", v), 0.5, 0.92, 1.2)
```

⚠️ **`hint_screen_texture`를 쓰지 않는 것이 핵심.** 화면을 읽는 셰이더를 `CanvasGroup`에 얹으면 Compatibility에서 흰 화면이 되는 열린 버그가 있다([godot#116729](https://github.com/godotengine/godot/issues/116729), 4.3~4.7.dev). 크로마틱 애버레이션·방사형 블러처럼 화면을 읽어야만 하는 효과가 정말 필요해지면 `CanvasGroup` 대신 **SubViewport + SubViewportContainer 셰이딩**으로 우회할 것.

- **임팩트 / 비용**: 중상 / 하

---

### 13. 니어미스 전용 연출 (차이 게이지가 0 앞에서 멈춘다)

- **출처**: [Near-miss & LDW systematic review (PubMed 28421402)](https://pubmed.ncbi.nlm.nih.gov/28421402/) · [Casino Center — near-miss effect](https://www.casinocenter.com/slot-machine-psychology-how-the-near-miss-effect-drives-player-behavior-in-online-gaming/) · [TextureProgressBar](https://docs.godotengine.org/en/stable/classes/class_textureprogressbar.html)
- **무엇인가**: 아깝게 진 것과 크게 진 것을 **같은 시각 언어로 보여주면 안 된다**. 니어미스는 신경학적으로 승리와 유사하게 반응하며 재도전 동기를 만든다. 차액이 0으로 줄어들다 **살짝 못 미쳐 멈추는** 애니메이션이 정석.
- **우리 게임 어디에**: `_settle_lost()`. 지금 1% 이내면 `_impact("간   발   의   차", ...)`를 띄우는데(이미 있음), **차액 게이지가 실제로 줄어들다 멈추는 장면이 없다**. 임계도 1%뿐이라 3% 차이는 40% 차이와 동일한 연출을 받는다.
- **Godot 4 구현 방법**: `_impact()` 직후 `result` 위에 게이지 한 줄. `TextureProgressBar` 없이 `_bar()` 재사용도 가능하지만 애니메이션엔 진행바가 낫다.

```gdscript
# _settle_lost() — _impact() 뒤
var acc := 100.0 - absf(bid - actual) * 100.0 / actual
if acc >= 92.0:                                   # 1% → 8%로 완화 (니어미스 구간을 넓힌다)
	var gap := TextureProgressBar.new()
	gap.max_value = 100.0
	gap.tint_progress = Color(COL_DOWN)
	gap.custom_minimum_size = Vector2(0, 10)
	right.add_child(gap)
	var tw := gap.create_tween()
	tw.tween_property(gap, "value", acc, 0.9).from(0.0) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)                        # ← 100 직전에서 멈춰 선 채로 버틴다
	tw.tween_callback(_play.bind("lose"))
```

- **임팩트 / 비용**: 중상 / 하

---

### 14. 승자의 저주를 "가짜 승리(LDW)"로 연출

- **출처**: [Losses disguised as wins — systematic review](https://pubmed.ncbi.nlm.nih.gov/28421402/)
- **무엇인가**: 슬롯머신의 LDW는 "이긴 것처럼 보이지만 실제로는 잃은" 순간을 승리 연출로 포장하는 기법이다. **우리 게임에는 이게 정직한 형태로 이미 존재한다** — 낙찰은 했는데 취득세·명도비까지 계산하면 손해인 물건.
- **우리 게임 어디에**: `_decision()` → `_settle_won()`에서 `net < 0`인 경로. 지금은 `_decision()`이 처음부터 담담하게 비용을 나열한다. 낙찰 순간에는 **온전한 축하**(별·팡파르)를 주고, 정산에서 조용히 되찾아 가게 하면 우리 루프에서 가장 극적인 박자가 된다. 사실이 한 박 뒤에 전부 공개되므로 윤리적으로도 문제없다.
- **Godot 4 구현 방법**: 새 함수 없이 순서만 바꾼다.

```gdscript
# _decision() 진입부 — 비용 나열 '전에' 축하를 먼저 준다
Juice.stars_burst(self, Vector2(size.x * 0.5, size.y * 0.35), 18)
_play("win", -4.0, 1.0)
_say("최고가매수신고인! 축하해요!")
await _beat(1.0)
# ↓ 그 다음에 기존 '잔금 납부 전 최종 점검' 텍스트
```

그리고 `_settle_won()`에서 `net < 0`일 때만 `dim`의 비네트를 다시 조이고(기법 12) 아래쪽 킥(기법 7)을 준다.

- **임팩트 / 비용**: 중상 / 하

---

### 15. 지속물 — 세션 동안 쌓이는 수취증 더미

- **출처**: [Designing Game Feel §III-D-2 (Decals & debris) / §III-D (Persistence)](https://arxiv.org/pdf/2011.09201) · [The Art of Screenshake — permanence](https://ssharancom.wordpress.com/2017/06/28/the-art-of-screenshake-vlambeers-games-2/)
- **무엇인가**: 과거 행동의 흔적을 화면에 남긴다. **서류 게임에 가장 잘 맞는 미사용 카테고리**. 쌓인 더미의 높이가 곧 진행도이자 "나는 여기서 일했다"는 감각.
- **우리 게임 어디에**: `_take_receipt_and_drop()`에서 `receipt`를 좌하단에 보관해 놓고 바로 다음 줄 `form_layer.queue_free()`로 지워버린다. 이걸 `sprite_layer`로 옮겨 살려두면 라운드 내내 쌓인다.
- **Godot 4 구현 방법**: `reparent()` 한 줄 + 배치 함수.

```gdscript
var _pile: Array[Control] = []

## 처리된 서류가 좌하단에 겹쳐 쌓인다 — 한 세션의 흔적
func _pile_add(node: Control) -> void:
	node.reparent(sprite_layer)
	var i := _pile.size()
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "position", Vector2(26.0 + i * 3, size.y - 132.0 - i * 4), 0.4) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation", randf_range(-0.09, 0.05), 0.4)
	tw.tween_property(node, "scale", Vector2(0.6, 0.6), 0.4)
	tw.tween_property(node, "modulate", Color(0.78, 0.78, 0.82), 0.4)
	_pile.append(node)
	while _pile.size() > 12:
		_pile.pop_front().queue_free()

# _take_receipt_and_drop() — form_layer.queue_free() 직전
_pile_add(receipt)
```

`receipt.pivot_offset`이 이미 설정돼 있고 `form_layer`가 전체 화면 앵커라 좌표계가 동일하다.

- **임팩트 / 비용**: 중상 / 중

---

### 16. 공유 요소 전환 — 봉투가 그대로 결과 카드가 된다

- **출처**: [Designing Game Feel §III-D-4 (Fluid interfaces, Apple 2018)](https://arxiv.org/pdf/2011.09201)
- **무엇인가**: 화면을 잘라 바꾸지 않고, 이전 화면의 요소를 **그대로 새 화면의 요소로 변형**시킨다. 공간적 연속성이 생겨 "다른 화면으로 갔다"가 아니라 "같은 사물이 변했다"로 읽힌다.
- **우리 게임 어디에**: `_ceremony()`의 `content.visible = false` — 지금은 UI가 통째로 사라지고 법정이 나타나는 하드 컷. `_take_receipt_and_drop()`에서 떨어진 `big_env`가 **개찰 때 단상 위 말풍선(`call_bubble`)으로 커지며** 이어지면 봉투 → 개찰이 하나의 동작이 된다.
- **Godot 4 구현 방법**: `content`를 즉시 끄지 말고 축소·페이드로 보내고, 봉투 잔상을 `call_bubble` 위치로 날린 뒤 교체.

```gdscript
# _ceremony() 시작 — content.visible = false 대체
content.pivot_offset = content.size / 2.0
var out := content.create_tween().set_parallel(true)
out.tween_property(content, "scale", Vector2(0.92, 0.92), 0.28) \
	.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
out.tween_property(content, "modulate:a", 0.0, 0.28)
out.chain().tween_callback(func() -> void:
	content.visible = false
	content.scale = Vector2.ONE
	content.modulate.a = 1.0)
```

복귀(`content.visible = true`)도 `Juice.pop_in(content)`로 대칭을 맞춘다.

- **임팩트 / 비용**: 중상 / 중

---

### 17. 화면 전환 셰이더 (CC0 단일 파일)

- **출처**: [cashew-olddew/Universal-Transition-Shader](https://github.com/cashew-olddew/Universal-Transition-Shader) — **CC0-1.0**, 별 ~503, 파일 1개(`transition.gdshader`)
- **무엇인가**: 방향성 와이프, 시계 와이프, 아이리스, 디졸브, 그리드 리빌 등을 `progress` uniform 하나로 구동하는 셰이더. **화면을 읽지 않고 마스크만 쓰기 때문에 gl_compatibility에서 100% 안전**하고 CC0라 출처 표기 의무도 없다.
- **우리 게임 어디에**: `title.gd`의 `_on_start()`(지금은 `modulate.a` 페이드), `setup.tscn` → `main.tscn` 전환, `_show_end()` → 재시작. 그리고 `_ceremony()` 진입 시 법정으로의 전환.
- **Godot 4 구현 방법**: `CanvasLayer` 위 전체 화면 `ColorRect` 하나 + 트윈 10줄.

```gdscript
# 어느 씬에서든
func _wipe_to(path: String) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 128
	add_child(cl)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/transition.gdshader")
	m.set_shader_parameter("progress", 0.0)
	r.material = m
	cl.add_child(r)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("progress", v),
		0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(path))
```

**대안으로 검토했다가 반려한 것**: `glass-brick/Scene-Manager`(별 626)는 **LICENSE 파일이 없다** — 라이선스 미명시는 전권 유보라 스팀 상업 출시에 쓰면 안 된다.

- **임팩트 / 비용**: 중 / 하

---

### 18. StyleBoxFlat 테두리 플래시

- **출처**: [StyleBoxFlat](https://docs.godotengine.org/en/stable/classes/class_styleboxflat.html) · [Control theme overrides](https://docs.godotengine.org/en/stable/classes/class_control.html)
- **무엇인가**: `StyleBox`는 일반 `Resource`라 속성을 그대로 트윈할 수 있다. 패널 테두리가 순간 굵어지며 색이 바뀌면 "이 패널에 지금 뭔가 일어났다"가 전달된다.
- **우리 게임 어디에**: `_answer_quiz()`(정답/오답 시 `detail`이 든 `info_card`), `_on_bid()`의 입찰 무효 3종 반려(지금은 `bid_preview.text` 교체 + `wrong` 사운드뿐이라 시각 반응이 약하다), `_update_cash()`의 `cash_card`.
- **Godot 4 구현 방법**: **반드시 `duplicate()` 후 override** — 테마 리소스는 공유되므로 원본을 건드리면 같은 스타일을 쓰는 모든 컨트롤이 같이 변한다.

```gdscript
## 패널 테두리 순간 강조. sb는 반드시 복제본이어야 한다 (테마 공유 사고 방지)
func _flash_border(p: PanelContainer, col: Color) -> void:
	var sb: StyleBoxFlat = p.get_theme_stylebox("panel").duplicate()
	p.add_theme_stylebox_override("panel", sb)
	var tw := p.create_tween()
	tw.tween_property(sb, "border_color", col, 0.07)
	tw.parallel().tween_method(func(w: int) -> void: sb.set_border_width_all(w), 1, 4, 0.07)
	tw.tween_property(sb, "border_color", COL_EDGE, 0.45)
	tw.parallel().tween_method(func(w: int) -> void: sb.set_border_width_all(w), 4, 1, 0.45)
```

- **임팩트 / 비용**: 중 / 하

---

### 19. 입력 버퍼링 + 쿨다운 시각화

- **출처**: [Designing Game Feel §III-A-8 (button caching: Mario 1~2프레임, Braid 0.23초)](https://arxiv.org/pdf/2011.09201) · [§III-B-4 (cooldown visualisation)](https://arxiv.org/pdf/2011.09201) · [How to Make Your Game Feel Good (150ms 이하)](https://egmatic.com/blog/how-to-make-your-game-feel-good)
- **무엇인가**: 연출 중 누른 입력을 삼키지 말고 **버퍼에 담았다가 유효해지는 순간 발사**한다. 버퍼가 없는 것이 UI가 "끈적하다"고 느껴지는 1번 원인. 그리고 비활성 버튼은 그냥 흐려지는 대신 **차올랐다가 다시 차는** 모습을 보여준다.
- **우리 게임 어디에**: `busy` 플래그. `_on_bid()`·`_show_tab()`·`_on_next()`가 전부 `if busy: return`으로 입력을 버린다. 기법 1의 `_skip`과 합쳐서, "연출 중 클릭 = 스킵", "연출 끝난 뒤 200ms 내 클릭 = 무시"로 처리하는 게 실전적이다.
- **Godot 4 구현 방법**: 기법 1의 `_unhandled_input` + `_last_skip_ms` 가드가 그대로 답이다. 추가로 `next_btn`이 나타날 때 시선 유도:

```gdscript
# _finish_case() 끝
next_btn.visible = true
Juice.pop_in(next_btn)
```

- **임팩트 / 비용**: 중 / 하

---

### 20. 유휴 애니메이션 · 배경 숨쉬기

- **출처**: [Designing Game Feel §III-D-5 (idle animations)](https://arxiv.org/pdf/2011.09201) · [What Features Influence Impact Feel? B4.1 (ambient feedback)](https://arxiv.org/pdf/2208.06155)
- **무엇인가**: **입력이 없을 때** 도는 작은 루프. 숙고하며 오래 앉아 있는 게임에서 특히 중요하다 — 화면이 죽어 있으면 게임이 멈춘 것처럼 느껴진다. 그리고 배경이 항상 미세하게 움직이면, 개찰 순간의 **정지**가 훨씬 세게 온다.
- **우리 게임 어디에**: 지지 `TextureRect`는 이미 무한 로테이션 아이들이 있다(`_build_ui()`). 하지만 `court` 배경은 개찰 때 말고는 완전 정지이고, `photo` 액자는 마우스 틸트(`_process`)만 있다. `_make_dust()`의 금가루는 좋은 시작점이지만 26개뿐이라 잘 안 보인다.
- **Godot 4 구현 방법**: 배경에 아주 느린 드리프트. `court.scale`은 `_ceremony()`가 쓰므로 `court.position`을 쓴다.

```gdscript
# _build_ui() — court 추가 직후
var breathe := court.create_tween().set_loops()
breathe.tween_property(court, "position:y", 6.0, 7.0) \
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
breathe.tween_property(court, "position:y", 0.0, 7.0) \
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
```

⚠️ GAG Intermediate에 **"배경 움직임을 끄는 옵션"** 항목이 있다. 기법 21의 `연출 강도` 설정에 묶을 것.

- **임팩트 / 비용**: 중 / 하

---

### 21. 접근성 설정 3종 (흔들림 / 번쩍임 / 연출 강도) + 스팀 태그

- **출처**: [Steamworks Accessibility Features (19개 공식 태그 전문)](https://partner.steamgames.com/doc/accessibility_features) · [WCAG 2.2 Three Flashes](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html) · [GAG — avoid flickering images](https://gameaccessibilityguidelines.com/avoid-flickering-images-and-repetitive-patterns/)
- **무엇인가**: 밸브가 개발자 자가 신고 방식으로 스토어 페이지에 표시·검색 필터링해 주는 19개 태그. 우리 게임은 2D UI 게임이라 **19개 중 11개를 며칠 작업으로 획득**할 수 있다.
- **우리 게임 어디에**: 설정 화면 자체가 없다. `title.gd`에 "설정" 버튼 하나 + `Game`에 필드 3개면 된다.
  - `화면 흔들림` → `Juice.shake`/`kick`/`_impact` → 스팀 **Camera Comfort**
  - `화면 번쩍임` → `Juice.flash`/`stars_burst`/취재진 플래시
  - `연출 속도` (보통/빠름/즉시) → `Game.fx_speed` → 스팀 **Playable at Your Own Pace**
  - 버스별 볼륨 (기법 4) → 스팀 **Custom Volume Controls**
  - `Window.content_scale_factor` 슬라이더 → 스팀 **Adjustable Text Size**
- **Godot 4 구현 방법**: 게이트를 `juice.gd` 진입부에 한 번만 둔다 — 호출부 30곳을 안 고쳐도 된다.

```gdscript
# juice.gd — shake / kick / flash 맨 앞
static func shake(c: Control, amount := 7.0, duration := 0.3) -> void:
	if not Game.fx_shake:
		return
	...

# 텍스트 크기 (전역, 한 줄)
get_window().content_scale_factor = Game.ui_scale   # 1.0 ~ 2.0
```

`content_scale_mode`는 `CONTENT_SCALE_MODE_CANVAS_ITEMS`로 두면 한글이 벡터 리샘플링돼 배율에서도 또렷하다. 그리고 Godot 4.5+의 내장 접근성(AccessKit)이 있으니 결과 패널만이라도:

```gdscript
result.accessibility_name = "경매 결과"
result.accessibility_live = Control.ACCESSIBILITY_LIVE_POLITE   # 값이 바뀌면 낭독
```

⚠️ **"간질 안전(epilepsy safe)"이라는 표현은 절대 쓰지 말 것** (GAG 명시). "화면 번쩍임 효과"처럼 기능 이름으로 적는다.

- **임팩트 / 비용**: 상 / 중

---

### 22. 결과별 스팅어 구분 + A/V 프레임 정렬

- **출처**: [What Features Influence Impact Feel? §IV — hit stop / sound coherence / camera control이 없으면 임팩트감이 "무너진다"](https://arxiv.org/pdf/2208.06155) · [Bluezone — creating tension with sound design](https://www.bluezone-corporation.com/blog/how-to-create-tension-with-sound-design)
- **무엇인가**: 44개 게임 조사에서 **사운드 일관성(A/V 지연 없음)** 은 없으면 임팩트감을 망치는 3대 요소 중 하나로 꼽혔다. 그리고 결과 종류마다 음색이 달라야 플레이어가 숫자를 읽기 한 박 전에 결과를 안다.
- **우리 게임 어디에**: `assets/sfx/`에 `win`/`lose`/`correct`/`wrong`/`nakchal` 5종이 있지만, `_settle_won()`은 이익/손실 모두 `win`/`lose` 둘로만 갈린다. 필요한 4분류: **싸게 낙찰 / 비싸게 낙찰(LDW) / 아깝게 패찰 / 크게 패찰**. 그리고 `get_tree().create_timer(0.55).timeout.connect(_voice.bind("v_final"))`(`_ceremony()`)처럼 **별도 타이머로 붙인 소리는 A/V가 어긋난다** — 트윈 콜백으로 옮겨야 한다.
- **Godot 4 구현 방법**: 스팅어 두 개(낙찰/패찰)를 **같은 길이·같은 악기**로 만들고 방향(상행/하행)과 조성만 바꾼다. 길이가 다르면 숫자가 뜨기 전에 길이로 결과가 새어 나가 리빌이 죽는다. 무료 소스는 아래 참조.

```gdscript
# _ceremony() — 타이머 대신 트윈 체인으로 A/V 고정
var t := create_tween()
t.tween_callback(func() -> void: _play("nakchal", -4.0, 1.0))
t.tween_interval(0.55)
t.tween_callback(_voice.bind("v_final"))
```

**무료·상업 이용 가능 음원 (라이선스 확인 완료)**
| 출처 | 라이선스 | 출처 표기 | 비고 |
|---|---|---|---|
| [Sonniss GDC Game Audio Bundle](https://sonniss.com/gameaudiogdc) | [독자 로열티프리](https://sonniss.com/gdc-bundle-license/) | **불필요** | 프로 96kHz 녹음, 프로젝트 수·기간 무제한. **AI/ML 학습 사용은 금지 조항 있음** |
| [Kenney.nl](https://kenney.nl/assets) | **CC0** | 불필요 | `Interface Sounds`(100개)·`UI Audio`·`Music Jingles`(85개)·`Casino Audio` — 우리 UI 사운드 대부분을 첫날에 덮는다 |
| [Freesound (CC0 필터)](https://freesound.org/search/?q=gavel&f=license%3A%22Creative+Commons+0%22) | **CC0** | 불필요 | 법봉/도장/현금등록기/드럼롤/군중 웅성거림 다수 확인 |
| [Incompetech](https://incompetech.com/music/royalty-free/faq.html) | CC-BY 4.0 | **필수** | 지정 문구 그대로 크레딧 필요 |
| [Pixabay](https://pixabay.com/service/license-summary/) | Pixabay License (CC0 아님) | 불필요 | 제3자 권리 면책 조항 있음 — 최후 수단 |
| ~~BBC Sound Effects~~ | **비상업 전용** | — | **사용 금지** |
| ~~FreePD~~ | — | — | **사이트 서비스 종료** |

특히 유용한 CC0 개별 항목: [경매 "Sold"](https://freesound.org/people/watchthatfilms/sounds/692529/) · [사무용 도장 여러 테이크](https://freesound.org/people/whammy/sounds/514486/) · [무한 루프 가능한 실내 웅성거림](https://freesound.org/people/SpliceSound/sounds/260124/) · [공증사무소 앰비언스(도장·프린터·말소리)](https://freesound.org/people/_vk/sounds/221848/) · [드럼롤+심벌 마무리](https://freesound.org/people/Scheffler/sounds/201211/)

⚠️ 조성 통일이 중요하다 — 드론·라이저·스팅어가 서로 다른 조성이면 싸구려로 들린다. 하나의 조(예: D단조)로 맞춰 피치 시프트할 것.

- **임팩트 / 비용**: 상 / 중

---

### 23. 3계층 앰비언스 (수직 리믹싱)

- **출처**: [Adaptive music — vertical remixing](https://en.wikipedia.org/wiki/Adaptive_music) · [AudioServer](https://docs.godotengine.org/en/stable/classes/class_audioserver.html) · [AudioStreamInteractive](https://docs.godotengine.org/en/stable/classes/class_audiostreaminteractive.html)
- **무엇인가**: 곡을 바꾸지 않고 **레이어를 켜고 끄면서** 강도를 조절한다. 같은 길이·같은 템포·같은 조성의 스템 3개를 같은 프레임에 시작해 루프시키고 `volume_db`만 트윈한다.
- **우리 게임 어디에**: BGM이 아예 없다. 3단계면 충분하다 — 조사(`_show_auction`) → 입찰(`_show_bid_form`) → 개찰(`_ceremony`).
- **Godot 4 구현 방법**: `AudioStreamInteractive`(비트 정렬 전환)는 에디터 저작이 필요하고 우리한테는 과하다. **`AudioStreamPlayer` 3개 + 볼륨 트윈**이 사다리 3~4단계의 정답.

```gdscript
var _amb: Array[AudioStreamPlayer] = []

func _ambience(level: int) -> void:   # 0 조사 / 1 입찰 / 2 개찰
	for i in _amb.size():
		create_tween().tween_property(_amb[i], "volume_db",
			-8.0 if i <= level else -60.0, 0.8)
```

`-60dB`까지 내리면 Godot이 무음 버스를 자동으로 비활성화해 유휴 비용이 0이 된다. 페이드는 50ms 미만으로 하면 클릭 노이즈가 난다.
`Master` 버스에 `AudioEffectHardLimiter`를 하나 걸 것 — 무료 라이브러리 소스는 레벨이 제각각이라 법봉+스팅어+군중이 한 프레임에 겹치면 클립된다.

- **임팩트 / 비용**: 중상 / 중

---

### 24. 포물선 낙하 (봉투 투함) + 궤적

- **출처**: [Designing Game Feel §III-D-1 (trails)](https://arxiv.org/pdf/2011.09201) · [Line2D](https://docs.godotengine.org/en/stable/classes/class_line2d.html) · [PathFollow2D](https://docs.godotengine.org/en/stable/classes/class_pathfollow2d.html)
- **무엇인가**: 물체가 직선으로 떨어지면 무게가 안 느껴진다. x는 등속, y는 가속으로 나누면 포물선이 되고 물리적 인상이 생긴다.
- **우리 게임 어디에**: `_take_receipt_and_drop()`의 `drop` 트윈(`position:y`만 +360, x는 고정)과 `_quick_submit()`의 동일 패턴.
- **Godot 4 구현 방법**: `Path2D`+`PathFollow2D`도 되지만 Control 기반 UI에선 노드 2개가 늘어난다. **두 트윈을 다른 이징으로 병렬 실행하는 게 한 줄 차이로 같은 결과** — 사다리 4단계.

```gdscript
# _take_receipt_and_drop() — drop 트윈 교체
big_env.pivot_offset = big_env.size / 2.0
var drop := big_env.create_tween().set_parallel(true)
drop.tween_property(big_env, "position:x", big_env.position.x + 140.0, 0.45) \
	.set_trans(Tween.TRANS_LINEAR)                              # 가로는 등속
drop.tween_property(big_env, "position:y", big_env.position.y + 380.0, 0.45) \
	.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)        # 세로는 가속 → 포물선
drop.tween_property(big_env, "rotation", 0.62, 0.45).set_trans(Tween.TRANS_SINE)
drop.tween_property(big_env, "modulate:a", 0.0, 0.42)
```

궤적(`Line2D`)까지 원하면 `_process`에서 점을 쌓고 24개 넘으면 앞에서 버린다. 단 **접촉 프레임에 궤적은 즉시 사라져야** 한다(실무 권고).

- **임팩트 / 비용**: 중 / 하

---

### 25. 33% 확률 변주 (취재진 플래시)

- **출처**: [Vlambeer — 33% 확률로 적이 무해하게 폭발](https://www.gamedeveloper.com/design/vlambeer-co-founder-shares-advice-on-building-better-action-games) · [Behavioral Game Design — 변동비율 스케줄](https://www.gamedeveloper.com/design/behavioral-game-design)
- **무엇인가**: 결과에 영향을 주지 않는 순수 장식 변주를 낮은 확률로 섞는다. 수백 번 보게 될 루프에서 "매번 똑같다"는 감각을 깬다. 고정비율(매 10번째)이 아니라 **변동비율**이어야 한다 — 고정이면 학습되어 무의미해진다.
- **우리 게임 어디에**: `_ceremony()`의 낙찰 순간. 지금 낙찰 리액션은 항상 동일하다(점프+별). `nicks` 배열로 경쟁자 이름은 이미 무작위화돼 있으니 같은 결에 맞는다.
- **Godot 4 구현 방법**:

```gdscript
# _ceremony() — 낙찰 리액션 안
if Game.fx_flash and randf() < 0.33:            # 3번에 1번, 취재진 플래시
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, 0.0)
	f.size = Vector2(300, 220)                   # WCAG 면적 하한 아래로 유지
	f.position = Vector2(size.x * randf_range(0.1, 0.75), size.y * 0.15)
	sprite_layer.add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "color:a", 0.85, 0.04)
	tw.tween_property(f, "color:a", 0.0, 0.22)
	tw.tween_callback(f.queue_free)
	_play("click", -10.0, 1.8)
```

⚠️ 반드시 `Game.fx_flash` 게이트를 통과시키고, 1초에 3회를 넘지 않게 할 것.

- **임팩트 / 비용**: 중 / 하

---

## 연출이 과해서 생기는 문제

### 1. 실증적으로, 우리는 이미 천장을 넘었을 가능성이 높다

Juul & Begy는 **기계적으로 완전히 동일한** 매치 게임 두 버전을 만들어 비교했다([논문](https://www.jesperjuul.net/text/juiciness.pdf)):

| | 주스 있음 | 주스 없음 |
|---|---|---|
| 품질 평가 | **3.74** | 3.26 |
| 실제 점수 | **40,340** | **49,682** |
| 사용 편의성 | 4.43 | **4.57** |

플레이어는 화려한 쪽을 **좋다고 평가했지만 성적은 19% 나빴고 쓰기 어렵다고 답했다**. 중복 피드백이 인지 부하를 올리기 때문이다. Kao의 대규모 연구도 **중·고 수준의 주스가 극단적 주스보다 모든 지표에서 우수**하다고 결론냈다.

**우리 게임은 숫자를 정확히 읽어야 하는 게임이다.** 주스가 정확히 저해하는 그 과제다. `_ceremony()` 낙찰 순간에는 지금 이만큼이 동시에 발사된다 — 드럼롤 정지 · `nakchal` 스팅어 · `v_final` 음성 · `Juice.shake(self, 10.0)` · `_call()` 말풍선 펀치 · 낙찰자 펀치 1.3배 · `stars_burst` 14개 · 점프 트윈 · 패자 4명 시무룩 트윈 · 배경 줌 · 금가루 파티클. **11개다.**

이 문서의 다음 수는 12번째 효과가 아니라, 이 11개를 **시간축에 흩뿌리는 것**(기법 2·5·11·22)이다.

### 2. 반복 시 지겨움 — 숫자로 보면

`_ceremony()` 한 번의 강제 대기:

```
open_wait 1.5~3.2s  +  호명 1.05s × 최대 5명  +  "마지막 봉투" 0.8s  +  스팅어 여운 1.8s
≈ 9.4초
```

여기에 `_confirmation()` 1.7초, `_show_event()` 1.7초, `_settle_won()` 정산 행(항목 수 × 0.18 + 0.5), `_impact()` 1.2초가 붙는다. `Game.round_size`는 기본 **20**이다.

**라운드당 최소 3~4분이 건너뛸 수 없는 대기다.** 두 번째 라운드부터 이건 연출이 아니라 벌칙이다. 기법 1이 이 문서 전체에서 가장 중요한 이유다.

설계 기준(3개 기관 가이드라인 종합):
- **처음 보는 물건에서만 온전한 연출**, 이후엔 짧게
- **아무 클릭 = 현재 단계 즉시 완료**, 연타 = 전부 완료. 건너뛰기에 **길게 누르기를 요구하지 말 것**(GAG Motor: 잦은 동작에 홀드 금지)
- 속도 설정은 **한 번 정하면 저장**. 매 라운드 다시 누르게 하면 안 된다(GAG Basic: 모든 설정은 기억돼야 한다)
- 결과 텍스트는 **타이머로 자동 넘기지 말 것** — 성인의 14%가 읽기 연령 11세 미만이다

### 3. 접근성 — 지금 걸리는 항목

| 항목 | 현재 상태 | 근거 |
|---|---|---|
| 색만으로 손익 표시 | ❌ `lightgreen`/`salmon` — 아시아권 남성 5% 구분 불가 | [GAG Basic](https://gameaccessibilityguidelines.com/ensure-no-essential-information-is-conveyed-by-a-fixed-colour-alone/) |
| 화면 흔들림 끄기 | ❌ 없음 (`Juice.shake` 무조건 발동) | 스팀 `Camera Comfort` |
| 번쩍임 끄기 | ❌ 없음 (`_impact` 색 띠 + 별 파티클) | [WCAG 3-flash](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html) |
| 볼륨 조절 | ❌ 버스도 설정 화면도 없음 (`volume_db` 하드코딩) | 스팀 `Custom Volume Controls` |
| 텍스트 크기 | ❌ `font_size` 하드코딩 (10~68px 혼재) | 1080p 최소 18px, 200% 확대 필요 — [XAG 101](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/101) |
| 한글 줄 길이 | ⚠️ 미검증 | **한국어는 한 줄 40자 이하** (XAG 101 CJK 규정) |
| 자동 줄바꿈 | ⚠️ `speech`만 `AUTOWRAP_WORD_SMART` | 도로명주소가 길어 `AUTOWRAP_WORD`는 넘친다 |
| 키보드 전용 조작 | ❌ 미검증 | 스팀 `Keyboard Only Option` |
| 설정 저장 | ❌ `Game`이 메모리에만 존재 | [GAG Basic](https://gameaccessibilityguidelines.com/full-list/) |

`10px`(`_digit_row`의 단위 라벨), `11px`(입찰표 주의문), `12px`(주민번호/주소 줄)는 1080p 최소 기준 18px에 크게 못 미친다. 입찰표는 "실제 서류 재현"이라는 의도가 있으니 **`연출 강도`가 아니라 `UI 크기` 배율에 함께 태우는 것**이 현실적인 타협이다.

### 4. 폰트 서브셋 함정

Noto Sans KR을 용량 때문에 서브셋하면 안 된다. **한글 음절 블록 U+AC00–U+D7A3 전체(11,172자)** 를 포함해야 한다 — 실데이터의 주소·물건 이름에 현재 JSON에 없는 글자가 반드시 나온다. 굵기도 Regular + Bold 최소 2종이 필요하다(200% 확대 시 헤더와 본문이 구분돼야 함).

### 5. gl_compatibility에서 하면 안 되는 것

조사 중 확인된, 우리 렌더러에서 **깨지거나 존재하지 않는** 것들:

- **`CanvasGroup` + 화면 읽기 셰이더 → 흰 화면.** 열린 버그, 4.3~4.7.dev ([godot#116729](https://github.com/godotengine/godot/issues/116729)). 흔히 추천되는 "UI를 CanvasGroup으로 감싸고 후처리 셰이더" 패턴을 쓰면 안 된다
- **`BackBufferCopy`의 Rect 모드** — 화면 텍스처가 갱신되지 않는다 ([#111096](https://github.com/godotengine/godot/issues/111096), 전 렌더러 공통). Viewport 모드만 사용
- **컴퓨트 셰이더 · `RenderingDevice` · `CompositorEffect`** — 전부 미지원. 이걸 쓰는 애드온(`Acerola-Compute`, `GodotRetro` 등)은 설치 불가
- **`GPUParticles2D.emit_particle()`** — Compatibility 미지원. 파티클 트레일·SDF 충돌도 미지원. **우리가 `_make_dust()`에서 이미 `CPUParticles2D`를 쓰는 건 정답이다** — 계속 유지할 것
- **2D MSAA · 디밴딩 · 2D HDR 뷰포트** — 미지원
- 반면 `hint_screen_texture`(2D) 자체는 **동작한다.** 다만 전체 화면 복사 비용이 붙고 위 버그들에 걸리므로, 크로마틱 애버레이션·방사형 블러가 정말 필요하면 **SubViewport + SubViewportContainer 셰이딩**으로 우회하는 편이 안전하고 더 싸다

### 6. "무엇을 juice할 것인가"

> "당신은 게임을 juice하는 게 아니라, **하나의 느낌을 골라 그 느낌을 juice하는 것**이다." — Lisa Brown

법원 경매의 느낌은 **긴장·무게·결과**지 아케이드적 쾌감이 아니다. 별 파티클과 거대 글씨 슬램은 Peggle의 문법이다. 위 25개 중 우리 정서에 맞는 건 **느린 쪽**들이다 — 지속물(15), 단계 공개(2), 무음(4), 니어미스(13), 유휴/숨쉬기(20), 타자기(9). 화려한 쪽(25번 플래시, 8번 화이트아웃)은 아껴 쓸수록 세진다.

---

## 부록 — 검토했으나 도입하지 않기로 한 것

| 대상 | 이유 |
|---|---|
| `glass-brick/Scene-Manager` (별 626) | **LICENSE 파일 없음** = 전권 유보. 상업 출시 불가 |
| GDQuest `godot-shaders`의 아트 에셋 | CC-BY-**NC**-SA (비상업). `.gdshader` 파일만 MIT라 코드만 발췌 가능 |
| `Dialogic`, `Juicee`, `Godot-Tween-Suite` | 에디터 툴링 중심 대형 애드온. 아이디어 참고용으로만 — 사다리 1·3단계 위반 |
| `AnimationTree` | `tree_root` + `anim_player` 필수, 붙이는 순간 `AnimationPlayer` 일부 속성이 오작동한다고 문서에 명시. 캐릭터 상태머신용이라 UI엔 순수 오버헤드 |
| 숫자 롤링 라이브러리 | Godot 4용 유지보수되는 것이 없고, `tween_method` 한 줄이면 된다 — 우리 `Juice.count`가 이미 그것 |
| 9-slice 애드온 | `NinePatchRect`·`StyleBoxTexture`가 코어 |
| `Camera2D` | Control 앵커는 뷰포트 기준이라 캔버스 변환과 충돌한다. 루트 `Control`의 `position`/`scale` 트윈이 정답 (우리 `Juice.shake`가 이미 그 방식) |
| `Window.position` 실제 창 흔들기 | 타일링 WM·전체화면·스팀 오버레이에서 오작동. 고장으로 읽힌다 |
| `AudioStreamInteractive` | 비트 정렬 전환이 필요해질 때까지 YAGNI. 볼륨 크로스페이드로 충분 |
| `Path2D`/`PathFollow2D` 아크 | 노드 2개 대신 트윈 2개로 같은 결과 (기법 24) |

## 참고 문헌

**게임필 이론**
[Designing Game Feel: A Survey — Pichlmair & Johansen](https://arxiv.org/pdf/2011.09201) · [What Features Influence Impact Feel? (44개 게임 조사)](https://arxiv.org/pdf/2208.06155) · [Good Feedback for bad Players? — Juul & Begy](https://www.jesperjuul.net/text/juiciness.pdf) · [The Art of Screenshake — Nijman](https://theengineeringofconsciousexperience.com/jan-willem-nijman-vlambeer-the-art-of-screenshake/) · [Juice it or lose it — Jonasson & Purho](https://www.youtube.com/watch?v=Fy0aCDmgnxg) · [Oil it or Spoil it — Doucet](https://www.fortressofdoors.com/oil-it-or-spoil-it/) · [Behavioral Game Design — Hopson](https://www.gamedeveloper.com/design/behavioral-game-design) · [Near-miss & LDW 리뷰](https://pubmed.ncbi.nlm.nih.gov/28421402/)

**Godot 문서**
[Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html) · [렌더러 비교(Compatibility 제약)](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) · [화면 읽기 셰이더](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html) · [BBCode](https://docs.godotengine.org/en/stable/tutorials/ui/bbcode_in_richtextlabel.html) · [AudioServer](https://docs.godotengine.org/en/stable/classes/class_audioserver.html) · [AudioEffectFilter](https://docs.godotengine.org/en/stable/classes/class_audioeffectfilter.html) · [AudioStreamRandomizer](https://docs.godotengine.org/en/stable/classes/class_audiostreamrandomizer.html) · [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html) · [StyleBoxFlat](https://docs.godotengine.org/en/stable/classes/class_styleboxflat.html) · [Control](https://docs.godotengine.org/en/stable/classes/class_control.html) · [CanvasItemMaterial](https://docs.godotengine.org/en/stable/classes/class_canvasitemmaterial.html)

**접근성**
[Steamworks Accessibility Features](https://partner.steamgames.com/doc/accessibility_features) · [Game Accessibility Guidelines 전체 목록](https://gameaccessibilityguidelines.com/full-list/) · [Xbox Accessibility Guideline 101 (텍스트 크기·CJK 줄 길이)](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/101) · [WCAG 2.2 Three Flashes](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html) · [Okabe-Ito 팔레트](https://jfly.uni-koeln.de/color/) · [Paul Tol 팔레트](https://sronpersonalpages.nl/~pault/) · [W3C 한국어 텍스트 레이아웃 요구사항](https://www.w3.org/TR/klreq/) · [AbleGamers APX](https://accessible.games/accessible-player-experiences/)

**오픈소스 (라이선스 확인 완료)**
[Universal-Transition-Shader — CC0-1.0](https://github.com/cashew-olddew/Universal-Transition-Shader) · [Kenney 에셋 — CC0](https://kenney.nl/assets) · [RPicster 파티클 텍스처 — CC0](https://github.com/RPicster/Godot-particle-and-vfx-textures) · [MrEliptik/godot_ui_components — MIT](https://github.com/MrEliptik/godot_ui_components) · [GodotRichTextLabel2 — MIT](https://github.com/chairfull/GodotRichTextLabel2) · [BurstParticles2D — MIT](https://github.com/uzkbwza/BurstParticles2D) · [Sonniss GDC Bundle 라이선스](https://sonniss.com/gdc-bundle-license/)
