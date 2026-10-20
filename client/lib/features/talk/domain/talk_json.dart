/// 이야기 응답 파싱 공통: 형식이 틀린 값은 null·기본값으로 흘려 보낸다 (앱이 죽지 않게)
class TalkJson {
  const TalkJson._();

  static String? text(Object? raw) => raw is String ? raw : null;

  /// 비어 있지 않은 문자열만 (id 처럼 꼭 있어야 하는 값)
  static String? nonEmptyText(Object? raw) =>
      raw is String && raw.isNotEmpty ? raw : null;

  static int count(Object? raw) => raw is num ? raw.toInt() : 0;

  static bool flag(Object? raw) => raw == true;

  /// 서버 LocalDateTime(ISO 문자열) > DateTime. 깨졌으면 null
  static DateTime? time(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;

  /// 목록의 각 항목을 [parse] 로 읽고 못 읽은 항목은 건너뛴다
  static List<T> list<T>(Object? raw, T? Function(Map<String, dynamic>) parse) {
    if (raw is! List) return const [];
    final parsed = <T>[];
    for (final element in raw) {
      if (element is! Map<String, dynamic>) continue;
      final item = parse(element);
      if (item != null) parsed.add(item);
    }
    return parsed;
  }
}
