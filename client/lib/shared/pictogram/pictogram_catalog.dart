import 'pictogram_ids.dart';

/// 서버가 카드마다 내려주는 `pictogramId` 의 허용 목록 (#469).
///
/// 서버 카탈로그(`server/src/main/resources/pictograms/catalog.json`)와 같은 811개다.
/// 서버가 앞서 새 id 를 내려줘도(앱 업데이트 전) **없는 자산을 그리려다 깨지지 않게**
/// 여기서 걸러 null 로 돌린다 — 그러면 카드는 기본 카드로 나온다.
abstract final class PictogramCatalog {
  /// 어떤 행동에도 맞는 그림이 없을 때 서버가 쓰는 폴백 (`go_,_to`).
  static const fallbackId = 'go_,_to';

  /// 번들에 있는 id 인가.
  static bool contains(String id) => pictogramIds.contains(id);

  /// 서버 JSON 값을 id 로 읽는다. 없거나 문자열이 아니거나 카탈로그에 없으면 null.
  ///
  /// 이 앱은 응답이 어떻게 오든 죽지 않아야 하므로 예외를 던지지 않는다.
  static String? parse(Object? raw) {
    if (raw is! String) return null;
    final id = raw.trim();
    return contains(id) ? id : null;
  }
}
