import 'dart:convert';

/// 의견 보내기에 첨부할 최근 앱 로그를 메모리에만 쥐고 있는 링버퍼.
///
/// 디스크에 쓰지 않는다 — 앱을 끄면 사라진다. 줄 수와 바이트 합계 둘 다 넘지 않게
/// 오래된 줄부터 버린다. 개발자 도구용 `DevLogBuffer` 와 달리 빌드와 무관하게 항상 쌓인다.
class AppLogBuffer {
  AppLogBuffer._();

  /// 보관할 최대 줄 수.
  static const maxLines = 200;

  /// 보관할 최대 크기(UTF-8 바이트 합계). 서버 상한(64KB)보다 낮게 둔다.
  static const maxBytes = 50 * 1024;

  static final List<String> _lines = [];
  static final List<int> _sizes = [];
  static int _totalBytes = 0;

  /// 한 줄을 더한다. 한 줄만으로 상한을 넘으면 뒤쪽 [maxBytes] 안으로 잘라 넣는다.
  static void add(String line) {
    var text = line;
    var size = utf8.encode(text).length;
    if (size > maxBytes) {
      text = _tail(text);
      size = utf8.encode(text).length;
    }
    _lines.add(text);
    _sizes.add(size);
    _totalBytes += size;

    // 오래된 줄부터 버린다. 방금 넣은 줄은 남긴다.
    while (_lines.length > 1 &&
        (_lines.length > maxLines || _totalBytes > maxBytes)) {
      _totalBytes -= _sizes.removeAt(0);
      _lines.removeAt(0);
    }
  }

  /// 보관 중인 줄을 오래된 순으로 이어 붙인다. 비었으면 빈 문자열.
  static String asText() => _lines.join('\n');

  static int get length => _lines.length;

  static int get totalBytes => _totalBytes;

  static void clear() {
    _lines.clear();
    _sizes.clear();
    _totalBytes = 0;
  }

  /// 테스트 시작 때 비운다.
  static void resetForTest() => clear();

  /// 글자 경계를 깨지 않고 뒤쪽 [maxBytes] 안만 남긴다.
  static String _tail(String text) {
    final runes = text.runes.toList();
    var bytes = 0;
    var start = runes.length;
    while (start > 0) {
      final w = utf8.encode(String.fromCharCode(runes[start - 1])).length;
      if (bytes + w > maxBytes) break;
      bytes += w;
      start--;
    }
    return String.fromCharCodes(runes.sublist(start));
  }
}
