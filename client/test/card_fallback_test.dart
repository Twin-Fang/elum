import 'package:elum/features/guardian/data/card_repository.dart';
import 'package:elum/shared/models/support_goal.dart';
import 'package:flutter_test/flutter_test.dart';

/// fallback은 데모 성립 조건이다 (docs 원칙 6번).
/// "어떤 실패에도 카드가 나온다"가 깨지면 발표 중 화면이 비어버린다.
void main() {
  const request = RoutineRequest(
    routineText: '내일 비가 많이 올 예정이야.',
    supportGoals: {SupportGoal.prepareItems},
  );

  group('CardRepository fallback 체인', () {

    test('서버가 예외를 던져도 카드를 반환한다', () async {
      final repo = CardRepositoryImpl(
        remote: (_) async => throw Exception('서버 다운'),
      );

      final cards = await repo.generateCards(request);
      expect(cards, isNotEmpty);
    });

    test('서버 연결 자체가 없어도 카드를 반환한다', () async {
      const repo = CardRepositoryImpl();

      final cards = await repo.generateCards(request);
      expect(cards, isNotEmpty);
    });

    test('어떤 목표 조합이든 절대 throw하지 않는다', () async {
      final repo = CardRepositoryImpl(
        remote: (_) async => throw Exception('실패'),
      );

      for (final goals in [
        <SupportGoal>{},
        {SupportGoal.prepareItems},
        SupportGoal.values.toSet(),
      ]) {
        final cards = await repo.generateCards(
          RoutineRequest(routineText: '테스트', supportGoals: goals),
        );
        expect(cards, isNotEmpty, reason: '목표 $goals 에서 카드가 비었다');
      }
    });
  });

}
