import 'dart:async';

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
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                ),
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
  }) => CreditSummary.fromJson(
    creditJson(available: available, bonus: bonus, inProgress: inProgress),
  );

  testWidgets('불러오는 동안 숫자를 그리지 않는다 — 0 이 보이면 다 쓴 줄 안다', (tester) async {
    final never = Completer<CreditSummary>();
    await pump(tester, () => never.future);

    expect(find.byKey(AiCreditCard.loadingKey), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d')), findsNothing);
    expect(find.textContaining(RegExp(r'\d'), findRichText: true), findsNothing);
  });

  testWidgets('정상 — 남은 양·단가·초기화 줄을 보여준다', (tester) async {
    await pump(tester, () async => summary());

    expect(find.text('이번 주 AI 생성'), findsOneWidget);
    expect(find.text('72 / 100 크레딧 남음', findRichText: true), findsOneWidget);
    expect(find.text('일과 글 만들기 1크레딧 · 완성된 AI 그림 1장당 1크레딧'), findsOneWidget);
    expect(find.text('9월 28일(월) 0시에 다시 채워져요'), findsOneWidget);
    expect(find.byKey(AiCreditCard.barKey), findsOneWidget);
    // 구매·플랜 표시는 없다 (이슈).
    expect(find.textContaining('무료'), findsNothing);
    expect(find.textContaining('구매'), findsNothing);
  });

  testWidgets('막대는 남은 비율만큼 채운다', (tester) async {
    await pump(tester, () async => summary());

    final bar = tester.widget<FractionallySizedBox>(
      find.descendant(
        of: find.byKey(AiCreditCard.barKey),
        matching: find.byType(FractionallySizedBox),
      ),
    );
    expect(bar.widthFactor, closeTo(0.72, 1e-9));
  });

  testWidgets('보너스가 있으면 `+ 추가 N` 을 붙인다', (tester) async {
    await pump(tester, () async => summary(available: 90, bonus: 20));

    expect(find.text('+ 추가 20'), findsOneWidget);
  });

  testWidgets('보너스가 없으면 추가 줄이 없다', (tester) async {
    await pump(tester, () async => summary());

    expect(find.textContaining('추가'), findsNothing);
  });

  testWidgets('적음(<11) — 끝까지 만들어지지만 0 이 될 수 있다고 알린다', (tester) async {
    await pump(tester, () async => summary(available: 10));

    expect(
      find.text('그림이 여러 장 생성돼도 이번 일과는 끝까지 만들어지고 크레딧은 0이 될 수 있어요'),
      findsOneWidget,
    );
  });

  testWidgets('11 이상이면 적음 줄이 없다', (tester) async {
    await pump(tester, () async => summary(available: 11));

    expect(find.textContaining('0이 될 수 있어요'), findsNothing);
  });

  testWidgets('0 — 다 썼다·초기화 시각·계속 할 수 있는 것을 알린다', (tester) async {
    await pump(tester, () async => summary(available: 0));

    expect(find.text('0 / 100 크레딧 남음', findRichText: true), findsOneWidget);
    expect(find.text('이번 주 크레딧을 모두 사용했어요'), findsOneWidget);
    expect(find.text('9월 28일(월) 0시에 다시 채워져요'), findsOneWidget);
    expect(find.text('만든 일과 보기와 직접 고치기는 계속 할 수 있어요'), findsOneWidget);
    // 0 에서는 적음 줄을 겹쳐 띄우지 않는다
    expect(find.textContaining('0이 될 수 있어요'), findsNothing);
  });

  testWidgets('만드는 중이면 한 줄로 알린다', (tester) async {
    await pump(
      tester,
      () async => summary(inProgress: [
        {'jobId': 'j1', 'kind': 'ROUTINE_CREATE', 'startedAt': '2026-09-24T10:00:00'},
      ]),
    );

    expect(find.text('일과를 만들고 있어요'), findsOneWidget);
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

  testWidgets('꺼져 있으면 아무것도 그리지 않는다', (tester) async {
    await pump(tester, () async => const CreditSummary.disabled());

    expect(find.byType(Text), findsNothing);
    expect(tester.getSize(find.byType(AiCreditCard)).height, 0);
  });

  testWidgets('낭독기는 카드를 한 덩어리로 읽는다', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, () async => summary(available: 10, bonus: 5));

    final node = tester.getSemantics(find.byKey(AiCreditCard.contentKey));
    expect(node.label, contains('이번 주 AI 생성'));
    expect(node.label, contains('10 / 100 크레딧 남음'));
    expect(node.label, contains('추가 5'));
    expect(node.label, contains('9월 28일(월) 0시에 다시 채워져요'));
    expect(node.label, contains('0이 될 수 있어요'));
    handle.dispose();
  });

  for (final (name, available, bonus) in [
    ('정상', 72, 0),
    ('보너스', 90, 20),
    ('적음', 10, 0),
    ('0', 0, 0),
  ]) {
    testWidgets('글꼴 2.0 — $name 상태가 넘치지 않는다', (tester) async {
      await pump(
        tester,
        () async => summary(available: available, bonus: bonus),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('글꼴 2.0 — 실패 상태가 넘치지 않는다', (tester) async {
    await pump(tester, () async {
      throw const AppFailure(fault: NetworkFault.offline);
    }, textScale: 2);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
