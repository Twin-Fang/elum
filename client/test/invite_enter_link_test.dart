import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/profile/application/invite_inbox.dart';
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

/// 링크로 받은 초대 코드가 채워진 입력 화면 (#365).
///
/// **링크는 코드를 대신 전달하는 수단일 뿐이다.** 코드 흐름·합류 규칙은 그대로다 —
/// 채워진 코드로 **자동 합류하지 않고**, 사람이 `함께하기` 를 눌러야 서버에 보낸다. 실패는 직접 친 코드와
/// 같은 갈래·같은 에러 코드로 안내한다.
void main() {
  useFigmaViewport();

  late FakeProfileRepository repo;
  late InMemoryStorage storage;
  late InviteInbox inbox;

  setUp(() {
    repo = FakeProfileRepository();
    storage = InMemoryStorage();
    inbox = InviteInbox();
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
        inviteInboxProvider.overrideWithValue(inbox),
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

  Future<void> open(WidgetTester tester, {String? code = 'A7K3M9'}) async {
    inbox.receive(code);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
  }

  TextEditingController input(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!;

  group('코드가 채워진 채로 열린다', () {

    testWidgets('자동으로 합류하지 않는다 — 사람이 확인하기 전에는 서버에 보내지 않는다', (tester) async {
      await open(tester);
      await tester.pump(const Duration(seconds: 3));

      expect(repo.sentCodes, isEmpty);
      expect(find.text('보호자 홈'), findsNothing);
      expect(find.text('함께하기'), findsOneWidget);
    });






  });

  group('링크로 열리지 않으면 지금까지와 같다', () {

    testWidgets('10분이 지난 링크는 채우지 않는다 — 만료된 코드로 서버에서 되돌려 받게 하지 않는다', (tester) async {
      var now = DateTime(2026, 10, 1, 12);
      inbox = InviteInbox(now: () => now);
      inbox.receive('A7K3M9');
      now = now.add(const Duration(minutes: 10));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('함께하기'), findsNothing);
      expect(input(tester).text, isEmpty);
    });
  });


  group('실패 — 직접 친 코드와 같은 갈래로 안내한다', () {
    Future<void> failWith(WidgetTester tester, AppFailure failure) async {
      repo.redeemResult = Attempt.failed(failure);
      await open(tester);
      await tester.tap(find.text('함께하기'));
      await tester.pumpAndSettle();
    }




    testWidgets('시도 한도(429): 안내하고 입력을 잠가 더 보내지 않는다', (tester) async {
      await failWith(tester, serverFailure(429, ServerErrorCode.profileInviteTooManyAttempts, '여러 번 잘못 입력했어요.'));

      expect(find.textContaining('여러 번 잘못 입력했어요'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(find.text('함께하기'), findsNothing);
      expect(repo.sentCodes.length, 1);
    });

    testWidgets('인터넷이 없으면: E-NET-OFFLINE 을 보이고 코드를 남겨 함께하기로 다시 보낸다', (tester) async {
      await failWith(tester, const AppFailure(fault: NetworkFault.offline));

      expect(find.textContaining('E-NET-OFFLINE'), findsOneWidget);
      // 다시 칠 필요가 없다 — 같은 버튼이 다시 시도다
      expect(find.text('함께하기'), findsOneWidget);
      expect(find.text('다시 시도'), findsNothing);

      repo.redeemResult = null;
      await tester.tap(find.text('함께하기'));
      await tester.pumpAndSettle();

      expect(repo.sentCodes, ['A7K3M9', 'A7K3M9']);
      expect(find.text('보호자 홈'), findsOneWidget);
    });

    testWidgets('약관 미동의(403): 팝업 뒤 동의 화면으로 가고 링크의 코드는 다시 맡겨 둔다', (tester) async {
      await failWith(tester, serverFailure(403, ServerErrorCode.consentRequired, '약관에 먼저 동의해주세요.'));

      expect(find.textContaining('약관에 먼저 동의해주세요.'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(find.text('약관 동의 화면'), findsOneWidget);
      // 동의를 마치고 홈에 닿으면 이어서 열린다
      expect(inbox.take()?.code, 'A7K3M9');
    });
  });


}
