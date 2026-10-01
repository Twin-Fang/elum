import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/features/profile/data/profile_repository.dart';
import 'package:elum/features/profile/domain/guardian_member.dart';
import 'package:elum/features/profile/presentation/guardians_screen.dart';
import 'package:elum/features/profile/presentation/invite_code_screen.dart';
import 'package:elum/features/profile/presentation/invite_enter_screen.dart';
import 'package:elum/features/profile/presentation/profile_switch_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/profile_fixtures.dart';

/// 시스템 글자를 가장 크게 키운 보호자에게도 새 화면이 깨지지 않는다 (#362 · 디자인 원칙 §7-2 #19).
///
/// 50대 보호자가 흔히 켜 두는 설정이다. 넘침(overflow)은 `flutter_test_config.dart` 가 자동으로
/// 실패시키므로 여기서는 화면을 크게 띄워 보기만 하면 된다. 가장 긴 문구(마지막 보호자 안내·
/// 오류 문구)가 들어간 상태로 본다.
void main() {
  useFigmaViewport();

  late FakeProfileRepository repo;

  setUp(() => repo = FakeProfileRepository());

  Future<void> pump(WidgetTester tester, String path, Widget screen, {double scale = 2.0}) async {
    final router = GoRouter(
      initialLocation: path,
      routes: [GoRoute(path: path, builder: (_, _) => screen)],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          localStorageProvider.overrideWithValue(InMemoryStorage(onboardingCompleted: true)),
          memberProvider.overrideWith((ref) async => memberWith([kProfileA, kProfileB])),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, child) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  for (final scale in [1.3, 2.0]) {
    testWidgets('초대 코드 만들기 — 글꼴 $scale', (tester) async {
      await pump(tester, Routes.guardianInvite, const InviteCodeScreen(), scale: scale);
      expect(find.byType(InviteCodeScreen), findsOneWidget);
    });

    testWidgets('초대 코드 넣기 — 글꼴 $scale (긴 실패 문구 포함)', (tester) async {
      await pump(tester, Routes.inviteEnter, const InviteEnterScreen(), scale: scale);
      await tester.enterText(find.byType(TextField), 'A0K3M9');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('E-INV-FORM'), findsOneWidget);
    });

    testWidgets('함께하는 사람 — 글꼴 $scale', (tester) async {
      await pump(tester, Routes.guardianPeople, const GuardiansScreen(), scale: scale);
      expect(find.text('엄마'), findsOneWidget);
    });

    testWidgets('이룸이 바꾸기 — 글꼴 $scale', (tester) async {
      await pump(tester, Routes.guardianProfileSwitch, const ProfileSwitchScreen(), scale: scale);
      expect(find.text('하늘이'), findsOneWidget);
    });
  }

  testWidgets('나가기 확인 팝업 — 마지막 보호자 문구가 글꼴 2.0 에서도 나가기·취소 버튼을 가리지 않는다', (tester) async {
    repo.guardiansResult = const Attempt.ok([Guardian(id: 'g-1', me: true)]);
    await pump(tester, Routes.guardianPeople, const GuardiansScreen());

    await tester.ensureVisible(find.text('이 이룸이에서 나가기'));
    await tester.pump();
    await tester.tap(find.text('이 이룸이에서 나가기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('되돌릴 수 없어요'), findsOneWidget);
    expect(find.text('나가기'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
  });
}
