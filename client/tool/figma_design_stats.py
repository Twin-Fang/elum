#!/usr/bin/env python3
"""Figma 화면 덤프 > 디자인 값 통계 (색 · 글자 · 모서리 · 여백 · 간격)

`tool/design_rules.yaml` 의 허용 값은 이 통계에서 나온다. 디자이너가 새 시안을 내면
덤프를 다시 받아 이 스크립트를 돌리고, 바뀐 값만 yaml 에 옮긴다.

  # 1. 덤프 받기 (Figma REST · 토큰은 환경변수로만)
  curl -s -H "X-Figma-Token: $FIGMA_TOKEN" \
    "https://api.figma.com/v1/files/VSmGuv1iuOpLZmp6QeBHWr/nodes?ids=238:1846" -o /tmp/figma_full.json
  # 2. 통계
  python3 tool/figma_design_stats.py /tmp/figma_full.json            # 사람이 읽는 표
  python3 tool/figma_design_stats.py /tmp/figma_full.json --palette               # UI 색 목록 (yaml palette)
  python3 tool/figma_design_stats.py /tmp/figma_full.json --illustration-palette  # 그림 벡터 색 목록 (yaml illustration_palette)

화면 프레임(폭 393)만 센다. 상태바 · 키보드 · 홈 표시줄은 앱이 그리지 않으므로 뺀다.
"""
import collections
import json
import sys

PHONE_FRAME_WIDTH = 393
# 앱이 그리지 않는 시스템 부품 (이름에 들어 있으면 뺀다)
SYSTEM_PARTS = ('StatusBar', 'Status Bar', 'Home Indicator', 'Keyboard', '키보드')
# 그림을 이루는 노드 종류. 아이콘(fi-*) 안이 아니면 색을 세지 않는다
ILLUSTRATION_TYPES = ('VECTOR', 'BOOLEAN_OPERATION', 'STAR', 'REGULAR_POLYGON')
ICON_PREFIXES = ('fi-', 'icon', 'Icon', '아이콘', '뒤로가기')
# 형제 사이 간격으로 볼 최대값 (그 위는 화면 배치 좌표)
MAX_SIBLING_GAP = 64


def to_hex(color, opacity=1.0):
    """Figma 색(0~1) > #RRGGBB 또는 #RRGGBB@NN% (투명도 있으면)"""
    alpha = color.get('a', 1) * opacity
    rgb = '#%02X%02X%02X' % tuple(round(color[k] * 255) for k in 'rgb')
    return rgb if alpha >= 0.99 else '%s@%d%%' % (rgb, round(alpha * 100))


def collect_phone_frames(node, found):
    """섹션을 따라 내려가며 폰 화면 프레임만 모은다"""
    if node['type'] == 'SECTION':
        for child in node.get('children', []):
            collect_phone_frames(child, found)
    elif node['type'] == 'FRAME' and node.get('absoluteBoundingBox', {}).get('width') == PHONE_FRAME_WIDTH:
        found.append(node)


class DesignStats:
    def __init__(self, is_illustration=False):
        # 그림(캐릭터 · 일러스트) 벡터 색은 따로 모은다 — 코드로 그린 그림 토큰의 근거
        self.illustration = None if is_illustration else DesignStats(is_illustration=True)
        self.fills = collections.Counter()
        self.gradient_stops = collections.Counter()
        self.strokes = collections.Counter()
        self.shadows = collections.Counter()
        self.fonts = collections.Counter()
        self.radii = collections.Counter()
        self.paddings = collections.Counter()
        self.item_gaps = collections.Counter()
        self.sibling_gaps = collections.Counter()
        self.text_left = collections.Counter()
        self.panel_left_width = collections.Counter()

    def walk(self, node, frame_left, depth, in_icon=False):
        if node.get('visible') is False or any(part in node.get('name', '') for part in SYSTEM_PARTS):
            return
        box = node.get('absoluteBoundingBox') or {}
        in_icon = in_icon or (node['type'] == 'INSTANCE' and node.get('name', '').startswith(ICON_PREFIXES))
        # 그림(캐릭터 · 일러스트) 벡터 색은 UI 색이 아니다. 아이콘 벡터만 센다
        if node['type'] not in ILLUSTRATION_TYPES or in_icon:
            self._count_paints(node)
        else:
            self.illustration._count_paints(node)
        self._count_text(node, box, frame_left)
        if node.get('cornerRadius'):
            self.radii[round(node['cornerRadius'], 1)] += 1
        if node.get('layoutMode'):
            self.paddings[tuple(node.get(k, 0) or 0 for k in ('paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft'))] += 1
            if node.get('itemSpacing'):
                self.item_gaps[node['itemSpacing']] += 1
        if node['type'] in ('RECTANGLE', 'FRAME', 'INSTANCE', 'GROUP') and box and 300 <= box['width'] <= 380 and depth >= 1:
            self.panel_left_width[(round(box['x'] - frame_left), round(box['width']))] += 1
        self._count_sibling_gaps(node)
        for child in node.get('children', []):
            self.walk(child, frame_left, depth + 1, in_icon)

    def _count_paints(self, node):
        kind = 'text' if node['type'] == 'TEXT' else 'shape'
        # 글자 일부만 다른 색 (예: `보호자`가 사용해요) 은 styleOverrideTable 에 있다
        override_paints = [paint for style in (node.get('styleOverrideTable') or {}).values() for paint in style.get('fills', [])]
        for paint in node.get('fills', []) + override_paints:
            if paint.get('visible', True) is False:
                continue
            if paint.get('type') == 'SOLID':
                self.fills[(to_hex(paint['color'], paint.get('opacity', 1)), kind)] += 1
            elif paint.get('type', '').startswith('GRADIENT'):
                for stop in paint.get('gradientStops', []):
                    self.gradient_stops[to_hex(stop['color'])] += 1
        for paint in node.get('strokes', []):
            if paint.get('type') == 'SOLID':
                self.strokes[(to_hex(paint['color']), node.get('strokeWeight'))] += 1
        for effect in node.get('effects', []):
            if effect.get('visible', True) and 'SHADOW' in effect['type']:
                offset = effect.get('offset', {})
                self.shadows[(effect['type'], offset.get('x'), offset.get('y'), effect.get('radius'), to_hex(effect['color']))] += 1

    def _count_text(self, node, box, frame_left):
        if node['type'] != 'TEXT':
            return
        style = node.get('style', {})
        size = style.get('fontSize', 0)
        line = round(style.get('lineHeightPx', 0) / size, 2) if size else 0
        self.fonts[(style.get('fontFamily'), style.get('fontWeight'), round(size, 1), line)] += 1
        if box:
            self.text_left[round(box['x'] - frame_left)] += 1

    def _count_sibling_gaps(self, node):
        """같은 열(x 같음)에 위아래로 놓인 형제 사이 빈칸"""
        siblings = sorted(
            (child for child in node.get('children', []) if child.get('absoluteBoundingBox') and child.get('visible') is not False),
            key=lambda child: child['absoluteBoundingBox']['y'],
        )
        for upper, lower in zip(siblings, siblings[1:]):
            upper_box, lower_box = upper['absoluteBoundingBox'], lower['absoluteBoundingBox']
            gap = round(lower_box['y'] - (upper_box['y'] + upper_box['height']))
            if 0 < gap <= MAX_SIBLING_GAP and abs(upper_box['x'] - lower_box['x']) < 2:
                self.sibling_gaps[gap] += 1


def print_table(title, counter, limit=40):
    print(f'\n## {title}')
    for key, count in counter.most_common(limit):
        print(f'  {count:4d}  {key}')


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    nodes = json.load(open(sys.argv[1]))['nodes']
    frames = []
    for value in nodes.values():
        collect_phone_frames(value['document'], frames)
    stats = DesignStats()
    for frame in frames:
        stats.walk(frame, frame['absoluteBoundingBox']['x'], 0)

    if '--palette' in sys.argv or '--illustration-palette' in sys.argv:
        source = stats.illustration if '--illustration-palette' in sys.argv else stats
        colors = {key[0].split('@')[0] for key in source.fills} | {key[0] for key in source.strokes}
        colors |= {color.split('@')[0] for color in source.gradient_stops}
        colors |= {key[4].split('@')[0] for key in source.shadows}
        for color in sorted(colors):
            print(f'  - "{color}"')
        return

    print(f'폰 화면 프레임 {len(frames)}장')
    print_table('채움 색 (색, 글자/면)', stats.fills, 60)
    print_table('그라데이션 색', stats.gradient_stops, 30)
    print_table('테두리 (색, 두께)', stats.strokes, 20)
    print_table('그림자 (종류, x, y, 흐림, 색)', stats.shadows, 15)
    print_table('글자 (글꼴, 굵기, 크기, 줄높이 배수)', stats.fonts, 60)
    print_table('모서리', stats.radii, 20)
    print_table('오토레이아웃 패딩 (위, 오른, 아래, 왼)', stats.paddings, 20)
    print_table('오토레이아웃 간격', stats.item_gaps, 20)
    print_table('위아래 형제 사이 간격', stats.sibling_gaps, 30)
    print_table('글 시작 x', stats.text_left, 15)
    print_table('큰 판 (x, 폭)', stats.panel_left_width, 15)


if __name__ == '__main__':
    main()
