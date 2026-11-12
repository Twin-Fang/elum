"""이룸 소개 사이트 생성: 문구(content/*.json) + 틀 > 정적 사이트 폴더

사용: python3 -I site/build_site.py --out <폴더> [--languages ko,en] [--date 2026-11-12]
출력: 언어별 첫 화면 · 안내 글 목록 · 안내 글, sitemap.xml, robots.txt, assets/**, 손으로 관리하는 페이지(static/**)
필요: 파이썬 표준 라이브러리만 (그림은 prepare_images.py 가 미리 만들어 둔 assets/img 를 그대로 복사)
"""
import argparse
import datetime
import json
import pathlib
import shutil
import sys

SITE_DIR = pathlib.Path(__file__).resolve().parent
# -I(격리 모드)로 실행하면 스크립트 폴더가 import 경로에 없음
sys.path.insert(0, str(SITE_DIR))

import site_config  # noqa: E402
from site_frame import page_url  # noqa: E402
from site_guides import build_guide_index, build_guide_page  # noqa: E402
from site_home import build_home  # noqa: E402

# 사이트맵에 싣는 손으로 관리하는 페이지 (초대·연결 링크 페이지는 검색 제외라 싣지 않음)
STATIC_SITEMAP_PATHS = ['privacy.html', 'delete.html']


def load_json(path: pathlib.Path) -> dict:
    """문구 파일 읽기 (없거나 깨졌으면 어느 파일인지 알리고 멈춤)"""
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f'[site build] content file unreadable : {path.relative_to(SITE_DIR)} ({error})')


def load_guides(language_code: str) -> dict:
    """언어 1개의 안내 글 전부 (목록 순서 유지)"""
    return {slug: load_json(SITE_DIR / f'content/guides/{slug}.{language_code}.json')
            for slug in site_config.GUIDE_SLUGS}


def write_page(out_dir: pathlib.Path, language, path: str, page_html: str):
    """언어 + 경로 > index.html 쓰기"""
    target = out_dir / language.path_prefix / path / 'index.html'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(page_html, encoding='utf-8')


def build_sitemap(paths: list, modified_date: str) -> str:
    """사이트맵: 번역 페이지(언어별 주소 연결) + 손으로 관리하는 페이지"""
    entries = []
    for path in paths:
        alternates = ''.join(
            f'<xhtml:link rel="alternate" hreflang="{language.hreflang}" href="{page_url(language, path)}"/>'
            for language in site_config.LANGUAGES)
        entries.extend(f'  <url><loc>{page_url(language, path)}</loc><lastmod>{modified_date}</lastmod>{alternates}</url>'
                       for language in site_config.LANGUAGES)
    entries.extend(f'  <url><loc>{site_config.SITE_URL}{path}</loc></url>' for path in STATIC_SITEMAP_PATHS)
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n'
            + '\n'.join(entries) + '\n</urlset>\n')


def build_robots() -> str:
    """robots.txt: 전체 허용, 10분짜리 코드가 실리는 초대·연결 링크만 제외"""
    return f'User-agent: *\nAllow: /\nDisallow: /invite/\nDisallow: /link/\nSitemap: {site_config.SITE_URL}sitemap.xml\n'


def main():
    parser = argparse.ArgumentParser(description='이룸 소개 사이트 생성')
    parser.add_argument('--out', required=True, help='출력 폴더 (있으면 비우고 다시 만듦)')
    parser.add_argument('--languages', help='미리 보기용: 만들 언어만 쉼표로 (기본 전체)')
    parser.add_argument('--date', default=datetime.date.today().isoformat(), help='고친 날 (사이트맵 · 글 수정일)')
    arguments = parser.parse_args()

    # 미리 보기: 일부 언어만 (언어별 주소 연결도 그 언어만)
    if arguments.languages:
        wanted_codes = arguments.languages.split(',')
        site_config.LANGUAGES[:] = [language for language in site_config.LANGUAGES if language.code in wanted_codes]

    out_dir = pathlib.Path(arguments.out).resolve()
    if out_dir.exists():
        shutil.rmtree(out_dir)
    # 손으로 관리하는 페이지 > 자산 순서로 복사 (같은 이름이면 자산이 이김)
    shutil.copytree(SITE_DIR / 'static', out_dir)
    shutil.copytree(SITE_DIR / 'assets', out_dir / 'assets', dirs_exist_ok=True)

    translated_paths = ['', 'guide/'] + [f'guide/{slug}/' for slug in site_config.GUIDE_SLUGS]
    for language in site_config.LANGUAGES:
        ui = load_json(SITE_DIR / f'content/{language.code}.json')
        guides = load_guides(language.code)
        write_page(out_dir, language, '', build_home(language, ui, guides))
        write_page(out_dir, language, 'guide/', build_guide_index(language, ui, guides))
        for slug in site_config.GUIDE_SLUGS:
            write_page(out_dir, language, f'guide/{slug}/', build_guide_page(language, ui, guides, slug, arguments.date))

    (out_dir / 'sitemap.xml').write_text(build_sitemap(translated_paths, arguments.date), encoding='utf-8')
    (out_dir / 'robots.txt').write_text(build_robots(), encoding='utf-8')
    page_count = len(translated_paths) * len(site_config.LANGUAGES)
    print(f'[site build] {page_count} pages, {len(site_config.LANGUAGES)} languages > {out_dir}')


if __name__ == '__main__':
    main()
