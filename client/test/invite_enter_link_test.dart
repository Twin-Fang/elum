import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/widgets/elum_button.dart';
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
import 'helpers/semantics_audit.dart';
import 'package:elum/features/member/application/member_providers.dart';

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
    testWidgets('여섯 글자가 칸에 보이고 링크로 받았다고 알려 준다', (tester) async {
      await open(tester);

      for (final ch in 'A7K3M9'.split('')) {
        expect(find.text(ch), findsOneWidget);
      }
      expect(find.textContaining('링크로 받은 초대 코드'), findsOneWidget);
      // 이룸이 휴대폰의 연결 암호와 말을 섞지 않는다
      expect(find.textContaining('연결 암호'), findsNothing);
    });

    testWidgets('자동으로 합류하지 않는다 — 사람이 확인하기 전에는 서버에 보내지 않는다', (tester) async {
      await open(tester);
      await tester.pump(const Duration(seconds: 3));

      expect(repo.sentCodes, isEmpty);
      expect(find.text('보호자 홈'), findsNothing);
      expect(find.text('함께하기'), findsOneWidget);
    });

    testWidgets('함께하기를 누르면 한 번 보내고 합류한 이룸이의 보호자 홈으로 간다', (tester) async {
      await open(tester);

      await tester.tap(find.text('함께하기'));
      await tester.pumpAndSettle();

      expect(repo.sentCodes, ['A7K3M9']);
      expect(find.text('보호자 홈'), findsOneWidget);
      expect(storage.selectedProfileId, 'p-b');
      expect(storage.isOnboardingCompleted, isTrue);
      expect(find.textContaining('바다'), findsOneWidget); // 스낵바
    });

    testWidgets('우편함은 비워진다 — 같은 코드를 두 번 보내면 두 번째는 409 다', (tester) async {
      await open(tester);
      expect(inbox.hasPending, isFalse);
    });

    testWidgets('소문자·하이픈이 섞여 있어도 정규화된 코드가 보내진다', (tester) async {
      // 해석기가 이미 정규화하지만 우편함에는 어떤 값이 와도 화면이 한 번 더 맞춘다
      await open(tester, code: 'A7K3M9');
      await tester.tap(find.text('함께하기'));
      await tester.pumpAndSettle();
      expect(repo.sentCodes.single, 'A7K3M9');
    });

    testWidgets('함께하기를 두 번 눌러도 한 번만 보낸다', (tester) async {
      await open(tester);

      // 같은 프레임에 두 번 — 첫 요청이 합류시키면 두 번째는 409 다
      final press = tester.widget<ElumButton>(find.byType(ElumButton)).onPressed!;
      press();
      press();
      await tester.pumpAndSettle();

      expect(repo.sentCodes.length, 1);
    });

    testWidgets('이름 없는 누름 자리가 없고 버튼이 이름으로 읽힌다', (tester) async {
      await open(tester);
      expect(unnamedTapTargets(tester), isEmpty);
    });

    testWidgets('직접 입력 안내 카드는 숨긴다 — 받은 코드가 이미 채워져 있다', (tester) async {
      await open(tester);
      expect(find.textContaining('설정 → 함께하는 사람'), findsNothing);
    });
  });

  group('링크로 열리지 않으면 지금까지와 같다', () {
    testWidgets('우편함이 비었으면 빈 입력 화면이고 여섯 자를 치면 바로 보낸다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('함께하기'), findsNothing);
      expect(find.textContaining('설정 → 함께하는 사람'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'A7K3M9');
      await tester.pumpAndSettle();
      expect(repo.sentCodes, ['A7K3M9']);
    });

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

  group('링크가 맞지 않을 때', () {
    testWidgets('코드를 못 쓰는 링크: 에러 코드와 안내를 보이고 빈 입력으로 직접 넣게 한다', (tester) async {
      await open(tester, code: null);

      expect(find.textContaining('E-INV-LINK'), findsOneWidget);
      expect(find.text('함께하기'), findsNothing);
      expect(input(tester).text, isEmpty);
      expect(repo.sentCodes, isEmpty);

      // 직접 치는 길은 그대로 열려 있다
      await tester.enterText(find.byType(TextField), 'A7K3M9');
      await tester.pumpAndSettle();
      expect(repo.sentCodes, ['A7K3M9']);
    });
  });

  group('실패 — 직접 친 코드와 같은 갈래로 안내한다', () {
    Future<void> failWith(WidgetTester tester, AppFailure failure) async {
      repo.redeemResult = Attempt.failed(failure);
      await open(tester);
      await tester.tap(find.text('함께하기'));
      await tester.pumpAndSettle();
    }

    testWidgets('없는·쓴 코드(404): 서버 문구와 에러 코드를 보이고 확인 상태를 거둔다', (tester) async {
      await failWith(tester, serverFailure(404, ServerErrorCode.profileInviteNotFound, '초대 코드가 맞지 않아요.'));

      expect(find.textContaining('초대 코드가 맞지 않아요.'), findsOneWidget);
      expect(find.textContaining('PROFILE_INVITE_NOT_FOUND'), findsOneWidget);
      expect(find.text('함께하기'), findsNothing);
      expect(input(tester).text, isEmpty);
    });

    testWidgets('만료(410): 새 코드를 받으라고 말한다', (tester) async {
      await failWith(tester, serverFailure(410, ServerErrorCode.profileInviteExpired, '초대 코드가 만료됐어요. 새 코드를 받아주세요.'));

      expect(find.textContaining('새 코드를 받아주세요'), findsOneWidget);
      expect(find.textContaining('PROFILE_INVITE_EXPIRED'), findsOneWidget);
      expect(find.text('함께하기'), findsNothing);
    });

    testWidgets('이미 함께하는 이룸이(409): 이유와 코드를 보인다', (tester) async {
      await failWith(tester, serverFailure(409, ServerErrorCode.profileAlreadyGuardian, '이미 함께하고 있는 이룸이예요.'));

      expect(find.textContaining('이미 함께하고 있는 이룸이예요.'), findsOneWidget);
      expect(find.textContaining('PROFILE_ALREADY_GUARDIAN'), findsOneWidget);
    });

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

  group('다른 코드 넣기', () {
    testWidgets('채워진 코드를 거두고 직접 입력으로 바꾼다', (tester) async {
      await open(tester);

      await tester.tap(find.text('다른 코드 넣기'));
      await tester.pumpAndSettle();

      expect(input(tester).text, isEmpty);
      expect(find.text('함께하기'), findsNothing);
      expect(repo.sentCodes, isEmpty);

      await tester.enterText(find.byType(TextField), 'B2C4D6');
      await tester.pumpAndSettle();
      expect(repo.sentCodes, ['B2C4D6']);
    });
  });

  group('입력 화면이 이미 열려 있을 때 링크가 오면', () {
    testWidgets('받은 코드로 채우고 확인을 기다린다 — 직접 치던 것은 대신한다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'B2C');
      await tester.pump();

      inbox.receive('A7K3M9');
      await tester.pumpAndSettle();

      expect(find.text('함께하기'), findsOneWidget);
      expect(repo.sentCodes, isEmpty);
      for (final ch in 'A7K3M9'.split('')) {
        expect(find.text(ch), findsOneWidget);
      }
      expect(inbox.hasPending, isFalse);
    });

    testWidgets('보내는 중에 온 링크는 그 요청이 끝난 뒤에 이어 채운다 — 보내던 코드는 건드리지 않는다', (tester) async {
      await open(tester);
      repo.redeemResult = Attempt.failed(serverFailure(404, ServerErrorCode.profileInviteNotFound));
      await tester.tap(find.text('함께하기'));
      // 응답이 오기 전 — 보내는 중이다
      inbox.receive('B2C4D6');
      await tester.pumpAndSettle();

      // 보내던 것은 그대로 한 번, 새 링크는 실패 안내 뒤에 채워져 확인을 기다린다
      expect(repo.sentCodes, ['A7K3M9']);
      expect(find.text('함께하기'), findsOneWidget);
      for (final ch in 'B2C4D6'.split('')) {
        expect(find.text(ch), findsOneWidget);
      }
      expect(inbox.hasPending, isFalse);
    });
  });
}
