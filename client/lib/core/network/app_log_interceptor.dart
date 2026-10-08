import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../logger/app_logger.dart';

/// 요청·응답·실패를 의견 첨부 기록에 남기는 인터셉터.
///
/// 요청마다 짧은 id 를 `X-Request-Id` 로 보내고 기록에도 같은 id 를 적는다 —
/// 서버 로그와 맞춰 보려는 것이다. 토큰·암호 값은 가리고 Authorization 은 아예 적지 않는다.
/// 기록하다 던지면 통신이 깨지므로 모든 기록 코드는 예외를 삼킨다.
class AppLogInterceptor extends Interceptor {
  AppLogInterceptor({Random? random}) : _random = random ?? Random.secure();

  static const requestIdHeader = 'X-Request-Id';

  /// 한 본문당 최대 글자 수.
  static const maxBodyChars = 8000;

  /// 값을 가릴 키(소문자). `code` 는 정확히 이 이름만 가린다.
  static const _secretKeys = {
    'accesstoken',
    'refreshtoken',
    'idtoken',
    'token',
    'password',
    'pin',
    'guardianpin',
    'authorization',
    'secret',
    'code',
  };

  /// 기록에 남길 요청 헤더. 이 밖의 헤더(Authorization 포함)는 적지 않는다.
  static const _shownHeaders = ['accept-language', 'x-profile-id'];

  static const _idKey = '_elumLogId';
  static const _startKey = '_elumLogWatch';

  final Random _random;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    try {
      final id = _newId();
      options.headers[requestIdHeader] = id;
      options.extra[_idKey] = id;
      options.extra[_startKey] = Stopwatch()..start();

      final buf = StringBuffer(
        '→ [$id] ${options.method} ${_pathWithQuery(options)}',
      );
      for (final name in _shownHeaders) {
        final v = _header(options.headers, name);
        if (v != null) buf.write('\n  $name: $v');
      }
      // 의견 요청 본문은 이 기록 자신이라, 남기면 다음 전송 때 기록 안에 기록이 겹쳐 쌓인다.
      final body = options.uri.path.endsWith('/api/feedback')
          ? '(feedback body omitted)'
          : describeBody(options.data, _header(options.headers, 'content-type'));
      if (body != null) buf.write('\n  body: $body');
      AppLogger.network(buf.toString());
    } catch (_) {}
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    try {
      final o = response.requestOptions;
      final buf = StringBuffer(
        '← [${_idOf(o)}] ${response.statusCode ?? 0} ${o.method} ${o.uri.path} '
        '(${_elapsedMs(o)}ms)',
      );
      final body = describeBody(
        response.data,
        response.headers.value('content-type'),
      );
      if (body != null) buf.write('\n  body: $body');
      AppLogger.network(buf.toString());
    } catch (_) {}
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    try {
      final o = err.requestOptions;
      final res = err.response;
      final buf = StringBuffer(
        '✕ [${_idOf(o)}] ${o.method} ${o.uri.path} '
        'status=${res?.statusCode ?? 0} '
        'serverErrorCode=${_serverErrorCode(res?.data) ?? '-'} '
        'type=${err.type.name} message=${err.message ?? '-'} '
        '(${_elapsedMs(o)}ms)',
      );
      final body = describeBody(res?.data, res?.headers.value('content-type'));
      if (body != null) buf.write('\n  body: $body');
      AppLogger.network(buf.toString());
    } catch (_) {}
    handler.next(err);
  }

  /// 본문을 기록용 문자열로 바꾼다. 남길 것이 없으면 null.
  static String? describeBody(Object? data, String? contentType) {
    if (data == null) return null;
    if (data is FormData) return '[multipart]';
    final type = (contentType ?? '').toLowerCase();
    if (type.startsWith('multipart/')) return '[multipart]';
    if (type.startsWith('image/')) return '[이미지 생략]'; // l10n-ignore: 기록 문구
    if (data is Uint8List || data is List<int>) {
      return '바이트 ${(data as List).length}개'; // l10n-ignore: 기록 문구
    }

    Object? tree = data;
    if (data is String) {
      final s = data.trimLeft();
      if (s.startsWith('{') || s.startsWith('[')) {
        try {
          tree = jsonDecode(s);
        } catch (_) {
          return _cap(data);
        }
      } else {
        return _cap(data);
      }
    }
    if (tree is Map || tree is List) {
      try {
        return _cap(
          jsonEncode(_mask(tree), toEncodable: (o) => o.toString()),
        );
      } catch (_) {
        return _cap(tree.toString());
      }
    }
    return _cap(tree.toString());
  }

  /// 비밀 키의 값을 `****` 로 바꾼 사본. 중첩 Map·List 도 따라간다.
  static Object? _mask(Object? v) {
    if (v is Map) {
      return {
        for (final e in v.entries)
          '${e.key}': _secretKeys.contains('${e.key}'.toLowerCase())
              ? '****'
              : _mask(e.value),
      };
    }
    if (v is List) return v.map(_mask).toList();
    return v;
  }

  static String _cap(String s) => s.length > maxBodyChars
      ? '${s.substring(0, maxBodyChars)}…(${s.length - maxBodyChars}자 생략)' // l10n-ignore: 기록 문구
      : s;

  /// 주소 뒤 쿼리 값도 비밀 키는 가린다(OAuth 코드 등).
  static String _pathWithQuery(RequestOptions o) {
    final q = o.uri.queryParameters;
    if (q.isEmpty) return o.uri.path;
    final masked = q.entries
        .map((e) =>
            '${e.key}=${_secretKeys.contains(e.key.toLowerCase()) ? '****' : e.value}')
        .join('&');
    return '${o.uri.path}?$masked';
  }

  static String? _serverErrorCode(Object? data) {
    if (data is Map) {
      final c = data['errorCode'];
      if (c != null) return '$c';
    }
    return null;
  }

  String _newId() => List.generate(
    16,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();

  /// 다른 인터셉터가 요청을 가로채 이 인터셉터의 onRequest 를 못 탄 경우는 '-'.
  static String _idOf(RequestOptions o) {
    final id = o.extra[_idKey];
    return id is String ? id : '-';
  }

  static int _elapsedMs(RequestOptions o) {
    final w = o.extra[_startKey];
    return w is Stopwatch ? w.elapsedMilliseconds : 0;
  }

  static String? _header(Map<String, dynamic> headers, String name) {
    for (final e in headers.entries) {
      if (e.key.toLowerCase() == name) return e.value?.toString();
    }
    return null;
  }
}
