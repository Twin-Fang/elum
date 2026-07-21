import 'package:flutter/foundation.dart';

/// 앱 내 로그 뷰어용 링버퍼.
///
/// 실기기·릴리스 빌드에는 `flutter run` 콘솔이 없어 로그를 볼 방법이 없다.
/// 데모 중 문제가 생겼을 때 원인을 파악하려면 앱 안에서 로그를 봐야 한다.
///
/// **원문 비저장 원칙(docs 원칙 5번)은 그대로다.** 보호자 입력 원문은 애초에
/// `debugPrint`로 나가지 않으므로 이 버퍼에도 담기지 않는다. 여기서 따로
/// 거르지 않고, 원문을 로그에 남기지 않는 기존 구조를 그대로 신뢰한다.
///
/// 정식 출시 전 제거 대상. (이슈 #13)
abstract final class DevLogBuffer {
  /// 메모리를 무한정 먹지 않도록 상한을 둔다.
  /// 데모 중 원인 파악에는 최근 로그면 충분하다.
  static const maxLines = 200;

  static final List<String> _lines = <String>[];

  /// 원본 debugPrint. install() 시점에 백업해 둔다.
  static DebugPrintCallback? _original;

  /// 새 로그가 쌓일 때 알린다. 뷰어가 열려 있으면 즉시 갱신된다.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// 쌓인 로그 (오래된 것부터).
  static List<String> get lines => List.unmodifiable(_lines);

  /// `debugPrint`를 가로채 버퍼에도 쌓는다. 원본 출력은 그대로 유지한다.
  ///
  /// main()에서 runApp 전에 한 번만 호출한다. 두 번 호출해도 원본이
  /// 중첩되지 않도록 막는다.
  static void install() {
    if (_original != null) return;

    _original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) _add(message);
      _original?.call(message, wrapWidth: wrapWidth);
    };
  }

  static void _add(String message) {
    _lines.add(message);
    // 상한을 넘으면 오래된 줄부터 버린다
    if (_lines.length > maxLines) {
      _lines.removeRange(0, _lines.length - maxLines);
    }
    revision.value++;
  }

  static void clear() {
    _lines.clear();
    revision.value++;
  }

  /// 클립보드 복사용 단일 문자열.
  static String asText() => _lines.join('\n');

  /// 테스트에서 가로채기를 되돌린다. 다음 테스트가 오염되지 않게 한다.
  @visibleForTesting
  static void uninstall() {
    if (_original == null) return;
    debugPrint = _original!;
    _original = null;
    _lines.clear();
  }
}
