"""첫 화면: 머리(카드 시연 · 믿음 띠) > 쓰는 순서 > ABA 원리 4가지 > 보호자와 함께 > 그림 방식 > 이런 분께 > 안내 글 > 앱 받기 > 자주 묻는 질문 > 문의"""
from site_config import ABA_PRINCIPLE_IMAGES, CONTACT_EMAIL, GUIDE_IMAGES, Language
from site_frame import build_download_section, build_store_buttons, escape, page_href, page_url, render_page
from site_schema import application_schema, faq_schema

# 쓰는 순서 3칸 그림 · 그림 방식 4칸 그림 (문구 순서와 같은 순서)
STEP_IMAGES = ['cards.webp', 'lumi_cards.webp', 'lumi_crown.webp']
STYLE_IMAGES = ['style_emoji.svg', 'style_symbol.svg', 'style_cartoon.webp', 'style_realistic.webp']
AUDIENCE_IMAGES = ['morning.webp', 'school.webp', 'chores.webp', 'outside.webp']
# 첫 화면에 보이는 안내 글 수
HOME_GUIDE_COUNT = 4


def build_card_demo(demo: dict) -> str:
    """카드 시연: 행동 카드 3장이 차례로 체크되고 보상이 나타남 (CSS 애니메이션)"""
    cards = ''.join(
        f'<li class="democard" style="--i:{index}"><span class="emoji" aria-hidden="true">{card["emoji"]}</span>'
        f'<span class="text"><b>{escape(card["title"])}</b><small>{escape(card["body"])}</small></span>'
        f'<i class="check" aria-hidden="true"></i></li>'
        for index, card in enumerate(demo['cards']))
    return f"""<div class="demo" role="img" aria-label="{escape(demo['label'])}">
  <p class="demo-title">{escape(demo['routine'])}</p>
  <ol>{cards}</ol>
  <p class="demo-reward"><span aria-hidden="true">⭐</span> {escape(demo['reward'])}</p>
</div>"""


def build_tiles(items: list, images: list, class_name: str) -> str:
    """그림 + 제목 + 한 줄 설명 타일 묶음"""
    return ''.join(
        f'<div class="tile reveal" style="--i:{index}">'
        f'<img src="/assets/img/{images[index]}" alt="" width="96" height="96" loading="lazy" decoding="async"/>'
        f'<h3>{escape(item["title"])}{build_badge(item)}</h3><p>{escape(item["body"])}</p></div>'
        for index, item in enumerate(items))


def build_trust_strip(items: list) -> str:
    """머리 아래 믿음 띠: 사실만 적은 짧은 알약 묶음"""
    return '<ul class="trust">' + ''.join(f'<li>{escape(item)}</li>' for item in items) + '</ul>'


def build_principles(items: list) -> str:
    """ABA 원리 4가지 카드: 번호 + 그림 + 원리 + 한 줄 설명 + 이룸에서 하는 일"""
    return ''.join(
        f'<li class="principle reveal" style="--i:{index}"><span class="num">{index + 1}</span>'
        f'<img src="/assets/img/{ABA_PRINCIPLE_IMAGES[index]}" alt="" width="88" height="88" loading="lazy" decoding="async"/>'
        f'<h3>{escape(item["title"])}</h3><p>{escape(item["body"])}</p>'
        f'<p class="inapp">{escape(item["app"])}</p></li>'
        for index, item in enumerate(items))


def build_badge(item: dict) -> str:
    """타일 제목 옆 작은 표시 (`PRO` 등, 없으면 빈 문자열)"""
    return f' <span class="badge">{escape(item["badge"])}</span>' if item.get('badge') else ''


def build_guide_cards(language: Language, guides: dict, slugs: list) -> str:
    """안내 글 카드 묶음 (그림 + 제목 + 설명)"""
    return ''.join(
        f'<a class="guidecard reveal" style="--i:{index}" href="{page_href(language, f"guide/{slug}/")}">'
        f'<img src="/assets/img/{GUIDE_IMAGES[slug]}" alt="" width="72" height="72" loading="lazy" decoding="async"/>'
        f'<span><b>{escape(guides[slug]["heading"])}</b><small>{escape(guides[slug]["description"])}</small></span></a>'
        for index, slug in enumerate(slugs))


def build_faq(items: list) -> str:
    """자주 묻는 질문 (첫 질문만 펼침)"""
    return '\n'.join(
        f'<details{" open" if index == 0 else ""}><summary>{escape(item["q"])}</summary>'
        f'<div class="body">{item["a"]}</div></details>'
        for index, item in enumerate(items))


def build_home(language: Language, ui: dict, guides: dict) -> str:
    """언어 1개의 첫 화면 HTML"""
    home = ui['home']
    hero = home['hero']
    guide_slugs = list(guides)[:HOME_GUIDE_COUNT]
    body = f"""<section class="hero">
  <div class="wrap hero-grid">
    <div class="hero-text">
      <p class="tag">{escape(hero['tag'])}</p>
      <h1>{hero['titleHtml']}</h1>
      <p class="lede">{escape(hero['lede'])}</p>
      <div class="cta">{build_store_buttons(ui, 'hero')}</div>
      <p class="hint">{escape(hero['hint'])}</p>
      {build_trust_strip(home['trust'])}
    </div>
    <div class="hero-visual">
      <img class="hero-art" src="/assets/img/hero.webp" alt="" width="672" height="384" fetchpriority="high"/>
      {build_card_demo(home['demo'])}
    </div>
  </div>
</section>

<section id="how">
  <div class="wrap">
    <p class="tag">{escape(home['steps']['tag'])}</p>
    <h2>{escape(home['steps']['title'])}</h2>
    <div class="tiles three">{build_tiles(home['steps']['items'], STEP_IMAGES, 'step')}</div>
  </div>
</section>

<section id="aba" class="tint">
  <div class="wrap">
    <p class="tag">{escape(home['aba']['tag'])}</p>
    <h2>{escape(home['aba']['title'])}</h2>
    <p class="sub">{escape(home['aba']['sub'])}</p>
    <ol class="principles">{build_principles(home['aba']['items'])}</ol>
    <a class="more" href="{page_href(language, 'guide/aba-principles/')}">{escape(home['aba']['link'])}</a>
  </div>
</section>

<section id="together">
  <div class="wrap together-grid">
    <img class="reveal" src="/assets/img/together.webp" alt="" width="360" height="360" loading="lazy" decoding="async"/>
    <div>
      <p class="tag">{escape(home['together']['tag'])}</p>
      <h2>{escape(home['together']['title'])}</h2>
      <p class="sub">{escape(home['together']['sub'])}</p>
      <ul class="points">{''.join(f'<li class="reveal"><b>{escape(item["title"])}</b><span>{escape(item["body"])}</span></li>' for item in home['together']['items'])}</ul>
      <a class="more" href="{page_href(language, 'guide/caregiver-role/')}">{escape(home['together']['link'])}</a>
    </div>
  </div>
</section>

<section id="styles" class="tint">
  <div class="wrap">
    <p class="tag">{escape(home['styles']['tag'])}</p>
    <h2>{escape(home['styles']['title'])}</h2>
    <p class="sub">{escape(home['styles']['sub'])}</p>
    <div class="tiles four pictures">{build_tiles(home['styles']['items'], STYLE_IMAGES, 'style')}</div>
  </div>
</section>

<section id="for">
  <div class="wrap">
    <p class="tag">{escape(home['audience']['tag'])}</p>
    <h2>{escape(home['audience']['title'])}</h2>
    <div class="tiles four">{build_tiles(home['audience']['items'], AUDIENCE_IMAGES, 'audience')}</div>
  </div>
</section>

<section id="guides" class="tint">
  <div class="wrap">
    <p class="tag">{escape(home['guides']['tag'])}</p>
    <h2>{escape(home['guides']['title'])}</h2>
    <p class="sub">{escape(home['guides']['sub'])}</p>
    <div class="guidecards">{build_guide_cards(language, guides, guide_slugs)}</div>
    <a class="more" href="{page_href(language, 'guide/')}">{escape(home['guides']['more'])}</a>
  </div>
</section>

<div id="download">{build_download_section(ui)}</div>

<section id="faq">
  <div class="wrap narrow">
    <p class="tag">FAQ</p>
    <h2>{escape(home['faq']['title'])}</h2>
    <div class="faq">{build_faq(home['faq']['items'])}</div>
  </div>
</section>

<section id="contact" class="tint">
  <div class="wrap narrow center">
    <h2>{escape(home['contact']['title'])}</h2>
    <p class="sub">{escape(home['contact']['sub'])}</p>
    <a class="mail" href="mailto:{CONTACT_EMAIL}">{CONTACT_EMAIL}</a>
  </div>
</section>"""
    url = page_url(language, '')
    structured_data = [application_schema(language.hreflang, home['description'], url), faq_schema(home['faq']['items'])]
    return render_page(language, ui, '', home['title'], home['description'], body, structured_data,
                       keywords=home.get('keywords', ''))
