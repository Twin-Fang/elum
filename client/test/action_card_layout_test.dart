import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/presentation/widgets/action_card_view.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 카드 레이아웃 회귀 방지.
///
/// 실기기에서 세 가지가 어긋났다.
/// 1. 카드마다 이미지 크기가 달랐다 (Expanded가 남는 공간을 다 먹었다)
/// 2. 텍스트 시작 높이가 달랐다 (이미지 높이가 달라 아래가 밀렸다)
/// 3. 긴 제목이 `…`으로 잘렸다 (`천천히 학교로 ...`)
void main() {
  // **뷰포트를 기기 크기로 고정한다.** 기본 800×600이면 `.w`가 2배로 잡혀
  // 40 짜리 배지가 81 로 측정된다 — 멀쩡한 코드를 결함으로 오판한다 (#335).
  useFigmaViewport();

  Widget wrap(
    ActionCard card, {
    ActionCardLayout layout = ActionCardLayout.review,
  }) {
    return ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 345,
              height: 431,
              child: ActionCardView(card: card, index: 0, layout: layout),
            ),
          ),
        ),
      ),
    );
  }

  ActionCard card(String title, String description) =>
      ActionCard(id: 'c1', title: title, description: description);

  testWidgets('내용이 길어도 오버플로가 나지 않는다', (tester) async {
    // 노란 줄무늬 경고가 뜨면 안 된다
    await tester.pumpWidget(
      wrap(
        card(
          '아주 아주 아주 긴 제목이 들어오는 경우를 대비한 문장입니다',
          '설명도 아주 길게 들어와서 여러 줄을 차지하는 상황을 가정한 문장입니다',
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  group('설명이 카드 밖으로 밀려 잘리지 않는다 (이슈 #335)', () {
    /// 카드 자리에 넣었을 때 **숨는 높이**. 0 이면 다 보인다.
    Future<double> hidden(
      WidgetTester tester, {
      required String description,
      required double height,
      required double width,
      ActionCardLayout layout = ActionCardLayout.review,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            useInheritedMediaQuery: true,
            builder: (context, _) => MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: ActionCardView(
                      card: card('옷을 갈아입어요', description),
                      index: 0,
                      layout: layout,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .maxScrollExtent;
    }

    // 실기기에서 AI 가 만든 문구들이다. 시험 고정 문구는 짧아 두 줄에
    // 들어맞아서, 골든으로는 이 결함이 잡히지 않았다.
    const real = [
      '학교에 입고 갈 옷으로 차례대로 갈아입어요.',
      '학교에 가져갈 가방을 손으로 챙겨요. 빠뜨린 것이 없는지 살펴요.',
    ];

    // #335 에서는 390 자리면 16.7 이 숨었다(되돌림 감시였다). #401 에서 카드확인
    // 그림칸이 시안대로 34 낮아지면서(313×230) 390 에서도 두 줄이 다 보인다.
    // 아래 간격 셋을 xs 로 줄인 것(#335)은 되돌릴 수 있게 됐다 — 이슈 #401 질문.
    testWidgets('그림칸이 시안대로 낮아져(#401) 390 자리에서도 두 줄이 다 보인다', (tester) async {
      expect(
        await hidden(tester, description: real.first, height: 390, width: 333),
        0,
      );
    });
  });

}
