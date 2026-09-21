import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_test/flutter_test.dart';

/// 서버 실패 시 클라이언트가 **로컬 가짜 일과를 만들지 않는지** 고정한다.
///
/// 과거엔 실패를 흡수해 로컬 카드('local' id)를 만들었으나, 그 일과는
/// confirm 시 `/api/routines/local/confirm` → 404가 나고 아이 모드에도 뜨지 않는
/// 유령 일과가 됐다(데이터 정합성 문제). 이제 실패하면 예외를 던지고,
/// notifier가 에러 상태로 전환해 **AI 재호출(재시도)** 로만 복구한다.
///
void main() {
  late _FakeAdapter adapter;
  late RoutineRepositoryImpl repo;

  setUp(() {
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    repo = RoutineRepositoryImpl(dio: dio);
  });

  group('카드 생성이 502일 때', () {
    test('로컬 카드로 흡수하지 않고 예외를 던진다', () async {
      // 이슈 #34의 실제 응답. 과거엔 흡수했지만, 이제는 실패를 드러내
      // notifier가 에러 화면 + AI 재시도로 처리하게 한다.
      adapter.stub(502, {
        'errorCode': 'ROUTINE_AI_GENERATION_FAILED',
        'errorMessage': 'AI 생성 처리에 실패했습니다.',
      });

      expect(
        () => repo.createRoutine(
          rawInputText: '비 오는 날 등교 준비하기',
          goals: {SupportGoal.prepareItems},
        ),
        throwsA(anything),
      );
    });

    test('단계 수 초과(다른 502 코드)도 예외를 던진다', () async {
      adapter.stub(502, {'errorCode': 'ROUTINE_STEP_LIMIT_EXCEEDED'});

      expect(
        () => repo.createRoutine(rawInputText: '손 씻기', goals: const {}),
        throwsA(anything),
      );
    });

    test('서버가 빈 카드(steps 0장)를 주면 예외를 던진다', () async {
      // 200이지만 steps가 비어 있는 경우 — 가짜 일과를 만들지 않는다
      adapter.stub(200, {'id': 'r1', 'title': '제목', 'steps': <dynamic>[]});

      expect(
        () => repo.createRoutine(rawInputText: '손 씻기', goals: const {}),
        throwsA(anything),
      );
    });

    test('성공하면 서버 카드를 그대로 쓴다', () async {
      adapter.stub(200, {
        'id': 'r1',
        'title': '비 오는 날 등교 준비하기',
        'steps': [
          {'id': 's1', 'description': '우산을 챙겨요', 'stepOrder': 1},
        ],
      });

      final routine = await repo.createRoutine(
        rawInputText: '비 오는 날 등교 준비하기',
        goals: const {},
      );

      expect(routine.id, 'r1');
      expect(routine.steps.single.description, '우산을 챙겨요');
    });
  });

  group('질문 생성이 실패할 때', () {
    test('대체 질문을 준다 — 화면이 비지 않는다', () async {
      adapter.stub(502, {'errorCode': 'ROUTINE_AI_GENERATION_FAILED'});

      final question = await repo.generateQuestion('비 오는 날 등교');

      expect(question.canAsk, isTrue);
      expect(question.askable, isNotEmpty);
    });
  });

  group('승인이 실패할 때 (이슈 #264)', () {
    test('로컬 승인으로 덮지 않고 예외를 던진다', () async {
      // 예전에는 실패해도 로컬에서 status를 CONFIRMED로 바꿔 돌려줬다.
      // 그러면 보호자 화면은 승인됐는데 서버엔 반영이 없어, 이룸이 휴대폰에는
      // 아무것도 뜨지 않는다. 그때 보호자가 의심할 곳은 앱이 아니라 이룸이다.
      adapter.stub(502, {'errorCode': 'INTERNAL_ERROR'});

      expect(
        () => repo.confirm(const Routine(id: 'r1', status: 'PENDING_REVIEW')),
        throwsA(anything),
      );
    });

    test('서버에 없는 일과는 승인을 시도하지 않는다', () async {
      // id가 비면 /api/routines//confirm 이 되어 엉뚱한 404가 난다.
      expect(
        () => repo.confirm(const Routine(id: '', status: 'PENDING_REVIEW')),
        throwsA(isA<StateError>()),
      );
    });

    test('성공하면 서버가 준 상태를 그대로 쓴다', () async {
      adapter.stub(200, {'id': 'r1', 'title': '아침 준비', 'status': 'CONFIRMED'});

      final confirmed = await repo.confirm(
        const Routine(id: 'r1', status: 'PENDING_REVIEW'),
      );

      expect(confirmed.status, 'CONFIRMED');
    });
  });

  group('목록 조회가 실패할 때 (이슈 #264)', () {
    test('빈 목록으로 뭉개지 않고 예외를 던진다', () async {
      // 예전에는 빈 목록을 돌려줬다. 그러면 "아직 만든 일과가 없어요"와
      // "불러오지 못했어요"가 같은 화면이 되어, 보호자는 무엇이 잘못됐는지
      // 알 수 없고 우리도 제보를 받아 추적할 수 없다.
      adapter.stub(502, {'errorCode': 'INTERNAL_ERROR'});

      expect(() => repo.getMyRoutines(), throwsA(anything));
    });

    test('추천도 내장 데이터로 대신하지 않는다', () async {
      adapter.stub(502, {'errorCode': 'INTERNAL_ERROR'});

      expect(() => repo.getSuggestions(), throwsA(anything));
    });
  });
}

class _FakeAdapter implements HttpClientAdapter {
  int _status = 200;
  Map<String, dynamic> _body = const {};

  void stub(int status, Map<String, dynamic> body) {
    _status = status;
    _body = body;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_status >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: _status,
          data: _body,
        ),
        type: DioExceptionType.badResponse,
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
