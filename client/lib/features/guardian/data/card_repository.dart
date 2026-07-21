import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/action_card.dart';
import '../../onboarding/domain/support_goal.dart';
import 'demo_cards.dart';

/// 카드 생성 요청. 보호자 입력 원문은 DLP를 거친 뒤에만 서버로 나간다.
class RoutineRequest {
  const RoutineRequest({
    required this.routineText,
    required this.supportGoals,
  });

  final String routineText;
  final Set<SupportGoal> supportGoals;
}

/// 카드 생성 저장소.
///
/// **절대 throw하지 않는다.** 어떤 실패에도 카드를 반환한다.
/// 데모는 어떤 실패 상황에서도 끝까지 진행되어야 하기 때문이다 (docs 원칙 6번).
/// 덕분에 UI는 에러 분기를 쓸 일이 없고, 빠뜨릴 수도 없다.
abstract interface class CardRepository {
  Future<List<ActionCard>> generateCards(RoutineRequest request);
}

/// 3단계 fallback 체인을 구현한다.
///
/// 1차 서버 → 2차 목표 반영 기본 세트 → 3차 하드코딩 데모 카드.
/// 어느 단계에서 떨어졌는지는 debugPrint로만 남기고 사용자에겐 드러내지 않는다.
class CardRepositoryImpl implements CardRepository {
  const CardRepositoryImpl({this.remote});

  /// 서버 준비 전에는 null. 그러면 곧바로 2차로 떨어진다.
  final Future<List<ActionCard>> Function(RoutineRequest)? remote;

  @override
  Future<List<ActionCard>> generateCards(RoutineRequest request) async {
    final remoteFn = remote;
    if (remoteFn != null) {
      try {
        final cards = await remoteFn(request);
        if (cards.isNotEmpty) return cards;
        debugPrint('[fallback:1] 서버가 빈 응답 → 기본 세트로 전환');
      } catch (e) {
        debugPrint('[fallback:1] 서버 실패 → 기본 세트로 전환: $e');
      }
    }

    try {
      final cards = DemoCards.forGoals(request.supportGoals);
      if (cards.isNotEmpty) return cards;
      debugPrint('[fallback:2] 기본 세트가 비어있음 → 데모 카드로 전환');
    } catch (e) {
      debugPrint('[fallback:2] 기본 세트 실패 → 데모 카드로 전환: $e');
    }

    // 3차는 순수 상수라 실패할 수 없다.
    return DemoCards.rainySchoolDay;
  }
}

/// 서버 준비 시 이 한 줄만 교체한다.
final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => const CardRepositoryImpl(),
);
