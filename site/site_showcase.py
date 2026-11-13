"""첫 화면 연출 조각: 기기 속 앱 화면·영상, 칭찬과 보상 칸, 이런 분들 칸 예시 행동 카드"""
from site_config import (APP_FLOW_REWARD_START_SECONDS, APP_SCREEN_NAMES, AUDIENCE_EXAMPLE_CARDS, Language,
                         to_app_screen_file_name, to_app_screen_language)
from site_frame import build_store_buttons, escape, page_href

# 기기 속 화면 순서: 앱 화면 2장(적기, 확인) > 앱 시연 영상(따라 하기 > 보상)
PHONE_STILL_SCREEN_NAMES = APP_SCREEN_NAMES[:2]
# 단계마다 기기 옆에 튀어나오는 그림 (적기: 반짝임, 확인: 카드, 따라 하기: 별, 보상: 선물)
PHONE_POP_IMAGES = ['pop_sparkles.svg', 'cards.webp', 'pop_star.webp', 'aba_reward.webp']
# 칭찬과 보상 칸 3줄 그림 (칭찬 별 장면, 보상 장면, 보상 상자)
REWARD_ITEM_IMAGES = ['flow_{language}_praise.webp', 'flow_{language}_reward.webp', 'aba_reward.webp']


def build_still_screen(file_name: str, index: int) -> str:
    """기기 속 앱 화면 1장 (첫 장만 먼저 불러옴)"""
    loading_attribute = 'fetchpriority="high"' if index == 0 else 'loading="lazy"'
    return f'<img class="still" src="/assets/img/{file_name}" alt="" width="330" height="717" {loading_attribute} decoding="async"/>'


def build_app_phone(language: Language, label: str, step_titles: list) -> str:
    """기기 틀 + 앱 화면 2장 + 시연 영상 + 같은 순서로 켜지는 단계 칩 4개 (재생 순서는 site.js)"""
    screen_language = to_app_screen_language(language.code)
    stills = ''.join(build_still_screen(to_app_screen_file_name(language.code, name), index)
                     for index, name in enumerate(PHONE_STILL_SCREEN_NAMES))
    video = (f'<video class="flow" muted playsinline preload="none" poster="/assets/img/flow_{screen_language}_poster.webp" '
             f'data-src="/assets/video/flow_{screen_language}.mp4" '
             f'data-reward-start="{APP_FLOW_REWARD_START_SECONDS[screen_language]}"></video>')
    steps = ''.join(f'<li style="--i:{index}">{escape(title)}<i></i></li>' for index, title in enumerate(step_titles))
    pops = ''.join(f'<img class="pop pop-{index}" src="/assets/img/{name}" alt="" width="64" height="64"/>'
                   for index, name in enumerate(PHONE_POP_IMAGES))
    return (f'<div class="phone-stage" aria-hidden="true">{pops}</div>'
            f'<div class="phone" role="img" aria-label="{escape(label)}"><div class="phone-screen">{stills}{video}</div></div>'
            f'<ol class="phone-steps" aria-hidden="true">{steps}</ol>')


def build_rewards_section(language: Language, ui: dict, rewards: dict) -> str:
    """칭찬과 보상 칸: 장면 그림과 이야기가 좌우로 번갈아 3줄 > 그 자리에서 앱 받기"""
    screen_language = to_app_screen_language(language.code)
    rows = ''.join(
        f'<li class="story-row reveal{" flip" if index % 2 else ""}">'
        f'<div class="story-shot{" box" if index == 2 else ""}"><img src="/assets/img/{image.format(language=screen_language)}" '
        f'alt="" loading="lazy" decoding="async"/></div>'
        f'<div class="story-text"><span class="story-num">{index + 1}</span><h3>{escape(item["title"])}</h3>'
        f'<p>{escape(item["body"])}</p></div></li>'
        for index, (image, item) in enumerate(zip(REWARD_ITEM_IMAGES, rewards['items'])))
    return f"""<section id="rewards">
  <div class="wrap">
    <p class="tag">{escape(rewards['tag'])}</p>
    <h2>{escape(rewards['title'])}</h2>
    <ol class="story">{rows}</ol>
    <div class="story-cta reveal">
      <div><p class="story-cta-title">{escape(rewards['ctaTitle'])}</p><p class="story-cta-hint">{escape(rewards['ctaHint'])}</p></div>
      <div class="cta">{build_store_buttons(ui, 'rewards')}</div>
    </div>
    <a class="more" href="{page_href(language, 'guide/rewards/')}">{escape(rewards['link'])}</a>
  </div>
</section>"""


def build_audience_tiles(items: list) -> str:
    """이런 분들 칸 4개: 앱 예시 행동 카드 3장 묶음(마우스 올리면 펼침) + 제목 + 설명"""
    return ''.join(
        f'<div class="tile audience-tile reveal" style="--i:{index}"><div class="card-fan">'
        + ''.join(f'<img src="/assets/img/card_{card_name}.webp" alt="" width="100" height="100" loading="lazy" '
                  f'decoding="async" style="--n:{card_index}"/>' for card_index, card_name in enumerate(card_names))
        + f'</div><h3>{escape(item["title"])}</h3><p>{escape(item["body"])}</p></div>'
        for index, (item, card_names) in enumerate(zip(items, AUDIENCE_EXAMPLE_CARDS)))

