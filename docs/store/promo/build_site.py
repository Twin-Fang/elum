"""소개 페이지 생성: 문구(site.*.json, copy.*.json) + 그림·실측 화면·영상 > gh-pages 폴더

사용: python3 -I build_site.py <gh-pages 작업 폴더>
출력: index.html(한국어), en/index.html(영어), sitemap.xml, assets/promo/**, assets/og_en.png
필요: Pillow, ffmpeg(영상이 있을 때)
"""
import html
import json
import pathlib
import re
import shutil
import subprocess
import sys

from PIL import Image

PROMO_DIR = pathlib.Path(__file__).resolve().parent
SITE_URL = 'https://twin-fang.github.io/elum/'
APP_STORE_URL = 'https://apps.apple.com/kr/app/id6792970508'
GOOGLE_PLAY_URL = 'https://play.google.com/store/apps/details?id=kr.twinfang.elum'
LANGUAGES = ['ko', 'en']
# 페이지에 싣는 크기 (가로 픽셀): 실측 화면, 장면 그림, 첫 화면 그림, 영상
SCREEN_WIDTH_PIXELS = 640
SCENE_WIDTH_PIXELS = 480
HERO_WIDTH_PIXELS = 1344
VIDEO_WIDTH_PIXELS = 720

APPLE_ICON = ('<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M16.37 12.6c.02 2.6 2.28 3.47 2.3 3.48'
              '-.02.06-.36 1.24-1.19 2.45-.72 1.05-1.46 2.09-2.63 2.11-1.15.02-1.52-.68-2.83-.68-1.32 0-1.73.66-2.82.7-1.13.04-1.99'
              '-1.13-2.71-2.18-1.48-2.14-2.61-6.04-1.09-8.68.75-1.31 2.1-2.14 3.56-2.16 1.11-.02 2.16.75 2.84.75.68 0 1.95-.93 3.29-.79'
              '.56.02 2.13.23 3.14 1.71-.08.05-1.87 1.09-1.86 3.27M14.2 4.99c.6-.73 1.01-1.74.9-2.75-.87.03-1.92.58-2.54 1.31-.56.64'
              '-1.05 1.67-.92 2.66.97.07 1.96-.49 2.56-1.22"/></svg>')
PLAY_ICON = ('<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="#34A853" d="M3.6 2.3 13.5 12l-9.9 9.7c-.4-.2-.6-.6-.6-1.1V3.4'
             'c0-.5.2-.9.6-1.1z"/><path fill="#FBBC04" d="m16.9 15.4-3.4-3.4 3.4-3.4 3.8 2.2c1 .6 1 1.8 0 2.4z"/><path fill="#4285F4"'
             ' d="M3.6 2.3c.3-.1.7-.1 1 .1l12.3 7.1-3.4 3.4z"/><path fill="#EA4335" d="m13.5 12 3.4 3.4-12.3 7.1c-.3.2-.7.2-1 .1z"/></svg>')


def strip_tags(text: str) -> str:
    """HTML 문구 > 구조화 데이터용 평문"""
    return html.unescape(re.sub(r'<[^>]+>', '', text))


def save_webp(source: pathlib.Path, target: pathlib.Path, width_pixels: int, has_alpha: bool = False):
    """PNG > 지정 폭 WebP (투명 유지 여부 선택)"""
    target.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as image:
        image = image.convert('RGBA' if has_alpha else 'RGB')
        if image.width > width_pixels:
            image = image.resize((width_pixels, round(image.height * width_pixels / image.width)), Image.LANCZOS)
        image.save(target, 'WEBP', quality=84, method=6)


def export_video(source: pathlib.Path, target: pathlib.Path):
    """실측 녹화 > 무음 H.264 MP4 (웹 자동 재생용, 앞부분 메타데이터 배치)"""
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', str(source), '-an',
                    '-vf', f'scale={VIDEO_WIDTH_PIXELS}:-2,fps=30', '-c:v', 'libx264', '-crf', '27',
                    '-preset', 'slow', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(target)], check=True)


def export_assets(site_dir: pathlib.Path) -> dict:
    """그림·화면·영상을 gh-pages assets/promo 로 내보내기 > 언어별로 있는 자산 목록"""
    promo_assets = site_dir / 'assets/promo'
    save_webp(PROMO_DIR / 'art/hero.png', promo_assets / 'hero.webp', HERO_WIDTH_PIXELS)
    transparent_dir = PROMO_DIR / 'out/.work'
    for scene in sorted((PROMO_DIR / 'art').glob('scene_*.png')):
        transparent = transparent_dir / f'{scene.stem}_transparent.png'
        save_webp(transparent if transparent.exists() else scene, promo_assets / f'{scene.stem}.webp',
                  SCENE_WIDTH_PIXELS, has_alpha=True)
    available = {}
    for language in LANGUAGES:
        screens = {}
        for screen in sorted((PROMO_DIR / f'screens/{language}').glob('*.png')):
            save_webp(screen, promo_assets / f'{language}/{screen.stem}.webp', SCREEN_WIDTH_PIXELS)
            screens[screen.stem] = f'assets/promo/{language}/{screen.stem}.webp'
        video_source = PROMO_DIR / f'video/{language}/elumi_flow.mp4'
        video = None
        if video_source.exists():
            export_video(video_source, promo_assets / f'{language}/elumi_flow.mp4')
            video = f'assets/promo/{language}/elumi_flow.mp4'
        available[language] = {'screens': screens, 'video': video}
    # 영어 공유 미리보기: 영어 대표 그래픽 재사용
    feature_en = PROMO_DIR / 'out/en/feature_graphic.png'
    if feature_en.exists():
        shutil.copyfile(feature_en, site_dir / 'assets/og_en.png')
    return available


def build_structured_data(site: dict) -> str:
    """구조화 데이터 2개: 앱 정보(MobileApplication), 자주 묻는 질문(FAQPage)"""
    page_url = SITE_URL + site['path']
    application = {
        '@context': 'https://schema.org', '@type': 'MobileApplication',
        'name': 'ELUM' if site['language'] == 'en' else '이룸 ELUM', 'alternateName': ['이룸', 'ELUM'],
        'description': site['schemaDescription'], 'applicationCategory': 'EducationalApplication',
        'operatingSystem': 'iOS, Android', 'inLanguage': site['language'], 'url': page_url,
        'downloadUrl': [APP_STORE_URL, GOOGLE_PLAY_URL], 'installUrl': [APP_STORE_URL, GOOGLE_PLAY_URL],
        'image': SITE_URL + 'assets/promo/hero.webp',
        'offers': {'@type': 'Offer', 'price': '0', 'priceCurrency': 'KRW' if site['language'] == 'ko' else 'USD'},
    }
    faq_page = {
        '@context': 'https://schema.org', '@type': 'FAQPage',
        'mainEntity': [{'@type': 'Question', 'name': item['q'],
                        'acceptedAnswer': {'@type': 'Answer', 'text': strip_tags(item['a'])}} for item in site['faq']],
    }
    return '\n'.join(f'<script type="application/ld+json">{json.dumps(data, ensure_ascii=False)}</script>'
                     for data in (application, faq_page))


def build_store_buttons(site: dict) -> str:
    """App Store·Google Play 받기 버튼 2개"""
    return (f'<a class="store" href="{APP_STORE_URL}" rel="noopener">{APPLE_ICON}<span>{site["hero"]["appStore"]}</span></a>'
            f'<a class="store" href="{GOOGLE_PLAY_URL}" rel="noopener">{PLAY_ICON}<span>{site["hero"]["googlePlay"]}</span></a>')


def build_phone(image_src: str | None, alt: str, root: str, video_src: str | None = None, label: str = '') -> str:
    """휴대폰 틀: 영상 있으면 영상(무음 반복), 없으면 실측 화면"""
    if video_src:
        poster = f' poster="{root}{image_src}"' if image_src else ''
        inner = (f'<video src="{root}{video_src}"{poster} autoplay muted loop playsinline preload="metadata" '
                 f'aria-label="{html.escape(label)}"></video>')
    elif image_src:
        inner = f'<img src="{root}{image_src}" alt="{html.escape(alt)}" loading="lazy" decoding="async"/>'
    else:
        return ''
    return f'<div class="phone"><div class="screen">{inner}<i class="island"></i></div></div>'


def build_features(site: dict, copy: dict, assets: dict, root: str) -> str:
    """기능 6개: 문구 > 실측 화면 + 장면 그림 (좌우 번갈아)"""
    rows = []
    for index, slide in enumerate(copy['slides']):
        screen_src = assets['screens'].get(slide['screen'])
        phone = build_phone(screen_src, strip_tags(slide['title'].replace('\n', ' ')), root)
        is_reversed = ' rev' if index % 2 else ''
        rows.append(f"""<article class="feature{is_reversed}">
  <div class="feature-text">
    <span class="eyebrow">{html.escape(slide['eyebrow'])}</span>
    <h3>{html.escape(slide['title']).replace(chr(10), '<br/>')}</h3>
    <p>{html.escape(slide['subtitle']).replace(chr(10), ' ')}</p>
  </div>
  <div class="feature-visual theme-{slide['theme']}">
    {phone}
    <img class="scene" src="{root}assets/promo/{slide['art']}.webp" alt="" loading="lazy" decoding="async"/>
  </div>
</article>""")
    return '\n'.join(rows)


def build_page(site: dict, copy: dict, assets: dict) -> str:
    """언어 1개 페이지 HTML"""
    root = '../' if site['path'] else './'
    page_url = SITE_URL + site['path']
    hero = site['hero']
    nav = site['nav']
    hero_phone = build_phone(assets['screens'].get('child_card'), hero['videoLabel'], root,
                             assets['video'], hero['videoLabel'])
    faq_items = '\n'.join(
        f'<details{" open" if index == 0 else ""}><summary>{html.escape(item["q"])}</summary>'
        f'<div class="body">{item["a"].replace("{root}", root)}</div></details>'
        for index, item in enumerate(site['faq']))
    steps = '\n'.join(
        f'<div class="tile"><div class="num">0{index}</div><div class="rule" style="background:{step["color"]}"></div>'
        f'<h3>{html.escape(step["title"])}</h3><p>{html.escape(step["body"])}</p></div>'
        for index, step in enumerate(site['steps'], 1))
    checklist = ''.join(f'<li>{item}</li>' for item in site['contactChecklistHtml'])
    return f"""<!DOCTYPE html>
<html lang="{site['language']}">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>{html.escape(site['title'])}</title>
<meta name="description" content="{html.escape(site['description'])}"/>
<link rel="canonical" href="{page_url}"/>
<link rel="alternate" hreflang="ko" href="{SITE_URL}"/>
<link rel="alternate" hreflang="en" href="{SITE_URL}en/"/>
<link rel="alternate" hreflang="x-default" href="{SITE_URL}"/>
<link rel="icon" href="{root}assets/lumi.svg"/>
<meta name="apple-itunes-app" content="app-id=6792970508"/>
{build_structured_data(site)}
<meta property="og:title" content="{html.escape(site['ogTitle'])}"/>
<meta property="og:description" content="{html.escape(site['ogDescription'])}"/>
<meta property="og:type" content="website"/>
<meta property="og:url" content="{page_url}"/>
<meta property="og:site_name" content="이룸 ELUM"/>
<meta property="og:locale" content="{site['locale']}"/>
<meta property="og:image" content="{SITE_URL}{site['ogImage']}"/>
<meta name="twitter:card" content="summary_large_image"/>
<link rel="preconnect" href="https://cdn.jsdelivr.net"/>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable-dynamic-subset.min.css"/>
<link rel="stylesheet" href="{root}assets/promo/site.css"/>
</head>
<body>

<header>
  <div class="wrap bar">
    <a class="brand" href="{root}{site['path']}"><img src="{root}assets/logo.svg" alt="이룸 ELUM"/></a>
    <nav>
      <a href="#features">{nav['features']}</a>
      <a href="#faq">{nav['faq']}</a>
      <a href="#contact">{nav['contact']}</a>
    </nav>
    <a class="lang" href="{nav['otherLanguageHref']}" hreflang="{'en' if site['language'] == 'ko' else 'ko'}">{nav['otherLanguage']}</a>
  </div>
</header>

<main>
<div class="wrap hero">
  <div class="hero-text">
    <div class="tag">{hero['tag']}</div>
    <h1>{hero['titleHtml']}</h1>
    <p class="lede">{html.escape(hero['lede'])}</p>
    <div class="cta">{build_store_buttons(site)}</div>
    <p class="hint">{hero['hintHtml']}</p>
  </div>
  <div class="hero-visual">
    <img class="hero-art" src="{root}assets/promo/hero.webp" alt="" fetchpriority="high"/>
    {hero_phone}
  </div>
</div>

<div class="wrap"><div class="trio">{steps}</div></div>

<section id="features">
  <div class="wrap">
    <div class="tag">{site['featuresTag']}</div>
    <h2>{html.escape(site['featuresTitle'])}</h2>
    <p class="sub">{html.escape(site['featuresSub'])}</p>
    <div class="features">{build_features(site, copy, assets, root)}</div>
  </div>
</section>

<section class="download">
  <div class="wrap download-box">
    <img src="{root}assets/promo/scene_06.webp" alt="" loading="lazy"/>
    <div>
      <h2>{html.escape(site['downloadTitle'])}</h2>
      <p class="sub">{html.escape(site['downloadSub'])}</p>
      <div class="cta">{build_store_buttons(site)}</div>
    </div>
  </div>
</section>

<section id="faq">
  <div class="wrap">
    <div class="tag">FAQ</div>
    <h2>{html.escape(site['faqTitle'])}</h2>
    <p class="sub">{html.escape(site['faqSub'])}</p>
    <div class="faq">{faq_items}</div>
  </div>
</section>

<section id="contact">
  <div class="wrap">
    <div class="tag">Contact</div>
    <h2>{html.escape(site['contactTitle'])}</h2>
    <p class="sub">{html.escape(site['contactSub'])}</p>
    <div class="contact">
      <div class="card mailcard">
        <div class="tag">{site['contactMailTag']}</div>
        <a class="mail" href="mailto:chan4760@gmail.com?subject={site['contactMailSubject']}">chan4760@gmail.com</a>
        <p class="hint">{html.escape(site['contactMailHint'])}</p>
      </div>
      <div class="card">
        <div class="tag">{site['contactChecklistTag']}</div>
        <ul class="check">{checklist}</ul>
      </div>
    </div>
  </div>
</section>
</main>

<footer>
  <div class="wrap fl">
    <img src="{root}assets/logo.svg" alt="이룸 ELUM"/>
    <a href="{root}privacy.html">{nav['privacy']}</a>
    <a href="{root}delete.html">{nav['delete']}</a>
    <span class="tag" style="margin-left:auto">Twin-Fang</span>
  </div>
</footer>

</body>
</html>
"""


def build_sitemap() -> str:
    """사이트맵: 한·영 첫 화면(서로 언어 연결) + 법적 안내 2개"""
    alternates = (f'<xhtml:link rel="alternate" hreflang="ko" href="{SITE_URL}"/>'
                  f'<xhtml:link rel="alternate" hreflang="en" href="{SITE_URL}en/"/>')
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
  <url><loc>{SITE_URL}</loc>{alternates}</url>
  <url><loc>{SITE_URL}en/</loc>{alternates}</url>
  <url><loc>{SITE_URL}privacy.html</loc></url>
  <url><loc>{SITE_URL}delete.html</loc></url>
</urlset>
"""


def main():
    if len(sys.argv) != 2:
        sys.exit('usage: build_site.py <gh-pages folder>')
    site_dir = pathlib.Path(sys.argv[1]).resolve()
    available = export_assets(site_dir)
    shutil.copyfile(PROMO_DIR / 'site.css', site_dir / 'assets/promo/site.css')
    for language in LANGUAGES:
        site = json.loads((PROMO_DIR / f'site.{language}.json').read_text(encoding='utf-8'))
        copy = json.loads((PROMO_DIR / f'copy.{language}.json').read_text(encoding='utf-8'))
        target = site_dir / site['path'] / 'index.html'
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(build_page(site, copy, available[language]), encoding='utf-8')
        print(f'[promo site] wrote {target.relative_to(site_dir)} screens={len(available[language]["screens"])}'
              f' video={bool(available[language]["video"])}')
    (site_dir / 'sitemap.xml').write_text(build_sitemap(), encoding='utf-8')


if __name__ == '__main__':
    main()
