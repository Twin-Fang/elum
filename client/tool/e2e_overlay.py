#!/usr/bin/env python3
"""실기기 캡처를 **시안 위에 겹쳐** 어긋난 자리를 붉게 칠한다.

    python3 tool/e2e_overlay.py guardian_home            # 시안 위에 두 기기
    python3 tool/e2e_overlay.py guardian_home ios        # 시안 위에 iOS 만
    python3 tool/e2e_overlay.py guardian_home vs         # iOS 위에 안드로이드

결과: e2e/shots/overlay/<flow>_<platform>.png

## ⚠️ 시안 겹치기는 **데이터가 같을 때만** 쓸모 있다

시안은 `스스로 옷을 입어요` 를 그려 뒀는데 실계정에는 `센터에 갈 준비를 해요` 가
들어 있다. 목록 화면을 겹치면 **붉은 것의 대부분이 데이터 차이**라 자리가
어긋난 것인지 글자가 다른 것인지 갈라지지 않는다.

- **데이터가 안 바뀌는 화면**(로그인·역할 선택·온보딩)은 시안 겹치기가 바로 먹힌다.
- **목록·카드처럼 내용이 실데이터인 화면**은 `vs` 로 **iOS ↔ 안드로이드**를 겹친다.
  같은 계정이라 데이터가 같아, 남는 붉은 것이 곧 **플랫폼 차이**다.
- 시안과 자리를 맞대야 하면 골든 대조(`tool/figma_diff.py`)를 쓴다. 그쪽은 시험
  데이터가 시안과 같게 맞춰져 있다.

## 나란히 보는 것(`e2e_compare.py`)과 무엇이 다른가

나란히 두면 **있고 없고**는 보이지만 **몇 px 어긋났는지**는 안 보인다. 겹쳐야
보인다. 실제로 로그인 부리는 나란히 봤을 때 못 잡았고 겹쳐서 잡았다 (#297).

## ⚠️ 그냥 겹치면 안 된다 — 세로를 맞춰야 한다

기기마다 상태바 높이가 다르다. 시안·iPhone 은 59, 에뮬레이터는 24다. 그대로
겹치면 안드로이드가 통째로 35 어긋나 **화면 전체가 붉어진다.**

그래서 **세로 이동량을 자동으로 찾는다.** 몇 px 씩 밀어 보며 차이가 가장 작은
자리를 고르고, 그 값을 결과에 찍는다. 찾은 이동량이 크면 그 자체가 정보다 —
상태바 차이(안드 −35쯤)면 정상이고, 그 밖이면 진짜로 밀린 것이다.

가로는 맞추지 않는다. 가로가 어긋나면 그건 정렬이 아니라 결함이다.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESIGN = (393, 852)
THRESHOLD = 24          # figma_diff.py 와 같은 기준 (채널차)
SEARCH = 60             # 세로 이동을 찾는 범위 (논리 px)
FONT = ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc', 22)


def load(path):
    """논리 크기(393×852)로 맞춰 읽는다. 기기마다 해상도가 다르다."""
    im = Image.open(path).convert('RGB')
    if im.size != DESIGN:
        im = im.resize(DESIGN, Image.LANCZOS)
    return np.asarray(im, dtype=np.int16)


def best_shift(design, shot, mask_top, mask_bottom):
    """세로로 몇 px 밀면 가장 잘 겹치는지. (이동량, 그때의 평균차)"""
    best = (0, float('inf'))
    h = DESIGN[1]
    for dy in range(-SEARCH, SEARCH + 1):
        ys, ye = mask_top, h - mask_bottom
        a = design[ys:ye]
        b = shot[ys + dy:ye + dy] if 0 <= ys + dy and ye + dy <= h else None
        if b is None or b.shape != a.shape:
            continue
        err = float(np.abs(a - b).mean())
        if err < best[1]:
            best = (dy, err)
    return best


def overlay(flow, platform, spec):
    shot_path = os.path.join(ROOT, 'e2e', 'shots', platform, f'{flow}.png')
    figma_path = os.path.normpath(os.path.join(ROOT, spec['figma']))
    if not os.path.exists(shot_path):
        print(f'  {platform}: 캡처 없음 — bash tool/e2e_shot.sh {flow} 먼저')
        return
    design, shot = load(figma_path), load(shot_path)

    mt = spec.get('mask_top', 59)
    mb = spec.get('mask_bottom', 21)
    dy, err = best_shift(design, shot, mt, mb)

    # `best_shift` 는 `shot[y+dy]` 를 `design[y]` 와 맞댔다. 그 정렬을 실제로
    # 만들려면 **반대로** 굴려야 한다 — 부호를 헷갈리면 어긋남이 두 배가 된다.
    shifted = np.roll(shot, -dy, axis=0)
    delta = np.abs(design - shifted).max(axis=2)
    delta[:mt] = 0
    if mb:
        delta[-mb:] = 0
    diff = delta > THRESHOLD
    compared = delta.size - (mt + mb) * DESIGN[0]
    pct = 100.0 * diff.sum() / max(compared, 1)

    canvas = (design * 0.35 + 255 * 0.65).astype(np.uint8)
    canvas[diff] = [255, 0, 0]
    out_im = Image.new('RGB', (DESIGN[0], DESIGN[1] + 30), (255, 255, 255))
    d = ImageDraw.Draw(out_im)
    d.text((6, 5), f'{platform}  세로 {dy:+d}  다른 픽셀 {pct:.2f}%',
           font=FONT, fill=(30, 30, 30))
    out_im.paste(Image.fromarray(canvas), (0, 30))

    out_dir = os.path.join(ROOT, 'e2e', 'shots', 'overlay')
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f'{flow}_{platform}.png')
    out_im.save(out)
    print(f'  {platform}: 세로 {dy:+d} 맞춤 · 다른 픽셀 {pct:.2f}% → {out}')


def versus(flow, spec):
    """iOS 위에 안드로이드를 겹친다. 같은 계정이라 남는 것은 플랫폼 차이뿐이다."""
    a_path = os.path.join(ROOT, 'e2e', 'shots', 'ios', f'{flow}.png')
    b_path = os.path.join(ROOT, 'e2e', 'shots', 'android', f'{flow}.png')
    for p in (a_path, b_path):
        if not os.path.exists(p):
            print(f'  vs: 캡처가 둘 다 있어야 한다 — 없는 것: {p}')
            return
    base, other = load(a_path), load(b_path)
    mt, mb = spec.get('mask_top', 59), spec.get('mask_bottom', 21)
    dy, _ = best_shift(base, other, mt, mb)
    shifted = np.roll(other, -dy, axis=0)

    delta = np.abs(base - shifted).max(axis=2)
    delta[:mt] = 0
    if mb:
        delta[-mb:] = 0
    diff = delta > THRESHOLD
    compared = delta.size - (mt + mb) * DESIGN[0]
    pct = 100.0 * diff.sum() / max(compared, 1)

    canvas = (base * 0.35 + 255 * 0.65).astype(np.uint8)
    canvas[diff] = [255, 0, 0]
    out_im = Image.new('RGB', (DESIGN[0], DESIGN[1] + 30), (255, 255, 255))
    ImageDraw.Draw(out_im).text(
        (6, 5), f'iOS ↔ Android  세로 {dy:+d}  다른 픽셀 {pct:.2f}%',
        font=FONT, fill=(30, 30, 30))
    out_im.paste(Image.fromarray(canvas), (0, 30))

    out_dir = os.path.join(ROOT, 'e2e', 'shots', 'overlay')
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f'{flow}_vs.png')
    out_im.save(out)
    print(f'  vs: 세로 {dy:+d} 맞춤 · 다른 픽셀 {pct:.2f}% → {out}')


def main():
    if len(sys.argv) < 2:
        print('사용: python3 tool/e2e_overlay.py <플로우이름> [ios|android|vs]',
              file=sys.stderr)
        return 2
    flow = sys.argv[1]
    only = sys.argv[2] if len(sys.argv) > 2 else None
    meta = json.load(open(os.path.join(ROOT, 'e2e', 'flows.json')))
    if flow not in meta:
        print(f'e2e/flows.json 에 {flow} 가 없다', file=sys.stderr)
        return 2
    print(f'▶ {flow}')
    if only == 'vs':
        versus(flow, meta[flow])
        return 0
    for platform in ('ios', 'android'):
        if only and only != platform:
            continue
        overlay(flow, platform, meta[flow])
    return 0


if __name__ == '__main__':
    sys.exit(main())
