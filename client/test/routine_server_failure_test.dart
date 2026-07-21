import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:flutter_test/flutter_test.dart';

/// 서버 실패 시 클라이언트가 **로컬 가짜 일과를 만들지 않는지** 고정한다.
///
/// 과거엔 실패를 흡수해 로컬 카드('local' id)를 만들었으나, 그 일과는
/// confirm 시 `/api/routines/local/confirm` → 404가 나고 아이 모드에도 뜨지 않는
/// 유령 일과가 됐다(데이터 정합성 문제). 이제 실패하면 예외를 던지고,
/// notifier가 에러 상태로 전환해 **AI 재호출(재시도)** 로만 복구한다.
///
/// 이 테스트는 `useMock=false`인 실제 경로를 검증한다 — mock을 켜면 서버를 아예
/// 타지 않아 실패 경로를 확인할 수 없다.
void main() {
  late _FakeAdapter adapter;
  late RoutineRepositoryImpl repo;

  setUp(() {
    // 실제 서버 경로를 검증한다. mock이 켜지면 요청 자체를 하지 않아
    // fallback이 도는지 확인할 수 없다.
    dotenv.loadFromString(envString: 'ELUM_USE_MOCK=false');

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

  group('목록 조회가 실패할 때', () {
    test('빈 목록을 준다 — 홈이 죽지 않는다', () async {
      adapter.stub(502, {'errorCode': 'INTERNAL_ERROR'});

      expect(await repo.getMyRoutines(), isEmpty);
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
