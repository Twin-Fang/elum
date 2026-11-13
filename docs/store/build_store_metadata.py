#!/usr/bin/env python3
"""
스토어 문구 원본(docs/store/listing/<언어>/) > iOS·Play fastlane metadata 생성 + 검사 (#1351)
검사 4개: 빈 값, 글자 수 한도, 효과 약속 문장, iOS 구독 안내(EULA) 유무

사용:
  python3 docs/store/build_store_metadata.py          # 생성
  python3 docs/store/build_store_metadata.py --check  # 생성 결과가 커밋본과 같은지만 확인 (다르면 exit 1)
"""
import re
import sys
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
LISTING_SOURCE_DIRECTORY = REPOSITORY_ROOT / 'docs/store/listing'
IOS_METADATA_DIRECTORY = REPOSITORY_ROOT / 'client/ios/fastlane/metadata'
PLAY_METADATA_DIRECTORY = REPOSITORY_ROOT / 'client/android/fastlane/metadata/android'

# 원본 언어 > (App Store Connect 로케일, Play 로케일) — 코드 규칙은 docs/store/locales/README.md
STORE_LOCALE_BY_LANGUAGE = {
    'ko': ('ko', 'ko-KR'),
    'en': ('en-US', 'en-US'),
    'ja': ('ja', 'ja-JP'),
    'zh': ('zh-Hans', 'zh-CN'),
    'es': ('es-MX', 'es-419'),
}

# 원본 파일 > 글자 수 한도 (스토어 규격)
CHARACTER_LIMIT_BY_SOURCE_FILE = {
    'ios_name.txt': 30,
    'ios_subtitle.txt': 30,
    'ios_keywords.txt': 100,
    'ios_promotional_text.txt': 170,
    'play_title.txt': 30,
    'play_short_description.txt': 80,
    'description.txt': 4000,
}
# 한국어는 배포 때 Fastfile 이 CHANGELOG 로 채움 > 다른 언어만 고정 문구
OPTIONAL_SOURCE_FILES = {'ios_release_notes.txt'}
IOS_DESCRIPTION_LIMIT = 4000
IOS_SUBSCRIPTION_NOTICE_FILE = 'ios_subscription_notice.txt'
# 가이드라인 3.1.2: 자동 갱신 구독 설명에 EULA 링크 필수 (#1081)
APPLE_EULA_URL = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'

# 모든 로케일 공통 주소 (언어별 방침 페이지 없음)
PRIVACY_POLICY_URL = 'https://elum.suhsaechan.kr/privacy.html'
SUPPORT_URL = 'https://elum.suhsaechan.kr/'

# 효과를 약속하는 문장 (검색어로 쓰는 '치료' 단어 자체는 허용, 앱이 치료한다는 문장만 차단)
EFFICACY_CLAIM_PATTERN = re.compile(
    r'치료해요|치료돼요|치료됩니다|좋아져요|나아져요|효과가 있|효과를 보|'
    r'\bcures?\b|\btreats? (?:autism|adhd)|proven to|'
    r'治ります|治療できます|効果があります|'
    r'治愈|治好|'
    r'\bcura\b|\bcurar\b'
)


def read_source_text(language_directory: Path, file_name: str) -> str:
    return (language_directory / file_name).read_text(encoding='utf-8').strip()


def find_problems_in_language(language: str) -> list[str]:
    """언어 1개 원본 검사 > 문제 목록 (없으면 빈 목록)"""
    language_directory = LISTING_SOURCE_DIRECTORY / language
    problems = []

    # 필수 파일, 빈 값, 글자 수
    for file_name, character_limit in CHARACTER_LIMIT_BY_SOURCE_FILE.items():
        if not (language_directory / file_name).is_file():
            problems.append(f'{language}/{file_name}: missing')
            continue
        text = read_source_text(language_directory, file_name)
        if not text:
            problems.append(f'{language}/{file_name}: empty')
        elif len(text) > character_limit:
            problems.append(f'{language}/{file_name}: {len(text)} > {character_limit} chars')

    # iOS 키워드: 쉼표 뒤 공백 = 100자 낭비, 중복 단어
    keywords_path = language_directory / 'ios_keywords.txt'
    if keywords_path.is_file():
        keywords = read_source_text(language_directory, 'ios_keywords.txt').split(',')
        if any(keyword != keyword.strip() or not keyword for keyword in keywords):
            problems.append(f'{language}/ios_keywords.txt: space or empty item around comma')
        duplicated_keywords = {keyword for keyword in keywords if keywords.count(keyword) > 1}
        if duplicated_keywords:
            problems.append(f'{language}/ios_keywords.txt: duplicated {sorted(duplicated_keywords)}')

    # 구독 안내 (EULA 링크) + 합친 iOS 설명 길이
    notice_path = language_directory / IOS_SUBSCRIPTION_NOTICE_FILE
    if not notice_path.is_file() or APPLE_EULA_URL not in notice_path.read_text(encoding='utf-8'):
        problems.append(f'{language}/{IOS_SUBSCRIPTION_NOTICE_FILE}: missing EULA link')
    elif (language_directory / 'description.txt').is_file():
        ios_description_length = len(build_ios_description(language_directory))
        if ios_description_length > IOS_DESCRIPTION_LIMIT:
            problems.append(f'{language}: iOS description {ios_description_length} > {IOS_DESCRIPTION_LIMIT} chars')

    # 효과 약속 문장 (사용자에게 보이는 파일 전부)
    for source_path in sorted(language_directory.glob('*.txt')):
        claim_match = EFFICACY_CLAIM_PATTERN.search(source_path.read_text(encoding='utf-8'))
        if claim_match:
            problems.append(f'{language}/{source_path.name}: efficacy claim "{claim_match.group(0)}"')
    return problems


def build_ios_description(language_directory: Path) -> str:
    """공용 설명 + 구독 안내 > iOS 설명 (Play 는 공용 설명만)"""
    description = read_source_text(language_directory, 'description.txt')
    subscription_notice = read_source_text(language_directory, IOS_SUBSCRIPTION_NOTICE_FILE)
    return f'{description}\n\n{subscription_notice}'


def build_output_files() -> dict[Path, str]:
    """원본 전체 > {출력 경로: 내용}"""
    output_files = {}
    for language, (ios_locale, play_locale) in STORE_LOCALE_BY_LANGUAGE.items():
        language_directory = LISTING_SOURCE_DIRECTORY / language
        ios_directory = IOS_METADATA_DIRECTORY / ios_locale
        play_directory = PLAY_METADATA_DIRECTORY / play_locale

        # iOS deliver 파일명 규격
        output_files[ios_directory / 'name.txt'] = read_source_text(language_directory, 'ios_name.txt')
        output_files[ios_directory / 'subtitle.txt'] = read_source_text(language_directory, 'ios_subtitle.txt')
        output_files[ios_directory / 'keywords.txt'] = read_source_text(language_directory, 'ios_keywords.txt')
        output_files[ios_directory / 'promotional_text.txt'] = read_source_text(language_directory, 'ios_promotional_text.txt')
        output_files[ios_directory / 'description.txt'] = build_ios_description(language_directory)
        output_files[ios_directory / 'privacy_url.txt'] = PRIVACY_POLICY_URL
        output_files[ios_directory / 'support_url.txt'] = SUPPORT_URL
        if (language_directory / 'ios_release_notes.txt').is_file():
            output_files[ios_directory / 'release_notes.txt'] = read_source_text(language_directory, 'ios_release_notes.txt')

        # Play supply 파일명 규격
        output_files[play_directory / 'title.txt'] = read_source_text(language_directory, 'play_title.txt')
        output_files[play_directory / 'short_description.txt'] = read_source_text(language_directory, 'play_short_description.txt')
        output_files[play_directory / 'full_description.txt'] = read_source_text(language_directory, 'description.txt')
    return {path: text + '\n' for path, text in output_files.items()}


def main() -> int:
    is_check_only = '--check' in sys.argv[1:]

    # 원본 검사 (실패 시 생성하지 않음)
    problems = [problem for language in STORE_LOCALE_BY_LANGUAGE for problem in find_problems_in_language(language)]
    if problems:
        print('[store metadata] rejected : source problems')
        for problem in problems:
            print(f'  - {problem}')
        return 1

    output_files = build_output_files()
    if is_check_only:
        stale_paths = [
            path for path, text in output_files.items()
            if not path.is_file() or path.read_text(encoding='utf-8') != text
        ]
        if stale_paths:
            print('[store metadata] stale : run build_store_metadata.py')
            for path in stale_paths:
                print(f'  - {path.relative_to(REPOSITORY_ROOT)}')
            return 1
        print(f'[store metadata] ok : {len(output_files)} files in sync')
        return 0

    for path, text in output_files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8')
    print(f'[store metadata] built : {len(output_files)} files')
    return 0


if __name__ == '__main__':
    sys.exit(main())
