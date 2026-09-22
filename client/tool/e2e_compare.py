#!/usr/bin/env python3
"""플로우 하나를 **시안 · iOS · 안드로이드** 세 벌로 나란히 붙인다.

    python3 tool/e2e_compare.py guardian_home

결과: e2e/shots/compare/<flow>.png

## 왜 세 벌을 같이 보나

수치(`figma_diff.py`)는 iOS 렌더 하나만 시안과 맞댄다. 실기기에서만 드러나는 것 —
글꼴 대체, 이모지 폭, 상태바 높이, 안드로이드만의 잘림 — 은 **두 기기를 같이
놓아야** 보인다. 실제로 로그인 화면 병아리 얼굴이 플랫폼마다 달라야 한다는 것을
이렇게 나란히 놓고서야 알았다 (#297).

세 벌은 **크기가 다르다.** iPhone 16 Pro 는 1206×2622, 에뮬레이터는 1080×2400,
시안 export 는 393×852 다. 가로를 맞춰 세로 비율을 지킨 채 줄인다 — 픽셀을 맞대는
것이 아니라 **사람이 눈으로 견주는** 그림이다.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILE_W = 360
GAP = 14
FONT = ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc', 24)


def design_path(spec, platform):
    """이 플랫폼이 따를 시안. 시안이 하나뿐이면 둘 다 그것을 본다.

    로그인은 시안이 **플랫폼별로 따로 나왔다** (#338). 한 장만 보면
    안드로이드는 늘 어긋난 것으로 나와 진짜 결함이 묻힌다.
    """
    fig = spec.get('figma')
    if not fig:
        return None
    if isinstance(fig, dict):
        fig = fig.get(platform)
        if not fig:
            return None
    return os.path.normpath(os.path.join(ROOT, fig))


def tile(label, path):
    """한 칸. 파일이 없으면 자리만 비워 두고 그 사실을 적는다."""
    head = 38
    if not path or not os.path.exists(path):
        t = Image.new('RGB', (TILE_W, 240), (246, 246, 246))
        d = ImageDraw.Draw(t)
        d.text((8, 8), label, font=FONT, fill=(30, 30, 30))
        d.text((8, 50), '캡처 없음', font=FONT, fill=(190, 60, 60))
        return t
    im = Image.open(path).convert('RGB')
    im = im.resize((TILE_W, round(im.height * TILE_W / im.width)), Image.LANCZOS)
    t = Image.new('RGB', (TILE_W, im.height + head), (255, 255, 255))
    d = ImageDraw.Draw(t)
    d.text((8, 8), label, font=FONT, fill=(30, 30, 30))
    t.paste(im, (0, head))
    return t


def main():
    if len(sys.argv) < 2:
        print('사용: python3 tool/e2e_compare.py <플로우이름>', file=sys.stderr)
        return 2
    flow = sys.argv[1]
    meta = json.load(open(os.path.join(ROOT, 'e2e', 'flows.json')))
    if flow not in meta:
        print(f'e2e/flows.json 에 {flow} 가 없다', file=sys.stderr)
        return 2
    spec = meta[flow]
    ios_design = design_path(spec, 'ios')
    aos_design = design_path(spec, 'android')

    # 시안이 플랫폼별로 갈린 화면은 **두 장을 다 보여준다.** 한 장만 걸면
    # 나머지 한쪽은 늘 어긋나 보여 진짜 결함이 묻힌다 (#338).
    if ios_design == aos_design:
        tiles = [tile(f"시안 {spec.get('node', '')}".strip(), ios_design)]
    else:
        tiles = [tile('시안 iOS', ios_design), tile('시안 AOS', aos_design)]
    tiles += [
        tile('iOS', os.path.join(ROOT, 'e2e', 'shots', 'ios', f'{flow}.png')),
        tile('Android', os.path.join(ROOT, 'e2e', 'shots', 'android', f'{flow}.png')),
    ]
    h = max(t.height for t in tiles)
    n = len(tiles)
    sheet = Image.new('RGB', (TILE_W * n + GAP * (n - 1), h + 40), (255, 255, 255))
    ImageDraw.Draw(sheet).text((8, 8), spec.get('title', flow), font=FONT, fill=(0, 0, 0))
    for i, t in enumerate(tiles):
        sheet.paste(t, (i * (TILE_W + GAP), 40))

    out_dir = os.path.join(ROOT, 'e2e', 'shots', 'compare')
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f'{flow}.png')
    sheet.save(out)
    print(out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
