import 'dart:convert';

import 'consent_documents.dart';

/// 화면에 보여줄 약관 한 벌 (이슈 #278).
///
/// 어디서 왔는지([source])를 함께 들고 다닌다. 서버본인지 캐시인지 번들 기본값인지에
/// 따라 **동의 기록에 남길 버전이 달라지기 때문**이다.
class ConsentBundle {
  const ConsentBundle({
    required this.version,
    required this.items,
    required this.source,
  });

  /// 동의를 기록할 때 서버로 보낼 버전. 필수 항목 중 가장 최근 것이다.
  final String version;

  final List<ConsentItem> items;

  final ConsentSource source;

  /// 앱에 박혀 있는 기본값. 서버도 캐시도 읽지 못했을 때 쓴다.
  static const bundled = ConsentBundle(
    version: consentVersion,
    items: consentItems,
    source: ConsentSource.bundled,
  );

  /// 서버 응답을 읽는다. **형식이 조금이라도 어긋나면 null이다** —
  /// 반쯤 읽어 빈 약관을 띄우느니 캐시나 기본값으로 떨어지는 편이 낫다.
  static ConsentBundle? tryParse(Object? raw, {required ConsentSource source}) {
    if (raw is! Map) return null;
    final documents = raw['documents'];
    if (documents is! List || documents.isEmpty) return null;

    final items = <ConsentItem>[];
    for (final entry in documents) {
      final item = ConsentItem.tryParse(entry);
      // 한 항목이라도 깨졌으면 통째로 버린다. 일부만 빠지면 사용자가 동의해야 할
      // 항목이 화면에서 사라지는데, 그건 조용히 일어나 아무도 알아채지 못한다.
      if (item == null) return null;
      items.add(item);
    }

    final version = raw['version'];
    if (version is! String || version.isEmpty) return null;

    return ConsentBundle(version: version, items: items, source: source);
  }

  static ConsentBundle? tryParseJson(String json, {required ConsentSource source}) {
    try {
      return tryParse(jsonDecode(json), source: source);
    } on FormatException {
      // 캐시가 깨졌다. 지우지 않고 그냥 무시한다 — 다음 갱신이 덮어쓴다.
      return null;
    }
  }

  String toJson() => jsonEncode({
    'version': version,
    'documents': items.map((item) => item.toJson()).toList(),
  });

  /// 필수 항목만. 동의 완료 판정에 쓴다.
  Iterable<ConsentItem> get requiredItems => items.where((item) => item.required);

  /// 빼도 되는 항목. 약관 목록이 필수와 나눠 보여준다 (#349).
  Iterable<ConsentItem> get optionalItems =>
      items.where((item) => !item.required);
}

/// 지금 화면에 띄운 약관이 어디서 온 것인가.
enum ConsentSource {
  /// 서버에서 방금 받았다.
  server,

  /// 지난번에 받아 둔 것.
  cache,

  /// 앱에 박힌 기본값. 서버도 캐시도 없었다.
  bundled,
}
