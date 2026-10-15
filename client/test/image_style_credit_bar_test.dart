import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/credit/data/credit_repository.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:elum/features/onboarding/domain/image_style.dart';
import 'package:elum/features/onboarding/presentation/widgets/image_style_credit_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 그림 방식 목록 위 크레딧 띠 — 고른 방식이 크레딧을 얼마나 쓰는지 보인다.
///
/// 틀리면 보호자가 비용을 잘못 알고 방식을 고른다 (기본 그림을 공짜로 알거나, 그림 값이 빠지거나).
void main() {
  useFigmaViewport();

  Future<void> pump(
    WidgetTester tester,
    ImageStyle style, {
    Future<CreditSummary> Function()? summary,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creditSummaryProvider.overrideWith(
            (ref) => summary?.call() ?? Future.value(const CreditSummary(enabled: true)),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, _) => MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ImageStyleCreditBar(style: style),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // 띠는 한 덩어리로 읽힌다 — 낭독 라벨이 곧 보이는 내용이다
  String? barLabel(WidgetTester tester) => tester
      .getSemantics(find.byType(ImageStyleCreditBar))
      .getSemanticsData()
      .label;

  testWidgets('기본 그림은 일과 크레딧만, 만화·실사는 그림 한 장 크레딧이 더 붙는다', (tester) async {
    final handle = tester.ensureSemantics();

    await pump(tester, ImageStyle.photoOnly);
    expect(barLabel(tester), '크레딧, 일과 1개');

    for (final style in [ImageStyle.cartoon, ImageStyle.realistic]) {
      await pump(tester, style);
      expect(barLabel(tester), '크레딧, 일과 1개, 그림 한 장 1개');
    }
    handle.dispose();
  });

  testWidgets('숫자는 서버 단가를 따른다', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      ImageStyle.cartoon,
      summary: () async => const CreditSummary(
        enabled: true,
        routineTextCost: 2,
        cardImageCost: 3,
      ),
    );

    expect(barLabel(tester), '크레딧, 일과 2개, 그림 한 장 3개');
    handle.dispose();
  });

  testWidgets('크레딧 조회가 실패해도 기본 단가로 그린다', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      ImageStyle.cartoon,
      summary: () => Future.error(AppFailure.of(Exception('down'))),
    );

    expect(tester.takeException(), isNull);
    expect(barLabel(tester), '크레딧, 일과 1개, 그림 한 장 1개');
    handle.dispose();
  });

  testWidgets('크레딧 기능이 꺼져 있으면 띠를 감춘다', (tester) async {
    await pump(
      tester,
      ImageStyle.cartoon,
      summary: () async => const CreditSummary.disabled(),
    );

    expect(find.textContaining('크레딧'), findsNothing);
  });

  testWidgets('글자를 2배로 키워도 넘치지 않는다', (tester) async {
    await pump(tester, ImageStyle.realistic, textScale: 2);

    expect(tester.takeException(), isNull);
  });
}
