"""사이트 그림 준비: 원본(스토어 홍보 그림 · 앱 에셋 · site/art 의 사이트 전용 그림) > site/assets/img 의 가벼운 WebP

사용: python3 -I site/prepare_images.py   (원본 그림이 바뀌었을 때만. 결과는 커밋한다)
필요: Pillow
"""
import pathlib
import shutil
import sys

from PIL import Image

# -I(격리 모드)로 실행하면 스크립트 폴더가 import 경로에 없음
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from site_config import APP_SCREEN_LANGUAGES, APP_SCREEN_NAMES, to_app_screen_file_name  # noqa: E402

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
TARGET_DIR = REPO_ROOT / 'site/assets/img'
PROMO_ART = REPO_ROOT / 'docs/store/promo/art'
# 스토어 홍보용 앱 실제 화면 캡처 (1320x2868)
PROMO_SCREENS = REPO_ROOT / 'docs/store/promo/screens'
APP_IMAGES = REPO_ROOT / 'client/assets/images'
APP_ASSETS = REPO_ROOT / 'client/assets'
# 사이트에만 쓰는 그림 원본 (이미지 하네스로 그린 512·768 PNG)
SITE_ART = REPO_ROOT / 'site/art'

# (원본, 결과 이름, 가로 픽셀, 투명 유지)
RASTER_IMAGES = [
    (PROMO_ART / 'scene_06.png', 'friends.webp', 480, False),
    (APP_IMAGES / 'aba_intro_lumi.png', 'lumi_cards.webp', 512, True),
    (APP_IMAGES / 'my_plan_pro_lumi.png', 'lumi_crown.webp', 384, True),
    (APP_IMAGES / 'routine_template_cards.webp', 'cards.webp', 128, True),
    (APP_IMAGES / 'example_category_morning.webp', 'morning.webp', 192, True),
    (APP_IMAGES / 'example_category_school.webp', 'school.webp', 192, True),
    (APP_IMAGES / 'example_category_chores.webp', 'chores.webp', 192, True),
    (APP_IMAGES / 'example_category_outside.webp', 'outside.webp', 192, True),
    (APP_IMAGES / 'image_style_cartoon.webp', 'style_cartoon.webp', 280, False),
    (APP_IMAGES / 'image_style_realistic.png', 'style_realistic.webp', 280, False),
    (SITE_ART / 'aba_steps.png', 'aba_steps.webp', 256, True),
    (SITE_ART / 'aba_show.png', 'aba_show.webp', 256, True),
    (SITE_ART / 'aba_help.png', 'aba_help.webp', 256, True),
    (SITE_ART / 'aba_reward.png', 'aba_reward.webp', 256, True),
    (SITE_ART / 'together.png', 'together.webp', 720, True),
    (APP_IMAGES / 'reward_star_green.png', 'pop_star.webp', 144, True),
    # 공유 썸네일의 앱 아이콘 타일 (스토어 아이콘과 같은 그림)
    (APP_ASSETS / 'icon/app_icon.png', 'app_icon.webp', 280, False),
] + [
    # 첫 화면 앱 화면 (언어 x 화면, site_config 가 원본)
    (PROMO_SCREENS / f'{language_code}/{screen_name}.png', to_app_screen_file_name(language_code, screen_name), 330, False)
    for language_code in APP_SCREEN_LANGUAGES for screen_name in APP_SCREEN_NAMES
]
# 그대로 복사하는 벡터 그림 (앱 그림 방식 예시와 같은 그림)
VECTOR_IMAGES = [
    # 보호자 칸 제목 아이콘 (앱 아이콘 그대로)
    (APP_IMAGES / 'icon_pencil_edit.svg', 'icon_guardian_decides.svg'),
    (APP_IMAGES / 'icon_calendar.svg', 'icon_same_time.svg'),
    (APP_IMAGES / 'icon_playing_cards.svg', 'icon_point_card.svg'),
    (APP_IMAGES / 'icon_sparkles_large.svg', 'pop_sparkles.svg'),
    (APP_ASSETS / 'emoji/emoji_toothbrush.svg', 'style_emoji.svg'),
    (APP_ASSETS / 'pictograms/brush_teeth_,_to.svg', 'style_symbol.svg'),
]


def main():
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    for source, name, width_pixels, has_alpha in RASTER_IMAGES:
        with Image.open(source) as image:
            image = image.convert('RGBA' if has_alpha else 'RGB')
            if image.width > width_pixels:
                image = image.resize((width_pixels, round(image.height * width_pixels / image.width)), Image.LANCZOS)
            image.save(TARGET_DIR / name, 'WEBP', quality=84, method=6)
    for source, name in VECTOR_IMAGES:
        shutil.copyfile(source, TARGET_DIR / name)
    print(f'[site images] {len(RASTER_IMAGES) + len(VECTOR_IMAGES)} files > {TARGET_DIR}')


if __name__ == '__main__':
    main()
