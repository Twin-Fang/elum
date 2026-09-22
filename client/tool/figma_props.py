#!/usr/bin/env python3
"""시안의 **속성**을 렌더에 직접 묻는다 — 퍼센트가 아니라 값으로 (이슈 #344).

## 왜 만들었나

일과 시트 상단 모서리가 각진 채 배포됐다. 픽셀 대조 도구(`figma_diff.py`)는
그 자리를 **리포트했다.**

```
476~519   0~785   786x44   평균차 77     ← 이게 그 모서리다
다른 픽셀  66,849 / 1,213,584  (5.51%)
```

그런데 22개 덩어리 중 한 줄이었고, 좌표와 평균차만 있을 뿐 **무엇이 어떻게 다른지가
없었다.** 사람은 22줄짜리 좌표표를 읽지 않는다.

물어야 할 것은 이것이다 — **곡선이 맞나, 색이 맞나, 이펙트가 맞나.**
이 도구는 Figma가 선언한 값을 들고 와서 렌더의 그 자리를 직접 찍어 본다.
결과는 좌표가 아니라 문장이다.

```
⚠️ 모서리 각짐   헤더배경 980:4891  좌상 r=20 → 렌더가 면 색으로 차 있다
```

## 쓰는 법

    export FIGMA_TOKEN=...            # 또는 client/.env 의 FIGMA_TOKEN
    python3 client/tool/figma_props.py \\
        --node 956:4084 \\
        --render client/test/figma/sheet_956-4084.png

    # 토큰 없이 — 받아 둔 덤프로
    python3 client/tool/figma_props.py --dump /tmp/sheet.json --render ...

    # 도구 자체가 맞는지 (네트워크 없이 돈다)
    python3 client/tool/figma_props.py --self-test

종료 코드 — 0 이상 없음 / 1 경고만 / 2 결함.
**CI 가 붙잡을 수 있게** 심각도를 코드로 낸다.

## 한계를 먼저 적는다

렌더는 PNG다. 그러니 **화면에 그려지는 것만** 물을 수 있다 — 면 색, 모서리 곡선,
그림자, 경계 위치. 글꼴 이름·자간·오토레이아웃 간격처럼 그림으로 드러나지 않는 것은
여기서 못 잡는다. 그건 위젯 테스트가 값으로 단언할 몫이다.

대신 **여기서 잡는 것들은 위젯 테스트가 거의 못 잡는다.** `clipBehavior` 를 안 줘서
자식이 부모의 둥근 모서리를 덮는 것 같은 결함은 위젯 트리에는 아무 이상이 없다.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
import urllib.request

try:
    import numpy as np
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit('PIL과 numpy가 필요하다: python3 -m pip install pillow numpy')

FILE_KEY = 'VSmGuv1iuOpLZmp6QeBHWr'

# 심각도 — 종료 코드로도 쓴다.
OK, WARN, ERROR = 0, 1, 2

# 색 거리는 **유클리드**로 잰다. 채널 최대 차로 재면 이 앱에서 못 쓴다 —
# 시트 흰색(#FFFFFF)과 배경(#F7F2EF)의 채널 최대 차가 16밖에 안 되어서,
# "면과 배경이 구분된다"는 문턱을 그 위에 두면 **정작 봐야 할 시트를 건너뛴다.**
# 유클리드로는 22.1이라 안전하게 갈린다.
SAME = 10          # 이만큼 가까우면 같은 색으로 본다
FILL_SAME = 14     # 면 색은 테마 토큰과 시안이 1~2 어긋나는 일이 있어 조금 느슨하게
DISTINCT = 18      # 면과 배경이 이보다 가까우면 **판정하지 않는다**


# --------------------------------------------------------------------------
# Figma 에서 속성을 뽑는다
# --------------------------------------------------------------------------

def read_token() -> str | None:
    """토큰을 찾는다. **저장소에 적지 않는다** — 환경변수나 무시되는 파일에서만 읽는다."""
    if os.environ.get('FIGMA_TOKEN'):
        return os.environ['FIGMA_TOKEN'].strip()
    here = pathlib.Path(__file__).resolve().parent.parent  # client/
    for candidate in (here / '.env', pathlib.Path.home() / '.figma_token'):
        if not candidate.exists():
            continue
        text = candidate.read_text(encoding='utf-8')
        if candidate.name == '.figma_token':
            return text.strip() or None
        for line in text.splitlines():
            if line.startswith('FIGMA_TOKEN'):
                return line.split('=', 1)[1].strip().strip('"\'')
    return None


def fetch_node(node_id: str, token: str) -> dict:
    url = f'https://api.figma.com/v1/files/{FILE_KEY}/nodes?ids={node_id}'
    req = urllib.request.Request(url, headers={'X-Figma-Token': token})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.load(resp)
    nodes = data.get('nodes') or {}
    if node_id not in nodes:
        raise SystemExit(f'노드를 찾지 못했다: {node_id}')
    return nodes[node_id]['document']


def solid_fill(node: dict):
    """맨 위의 보이는 단색 채움을 (rgb, alpha) 로 돌려준다. 없으면 None.

    그라디언트·이미지 채움은 **여기서 다루지 않는다** — 한 점을 찍어 비교할 수
    없기 때문이다. 없는 것을 있는 척 검사하면 오탐만 쌓인다.
    """
    for fill in reversed(node.get('fills') or []):
        if fill.get('visible') is False:
            continue
        if fill.get('type') != 'SOLID':
            return None  # 맨 위가 단색이 아니면 이 노드는 색 검사를 건너뛴다
        col = fill['color']
        alpha = fill.get('opacity', col.get('a', 1.0)) * node.get('opacity', 1.0)
        return (
            round(col['r'] * 255),
            round(col['g'] * 255),
            round(col['b'] * 255),
        ), alpha
    return None


def radii_of(node: dict) -> list[float]:
    """모서리 반지름 네 개 [좌상, 우상, 우하, 좌하]."""
    rr = node.get('rectangleCornerRadii')
    if rr and len(rr) == 4:
        return [float(v) for v in rr]
    r = float(node.get('cornerRadius') or 0)
    return [r, r, r, r]


# 면으로 볼 수 있는 타입. **꼭 필요한 제한이다** —
# VECTOR·ELLIPSE·STAR 는 채움이 바운딩박스를 다 덮지 않아서, 가운데를 찍으면
# 도형이 아니라 뒤에 있는 것이 나온다. 처음엔 다 넣었다가 아이콘마다 "면 색 다름"이
# 쏟아졌다. 오탐이 42건이면 아무도 안 읽는다 — 그게 이 이슈의 출발점이었다.
FACE_TYPES = {'RECTANGLE', 'FRAME', 'COMPONENT', 'INSTANCE'}


def collect_boxes(root: dict, origin: tuple[float, float]):
    """검사할 '면'과, 그 위에 덮이는 '가림막'을 함께 모은다.

    ## 가림막이 왜 필요한가

    Figma 는 **나중에 나오는 형제가 위에 그려진다.** 바텀시트 시안에는 화면 전체를
    덮는 `Scrim`(검정 50%)이 있어서, 그 아래 홈 화면의 면들은 렌더에서 **어두워진
    색**으로 나온다. 가림막을 모르면 그 면들이 전부 "면 색 다름"으로 잡힌다.

    자식도 같은 이야기다. 부모 면 한가운데를 찍으면 자식이 덮고 있는 게 정상이다.
    그래서 **문서 순서(그리는 순서)를 들고 다니며** 표본 자리마다
    "나보다 나중에 그려지는 것이 여기를 덮고 있나"를 묻는다.
    """
    boxes: list[dict] = []
    occluders: list[tuple] = []   # (order, x, y, w, h)
    ox, oy = origin
    order = 0

    def walk(node: dict, hidden: bool):
        nonlocal order
        hidden = hidden or node.get('visible') is False
        bb = node.get('absoluteBoundingBox')
        order += 1
        mine = order

        if bb and not hidden:
            x, y = bb['x'] - ox, bb['y'] - oy
            w, h = bb.get('width') or 0, bb.get('height') or 0
            fill = solid_fill(node)

            # 가림막은 **타입을 가리지 않는다.** 아이콘이든 도형이든 덮으면 덮는 것이다.
            # 다만 거의 투명한 것은 아래 색을 바꾸지 못하므로 뺀다.
            if node.get('fills') and w > 0 and h > 0:
                visible_fill = any(f.get('visible') is not False
                                   for f in node['fills'])
                alpha = (fill[1] if fill else 1.0)
                if visible_fill and alpha >= 0.2:
                    occluders.append((mine, x, y, w, h))

            if (fill and node.get('type') in FACE_TYPES
                    and w >= 12 and h >= 12):
                boxes.append({
                    'order': mine,
                    'id': node.get('id', ''),
                    'name': node.get('name', '')[:24],
                    'x': x, 'y': y, 'w': w, 'h': h,
                    'fill': fill[0],
                    'alpha': fill[1],
                    'radii': radii_of(node),
                    # 안쪽 선은 면을 그만큼 갉아먹는다 — 경계 판정에서 빼 준다.
                    'stroke': float(node.get('strokeWeight') or 0),
                    'effects': [
                        e for e in (node.get('effects') or [])
                        if e.get('visible') is not False
                    ],
                })

        for kid in node.get('children') or []:
            walk(kid, hidden)

    walk(root, False)
    return boxes, occluders


def make_visible_fn(occluders):
    """`(점, 내 순서)` 가 가려지지 않았는지 묻는 함수를 만든다."""
    def visible(point, order):
        px, py = point
        for o_order, x, y, w, h in occluders:
            if o_order <= order:
                continue
            if x <= px <= x + w and y <= py <= y + h:
                return False
        return True
    return visible


# --------------------------------------------------------------------------
# 렌더에 묻는다
# --------------------------------------------------------------------------

def dist(a, b) -> float:
    """두 색 사이 유클리드 거리."""
    return sum((int(a[i]) - int(b[i])) ** 2 for i in range(3)) ** 0.5


def nearer(got, face, behind) -> str:
    """찍은 색이 **면 쪽인가 배경 쪽인가.**

    절대 문턱 하나로 "면 색이다/아니다"를 가르면 흰색과 크림색처럼 가까운 짝에서
    둘 다 통과하거나 둘 다 떨어진다. 둘 중 **가까운 쪽**을 고르면 그 문제가 없다.
    """
    return 'face' if dist(got, face) <= dist(got, behind) else 'behind' 


def over(fg, alpha, bg):
    """반투명 채움을 배경 위에 얹었을 때의 색."""
    return tuple(round(fg[i] * alpha + bg[i] * (1 - alpha)) for i in range(3))


class Render:
    """렌더 PNG. 화면 밖을 찍으면 None 을 준다 — 예외로 멈추지 않는다."""

    def __init__(self, path):
        img = Image.open(path).convert('RGBA')
        bg = Image.new('RGBA', img.size, (255, 255, 255, 255))
        self.a = np.asarray(Image.alpha_composite(bg, img).convert('RGB'), dtype=np.int16)
        self.h, self.w = self.a.shape[:2]

    def at(self, x, y):
        x, y = int(round(x)), int(round(y))
        if not (0 <= x < self.w and 0 <= y < self.h):
            return None
        return tuple(int(v) for v in self.a[y, x])

    def median(self, points):
        got = [self.at(*p) for p in points]
        got = [g for g in got if g is not None]
        if not got:
            return None
        arr = np.array(got)
        return tuple(int(v) for v in np.median(arr, axis=0))


def finding(level, kind, box, text):
    return {
        'level': level,
        'kind': kind,
        'name': box['name'],
        'id': box['id'],
        'rect': f"{round(box['w'])}x{round(box['h'])} @{round(box['x'])},{round(box['y'])}",
        'text': text,
    }


def _free_points(box, visible):
    """면 색을 찍을 자리 — **나중에 그려지는 것이 덮지 않은 곳만** 고른다."""
    x, y, w, h = box['x'], box['y'], box['w'], box['h']
    pad = max(3, min(w, h) * 0.1)
    cand = []
    for fx in (0.12, 0.3, 0.5, 0.7, 0.88):
        for fy in (0.12, 0.3, 0.5, 0.7, 0.88):
            px = x + min(max(pad, w * fx), w - pad)
            py = y + min(max(pad, h * fy), h - pad)
            if visible((px, py), box['order']):
                cand.append((px, py))
    return cand


def _outside(box, render, corner=None):
    """상자 **바깥** 색. 모서리가 둥근지 판단하려면 뒤에 뭐가 있는지 알아야 한다."""
    x, y, w, h = box['x'], box['y'], box['w'], box['h']
    off = 4
    if corner == 'tl':
        pts = [(x - off, y - off), (x - off, y + 2), (x + 2, y - off)]
    elif corner == 'tr':
        pts = [(x + w + off, y - off), (x + w + off, y + 2), (x + w - 2, y - off)]
    elif corner == 'br':
        pts = [(x + w + off, y + h + off), (x + w + off, y + h - 2), (x + w - 2, y + h + off)]
    elif corner == 'bl':
        pts = [(x - off, y + h + off), (x - off, y + h - 2), (x + 2, y + h + off)]
    else:
        pts = [(x - off, y + h / 2), (x + w + off, y + h / 2),
               (x + w / 2, y - off), (x + w / 2, y + h + off)]
    return render.median(pts)


def _backdrop_uniform(box, render) -> bool:
    """상자 **뒤가 한 가지 색인가.**

    반투명 면은 뒤에 있는 것에 따라 찍히는 색이 달라진다. 로그인 화면의
    `최근 로그인` 알약(#FFFADC 50%)이 그렇다 — 위쪽은 병아리 그림 위에, 아래쪽은
    카카오 버튼 위에 얹혀 **한 알약 안에서 색이 두 가지**다. 기대값 하나로
    맞대면 멀쩡한 것을 틀렸다고 말한다(실제로 그랬다).

    뒤가 고르지 않으면 값으로 묻는 검사를 건너뛴다.
    """
    x, y, w, h = box['x'], box['y'], box['w'], box['h']
    off = 4
    pts = [(x - off, y + h / 2), (x + w + off, y + h / 2),
           (x + w / 2, y - off), (x + w / 2, y + h + off)]
    got = [render.at(*p) for p in pts]
    got = [g for g in got if g is not None]
    if len(got) < 2:
        return False
    return max(dist(a, b) for a in got for b in got) <= DISTINCT


def check_fill(box, render, visible, findings):
    """면 색이 시안과 같은가. 다르면 그 자리에서 한 문장으로 말한다."""
    pts = _free_points(box, visible)
    # 표본이 두 점도 안 남으면 그 면은 거의 다 덮여 있다 — 판정하지 않는다.
    if len(pts) < 2:
        return None
    got = render.median(pts)
    if got is None:
        return None

    want = box['fill']
    if box['alpha'] < 0.99:
        # 뒤가 고르지 않으면 기대값이 하나로 안 나온다 — 묻지 않는다.
        if not _backdrop_uniform(box, render):
            return None
        behind = _outside(box, render)
        if behind is None:
            return None
        want = over(box['fill'], box['alpha'], behind)

    if dist(got, want) > FILL_SAME:
        findings.append(finding(
            ERROR, '면 색 다름', box,
            f"시안 #{'%02X%02X%02X' % want} → 렌더 #{'%02X%02X%02X' % got}",
        ))
        return None
    return want


def check_corners(box, render, face, visible, findings):
    """**이번 사고를 잡는 검사.** 둥글어야 할 자리가 채워져 있는가.

    ## 탐침을 어디에 둘 것인가 — 이 계산을 틀리면 도구가 조용히 거짓말한다

    반지름 r 의 모서리는 꼭짓점에서 (r, r) 떨어진 곳을 중심으로 한 원호다.
    꼭짓점에서 대각선으로 d 들어간 점 (d, d) 가 **원호 바깥**일 조건은

        (r-d)² + (r-d)² > r²   →   d < r(1 - 1/√2) ≈ r × 0.293

    처음 시제품은 `r × 0.3` 을 썼다. **0.293 을 아슬아슬하게 넘는 값이라
    탐침이 곡선 안쪽에 들어간다** — 둥근 렌더를 각졌다고 보고했다.
    그래서 0.10·0.16·0.22 세 자리를 찍어 가운데값을 쓴다. r=20 에서 곡선
    바깥으로 2px 이상 떨어져 안티에일리어싱에도 흔들리지 않는다.

    면과 배경이 비슷하면 아예 묻지 않는다 — 픽셀로 구분할 수 없는 것을
    "이상 없음"이라고 말하면 도구를 믿을 수 없게 된다.
    """
    if face is None:
        return
    names = {'tl': '좌상', 'tr': '우상', 'br': '우하', 'bl': '좌하'}
    x, y, w, h = box['x'], box['y'], box['w'], box['h']

    for corner, r in zip(('tl', 'tr', 'br', 'bl'), box['radii']):
        # r 이 작으면 안티에일리어싱이 곡선보다 굵어 판정할 수 없다.
        if r < 6:
            continue
        behind = _outside(box, render, corner)
        if behind is None or dist(face, behind) < DISTINCT:
            continue

        probes = []
        for frac in (0.10, 0.16, 0.22):
            d = max(1.0, r * frac)
            probes.append({
                'tl': (x + d, y + d),
                'tr': (x + w - d, y + d),
                'br': (x + w - d, y + h - d),
                'bl': (x + d, y + h - d),
            }[corner])
        probes = [p for p in probes if visible(p, box['order'])]
        got = render.median(probes) if probes else None
        if got is None:
            continue

        if nearer(got, face, behind) == 'face':
            findings.append(finding(
                ERROR, '모서리 각짐', box,
                f"{names[corner]} r={round(r)} → 렌더가 면 색으로 차 있다",
            ))


def check_square_corners(box, render, face, visible, findings):
    """반대 방향 — 각져야 하는데 둥글다.

    시안이 r=0 인데 렌더가 깎여 있으면 컴포넌트를 잘못 가져다 쓴 것이다.
    """
    if face is None:
        return
    names = {'tl': '좌상', 'tr': '우상', 'br': '우하', 'bl': '좌하'}
    x, y, w, h = box['x'], box['y'], box['w'], box['h']
    if min(w, h) < 24:
        return

    for corner, r in zip(('tl', 'tr', 'br', 'bl'), box['radii']):
        if r > 0.5:
            continue
        probe = {
            'tl': (x + 1.5, y + 1.5),
            'tr': (x + w - 1.5, y + 1.5),
            'br': (x + w - 1.5, y + h - 1.5),
            'bl': (x + 1.5, y + h - 1.5),
        }[corner]
        behind = _outside(box, render, corner)
        got = render.at(*probe) if visible(probe, box['order']) else None
        if got is None or behind is None or dist(face, behind) < DISTINCT:
            continue
        # 모서리가 배경 쪽으로 기울어 있으면 깎인 것이다.
        if nearer(got, face, behind) == 'behind':
            findings.append(finding(
                WARN, '모서리 과도함', box,
                f"{names[corner]} 시안 r=0 인데 렌더가 깎여 있다",
            ))


def check_shadows(box, render, face, visible, findings):
    """그림자가 실제로 그려졌는가.

    `figma_diff.py` 주석이 적어 둔 사고가 이것이다 — 361×68 안의 10px 안쪽 그림자
    **세 줄이 통째로 빠진 채** 배포됐는데 골든도 눈도 못 잡았다. 값 단언도
    "단언하기로 생각한 것만" 지킨다. 여기서는 **시안이 선언한 그림자 목록을
    그대로 들고 와** 하나씩 그 자리를 찍는다.
    """
    if face is None:
        return
    x, y, w, h = box['x'], box['y'], box['w'], box['h']

    for eff in box['effects']:
        kind = eff.get('type')
        if kind not in ('DROP_SHADOW', 'INNER_SHADOW'):
            continue
        col = eff.get('color') or {}
        alpha = col.get('a', 0)
        radius = eff.get('radius', 0)
        off = eff.get('offset') or {'x': 0, 'y': 0}
        # 옅거나 아주 좁은 그림자는 1배 렌더에서 판정할 수 없다.
        if alpha < 0.12 or (radius < 3 and abs(off['x']) < 2 and abs(off['y']) < 2):
            continue

        shadow = (round(col.get('r', 0) * 255), round(col.get('g', 0) * 255),
                  round(col.get('b', 0) * 255))

        if kind == 'INNER_SHADOW':
            # 안쪽 그림자는 **면 안쪽 가장자리**를 물들인다.
            depth = max(2, min(radius * 0.5, min(w, h) * 0.3))
            pts = [(x + w / 2, y + depth), (x + w / 2, y + h - depth),
                   (x + depth, y + h / 2), (x + w - depth, y + h / 2)]
            pts = [p for p in pts if visible(p, box['order'])]
            got = render.median(pts) if pts else None
            if got is None:
                continue
            # 그림자가 있으면 면보다 그림자 색 쪽으로 기울어 있어야 한다.
            if dist(got, face) <= 3 and dist(face, shadow) > DISTINCT:
                findings.append(finding(
                    WARN, '안쪽 그림자 없음', box,
                    f"블러 {round(radius)} 알파 {alpha:.2f} 인데 "
                    f"안쪽 가장자리가 면 색 그대로다",
                ))
        else:
            # 바깥 그림자는 상자 **밖**을 물들인다. 그림자가 향하는 쪽을 본다.
            dx, dy = off['x'], off['y']
            reach = max(2, min(radius * 0.6, 12))
            if abs(dy) >= abs(dx):
                base_y = y + h + reach if dy >= 0 else y - reach
                pts = [(x + w * f, base_y) for f in (0.3, 0.5, 0.7)]
            else:
                base_x = x + w + reach if dx >= 0 else x - reach
                pts = [(base_x, y + h * f) for f in (0.3, 0.5, 0.7)]
            got = render.median(pts)
            far = _outside(box, render)
            if got is None or far is None:
                continue
            # 그림자 자리가 '멀리 있는 배경'과 똑같으면 안 그려진 것이다.
            if dist(got, far) <= 2:
                findings.append(finding(
                    WARN, '바깥 그림자 없음', box,
                    f"({round(dx)},{round(dy)}) 블러 {round(radius)} 알파 {alpha:.2f} "
                    f"인데 바깥이 배경 그대로다",
                ))


def check_edges(box, render, face, findings):
    """면의 실제 경계가 시안 좌표와 맞는가.

    여러 줄을 훑어 **과반이 같은 값을 말할 때만** 보고한다. 한 줄만 보면
    자식이 덮은 자리에 걸려 엉뚱한 값이 나온다.
    """
    if face is None:
        return
    # 반투명 면은 가장자리 색이 뒤에 따라 달라져 이 방식으로 못 잰다.
    if box['alpha'] < 0.99:
        return
    x, y, w, h = box['x'], box['y'], box['w'], box['h']
    if min(w, h) < 24:
        return
    behind = _outside(box, render)
    if behind is None or dist(face, behind) < DISTINCT:
        return

    def scan(fixed_vals, horizontal, forward):
        """가장자리에서 안쪽으로 들어가며 면 색이 시작되는 자리를 찾는다."""
        found = []
        span = w if horizontal else h
        for v in fixed_vals:
            hit = None
            for step in range(0, int(span * 0.4)):
                d = step if forward else -step
                px = (x + d) if horizontal else v
                py = v if horizontal else (y + d)
                if not forward:
                    px = (x + w + d) if horizontal else v
                    py = v if horizontal else (y + h + d)
                got = render.at(px, py)
                if got is not None and dist(got, face) <= SAME:
                    hit = d if forward else -d
                    break
            if hit is not None:
                found.append(hit)
        if len(found) < 2:
            return None
        return int(np.median(found))

    rows = [y + h * f for f in (0.35, 0.5, 0.65)]
    cols = [x + w * f for f in (0.35, 0.5, 0.65)]
    # 안쪽 선(`strokeAlign: INSIDE`)이 있으면 면이 그 두께만큼 안에서 시작한다.
    # 실제로 홈 배지(2px 선)가 `오른쪽 3 안쪽`으로 잡혀 오탐이 났다.
    tol = 2 + box['stroke']
    for label, delta in (
        ('왼쪽', scan(rows, True, True)),
        ('오른쪽', scan(rows, True, False)),
        ('위', scan(cols, False, True)),
        ('아래', scan(cols, False, False)),
    ):
        if delta is not None and abs(delta) > tol:
            findings.append(finding(
                WARN, '경계 어긋남', box,
                f"{label} 가장자리가 {abs(delta)} {'안쪽' if delta > 0 else '바깥'}에 있다",
            ))


def inspect(boxes, render, occluders=(), skip_top=0.0, skip_bottom=0.0) -> list[dict]:
    """상자 목록을 렌더에 하나씩 물어본다.

    `skip_top`·`skip_bottom` 은 **기기 껍데기**를 건너뛰는 자리다. 시안은 상태바와
    홈인디케이터를 그려 넣지만 위젯 테스트 렌더는 안전영역만 비워 둔다. 그대로 두면
    화면마다 `StatusBar-dynamicIsland` 세 줄이 똑같이 올라와 진짜 결함을 덮는다.
    """
    visible = make_visible_fn(occluders)
    findings: list[dict] = []
    for box in boxes:
        if skip_top and box['y'] + box['h'] <= skip_top:
            continue
        if skip_bottom and box['y'] >= render.h - skip_bottom:
            continue
        face = check_fill(box, render, visible, findings)
        check_corners(box, render, face, visible, findings)
        check_square_corners(box, render, face, visible, findings)
        check_shadows(box, render, face, visible, findings)
        check_edges(box, render, face, findings)
    return findings


# --------------------------------------------------------------------------
# 출력
# --------------------------------------------------------------------------

MARK = {ERROR: '⚠️', WARN: '·'}


def report(findings, checked, as_json=False) -> int:
    if as_json:
        print(json.dumps({'checked': checked, 'findings': findings},
                         ensure_ascii=False, indent=2))
    else:
        print(f'검사한 면 {checked}개')
        if not findings:
            print('  이상 없음')
        else:
            # 결함을 먼저, 그 다음 경고. 사람이 위에서부터 읽는다.
            for f in sorted(findings, key=lambda f: -f['level']):
                print(f"  {MARK[f['level']]} {f['kind']:<12} "
                      f"{f['name']:<24} {f['rect']:<18} {f['text']}")
    if any(f['level'] == ERROR for f in findings):
        return ERROR
    return WARN if findings else OK


# --------------------------------------------------------------------------
# 도구가 맞는지 스스로 확인한다 (네트워크 없이 돈다)
# --------------------------------------------------------------------------

def self_test() -> int:
    """**각진 모서리를 실제로 잡는지** 두 방향으로 확인한다.

    회귀 방지의 핵심 — 도구가 조용히 망가지면 "이상 없음"만 찍어 대는데,
    그건 검사가 없는 것보다 나쁘다. 믿고 안 보게 되기 때문이다.
    """
    import tempfile

    bg = (247, 242, 239)
    face = (255, 255, 255)
    r = 20

    def draw(rounded: bool):
        img = Image.new('RGB', (200, 200), bg)
        px = img.load()
        for yy in range(40, 160):
            for xx in range(20, 180):
                if rounded:
                    # 위 두 모서리만 둥글게 — 시트와 같은 모양이다.
                    cx = 20 + r if xx < 20 + r else (180 - r if xx > 180 - r else xx)
                    cy = 40 + r
                    if yy < 40 + r and (xx < 20 + r or xx > 180 - r):
                        if (xx - cx) ** 2 + (yy - cy) ** 2 > r * r:
                            continue
                px[xx, yy] = face
        return img

    box = {
        'order': 1,
        'id': 'self', 'name': '자가검사 면', 'x': 20, 'y': 40, 'w': 160, 'h': 120,
        'fill': face, 'alpha': 1.0, 'radii': [r, r, 0, 0], 'stroke': 0.0,
        'effects': [],
    }

    passed = True
    with tempfile.TemporaryDirectory() as tmp:
        for rounded, expect_corner in ((True, False), (False, True)):
            path = pathlib.Path(tmp) / f'{rounded}.png'
            draw(rounded).save(path)
            found = inspect([box], Render(path))
            got = any(f['kind'] == '모서리 각짐' for f in found)
            label = '둥근 렌더' if rounded else '각진 렌더'
            ok = got == expect_corner
            passed &= ok
            print(f"  {'통과' if ok else '실패'}  {label} → "
                  f"모서리 각짐 {'보고함' if got else '보고 안 함'} "
                  f"(기대: {'보고' if expect_corner else '없음'})")
            # 둥근 쪽은 다른 검사도 조용해야 한다 — 오탐이 있으면 아무도 안 읽는다.
            if rounded and found:
                passed = False
                print(f"     오탐 {len(found)}건: {[f['kind'] for f in found]}")

    passed &= _fixture_test()
    print('자가검사', '통과' if passed else '실패')
    return OK if passed else ERROR


def _fixture_test() -> bool:
    """**실물 회귀 샘플** — #345 가 났을 때의 일과 시트로 도구를 확인한다.

    합성 사각형만으로는 "우리 화면에서도 잡히는가"를 말하지 못한다. 그래서
    실제 시안 덤프(`fixtures/sheet_956-4084.json`)와, 그때처럼 상단 모서리를
    메운 렌더를 함께 둔다. 네트워크 없이 돌아간다.
    """
    here = pathlib.Path(__file__).resolve().parent / 'fixtures'
    dump = here / 'sheet_956-4084.json'
    bad = here / 'sheet_squared_956-4084.png'
    good = here.parent.parent / 'test/figma/sheet_956-4084.png'
    if not (dump.exists() and bad.exists() and good.exists()):
        print('  건너뜀  회귀 샘플이 없다 (fixtures/)')
        return True

    doc = json.loads(dump.read_text(encoding='utf-8'))
    bb = doc['absoluteBoundingBox']
    boxes, occ = collect_boxes(doc, (bb['x'], bb['y']))

    ok = True
    for path, expect in ((bad, True), (good, False)):
        found = inspect(boxes, Render(path), occ, 59, 21)
        corner = [f for f in found if f['kind'] == '모서리 각짐']
        hit = bool(corner)
        ok &= hit == expect
        label = '각진 시트(#345 재현)' if expect else '고친 시트'
        print(f"  {'통과' if hit == expect else '실패'}  {label} → "
              f"모서리 각짐 {len(corner)}건, 그 밖 {len(found) - len(corner)}건")
        # 고친 쪽은 **아무 소리도 나지 않아야** 한다. 오탐이 섞이면 아무도 안 읽는다.
        if not expect and found:
            ok = False
            for f in found:
                print(f"     오탐 {f['kind']} {f['name']} {f['text']}")
    return ok


# --------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description='시안 속성을 렌더에 직접 묻는다 (#344)')
    ap.add_argument('--node', help='Figma 노드 id (예: 956:4084)')
    ap.add_argument('--render', help='앱 렌더 PNG')
    ap.add_argument('--dump', help='받아 둔 노드 JSON (토큰 없이 쓸 때)')
    ap.add_argument('--save-dump', help='받은 노드 JSON을 여기에 저장한다')
    ap.add_argument('--origin', help='프레임 원점 "x,y" — 기본은 노드 자신의 좌상단')
    ap.add_argument('--ignore-top', type=float, default=59,
                    help='상태바 높이 — 이 위에만 있는 면은 검사하지 않는다 (기본 59)')
    ap.add_argument('--ignore-bottom', type=float, default=21,
                    help='홈인디케이터 높이 (기본 21)')
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--self-test', action='store_true', help='도구 자체를 확인한다')
    ap.add_argument('--dir', help='이 폴더의 대조 렌더를 전부 검사한다 (파일명에서 노드 id를 읽는다)')
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    if args.dir:
        return run_dir(args)

    if not args.render:
        ap.error('--render 가 필요하다')

    if args.dump:
        doc = json.loads(pathlib.Path(args.dump).read_text(encoding='utf-8'))
        doc = doc.get('document', doc)
    else:
        if not args.node:
            ap.error('--node 또는 --dump 가 필요하다')
        token = read_token()
        if not token:
            return report_missing_token()
        doc = fetch_node(args.node, token)
        if args.save_dump:
            pathlib.Path(args.save_dump).write_text(
                json.dumps(doc, ensure_ascii=False), encoding='utf-8')

    bb = doc.get('absoluteBoundingBox') or {}
    if args.origin:
        ox, oy = (float(v) for v in args.origin.split(','))
    else:
        ox, oy = bb.get('x', 0), bb.get('y', 0)

    render = Render(args.render)
    # 크기가 다르면 늘려서 맞추지 않는다 — 늘린 픽셀로 모서리를 재면 답이 흐려진다.
    if bb and (abs(render.w - bb['width']) > 1 or abs(render.h - bb['height']) > 1):
        print(f"❌ 크기가 다르다 — 시안 {round(bb['width'])}x{round(bb['height'])} "
              f"vs 렌더 {render.w}x{render.h}")
        print('   렌더를 1배로 다시 찍어라. 늘려서 맞추면 모서리 판정이 흐려진다.')
        return ERROR

    boxes, occluders = collect_boxes(doc, (ox, oy))
    findings = inspect(boxes, render, occluders,
                       args.ignore_top, args.ignore_bottom)
    checked = sum(1 for b in boxes
                  if b['y'] + b['h'] > args.ignore_top
                  and b['y'] < render.h - args.ignore_bottom)
    return report(findings, checked, args.json)


def run_dir(args) -> int:
    """폴더 하나를 통째로 검사한다.

    대조 렌더 이름은 `이름_노드-아이디.png` 규칙이라(`sheet_956-4084.png`)
    파일명만 보고 어느 시안과 맞댈지 정할 수 있다. **올린 화면만 지켜진다** —
    묶음으로 돌려야 새로 올린 화면이 빠졌는지도 드러난다.
    """
    import re
    token = read_token()
    if not token:
        return report_missing_token()

    worst = OK
    for png in sorted(pathlib.Path(args.dir).glob('*.png')):
        m = re.search(r'_(\d+)-(\d+)$', png.stem)
        if not m:
            print(f'· 건너뜀  {png.name} — 파일명에 노드 id 가 없다')
            continue
        node_id = f'{m.group(1)}:{m.group(2)}'
        print(f'\n=== {png.name}  ({node_id})')
        try:
            doc = fetch_node(node_id, token)
        except Exception as err:  # 한 화면이 실패해도 나머지는 계속 본다
            print(f'  받지 못했다: {err}')
            worst = max(worst, WARN)
            continue
        bb = doc.get('absoluteBoundingBox') or {}
        render = Render(png)
        if bb and (abs(render.w - bb['width']) > 1 or abs(render.h - bb['height']) > 1):
            print(f"  · 크기가 달라 건너뛴다 — 시안 {round(bb['width'])}x{round(bb['height'])}"
                  f" vs 렌더 {render.w}x{render.h}")
            worst = max(worst, WARN)
            continue
        boxes, occ = collect_boxes(doc, (bb.get('x', 0), bb.get('y', 0)))
        findings = inspect(boxes, render, occ, args.ignore_top, args.ignore_bottom)
        worst = max(worst, report(findings, len(boxes), False))
    return worst


def report_missing_token() -> int:
    print('❌ Figma 토큰이 없다.')
    print('   FIGMA_TOKEN 환경변수, client/.env 의 FIGMA_TOKEN, 또는 ~/.figma_token')
    print('   토큰은 저장소에 커밋하지 않는다.')
    return ERROR


if __name__ == '__main__':
    sys.exit(main())
