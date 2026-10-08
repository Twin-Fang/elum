import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/profile/domain/profile_summary.dart';
import 'package:elum/features/profile/presentation/profile_switch_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/profile_fixtures.dart';
import 'helpers/semantics_audit.dart';
import 'package:elum/features/member/application/member_providers.dart';

/// 이룸이 바꾸기 (#362 · E44). 복지사처럼 이룸이를 여럿 돌보는 보호자가 쓴다.
void main() {
  useFigmaViewport();

  late InMemoryStorage storage;
  Object memberResult = memberWith([kProfileA, kProfileB]);

  setUp(() {
    storage = InMemoryStorage(onboardingCompleted: true);
    memberResult = memberWith([kProfileA, kProfileB]);
  });

  Widget wrap() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('설정'))),
        GoRoute(path: Routes.guardianProfileSwitch, builder: (_, _) => const ProfileSwitchScreen()),
      ],
    );
    return ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        memberProvider.overrideWith((ref) async {
          final r = memberResult;
          if (r is Member) return r;
          throw r;
        }),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('설정'))).push(Routes.guardianProfileSwitch);
    await tester.pumpAndSettle();
  }

  testWidgets('연결된 이룸이를 모두 보여 주고 지금 보는 이룸이를 표시한다', (tester) async {
    await open(tester);

    expect(find.text('하늘이'), findsOneWidget);
    expect(find.text('바다'), findsOneWidget);
    // 고른 적이 없으면 첫 이룸이가 지금 보는 이룸이다
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(
      find.descendant(of: find.ancestor(of: find.text('하늘이'), matching: find.byType(Row)).first, matching: find.byIcon(Icons.check_rounded)),
      findsOneWidget,
    );
  });

  testWidgets('이름이 아직 없는 이룸이는 이룸이라고 부른다', (tester) async {
    memberResult = memberWith([kProfileA, const ProfileSummary(id: 'p-c')]);
    await open(tester);

    expect(find.text('이룸이'), findsOneWidget);
  });

  testWidgets('다른 이룸이를 고르면 이룸이를 바꾸고 이름·캐릭터를 맞추고 돌아간다 (E44)', (tester) async {
    await open(tester);

    await tester.tap(find.text('바다'));
    await tester.pumpAndSettle();

    expect(storage.selectedProfileId, 'p-b');
    expect(storage.nickname, '바다');
    expect(storage.character, 'POPO');
    // 설정으로 돌아왔다
    expect(find.text('설정'), findsOneWidget);
    expect(find.text('이룸이를 바꿨어요'), findsOneWidget);
  });

  testWidgets('지금 보는 이룸이를 다시 고르면 아무것도 바꾸지 않고 돌아간다', (tester) async {
    await open(tester);

    await tester.tap(find.text('하늘이'));
    await tester.pumpAndSettle();

    expect(storage.selectedProfileId, anyOf(isNull, 'p-a'));
    expect(find.text('이룸이를 바꿨어요'), findsNothing);
    expect(find.text('설정'), findsOneWidget);
  });

  testWidgets('이룸이 목록을 못 받으면 에러 코드와 다시 시도를 보인다', (tester) async {
    memberResult = const AppFailure(fault: NetworkFault.offline);
    await open(tester);

    expect(find.textContaining('E-NET-OFFLINE'), findsOneWidget);
    expect(find.textContaining('다시 시도'), findsOneWidget);
  });

  testWidgets('회원 정보를 못 받으면(null) 목록 없이 코드와 다시 시도를 보인다 — 빈 화면이 아니다', (tester) async {
    memberResult = const Member();
    await open(tester);

    // 서버가 이룸이 목록을 주지 않았다 (옛 서버·조회 실패)
    expect(find.textContaining('E-PRO-LOAD'), findsOneWidget);
    expect(find.textContaining('다시 시도'), findsOneWidget);
  });

  testWidgets('이름 없는 누름 자리가 없고 줄이 이룸이 이름으로 읽힌다', (tester) async {
    await open(tester);

    expect(unnamedTapTargets(tester), isEmpty);
  });
}
