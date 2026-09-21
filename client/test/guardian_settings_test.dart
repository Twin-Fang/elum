import 'package:dio/dio.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/data/oauth_sdk.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
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
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        // 약관 목록은 서버·캐시를 타므로 테스트에서는 앱 번들 기본값으로 고정한다.
        consentBundleProvider.overrideWith((ref) async => ConsentBundle.bundled),
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

  testWidgets('설정에는 로그아웃과 회원 탈퇴가 있다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('로그아웃'), findsOneWidget);
    expect(find.text('회원 탈퇴'), findsOneWidget);
  });

  // 가입한 뒤에 약관을 다시 볼 곳이 없으면 Apple 심사에서 지적받는다(5.1.1(i)).
  // 줄이 사라져도 화면은 멀쩡히 뜨므로 눈으로는 알아채기 어렵다 (이슈 #289).
  testWidgets('설정에서 약관과 문의로 들어갈 수 있다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('약관 및 개인정보처리방침'), findsOneWidget);
    // 문의하기는 뺐다 (#312). 스토어 페이지의 지원 주소가 그 몫을 한다.
    expect(find.text('문의하기'), findsNothing);
  });

  testWidgets('약관 줄을 누르면 문서 목록이 열린다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('약관 및 개인정보처리방침'));
    await tester.pumpAndSettle();

    // 동의 화면이 쓰는 묶음을 그대로 보여준다 — 여기만 따로 만들면 조용히 어긋난다.
    expect(find.text('개인정보 수집·이용'), findsOneWidget);
    expect(find.text('개인정보 국외 이전'), findsOneWidget);
  });

  testWidgets('문서를 고르면 전문이 열린다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('약관 및 개인정보처리방침'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('개인정보 수집·이용'));
    await tester.pumpAndSettle();

    expect(find.text('[필수] 개인정보 수집·이용'), findsOneWidget);
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

  testWidgets('회원 탈퇴는 되돌릴 수 없다고 알린 뒤 실행한다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();

    expect(find.textContaining('되돌릴 수 없어요'), findsOneWidget,
        reason: '로그아웃과 같은 문구면 사용자가 둘을 구분할 수 없다');
    expect(auth.deleteCalls, 0);

    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();

    expect(auth.deleteCalls, 1);
    expect(find.text('로그인 화면'), findsOneWidget);
  });

  testWidgets('되돌릴 수 없는 항목은 흐린 색이 아니라 위험 색이다 (이슈 #188)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final colors = AppColors.light;
    final withdraw = tester.widget<Text>(find.text('회원 탈퇴'));
    final logout = tester.widget<Text>(find.text('로그아웃'));

    expect(withdraw.style?.color, colors.danger,
        reason: '흐린 보조색을 쓰면 위험이 아니라 비활성으로 읽힌다');
    expect(withdraw.style?.color, isNot(colors.textSecondary));
    // 일반 항목까지 물들면 위험 표시가 의미를 잃는다.
    expect(logout.style?.color, colors.textPrimary);
  });

  testWidgets('확인 시트에서 취소가 비활성처럼 보이지 않는다 (이슈 #188)', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();

    final colors = AppColors.light;
    Color? fillBehind(String label) {
      final box = tester.widget<Container>(
        find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
      );
      return (box.decoration as BoxDecoration?)?.color;
    }

    // 취소가 비활성 색이면 "지금은 물러날 수 없다"로 읽혀 확인 쪽으로 몰린다.
    expect(fillBehind('취소'), colors.buttonNeutral);
    expect(fillBehind('취소'), isNot(colors.buttonDisabled));
    // 되돌릴 수 없는 쪽은 기본 버튼색이 아니라 위험색이어야 한다.
    expect(fillBehind('탈퇴하기'), colors.danger);
    expect(fillBehind('탈퇴하기'), isNot(colors.buttonEnabled));
  });

  testWidgets('되돌릴 수 있는 확인은 위험색을 쓰지 않는다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();

    final box = tester.widget<Container>(
      find.ancestor(of: find.text('로그아웃').last, matching: find.byType(Container)).first,
    );
    // 로그아웃까지 붉게 칠하면 진짜 위험한 것과 구분이 사라진다.
    expect((box.decoration as BoxDecoration?)?.color, AppColors.light.buttonEnabled);
  });

  testWidgets('서버 삭제가 실패하면 탈퇴됐다고 하지 않는다 (이슈 #187)', (tester) async {
    auth.deleteSucceeds = false;

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('회원 탈퇴'));
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

    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();

    // 실패 후에도 버튼이 잠겨 있으면 그 자리에서 할 수 있는 일이 없어진다.
    auth.deleteSucceeds = true;
    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탈퇴하기'));
    await tester.pumpAndSettle();

    expect(auth.deleteCalls, 2);
    expect(find.text('로그인 화면'), findsOneWidget);
  });

  testWidgets('회원 탈퇴 확인 창에서 취소하면 계정이 남는다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('회원 탈퇴'));
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
