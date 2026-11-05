# 이모지 카드 그림 카탈로그 (#1149)

`python3 -I server/tool/emoji/build_emoji_catalog.py --repo-root .` (레포 루트에서)

- 입력: `@twemoji/svg@15.0.0`, `emojibase-data@15.3.0` (스크립트에 고정)
- 출력: `server/src/main/resources/emoji/catalog.json`, `client/assets/emoji/`, `client/lib/shared/pictogram/emoji_ids.dart`
- 생성물은 손으로 고치지 않는다. 선별 범위를 바꾸려면 스크립트의 `INCLUDED_SUBGROUPS`·`EXCLUDED_LABELS`를 고치고 다시 돌린다.
