"""从品牌 logo 生成安卓应用图标（legacy mipmap + adaptive 前景/背景）。

logo 原图是带文字的方形徽章。文字在 48dp 下不可读，因此只取徽章内部
上半段的鲸鱼与浪花；四周留白用边缘像素复制（edge replication）延展，
底色即 logo 自身的白到浅蓝渐变，不会出现拼接色差。
"""

import os
from PIL import Image, ImageDraw

SRC = r"C:\Users\nie\Downloads\logo.png"
RES = r"C:\Users\nie\Desktop\SIP_terminal\sip_terminal_app\android\app\src\main\res"

# 徽章内部、仅含鲸鱼与浪花的区域。下边界取 y=1204：实测这一行是浪花之下、
# “小栋通信”字头之上最干净的一行（非背景像素仅约 9%），中位色填充几乎无缝。
ART_BOX = (424, 404, 1626, 1204)

LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
FOREGROUND = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def _stretch_h(art: Image.Image, width: int) -> Image.Image:
    """把 art 水平居中放到 width 宽的画布上，左右空白用首/末列像素拉伸填充。"""
    aw, ah = art.size
    out = Image.new("RGB", (width, ah))
    left = (width - aw) // 2
    if left > 0:
        out.paste(art.crop((0, 0, 1, ah)).resize((left, ah)), (0, 0))
        right = width - aw - left
        if right > 0:
            out.paste(art.crop((aw - 1, 0, aw, ah)).resize((right, ah)), (left + aw, 0))
    out.paste(art, (left, 0))
    return out


def _edge_color(img: Image.Image, row: int) -> tuple:
    """取某一行的中位色作为该侧留白的填充色。

    不能直接拉伸边缘行：浪花线条与水花会被拉成竖条纹。中位色取到的是这一行
    真正的背景色（浪花只占少数像素），和 logo 自身的白/浅蓝底完全一致。
    """
    w = img.size[0]
    px = [img.getpixel((x, row)) for x in range(0, w, max(1, w // 240))]
    return tuple(sorted(c[i] for c in px)[len(px) // 2] for i in range(3))


def _stretch_v(img: Image.Image, height: int, center: float) -> Image.Image:
    """垂直居中（center 为中心位置比例），上下留白填该侧边缘行的中位背景色。"""
    w, h = img.size
    top = max(0, min(height - h, round(height * center) - h // 2))
    out = Image.new("RGB", (w, height), _edge_color(img, h - 1))
    if top > 0:
        out.paste(Image.new("RGB", (w, top), _edge_color(img, 0)), (0, 0))
    out.paste(img, (0, top))
    return out


def compose(size: int, art_ratio: float, center_y: float) -> Image.Image:
    art = Image.open(SRC).convert("RGB").crop(ART_BOX)
    aw = round(size * art_ratio)
    ah = round(aw * art.height / art.width)
    art = art.resize((aw, ah), Image.LANCZOS)
    return _stretch_v(_stretch_h(art, size), size, center_y)


def rounded(img: Image.Image, radius_ratio: float) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1],
        radius=round(img.size[0] * radius_ratio),
        fill=255,
    )
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


for density, px in LEGACY.items():
    # 圆角自绘：现代 launcher 会再套一层遮罩（不可见），老 launcher 直接显示也正常
    icon = rounded(compose(px * 4, 0.96, 0.46), 0.22).resize((px, px), Image.LANCZOS)
    icon.save(os.path.join(RES, f"mipmap-{density}", "ic_launcher.png"))

for density, px in FOREGROUND.items():
    # adaptive 前景把主体收进中心安全区（108dp 中的 66dp），圆形遮罩不切鲸鱼
    fg = compose(px * 3, 0.80, 0.46).resize((px, px), Image.LANCZOS)
    fg.save(os.path.join(RES, f"mipmap-{density}", "ic_launcher_foreground.png"))

print("icons written")
