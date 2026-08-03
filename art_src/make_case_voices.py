"""사건번호 호명 음성 자동 생성 파이프라인
data/sample_auctions.json의 각 물건에 대해
"사건번호, YYYY 타경 NNNNN호. 개찰을 시작하겠습니다." 를 TTS로 생성하고
피치다운(중후한 톤) 가공 → assets/sfx/case_<idx>.wav

사용: py art_src/make_case_voices.py   (Windows, Heami 음성 필요)
실데이터 교체 후 재실행하면 전체 물건 음성이 다시 생성된다.
"""
import json
import math
import os
import re
import struct
import subprocess
import tempfile
import wave

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data", "sample_auctions.json")
OUT_DIR = os.path.join(ROOT, "assets", "sfx")


def tts_raw(text, path):
    ps = (
        "Add-Type -AssemblyName System.Speech; "
        "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
        "$s.SelectVoice('Microsoft Heami Desktop'); $s.Rate = 4; "
        f"$s.SetOutputToWaveFile('{path}'); $s.Speak('{text}'); $s.Dispose()"
    )
    subprocess.run(["powershell", "-NoProfile", "-Command", ps], check=True, capture_output=True)


def deepen(src, dst, pitch=0.82):
    with wave.open(src, "rb") as w:
        sr = w.getframerate()
        n = w.getnframes()
        ch = w.getnchannels()
        raw = w.readframes(n)
    data = struct.unpack("<%dh" % (n * ch), raw)
    mono = data[::ch]
    step = pitch * sr / SR
    out = []
    pos = 0.0
    while pos < len(mono) - 1:
        i = int(pos)
        frac = pos - i
        out.append((mono[i] * (1 - frac) + mono[i + 1] * frac) / 32768.0)
        pos += step
    tail = int(SR * 0.09)
    for i in range(tail, len(out)):
        out[i] += out[i - tail] * 0.22
    peak = max(1e-9, max(abs(s) for s in out))
    norm = [max(-1.0, min(1.0, s / peak * 0.92)) for s in out]
    with wave.open(dst, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in norm))


auctions = json.load(open(DATA, encoding="utf-8"))
tmp = tempfile.mkdtemp()
for i, a in enumerate(auctions):
    case = a["case_no"].split(" ")[0].split("(")[0]
    m = re.match(r"(\d{4})타경(\d+)", case)
    if not m:
        print("skip (형식 불일치):", a["case_no"])
        continue
    text = f"사건번호, {m.group(1)} 타경 {m.group(2)}호. 개찰을 시작하겠습니다."
    raw = os.path.join(tmp, f"case_{i}_raw.wav")
    dst = os.path.join(OUT_DIR, f"case_{i}.wav")
    tts_raw(text, raw)
    deepen(raw, dst)
    print(f"case_{i}.wav  <-  {text}")
print("done")
