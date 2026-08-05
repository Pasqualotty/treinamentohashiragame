from pathlib import Path
from PIL import Image

files = [
    "assets/ui/map/world_map_w1.png",
    "assets/ui/map/node_stage.png",
    "assets/ui/map/node_boss_lock.png",
    "assets/ui/map/node_cleared.png",
    "assets/backgrounds/w1/stage_forest.png",
    "assets/backgrounds/w1/stage_village.png",
    "assets/backgrounds/w1/stage_mountain.png",
    "assets/tiles/w1/ground_platform_strip.png",
    "assets/characters/player/combat/tanjiro_run.png",
    "assets/characters/player/combat/tanjiro_attack_slash.png",
]
ok = True
for p in files:
    path = Path(p)
    if not path.exists():
        print("MISSING", p)
        ok = False
        continue
    with open(path, "rb") as f:
        hdr = f.read(8)
    real = hdr == b"\x89PNG\r\n\x1a\n"
    im = Image.open(path)
    status = "OK" if real else "BAD"
    print(f"{status} {p} {im.size} {im.mode} png={real}")
    if not real:
        ok = False
print("ALL_OK" if ok else "FAIL")
