"""안내 글: 목록 페이지 + 글 페이지 (본문 > 행동 카드 예시 > 자주 묻는 질문 > 이어 읽기 > 앱 받기)"""
from site_config import GUIDE_IMAGES, GUIDE_SECTION_IMAGES, SITE_URL, Language
from site_frame import build_download_section, build_store_buttons, escape, page_href, page_url, render_page
from site_schema import article_schema, breadcrumb_schema, faq_schema, how_to_schema

# 글을 처음 올린 날 (구조화 데이터 datePublished)
GUIDES_PUBLISHED_DATE = '2026-11-12'


def build_breadcrumb(trail: list) -> str:
    """경로 줄 ((이름, 링크) 목록, 마지막은 지금 글)"""
    links = ''.join(f'<a href="{href}">{escape(name)}</a><i aria-hidden="true">›</i>' for name, href in trail[:-1])
    return f'<nav class="crumb" aria-label="breadcrumb">{links}<span>{escape(trail[-1][0])}</span></nav>'


def build_section(section: dict, image: str | None = None) -> str:
    """글 한 덩이: (있으면) 그림 + 소제목 > 문단들 > (있으면) 목록. 그림이 있으면 카드 모양"""
    paragraphs = ''.join(f'<p>{paragraph}</p>' for paragraph in section.get('paragraphs', []))
    items = section.get('list', [])
    bullet_list = f'<ul>{"".join(f"<li>{item}</li>" for item in items)}</ul>' if items else ''
    heading = f'<h2>{escape(section["heading"])}</h2>'
    if image is None:
        return f'<section class="reveal">{heading}{paragraphs}{bullet_list}</section>'
    picture = f'<img src="/assets/img/{image}" alt="" width="72" height="72" loading="lazy" decoding="async"/>'
    return f'<section class="reveal pictured">{picture}<div>{heading}{paragraphs}{bullet_list}</div></section>'


def build_card_example(cards: dict, step_label: str) -> str:
    """행동 카드 예시: 번호 + 이모지 + 제목 + 한 줄 (앱의 이모지 그림 카드 모양)"""
    items = ''.join(
        f'<li class="excard reveal" style="--i:{index}"><span class="num">{step_label.replace("{n}", str(index + 1))}</span>'
        f'<span class="emoji" aria-hidden="true">{card["emoji"]}</span>'
        f'<b>{escape(card["title"])}</b><small>{escape(card["body"])}</small></li>'
        for index, card in enumerate(cards['items']))
    reward = (f'<p class="exreward"><span aria-hidden="true">⭐</span> {escape(cards["reward"])}</p>'
              if cards.get('reward') else '')
    return f'<section class="example"><h2>{escape(cards["title"])}</h2><ol class="excards">{items}</ol>{reward}</section>'


def build_related(language: Language, guides: dict, slugs: list, heading: str) -> str:
    """이어 읽기 글 링크"""
    links = ''.join(
        f'<a class="guidecard" href="{page_href(language, f"guide/{slug}/")}">'
        f'<img src="/assets/img/{GUIDE_IMAGES[slug]}" alt="" width="72" height="72" loading="lazy" decoding="async"/>'
        f'<span><b>{escape(guides[slug]["heading"])}</b><small>{escape(guides[slug]["description"])}</small></span></a>'
        for slug in slugs if slug in guides)
    return f'<section class="related"><h2>{escape(heading)}</h2><div class="guidecards">{links}</div></section>'


def build_guide_page(language: Language, ui: dict, guides: dict, slug: str, modified_date: str) -> str:
    """안내 글 1개 페이지 HTML"""
    guide = guides[slug]
    labels = ui['guide']
    path = f'guide/{slug}/'
    url = page_url(language, path)
    image_url = f'{SITE_URL}assets/img/{GUIDE_IMAGES[slug]}'
    trail = [(labels['breadcrumbHome'], page_href(language, '')),
             (labels['breadcrumbGuides'], page_href(language, 'guide/')),
             (guide['heading'], page_href(language, path))]
    faq_items = guide.get('faq', [])
    faq = ''
    if faq_items:
        faq_details = ''.join(f'<details><summary>{escape(item["q"])}</summary><div class="body">{item["a"]}</div></details>'
                              for item in faq_items)
        faq = f'<section class="reveal"><h2>{escape(labels["faqHeading"])}</h2><div class="faq">{faq_details}</div></section>'
    cards = guide.get('cards')
    section_images = GUIDE_SECTION_IMAGES.get(slug, {})
    body = f"""<article class="guide">
  <div class="wrap narrow">
    {build_breadcrumb(trail)}
    <header class="guide-head">
      <img src="/assets/img/{GUIDE_IMAGES[slug]}" alt="" width="120" height="120" fetchpriority="high"/>
      <h1>{escape(guide['heading'])}</h1>
      <p class="lede">{escape(guide['lede'])}</p>
      <p class="meta">{escape(labels['minutes'].replace('{n}', str(guide['minutes'])))}</p>
    </header>
    {''.join(build_section(section, section_images.get(index)) for index, section in enumerate(guide['sections']))}
    {build_card_example(cards, labels['stepLabel']) if cards else ''}
    <aside class="inline-cta reveal">
      <div><b>{escape(labels['ctaTitle'])}</b><span>{escape(labels['ctaSub'])}</span></div>
      <div class="cta">{build_store_buttons(ui, 'guide')}</div>
    </aside>
    {faq}
    <p class="notice">{escape(labels['notice'])}</p>
    {build_related(language, guides, guide.get('related', []), labels['related'])}
  </div>
</article>
{build_download_section(ui)}"""
    structured_data = [
        article_schema(language.hreflang, guide['heading'], guide['description'], url, image_url,
                       GUIDES_PUBLISHED_DATE, modified_date),
        breadcrumb_schema([(name, SITE_URL.rstrip('/') + href) for name, href in trail]),
    ]
    if faq_items:
        structured_data.append(faq_schema(faq_items))
    if cards:
        structured_data.append(how_to_schema(cards['title'], cards['items']))
    return render_page(language, ui, path, guide['title'], guide['description'], body, structured_data,
                       og_image=f'assets/img/{GUIDE_IMAGES[slug]}', og_type='article',
                       keywords=guide.get('keywords', ''))


def build_guide_index(language: Language, ui: dict, guides: dict) -> str:
    """안내 글 목록 페이지 HTML"""
    labels = ui['guide']
    path = 'guide/'
    trail = [(labels['breadcrumbHome'], page_href(language, '')), (labels['breadcrumbGuides'], page_href(language, path))]
    cards = ''.join(
        f'<a class="guidecard reveal" style="--i:{index}" href="{page_href(language, f"guide/{slug}/")}">'
        f'<img src="/assets/img/{GUIDE_IMAGES[slug]}" alt="" width="72" height="72" loading="lazy" decoding="async"/>'
        f'<span><b>{escape(guide["heading"])}</b><small>{escape(guide["description"])}</small></span></a>'
        for index, (slug, guide) in enumerate(guides.items()))
    body = f"""<section class="guide-index">
  <div class="wrap narrow">
    {build_breadcrumb(trail)}
    <h1>{escape(labels['indexHeading'])}</h1>
    <p class="lede">{escape(labels['indexSub'])}</p>
    <div class="guidecards wide">{cards}</div>
  </div>
</section>
{build_download_section(ui)}"""
    structured_data = [breadcrumb_schema([(name, SITE_URL.rstrip('/') + href) for name, href in trail])]
    return render_page(language, ui, path, labels['indexTitle'], labels['indexDescription'], body, structured_data,
                       keywords=labels.get('indexKeywords', ''))
