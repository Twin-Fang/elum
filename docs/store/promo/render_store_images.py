"""스토어 홍보 이미지 생성: 문구(copy.*.json) + 실측 화면(screens/) + 그림(art/) > 규격별 PNG

사용: python3 -I render_store_images.py [--language ko|en] [--screens-fallback 폴더]
출력: out/{언어}/{규격}/{슬라이드 id}.png, out/{언어}/feature_graphic.png
필요: playwright(chromium), Pillow
"""
import argparse
import json
import pathlib
import re
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

PROMO_DIR = pathlib.Path(__file__).resolve().parent
REPO_ROOT = PROMO_DIR.parents[2]
FONT_DIR = REPO_ROOT / 'client/assets/fonts'
LOGO_PATH = REPO_ROOT / 'client/assets/images/logo_elum.svg'

# 스토어 규격 (가로, 세로 픽셀): App Store 6.9형·6.5형, Google Play 휴대폰 9:16
STORE_SIZES = {
    'ios_6.9': (1320, 2868),
    'ios_6.5': (1284, 2778),
    'android_phone': (1080, 1920),
}
# Google Play 대표 그래픽 (1024×500 고정)
FEATURE_GRAPHIC_SIZE = (1024, 500)
# 레이아웃 기준 폭 (CSS px) — 규격마다 배율만 바꿔 같은 배치 유지
LAYOUT_WIDTH_CSS = 440

# 스토어 문구 금지어: 의료·효과 암시, 연령 암시 (docs/store/store-listing.md)
FORBIDDEN_WORDS_KO = ['치료', '진단', '교정', '훈련', '증상', '완화', '재활', '연습', '효과', '예방',
                      '극복', '향상', '호전', '의료', '처방', '아이', '아동']
FORBIDDEN_WORDS_EN = ['therapy', 'treat', 'diagnos', 'cure', 'symptom', 'medical', 'clinical',
                      'improve', 'training', 'child', 'kid']

# 슬라이드 배경 테마: (배경 위, 배경 아래, 강조 알약 배경)
THEMES = {
    'peach': ('#FFF4EC', '#FFD9C4', '#FF8B26'),
    'butter': ('#FFFBEA', '#FFEFA8', '#E08A00'),
    'mint': ('#F1FFFB', '#BFF5E6', '#14A889'),
    'lavender': ('#F6F4FF', '#D9D4FF', '#6C5CE7'),
    'sky': ('#F2F9FF', '#CDE7FF', '#2F80ED'),
    'cream': ('#FBF8F5', '#EFE7DF', '#242634'),
}


# 화면에 보이는 문구 키 (screen·art·theme 같은 내부 식별자는 검사하지 않음)
VISIBLE_TEXT_KEYS = ('brand', 'tagline', 'eyebrow', 'title', 'subtitle')


def collect_visible_text(node) -> list[str]:
    """문구 JSON에서 화면에 보이는 문자열만 수집"""
    if isinstance(node, dict):
        return [value for key, item in node.items()
                for value in (([item] if key in VISIBLE_TEXT_KEYS and isinstance(item, str)
                               else collect_visible_text(item)))]
    if isinstance(node, list):
        return [value for item in node for value in collect_visible_text(item)]
    return []


def find_forbidden_words(copy: dict) -> list[str]:
    """화면에 보이는 문구에서 금지어 찾기 > 발견 목록"""
    text = '\n'.join(collect_visible_text(copy))
    words = FORBIDDEN_WORDS_KO if copy['language'] == 'ko' else FORBIDDEN_WORDS_EN
    return [word for word in words if re.search(word, text, re.IGNORECASE)]


def make_transparent_art(source: pathlib.Path, target: pathlib.Path) -> pathlib.Path:
    """흰 배경 그림 > 테두리와 이어진 흰 영역만 투명 (캐릭터 안쪽 흰색 보존)"""
    if target.exists() and target.stat().st_mtime > source.stat().st_mtime:
        return target
    image = Image.open(source).convert('RGBA')
    width, height = image.size
    pixels = image.load()
    # 거의 흰색 판정 (밝기 하한 238)
    def is_near_white(x, y):
        red, green, blue, _ = pixels[x, y]
        return min(red, green, blue) >= 238
    # 테두리에서 시작하는 흰 영역 채우기
    visited = bytearray(width * height)
    stack = [(x, y) for x in range(width) for y in (0, height - 1)]
    stack += [(x, y) for y in range(height) for x in (0, width - 1)]
    while stack:
        x, y = stack.pop()
        index = y * width + x
        if visited[index] or not is_near_white(x, y):
            continue
        visited[index] = 1
        pixels[x, y] = (255, 255, 255, 0)
        if x > 0: stack.append((x - 1, y))
        if x < width - 1: stack.append((x + 1, y))
        if y > 0: stack.append((x, y - 1))
        if y < height - 1: stack.append((x, y + 1))
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target)
    return target


def build_font_faces() -> str:
    """앱과 같은 Pretendard 굵기별 @font-face"""
    weights = {'Regular': 400, 'Medium': 500, 'SemiBold': 600, 'Bold': 700, 'ExtraBold': 800}
    faces = []
    for name, weight in weights.items():
        matches = list(FONT_DIR.glob(f'Pretendard-{name}.*'))
        if matches:
            faces.append(f"@font-face{{font-family:'PromoSans';font-weight:{weight};"
                         f"src:url('{matches[0].as_uri()}')}}")
    return '\n'.join(faces)


def to_html_lines(text: str) -> str:
    """줄바꿈(\\n) > <br>, HTML 특수문자 이스케이프"""
    escaped = text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    return escaped.replace('\n', '<br>')


def build_slide_html(slide: dict, screen_path: pathlib.Path | None, art_path: pathlib.Path,
                     slide_index: int, height_css: float) -> str:
    """슬라이드 1장 HTML: 강조 알약 > 제목 > 설명 > 휴대폰(실측 화면) > 캐릭터 그림
    실측 화면 없음(영어 일과 생성 전) > 휴대폰 없이 그림만 크게"""
    top_color, bottom_color, accent_color = THEMES[slide['theme']]
    # 캐릭터는 좌우 번갈아 배치 (홀수 슬라이드 오른쪽)
    is_art_on_right = slide_index % 2 == 1
    art_side = 'right:-6px' if is_art_on_right else 'left:-6px'
    phone_shift = '-18px' if is_art_on_right else '18px'
    # 짧은 규격(안드로이드 9:16)은 휴대폰을 덜 보여 주고 제목 공간 유지
    phone_top_css = 236 if height_css > 900 else 222
    if screen_path:
        phone_html = (f'<div class="phone"><div class="screen"><img src="{screen_path.as_uri()}">'
                      f'<div class="island"></div></div></div>')
        art_class = 'art'
    else:
        phone_html = ''
        art_class = 'art-only'
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
{build_font_faces()}
*{{box-sizing:border-box;margin:0}}
html,body{{width:{LAYOUT_WIDTH_CSS}px;height:{height_css}px;overflow:hidden}}
body{{font-family:'PromoSans',sans-serif;color:#242634;position:relative;
  background:linear-gradient(180deg,{top_color} 0%,{bottom_color} 100%);-webkit-font-smoothing:antialiased}}
.glow{{position:absolute;width:520px;height:520px;border-radius:50%;left:-40px;top:{phone_top_css + 120}px;
  background:radial-gradient(circle,rgba(255,255,255,.75) 0%,rgba(255,255,255,0) 65%)}}
.copy{{position:absolute;left:0;right:0;top:44px;text-align:center;padding:0 22px}}
.eyebrow{{display:inline-block;font-weight:700;font-size:13px;letter-spacing:.02em;color:#fff;
  background:{accent_color};border-radius:999px;padding:6px 14px}}
h1{{margin-top:14px;font-weight:800;font-size:31px;line-height:1.22;letter-spacing:-.03em}}
p{{margin-top:12px;font-weight:500;font-size:15.5px;line-height:1.5;color:#5E5F6B;letter-spacing:-.01em}}
.phone{{position:absolute;left:50%;top:{phone_top_css}px;width:286px;transform:translateX(calc(-50% + {phone_shift}));
  border-radius:52px;background:#16171D;padding:9px;
  box-shadow:0 30px 60px rgba(36,38,52,.22),0 0 0 2px #2C2D35 inset}}
.screen{{position:relative;border-radius:43px;overflow:hidden;background:#000}}
.screen img{{display:block;width:100%}}
.island{{position:absolute;top:11px;left:50%;transform:translateX(-50%);width:84px;height:24px;
  border-radius:20px;background:#000}}
.art{{position:absolute;{art_side};bottom:{max(height_css * 0.02, 10):.0f}px;width:200px;
  filter:drop-shadow(0 12px 18px rgba(36,38,52,.16))}}
.art-only{{position:absolute;left:50%;top:{phone_top_css + (height_css - phone_top_css) / 2:.0f}px;width:380px;
  transform:translate(-50%,-50%);filter:drop-shadow(0 16px 26px rgba(36,38,52,.18))}}
</style></head><body>
<div class="glow"></div>
<div class="copy">
  <span class="eyebrow">{to_html_lines(slide['eyebrow'])}</span>
  <h1>{to_html_lines(slide['title'])}</h1>
  <p>{to_html_lines(slide['subtitle'])}</p>
</div>
{phone_html}
<img class="{art_class}" src="{art_path.as_uri()}">
</body></html>"""


def build_feature_graphic_html(copy: dict, art_path: pathlib.Path) -> str:
    """Google Play 대표 그래픽: 그림 배경 > 왼쪽 로고·제목·설명"""
    feature = copy['featureGraphic']
    width, height = FEATURE_GRAPHIC_SIZE
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
{build_font_faces()}
*{{box-sizing:border-box;margin:0}}
html,body{{width:{width}px;height:{height}px;overflow:hidden}}
body{{font-family:'PromoSans',sans-serif;color:#242634;position:relative;background:#FEFDF1}}
.bg{{position:absolute;right:-60px;top:50%;transform:translateY(-50%);height:118%;
  -webkit-mask-image:linear-gradient(90deg,transparent 0%,#000 22%,#000 100%)}}
.copy{{position:absolute;left:64px;top:50%;transform:translateY(-50%);width:470px}}
.logo{{height:40px;display:block}}
h1{{margin-top:22px;font-weight:800;font-size:44px;line-height:1.18;letter-spacing:-.035em}}
p{{margin-top:16px;font-weight:500;font-size:20px;color:#5E5F6B}}
</style></head><body>
<img class="bg" src="{art_path.as_uri()}">
<div class="copy"><img class="logo" src="{LOGO_PATH.as_uri()}">
<h1>{to_html_lines(feature['title'])}</h1><p>{to_html_lines(feature['subtitle'])}</p></div>
</body></html>"""


def render_html(page, html: str, work_file: pathlib.Path, size: tuple[int, int], out_file: pathlib.Path):
    """HTML > 정확한 픽셀 크기 PNG (배율 = 목표 폭 / 기준 폭)"""
    width_px, height_px = size
    work_file.write_text(html, encoding='utf-8')
    page.goto(work_file.as_uri())
    page.wait_for_load_state('networkidle')
    page.evaluate('document.fonts.ready')
    out_file.parent.mkdir(parents=True, exist_ok=True)
    page.screenshot(path=str(out_file), clip={'x': 0, 'y': 0,
                    'width': page.viewport_size['width'], 'height': page.viewport_size['height']})
    # 배율 반올림 오차로 1px 어긋나면 목표 크기로 맞춤
    with Image.open(out_file) as image:
        if image.size != (width_px, height_px):
            image.convert('RGB').resize((width_px, height_px), Image.LANCZOS).save(out_file)
        else:
            image.convert('RGB').save(out_file)


def render_language(language: str, screens_fallback: pathlib.Path | None) -> list[pathlib.Path]:
    """언어 1개: 금지어 검사 > 슬라이드 규격별 > 대표 그래픽"""
    copy = json.loads((PROMO_DIR / f'copy.{language}.json').read_text(encoding='utf-8'))
    forbidden = find_forbidden_words(copy)
    if forbidden:
        sys.exit(f'[promo render] rejected : forbidden words in copy.{language}.json -> {forbidden}')

    work_dir = PROMO_DIR / 'out/.work'
    work_dir.mkdir(parents=True, exist_ok=True)
    outputs = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        for size_name, (width_px, height_px) in STORE_SIZES.items():
            scale = width_px / LAYOUT_WIDTH_CSS
            height_css = height_px / scale
            page = browser.new_page(viewport={'width': LAYOUT_WIDTH_CSS, 'height': round(height_css)},
                                    device_scale_factor=scale)
            for index, slide in enumerate(copy['slides'], 1):
                screen_path = PROMO_DIR / f'screens/{language}/{slide["screen"]}.png'
                if not screen_path.exists() and screens_fallback:
                    screen_path = screens_fallback / f'{slide["screen"]}.png'
                if not screen_path.exists():
                    print(f'[promo render] art only : screen missing {language}/{slide["screen"]}')
                    screen_path = None
                art_path = make_transparent_art(PROMO_DIR / f'art/{slide["art"]}.png',
                                                work_dir / f'{slide["art"]}_transparent.png')
                html = build_slide_html(slide, screen_path, art_path, index, height_css)
                out_file = PROMO_DIR / f'out/{language}/{size_name}/{slide["id"]}.png'
                render_html(page, html, work_dir / 'slide.html', (width_px, height_px), out_file)
                outputs.append(out_file)
            page.close()

        width_px, height_px = FEATURE_GRAPHIC_SIZE
        page = browser.new_page(viewport={'width': width_px, 'height': height_px}, device_scale_factor=1)
        out_file = PROMO_DIR / f'out/{language}/feature_graphic.png'
        render_html(page, build_feature_graphic_html(copy, PROMO_DIR / 'art/hero.png'),
                    work_dir / 'feature.html', FEATURE_GRAPHIC_SIZE, out_file)
        outputs.append(out_file)
        browser.close()
    return outputs


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--language', choices=['ko', 'en'], action='append')
    parser.add_argument('--screens-fallback', type=pathlib.Path,
                        help='실측 화면이 없을 때 쓸 임시 화면 폴더 (배치 확인용)')
    arguments = parser.parse_args()
    for language in arguments.language or ['ko', 'en']:
        for out_file in render_language(language, arguments.screens_fallback):
            with Image.open(out_file) as image:
                print(f'{out_file.relative_to(PROMO_DIR)} {image.size[0]}x{image.size[1]}')


if __name__ == '__main__':
    main()
