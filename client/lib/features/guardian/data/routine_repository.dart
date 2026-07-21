import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/routine.dart';
import '../../onboarding/domain/support_goal.dart';
import 'demo_cards.dart';

/// 일과 저장소.
///
/// **절대 throw하지 않는다.** 데모는 어떤 실패에도 끝까지 진행되어야 한다 (docs 원칙 6번).
/// 화면은 에러 분기를 쓸 일이 없고, 따라서 빠뜨릴 수도 없다.
abstract interface class RoutineRepository {
  /// AI 추가 질문. 실패하면 "질문 없음"으로 처리해 다음 단계로 넘긴다.
  Future<RoutineQuestion> generateQuestion(String rawInputText);

  /// 일과 생성 → 카드 5장.
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers,
  });

  /// 보호자 승인. 이후에만 아동 화면에 노출된다 (docs 원칙 3번).
  Future<Routine> confirm(Routine routine);

  /// 카드 문장 수정
  Future<Routine> updateStep(Routine routine, String stepId, String description);
}

class RoutineRepositoryImpl implements RoutineRepository {
  RoutineRepositoryImpl({Dio? dio}) : _dio = dio ?? DioClient.create();

  final Dio _dio;

  @override
  Future<RoutineQuestion> generateQuestion(String rawInputText) async {
    if (AppConfig.useMock) return _mockQuestion();

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/routines/questions',
        data: {'rawInputText': rawInputText},
      );
      final body = res.data;
      if (body != null) return RoutineQuestion.fromJson(body);
    } catch (e) {
      debugPrint('[fallback] 질문 생성 실패 → mock 질문 사용: $e');
    }
    return _mockQuestion();
  }

  @override
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers = const [],
  }) async {
    if (!AppConfig.useMock) {
      try {
        final res = await _dio.post<Map<String, dynamic>>(
          '/api/routines',
          data: {
            'rawInputText': rawInputText,
            'scheduledAt': DateTime.now()
                .add(const Duration(days: 1))
                .toIso8601String()
                .split('.')
                .first,
            'answers': answers,
          },
        );
        final body = res.data;
        if (body != null) {
          final routine = Routine.fromJson(body);
          if (routine.steps.isNotEmpty) return routine;
          debugPrint('[fallback:1] 서버가 빈 카드 → 로컬 생성으로 전환');
        }
      } catch (e) {
        debugPrint('[fallback:1] 일과 생성 실패 → 로컬 생성으로 전환: $e');
      }
    }

    return _localRoutine(rawInputText, goals);
  }

  @override
  Future<Routine> confirm(Routine routine) async {
    if (!AppConfig.useMock && routine.id.isNotEmpty) {
      try {
        final res = await _dio.patch<Map<String, dynamic>>(
          '/api/routines/${routine.id}/confirm',
        );
        final body = res.data;
        if (body != null) return Routine.fromJson(body);
      } catch (e) {
        debugPrint('[fallback] 승인 API 실패 → 로컬 상태로 처리: $e');
      }
    }
    // 서버가 없어도 승인은 성립해야 한다 — 데모가 멈추면 안 된다
    return routine.copyWith(status: 'CONFIRMED');
  }

  @override
  Future<Routine> updateStep(
    Routine routine,
    String stepId,
    String description,
  ) async {
    if (!AppConfig.useMock && routine.id.isNotEmpty) {
      try {
        final res = await _dio.patch<Map<String, dynamic>>(
          '/api/routines/${routine.id}/steps/$stepId',
          data: {'description': description},
        );
        final body = res.data;
        if (body != null) return Routine.fromJson(body);
      } catch (e) {
        debugPrint('[fallback] 카드 수정 API 실패 → 로컬 반영: $e');
      }
    }

    return routine.copyWith(
      steps: [
        for (final step in routine.steps)
          if (step.id == stepId) step.copyWith(description: description) else step,
      ],
    );
  }

  // --- 로컬 대체 구현 ---

  RoutineQuestion _mockQuestion() => const RoutineQuestion(
        isRequired: true,
        question: '비 오는 날 평소와 다르게 챙겨야 하는 물건이 있나요?',
        options: ['우산', '장화', '여벌 양말', '우비'],
      );

  /// 서버 없이도 데모가 성립하도록 로컬에서 일과를 구성한다.
  /// DLP 마스킹도 여기서 흉내낸다 — 발표에서 전/후 비교를 보여줘야 하기 때문이다.
  Routine _localRoutine(String rawInputText, Set<SupportGoal> goals) {
    return Routine(
      id: 'local',
      title: '비 오는 날 학교 가기',
      rawInputText: rawInputText,
      sanitizedInputText: LocalDlp.mask(rawInputText),
      status: 'PENDING_REVIEW',
      steps: DemoCards.forGoals(goals),
    );
  }
}

/// 서버가 없을 때 쓰는 로컬 마스킹.
///
/// 실제 DLP는 서버(AI DLP Gateway)가 담당한다. 이건 **데모 대비용**이며,
/// 서버가 붙으면 `sanitizedInputText`를 그대로 쓴다.
abstract final class LocalDlp {
  /// 탐지 유형 4종 — 데모 성립 조건 (docs/07-mvp-scope.md)
  static final _patterns = <String, RegExp>{
    '전화번호': RegExp(r'01[0-9]-?\d{3,4}-?\d{4}'),
    '이메일': RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'),
    '학교명': RegExp(r'[가-힣]+(초등학교|중학교|고등학교|학교)'),
  };

  static String mask(String input) {
    var result = input;
    _patterns.forEach((label, pattern) {
      result = result.replaceAll(pattern, '<$label>');
    });
    return result;
  }

  /// 탐지된 유형 목록. **원문은 담지 않는다** — 유형·건수만 남긴다 (docs 원칙 5번).
  static List<String> detectedTypes(String input) {
    return [
      for (final entry in _patterns.entries)
        if (entry.value.hasMatch(input)) entry.key,
    ];
  }
}

final routineRepositoryProvider = Provider<RoutineRepository>(
  (ref) => RoutineRepositoryImpl(),
);
