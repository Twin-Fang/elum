import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 로그를 파일에 쌓는다 — 상한 2MB, 넘으면 오래된 쪽부터 버린다 (이슈 #219).
///
/// 메모리 링버퍼([DevLogBuffer])만으로는 **앱이 죽으면 로그가 함께 사라진다.**
/// QA가 "튕겼어요"라고 할 때 정작 볼 것이 없었다. 파일에 남겨 다음 실행에서도 읽는다.
///
/// ## 왜 앞부분을 버리나
///
/// 문제는 보통 **마지막에** 일어난다. 상한에 닿았을 때 새 로그를 막으면 정작 필요한
/// 순간이 기록되지 않는다. 그래서 오래된 앞부분을 버리고 최근을 남긴다.
///
/// ## 쓰기 실패는 삼킨다
///
/// 저장 공간이 없거나 권한이 없어도 **앱이 죽으면 안 된다.** 로그는 보조 수단이다.
/// 파일 쓰기가 실패해도 메모리 버퍼는 계속 동작해 실시간 보기는 살아 있다.
///
/// 정식 출시 전 제거 대상 (이슈 #13).
abstract final class DevLogFile {
  /// 파일 상한. 넘으면 앞에서부터 잘라낸다.
  static const maxBytes = 2 * 1024 * 1024; // 2MB

  /// 잘라낼 때 한 번에 비우는 비율. 1바이트씩 줄이면 상한 근처에서 매번 재작성한다.
  static const _trimRatio = 0.25;

  static File? _file;
  static bool _initFailed = false;

  /// 쓰기를 직렬화한다. 여러 로그가 동시에 append하면 줄이 섞인다.
  static Future<void> _queue = Future<void>.value();

  /// 현재 파일 크기. UI가 사용량을 보여줄 때 읽는다 (파일 I/O 없이).
  static final ValueNotifier<int> sizeBytes = ValueNotifier<int>(0);

  static String? get path => _file?.path;

  /// 0.0 ~ 1.0. 디버깅 버튼이 얼마나 찼는지 보여준다.
  static double get usedRatio =>
      (sizeBytes.value / maxBytes).clamp(0.0, 1.0).toDouble();

  /// 파일을 열고 현재 크기를 읽는다. main()에서 한 번 부른다.
  ///
  /// 실패해도 예외를 던지지 않는다 — 로그 때문에 앱이 안 뜨면 본말전도다.
  static Future<void> init() async {
    if (_file != null || _initFailed) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/elum-debug.log');
      if (!await f.exists()) {
        await f.create(recursive: true);
      }
      _file = f;
      sizeBytes.value = await f.length();
    } catch (e) {
      _initFailed = true;
      debugPrint('[개발자도구] 로그 파일 초기화 실패: $e');
    }
  }

  /// 한 줄 덧붙인다. 호출부를 막지 않도록 큐에 넣고 바로 반환한다.
  static void append(String line) {
    final f = _file;
    if (f == null) return;
    _queue = _queue.then((_) => _append(f, line)).catchError((Object e) {
      // 쓰기 실패는 조용히 넘긴다. 여기서 debugPrint하면 그 로그가 다시 append를
      // 부르는 무한 재귀가 된다.
    });
  }

  static Future<void> _append(File f, String line) async {
    await f.writeAsString('$line\n', mode: FileMode.append, flush: false);
    final len = await f.length();
    sizeBytes.value = len;
    if (len > maxBytes) await _trim(f);
  }

  /// 앞에서부터 잘라 상한 아래로 내린다.
  ///
  /// 줄 중간에서 자르면 첫 줄이 깨지므로, 자른 뒤 **첫 줄바꿈까지 더 버린다.**
  static Future<void> _trim(File f) async {
    try {
      final bytes = await f.readAsBytes();
      final keepFrom = (maxBytes * (1 - _trimRatio)).toInt();
      var start = bytes.length - keepFrom;
      if (start < 0) start = 0;

      // 깨진 첫 줄을 버린다 (0x0A = '\n')
      final nl = bytes.indexOf(0x0A, start);
      if (nl != -1 && nl + 1 < bytes.length) start = nl + 1;

      await f.writeAsBytes(bytes.sublist(start), flush: true);
      sizeBytes.value = await f.length();
    } catch (_) {
      // 잘라내기가 실패하면 파일을 비운다 — 무한히 커지는 것보다 낫다
      try {
        await f.writeAsString('', flush: true);
        sizeBytes.value = 0;
      } catch (_) {}
    }
  }

  /// 파일 전체를 읽는다. 내보내기·덤프에서 쓴다.
  static Future<String> readAll() async {
    final f = _file;
    if (f == null) return '(로그 파일 없음)';
    try {
      return await f.readAsString();
    } catch (e) {
      // 손상됐으면 비우고 다시 시작한다 — 읽을 수 없는 파일을 붙들고 있을 이유가 없다
      try {
        await f.writeAsString('', flush: true);
        sizeBytes.value = 0;
      } catch (_) {}
      return '(로그 파일을 읽지 못해 비웠습니다: $e)';
    }
  }

  static Future<void> clear() async {
    final f = _file;
    if (f == null) return;
    try {
      await f.writeAsString('', flush: true);
      sizeBytes.value = 0;
    } catch (_) {}
  }

  @visibleForTesting
  static void resetForTest() {
    _file = null;
    _initFailed = false;
    _queue = Future<void>.value();
    sizeBytes.value = 0;
  }

  /// 테스트에서 임시 파일을 물린다. 실제 문서 폴더를 건드리지 않는다.
  @visibleForTesting
  static void useFileForTest(File f) {
    _file = f;
    _initFailed = false;
    sizeBytes.value = f.existsSync() ? f.lengthSync() : 0;
  }

  /// 큐에 쌓인 쓰기가 끝날 때까지 기다린다. 테스트에서만 쓴다.
  @visibleForTesting
  static Future<void> flushForTest() => _queue;
}
