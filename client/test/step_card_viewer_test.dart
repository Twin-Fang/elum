import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/presentation/widgets/action_card_view.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_detail_sheet.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// 일과 시트에서 카드를 눌러 크게 보기 (Figma `1274:8864`, 이슈 #495).
///
/// 시안은 뒤를 검정 70% 로 덮고 카드 333×410 을 x=30, y=231 에 세운다. 옆 카드는
/// x=373 에서 20 걸쳐 보이고, `닫기` 40×40 이 x=328, y=183 에 선다.
void main() {
  useFigmaViewport();

  const steps = [
    ActionCard(
      id: 'c1',
      title: '옷을 골라요',
      description: '밖에 나갈 때 입을 옷을 꺼내요',
      stepOrder: 1,
    ),
    ActionCard(
      id: 'c2',
      title: '바지를 입어요',
      description: '양쪽 다리를 넣고 바지를 올려 입어요',
      stepOrder: 2,
    ),
    ActionCard(
      id: 'c3',
      title: '윗옷을 입어요',
      description: '머리와 팔을 넣어 윗옷을 입어요',
      stepOrder: 3,
    ),
  ];

  const routine = Routine(
    id: 'r1',
    title: '스스로 옷을 입어요',
    status: 'CONFIRMED',
    steps: steps,
    rewardText: '유튜브 시청 20분',
  );

  late _Speech speech;

  Future<void> pump(WidgetTester tester, {bool isPast = false}) async {
    speech = _Speech();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          offlineDioOverride(),
          testStorageOverride(onboardingCompleted: true),
          routineRepositoryProvider.overrideWithValue(_Repo()),
          speechServiceProvider.overrideWithValue(speech),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: RoutineDetailSheet(routine: routine, isPast: isPast),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// 시트의 단계 줄을 눌러 큰 카드를 연다
  Future<void> openStep(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  group('카드를 눌러 크게 본다 (#495)', () {
    testWidgets('단계 줄을 누르면 그 카드가 크게 뜬다', (tester) async {
      await pump(tester);

      await openStep(tester, '바지를 입어요');

      // 큰 카드는 카드확인과 같은 카드 위젯이다
      expect(find.byType(ActionCardView), findsWidgets);
      // 눌린 카드(둘째)가 가운데 서 있다
      final centered = tester
          .widgetList<ActionCardView>(find.byType(ActionCardView))
          .firstWhere((v) => v.card.id == 'c2');
      expect(centered.index, 1);
      // 카드에는 삭제 X 가 없다 — 읽기만 한다
      expect(centered.onDelete, isNull);
    });

    testWidgets('시안 자리에 선다 — 카드 333×410 @ (30, 231), 닫기 40×40 @ (328, 183)',
        (tester) async {
      await pump(tester);

      await openStep(tester, '옷을 골라요');

      final card = tester.getRect(
        find.byWidgetPredicate((w) => w is ActionCardView && w.card.id == 'c1'),
      );
      expect(card.left, closeTo(30, 0.6));
      expect(card.top, closeTo(231, 0.6));
      expect(card.width, closeTo(333, 0.6));
      expect(card.height, closeTo(410, 0.6));

      final close = tester.getRect(
        find
            .ancestor(
              of: svgWithAsset(AppAssets.iconClose),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(close.left, closeTo(328, 0.6));
      expect(close.top, closeTo(183, 0.6));
      expect(close.width, closeTo(40, 0.6));

      // 옆 카드가 20 걸쳐 보인다 (x=373)
      final next = tester.getRect(
        find.byWidgetPredicate((w) => w is ActionCardView && w.card.id == 'c2'),
      );
      expect(next.left, closeTo(373, 0.6));
    });

    testWidgets('옆으로 밀면 다음 카드가 가운데 온다', (tester) async {
      await pump(tester);
      await openStep(tester, '옷을 골라요');

      await tester.drag(
        find.byWidgetPredicate((w) => w is ActionCardView && w.card.id == 'c1'),
        const Offset(-343, 0),
      );
      await tester.pumpAndSettle();

      final c2 = tester.getRect(
        find.byWidgetPredicate((w) => w is ActionCardView && w.card.id == 'c2'),
      );
      expect(c2.left, closeTo(30, 1));
    });

    testWidgets('닫기를 누르면 시트로 돌아온다', (tester) async {
      await pump(tester);
      await openStep(tester, '바지를 입어요');
      expect(find.byType(ActionCardView), findsWidgets);

      await tester.tap(svgWithAsset(AppAssets.iconClose));
      await tester.pumpAndSettle();

      expect(find.byType(ActionCardView), findsNothing);
      expect(find.text('스스로 옷을 입어요'), findsOneWidget, reason: '시트는 그대로 있다');
    });

    testWidgets('보상 줄을 눌러도 카드는 열리지 않는다', (tester) async {
      await pump(tester);

      await tester.tap(find.text('유튜브 시청 20분'));
      await tester.pumpAndSettle();

      expect(find.byType(ActionCardView), findsNothing);
    });

    testWidgets('지난 일과에서도 같은 카드가 열린다', (tester) async {
      await pump(tester, isPast: true);

      await openStep(tester, '윗옷을 입어요');

      expect(find.byType(ActionCardView), findsWidgets);
    });

    testWidgets('스피커를 누르면 제목과 설명을 읽는다', (tester) async {
      await pump(tester);
      await openStep(tester, '옷을 골라요');

      final view = tester.widget<ActionCardView>(
        find.byWidgetPredicate((w) => w is ActionCardView && w.card.id == 'c1'),
      );
      view.onSpeak!();
      await tester.pump();

      expect(speech.spoken, ['옷을 골라요. 밖에 나갈 때 입을 옷을 꺼내요']);
    });
  });
}

class _Speech implements SpeechService {
  final spoken = <String>[];

  @override
  Future<bool> speak(String text, {String language = 'ko'}) async {
    spoken.add(text);
    return true;
  }

  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo with FakeRewardApi implements RoutineRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} 은 이 테스트에서 쓰지 않는다');
}
