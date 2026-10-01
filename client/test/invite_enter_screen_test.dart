import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/features/link/presentation/widgets/code_boxes.dart';
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

  TextEditingController input(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!;

  testWidgets('어디서 받는지와 이 코드가 초대 코드라는 것을 화면이 알려 준다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('함께하는 보호자 휴대폰에서'), findsOneWidget);
    expect(find.textContaining('설정 → 함께하는 사람'), findsOneWidget);
    // 이룸이 휴대폰의 연결 암호와 말을 섞지 않는다
    expect(find.textContaining('연결 암호'), findsNothing);
    expect(find.textContaining('초대 코드'), findsWidgets);
  });

  testWidgets('여섯 칸이 초대 코드 넣기로 읽히고 이름 없는 누름 자리가 없다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expectLabeledButton(tester, '초대 코드 넣기');
    expect(unnamedTapTargets(tester), isEmpty);
  });

  group('정상', () {
    testWidgets('여섯 자를 채우면 확인 버튼 없이 바로 보내고 합류한 이룸이의 보호자 홈으로 간다 (E6)', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await type(tester, 'A7K3M9');

      expect(repo.sentCodes, ['A7K3M9']);
      expect(find.text('보호자 홈'), findsOneWidget);
      // 온보딩(이룸이 등록)을 건너뛰어도 라우터가 이름 입력으로 되돌리지 않는다
      expect(storage.isOnboardingCompleted, isTrue);
      expect(storage.selectedProfileId, 'p-b');
      expect(find.textContaining('바다'), findsOneWidget); // 스낵바
    });

    testWidgets('소문자·공백·하이픈으로 쳐도 대문자로 정리해 보낸다 (입력 정규화)', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await type(tester, 'a7k-3m9');

      expect(repo.sentCodes, ['A7K3M9']);
    });

    testWidgets('보내는 중에 같은 코드를 두 번 보내지 않는다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'A7K3M9');
      await tester.enterText(find.byType(TextField), 'A7K3M9 ');
      await tester.pumpAndSettle();

      expect(repo.sentCodes.length, 1);
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
      await type(tester, 'A7K3M9');
    }

    testWidgets('없는 코드(404): 서버 문구와 에러 코드를 보이고 입력을 비운다 (E8)', (tester) async {
      await failWith(tester, serverFailure(404, ServerErrorCode.profileInviteNotFound, '초대 코드가 맞지 않아요.'));

      expect(find.textContaining('초대 코드가 맞지 않아요.'), findsOneWidget);
      expect(find.textContaining('PROFILE_INVITE_NOT_FOUND'), findsOneWidget);
      expect(input(tester).text, isEmpty);
      expect(find.text('보호자 홈'), findsNothing);
    });

    testWidgets('만료(410): 새 코드를 받으라고 말한다', (tester) async {
      await failWith(tester, serverFailure(410, ServerErrorCode.profileInviteExpired, '초대 코드가 만료됐어요. 새 코드를 받아주세요.'));

      expect(find.textContaining('새 코드를 받아주세요'), findsOneWidget);
      expect(find.textContaining('PROFILE_INVITE_EXPIRED'), findsOneWidget);
      expect(input(tester).text, isEmpty);
    });

    testWidgets('이미 함께하는 이룸이(409, 자기 코드 포함): 이유와 코드를 보인다 (E1·E2)', (tester) async {
      await failWith(tester, serverFailure(409, ServerErrorCode.profileAlreadyGuardian, '이미 함께하고 있는 이룸이예요.'));

      expect(find.textContaining('이미 함께하고 있는 이룸이예요.'), findsOneWidget);
      expect(find.textContaining('PROFILE_ALREADY_GUARDIAN'), findsOneWidget);
      expect(find.text('보호자 홈'), findsNothing);
    });

    testWidgets('시도 한도(429): 안내하고 입력을 잠가 더 보내지 않는다', (tester) async {
      await failWith(tester, serverFailure(429, ServerErrorCode.profileInviteTooManyAttempts, '여러 번 잘못 입력했어요. 잠시 뒤에 다시 하거나 새 코드를 받아주세요.'));

      expect(find.textContaining('여러 번 잘못 입력했어요'), findsOneWidget);
      expect(find.textContaining('PROFILE_INVITE_TOO_MANY_ATTEMPTS'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      // 잠긴 뒤 칸을 눌러도 다시 보내지 않는다
      await tester.tap(find.bySemanticsLabel('초대 코드 넣기'));
      await tester.pumpAndSettle();
      expect(repo.sentCodes.length, 1);
    });

    testWidgets('이룸이 휴대폰(403): 이유를 보이고 잠근다 — 서버 코드 DEVICE_LINK_FORBIDDEN_FOR_ELUMI', (tester) async {
      await failWith(tester, serverFailure(403, ServerErrorCode.deviceLinkForbiddenForElumi, '이룸이 휴대폰에서는 할 수 없어요.'));

      expect(find.textContaining('이룸이 휴대폰에서는 할 수 없어요.'), findsOneWidget);
      expect(find.textContaining('DEVICE_LINK_FORBIDDEN_FOR_ELUMI'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('약관 미동의(403): 팝업으로 알리고 확인하면 동의 화면으로 간다 (E6)', (tester) async {
      await failWith(tester, serverFailure(403, ServerErrorCode.consentRequired, '약관에 먼저 동의해주세요.'));

      expect(find.textContaining('약관에 먼저 동의해주세요.'), findsOneWidget);
      expect(find.text('CONSENT_REQUIRED'), findsOneWidget);

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(find.text('약관 동의 화면'), findsOneWidget);
    });

    testWidgets('인터넷이 없으면: E-NET-OFFLINE 과 안내를 보이고 입력을 남겨 다시 시도할 수 있다 (E47)', (tester) async {
      await failWith(tester, const AppFailure(fault: NetworkFault.offline));

      expect(find.textContaining('E-NET-OFFLINE'), findsOneWidget);
      expect(find.textContaining('인터넷'), findsWidgets);
      // 다시 칠 필요가 없다
      expect(input(tester).text, 'A7K3M9');

      repo.redeemResult = null; // 이번에는 성공한다
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(repo.sentCodes, ['A7K3M9', 'A7K3M9']);
      expect(find.text('보호자 홈'), findsOneWidget);
    });

    testWidgets('시간 초과도 오프라인과 같이 다룬다 (E-NET-TIMEOUT)', (tester) async {
      await failWith(tester, const AppFailure(fault: NetworkFault.timeout));

      expect(find.textContaining('E-NET-TIMEOUT'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('예상 못 한 실패도 화면을 덮지 않고 코드를 보인다', (tester) async {
      await failWith(tester, serverFailure(500, ServerErrorCode.internalServerError, '잠시 후 다시 시도해주세요.'));

      expect(find.textContaining('E-INV'), findsNothing); // 서버 코드가 이긴다
      expect(find.textContaining('INTERNAL_SERVER_ERROR'), findsOneWidget);
      expect(find.text('보호자 홈'), findsNothing);
    });

    testWidgets('만들 수 없는 모양은 서버에 보내지 않는다 — 계정당 시도 한도를 아낀다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // 0 은 서버가 만들지 않는 글자다
      await type(tester, 'A0K3M9');

      expect(repo.sentCodes, isEmpty);
      expect(find.textContaining('E-INV-FORM'), findsOneWidget);
    });
  });

  testWidgets('틀려도 칸 테두리를 경고색으로 칠하지 않는다 — 이룸이 휴대폰에도 깔리는 앱이다', (tester) async {
    repo.redeemResult = Attempt.failed(serverFailure(404, ServerErrorCode.profileInviteNotFound));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await type(tester, 'A7K3M9');

    final danger = AppTheme.light.extension<AppColors>()!.danger;
    final borders = tester
        .widgetList<Container>(
          find.descendant(of: find.byType(CodeBoxes), matching: find.byType(Container)),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.border)
        .whereType<Border>()
        .map((b) => b.top.color)
        .toList();
    expect(borders, isNotEmpty);
    expect(borders, everyElement(isNot(danger)));
  });
}
