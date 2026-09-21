#!/usr/bin/env python3
"""Figma export와 앱 렌더를 픽셀로 맞대본다.

왜 필요한가 — **눈으로는 못 잡는다.** `새로운 일과 만들기` 버튼에서 효과 네 줄 중
안쪽 세 줄이 통째로 빠진 채 배포됐는데, 전체 화면 골든을 만들어 놓고도 지나갔다.
361x68 안의 10px 안쪽 그림자는 그 크기에서 몇 픽셀이라 있으나 없으나 비슷해 보인다.
(이슈 #258)

값 단언(`expect(shadow.blur, 10)`)도 절반만 막는다. **단언하기로 생각한 것만** 지킨다.
빠뜨린 줄은 애초에 단언도 안 썼으니 아무도 세지 않는다. 그림으로 맞대야 한다.

사용:

    python3 tool/figma_diff.py \\
        --render test/goldens/figma/home_931-3896.png \\
        --design ../docs/figma/home-redesign/cmp_home_filled.png \\
        --out /tmp/diff_home.png

읽는 법 — `diff%`는 글자 안티에일리어싱 때문에 절대 0이 되지 않는다. 숫자 자체보다
**어디가 다른가**가 중요하므로, 임계를 넘은 덩어리를 좌표와 크기로 뽑아 준다.
덩어리가 글자 자리면 대개 무해하고, 덩어리가 도형·여백 자리면 실제로 틀린 것이다.
"""

import argparse
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit('PIL과 numpy가 필요하다: python3 -m pip install pillow numpy')


def load_rgb(path, size=None):
    """알파를 시안 배경 위에 합성해 RGB로 맞춘다.

    앱 렌더는 바깥 발광이 반투명으로 남고, Figma export는 배경이 합성된 채로 온다.
    그대로 빼면 발광 전체가 '다름'으로 잡혀 diff가 의미를 잃는다.
    """
    img = Image.open(path).convert('RGBA')
    if size and img.size != size:
        img = img.resize(size, Image.LANCZOS)
    bg = Image.new('RGBA', img.size, (247, 242, 239, 255))  # #F7F2EF
    return np.asarray(Image.alpha_composite(bg, img).convert('RGB'), dtype=np.int16)


def clusters(mask, min_area):
    """다른 픽셀이 뭉친 덩어리를 상자로 묶는다.

    한 픽셀씩 보고하면 안티에일리어싱 노이즈에 묻혀 못 읽는다.
    행 단위로 훑어 겹치는 상자를 합치는 정도면 사람이 읽기에 충분하다.
    """
    ys, xs = np.nonzero(mask)
    if len(ys) == 0:
        return []
    boxes = []
    for y in range(mask.shape[0]):
        row = np.nonzero(mask[y])[0]
        if len(row) == 0:
            continue
        x0, x1 = int(row.min()), int(row.max())
        if boxes and y - boxes[-1][3] <= 2:
            b = boxes[-1]
            boxes[-1] = [min(b[0], x0), b[1], max(b[2], x1), y]
        else:
            boxes.append([x0, y, x1, y])
    return [b for b in boxes if (b[2] - b[0] + 1) * (b[3] - b[1] + 1) >= min_area]


def _ink_rows(img, thr, top, bottom):
    """가로로 글자가 있는 구간을 y범위 목록으로 돌려준다."""
    dark = img.sum(axis=2) < thr
    if top:
        dark[:top] = False
    if bottom:
        dark[-bottom:] = False
    counts = dark.sum(axis=1)
    runs, start = [], None
    for y, v in enumerate(counts):
        if v > 0 and start is None:
            start = y
        elif v == 0 and start is not None:
            if y - start > 2:
                runs.append((start, y))
            start = None
    if start is not None:
        runs.append((start, len(counts)))
    return runs


def _report_rows(design, render, thr, top, bottom, scale):
    """양쪽 글줄을 순서대로 맞대 **몇 px 어긋났는지** 찍는다.

    배경이 움직이는 화면(오로라·로딩)에서는 `diff%`가 배경에 먹혀 쓸모가 없다.
    그럴 때도 **글자가 어느 높이에 있는지**는 이렇게 숫자로 볼 수 있다 —
    실제로 추가질문에서 제목이 넷째 줄까지 꺾여 있던 것을 이 방법으로 찾았다.
    """
    d = _ink_rows(design, thr, top, bottom)
    r = _ink_rows(render, thr, top, bottom)
    print(f'글줄 (밝기합 {thr} 미만을 글자로 본다 · 논리 px)')
    print(f'{"#":>3}  {"시안":>12}  {"앱":>12}  어긋남')
    for i in range(max(len(d), len(r))):
        dv = d[i] if i < len(d) else None
        rv = r[i] if i < len(r) else None
        def fmt(v):
            return f'{round(v[0]/scale)}~{round(v[1]/scale)}' if v else '—'
        gap = ''
        if dv and rv:
            off = round((rv[0] - dv[0]) / scale)
            gap = '맞음' if abs(off) <= 1 else f'{off:+d}'
        else:
            gap = '한쪽에만 있다'
        print(f'{i + 1:>3}  {fmt(dv):>12}  {fmt(rv):>12}  {gap}')
    if len(d) != len(r):
        print(f'\n⚠️ 줄 개수가 다르다 — 시안 {len(d)}, 앱 {len(r)}. '
              f'글자가 한 줄 더 꺾였거나 요소가 빠졌다.')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--render', required=True, help='앱이 그린 PNG')
    ap.add_argument('--design', required=True, help='Figma export PNG')
    ap.add_argument('--out', help='차이를 칠한 PNG를 저장할 경로')
    ap.add_argument('--threshold', type=int, default=24,
                    help='채널당 이 값을 넘어야 "다르다"로 본다 (기본 24)')
    # **기본값이 0이면 안 된다.** 앱은 시계·배터리·홈 인디케이터를 그리지 않는데
    # 시안에는 그려져 있어, 가리지 않으면 그 띠가 통째로 "다름"으로 잡힌다.
    # 인자를 깜빡한 채 돌려서 모든 수치가 부풀어 있었다 — 기본값을 실측으로 둔다.
    #
    # 단위는 **논리 픽셀(852 높이 기준)**이다. 시안 export 는 2x·3x 로 나오므로
    # 아래에서 비교 크기에 맞춰 환산한다. 겹치는 화면이 없으면 0으로 끌 수 있다.
    ap.add_argument('--mask-top', type=int, default=59,
                    help='위에서 이만큼(논리px)을 비교에서 뺀다 — 상태바 (기본 59)')
    ap.add_argument('--mask-bottom', type=int, default=21,
                    help='아래에서 이만큼(논리px)을 뺀다 — 홈 인디케이터 (기본 21)')
    ap.add_argument('--design-height', type=int, default=852,
                    help='시안 프레임의 논리 높이 (기본 852)')
    ap.add_argument('--min-area', type=int, default=200,
                    help='이 넓이 미만 덩어리는 보고하지 않는다')
    # 오로라처럼 배경이 통째로 움직이는 화면은 diff%가 배경에 먹힌다.
    # 그럴 때 **글줄 y좌표**를 양쪽에서 뽑아 맞대면 자리는 정확히 볼 수 있다.
    ap.add_argument('--rows', action='store_true',
                    help='글줄 y좌표를 양쪽에서 뽑아 맞대본다 (배경이 움직이는 화면용)')
    ap.add_argument('--row-threshold', type=int, default=470,
                    help='--rows 에서 "글자"로 볼 밝기 합 (기본 470)')
    args = ap.parse_args()

    design = load_rgb(args.design)
    render = load_rgb(args.render, size=(design.shape[1], design.shape[0]))

    delta = np.abs(design - render).max(axis=2)

    # 논리 px -> 실제 비교 px. 시안이 2x면 59 가 118 이 된다.
    scale = design.shape[0] / max(args.design_height, 1)
    top = int(round(args.mask_top * scale))
    bottom = int(round(args.mask_bottom * scale))
    if top:
        delta[:top] = 0
    if bottom:
        delta[-bottom:] = 0

    mask = delta > args.threshold
    compared = delta.size - (top + bottom) * delta.shape[1]
    pct = 100.0 * mask.sum() / max(compared, 1)

    print(f'비교 크기   {design.shape[1]}x{design.shape[0]}')
    print(f'임계        채널차 {args.threshold} 초과')
    if top or bottom:
        print(f'가린 띠     위 {top}px · 아래 {bottom}px (앱이 그리지 않는 자리)')
    print(f'다른 픽셀   {mask.sum():,} / {compared:,}  ({pct:.2f}%)')
    print(f'최대 채널차 {int(delta.max())}')
    print()

    found = clusters(mask, args.min_area)
    if not found:
        print('임계를 넘는 덩어리 없음')
    else:
        print(f'다른 덩어리 {len(found)}개 (넓이 {args.min_area} 이상, 위에서부터)')
        print(f'{"y범위":>12}  {"x범위":>12}  {"크기":>10}  평균차')
        for x0, y0, x1, y1 in found:
            region = delta[y0:y1 + 1, x0:x1 + 1]
            hot = region[region > args.threshold]
            print(f'{y0:5}~{y1:<6}  {x0:5}~{x1:<6}  '
                  f'{x1 - x0 + 1:4}x{y1 - y0 + 1:<5}  {hot.mean():.0f}')

    if args.rows:
        print()
        _report_rows(design, render, args.row_threshold, top, bottom, scale)

    if args.out:
        # 원본을 흐리게 깔고 다른 자리만 붉게 칠한다 — 어디가 틀렸는지 바로 보인다.
        canvas = (design * 0.35 + 255 * 0.65).astype(np.uint8)
        canvas[mask] = [255, 0, 0]
        Image.fromarray(canvas).save(args.out)
        print(f'\n차이 그림   {args.out}')

    return 0


if __name__ == '__main__':
    sys.exit(main())
