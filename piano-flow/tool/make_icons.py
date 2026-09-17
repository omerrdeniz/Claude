# Draws the app icons — home screen, launcher and browser tab.
#
#     pip install pillow && python3 tool/make_icons.py
#
# Writes web/icons/*.png and web/favicon.png. The ones Flutter ships with the
# project template are the Flutter logo, which is what the game showed on the
# home screen until this existed.
#
# The picture is the game's own: notes falling towards the line they are
# played on, coloured the way the game colours a chord by how many notes it
# holds. Kept deliberately plain — at 192 pixels on a home screen, anything
# finer turns to mud.

from PIL import Image, ImageDraw

# The game's own palette (lib/theme/app_theme.dart): a colour per chord size.
BG     = (11, 11, 20)
VIOLET = (155, 107, 255)
AMBER  = (255, 192, 72)
BLUE   = (63, 169, 255)
GREEN  = (61, 214, 140)
LINE   = (150, 150, 170)

SS = 4  # supersample, then downsample for smooth edges


def draw(size, maskable):
    n = size * SS
    img = Image.new("RGB", (n, n), BG)   # opaque: PIL's draw writes, not blends
    d = ImageDraw.Draw(img)

    # A maskable icon gets cropped to a circle, so keep everything well inside.
    inset = 0.14 if maskable else 0.06
    def p(v):
        return (inset + v * (1 - 2 * inset)) * n
    span = (1 - 2 * inset) * n

    # The line a note is played on, where the game puts it: low on the stage.
    ly = p(0.72)
    h = 0.016 * span
    d.rounded_rectangle([p(0.06), ly - h, p(0.94), ly + h],
                        radius=h, fill=LINE)

    # Notes falling towards it, coloured the way the game colours a chord by
    # how many notes it holds: one violet, two amber, three blue, four green.
    for cx, cy, colour in [
        (0.19, 0.30, VIOLET),
        (0.41, 0.52, AMBER),
        (0.63, 0.16, BLUE),
        (0.83, 0.46, GREEN),
    ]:
        r = 0.10 * span
        x, y = p(cx), p(cy)
        d.ellipse([x - r, y - r, x + r, y + r], fill=colour)

    return img.resize((size, size), Image.LANCZOS)


for size in (192, 512):
    draw(size, False).save(f"web/icons/Icon-{size}.png")
    draw(size, True).save(f"web/icons/Icon-maskable-{size}.png")
draw(64, False).save("web/favicon.png")
print("icons written")
