import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
    dotenv.loadFromString(envString: 'ELUM_USE_MOCK=false');
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

  test('캐시가 없으면 기존 폴백(빈 목록)으로 간다', () async {
    adapter.fail = true;

    final routines = await repo.getTodayRoutines();

    expect(routines, isEmpty);
  });

  test('Routine.toJson은 fromJson과 왕복한다', () {
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

    final restored = Routine.fromJson(routine.toJson());

    expect(restored, routine);
  });
}

/// 응답을 미리 정해두거나 연결 실패를 흉내내는 어댑터.
class _StubAdapter implements HttpClientAdapter {
  int _status = 200;
  Object _body = const [];
  bool fail = false;

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
    if (fail) {
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
