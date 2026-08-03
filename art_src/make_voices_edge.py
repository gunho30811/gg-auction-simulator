"""집행관 음성 생성 (Edge TTS — ko-KR-InJoonNeural 남성, 차분한 톤)
공용 라인 + 물건별 사건번호 호명을 mp3로 assets/sfx에 생성.
사용: py art_src/make_voices_edge.py   (네트워크 필요. 실데이터 교체 후 재실행)
"""
import asyncio
import json
import os
import re

import edge_tts

VOICE = "ko-KR-InJoonNeural"
RATE = "-10%"
PITCH = "-8Hz"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sfx")

LINES = {
    "v_open": "지금부터 개찰을 시작하겠습니다.",
    "v_rank5": "오 순위.",
    "v_rank4": "사 순위.",
    "v_rank3": "삼 순위.",
    "v_rank2": "이 순위.",
    "v_rank1": "일 순위.",
    "v_last": "마지막 봉투입니다.",
    "v_final": "낙찰입니다! 축하합니다!",
}


def case_lines():
    auctions = json.load(open(os.path.join(ROOT, "data", "sample_auctions.json"), encoding="utf-8"))
    out = {}
    for i, a in enumerate(auctions):
        case = a["case_no"].split(" ")[0].split("(")[0]
        m = re.match(r"(\d{4})타경(\d+)", case)
        if m:
            out["case_%d" % i] = f"사건번호, {m.group(1)} 타경 {m.group(2)}호. 개찰을 시작하겠습니다."
    return out


async def main():
    all_lines = LINES | case_lines()
    for name, text in all_lines.items():
        dst = os.path.join(OUT, name + ".mp3")
        await edge_tts.Communicate(text, VOICE, rate=RATE, pitch=PITCH).save(dst)
        print(name + ".mp3", "<-", text)


asyncio.run(main())
