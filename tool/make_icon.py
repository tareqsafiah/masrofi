# يولّد أيقونة التطبيق assets/icon.png
import os
from PIL import Image, ImageDraw
S = 1024
img = Image.new('RGB', (S, S))
d = ImageDraw.Draw(img)
top, bot = (46, 214, 160), (14, 58, 69)
for y in range(S):
    for x in range(0, S, 4):
        t = (x + y) / (2 * S)
        c = tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3))
        d.line([(x, y), (x + 3, y)], fill=c)
layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
ld = ImageDraw.Draw(layer)
ld.rounded_rectangle([200, 330, 824, 760], radius=90, fill=(255, 255, 255, 245))
ld.rounded_rectangle([250, 260, 720, 380], radius=60, fill=(255, 255, 255, 150))
ld.rounded_rectangle([600, 470, 860, 620], radius=60, fill=(13, 16, 21, 255))
ld.ellipse([660, 510, 730, 580], fill=(46, 214, 160, 255))
ld.line([(300, 660), (390, 570), (450, 620), (540, 520)], fill=(20, 163, 122, 255), width=34, joint='curve')
ld.polygon([(560, 500), (500, 505), (555, 560)], fill=(20, 163, 122, 255))
img.paste(layer, (0, 0), layer)
os.makedirs('assets', exist_ok=True)
img.save('assets/icon.png')
