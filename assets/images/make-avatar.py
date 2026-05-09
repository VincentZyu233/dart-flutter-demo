from PIL import Image, ImageOps

src = r"./mahiro-pfp-VincentZyu.jpg"
dst = r"./mahiro-pfp-VincentZyu-square.png"

img = Image.open(src).convert("RGBA")
img = ImageOps.fit(img, (512, 512), method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))
img.save(dst)
print(dst)