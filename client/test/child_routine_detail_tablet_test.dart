import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/action_card_view.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/adaptive_test_app.dart';
import 'helpers/fake_dio.dart';
import 'helpers/test_storage.dart';

/// 이룸이 카드 상세: 태블릿에서 카드를 크게, 체크 버튼은 손이 닿는 자리에 둔다.
/// 깨지면: 이룸이가 쓰는 태블릿에서 카드가 폰 크기 그대로 작게 떠 있거나 체크 버튼이 화면 밖에 있다.
void main() {
  const cards = [
    ActionCard(id: 'c1', title: '세수해요', description: '물로 얼굴을 씻어요', stepOrder: 1),
    ActionCard(id: 'c2', title: '옷을 입어요', description: '옷을 차례대로 입어요', stepOrder: 2),
    ActionCard(id: 'c3', title: '신발을 신어요', description: '현관에서 신발을 신어요', stepOrder: 3),
  ];

  Future<void> pumpDetail(WidgetTester tester, Size size) async {
    setTestWindowSize(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          offlineDioOverride(),
          testStorageOverride(onboardingCompleted: true),
          speechServiceProvider.overrideWithValue(_SilentSpeech()),
        ],
        child: adaptiveTestApp(
          home: const ChildRoutineDetailScreen(
            // id 를 local 로 둔다: 서버에 없는 일과라 동기화를 타지 않는다
            routine: Routine(
              id: 'local',
              title: '아침에 학교 갈 준비',
              status: 'CONFIRMED',
              rewardText: '젤리 먹기',
              steps: cards,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  final currentCard = find.byKey(const ValueKey('c1'));
  final checkButton = find.byKey(ChildRoutineDetailScreen.checkButtonKey);

  testWidgets('폰 393x852: 카드는 시안 크기 333 그대로 (회귀 0)', (tester) async {
    await pumpDetail(tester, const Size(393, 852));

    expect(tester.getSize(currentCard).width, closeTo(333, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('가로 태블릿 1194x834: 카드가 크고 체크 버튼은 카드 오른쪽', (tester) async {
    await pumpDetail(tester, const Size(1194, 834));

    final card = tester.getRect(currentCard);
    final button = tester.getRect(checkButton);
    const window = Rect.fromLTWH(0, 0, 1194, 834);

    expect(card.width, greaterThan(480), reason: '폰(333)보다 훨씬 크다');
    expect(card.height, greaterThan(500));
    expect(window.contains(card.topLeft) && window.contains(card.bottomRight), isTrue);
    expect(button.left, greaterThan(card.right - 1), reason: '체크 버튼은 카드 오른쪽');
    expect(window.contains(button.bottomRight), isTrue);
    expect(button.width, greaterThanOrEqualTo(64), reason: '이룸이 터치 영역 64 이상');
    expect(tester.takeException(), isNull);
  });

  testWidgets('세로 태블릿 820x1180: 카드가 크고 체크 버튼은 카드 아래', (tester) async {
    await pumpDetail(tester, const Size(820, 1180));

    final card = tester.getRect(currentCard);
    final button = tester.getRect(checkButton);

    expect(card.width, greaterThan(420));
    expect(button.top, greaterThan(card.bottom - 1), reason: '체크 버튼은 카드 아래');
    expect(button.bottom, lessThanOrEqualTo(1180));
    expect(tester.takeException(), isNull);
  });

  testWidgets('낮은 창 1024x320 에서도 예외 없이 뜬다', (tester) async {
    await pumpDetail(tester, const Size(1024, 320));

    expect(tester.takeException(), isNull);
  });
}

class _SilentSpeech implements SpeechService {
  @override
  Future<bool> speak(String text, {String language = 'ko', StoredSpeechSource? stored}) async => true;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
