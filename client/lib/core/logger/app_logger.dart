import 'package:flutter/foundation.dart';

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
  static void _log(String tag, String message, [Map<String, dynamic>? data]) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${(now.millisecond).toString().padLeft(3, '0')}';

    if (data == null || data.isEmpty) {
      debugPrint('[$timeStr] $tag $message');
    } else {
      final dataStr = _formatData(data);
      debugPrint('[$timeStr] $tag $message\n  $dataStr');
    }
  }

  /// 데이터를 보기 좋게 포맷팅
  static String _formatData(Map<String, dynamic> data) {
    return data.entries
        .map((e) => '${e.key}: ${_formatValue(e.value)}')
        .join(' | ');
  }

  /// 값을 문자열로 변환 (깊은 객체도 표시)
  static String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return value.length > 100 ? '${value.substring(0, 100)}...' : value;
    if (value is num || value is bool) return value.toString();
    if (value is List) return '[${value.length} items]';
    if (value is Map) return '{${value.length} entries}';
    return value.runtimeType.toString();
  }

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
      if (responseData != null) 'response': responseData,
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
      if (errorMessage != null) 'message': errorMessage,
      if (errorData != null) 'error': errorData,
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
      if (result != null) 'result': result,
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
    _log(_tagStorage, '읽기', data);
  }

  /// SharedPreferences 쓰기
  static void storageWrite(String key, dynamic value) {
    final data = {
      'action': 'write',
      'key': key,
      'value': value,
    };
    _log(_tagStorage, '쓰기', data);
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
    _log(_tagError, '예외 발생', data);
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
