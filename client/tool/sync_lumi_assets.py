"""루미 그림 원본 > 플랫폼 사본 생성 (#1465)

원본: client/assets/images/lumi/lumi_<이름>.webp (앱이 쓰는 단일 원본, 투명 배경)
사본 2곳 (손으로 고치지 않음, 이 스크립트로만 만듦):
  - iOS 위젯: client/ios/ElumHomeWidget/Assets.xcassets/<이름>.imageset (PNG)
  - Android 위젯: client/android/app/src/main/res/drawable-nodpi/<이름>.webp
별 그림(widget_star)은 client/assets/images/star_big.png 에서 만든다.

사용: python3 -I client/tool/sync_lumi_assets.py [--import-dir 승인한_PNG_폴더]
  --import-dir: 새로 승인한 PNG(lumi_<이름>.png)를 원본 webp 로 먼저 바꿔 넣음
필요: Pillow
"""
import argparse
import json
import pathlib
import shutil

from PIL import Image

CLIENT_DIR = pathlib.Path(__file__).resolve().parents[1]
SOURCE_DIR = CLIENT_DIR / 'assets/images/lumi'
STAR_SOURCE = CLIENT_DIR / 'assets/images/star_big.png'
IOS_CATALOG_DIR = CLIENT_DIR / 'ios/ElumHomeWidget/Assets.xcassets'
ANDROID_DRAWABLE_DIR = CLIENT_DIR / 'android/app/src/main/res/drawable-nodpi'

# 한 변 픽셀: 원본(앱 · 화면 최대 약 200pt × 3배) · 위젯 사본(최대 약 120pt × 3배)
SOURCE_PIXEL_SIDE = 640
WIDGET_PIXEL_SIDE = 384
# webp 품질 (투명 가장자리 계단 없게 높게)
WEBP_QUALITY = 90


# 그림 둘레 투명 여백 비율 (그림마다 다른 여백을 잘라 크기를 맞춘 뒤 같은 여백을 줌)
PADDING_RATIO = 0.06
# 투명으로 보는 알파 한계 (은은한 빛 가장자리는 자르지 않게 낮게)
ALPHA_TRIM_THRESHOLD = 8


def fit_square(image: Image.Image, side: int) -> Image.Image:
    """여백 자르기 > 투명 정사각 캔버스 가운데에 비율 유지로 맞춤 (그림마다 크기 통일)"""
    image = image.convert('RGBA')
    bounding_box = image.getchannel('A').point(lambda alpha: 255 if alpha > ALPHA_TRIM_THRESHOLD else 0).getbbox()
    if bounding_box:
        image = image.crop(bounding_box)
    inner_side = int(side * (1 - PADDING_RATIO * 2))
    image.thumbnail((inner_side, inner_side), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.paste(image, ((side - image.width) // 2, (side - image.height) // 2), image)
    return canvas


def import_approved(import_dir: pathlib.Path) -> None:
    """승인한 PNG > 원본 webp (같은 이름이면 덮어씀)"""
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    for png in sorted(import_dir.glob('lumi_*.png')):
        target = SOURCE_DIR / f'{png.stem}.webp'
        fit_square(Image.open(png), SOURCE_PIXEL_SIDE).save(target, 'WEBP', quality=WEBP_QUALITY)
        print(f'imported {target.relative_to(CLIENT_DIR)}')


def write_ios_imageset(name: str, image: Image.Image) -> None:
    """iOS 위젯 이미지 세트 1개 (한 장 universal)"""
    imageset = IOS_CATALOG_DIR / f'{name}.imageset'
    if imageset.exists():
        shutil.rmtree(imageset)
    imageset.mkdir(parents=True)
    image.save(imageset / f'{name}.png', 'PNG')
    contents = {
        'images': [{'filename': f'{name}.png', 'idiom': 'universal'}],
        'info': {'author': 'xcode', 'version': 1},
    }
    (imageset / 'Contents.json').write_text(json.dumps(contents, indent=2) + '\n')


def sync() -> None:
    """원본 > iOS · Android 위젯 사본 (원본에 없는 옛 사본은 지움)"""
    IOS_CATALOG_DIR.mkdir(parents=True, exist_ok=True)
    (IOS_CATALOG_DIR / 'Contents.json').write_text(
        json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n'
    )
    ANDROID_DRAWABLE_DIR.mkdir(parents=True, exist_ok=True)
    sources = {path.stem: Image.open(path) for path in sorted(SOURCE_DIR.glob('lumi_*.webp'))}
    sources['widget_star'] = Image.open(STAR_SOURCE)
    for name, image in sources.items():
        widget_image = fit_square(image, WIDGET_PIXEL_SIDE)
        write_ios_imageset(name, widget_image)
        widget_image.save(ANDROID_DRAWABLE_DIR / f'{name}.webp', 'WEBP', quality=WEBP_QUALITY)
        # 같은 이름의 임시 png 가 있으면 리소스 이름이 겹침 > 지움
        stale_png = ANDROID_DRAWABLE_DIR / f'{name}.png'
        if stale_png.exists():
            stale_png.unlink()
    print(f'synced {len(sources)} images > iOS widget catalog, Android drawable-nodpi')


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--import-dir', type=pathlib.Path)
    arguments = parser.parse_args()
    if arguments.import_dir:
        import_approved(arguments.import_dir)
    sync()


if __name__ == '__main__':
    main()
