import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/credit/data/credit_repository.dart';
import 'package:elum/features/credit/domain/credit_history.dart';
import 'package:elum/features/credit/presentation/credit_history_screen.dart';
import 'package:elum/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 크레딧 사용 내역 (#658): 서버 응답 읽기, 날짜 묶음, 화면 네 상태, 다음 쪽 실패.
void main() {
  useFigmaViewport();

  Map<String, Object?> entryJson(
    String id, {
    String kind = 'ROUTINE_TEXT',
    int delta = -1,
    String at = '2026-10-01T11:22:00+09:00',
    String? title = '스스로 옷을 입어요',
    int? cardCount,
  }) => {
    'id': id,
    'kind': kind,
    'routineTitle': title,
    'cardCount': cardCount,
    'delta': delta,
    'occurredAt': '2026-10-01T11:22:00',
    'occurredAtOffset': at,
  };

  Map<String, Object?> pageJson(
    List<Map<String, Object?>> entries, {
    bool hasNext = false,
    int page = 0,
  }) => {'entries': entries, 'hasNext': hasNext, 'page': page};

  group('응답 읽기', () {
    test('틀린 줄은 건너뛰고 나머지는 읽는다', () {
      final page = CreditHistoryPage.fromJson(
        pageJson([
          entryJson('a'),
          {'id': 'broken', 'delta': 'x'},
          entryJson('b', delta: 100, kind: 'WEEKLY_GRANT', title: null),
        ]),
      );

      expect(page.entries.map((e) => e.id), ['a', 'b']);
    });

    test('모르는 종류는 null 로 읽는다 — 서버가 새 종류를 먼저 내려도 앱이 죽지 않는다', () {
      final page = CreditHistoryPage.fromJson(
        pageJson([entryJson('a', kind: 'SOMETHING_NEW')]),
      );

      expect(page.entries.single.kind, isNull);
    });

    test('겉 모양이 틀리면 빈 목록이 아니라 실패다', () {
      expect(
        () => CreditHistoryPage.fromJson({'entries': 'no', 'hasNext': false}),
        throwsFormatException,
      );
    });
  });

  test('날짜별로 묶되 줄 순서는 그대로 둔다', () {
    final entries = [
      CreditHistoryEntry.tryParse(entryJson('a', at: '2026-10-01T11:23:00')),
      CreditHistoryEntry.tryParse(entryJson('b', at: '2026-10-01T09:00:00')),
      CreditHistoryEntry.tryParse(entryJson('c', at: '2026-09-27T23:00:00')),
    ].nonNulls.toList();

    final days = groupCreditHistoryByDay(entries);

    expect(days.map((d) => d.entries.map((e) => e.id).toList()), [
      ['a', 'b'],
      ['c'],
    ]);
  });

  group('화면', () {
    Future<void> pump(
      WidgetTester tester,
      CreditRepository repository,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [creditRepositoryProvider.overrideWithValue(repository)],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) => MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('ko'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const CreditHistoryScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('내역을 날짜 카드로 보여주고 사용은 제목·종류·시각·증감을 한 줄에 둔다', (tester) async {
      await pump(
        tester,
        _FakeCreditRepository([
          pageJson([
            entryJson('a', kind: 'CARD_IMAGES', delta: -4, cardCount: 4),
            entryJson('b', delta: 100, kind: 'WEEKLY_GRANT', title: null),
          ]),
        ]),
      );

      expect(find.text('크레딧 사용 내역'), findsOneWidget);
      expect(find.text('10월 1일'), findsOneWidget);
      expect(find.text('스스로 옷을 입어요'), findsOneWidget);
      expect(find.textContaining('카드 그림 4장'), findsOneWidget);
      expect(find.text('-4'), findsOneWidget);
      expect(find.text('이번 주 크레딧을 채워드렸어요'), findsOneWidget);
      expect(find.text('+100'), findsOneWidget);
    });

    testWidgets('0건은 로딩·실패와 다른 빈 화면이다', (tester) async {
      await pump(tester, _FakeCreditRepository([pageJson([])]));

      expect(find.byKey(CreditHistoryScreen.emptyKey), findsOneWidget);
      expect(find.text('아직 사용한 크레딧이 없어요'), findsOneWidget);
      expect(find.textContaining('E-CREDIT'), findsNothing);
    });

    testWidgets('조회 실패는 "쓴 적 없다"가 아니라 다시 하기와 에러 코드를 보인다', (tester) async {
      final repository = _FakeCreditRepository([], failFirst: true);
      await pump(tester, repository);

      expect(find.byKey(CreditHistoryScreen.emptyKey), findsNothing);
      expect(find.text('사용 내역을 불러오지 못했어요'), findsOneWidget);
      expect(find.textContaining('E-'), findsWidgets);

      // 다시 하기 > 두 번째 호출은 성공
      repository.failFirst = false;
      repository.pages.add(pageJson([entryJson('a')]));
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      await tester.pump();
      expect(find.text('스스로 옷을 입어요'), findsOneWidget);
    });

    testWidgets('끝에 닿으면 다음 쪽을 이어 붙이고 겹친 줄은 한 번만 보인다', (tester) async {
      final repository = _FakeCreditRepository([
        pageJson(
          [for (var i = 0; i < 12; i++) entryJson('p0-$i', title: '일과 $i')],
          hasNext: true,
        ),
        pageJson(
          [entryJson('p0-11', title: '일과 11'), entryJson('p1-0', title: '다음 쪽 일과')],
          page: 1,
        ),
      ]);
      await pump(tester, repository);

      await tester.drag(
        find.byKey(CreditHistoryScreen.listKey),
        const Offset(0, -3000),
      );
      await tester.pump();
      await tester.pump();

      expect(repository.requestedPages, [0, 1]);
      expect(find.text('일과 11'), findsOneWidget);
    });

    testWidgets('다음 쪽 실패는 받아 둔 내역을 지우지 않고 다시 하기를 둔다', (tester) async {
      final repository = _FakeCreditRepository(
        [
          pageJson(
            [for (var i = 0; i < 12; i++) entryJson('p0-$i', title: '일과 $i')],
            hasNext: true,
          ),
        ],
        failOnPage: 1,
      );
      await pump(tester, repository);

      await tester.drag(
        find.byKey(CreditHistoryScreen.listKey),
        const Offset(0, -3000),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(CreditHistoryScreen.moreFailedKey), findsOneWidget);
      expect(find.text('일과 11'), findsOneWidget);
    });
  });
}

/// 쪽 번호 순서대로 응답을 준다. [failFirst] 면 첫 호출이 실패하고 [failOnPage] 쪽은 늘 실패한다.
class _FakeCreditRepository extends CreditRepository {
  _FakeCreditRepository(this.pages, {this.failFirst = false, this.failOnPage})
    : super(Dio());

  final List<Map<String, Object?>> pages;
  bool failFirst;
  final int? failOnPage;
  final requestedPages = <int>[];

  @override
  Future<CreditHistoryPage> getHistory({required int page, int size = 30}) async {
    requestedPages.add(page);
    if (failFirst && requestedPages.length == 1) {
      throw const AppFailure(fault: NetworkFault.offline);
    }
    if (page == failOnPage) throw const AppFailure(fault: NetworkFault.offline);
    return CreditHistoryPage.fromJson(pages[page]);
  }
}
