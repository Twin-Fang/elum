import 'package:elum/features/guardian/data/card_repository.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// fallback은 데모 성립 조건이다 (docs 원칙 6번).
/// "어떤 실패에도 카드가 나온다"가 깨지면 발표 중 화면이 비어버린다.
void main() {
  const request = RoutineRequest(
    routineText: '내일 비가 많이 올 예정이야.',
    supportGoals: {SupportGoal.prepareItems},
  );

  group('CardRepository fallback 체인', () {
    test('서버가 성공하면 서버 결과를 그대로 쓴다', () async {
      const serverCards = [
        ActionCard(id: 's1', description: '서버가 만든 카드', stepOrder: 1),
      ];
      final repo = CardRepositoryImpl(remote: (_) async => serverCards);

      expect(await repo.generateCards(request), serverCards);
    });

    test('서버가 예외를 던져도 카드를 반환한다', () async {
      final repo = CardRepositoryImpl(
        remote: (_) async => throw Exception('서버 다운'),
      );

      final cards = await repo.generateCards(request);
      expect(cards, isNotEmpty);
    });

    test('서버가 빈 목록을 줘도 카드를 반환한다', () async {
      final repo = CardRepositoryImpl(remote: (_) async => const []);

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

  group('ActionCard 서버 응답 파싱', () {
    test('정상 응답을 파싱한다', () {
      final card = ActionCard.fromJson({
        'id': 'abc',
        'description': '가방을 챙겨요',
        'stepOrder': 2,
        'imagePath': '/img/bag.png',
        'completed': true,
      });

      expect(card.id, 'abc');
      expect(card.description, '가방을 챙겨요');
      expect(card.stepOrder, 2);
      expect(card.completed, isTrue);
    });

    test('필드가 없거나 타입이 달라도 죽지 않는다', () {
      final card = ActionCard.fromJson({'stepOrder': '3'});

      expect(card.id, '');
      expect(card.description, '');
      expect(card.stepOrder, 3); // 문자열 숫자도 받아준다
      expect(card.completed, isFalse);
    });
  });
}
