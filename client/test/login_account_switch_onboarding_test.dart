import 'package:dio/dio.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/auth/data/oauth_sdk.dart';
import 'package:elum/features/auth/presentation/login_screen.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/features/onboarding/domain/character.dart';
import 'package:elum/features/onboarding/domain/image_style.dart';
import 'package:elum/features/onboarding/domain/support_goal.dart';
import 'package:elum/features/profile/application/profile_session.dart';
import 'package:elum/features/profile/domain/profile_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';

/// 다른 계정으로 로그인했을 때 이전 계정의 **이룸이 설정**이 메모리에 남지 않는다.
///
/// 로그아웃·탈퇴는 저장소만 비우고 메모리는 다음 로그인에서 버린다 (#362 · #482). 이미 온보딩을
/// 마친 계정으로 들어오는 경로(`AuthOutcome.home`)는 이룸이 상태(`onboardingProvider`)를 비우지
/// 않았다. 새 계정의 이룸이에 캐릭터가 없으면 서버 값 반영이 "없으면 기존 값 유지"라 이전 계정의
/// 캐릭터·도움 목표·그림 방식·PIN 이 홈과 일과 만들기에 그대로 쓰였다.
void main() {
  useFigmaViewport();

  testWidgets('이미 온보딩을 마친 계정으로 로그인하면 이전 계정의 이룸이 설정이 남지 않는다', (tester) async {
    final storage = InMemoryStorage(onboardingCompleted: true);
    final router = GoRouter(
      initialLocation: Routes.login,
      routes: [
        GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: Routes.guardian,
          builder: (_, _) => const Scaffold(body: Text('보호자 홈')),
        ),
      ],
    );
    // 계정 B: 이룸이에 캐릭터·도움 목표가 아직 없다 (옛 데이터·서버 값 없음)
    const memberB = Member(
      nickname: 'B',
      profiles: [ProfileSummary(id: 'pB', nickname: 'B')],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          memberProvider.overrideWith((ref) async => memberB),
          authRepositoryProvider.overrideWithValue(_LoginSucceeds(storage)),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, child) =>
              MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LoginScreen)),
    );

    // 계정 A 로 쓰던 상태 — 여우·목표·실사 그림·PIN 이 메모리에 있다
    final notifier = container.read(onboardingProvider.notifier);
    await notifier.applyServerProfile(
      const ProfileSummary(
        id: 'pA',
        nickname: 'A',
        character: 'POPO',
        imageStyle: ImageStyle.realistic,
      ),
      goals: const ['PREPARE_ITEMS'],
    );
    notifier.setPin('1234');
    final before = container.read(onboardingProvider);
    expect(before.cardCharacter, CardCharacter.fox);
    expect(before.supportGoals, {SupportGoal.prepareItems});

    // 로그아웃·탈퇴 — 저장소는 비워지지만(AuthRepository.logout) 메모리는 그대로다
    await storage.clearAll();

    // 앱을 끄지 않고 계정 B 로 로그인한다
    await tester.tap(find.text('카카오로 로그인'));
    await tester.pumpAndSettle();
    container.read(profileSessionProvider); // 홈이 열리면 읽는다 — 회원 정보 반영이 돈다
    await tester.pumpAndSettle();

    expect(find.text('보호자 홈'), findsOneWidget);
    final after = container.read(onboardingProvider);
    expect(after.cardCharacter, isNull, reason: '이전 계정(A)의 캐릭터가 남았다');
    expect(after.supportGoals, isEmpty, reason: '이전 계정(A)의 도움 목표가 남았다');
    expect(after.imageStyle, ImageStyle.cartoon, reason: '이전 계정(A)의 그림 방식이 남았다');
    expect(after.guardianPin, isEmpty, reason: '이전 계정(A)의 PIN 이 남았다');
  });
}

/// 로그인하면 홈으로 가는 가짜 — 이미 온보딩을 마친 계정이다.
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
