import 'dart:convert';

/// 의견 보내기에 첨부할 최근 앱 기록을 메모리에만 쥐고 있는 버퍼.
///
/// 디스크에 쓰지 않는다 — 앱을 끄면 사라진다. 두 구역으로 나눠 쌓는다.
/// - 일반 기록: 링버퍼. 줄 수·바이트 합계가 넘으면 오래된 줄부터 버린다.
/// - 오류 보관: 최근 [maxErrors]건. 일반 기록이 쏟아져도 밀려나지 않는다.
///
/// 개발자 도구용 `DevLogBuffer` 와 달리 빌드와 무관하게 항상 쌓인다.
class AppLogBuffer {
  AppLogBuffer._();

  /// 일반 기록 최대 줄 수.
  static const maxLines = 1500;

  /// 전송 텍스트 전체(머리말+오류+기록)의 UTF-8 상한. 서버 상한과 같다.
  static const maxBytes = 256 * 1024;

  /// 오류 보관 건수.
  static const maxErrors = 30;

  /// 오류 한 건(스택 포함)의 최대 글자 수.
  static const maxErrorChars = 6000;

  static const _headerMaxBytes = 8 * 1024;
  static const errorSectionTitle = '== 최근 오류 ==';
  static const logSectionTitle = '== 기록 ==';

  static final List<String> _lines = [];
  static final List<int> _sizes = [];
  static final List<String> _errors = [];
  static int _totalBytes = 0;

  /// 한 줄을 더한다. 한 줄만으로 상한을 넘으면 뒤쪽 [maxBytes] 안으로 잘라 넣는다.
  static void add(String line) {
    var text = line;
    var size = _bytes(text);
    if (size > maxBytes) {
      text = _tail(text, maxBytes);
      size = _bytes(text);
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

  /// 오류 한 건을 오류 보관에 더한다. [maxErrorChars] 를 넘는 뒷부분은 자른다.
  static void addError(String text) {
    _errors.add(_capChars(text, maxErrorChars));
    while (_errors.length > maxErrors) {
      _errors.removeAt(0);
    }
  }

  /// 전송용 텍스트. `머리말 → 오류 → 기록` 순이며 전체가 [maxBytes] 를 넘지 않는다.
  ///
  /// 넘치면 일반 기록을 앞(오래된 쪽)부터 자른다. 오류 구역은 우선 보존하되
  /// 기록이 통째로 사라지지 않게 남은 자리의 3/4 까지만 쓴다.
  /// 구역 제목은 머리말이나 오류가 있을 때만 붙인다(기록만 있으면 줄만 이어 붙인다).
  static String asText({String header = ''}) {
    final out = <String>[];
    var budget = maxBytes;

    final head = _fitHead(header.trim(), _headerMaxBytes);
    if (head.isNotEmpty) {
      out.add(head);
      budget -= _bytes(head) + 1;
    }

    // 오류: 최신부터 담되 오래된 순으로 출력한다.
    final errBudget = ((budget - _bytes(errorSectionTitle) - 1) * 3) ~/ 4;
    final errs = <String>[];
    var used = 0;
    for (var i = _errors.length - 1; i >= 0; i--) {
      final cost = _bytes(_errors[i]) + 1;
      if (used + cost > errBudget) break;
      used += cost;
      errs.insert(0, _errors[i]);
    }
    if (errs.isNotEmpty) {
      out
        ..add(errorSectionTitle)
        ..addAll(errs);
      budget -= _bytes(errorSectionTitle) + 1 + used;
    }

    // 일반 기록: 최신부터 남은 자리에 담는다.
    final needTitle = out.isNotEmpty;
    var logBudget = budget - (needTitle ? _bytes(logSectionTitle) + 1 : 0);
    final kept = <String>[];
    for (var i = _lines.length - 1; i >= 0; i--) {
      final cost = _sizes[i] + 1;
      if (cost > logBudget) {
        // 가장 최신 줄 하나가 통째로 안 들어가면 뒤쪽만이라도 남긴다.
        if (kept.isEmpty && logBudget > 1) {
          kept.add(_tail(_lines[i], logBudget - 1));
        }
        break;
      }
      logBudget -= cost;
      kept.insert(0, _lines[i]);
    }
    if (kept.isNotEmpty) {
      if (needTitle) out.add(logSectionTitle);
      out.addAll(kept);
    }
    return out.join('\n');
  }

  /// 일반 기록과 오류 보관이 모두 비었는지.
  static bool get isEmpty => _lines.isEmpty && _errors.isEmpty;

  static int get length => _lines.length;

  static int get errorCount => _errors.length;

  /// 일반 기록의 UTF-8 바이트 합계.
  static int get totalBytes => _totalBytes;

  static void clear() {
    _lines.clear();
    _sizes.clear();
    _errors.clear();
    _totalBytes = 0;
  }

  /// 테스트 시작 때 비운다.
  static void resetForTest() => clear();

  static int _bytes(String s) => utf8.encode(s).length;

  /// 글자 경계를 깨지 않고 뒤쪽 [limit] 바이트 안만 남긴다.
  static String _tail(String text, int limit) {
    final runes = text.runes.toList();
    var bytes = 0;
    var start = runes.length;
    while (start > 0) {
      final w = _bytes(String.fromCharCode(runes[start - 1]));
      if (bytes + w > limit) break;
      bytes += w;
      start--;
    }
    return String.fromCharCodes(runes.sublist(start));
  }

  /// 글자 경계를 깨지 않고 앞쪽 [limit] 바이트 안만 남긴다.
  static String _fitHead(String text, int limit) {
    if (_bytes(text) <= limit) return text;
    var bytes = 0;
    final buf = StringBuffer();
    for (final r in text.runes) {
      final w = _bytes(String.fromCharCode(r));
      if (bytes + w > limit) break;
      bytes += w;
      buf.writeCharCode(r);
    }
    return buf.toString();
  }

  /// 앞쪽 [limit] 글자만 남긴다. 서로게이트 쌍은 쪼개지 않는다.
  static String _capChars(String text, int limit) {
    if (text.length <= limit) return text;
    var end = limit - 1; // 말줄임표 자리
    final last = text.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) end--;
    return '${text.substring(0, end)}…';
  }
}
