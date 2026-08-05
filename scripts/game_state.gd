extends Node
## 게임 설정 싱글톤 (autoload: Game) — 입찰 준비 화면에서 채워짐

var capital := 2_000_000_000
var simple_bid := false  # 기일입찰표 상세 과정 생략
var region: PackedStringArray = []  # 주소 앞 토큰 경로 (예: ["인천", "남동구"]). 빈 배열 = 전체
var kinds: Array = []               # 허용 용도 문자열 (빈 = 전체)
var series_label := "전체"
var jong_label := "전체"


func region_match(address: String) -> bool:
	if region.is_empty():
		return true
	var toks := address.split(" ")
	for i in region.size():
		if i >= toks.size() or toks[i] != region[i]:
			return false
	return true


func kind_allowed(kind: String) -> bool:
	if kinds.is_empty():
		return true
	for k in kinds:
		if kind == k or String(k).begins_with(kind) or kind.begins_with(String(k)):
			return true
	return false


func filter_auctions(auctions: Array) -> Array:
	var out: Array = []
	for a in auctions:
		# kind_tax는 선택 UI(usage_taxonomy)의 이름, kind는 화면 표시용 원래 이름
		if kind_allowed(str(a.get("kind_tax", a.get("kind", "")))) and region_match(str(a.get("address", ""))):
			out.append(a)
	return out