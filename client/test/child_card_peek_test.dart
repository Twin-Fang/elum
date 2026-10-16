import 'dart:typed_data';

import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/application/child_routine_notifier.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/guardian/data/card_image_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/test_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 행동카드 넘기기 화면에서 양옆 카드가 살짝 보인다 (이슈 #394).
///
/// 시안(`1197:6775`)은 가운데 카드와 오른쪽 옆 카드(x373)를 그린다. 옆으로 넘기면
/// 더 있다는 것을 글이 아니라 그림으로 알리려고 **양옆 카드를 가장자리에 걸친다** —
/// 사용자가 승인한 시안 이탈(#394)을 시안이 따라왔다. 가운데 카드의 크기·자리
/// (333×410 @ 30,231)는 시안 그대로다.
void main() {
  useFigmaViewport();

  const threeCards = [
    ActionCard(
      id: 'c1',
      title: '옷을 입어요',
      description: '학교에 갈 옷을 차례대로 입어요',
      stepOrder: 1,
    ),
    ActionCard(
      id: 'c2',
      title: '우산을 챙겨요',
      description: '현관에서 우산을 챙겨요',
      stepOrder: 2,
    ),
    ActionCard(
      id: 'c3',
      title: '신발을 신어요',
      description: '현관에서 신발을 신어요',
      stepOrder: 3,
    ),
  ];


  /// id를 `local`로 둔다 — 서버에 없는 일과라 동기화를 타지 않는다.
  Widget wrap({
    List<ActionCard> cards = threeCards,
    bool reduceMotion = false,
    double textScale = 1,
    _CountingSpeech? speech,
    Uint8List? imageBytes,
  }) => ProviderScope(
    overrides: [
      offlineDioOverride(),
      // 그림이 있는 카드를 만들 때만 — 없으면 이 일과(`local`)는 그림이 없는 기본 카드다
      if (imageBytes != null)
        cardImageProvider.overrideWith((ref, key) async => imageBytes),
      testStorageOverride(onboardingCompleted: true),
      speechServiceProvider.overrideWithValue(speech ?? _CountingSpeech()),
    ],
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      useInheritedMediaQuery: true,
      builder: (context, _) => MaterialApp.router(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // 시안 프레임은 상태바 59·홈 인디케이터 21 을 포함해 그린다
            padding: const EdgeInsets.only(top: 59, bottom: 21),
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        routerConfig: GoRouter(
          initialLocation: Routes.childRoutineDetail,
          routes: [
            GoRoute(
              path: Routes.childRoutineDetail,
              builder: (context, state) => ChildRoutineDetailScreen(
                routine: Routine(
                  id: imageBytes != null ? 'r1' : 'local',
                  title: '비 오는 날 학교에 가요',
                  status: 'CONFIRMED',
                  steps: cards,
                ),
              ),
            ),
            GoRoute(
              path: Routes.childReward,
              builder: (context, state) => const Scaffold(body: Text('보상 화면')),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<ActionCard> cards = threeCards,
    bool reduceMotion = false,
    double textScale = 1,
    _CountingSpeech? speech,
    Uint8List? imageBytes,
  }) async {
    await tester.pumpWidget(
      wrap(
        cards: cards,
        reduceMotion: reduceMotion,
        textScale: textScale,
        speech: speech,
        imageBytes: imageBytes,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  PageController controllerOf(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!;


  // 시안 `1197:6775` 카드 안 — 테두리(2, 안쪽)를 포함해 바깥에서 10 들어온 자리에
  // 그림칸 313×230, 그 아래 10 에 배지(40), 배지 오른쪽 8 에 제목, 배지 아래 18 에
  // 설명. 스피커(24)는 배지 칸 한가운데, 설명은 제목과 같은 x 에서 시작한다.


  group('누르기와 화면 낭독기', () {
    testWidgets('P4 옆 카드를 누르면 그 카드로 넘어간다', (tester) async {
      final speech = _CountingSpeech();
      await pumpScreen(tester, speech: speech);

      // 오른쪽 가장자리에 걸친 옆 카드
      await tester.tapAt(const Offset(385, 400));
      await tester.pumpAndSettle();

      expect(controllerOf(tester).page, closeTo(1, 0.001));
      // 옆 카드 안의 스피커가 대신 눌리지 않는다
      expect(speech.spoken, isEmpty);
    });

    testWidgets('P5 체크 버튼은 언제나 가운데 카드를 체크한다', (tester) async {
      await pumpScreen(tester);

      await tester.tapAt(const Offset(385, 400));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ChildRoutineDetailScreen.checkButtonKey));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChildRoutineDetailScreen)),
      );
      final progress = container.read(childRoutineProvider);
      expect(progress.isChecked('local', threeCards[1]), isTrue);
      expect(progress.isChecked('local', threeCards[0]), isFalse);
      expect(progress.isChecked('local', threeCards[2]), isFalse);

      // 보상 화면으로 넘어가는 대기 타이머를 흘려보낸다
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
    });

  });

  // P8 — 시안(`309:3648`)은 체크해도 카드 자체는 그대로고 아래 버튼만 바뀐다. 그래서
  // 옆에 걸친 16 띠에는 체크 여부가 드러나지 않았다. 옆 띠 안에 앱의 체크 표시(민트
  // 원 + 흰 체크)를 둔다. 가운데 카드는 시안대로 아래 버튼으로만 알린다.

}

/// 읽어 주기를 센다 — 옆 카드의 스피커가 잘못 눌렸는지 본다.
class _CountingSpeech implements SpeechService {
  final spoken = <String>[];

  @override
  Future<bool> speak(String text, {String language = 'ko', StoredSpeechSource? stored}) async {
    spoken.add(text);
    return true;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

