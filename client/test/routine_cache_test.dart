import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_test/flutter_test.dart';

/// 오늘 일과 목록의 오프라인 캐시 (이슈 #140).
///
/// 인터넷이 끊기면 `/api/routines/today`가 실패한다. 마지막 성공 응답을 저장해 두고
/// 그걸 보여줘야 아동 모드가 오프라인에서도 비지 않는다.
void main() {
  late _StubAdapter adapter;
  late InMemoryStorage storage;
  late RoutineRepositoryImpl repo;

  setUp(() {
    // 실서버 경로를 타야 캐시가 동작한다. mock이면 요청 자체를 안 한다.
    adapter = _StubAdapter();
    storage = InMemoryStorage();
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    repo = RoutineRepositoryImpl(dio: dio, storage: storage);
  });

  const serverBody = [
    {
      'id': 'r1',
      'title': '비 오는 날 학교 가기',
      'status': 'CONFIRMED',
      'steps': [
        {
          'id': 'c1',
          'description': '옷을 입어요',
          'stepOrder': 1,
          'completed': true,
        },
        {
          'id': 'c2',
          'description': '우산을 챙겨요',
          'stepOrder': 2,
          'completed': false,
        },
      ],
      'completedStepCount': 1,
      'totalStepCount': 2,
      'progressPercent': 50,
    },
  ];

  test('성공 응답을 캐시에 저장한다', () async {
    adapter.stubJson(200, serverBody);

    await repo.getTodayRoutines();

    final cached =
        jsonDecode(storage.cachedTodayRoutinesJson!) as List<dynamic>;
    expect(cached, hasLength(1));
    expect((cached.first as Map)['id'], 'r1');
  });

  test('네트워크가 끊기면 캐시를 돌려준다', () async {
    adapter.stubJson(200, serverBody);
    await repo.getTodayRoutines();
    adapter.fail = true;

    final routines = await repo.getTodayRoutines();

    expect(routines.map((r) => r.id), ['r1']);
    expect(routines.first.steps.first.completed, isTrue);
  });

  test('캐시도 없으면 실패를 드러낸다 (이슈 #264)', () async {
    // 오프라인 캐시는 그대로 둔다 — 비행기 모드에서도 오늘 할 일은 보여야 한다.
    // 다만 캐시마저 없으면 보여줄 것이 없으므로 빈 목록으로 뭉개지 않는다.
    // 빈 목록은 "오늘 할 일이 없다"는 뜻이라 실패와 구분되지 않는다.
    adapter.fail = true;

    expect(() => repo.getTodayRoutines(), throwsA(anything));
  });

  group('캐시·폴백도 오늘 + 승인된 것만 준다 (이슈 #353)', () {
    // 서버가 /today 로 거르는 규칙을 오프라인 경로도 지켜야 한다 — 어제 받아 둔 캐시나
    // 전체 목록 폴백이 그대로 나가면 어제 것·승인 전 것이 오늘 일과로 뜬다.
    final now = DateTime.now();
    final today9 = DateTime(now.year, now.month, now.day, 9).toIso8601String();
    final yesterday9 =
        DateTime(now.year, now.month, now.day - 1, 9).toIso8601String();

    Map<String, dynamic> item(String id, String status, String at) => {
      'id': id,
      'title': id,
      'status': status,
      'steps': const [],
      'scheduledAt': at,
    };

    test('어제 받아 둔 캐시는 오프라인이어도 오늘 일과로 나가지 않는다', () async {
      await storage.setCachedTodayRoutinesJson(
        jsonEncode([
          item('어제 것', 'CONFIRMED', yesterday9),
          item('오늘 것', 'CONFIRMED', today9),
        ]),
      );
      adapter.fail = true;

      final routines = await repo.getTodayRoutines();

      expect(routines.map((r) => r.id), ['오늘 것']);
    });

    test('캐시에 승인 전 일과가 섞여 있어도 나가지 않는다', () async {
      await storage.setCachedTodayRoutinesJson(
        jsonEncode([
          item('임시저장', 'PENDING_REVIEW', today9),
          item('오늘 것', 'CONFIRMED', today9),
        ]),
      );
      adapter.fail = true;

      final routines = await repo.getTodayRoutines();

      expect(routines.map((r) => r.id), ['오늘 것']);
    });

    test('캐시도 없어 전체 조회로 폴백하면 어제 것·승인 전 것을 뺀다', () async {
      // /today 만 실패하고 전체 조회는 성공하는 경우 — 폴백이 전체를 그대로 주면 안 된다.
      adapter.failPath = '/api/routines/today';
      adapter.stubJson(200, [
        item('임시저장', 'PENDING_REVIEW', today9),
        item('어제 것', 'CONFIRMED', yesterday9),
        item('오늘 것', 'CONFIRMED', today9),
        item('오늘 끝난 것', 'COMPLETED', today9),
      ]);

      final routines = await repo.getTodayRoutines();

      expect(routines.map((r) => r.id), ['오늘 것', '오늘 끝난 것']);
    });

    test('서버가 준 /today 목록은 그대로 쓴다 — 날짜를 몰라도 거르지 않는다', () async {
      // scheduledAt 이 없으면 날짜를 알 수 없다. 서버가 이미 거른 응답이므로 믿는다.
      adapter.stubJson(200, serverBody);

      final routines = await repo.getTodayRoutines();

      expect(routines.map((r) => r.id), ['r1']);
    });
  });

  test('Routine.toJson은 fromJson과 왕복한다 (원문 계열은 제외)', () {
    const routine = Routine(
      id: 'r1',
      title: '제목',
      rawInputText: '원문',
      sanitizedInputText: '<이름> 원문',
      status: 'CONFIRMED',
      steps: [
        ActionCard(id: 'c1', description: '설명', stepOrder: 1, completed: true),
      ],
      completedStepCount: 1,
      totalStepCount: 1,
      progressPercent: 100,
    );

    final json = routine.toJson();
    final restored = Routine.fromJson(json);

    // 원문은 저장 대상이 아니므로 비워서 맞춘다 (#358)
    expect(restored, routine.copyWith(rawInputText: '', sanitizedInputText: ''));
    expect(json.containsKey('rawInputText'), isFalse);
    expect(json.containsKey('sanitizedInputText'), isFalse);
  });

  group('보호자 원문은 캐시에 남지 않는다 (#358)', () {
    const withRaw = [
      {
        'id': 'r1',
        'title': '제목',
        'rawInputText': '비밀 원문 하나',
        'sanitizedInputText': '비밀 마스킹본 둘',
        'revisionFeedback': '비밀 피드백 셋',
        'status': 'CONFIRMED',
        'steps': [],
      },
    ];

    test('서버 응답에 원문이 있어도 캐시 문자열에는 없다', () async {
      adapter.stubJson(200, withRaw);

      await repo.getTodayRoutines();

      final cached = storage.cachedTodayRoutinesJson!;
      expect(cached, isNot(contains('rawInputText')));
      expect(cached, isNot(contains('sanitizedInputText')));
      expect(cached, isNot(contains('비밀')));
      expect(cached, contains('r1'));
    });

    test('옛 빌드가 저장한 캐시는 읽을 때 원문을 지워 다시 쓴다', () async {
      await storage.setCachedTodayRoutinesJson(jsonEncode(withRaw));
      adapter.fail = true;

      final routines = await repo.getTodayRoutines();

      expect(routines.map((r) => r.id), ['r1']);
      final cached = storage.cachedTodayRoutinesJson!;
      expect(cached, isNot(contains('rawInputText')));
      expect(cached, isNot(contains('sanitizedInputText')));
      expect(cached, isNot(contains('비밀')));
    });

    test('형식이 깨진 캐시여도 앱이 죽지 않는다', () async {
      adapter.fail = true;
      for (final broken in ['not json', '{"a":1}', '[1,"x",null]']) {
        await storage.setCachedTodayRoutinesJson(broken);
        // 캐시를 못 쓰면 폴백(전체 조회)도 실패해 던진다 — 형식 오류로 죽는 것과 구분한다.
        try {
          await repo.getTodayRoutines();
        } on DioException {
          // 네트워크 실패는 정상 경로
        }
      }
    });
  });
}

/// 응답을 미리 정해두거나 연결 실패를 흉내내는 어댑터.
class _StubAdapter implements HttpClientAdapter {
  int _status = 200;
  Object _body = const [];
  bool fail = false;

  /// 이 경로만 연결 실패로 만든다 (나머지는 정상 응답).
  String? failPath;

  void stubJson(int status, Object body) {
    _status = status;
    _body = body;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (fail || options.path == failPath) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(_body),
      _status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
