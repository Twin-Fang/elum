
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/credit/data/credit_repository.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:elum/features/guardian/presentation/widgets/ai_credit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/credit_fixtures.dart';
import 'helpers/device_viewport.dart';

/// 보호자 설정의 AI 크레딧 카드 (#407 스펙 §5 · 이슈 표).
void main() {
  useFigmaViewport();

  Future<void> pump(
    WidgetTester tester,
    Future<CreditSummary> Function() load, {
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [creditSummaryProvider.overrideWith((ref) => load())],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: const Scaffold(
                  body: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: AiCreditCard(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  CreditSummary summary({
    int available = 72,
    int bonus = 0,
    List<Object?> inProgress = const [],
    int routineTextCost = 1,
    int cardImageCost = 1,
  }) => CreditSummary.fromJson(
    creditJson(
      available: available,
      bonus: bonus,
      inProgress: inProgress,
      routineTextCost: routineTextCost,
      cardImageCost: cardImageCost,
    ),
  );

  testWidgets('정상 — 남은 양·초기화 줄을 보여준다', (tester) async {
    await pump(tester, () async => summary());

    expect(find.text('이번 주 AI 생성'), findsOneWidget);
    // 큰 숫자와 단위는 따로 그린다 (Figma `1579:8115` 숫자 + `/ 100 크레딧 남음`)
    expect(find.text('72'), findsOneWidget);
    expect(find.text('/ 100 크레딧 남음'), findsOneWidget);
    expect(find.text('9월 28일(월) 0시에 다시 채워져요'), findsOneWidget);
    expect(find.byKey(AiCreditCard.barKey), findsOneWidget);
    // 구매·플랜 표시는 없다 (이슈).
    expect(find.textContaining('무료'), findsNothing);
    expect(find.textContaining('구매'), findsNothing);
  });

  testWidgets('0 — 다 썼다·초기화 시각·계속 할 수 있는 것을 알린다', (tester) async {
    await pump(tester, () async => summary(available: 0));

    expect(find.text('0'), findsOneWidget);
    expect(find.text('/ 100 크레딧 남음'), findsOneWidget);
    expect(find.text('이번 주 크레딧을 모두 사용했어요'), findsOneWidget);
    expect(find.text('9월 28일(월) 0시에 다시 채워져요'), findsOneWidget);
    expect(find.text('만든 일과 보기와 직접 고치기는 계속 할 수 있어요'), findsOneWidget);
    // 0 에서는 적음 줄을 겹쳐 띄우지 않는다
    expect(find.textContaining('0이 될 수 있어요'), findsNothing);
  });

  testWidgets('조회 실패 — 다시 하기와 코드를 띄우고 숫자를 그리지 않는다', (tester) async {
    var calls = 0;
    await pump(tester, () async {
      calls++;
      throw const AppFailure(fault: NetworkFault.app);
    });
    await tester.pump();

    expect(find.text('사용량을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 하기'), findsOneWidget);
    expect(find.text('E-CREDIT'), findsOneWidget);
    expect(find.textContaining('크레딧 남음', findRichText: true), findsNothing);

    await tester.tap(find.text('다시 하기'));
    await tester.pump();
    await tester.pump();
    expect(calls, 2, reason: '다시 하기는 새로 받는다');
  });

  testWidgets('서버 코드가 있으면 그 코드를 보인다', (tester) async {
    await pump(tester, () async {
      throw const AppFailure(fault: NetworkFault.offline);
    });
    await tester.pump();

    expect(find.text('E-NET-OFFLINE'), findsOneWidget);
    expect(find.text('인터넷 연결을 확인해주세요'), findsOneWidget);
  });
}
