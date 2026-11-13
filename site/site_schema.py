"""구조화 데이터(JSON-LD): 앱 · 자주 묻는 질문 · 글 · 경로 · 만드는 순서"""
import html
import re

from site_config import APP_STORE_URL, GOOGLE_PLAY_URL, SITE_NAME, SITE_URL

ORGANIZATION = {'@type': 'Organization', 'name': 'Twin-Fang', 'url': SITE_URL}


def plain_text(text: str) -> str:
    """HTML 문구 > 평문"""
    return html.unescape(re.sub(r'<[^>]+>', '', text))


def application_schema(language_code: str, description: str, url: str) -> dict:
    """앱 정보 (무료 설치, iOS·Android)"""
    return {
        '@context': 'https://schema.org', '@type': 'MobileApplication',
        'name': SITE_NAME, 'alternateName': ['이룸', 'ELUM'], 'description': description,
        'applicationCategory': 'EducationalApplication', 'operatingSystem': 'iOS, Android',
        'inLanguage': language_code, 'url': url,
        'downloadUrl': [APP_STORE_URL, GOOGLE_PLAY_URL], 'installUrl': [APP_STORE_URL, GOOGLE_PLAY_URL],
        'image': SITE_URL + 'assets/og.png', 'publisher': ORGANIZATION,
        'offers': {'@type': 'Offer', 'price': '0', 'priceCurrency': 'KRW' if language_code == 'ko' else 'USD'},
    }


def faq_schema(items: list) -> dict:
    """자주 묻는 질문 묶음 ({q, a} 목록)"""
    return {
        '@context': 'https://schema.org', '@type': 'FAQPage',
        'mainEntity': [{'@type': 'Question', 'name': item['q'],
                        'acceptedAnswer': {'@type': 'Answer', 'text': plain_text(item['a'])}} for item in items],
    }


def article_schema(language_code: str, title: str, description: str, url: str, image_url: str,
                   published: str, modified: str) -> dict:
    """안내 글 1개"""
    return {
        '@context': 'https://schema.org', '@type': 'Article', 'headline': title, 'description': description,
        'inLanguage': language_code, 'mainEntityOfPage': url, 'image': image_url,
        'datePublished': published, 'dateModified': modified,
        'author': ORGANIZATION, 'publisher': ORGANIZATION,
    }


def breadcrumb_schema(trail: list) -> dict:
    """경로 ((이름, 주소) 목록, 앞에서부터)"""
    return {
        '@context': 'https://schema.org', '@type': 'BreadcrumbList',
        'itemListElement': [{'@type': 'ListItem', 'position': position, 'name': name, 'item': url}
                            for position, (name, url) in enumerate(trail, 1)],
    }


def how_to_schema(name: str, steps: list) -> dict:
    """행동 카드 예시 > 순서 ({title, body} 목록)"""
    return {
        '@context': 'https://schema.org', '@type': 'HowTo', 'name': name,
        'step': [{'@type': 'HowToStep', 'position': position, 'name': step['title'], 'text': step['body']}
                 for position, step in enumerate(steps, 1)],
    }
