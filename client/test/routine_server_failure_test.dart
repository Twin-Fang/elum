import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:flutter_test/flutter_test.dart';

/// 서버가 실패해도 화면이 진행되는지 고정한다.
///
/// `POST /api/routines`가 실측상 3회 중 2회 502를 낸다(이슈 #34). 서버가 고쳐질
/// 때까지 **클라이언트는 그 실패를 흡수해야** 데모가 멈추지 않는다 (docs 원칙 6번).
///
/// 이 테스트는 `useMock=false`인 실제 경로를 검증한다 — mock을 켜면 서버를 아예
/// 타지 않아 fallback이 도는지 확인할 수 없다.
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
    test('예외를 던지지 않고 로컬 카드를 준다', () async {
      // 이슈 #34의 실제 응답
      adapter.stub(502, {
        'errorCode': 'ROUTINE_AI_GENERATION_FAILED',
        'errorMessage': 'AI 생성 처리에 실패했습니다.',
      });

      final routine = await repo.createRoutine(
        rawInputText: '비 오는 날 등교 준비하기',
        goals: {SupportGoal.prepareItems},
      );

      // 카드가 비면 다음 화면이 빈 상태가 된다
      expect(routine.steps, isNotEmpty);
    });

    test('로컬 카드에도 제목과 설명이 들어 있다', () async {
      // Figma 카드는 제목·설명을 나눠 보여준다. 하나라도 비면 칸이 빈다.
      adapter.stub(502, {'errorCode': 'ROUTINE_AI_GENERATION_FAILED'});

      final routine = await repo.createRoutine(
        rawInputText: '비 오는 날 등교 준비하기',
        goals: const {},
      );

      for (final card in routine.steps) {
        expect(card.displayTitle, isNotEmpty);
        expect(card.description, isNotEmpty);
      }
    });

    test('단계 수 초과(다른 502 코드)도 흡수한다', () async {
      // 서버가 10단계를 넘기면 ROUTINE_STEP_LIMIT_EXCEEDED를 준다
      adapter.stub(502, {'errorCode': 'ROUTINE_STEP_LIMIT_EXCEEDED'});

      final routine = await repo.createRoutine(
        rawInputText: '손 씻기',
        goals: const {},
      );

      expect(routine.steps, isNotEmpty);
    });

    test('서버가 빈 카드를 줘도 로컬로 대체한다', () async {
      // 200이지만 steps가 비어 있는 경우
      adapter.stub(200, {'id': 'r1', 'title': '제목', 'steps': <dynamic>[]});

      final routine = await repo.createRoutine(
        rawInputText: '손 씻기',
        goals: const {},
      );

      expect(routine.steps, isNotEmpty);
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
