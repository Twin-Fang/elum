import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'app_log_buffer.dart';

/// 애플리케이션 전체에서 사용하는 로거.
/// 타임스탐프, 카테고리, 구조화된 데이터를 자동으로 포함한다.
abstract final class AppLogger {
  // 카테고리별 태그
  static const _tagNetwork = '[네트워크]';
  static const _tagRepository = '[저장소]';
  static const _tagNotifier = '[상태관리]';
  static const _tagUI = '[화면]';
  static const _tagStorage = '[로컬저장]';
  static const _tagError = '[에러]';
  static const _tagLifecycle = '[생명주기]';
  static const _tagData = '[데이터]';

  /// 타임스탐프 포함 로그 출력 (HH:mm:ss.SSS 형식)
  /// [toBuffer] 가 false 면 콘솔에만 찍는다(의견 첨부 기록의 소음 제거용).
  static String _log(
    String tag,
    String message, [
    Map<String, dynamic>? data,
    bool toBuffer = true,
  ]) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${(now.millisecond).toString().padLeft(3, '0')}';

    final String line;
    if (data == null || data.isEmpty) {
      line = '[$timeStr] $tag $message';
    } else {
      line = '[$timeStr] $tag $message\n  ${_formatData(data)}';
    }
    // 의견 보내기 첨부용. 출력 여부와 무관하게 항상 쌓는다.
    if (toBuffer) AppLogBuffer.add(line);
    debugPrint(line);
    return line;
  }

  /// 스택 상위 [lines] 줄. 오류 추적에 필요한 건 앞쪽이다.
  static String topStack(StackTrace? stack, [int lines = 12]) {
    if (stack == null) return '';
    return stack.toString().trimRight().split('\n').take(lines).join('\n');
  }

  // ========== 자유 형식 기록 (인터셉터·관찰자용) ==========

  /// 네트워크 쪽 한 건(요청·응답·연결 상태).
  static void network(String message) => _log(_tagNetwork, message);

  /// 화면 이동.
  static void screen(String message) => _log(_tagUI, message);

  /// 앱 생명주기 변화.
  static void lifecycle(String message) => _log(_tagLifecycle, message);

  /// 데이터를 보기 좋게 포맷팅
  static String _formatData(Map<String, dynamic> data) {
    return data.entries
        .map((e) => '${e.key}: ${_formatValue(e.value)}')
        .join(' | ');
  }

  /// 값을 문자열로 변환 (깊은 객체도 표시)
  /// 값 하나가 로그를 통째로 삼키지 않도록 둔 상한.
  /// 카드 5장 + 이미지 경로가 들어가는 일과 응답이 대략 2~3천자라 넉넉히 잡았다.
  static const _maxExpandedLength = 8000;

  /// 펼쳐서 찍을지. 개발자 도구를 켠 빌드에서만 전체를 남긴다.
  ///
  /// 컬렉션을 `{5 entries}`로만 줄이면 **백엔드가 무슨 값을 보냈는지
  /// 로그만으로 알 수 없어** 실패 원인을 서버 로그에서 따로 찾아야 한다.
  static bool get _expand => kDebugMode || AppConfig.showDevTools;

  static String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is num || value is bool) return value.toString();

    if (!_expand) {
      // 개발자 도구가 꺼진 빌드 — 크기만 남긴다
      if (value is String) {
        return value.length > 100 ? '${value.substring(0, 100)}...' : value;
      }
      if (value is List) return '[${value.length} items]';
      if (value is Map) return '{${value.length} entries}';
      return value.runtimeType.toString();
    }

    if (value is String) return _cap(value);

    // 바이트 목록은 숫자를 펼치지 않는다. 카드 그림 응답(수 MB)이 `[137,80,...]`로
    // 한 줄에 수천 자씩 찍혀 로그를 내보내거나 읽을 수 없었다.
    final bytes = _asBytes(value);
    if (bytes != null) return _describeBytes(bytes);

    // Map·List는 JSON으로 펼친다. 직렬화할 수 없는 값이 섞이면 toString으로 떨어뜨려
    // **로그 한 줄 때문에 예외가 나지 않게** 한다.
    if (value is Map || value is List) {
      try {
        return _cap(jsonEncode(value, toEncodable: (o) => o.toString()));
      } catch (_) {
        return _cap(value.toString());
      }
    }
    return _cap(value.toString());
  }

  /// 바이트 목록처럼 보이면 그 목록을, 아니면 null. 앞 16개만 보고 판단해 큰 목록을 훑지 않는다.
  static List<int>? _asBytes(dynamic value) {
    if (value is! List || value.length < _minBytesLength) return null;
    if (value is List<int>) return value;
    for (var i = 0; i < 16; i++) {
      final e = value[i];
      if (e is! int || e < 0 || e > 255) return null;
    }
    return value.cast<int>();
  }

  /// `바이트 N개`로 줄인다. 앞부분이 글자로 읽히면(502 HTML 오류 페이지 등) 무슨 오류인지
  /// 알 수 있게 앞 120자를 함께 보여 준다. 그림 같은 바이너리는 개수만 남긴다.
  static String _describeBytes(List<int> bytes) {
    final head = bytes.length > _bytesPreview ? bytes.sublist(0, _bytesPreview) : bytes;
    final readable = head.every((b) => b == 9 || b == 10 || b == 13 || (b >= 32 && b <= 126));
    if (!readable) return '바이트 ${bytes.length}개';
    return '바이트 ${bytes.length}개 (${String.fromCharCodes(head).replaceAll(RegExp(r'\s+'), ' ')}…)';
  }

  /// 이 길이 이상의 정수 목록만 바이트로 본다. 짧은 id 목록 같은 것은 그대로 펼친다.
  static const _minBytesLength = 64;
  static const _bytesPreview = 120;

  static String _cap(String s) => s.length > _maxExpandedLength
      ? '${s.substring(0, _maxExpandedLength)}… (${s.length}자 중 앞부분)'
      : s;

  // ========== 네트워크 로깅 ==========

  /// API 요청 시작
  static void networkRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? params,
    Map<String, String>? headers,
  }) {
    final data = {
      'method': method,
      'endpoint': endpoint,
      if (params != null) ...params,
      if (headers != null) 'headers': headers.keys.join(','),
    };
    _log(_tagNetwork, '요청 시작', data);
  }

  /// API 응답 성공
  static void networkSuccess({
    required String method,
    required String endpoint,
    required int statusCode,
    required Duration duration,
    dynamic responseData,
  }) {
    final data = {
      'method': method,
      'endpoint': endpoint,
      'statusCode': statusCode,
      'duration': '${duration.inMilliseconds}ms',
      'response': ?responseData,
    };
    _log(_tagNetwork, '✅ 응답 성공', data);
  }

  /// API 응답 실패
  static void networkError({
    required String method,
    required String endpoint,
    required int statusCode,
    required Duration duration,
    dynamic errorData,
    String? errorMessage,
  }) {
    final data = {
      'method': method,
      'endpoint': endpoint,
      'statusCode': statusCode,
      'duration': '${duration.inMilliseconds}ms',
      'message': ?errorMessage,
      'error': ?errorData,
    };
    _log(_tagNetwork, '❌ 응답 실패', data);
  }

  // ========== 저장소 로깅 ==========

  /// Repository 메서드 호출
  static void repositoryCall(
    String repositoryName,
    String methodName, [
    Map<String, dynamic>? params,
  ]) {
    final data = {
      'repository': repositoryName,
      'method': methodName,
      if (params != null) ...params,
    };
    _log(_tagRepository, '호출', data);
  }

  /// Repository 메서드 완료
  static void repositorySuccess(
    String repositoryName,
    String methodName, [
    dynamic result,
  ]) {
    final data = {
      'repository': repositoryName,
      'method': methodName,
      'result': ?result,
    };
    _log(_tagRepository, '완료', data);
  }

  /// Repository 메서드 실패
  static void repositoryError(
    String repositoryName,
    String methodName,
    dynamic error,
  ) {
    final data = {
      'repository': repositoryName,
      'method': methodName,
      'error': error.toString(),
    };
    _log(_tagRepository, '실패', data);
  }

  // ========== 상태관리 로깅 ==========

  /// Notifier 상태 변화
  static void notifierStateChange(
    String notifierName,
    String beforeState,
    String afterState, [
    Map<String, dynamic>? context,
  ]) {
    final data = {
      'notifier': notifierName,
      'before': beforeState,
      'after': afterState,
      if (context != null) ...context,
    };
    _log(_tagNotifier, '상태 변화', data);
  }

  /// Notifier 메서드 호출
  static void notifierCall(
    String notifierName,
    String methodName, [
    Map<String, dynamic>? params,
  ]) {
    final data = {
      'notifier': notifierName,
      'method': methodName,
      if (params != null) ...params,
    };
    _log(_tagNotifier, '메서드 호출', data);
  }

  // ========== UI 로깅 ==========

  /// 화면 생성
  static void uiScreenCreated(String screenName) {
    _log(_tagUI, '화면 생성: $screenName');
  }

  /// 화면 진입 (build)
  static void uiScreenBuilt(String screenName) {
    _log(_tagUI, '화면 빌드: $screenName');
  }

  /// 화면 제거
  static void uiScreenDisposed(String screenName) {
    _log(_tagUI, '화면 제거: $screenName');
  }

  /// 위젯 이벤트
  static void uiEvent(String screenName, String eventName, [Map<String, dynamic>? data]) {
    final logData = {
      'screen': screenName,
      'event': eventName,
      if (data != null) ...data,
    };
    _log(_tagUI, '이벤트', logData);
  }

  // ========== 로컬저장소 로깅 ==========

  /// SharedPreferences 읽기
  static void storageRead(String key, dynamic value) {
    final data = {
      'action': 'read',
      'key': key,
      'value': value,
    };
    // 읽기는 소음이라 첨부 기록에서 뺀다
    _log(_tagStorage, '읽기', data, false);
  }

  /// SharedPreferences 쓰기
  static void storageWrite(String key, dynamic value) {
    final data = {
      'action': 'write',
      'key': key,
      'value': value,
    };
    // 캐시 쓰기는 응답 캐싱마다 반복돼 기록을 덮는다
    _log(_tagStorage, '쓰기', data, !key.startsWith('cache.'));
  }

  /// SharedPreferences 삭제
  static void storageDelete(String key) {
    final data = {
      'action': 'delete',
      'key': key,
    };
    _log(_tagStorage, '삭제', data);
  }

  // ========== 데이터 로깅 ==========

  /// 데이터 파싱/변환
  static void dataParse(String dataType, dynamic data) {
    final logData = {
      'type': dataType,
      'data': data,
    };
    _log(_tagData, '파싱', logData);
  }

  // ========== 에러 로깅 ==========

  /// 예외 발생
  static void error(
    String category,
    dynamic error, [
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ]) {
    final data = {
      'category': category,
      'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString().split('\n').first,
      if (context != null) ...context,
    };
    final line = _log(_tagError, '예외 발생', data);
    // 오류 전용 보관 — 일반 기록이 쏟아져도 밀리지 않는다
    final stack = topStack(stackTrace);
    AppLogBuffer.addError(stack.isEmpty ? line : '$line\n$stack');
  }

  // ========== 생명주기 로깅 ==========

  /// 앱 시작
  static void appStarted() {
    _log(_tagLifecycle, '앱 시작');
  }

  /// 앱 종료
  static void appTerminated() {
    _log(_tagLifecycle, '앱 종료');
  }
}
