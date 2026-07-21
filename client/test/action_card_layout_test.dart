import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/presentation/widgets/action_card_view.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// 카드 레이아웃 회귀 방지.
///
/// 실기기에서 세 가지가 어긋났다.
/// 1. 카드마다 이미지 크기가 달랐다 (Expanded가 남는 공간을 다 먹었다)
/// 2. 텍스트 시작 높이가 달랐다 (이미지 높이가 달라 아래가 밀렸다)
/// 3. 긴 제목이 `…`으로 잘렸다 (`천천히 학교로 ...`)
void main() {
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

  testWidgets('이미지는 항상 4:3 비율이다', (tester) async {
    // 카드마다 비율이 다르면 넘길 때 그림이 들쭉날쭉해 보인다.
    // 서버 Gemini 생성 비율(4:3, 2026-07-22 변경)과 통일한다.
    await tester.pumpWidget(wrap(card('옷을 입어요', '학교에 갈 옷을 입어요')));
    await tester.pump();

    final size = tester.getSize(find.byType(AspectRatio));
    expect(size.width / size.height, closeTo(4 / 3, 0.01));
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
}
