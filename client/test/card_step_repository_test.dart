import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dio.dart';

/// 카드 추가·순서 저장의 **서버 계약** (#444).
///
/// 위젯 테스트는 저장소 자리에 가짜를 끼우므로 요청이 서버가 받는 모양으로 나가는지
/// 보지 못한다. 여기서는 진짜 [RoutineRepositoryImpl] 을 가짜 HTTP 위에서 돌려
/// 경로·본문·응답 읽기를 본다.
///
/// 서버 원본: `RoutineController.addStep` (`POST /{routineId}/steps`,
/// `RoutineStepCreateRequest{title, description, generateImage}`) ·
/// `reorderSteps` (`PATCH /{routineId}/steps/order`, `{stepIds}`).
void main() {
  const routine = Routine(
    id: 'r1',
    title: '학교에 가요',
    status: 'PENDING_REVIEW',
    steps: [
      ActionCard(id: 'c1', stepOrder: 1, description: '옷을 입어요'),
      ActionCard(id: 'c2', stepOrder: 2, description: '가방을 챙겨요'),
    ],
  );

  ({RoutineRepositoryImpl repo, _Capture adapter}) setUp(
    Map<String, Object?> routes,
  ) {
    final adapter = _Capture(routes);
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    return (repo: RoutineRepositoryImpl(dio: dio), adapter: adapter);
  }

  Map<String, Object?> routineJson(List<Map<String, Object?>> steps) => {
    'id': 'r1',
    'title': '학교에 가요',
    'status': 'PENDING_REVIEW',
    'steps': steps,
  };

  group('addStep', () {
    test('POST /steps 로 제목과 설명만 보낸다 — 그림 생성을 요청하지 않는다', () async {
      final f = setUp({
        'POST /api/routines/r1/steps': routineJson([
          {'id': 'c1', 'stepOrder': 1, 'description': '옷을 입어요'},
          {'id': 'c2', 'stepOrder': 2, 'description': '가방을 챙겨요'},
          {'id': 'n1', 'stepOrder': 3, 'description': '이를 닦아요'},
        ]),
      });

      final result = await f.repo.addStep(
        routine,
        title: '양치를 해요',
        description: '이를 닦아요',
      );

      expect(result.failure, isNull);
      expect(f.adapter.bodies.single, {
        'title': '양치를 해요',
        'description': '이를 닦아요',
      });
      // generateImage 를 주면 서버가 크레딧을 쓰고 그림을 그린다(#407). 시안에 그 선택이 없다.
      expect(f.adapter.bodies.single.containsKey('generateImage'), isFalse);
    });

    test('응답의 카드 목록을 읽는다', () async {
      final f = setUp({
        'POST /api/routines/r1/steps': routineJson([
          {'id': 'c1', 'stepOrder': 1, 'description': '옷을 입어요'},
          {'id': 'c2', 'stepOrder': 2, 'description': '가방을 챙겨요'},
          {'id': 'n1', 'stepOrder': 3, 'description': '이를 닦아요'},
        ]),
      });

      final result = await f.repo.addStep(
        routine,
        title: '양치를 해요',
        description: '이를 닦아요',
      );

      expect([for (final s in result.routine.steps) s.id], ['c1', 'c2', 'n1']);
    });

    test('서버가 거절하면 일과를 그대로 두고 이유를 돌려준다', () async {
      final f = setUp({
        'POST /api/routines/r1/steps': const FakeHttpError(
          409,
          errorCode: 'ROUTINE_INVALID_STATUS',
          errorMessage: '이 일과는 고칠 수 없어요.',
        ),
      });

      final result = await f.repo.addStep(
        routine,
        title: '양치를 해요',
        description: '이를 닦아요',
      );

      expect(result.failure, isNotNull);
      expect(result.routine, routine, reason: '실패해도 없는 카드를 로컬에 넣지 않는다');
    });

    test('서버에 닿지 못하면 연결 실패로 알린다', () async {
      final f = setUp({'POST /api/routines/r1/steps': const FakeOffline()});

      final result = await f.repo.addStep(
        routine,
        title: '양치를 해요',
        description: '이를 닦아요',
      );

      expect(result.failure?.fault, NetworkFault.offline);
      expect(result.routine, routine);
    });

    test('서버에 없는 로컬 일과는 서버를 부르지 않고 로컬에 넣는다', () async {
      final f = setUp(const {});
      const local = Routine(
        id: '',
        steps: [ActionCard(id: 'c1', stepOrder: 1, description: '옷을 입어요')],
      );

      final result = await f.repo.addStep(
        local,
        title: '양치를 해요',
        description: '이를 닦아요',
      );

      expect(f.adapter.calls, isEmpty);
      expect(result.failure, isNull);
      expect(result.routine.steps, hasLength(2));
      expect(result.routine.steps.last.title, '양치를 해요');
    });
  });

  group('reorderSteps', () {
    test('PATCH /steps/order 로 카드 id 전체를 순서대로 보낸다', () async {
      final f = setUp({
        'PATCH /api/routines/r1/steps/order': const <String, Object?>{},
      });

      final failure = await f.repo.reorderSteps('r1', ['c2', 'c1']);

      expect(failure, isNull);
      expect(f.adapter.calls, ['PATCH /api/routines/r1/steps/order']);
      expect(f.adapter.bodies.single, {
        'stepIds': ['c2', 'c1'],
      });
    });

    test('서버가 거절하면 이유를 돌려준다', () async {
      final f = setUp({
        'PATCH /api/routines/r1/steps/order': const FakeHttpError(
          400,
          errorCode: 'INVALID_INPUT_VALUE',
        ),
      });

      final failure = await f.repo.reorderSteps('r1', ['c2', 'c1']);

      expect(failure, isNotNull);
    });
  });
}

/// 나간 요청의 본문까지 남기는 가짜 어댑터. [FakeAdapter] 는 경로만 남긴다.
class _Capture extends FakeAdapter {
  _Capture(super.routes);

  final bodies = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final data = options.data;
    if (data is Map<String, dynamic>) bodies.add(data);
    return super.fetch(options, requestStream, cancelFuture);
  }
}
