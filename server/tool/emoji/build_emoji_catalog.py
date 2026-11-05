"""
이모지 카드 그림 카탈로그 생성: 고정 버전 다운로드 > 선별 > 서버·앱 catalog.json + 앱 SVG·id 목록 > 자체 점검
단일 원본: 서버 catalog.json, 앱 assets/emoji/*, emoji_ids.dart 는 모두 이 스크립트 생성물 (#1149)
"""
import argparse
import io
import json
import re
import sys
import tarfile
import tempfile
import unicodedata
import urllib.request
from pathlib import Path

# 입력 버전 고정 (바꾸면 카탈로그 전체가 바뀜)
TWEMOJI_VERSION = "15.0.0"
EMOJIBASE_VERSION = "15.3.0"
TWEMOJI_TARBALL_URL = f"https://registry.npmjs.org/@twemoji/svg/-/svg-{TWEMOJI_VERSION}.tgz"
EMOJIBASE_DATA_URL = f"https://cdn.jsdelivr.net/npm/emojibase-data@{EMOJIBASE_VERSION}/en/data.json"
EMOJIBASE_GROUPS_URL = f"https://cdn.jsdelivr.net/npm/emojibase-data@{EMOJIBASE_VERSION}/meta/groups.json"

ID_PREFIX = "emoji_"
FALLBACK_ID = "emoji_star"
MIN_SYMBOL_COUNT = 700
MAX_SYMBOL_COUNT = 900

# 고르는 하위 그룹 (emojibase subgroup 이름): 감정 얼굴 일부, 손·몸, 사람 동작, 동물·식물, 음식, 장소·탈것·날씨·시간, 활동, 물건
INCLUDED_SUBGROUPS = {
    "face-smiling", "face-concerned", "face-sleepy", "face-unwell", "emotion",
    "hand-fingers-open", "hand-fingers-closed", "hands", "hand-prop",
    "body-parts", "person", "person-gesture", "person-role", "person-activity", "person-sport", "person-resting",
    "animal-mammal", "animal-bird", "animal-amphibian", "animal-reptile", "animal-marine", "animal-bug",
    "plant-flower", "plant-other",
    "food-fruit", "food-vegetable", "food-prepared", "food-asian", "food-marine", "food-sweet", "drink", "dishware",
    "place-geographic", "place-building", "place-other",
    "transport-ground", "transport-water", "transport-air", "hotel", "time", "sky-weather",
    "event", "award-medal", "sport", "game", "arts-crafts",
    "clothing", "sound", "music", "musical-instrument", "phone", "computer", "light-video", "book-paper",
    "writing", "office", "tool", "medical", "household", "other-object",
}

# 아동 카드에 맞지 않는 라벨 (술·담배·무기·죽음·욕설 손짓)
EXCLUDED_LABELS = {
    "beer mug", "clinking beer mugs", "wine glass", "cocktail glass", "tropical drink", "tumbler glass",
    "bottle with popping cork", "sake", "clinking glasses",
    "cigarette", "bomb", "dagger", "crossed swords", "water pistol", "kitchen knife", "coffin", "funeral urn",
    "middle finger", "skull", "skull and crossbones", "knife", "boomerang", "carpentry saw",
    "moai", "drop of blood", "money with wings", "lipstick", "ring", "kiss mark",
    "love letter", "anatomical heart", "lungs", "biting lip",
    "ninja", "person wearing turban", "person with skullcap", "woman with headscarf", "person with veil",
    "pregnant woman", "pregnant man", "pregnant person", "breast-feeding", "vulcan salute",
    "card index dividers", "card index", "chart increasing", "chart decreasing", "bar chart", "card file box",
    "file cabinet", "linked paperclips", "oil drum", "mouse trap", "plunger",
}

# 같은 그림이 여러 장인 묶음 (시계 24장, 달 모양, 다가오는 탈것, 손 방향 변형)
EXCLUDED_LABEL_PATTERN = re.compile(
    r"o’clock|-thirty|moon face|(waxing|waning|quarter) moon|^new moon$|^oncoming |wards hand|pushing hand|^palm |raised back"
)


def main() -> int:
    arguments = parse_arguments()
    repo_root = Path(arguments.repo_root).resolve()
    cache_directory = Path(arguments.cache_dir).resolve()
    cache_directory.mkdir(parents=True, exist_ok=True)

    # 입력 받기 (캐시 있으면 재사용)
    twemoji_tarball = download_cached(TWEMOJI_TARBALL_URL, cache_directory / f"twemoji-{TWEMOJI_VERSION}.tgz")
    emoji_entries = json.loads(download_cached(EMOJIBASE_DATA_URL, cache_directory / f"emojibase-{EMOJIBASE_VERSION}-data.json"))
    group_meta = json.loads(download_cached(EMOJIBASE_GROUPS_URL, cache_directory / f"emojibase-{EMOJIBASE_VERSION}-groups.json"))

    svg_by_file_name = read_svg_files(twemoji_tarball)
    symbols, svg_by_id = select_symbols(emoji_entries, group_meta["subgroups"], svg_by_file_name)
    catalog_text = build_catalog_text(symbols)

    write_outputs(repo_root, catalog_text, svg_by_id, read_license_text(twemoji_tarball))
    return verify_outputs(repo_root, catalog_text, symbols)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build the Twemoji card picture catalog for server and app")
    parser.add_argument("--repo-root", default=".", help="repository root (contains server/ and client/)")
    parser.add_argument("--cache-dir", default=str(Path(tempfile.gettempdir()) / "elum-emoji-cache"),
                        help="download cache directory")
    return parser.parse_args()


def download_cached(url: str, cache_path: Path) -> bytes:
    if cache_path.exists():
        return cache_path.read_bytes()
    with urllib.request.urlopen(url, timeout=60) as response:
        content = response.read()
    cache_path.write_bytes(content)
    return content


def read_svg_files(tarball: bytes) -> dict:
    """tarball > {파일명(소문자 hex.svg): 바이트} (압축 해제 없이 메모리에서 읽음)"""
    svg_by_file_name = {}
    with tarfile.open(fileobj=io.BytesIO(tarball), mode="r:gz") as archive:
        for member in archive.getmembers():
            if member.isfile() and member.name.endswith(".svg"):
                svg_by_file_name[Path(member.name).name] = archive.extractfile(member).read()
    return svg_by_file_name


def read_license_text(tarball: bytes) -> str:
    with tarfile.open(fileobj=io.BytesIO(tarball), mode="r:gz") as archive:
        return archive.extractfile("package/license").read().decode("utf-8")


def select_symbols(emoji_entries: list, subgroup_names: dict, svg_by_file_name: dict):
    """emojibase 항목 > 선별된 심볼 목록 + {id: svg 바이트}"""
    symbols = []
    svg_by_id = {}
    used_ids = set()
    for entry in sorted(emoji_entries, key=lambda item: item.get("order", 0)):
        # 단일 코드포인트만 (FE0F 제외 후), 포함 하위 그룹·제외 라벨 검사
        subgroup_name = subgroup_names.get(str(entry.get("subgroup")))
        label = entry.get("label", "")
        codepoints = [part for part in entry["hexcode"].lower().split("-") if part != "fe0f"]
        if len(codepoints) != 1 or subgroup_name not in INCLUDED_SUBGROUPS or is_excluded_label(label):
            continue
        svg_file_name = f"{codepoints[0]}.svg"
        if svg_file_name not in svg_by_file_name:
            continue
        symbol_id = to_unique_symbol_id(label, used_ids)
        symbols.append({
            "id": symbol_id,
            "label": label,
            "category": subgroup_name,
            "verb": False,
            "codepoint": codepoints[0].upper(),
        })
        svg_by_id[symbol_id] = svg_by_file_name[svg_file_name]
    return symbols, svg_by_id


def is_excluded_label(label: str) -> bool:
    return label in EXCLUDED_LABELS or EXCLUDED_LABEL_PATTERN.search(label) is not None


def to_unique_symbol_id(label: str, used_ids: set) -> str:
    """영어 라벨 > emoji_snake_case (악센트 제거, 영숫자만, 중복이면 _2)"""
    ascii_label = unicodedata.normalize("NFKD", label).encode("ascii", "ignore").decode("ascii").lower()
    base_id = ID_PREFIX + re.sub(r"[^a-z0-9]+", "_", ascii_label).strip("_")
    symbol_id = base_id
    suffix = 2
    while symbol_id in used_ids:
        symbol_id = f"{base_id}_{suffix}"
        suffix += 1
    used_ids.add(symbol_id)
    return symbol_id


def build_catalog_text(symbols: list) -> str:
    catalog = {
        "source": f"Twemoji v{TWEMOJI_VERSION} (https://github.com/jdecked/twemoji), labels from emojibase-data v{EMOJIBASE_VERSION}",
        "license": "CC BY 4.0",
        "attribution": "Twemoji graphics by Twitter, Inc and other contributors are licensed under CC-BY 4.0: https://creativecommons.org/licenses/by/4.0/",
        "fallbackId": FALLBACK_ID,
        "symbols": symbols,
    }
    return json.dumps(catalog, ensure_ascii=False, indent=1) + "\n"


def write_outputs(repo_root: Path, catalog_text: str, svg_by_id: dict, twemoji_license_text: str) -> None:
    server_catalog_path = repo_root / "server/src/main/resources/emoji/catalog.json"
    client_asset_directory = repo_root / "client/assets/emoji"
    server_catalog_path.parent.mkdir(parents=True, exist_ok=True)
    client_asset_directory.mkdir(parents=True, exist_ok=True)

    # 서버·앱 catalog (같은 바이트)
    server_catalog_path.write_text(catalog_text, encoding="utf-8")
    (client_asset_directory / "catalog.json").write_text(catalog_text, encoding="utf-8")

    # 앱 SVG: 지난 생성물 정리 후 원본 그대로 복사 (변형 없음)
    for old_svg in client_asset_directory.glob("*.svg"):
        old_svg.unlink()
    for symbol_id, svg_bytes in svg_by_id.items():
        (client_asset_directory / f"{symbol_id}.svg").write_bytes(svg_bytes)

    (client_asset_directory / "LICENSE.txt").write_text(
        "Twemoji graphics (https://github.com/jdecked/twemoji)\n"
        "Copyright 2019 Twitter, Inc and other contributors\n"
        "Graphics licensed under CC-BY 4.0: https://creativecommons.org/licenses/by/4.0/\n"
        "Files are copied unmodified; file names are renamed to emoji_<english name>.svg.\n\n"
        + twemoji_license_text,
        encoding="utf-8",
    )
    write_dart_ids(repo_root / "client/lib/shared/pictogram/emoji_ids.dart", sorted(svg_by_id))


def write_dart_ids(dart_path: Path, symbol_ids: list) -> None:
    lines = [
        "// 자동 생성 — 직접 고치지 않는다. `python3 -I server/tool/emoji/build_emoji_catalog.py`",
        f"// 원본: assets/emoji/catalog.json (Twemoji v{TWEMOJI_VERSION}, {len(symbol_ids)}개)",
        "",
        "/// 앱에 번들된 이모지 그림 id 전부 (SVG 파일명 stem).",
        "const emojiIds = <String>{",
        *[f"  '{symbol_id}'," for symbol_id in symbol_ids],
        "};",
        "",
    ]
    dart_path.write_text("\n".join(lines), encoding="utf-8")


def verify_outputs(repo_root: Path, catalog_text: str, symbols: list) -> int:
    """자체 점검 4개: 개수 범위, id마다 SVG, 서버·앱 catalog 동일, Mulberry id 겹침 0, fallback 존재"""
    client_asset_directory = repo_root / "client/assets/emoji"
    symbol_ids = {symbol["id"] for symbol in symbols}
    mulberry = json.loads((repo_root / "server/src/main/resources/pictograms/catalog.json").read_text(encoding="utf-8"))
    mulberry_ids = {symbol["id"] for symbol in mulberry["symbols"]}

    problems = []
    if not MIN_SYMBOL_COUNT <= len(symbols) <= MAX_SYMBOL_COUNT:
        problems.append(f"count {len(symbols)} outside {MIN_SYMBOL_COUNT}..{MAX_SYMBOL_COUNT}")
    missing_svg_ids = [symbol_id for symbol_id in symbol_ids if not (client_asset_directory / f"{symbol_id}.svg").exists()]
    if missing_svg_ids:
        problems.append(f"missing svg: {missing_svg_ids[:5]}")
    server_text = (repo_root / "server/src/main/resources/emoji/catalog.json").read_text(encoding="utf-8")
    client_text = (client_asset_directory / "catalog.json").read_text(encoding="utf-8")
    if not server_text == client_text == catalog_text:
        problems.append("server and client catalog differ")
    overlapping_ids = symbol_ids & mulberry_ids
    if overlapping_ids:
        problems.append(f"overlap with mulberry: {sorted(overlapping_ids)[:5]}")
    if FALLBACK_ID not in symbol_ids:
        problems.append(f"fallback {FALLBACK_ID} missing")

    if problems:
        print(f"[emoji catalog] failed : {'; '.join(problems)}", file=sys.stderr)
        return 1
    print(f"[emoji catalog] ok : symbols={len(symbols)} fallback={FALLBACK_ID}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
