import 'package:dio/dio.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/auth/data/oauth_sdk.dart';
import 'package:elum/features/guardian/presentation/guardian_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';

/// 보호자 설정 화면 (이슈 #181).
///
/// 로그아웃은 **되돌릴 수 없는 동작이 아니지만** 실수로 눌리면 다시 로그인해야 한다.
/// 회원탈퇴는 진짜로 되돌릴 수 없다. 둘 다 확인을 거치는지, 그리고 취소가 실제로
/// 아무 일도 하지 않는지를 고정한다 — 확인 창이 형식만 남고 무력해지는 일이 흔하다.
void main() {
  useFigmaViewport();

  late _FakeAuth auth;

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.guardianSettings,
      routes: [
        GoRoute(
          path: Routes.guardianSettings,
          builder: (context, state) => const GuardianSettingsScreen(),
        ),
        GoRoute(
          path: Routes.login,
          builder: (context, state) => const Scaffold(body: Text('로그인 화면')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  setUp(() => auth = _FakeAuth());

  testWidgets('설정에는 로그아웃과 회원탈퇴가 있다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('로그아웃'), findsOneWidget);
    expect(find.text('회원탈퇴'), findsOneWidget);
  });

  testWidgets('로그아웃은 확인을 거친다 — 탭만으로는 나가지지 않는다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    expect(find.text('로그아웃할까요?'), findsOneWidget);
    expect(auth.logoutCalls, 0, reason: '확인 전에는 아무 일도 일어나면 안 된다');
  });

  testWidgets('확인 창에서 취소하면 로그아웃되지 않는다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 0);
    expect(find.text('설정'), findsOneWidget, reason: '설정 화면에 그대로 남아야 한다');
  });

  testWidgets('확인하면 로그아웃하고 로그인 화면으로 간다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    // 시트의 확인 버튼. 목록의 '로그아웃'과 글자가 같으므로 마지막 것을 집는다.
    await tester.tap(find.text('로그아웃').last);
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
    expect(find.text('로그인 화면'), findsOneWidget);
  });

  testWidgets('회원탈퇴는 되돌릴 수 없다고 알린 뒤 실행한다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('회원탈퇴'));
    await tester.pumpAndSettle();

    expect(find.textContaining('되돌릴 수 없어요'), findsOneWidget,
        reason: '로그아웃과 같은 문구면 사용자가 둘을 구분할 수 없다');
    expect(auth.deleteCalls, 0);

    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();

    expect(auth.deleteCalls, 1);
    expect(find.text('로그인 화면'), findsOneWidget);
  });

  testWidgets('서버 삭제가 실패하면 탈퇴됐다고 하지 않는다 (이슈 #187)', (tester) async {
    auth.deleteSucceeds = false;

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();

    // 아무것도 지워지지 않았으므로 화면을 옮기지 않는다. 옮기면 사용자는
    // 탈퇴가 끝난 것과 구분할 수 없다.
    expect(find.text('로그인 화면'), findsNothing);
    expect(find.text('설정'), findsOneWidget);
    // 무엇이 잘못됐는지 코드까지 보여야 제보를 추적할 수 있다.
    expect(find.textContaining('E-DEL'), findsOneWidget);
  });

  testWidgets('삭제에 실패해도 다시 시도할 수 있다', (tester) async {
    auth.deleteSucceeds = false;

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();

    // 실패 후에도 버튼이 잠겨 있으면 그 자리에서 할 수 있는 일이 없어진다.
    auth.deleteSucceeds = true;
    await tester.tap(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();

    expect(auth.deleteCalls, 2);
    expect(find.text('로그인 화면'), findsOneWidget);
  });

  testWidgets('회원탈퇴 확인 창에서 취소하면 계정이 남는다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(auth.deleteCalls, 0);
    expect(find.text('설정'), findsOneWidget);
  });
}

/// 서버에 나가지 않는 대역. 호출 횟수만 센다.
class _FakeAuth extends AuthRepository {
  _FakeAuth()
      : super(
          dio: Dio(),
          storage: InMemoryStorage(),
          tokens: InMemoryTokenStore(),
          sdk: OAuthSdk(),
        );

  int logoutCalls = 0;
  int deleteCalls = 0;

  /// 서버 삭제가 실패하는 상황을 만들 때 false로 둔다 (이슈 #187).
  bool deleteSucceeds = true;

  @override
  Future<void> logout() async => logoutCalls++;

  @override
  Future<bool> deleteAccount() async {
    deleteCalls++;
    return deleteSucceeds;
  }
}
