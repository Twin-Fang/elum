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


def _components(mask, min_area):
    """다른 픽셀을 **진짜 연결 덩어리**로 묶는다 (4-이웃).

    [clusters]는 행 단위로 겹치면 합쳐서 사람이 읽기 좋은 상자를 만든다. 대신 한 행에
    글자와 그림이 같이 있으면 둘이 한 상자가 된다. 색 덩어리인지 글자 뭉개짐인지
    가리려면 그 둘이 갈라져 있어야 해서 따로 센다.

    행마다 연속 구간(run)을 찾아 위 행과 겹치는 것끼리 union-find 로 잇는다.
    마스크 픽셀만 훑으므로 화면 하나에 수십 ms면 끝난다.
    """
    h, w = mask.shape
    parent = {}

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    prev_runs = []
    runs = []          # (label, y, x0, x1)
    for y in range(h):
        xs = np.nonzero(mask[y])[0]
        if len(xs) == 0:
            prev_runs = []
            continue
        cur = []
        start = xs[0]
        for i in range(1, len(xs) + 1):
            if i == len(xs) or xs[i] != xs[i - 1] + 1:
                x0, x1 = int(start), int(xs[i - 1])
                label = len(runs)
                parent[label] = label
                for plabel, px0, px1 in prev_runs:
                    if px0 <= x1 and x0 <= px1:      # 위 행과 가로가 겹친다
                        union(plabel, label)
                runs.append((label, y, x0, x1))
                cur.append((label, x0, x1))
                if i < len(xs):
                    start = xs[i]
        prev_runs = cur

    agg = {}
    for label, y, x0, x1 in runs:
        root = find(label)
        a = agg.get(root)
        n = x1 - x0 + 1
        if a is None:
            agg[root] = [x0, y, x1, y, n]
        else:
            a[0] = min(a[0], x0); a[2] = max(a[2], x1)
            a[3] = y; a[4] += n
    return [v for v in agg.values() if v[4] >= min_area]


def _edge_density(img, thr):
    """가로로 이웃과 크게 다른 픽셀의 비율. 글자가 있으면 높고, 색면이면 0에 가깝다."""
    if img.shape[1] < 2:
        return 0.0
    d = np.abs(img[:, 1:].astype(np.int16) - img[:, :-1]).max(axis=2)
    return float((d > thr).mean())


def _report_solids(design, render, mask, thr, min_area):
    """**한쪽에만 있는 덩어리**를 찾아낸다.

    글자 뭉개짐은 양쪽 다 글자가 있어서 가장자리가 촘촘하다. 반대로 한쪽에만 있는
    그림 조각은 양쪽 다 매끈한데 색만 다르다 — 그 차이로 가른다.

    **채움률도 본다.** 그림이 1px만 밀려도 실루엣을 따라 색이 확 바뀌어 위 조건을
    통과한다. 그런 것은 가는 곡선이라 상자 안이 거의 비어 있고(10% 안팎),
    한쪽에만 있는 조각은 상자를 꽉 채운다. 부리는 0.69, 1px 밀린 포포는 0.09였다.

    로그인 화면이 1.66%까지 내려간 뒤에도 병아리 부리가 카카오 버튼 아래로 13
    삐져나와 있었다. 수치로는 이미 "글자만 남은" 화면이라 열어보지 않았다 (#297).
    """
    found = _components(mask, min_area)
    hits = []
    for x0, y0, x1, y1, area in found:
        dcrop = design[y0:y1 + 1, x0:x1 + 1]
        rcrop = render[y0:y1 + 1, x0:x1 + 1]
        de, re_ = _edge_density(dcrop, thr), _edge_density(rcrop, thr)
        sub = mask[y0:y1 + 1, x0:x1 + 1]
        dmean = dcrop[sub].mean(axis=0)
        rmean = rcrop[sub].mean(axis=0)
        gap = float(np.abs(dmean - rmean).max())
        fill = area / float((x1 - x0 + 1) * (y1 - y0 + 1))
        if de < 0.10 and re_ < 0.10 and gap > 40 and fill >= 0.30:
            hits.append((area, x0, y0, x1, y1, dmean, rmean, gap, fill))

    if not hits:
        print('한쪽에만 있는 덩어리: 없음')
        return
    hits.sort(reverse=True)
    print(f'⚠️ 한쪽에만 있는 덩어리 {len(hits)}개 — 글자가 아니라 **색면**이 다르다')
    print(f'{"y범위":>12}  {"x범위":>12}  {"넓이":>7}  {"시안색":>15}  {"앱색":>15}  '
          f'색차  채움률')
    for area, x0, y0, x1, y1, dmean, rmean, gap, fill in hits:
        d_ = ','.join(f'{int(v):3}' for v in dmean)
        r_ = ','.join(f'{int(v):3}' for v in rmean)
        print(f'{y0:5}~{y1:<6}  {x0:5}~{x1:<6}  {area:7}  {d_:>15}  {r_:>15}  '
              f'{gap:4.0f}  {fill:.2f}')


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


def _match_rows(d, r, scale, tol):
    """글줄을 **겹치는 것끼리** 짝짓는다 (순서는 지킨다).

    순서대로 1:1로 맞대면 한 줄만 어긋나도 그 뒤가 통째로 밀려 "백 몇 px 어긋남"
    같은 헛것이 줄줄이 나온다. 실제로 보호자 홈에서 글줄 둘이 붙어 하나로 세어진
    것뿐인데 14 대 12로 보고돼 요소가 빠진 줄 알았다 (#297).

    그래서 정렬 문제로 푼다. 짝을 최대한 많이 맺되, 같은 수면 어긋남 합이 작은
    쪽을 고른다. [tol](논리 px)보다 멀면 아예 짝으로 보지 않는다.
    """
    n, m = len(d), len(r)
    INF = float('inf')
    # dp[i][j] = (못 맺은 줄 수, 어긋남 합) — 사전식으로 작은 것이 낫다
    dp = [[(INF, INF)] * (m + 1) for _ in range(n + 1)]
    back = [[None] * (m + 1) for _ in range(n + 1)]
    dp[0][0] = (0, 0)
    for i in range(n + 1):
        for j in range(m + 1):
            cur = dp[i][j]
            if cur[0] == INF:
                continue
            if i < n:                                   # 시안 줄을 못 맺고 넘긴다
                cand = (cur[0] + 1, cur[1])
                if cand < dp[i + 1][j]:
                    dp[i + 1][j], back[i + 1][j] = cand, (i, j, 'd')
            if j < m:                                   # 앱 줄을 못 맺고 넘긴다
                cand = (cur[0] + 1, cur[1])
                if cand < dp[i][j + 1]:
                    dp[i][j + 1], back[i][j + 1] = cand, (i, j, 'r')
            if i < n and j < m:
                off = abs((r[j][0] - d[i][0]) / scale)
                if off <= tol:
                    cand = (cur[0], cur[1] + off)
                    if cand < dp[i + 1][j + 1]:
                        dp[i + 1][j + 1], back[i + 1][j + 1] = cand, (i, j, 'm')
    pairs, i, j = [], n, m
    while (i, j) != (0, 0):
        pi, pj, how = back[i][j]
        if how == 'm':
            pairs.append((d[pi], r[pj]))
        elif how == 'd':
            pairs.append((d[pi], None))
        else:
            pairs.append((None, r[pj]))
        i, j = pi, pj
    pairs.reverse()
    return pairs


def _report_rows(design, render, thr, top, bottom, scale, tol=40):
    """양쪽 글줄을 맞대 **몇 px 어긋났는지** 찍는다.

    배경이 움직이는 화면(오로라·로딩)에서는 `diff%`가 배경에 먹혀 쓸모가 없다.
    그럴 때도 **글자가 어느 높이에 있는지**는 이렇게 숫자로 볼 수 있다 —
    실제로 추가질문에서 제목이 넷째 줄까지 꺾여 있던 것을 이 방법으로 찾았다.
    """
    d = _ink_rows(design, thr, top, bottom)
    r = _ink_rows(render, thr, top, bottom)
    pairs = _match_rows(d, r, scale, tol)
    print(f'글줄 (밝기합 {thr} 미만을 글자로 본다 · 논리 px · {tol} 넘게 떨어지면 짝으로 안 본다)')
    print(f'{"#":>3}  {"시안":>12}  {"앱":>12}  어긋남')

    def fmt(v):
        return f'{round(v[0] / scale)}~{round(v[1] / scale)}' if v else '—'

    lonely = 0
    for i, (dv, rv) in enumerate(pairs):
        if dv and rv:
            off = round((rv[0] - dv[0]) / scale)
            gap = '맞음' if abs(off) <= 1 else f'{off:+d}'
        else:
            gap = '앱에만 있다' if rv else '시안에만 있다'
            lonely += 1
        print(f'{i + 1:>3}  {fmt(dv):>12}  {fmt(rv):>12}  {gap}')
    if lonely:
        print(f'\n⚠️ 짝이 없는 글줄 {lonely}개. 글자가 한 줄 더 꺾였거나 '
              f'요소가 빠졌거나, 붙어 있어 한 줄로 세어진 것이다.')


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
    ap.add_argument('--solids', action='store_true',
                    help='한쪽에만 있는 색 덩어리를 찾는다 (글자 뭉개짐과 구분)')
    ap.add_argument('--row-tolerance', type=int, default=40,
                    help='--rows 에서 짝으로 볼 최대 어긋남 (기본 40)')
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

    if args.solids:
        print()
        _report_solids(design, render, mask, args.threshold, args.min_area)

    if args.rows:
        print()
        _report_rows(design, render, args.row_threshold, top, bottom, scale,
                      args.row_tolerance)

    if args.out:
        # 원본을 흐리게 깔고 다른 자리만 붉게 칠한다 — 어디가 틀렸는지 바로 보인다.
        canvas = (design * 0.35 + 255 * 0.65).astype(np.uint8)
        canvas[mask] = [255, 0, 0]
        Image.fromarray(canvas).save(args.out)
        print(f'\n차이 그림   {args.out}')

    return 0


if __name__ == '__main__':
    sys.exit(main())
