import 'package:dio/dio.dart';
import 'package:elum/core/app_status/app_status_repository.dart';
import 'package:elum/features/auth/data/oauth_sdk.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/auth/presentation/login_screen.dart';
import 'package:elum/features/profile/application/profile_session.dart';
import 'package:elum/features/credit/data/credit_repository.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/guardian/presentation/guardian_settings_screen.dart';
import 'package:elum/features/onboarding/presentation/name_screen.dart';
import 'package:elum/features/profile/domain/profile_summary.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/credit_fixtures.dart';
import 'helpers/device_viewport.dart';
import 'helpers/profile_fixtures.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/core/router/routes.dart';
import 'package:elum/core/router/route_redirect.dart';

/// 다중 보호자 화면으로 들어가는 길 (#362).
///
/// 화면 하나하나는 각자의 테스트가 있다. 여기서는 **길이 이어지는지**를 본다 — 설정의 줄,
/// 새 가입자가 온보딩 대신 들어오는 링크, 이룸이가 없어졌을 때 홈이 보내는 곳, 이룸이 휴대폰에서
/// 이 기능이 열리지 않는 것.
void main() {
  useFigmaViewport();

  group('라우터 가드 — 이룸이 휴대폰에서는 이 기능이 보이지도 열리지도 않는다', () {
    String? guard(String path, {bool elumi = false, bool onboarded = true}) =>
        resolveRedirect(
          path,
          hasSession: true,
          onboardingCompleted: onboarded,
          skipOnboarding: false,
          isElumiDevice: elumi,
        );

    test('이룸이 휴대폰은 함께하는 사람·초대·이룸이 바꾸기·초대 코드 넣기를 열 수 없다', () {
      for (final path in [
        Routes.guardianPeople,
        Routes.guardianInvite,
        Routes.guardianProfileSwitch,
        Routes.inviteEnter,
      ]) {
        expect(guard(path, elumi: true), Routes.child, reason: path);
      }
    });

    test('보호자 휴대폰은 그대로 연다', () {
      for (final path in [
        Routes.guardianPeople,
        Routes.guardianInvite,
        Routes.guardianProfileSwitch,
      ]) {
        expect(guard(path), isNull, reason: path);
      }
    });

    test('새로 가입한 보호자(온보딩 전)도 초대 코드 넣기는 열 수 있다 — 온보딩을 건너뛰고 합류한다 (E6)', () {
      expect(guard(Routes.inviteEnter, onboarded: false), isNull);
    });

    test('세션이 없으면 초대 코드 넣기도 로그인으로 보낸다', () {
      expect(
        resolveRedirect(
          Routes.inviteEnter,
          hasSession: false,
          onboardingCompleted: false,
          skipOnboarding: false,
        ),
        Routes.login,
      );
    });
  });

  group('설정', () {
    Widget wrapSettings(List<ProfileSummary> profiles) {
      final router = GoRouter(
        initialLocation: Routes.guardianSettings,
        routes: [
          GoRoute(path: Routes.guardianSettings, builder: (_, _) => const GuardianSettingsScreen()),
          GoRoute(path: Routes.guardianPeople, builder: (_, _) => const Scaffold(body: Text('함께하는 사람 화면'))),
          GoRoute(path: Routes.guardianProfileSwitch, builder: (_, _) => const Scaffold(body: Text('이룸이 바꾸기 화면'))),
        ],
      );
      return ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(InMemoryStorage(onboardingCompleted: true)),
          memberProvider.overrideWith((ref) async => memberWith(profiles)),
          consentBundleProvider.overrideWith((ref) async => ConsentBundle.bundled),
          appVersionProvider.overrideWith((ref) async => '1.0.0'),
          creditSummaryProvider.overrideWith((ref) async => CreditSummary.fromJson(creditJson(enabled: false))),
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

    testWidgets('함께하는 사람 줄이 있고 누르면 그 화면으로 간다', (tester) async {
      await tester.pumpWidget(wrapSettings([kProfileA]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('함께하는 사람'));
      await tester.pumpAndSettle();

      expect(find.text('함께하는 사람 화면'), findsOneWidget);
    });

    testWidgets('이룸이가 하나뿐이면 이룸이 바꾸기 줄을 숨긴다', (tester) async {
      await tester.pumpWidget(wrapSettings([kProfileA]));
      await tester.pumpAndSettle();

      expect(find.text('이룸이 바꾸기'), findsNothing);
    });

    testWidgets('이룸이가 둘 이상이면 이룸이 바꾸기 줄에 지금 보는 이룸이 이름을 보이고 누르면 간다', (tester) async {
      await tester.pumpWidget(wrapSettings([kProfileA, kProfileB]));
      await tester.pumpAndSettle();

      expect(find.text('이룸이 바꾸기'), findsOneWidget);
      expect(find.text('하늘이'), findsOneWidget);

      await tester.tap(find.text('이룸이 바꾸기'));
      await tester.pumpAndSettle();

      expect(find.text('이룸이 바꾸기 화면'), findsOneWidget);
    });

    testWidgets('회원 정보를 못 받으면 이룸이 바꾸기만 숨기고 설정은 그대로 뜬다', (tester) async {
      final router = GoRouter(
        initialLocation: Routes.guardianSettings,
        routes: [GoRoute(path: Routes.guardianSettings, builder: (_, _) => const GuardianSettingsScreen())],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(InMemoryStorage(onboardingCompleted: true)),
            memberProvider.overrideWith((ref) async => null),
            consentBundleProvider.overrideWith((ref) async => ConsentBundle.bundled),
            appVersionProvider.overrideWith((ref) async => '1.0.0'),
            creditSummaryProvider.overrideWith((ref) async => CreditSummary.fromJson(creditJson(enabled: false))),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, child) => MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('이룸이 바꾸기'), findsNothing);
      expect(find.text('함께하는 사람'), findsOneWidget);
      expect(find.text('로그아웃'), findsOneWidget);
    });
  });

  group('로그인 — 이전 세션의 이룸이 상태를 버린다 (#362)', () {
    testWidgets('로그인에 성공하면 고른 이룸이와 회원 정보 캐시를 버린다 — 다른 계정이 들어와도 옛 이룸이로 시작하지 않는다', (tester) async {
      TestWidgetsFlutterBinding.ensureInitialized()
              .platformDispatcher
              .accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .clearAccessibilityFeaturesTestValue,
      );
      final storage = InMemoryStorage(onboardingCompleted: true, pin: '1234');
      await storage.setSelectedProfileId('p-old');
      var memberFetches = 0;
      final router = GoRouter(
        initialLocation: Routes.login,
        routes: [
          GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
          GoRoute(path: Routes.guardian, builder: (_, _) => const Scaffold(body: Text('보호자 홈'))),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(storage),
            authRepositoryProvider.overrideWithValue(_LoginSucceeds(storage)),
            memberProvider.overrideWith((ref) async {
              memberFetches++;
              return memberWith([kProfileA]);
            }),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, child) => MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(tester.element(find.byType(LoginScreen)));
      // 이전 세션에서 만들어진 이룸이 상태가 메모리에 남아 있다
      container.listen(profileSessionProvider, (_, _) {});
      expect(container.read(profileSessionProvider).selectedId, 'p-old');
      await tester.pump();
      final before = memberFetches;

      await tester.tap(find.text('카카오로 로그인'));
      await tester.pumpAndSettle();

      expect(find.text('보호자 홈'), findsOneWidget);
      // 저장소에서 지워진 값을 메모리 상태가 다시 읽었다 (옛 id 가 헤더에 실리지 않는다)
      expect(container.read(profileSessionProvider).selectedId, isNot('p-old'));
      expect(memberFetches, greaterThan(before));
    });
  });

  group('새 가입자의 진입점 — 온보딩 이름 화면', () {
    testWidgets('초대 코드가 있어요 링크가 초대 코드 넣기로 이어진다 (E6)', (tester) async {
      final router = GoRouter(
        initialLocation: Routes.onboardingName,
        routes: [
          GoRoute(path: Routes.onboardingName, builder: (_, _) => const NameScreen()),
          GoRoute(path: Routes.inviteEnter, builder: (_, _) => const Scaffold(body: Text('초대 코드 넣기 화면'))),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [localStorageProvider.overrideWithValue(InMemoryStorage())],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, child) => MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('초대 코드가 있어요'));
      await tester.pumpAndSettle();

      expect(find.text('초대 코드 넣기 화면'), findsOneWidget);
    });
  });

  group('보호자 홈', () {
    testWidgets('연결된 이룸이가 하나도 없으면 이룸이 등록으로 보낸다 (E29)', (tester) async {
      final storage = InMemoryStorage(onboardingCompleted: true);
      final router = GoRouter(
        initialLocation: Routes.guardian,
        routes: [
          GoRoute(path: Routes.guardian, builder: (_, _) => const GuardianHomeScreen()),
          GoRoute(path: Routes.onboardingName, builder: (_, _) => const Scaffold(body: Text('이룸이 등록'))),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(storage),
            // 서버가 "연결된 이룸이가 없다"고 답했다
            memberProvider.overrideWith((ref) async => memberWith(const [])),
            todayRoutinesProvider.overrideWith((ref) async => const []),
            pastRoutinesProvider.overrideWith((ref) async => const []),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, child) => MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('이룸이 등록'), findsOneWidget);
      expect(storage.isOnboardingCompleted, isFalse);
    });
  });
}

/// 카카오로 로그인하면 성공하는 가짜. 진짜 저장소처럼 **고른 이룸이를 지운다** (`_exchange`).
class _LoginSucceeds extends AuthRepository {
  _LoginSucceeds(this._storage)
    : super(
        dio: Dio(),
        storage: _storage,
        tokens: InMemoryTokenStore(),
        sdk: OAuthSdk(),
      );

  final InMemoryStorage _storage;

  @override
  Future<AuthResult> signInWith(OAuthProvider provider) async {
    await _storage.clearSelectedProfileId();
    return const AuthResult(AuthOutcome.home);
  }
}
