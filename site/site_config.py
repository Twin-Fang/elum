"""사이트 설정 단일 원본: 주소 · 스토어 링크 · 언어 · 안내 글 목록"""
from dataclasses import dataclass

# 공개 주소 (끝에 / 포함). 앱·서버·스토어 원본이 같은 주소를 쓴다
SITE_URL = 'https://elum.suhsaechan.kr/'
APP_STORE_URL = 'https://apps.apple.com/kr/app/id6792970508'
APP_STORE_ID = '6792970508'
GOOGLE_PLAY_URL = 'https://play.google.com/store/apps/details?id=kr.twinfang.elum'
CONTACT_EMAIL = 'chan4760@gmail.com'
SITE_NAME = '이룸 ELUM'

# 사업자 정보 (바닥 표시. passQL 사이트와 같은 사업자)
BUSINESS_NAME = '콜리랩(KOLLYLAB)'
BUSINESS_REPRESENTATIVE = '서새찬'
BUSINESS_REGISTRATION_NUMBER = '331-37-01670'


@dataclass(frozen=True)
class Language:
    """언어 1개: 코드 · 주소 앞부분 · hreflang · og:locale · 화면 이름"""
    code: str
    path_prefix: str
    hreflang: str
    og_locale: str
    label: str


# 순서 = 언어 메뉴 순서. 한국어가 루트(/), 나머지는 /<code>/
LANGUAGES = [
    Language('ko', '', 'ko', 'ko_KR', '한국어'),
    Language('en', 'en/', 'en', 'en_US', 'English'),
    Language('ja', 'ja/', 'ja', 'ja_JP', '日本語'),
    Language('zh', 'zh/', 'zh-Hans', 'zh_CN', '简体中文'),
    Language('es', 'es/', 'es', 'es_ES', 'Español'),
]
DEFAULT_LANGUAGE = LANGUAGES[0]

# 안내 글 주소 조각 (모든 언어가 같은 영문 조각). 순서 = 목록 순서
GUIDE_SLUGS = [
    'action-cards',
    'make-action-cards',
    'aba-principles',
    'why-action-cards',
    'caregiver-role',
    'task-analysis',
    'rewards',
    'morning-routine',
    'adhd-routine',
    'developmental-disability-routine',
    'learning-homework',
]

# 안내 글 대표 그림 (assets/img 의 파일 이름)
GUIDE_IMAGES = {
    'action-cards': 'cards.webp',
    'make-action-cards': 'aba_show.webp',
    'why-action-cards': 'aba_steps.webp',
    'caregiver-role': 'together.webp',
    'aba-principles': 'lumi_cards.webp',
    'task-analysis': 'morning.webp',
    'rewards': 'lumi_crown.webp',
    'morning-routine': 'school.webp',
    'adhd-routine': 'outside.webp',
    'developmental-disability-routine': 'friends.webp',
    'learning-homework': 'chores.webp',
}

# ABA 원리 4가지 그림 (첫 화면 ABA 칸 · 안내 글 소제목 옆. 문구 순서와 같은 순서)
ABA_PRINCIPLE_IMAGES = ['aba_steps.webp', 'aba_show.webp', 'aba_help.webp', 'aba_reward.webp']

# 첫 화면 기기 틀 속 앱 화면 (쓰는 순서 3칸과 같은 순서). 원본: docs/store/promo/screens/<언어>/<이름>.png
APP_SCREEN_NAMES = ['input', 'card_review', 'child_card']
# 앱 화면 캡처가 있는 언어 · 없는 언어는 영어 화면
APP_SCREEN_LANGUAGES = ['ko', 'en']
APP_SCREEN_FALLBACK_LANGUAGE = 'en'


def to_app_screen_file_name(language_code: str, screen_name: str) -> str:
    """언어 · 화면 이름 > assets/img 의 앱 화면 파일 이름 (캡처 없는 언어는 영어)"""
    screen_language = language_code if language_code in APP_SCREEN_LANGUAGES else APP_SCREEN_FALLBACK_LANGUAGE
    return f'screen_{screen_language}_{screen_name}.webp'


# 안내 글 소제목 옆 그림: 글 > {소제목 순서(0부터): 그림}
GUIDE_SECTION_IMAGES = {
    'aba-principles': {1: 'aba_steps.webp', 2: 'aba_show.webp', 3: 'aba_help.webp', 4: 'aba_reward.webp'},
    'why-action-cards': {0: 'aba_show.webp', 1: 'aba_steps.webp', 2: 'aba_help.webp', 3: 'aba_reward.webp'},
}
