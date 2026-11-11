import 'emoji_ids.dart';
import 'pictogram_ids.dart';

/// 서버가 카드마다 내려주는 `pictogramId` 의 허용 목록.
///
/// 서버 카탈로그 두 벌과 같다: Mulberry 811개(`pictograms/catalog.json`), 이모지(`emoji/catalog.json`, `emoji_` 로 시작, #1149).
/// 서버가 앞서 새 id 를 내려줘도(앱 업데이트 전) **없는 자산을 그리려다 깨지지 않게**
/// 여기서 걸러 null 로 돌린다 — 그러면 카드는 기본 카드로 나온다.
abstract final class PictogramCatalog {
  /// 어떤 행동에도 맞는 그림이 없을 때 서버가 쓰는 폴백 (`go_,_to`).
  static const fallbackId = 'go_,_to';

  /// 이모지 그림 id 접두사 (서버 build_emoji_catalog.py 와 같음). Mulberry 에는 이 접두사 id 가 없다
  static const emojiIdPrefix = 'emoji_';

  /// 이모지 그림(Twemoji) id 인가. 아니면 Mulberry 그림 기호
  static bool isEmoji(String id) => id.startsWith(emojiIdPrefix);

  /// 번들에 있는 id 인가 (접두사로 목록을 고름).
  static bool contains(String id) => isEmoji(id) ? emojiIds.contains(id) : pictogramIds.contains(id);

  /// 서버 JSON 값을 id 로 읽는다. 없거나 문자열이 아니거나 카탈로그에 없으면 null.
  ///
  /// 이 앱은 응답이 어떻게 오든 죽지 않아야 하므로 예외를 던지지 않는다.
  static String? parse(Object? raw) {
    if (raw is! String) return null;
    final id = raw.trim();
    return contains(id) ? id : null;
  }
}
