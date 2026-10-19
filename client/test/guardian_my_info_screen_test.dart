import 'dart:async';

import 'package:elum/core/router/routes.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/credit/data/credit_repository.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:elum/features/guardian/presentation/guardian_my_info_screen.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/profile/domain/profile_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

/// 보호자 내정보 칸 첫 화면 (#817).
///
/// 깨지면: 설정 아이콘이 설정으로 안 가거나, 이룸이가 여럿인데 목록이 한 명만 나오거나,
/// 회원 정보를 못 받았을 때 "연결된 이룸이가 없다"고 잘못 말한다.
void main() {
  useFigmaViewport();

  const lulu = ProfileSummary(id: '1', nickname: '하늘이', character: 'LULU');
  const popo = ProfileSummary(id: '2', nickname: '바다', character: 'POPO');

  Future<GoRouter> pump(WidgetTester tester, Member? member) async {
    final router = GoRouter(
      initialLocation: Routes.guardianMyInfo,
      routes: [
        GoRoute(
          path: Routes.guardianMyInfo,
          builder: (_, _) => const GuardianMyInfoScreen(),
        ),
        for (final path in [
          Routes.guardianSettings,
          Routes.guardianPeople,
          Routes.guardianDrafts,
          Routes.guardianProfileSwitch,
        ])
          GoRoute(path: path, builder: (_, _) => Scaffold(body: Text(path))),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          memberProvider.overrideWith((ref) async => member),
          // 크레딧 카드는 이 테스트의 관심사가 아니다 (불러오는 중으로 둔다)
          creditSummaryProvider.overrideWith(
            (ref) => Completer<CreditSummary>().future,
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) =>
              MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String topOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  testWidgets('이룸이 1명 — 프로필 카드와 이룸이 한 줄, 설정 목록은 없다', (tester) async {
    await pump(tester, const Member(profiles: [lulu]));

    expect(find.text('내 정보'), findsOneWidget);
    expect(find.text('보호자'), findsOneWidget);
    expect(find.text('이룸이 1명과 함께해요'), findsOneWidget);
    expect(find.text('하늘이'), findsOneWidget);
    expect(find.text('보는 중'), findsNothing, reason: '한 명이면 고를 것이 없다');
    expect(find.text('로그아웃'), findsNothing);
  });

  testWidgets('이룸이 여러 명 — 모두 나오고 줄을 누르면 이룸이 바꾸기로 간다', (tester) async {
    final router = await pump(tester, const Member(profiles: [lulu, popo]));

    expect(find.text('이룸이 2명과 함께해요'), findsOneWidget);
    expect(find.text('하늘이'), findsOneWidget);
    expect(find.text('바다'), findsOneWidget);
    expect(find.text('보는 중'), findsOneWidget);

    await tester.tap(find.text('바다'));
    await tester.pumpAndSettle();
    expect(topOf(router), Routes.guardianProfileSwitch);
  });

  testWidgets('이룸이 0명 — 안내 문구를 보여주고 이룸이 목록은 없다', (tester) async {
    await pump(tester, const Member(profiles: [], profilesKnown: true));

    expect(find.text('연결된 이룸이가 아직 없어요'), findsOneWidget);
    expect(find.text('이룸이'), findsNothing);
  });

  testWidgets('회원 정보를 못 받으면 이룸이 영역만 빠지고 화면은 그대로 뜬다', (tester) async {
    await pump(tester, null);

    expect(find.text('보호자'), findsOneWidget);
    expect(find.textContaining('이룸이'), findsNothing);
    expect(find.text('함께하는 사람'), findsOneWidget);
  });

  testWidgets('설정 아이콘과 바로가기 줄은 각자의 화면으로 간다', (tester) async {
    final router = await pump(tester, const Member(profiles: [lulu]));

    final targets = {
      '함께하는 사람': Routes.guardianPeople,
      '임시저장': Routes.guardianDrafts,
    };
    for (final entry in targets.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(topOf(router), entry.value, reason: entry.key);
      router.pop();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.bySemanticsLabel('설정'));
    await tester.pumpAndSettle();
    expect(topOf(router), Routes.guardianSettings);
  });
}
