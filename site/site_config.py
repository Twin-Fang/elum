"""사이트 설정 단일 원본: 주소 · 스토어 링크 · 언어 · 안내 글 목록"""
from dataclasses import dataclass

# 공개 주소 (끝에 / 포함). 앱·서버·스토어 원본이 같은 주소를 쓴다
SITE_URL = 'https://elum.suhsaechan.kr/'
APP_STORE_URL = 'https://apps.apple.com/kr/app/id6792970508'
APP_STORE_ID = '6792970508'
GOOGLE_PLAY_URL = 'https://play.google.com/store/apps/details?id=kr.twinfang.elum'
CONTACT_EMAIL = 'chan4760@gmail.com'
SITE_NAME = '이룸 ELUM'


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
    'aba-principles',
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
    'aba-principles': 'lumi_cards.webp',
    'task-analysis': 'morning.webp',
    'rewards': 'lumi_crown.webp',
    'morning-routine': 'school.webp',
    'adhd-routine': 'outside.webp',
    'developmental-disability-routine': 'friends.webp',
    'learning-homework': 'chores.webp',
}
