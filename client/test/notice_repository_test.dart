import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elum/features/notice/data/notice_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// 공지 받기 (이슈 #371 · 명세 3-1 `GET /api/app/notices?platform=IOS|ANDROID`).
///
/// **못 받으면 빈 목록이다(N1).** 공지는 부가 기능이라 앱을 막지 않는다 —
/// 에러 화면도 없다. 대신 로그는 남긴다. 조용히 삼키면 서버가 안 주는 건지
/// 앱이 못 받는 건지 가릴 수 없다.
void main() {
  late _Recorder adapter;

  NoticeRepository repo(_Reply reply) {
    adapter = _Recorder(reply);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    return NoticeRepository(dio);
  }

  /// debugPrint 로 나간 로그를 모은다. AppLogger 는 debugPrint 로만 찍는다.
  List<String> captureLogs() {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);
    return logs;
  }

  group('요청', () {
    test('인증 없는 공개 경로에 플랫폼을 붙여 부른다', () async {
      await repo(
        _Reply.json({'hideDays': 7, 'notices': []}),
      ).fetch(NoticePlatform.android);
      expect(adapter.last.path, '/api/app/notices');
      expect(adapter.last.method, 'GET');
      expect(adapter.last.queryParameters, {'platform': 'ANDROID'});

      await repo(
        _Reply.json({'hideDays': 7, 'notices': []}),
      ).fetch(NoticePlatform.ios);
      expect(adapter.last.queryParameters, {'platform': 'IOS'});
    });

    test('플랫폼 값은 서버 NoticePlatform enum 과 같다', () {
      expect(NoticePlatform.ios.wire, 'IOS');
      expect(NoticePlatform.android.wire, 'ANDROID');
    });

    test('지금 플랫폼을 가린다', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(NoticePlatform.current, NoticePlatform.ios);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(NoticePlatform.current, NoticePlatform.android);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  test('받은 공지를 읽고 이미지 경로는 서버 주소에 붙인다', () async {
    final feed = await repo(
      _Reply.json({
        'hideDays': 3,
        'notices': [
          {
            'id': 'a',
            'revision': 1,
            'title': '제목',
            'body': '본문',
            'imageUrl': '/api/app/notices/a/image?v=1',
            'button': null,
          },
        ],
      }),
    ).fetch(NoticePlatform.android);

    expect(feed.hideDays, 3);
    expect(
      feed.notices.single.imageUrl,
      'https://api.test/api/app/notices/a/image?v=1',
    );
  });

  group('N1 못 받으면 빈 목록 — 로그는 남긴다', () {
    for (final (name, reply) in [
      ('서버가 아직 없다(404)', _Reply.status(404)),
      ('서버 오류(500)', _Reply.status(500)),
      ('오프라인', _Reply.offline()),
    ]) {
      test(name, () async {
        final logs = captureLogs();

        final feed = await repo(reply).fetch(NoticePlatform.android);

        expect(feed.notices, isEmpty);
        expect(
          logs.where((l) => l.contains('[에러]') && l.contains('notice')),
          isNotEmpty,
          reason: '실패를 조용히 삼키면 서버가 안 주는 건지 못 받는 건지 모른다',
        );
      });
    }

    test('N2 본문이 기대한 모양이 아니어도 빈 목록이다', () async {
      final feed = await repo(
        _Reply.json(['목록']),
      ).fetch(NoticePlatform.android);
      expect(feed.notices, isEmpty);
    });
  });
}

/// 테스트가 원하는 응답 하나.
class _Reply {
  _Reply.json(this.body) : status = 200, offline = false;
  _Reply.status(this.status) : body = null, offline = false;
  _Reply.offline() : body = null, status = 0, offline = true;

  final Object? body;
  final int status;
  final bool offline;
}

/// 나간 요청을 기록하고 정해진 응답을 돌려준다.
class _Recorder implements HttpClientAdapter {
  _Recorder(this.reply);

  final _Reply reply;
  late RequestOptions last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    if (reply.offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: '비행기 모드',
      );
    }
    return ResponseBody.fromString(
      reply.body == null ? '' : jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
