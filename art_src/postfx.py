"""렌더 후처리: 채도·대비 업 + 소프트 글로우 + 다운스케일 → 게임용 PNG
사용: py art_src/postfx.py <입력.png> <출력.png> [크기(기본 1024)]
"""
import sys

from PIL import Image, ImageEnhance, ImageFilter

src, dst = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 1024

img = Image.open(src).convert("RGBA")
rgb = img.convert("RGB")
rgb = ImageEnhance.Color(rgb).enhance(1.18)      # 채도
rgb = ImageEnhance.Contrast(rgb).enhance(1.06)   # 대비
rgb = ImageEnhance.Brightness(rgb).enhance(1.03)

# 소프트 글로우 (스크린 합성 근사)
blur = rgb.filter(ImageFilter.GaussianBlur(radius=img.width // 90))
rgb = Image.blend(rgb, Image.composite(blur, rgb, blur.convert("L")), 0.25)

out = Image.merge("RGBA", (*rgb.split(), img.split()[3]))
out = out.resize((size, size), Image.LANCZOS)
out.save(dst)
print("POSTFX DONE:", dst)
