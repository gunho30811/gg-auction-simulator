"""태극기 텍스처 생성 (태극 문양 + 4괘) → art_src/taegukgi.png (512x342, 3:2)"""
import math
import os

from PIL import Image, ImageDraw

W, H = 512, 342
img = Image.new("RGB", (W, H), (255, 255, 255))
d = ImageDraw.Draw(img)

cx, cy = W / 2, H / 2
R = H / 4  # 태극 반지름 (규격: 세로의 1/2 지름)

RED = (205, 46, 58)
BLUE = (0, 71, 160)
BLACK = (20, 20, 20)

# 태극: 공식 규격은 대각선 기준 — 대각선 각도로 회전한 S자
ang = math.atan2(H, W)  # 좌하-우상 대각선 각도

# 큰 원: 위쪽(회전 기준) 빨강, 아래 파랑 반원
deg = math.degrees(ang)
d.pieslice([cx - R, cy - R, cx + R, cy + R], 180 - deg, 360 - deg, fill=RED)
d.pieslice([cx - R, cy - R, cx + R, cy + R], -deg, 180 - deg, fill=BLUE)
# 작은 반원 2개로 S자 완성 (대각선 방향 오프셋)
ox, oy = (R / 2) * math.cos(ang), (R / 2) * math.sin(ang)
d.ellipse([cx - ox - R / 2, cy + oy - R / 2, cx - ox + R / 2, cy + oy + R / 2], fill=BLUE)
d.ellipse([cx + ox - R / 2, cy - oy - R / 2, cx + ox + R / 2, cy - oy + R / 2], fill=RED)


def trigram(cx_, cy_, angle, bars):
    """괘 그리기: bars = [True(이어짐)/False(끊어짐)] 3개, 태극 쪽에서 바깥 순"""
    bw, bh, gap = R * 0.94, R * 0.18, R * 0.09
    for i, solid in enumerate(bars):
        off = (R * 1.32) + i * (bh + gap)
        ca, sa = math.cos(angle), math.sin(angle)
        bx, by = cx_ + off * ca, cy_ + off * sa
        px, py = -sa, ca  # 바 방향(각도에 수직)
        def rect(x0, x1):
            pts = []
            for dx, dz in ((x0, -bh / 2), (x1, -bh / 2), (x1, bh / 2), (x0, bh / 2)):
                pts.append((bx + dx * px + dz * ca, by + dx * py + dz * sa))
            d.polygon(pts, fill=BLACK)
        if solid:
            rect(-bw / 2, bw / 2)
        else:
            rect(-bw / 2, -bw * 0.07)
            rect(bw * 0.07, bw / 2)


# 4괘: 건(좌상 ☰), 곤(우하 ☷), 감(우상 ☵), 리(좌하 ☲)
trigram(cx, cy, math.pi + ang, [True, True, True])            # 건 — 좌상
trigram(cx, cy, ang, [False, False, False])                    # 곤 — 우하
trigram(cx, cy, -ang, [False, True, False])                    # 감 — 우상
trigram(cx, cy, math.pi - ang, [True, False, True])            # 리 — 좌하

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "taegukgi.png")
img.save(out)
print("saved:", out)
