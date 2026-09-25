import 'dart:async';

import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
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

  testWidgets('불러오는 동안 숫자를 그리지 않는다 — 0 이 보이면 다 쓴 줄 안다', (tester) async {
    final never = Completer<CreditSummary>();
    await pump(tester, () => never.future);

    expect(find.byKey(AiCreditCard.loadingKey), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d')), findsNothing);
    expect(
      find.textContaining(RegExp(r'\d'), findRichText: true),
      findsNothing,
    );
  });

  testWidgets('정상 — 남은 양·초기화 줄을 보여준다', (tester) async {
    await pump(tester, () async => summary());

    expect(find.text('이번 주 AI 생성'), findsOneWidget);
    expect(find.text('72 / 100 크레딧 남음', findRichText: true), findsOneWidget);
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

  // 적어도 경고 문구를 덧붙이지 않는다 — 숫자와 막대로 충분하다
  // (2026-09-25 사용자 결정, #421).
  testWidgets('잔액이 적어도 경고 문구가 없다', (tester) async {
    await pump(tester, () async => summary(available: 3));

    expect(find.textContaining('끝까지 만들어지고'), findsNothing);
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
      () async => summary(
        inProgress: [
          {
            'jobId': 'j1',
            'kind': 'ROUTINE_CREATE',
            'startedAt': '2026-09-24T10:00:00',
          },
        ],
      ),
    );

    expect(find.text('일과를 만들고 있어요'), findsOneWidget);
  });

  testWidgets('단가 줄은 카드에 두지 않는다 — 안내 팝업으로 옮겼다', (tester) async {
    await pump(tester, () async => summary());

    expect(find.textContaining('크레딧 · '), findsNothing);
    expect(find.textContaining('1장당'), findsNothing);
    expect(find.textContaining('일과 글'), findsNothing);
  });

  testWidgets('안내 버튼 — 제목 줄 오른쪽 · 낭독기 이름 · 누름 영역 44 이상', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, () async => summary());

    final info = find.byKey(AiCreditCard.infoKey);
    expect(info, findsOneWidget);
    expect(find.bySemanticsLabel('AI 크레딧 안내'), findsOneWidget);

    final box = tester.getRect(info);
    expect(box.width, greaterThanOrEqualTo(44));
    expect(box.height, greaterThanOrEqualTo(44));

    // 제목 줄 오른쪽 — 제목보다 오른쪽이고, 세로로 제목 줄에 걸친다
    final title = tester.getRect(find.text('이번 주 AI 생성'));
    expect(box.left, greaterThan(title.right));
    expect(box.top, lessThanOrEqualTo(title.center.dy));
    expect(box.bottom, greaterThanOrEqualTo(title.center.dy));
    // 카드 안에 있다 — 밖으로 나가면 그 부분은 눌리지 않는다
    final card = tester.getRect(find.byType(AiCreditFrame));
    expect(box.right, lessThanOrEqualTo(card.right));
    expect(box.top, greaterThanOrEqualTo(card.top));
    handle.dispose();
  });

  testWidgets('안내 버튼을 누르면 서버 단가로 적은 팝업이 뜬다', (tester) async {
    await pump(
      tester,
      () async => summary(routineTextCost: 2, cardImageCost: 3),
    );

    await tester.tap(find.byKey(AiCreditCard.infoKey));
    await tester.pumpAndSettle();

    expect(find.byType(ElumDialogCard<void>), findsOneWidget);
    expect(find.text('AI 크레딧은 이렇게 줄어요'), findsOneWidget);
    final message = find.bySemanticsLabel(RegExp('일과 글을 만들 때'));
    expect(message, findsOneWidget);
    final label = tester.getSemantics(message).label;
    expect(label, contains('일과 글을 만들 때 2개, 그림이 완성된 카드 1장마다 3개씩 써요.'));
    expect(label, contains('크레딧이 남아 있을 때 시작한 일과는 그림이 많아도 끝까지 만들어져요.'));
    expect(label, contains('매주 월요일 0시에 다시 채워져요.'));

    // 낱말 가운데서 꺾이지 않게 보상 도움말과 같은 선택을 켠다 (#393 S4)
    final card = tester.widget<ElumDialogCard<void>>(
      find.byType(ElumDialogCard<void>),
    );
    expect(card.keepWordsInMessage, isTrue);
    expect(find.text('확인'), findsOneWidget);
  });

  testWidgets('안내 팝업은 확인이나 바깥을 눌러 닫는다', (tester) async {
    await pump(tester, () async => summary());

    await tester.tap(find.byKey(AiCreditCard.infoKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byType(ElumDialogCard<void>), findsNothing);

    await tester.tap(find.byKey(AiCreditCard.infoKey));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(ElumDialogCard<void>), findsNothing);
  });

  testWidgets('불러오는 동안에는 안내 버튼이 없다', (tester) async {
    final never = Completer<CreditSummary>();
    await pump(tester, () => never.future);

    expect(find.byKey(AiCreditCard.infoKey), findsNothing);
  });

  testWidgets('조회 실패면 안내 버튼이 없다', (tester) async {
    await pump(tester, () async {
      throw const AppFailure(fault: NetworkFault.offline);
    });
    await tester.pump();

    expect(find.byKey(AiCreditCard.infoKey), findsNothing);
  });

  testWidgets('글꼴 2.0 — 안내 팝업이 넘치지 않는다', (tester) async {
    await pump(tester, () async => summary(), textScale: 2);

    await tester.tap(find.byKey(AiCreditCard.infoKey));
    await tester.pumpAndSettle();
    expect(find.text('AI 크레딧은 이렇게 줄어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    // 적음 경고 문구는 없앴다 (#421) — 낭독기에도 읽히지 않는다.
    expect(node.label, isNot(contains('0이 될 수 있어요')));
    handle.dispose();
  });

  for (final (name, available, bonus, jobs) in [
    ('정상', 72, 0, const <Object?>[]),
    ('보너스', 90, 20, const <Object?>[]),
    ('적음', 10, 0, const <Object?>[]),
    ('0', 0, 0, const <Object?>[]),
    (
      '만드는 중',
      72,
      0,
      const <Object?>[
        {'jobId': 'j1', 'kind': 'ROUTINE_CREATE'},
      ],
    ),
  ]) {
    testWidgets('글꼴 2.0 — $name 상태가 넘치지 않는다', (tester) async {
      await pump(
        tester,
        () async =>
            summary(available: available, bonus: bonus, inProgress: jobs),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      // 큰 글꼴에서도 안내 버튼이 제목과 겹치지 않는다
      final title = tester.getRect(find.text('이번 주 AI 생성'));
      final info = tester.getRect(find.byKey(AiCreditCard.infoKey));
      expect(info.left, greaterThanOrEqualTo(title.right));
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
