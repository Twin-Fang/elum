import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/presentation/widgets/action_card_view.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/semantics_audit.dart';

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

  Widget wrap(ActionCard card) {
    return ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 345,
              height: 431,
              child: ActionCardView(card: card, index: 0),
            ),
          ),
        ),
      ),
    );
  }

  ActionCard card(String title, String description) => ActionCard(
        id: 'c1',
        title: title,
        description: description,
      );

  testWidgets('이미지 칸은 항상 313:264 비율이다', (tester) async {
    // 카드마다 비율이 다르면 넘길 때 그림이 들쭉날쭉해 보인다.
    // 시안(`309:3548`)이 그린 칸이 313×264다 — 4:3으로 두면 칸이 32 낮아지고
    // 카드 전체가 시안보다 46 짧아진다 (#297). 그림은 `contain`이라 안 잘린다.
    await tester.pumpWidget(wrap(card('옷을 입어요', '학교에 갈 옷을 입어요')));
    await tester.pump();

    final size = tester.getSize(find.byType(AspectRatio));
    expect(size.width / size.height, closeTo(313 / 264, 0.01));
  });

  testWidgets('제목이 길어도 이미지 크기가 같다', (tester) async {
    // 제목 길이가 이미지를 밀어내면 안 된다
    await tester.pumpWidget(wrap(card('옷', '짧은 설명')));
    await tester.pump();
    final short = tester.getSize(find.byType(AspectRatio));

    await tester.pumpWidget(
      wrap(card('천천히 학교로 가요 아주 긴 제목입니다', '비 오는 길에서는 천천히 걸어요')),
    );
    await tester.pump();
    final long = tester.getSize(find.byType(AspectRatio));

    expect(long.height, closeTo(short.height, 0.5));
  });

  testWidgets('긴 제목을 …로 자르지 않는다', (tester) async {
    // `천천히 학교로 ...`처럼 잘리면 무엇을 해야 하는지 알 수 없다
    const title = '천천히 학교로 가요';
    await tester.pumpWidget(wrap(card(title, '비 오는 길에서는 천천히 걸어요')));
    await tester.pump();

    final text = tester.widget<Text>(find.text(title));
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(text.maxLines, isNull);
  });

  testWidgets('설명도 자르지 않는다', (tester) async {
    const description = '비 오는 길에서는 천천히 걸어요 그리고 조심해요';
    await tester.pumpWidget(wrap(card('천천히 가요', description)));
    await tester.pump();

    final text = tester.widget<Text>(find.text(description));
    expect(text.overflow, isNot(TextOverflow.ellipsis));
  });

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

  testWidgets('제목이 비면 설명을 대신 쓴다', (tester) async {
    // 서버가 title을 주지 않는다
    await tester.pumpWidget(
      wrap(const ActionCard(id: 'c1', description: '설명만 있는 카드')),
    );
    await tester.pump();

    expect(find.text('설명만 있는 카드'), findsWidgets);
  });

  group('설명이 카드 밖으로 밀려 잘리지 않는다 (이슈 #335)', () {
    /// 카드 자리에 넣었을 때 **숨는 높이**. 0 이면 다 보인다.
    Future<double> hidden(
      WidgetTester tester, {
      required String description,
      required double height,
      required double width,
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

    testWidgets('이룸이 카드 상세 (431) — 두 줄은 다 보인다', (tester) async {
      expect(
        await hidden(tester, description: real.first, height: 431, width: 345.8),
        0,
      );
    });

    testWidgets('세 줄은 시안 자리에서도 넘친다 — 알고 남겨 둔 한계', (tester) async {
      // 시안(`309:3548`)은 설명을 두 줄로 그렸다. 세 줄짜리 문구가 오면
      // **어느 화면에서도** 카드 안에 다 안 들어간다. 카드 자리를 늘리거나
      // 문구 길이를 제한해야 하는 문제라 여기서 고치지 않는다 (#335).
      expect(
        await hidden(tester, description: real.last, height: 431, width: 345.8),
        greaterThan(0),
      );
    });

    testWidgets('카드확인 — 아래 간격을 줄여 얻은 414 자리에 두 줄이 들어간다', (tester) async {
      // 보상 줄(#239)이 붙으면서 카드가 390으로 짧아져 16.7 이 숨었다.
      // 아래 간격 셋을 md(16) → xs(8) 로 줄여 24 를 카드에 돌려줬다.
      expect(
        await hidden(tester, description: real.first, height: 414, width: 332),
        0,
        reason: '두 줄 설명은 카드 안에 다 들어가야 한다',
      );
    });

    testWidgets('고치기 전 자리(390)였다면 잘린다 — 되돌림 감시', (tester) async {
      expect(
        await hidden(tester, description: real.first, height: 390, width: 332),
        greaterThan(0),
        reason: '이 값이 0 이 되면 자리가 넉넉해진 것이니 간격을 되돌려도 된다',
      );
    });
  });

  group('누를 수 있는 것에 읽을 이름이 있다 (#339)', () {
    Widget withActions({bool isSpeaking = false}) => ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 345,
              height: 431,
              child: ActionCardView(
                card: card('옷을 입어요', '학교에 갈 옷을 입어요'),
                index: 0,
                onSpeak: () {},
                onDelete: () {},
                isSpeaking: isSpeaking,
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('스피커와 X가 무엇을 하는지 읽힌다', (tester) async {
      await tester.pumpWidget(withActions());
      await tester.pump();

      expectLabeledButton(tester, '소리로 듣기');
      expectLabeledButton(tester, '이 카드 지우기');
      expect(unnamedTapTargets(tester), isEmpty);
    });

    testWidgets('읽는 중에는 스피커가 멈추기라고 읽힌다', (tester) async {
      // 읽는 중에 다시 누르면 멈춘다. 흐려지는 것만으로는 화면 낭독기에 안 닿는다.
      await tester.pumpWidget(withActions(isSpeaking: true));
      await tester.pump();

      expectLabeledButton(tester, '읽기 멈추기');
      expect(find.bySemanticsLabel('소리로 듣기'), findsNothing);
    });
  });
}
