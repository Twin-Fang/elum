import 'package:dio/dio.dart';
import 'package:elum/core/app_status/app_status_repository.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/data/oauth_sdk.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/guardian/application/routine_manage_coach_notifier.dart';
import 'package:elum/features/guardian/presentation/guardian_settings_screen.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 보호자 설정 화면 (이슈 #181).
///
/// 로그아웃은 **되돌릴 수 없는 동작이 아니지만** 실수로 눌리면 다시 로그인해야 한다.
/// 회원탈퇴는 진짜로 되돌릴 수 없다. 둘 다 확인을 거치는지, 그리고 취소가 실제로
/// 아무 일도 하지 않는지를 고정한다 — 확인 창이 형식만 남고 무력해지는 일이 흔하다.
void main() {
  useFigmaViewport();

  late _FakeAuth auth;

  Widget wrap({
    String version = '1.24.1',
    Attempt<LinkStatus>? link,
  }) {
    final router = GoRouter(
      initialLocation: Routes.guardianSettings,
      routes: [
        GoRoute(
          path: Routes.guardianSettings,
          builder: (context, state) => const GuardianSettingsScreen(),
        ),
        GoRoute(
          path: Routes.guardianManage,
          builder: (context, state) => const Scaffold(body: Text('일과관리 화면')),
        ),
        GoRoute(
          path: Routes.login,
          builder: (context, state) => const Scaffold(body: Text('로그인 화면')),
        ),
        GoRoute(
          path: Routes.guardianPinChange,
          builder: (context, state) => const Scaffold(body: Text('비밀암호 변경 화면')),
        ),
        GoRoute(
          path: Routes.linkCode,
          builder: (context, state) => const Scaffold(body: Text('연결 암호 화면')),
        ),
        GoRoute(
          path: Routes.guardianLinkStatus,
          builder: (context, state) => const Scaffold(body: Text('연결 상태 화면')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        // 그림 방식 줄(#458)이 저장된 값을 읽는다
        testStorageOverride(),
        authRepositoryProvider.overrideWithValue(auth),
        // 약관 목록은 서버·캐시를 타므로 테스트에서는 앱 번들 기본값으로 고정한다.
        consentBundleProvider.overrideWith((ref) async => ConsentBundle.bundled),
        appVersionProvider.overrideWith((ref) async => version),
        // 이룸이 휴대폰 연결 상태 (#363). 서버를 타지 않는다
        linkStatusProvider.overrideWith(
          (ref) async => link ?? Attempt.ok(LinkStatus.empty),
        ),
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

  setUp(() => auth = _FakeAuth());

  // 이룸이 카드 진동 스위치 (#515) — 이룸이 설정과 같은 값 하나를 본다.

  // 이룸이 휴대폰 줄 (#363 · 명세 §8-4) — 연결 전에는 할 일(`연결하기`), 연결된 뒤에는 상태(`연결됨 ›`).
  group('이룸이 기기 줄', () {



    testWidgets('상태를 못 불러와도 설정은 멈추지 않는다 — `연결하기`로 둔다', (tester) async {
      await tester.pumpWidget(
        wrap(link: const Attempt.failed(AppFailure(fault: NetworkFault.offline))),
      );
      await tester.pumpAndSettle();

      expect(find.text('이룸이 기기 연결하기'), findsOneWidget);
      expect(find.text('로그아웃'), findsOneWidget);
    });

  });

  // 버전은 맨 아래 떨어진 글자가 아니라 목록의 한 줄이다 (#418).



  // 공통 뒤로가기(`ElumScaffold`)라 이 자리가 비면 앱 거의 모든 화면이 함께
  // 빈다. 실기기에서 설정의 화살표가 이름 없이 잡혔다 (#339).

  // 가입한 뒤에 약관을 다시 볼 곳이 없으면 Apple 심사에서 지적받는다(5.1.1(i)).
  // 줄이 사라져도 화면은 멀쩡히 뜨므로 눈으로는 알아채기 어렵다 (이슈 #289).

  // 문의하기는 **시안(`1022:4467`)과 일부러 다르게** 뺐다 (#312, 2026-09-23 결정).
  //
  // #312 에서 뺐다가 #349 에서 "시안에 다시 그려져 있다"며 되살렸고, App Store
  // 심사 기간이라 다시 뺐다. 애플이 요구하는 것은 스토어 페이지의 지원 주소이고
  // 앱 안 문의하기는 필수가 아니다. 시안 대조만 보고 또 되살리지 않도록 여기서
  // 막는다 — 되살릴 때는 이 테스트를 함께 바꾼다.

  testWidgets('비밀암호 변경하기 줄을 누르면 변경 화면이 열린다 (#437)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('비밀암호 변경하기'));
    await tester.pumpAndSettle();
    expect(find.text('비밀암호 변경 화면'), findsOneWidget);
  });




  testWidgets('일과관리 사용법 다시 보기 줄을 누르면 일과관리로 가서 안내를 다시 요청한다 (#832)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('일과관리 사용법 다시 보기'), 200);
    await tester.tap(find.text('일과관리 사용법 다시 보기'));
    await tester.pumpAndSettle();

    expect(find.text('일과관리 화면'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.text('일과관리 화면')),
    );
    expect(container.read(routineManageCoachProvider).isReplayRequested, isTrue);
  });

  testWidgets('로그아웃은 확인을 거친다 — 탭만으로는 나가지지 않는다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    expect(find.text('로그아웃 하실건가요?'), findsOneWidget);
    expect(auth.logoutCalls, 0, reason: '확인 전에는 아무 일도 일어나면 안 된다');
  });


  testWidgets('확인하면 로그아웃하고 로그인 화면으로 간다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('로그아웃'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    // 시안(`팝업` 1045:5194)의 확인 버튼 이름은 `확인`이다.
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(auth.logoutCalls, 1);
    expect(find.text('로그인 화면'), findsOneWidget);
  });

  testWidgets('회원 탈퇴는 되돌릴 수 없다고 알린 뒤 실행한다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('회원탈퇴'));
    await tester.ensureVisible(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('회원탈퇴'));
    await tester.pumpAndSettle();

    expect(find.textContaining('되돌릴 수 없어요'), findsOneWidget,
        reason: '로그아웃과 같은 문구면 사용자가 둘을 구분할 수 없다');
    expect(auth.deleteCalls, 0);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(auth.deleteCalls, 1);
    expect(find.text('로그인 화면'), findsOneWidget);
  });




  testWidgets('서버 삭제가 실패하면 탈퇴됐다고 하지 않는다 (이슈 #187)', (tester) async {
    auth.deleteSucceeds = false;

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('회원탈퇴'));
    await tester.ensureVisible(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
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

    await tester.ensureVisible(find.text('회원탈퇴'));
    await tester.ensureVisible(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    // 실패 팝업을 닫는다 — 스낵바가 아니라 팝업이라 닫아야 설정으로 돌아온다 (#433)
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // 실패 후에도 버튼이 잠겨 있으면 그 자리에서 할 수 있는 일이 없어진다.
    auth.deleteSucceeds = true;
    await tester.ensureVisible(find.text('회원탈퇴'));
    await tester.ensureVisible(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('회원탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(auth.deleteCalls, 2);
    expect(find.text('로그인 화면'), findsOneWidget);
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
  Future<AppFailure?> deleteAccount() async {
    deleteCalls++;
    return deleteSucceeds ? null : const AppFailure(fault: NetworkFault.app);
  }
}
