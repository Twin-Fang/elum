"""공통 틀: head(검색·공유 정보) · 머리 · 바닥 · 스토어 버튼 · 앱 받기 띠"""
import html
import json

from site_config import (APP_STORE_ID, APP_STORE_URL, BUSINESS_NAME, BUSINESS_REGISTRATION_NUMBER,
                         BUSINESS_REPRESENTATIVE, CONTACT_EMAIL, DEFAULT_LANGUAGE, GOOGLE_PLAY_URL, GUIDE_IMAGES, LANGUAGES,
                         SITE_NAME, SITE_URL, Language, to_og_image_path, to_privacy_path)

APPLE_ICON = ('<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M16.37 12.6c.02 2.6 2.28 3.47 2.3 3.48'
              '-.02.06-.36 1.24-1.19 2.45-.72 1.05-1.46 2.09-2.63 2.11-1.15.02-1.52-.68-2.83-.68-1.32 0-1.73.66-2.82.7-1.13.04-1.99'
              '-1.13-2.71-2.18-1.48-2.14-2.61-6.04-1.09-8.68.75-1.31 2.1-2.14 3.56-2.16 1.11-.02 2.16.75 2.84.75.68 0 1.95-.93 3.29-.79'
              '.56.02 2.13.23 3.14 1.71-.08.05-1.87 1.09-1.86 3.27M14.2 4.99c.6-.73 1.01-1.74.9-2.75-.87.03-1.92.58-2.54 1.31-.56.64'
              '-1.05 1.67-.92 2.66.97.07 1.96-.49 2.56-1.22"/></svg>')
PLAY_ICON = ('<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="#34A853" d="M3.6 2.3 13.5 12l-9.9 9.7c-.4-.2-.6-.6-.6-1.1V3.4'
             'c0-.5.2-.9.6-1.1z"/><path fill="#FBBC04" d="m16.9 15.4-3.4-3.4 3.4-3.4 3.8 2.2c1 .6 1 1.8 0 2.4z"/><path fill="#4285F4"'
             ' d="M3.6 2.3c.3-.1.7-.1 1 .1l12.3 7.1-3.4 3.4z"/><path fill="#EA4335" d="m13.5 12 3.4 3.4-12.3 7.1c-.3.2-.7.2-1 .1z"/></svg>')


def escape(text: str) -> str:
    """본문 글자 > HTML 안전 글자"""
    return html.escape(text, quote=True)


def page_url(language: Language, path: str) -> str:
    """언어 + 언어 안 경로(`guide/rewards/`) > 전체 주소"""
    return SITE_URL + language.path_prefix + path


def page_href(language: Language, path: str) -> str:
    """언어 + 언어 안 경로 > 사이트 안 링크 (`/en/guide/`)"""
    return '/' + language.path_prefix + path


def build_alternate_links(path: str) -> str:
    """같은 글의 언어별 주소 (hreflang, 기본은 한국어)"""
    links = [f'<link rel="alternate" hreflang="{language.hreflang}" href="{page_url(language, path)}"/>'
             for language in LANGUAGES]
    links.append(f'<link rel="alternate" hreflang="x-default" href="{page_url(DEFAULT_LANGUAGE, path)}"/>')
    return '\n'.join(links)


def build_store_buttons(ui: dict, placement: str) -> str:
    """App Store · Google Play 버튼 2개 ([placement]: 누른 자리 구분용 표시)"""
    return (f'<a class="store" data-store="ios" data-place="{placement}" href="{APP_STORE_URL}" rel="noopener">'
            f'{APPLE_ICON}<span>{escape(ui["store"]["appStore"])}</span></a>'
            f'<a class="store" data-store="android" data-place="{placement}" href="{GOOGLE_PLAY_URL}" rel="noopener">'
            f'{PLAY_ICON}<span>{escape(ui["store"]["googlePlay"])}</span></a>')


def build_structured_data(items: list) -> str:
    """구조화 데이터 묶음 > script 태그"""
    return '\n'.join(f'<script type="application/ld+json">{json.dumps(item, ensure_ascii=False)}</script>'
                     for item in items)


def build_language_menu(language: Language, path: str, ui: dict) -> str:
    """언어 바꾸기 메뉴 (같은 글의 다른 언어로)"""
    current_mark = ' aria-current="true"'
    options = ''.join(
        f'<a href="{page_href(other, path)}" hreflang="{other.hreflang}" lang="{other.hreflang}"'
        f'{current_mark if other == language else ""}>{other.label}</a>'
        for other in LANGUAGES)
    return (f'<details class="lang"><summary aria-label="{escape(ui["languageMenu"])}">'
            f'<span>{language.label}</span></summary><div class="lang-list">{options}</div></details>')


def build_guide_cards(language: Language, guides: dict, slugs: list, class_name: str = 'guidecards') -> str:
    """안내 글 카드 묶음 (그림 + 제목 + 설명). 첫 화면 · 목록 · 이어 읽기 공통"""
    cards = ''.join(
        f'<a class="guidecard reveal" style="--i:{index}" href="{page_href(language, f"guide/{slug}/")}">'
        f'<img src="/assets/img/{GUIDE_IMAGES[slug]}" alt="" width="72" height="72" loading="lazy" decoding="async"/>'
        f'<span><b>{escape(guides[slug]["heading"])}</b><small>{escape(guides[slug]["description"])}</small></span></a>'
        for index, slug in enumerate(slugs) if slug in guides)
    return f'<div class="{class_name}">{cards}</div>'


def build_download_section(ui: dict) -> str:
    """글 끝 앱 받기 묶음"""
    download = ui['download']
    return f"""<section class="download reveal">
  <div class="wrap download-box">
    <img src="/assets/img/friends.webp" alt="" width="240" height="240" loading="lazy" decoding="async"/>
    <div>
      <h2>{escape(download['title'])}</h2>
      <p class="sub">{escape(download['sub'])}</p>
      <div class="cta">{build_store_buttons(ui, 'download')}</div>
    </div>
  </div>
</section>"""


def render_page(language: Language, ui: dict, path: str, title: str, description: str, body: str,
                structured_data: list, og_image: str = '', og_type: str = 'website',
                is_translated: bool = True, keywords: str = '') -> str:
    """페이지 1장: head(제목 · 설명 · 대표 주소 · 언어별 주소 · 공유 정보 · 구조화 데이터) + 머리 + 본문 + 바닥

    [is_translated] 가 False 면 언어별 주소를 싣지 않음 (한 언어만 있는 글)
    [og_image] 를 비우면 그 언어의 공유 썸네일
    """
    url = page_url(language, path)
    og_image = og_image or to_og_image_path(language.code)
    nav = ui['nav']
    footer = ui['footer']
    alternates = build_alternate_links(path) if is_translated else ''
    keywords_meta = f'<meta name="keywords" content="{escape(keywords)}"/>' if keywords else ''
    business = footer['business']
    return f"""<!DOCTYPE html>
<html lang="{language.hreflang}">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>{escape(title)}</title>
<meta name="description" content="{escape(description)}"/>
{keywords_meta}
<link rel="canonical" href="{url}"/>
{alternates}
<link rel="icon" href="/assets/lumi.svg"/>
<meta name="theme-color" content="#F7F2EF"/>
<meta name="apple-itunes-app" content="app-id={APP_STORE_ID}"/>
<meta property="og:title" content="{escape(title)}"/>
<meta property="og:description" content="{escape(description)}"/>
<meta property="og:type" content="{og_type}"/>
<meta property="og:url" content="{url}"/>
<meta property="og:site_name" content="{SITE_NAME}"/>
<meta property="og:locale" content="{language.og_locale}"/>
<meta property="og:image" content="{SITE_URL}{og_image}"/>
<meta name="twitter:card" content="summary_large_image"/>
{build_structured_data(structured_data)}
<link rel="preconnect" href="https://cdn.jsdelivr.net"/>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable-dynamic-subset.min.css"/>
<link rel="stylesheet" href="/assets/site.css"/>
<link rel="stylesheet" href="/assets/showcase.css"/>
</head>
<body>
<a class="skip" href="#main">{escape(ui['skipToContent'])}</a>
<header class="top">
  <div class="wrap bar">
    <a class="brand" href="{page_href(language, '')}"><img src="/assets/logo.svg" alt="{SITE_NAME}" width="92" height="28"/></a>
    <nav aria-label="{escape(nav['label'])}">
      <a href="{page_href(language, 'guide/')}">{escape(nav['guides'])}</a>
      <a href="{page_href(language, '')}#faq">{escape(nav['faq'])}</a>
    </nav>
    {build_language_menu(language, path, ui)}
    <a class="get" href="{page_href(language, '')}#download">{escape(nav['download'])}</a>
  </div>
</header>

<main id="main">
{body}
</main>

<footer class="bottom">
  <div class="wrap foot">
    <img src="/assets/logo.svg" alt="{SITE_NAME}" width="80" height="24" loading="lazy"/>
    <nav aria-label="{escape(footer['label'])}">
      <a href="{page_href(language, 'guide/')}">{escape(nav['guides'])}</a>
      <a href="/{to_privacy_path(language.code)}">{escape(footer['privacy'])}</a>
      <a href="/delete.html">{escape(footer['delete'])}</a>
      <a href="mailto:{CONTACT_EMAIL}">{escape(footer['contact'])}</a>
    </nav>
    <p class="fine">{escape(footer['notice'])}</p>
    <dl class="business">
      <div><dt>{escape(business['name'])}</dt><dd>{BUSINESS_NAME}</dd></div>
      <div><dt>{escape(business['representative'])}</dt><dd>{BUSINESS_REPRESENTATIVE}</dd></div>
      <div><dt>{escape(business['registration'])}</dt><dd>{BUSINESS_REGISTRATION_NUMBER}</dd></div>
      <div><dt>{escape(business['contact'])}</dt><dd><a href="mailto:{CONTACT_EMAIL}">{CONTACT_EMAIL}</a></dd></div>
    </dl>
    <p class="fine">© 2026 {BUSINESS_NAME}</p>
  </div>
</footer>

<div class="getbar" id="getbar" hidden>
  <span>{escape(ui['download']['bar'])}</span>
  <div class="cta">{build_store_buttons(ui, 'bar')}</div>
</div>
<script src="/assets/site.js" defer></script>
</body>
</html>
"""
