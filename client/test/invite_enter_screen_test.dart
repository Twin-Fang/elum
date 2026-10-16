import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/widgets/elum_button.dart';import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/profile/data/profile_repository.dart';
import 'package:elum/features/profile/presentation/invite_enter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/profile_fixtures.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 초대 코드 넣기 (#362 · E1·E2·E5·E6·E8·E47).
///
/// **실패 경로를 정상 경로만큼 고정한다.** 받는 사람은 처음 보는 화면이고, 틀렸을 때 무엇을
/// 해야 하는지 화면이 말해 주지 않으면 거기서 멈춘다. 서버가 준 문구를 그대로 보여 주는지,
/// 에러 코드가 함께 보이는지, 실패 뒤 입력이 갈래에 맞게 남거나 비워지는지를 본다.
void main() {
  useFigmaViewport();

  late FakeProfileRepository repo;
  late InMemoryStorage storage;

  setUp(() {
    repo = FakeProfileRepository();
    // 새로 가입한 보호자 — 약관은 마쳤고 온보딩은 안 했다 (E6)
    storage = InMemoryStorage();
  });

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.inviteEnter,
      routes: [
        GoRoute(path: Routes.inviteEnter, builder: (_, _) => const InviteEnterScreen()),
        GoRoute(path: Routes.guardian, builder: (_, _) => const Scaffold(body: Text('보호자 홈'))),
        GoRoute(path: Routes.consent, builder: (_, _) => const Scaffold(body: Text('약관 동의 화면'))),
      ],
    );
    return ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        localStorageProvider.overrideWithValue(storage),
        memberProvider.overrideWith((ref) async => memberWith([kProfileB])),
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

  Future<void> type(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.pumpAndSettle();
  }

  /// 여섯 자를 채우고 `시작하기` 를 눌러 보낸다 (자동 제출은 없다)
  Future<void> typeAndStart(WidgetTester tester, String code) async {
    await type(tester, code);
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
  }

  VoidCallback? startButtonAction(WidgetTester tester) =>
      tester.widget<ElumButton>(find.byType(ElumButton)).onPressed;




  group('정상', () {
    testWidgets('여섯 자를 채워도 보내지 않고 시작하기가 켜진다 — 틀린 시도를 서버가 세기 때문', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(startButtonAction(tester), isNull);

      await type(tester, 'A7K3M9');

      expect(repo.sentCodes, isEmpty);
      expect(startButtonAction(tester), isNotNull);
    });

    testWidgets('시작하기를 누르면 보내고 합류한 이룸이의 보호자 홈으로 간다 (E6)', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await typeAndStart(tester, 'A7K3M9');

      expect(repo.sentCodes, ['A7K3M9']);
      expect(find.text('보호자 홈'), findsOneWidget);
      // 온보딩(이룸이 등록)을 건너뛰어도 라우터가 이름 입력으로 되돌리지 않는다
      expect(storage.isOnboardingCompleted, isTrue);
      expect(storage.selectedProfileId, 'p-b');
      expect(find.textContaining('바다'), findsOneWidget); // 스낵바
    });


  });

  group('실패 — 갈래마다 다르게 움직인다', () {
    Future<void> failWith(
      WidgetTester tester,
      AppFailure failure,
    ) async {
      repo.redeemResult = Attempt.failed(failure);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await typeAndStart(tester, 'A7K3M9');
    }






    testWidgets('약관 미동의(403): 팝업으로 알리고 확인하면 동의 화면으로 간다 (E6)', (tester) async {
      await failWith(tester, serverFailure(403, ServerErrorCode.consentRequired, '약관에 먼저 동의해주세요.'));

      expect(find.textContaining('약관에 먼저 동의해주세요.'), findsOneWidget);
      expect(find.text('CONSENT_REQUIRED'), findsOneWidget);

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(find.text('약관 동의 화면'), findsOneWidget);
    });



    testWidgets('예상 못 한 실패도 화면을 덮지 않고 코드를 보인다', (tester) async {
      await failWith(tester, serverFailure(500, ServerErrorCode.internalServerError, '잠시 후 다시 시도해주세요.'));

      // 서버 enum 이 아니라 앱 에러 코드(상태 코드 포함)를 보인다
      expect(find.textContaining('E-INV/500'), findsOneWidget);
      expect(find.textContaining('INTERNAL_SERVER_ERROR'), findsNothing);
      expect(find.text('보호자 홈'), findsNothing);
    });

  });

}
