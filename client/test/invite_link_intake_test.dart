import 'package:elum/core/router/app_router.dart';
import 'package:elum/features/profile/application/invite_inbox.dart';
import 'package:elum/features/profile/application/invite_link_intake.dart';
import 'package:elum/features/profile/domain/invite_link.dart';
import 'package:elum/features/profile/presentation/invite_link_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// 열린 초대 링크를 알맞은 때에 입력 화면으로 이어 주는 판단 (#365).
///
/// **링크는 아무 때나 열린다.** 로그인 전·온보딩 도중·이룸이 휴대폰·다른 일을 하던 중에도.
/// 그때마다 화면을 덮으면 하던 일이 날아가고, 그냥 버리면 받은 사람이 링크를 다시 눌러야 한다.
/// 진짜 입력 화면이 우편함을 다루는 모양만 흉내 낸다 — 열릴 때 꺼내고, 열려 있는 동안 새로 오면 꺼낸다.
class _FakeEnterScreen extends StatefulWidget {
  const _FakeEnterScreen({required this.inbox});

  final InviteInbox inbox;

  @override
  State<_FakeEnterScreen> createState() => _FakeEnterScreenState();
}

class _FakeEnterScreenState extends State<_FakeEnterScreen> {
  void _take() => widget.inbox.take();

  @override
  void initState() {
    super.initState();
    _take();
    widget.inbox.addListener(_take);
  }

  @override
  void dispose() {
    widget.inbox.removeListener(_take);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('초대 코드 입력'));
}

void main() {
  group('판단 — InviteLinkIntake', () {
    late InviteInbox inbox;
    late int opened;
    late bool elumi;
    late bool session;
    late String? top;

    InviteLinkIntake build() => InviteLinkIntake(
      inbox: inbox,
      isElumiDevice: () => elumi,
      hasSession: () => session,
      topLocation: () => top,
      open: () => opened++,
    );

    InviteLink link(String? code) => InviteLink(code: code);

    setUp(() {
      inbox = InviteInbox();
      opened = 0;
      elumi = false;
      session = true;
      top = Routes.guardian;
    });

    test('보호자 홈에 있으면 바로 입력 화면을 연다', () {
      build().accept(link('A7K3M9'));

      expect(opened, 1);
      // 우편함에는 아직 있다 — 화면이 열리면서 꺼낸다
      expect(inbox.take()?.code, 'A7K3M9');
    });

    test('이름 화면(온보딩 도중)에서도 연다 — 새로 가입한 보호자는 이룸이 등록을 건너뛴다 (E6)', () {
      top = Routes.onboardingName;
      build().accept(link('A7K3M9'));
      expect(opened, 1);
    });

    test('로그인 전이면 열지 않고 맡겨 둔다 — 로그인 뒤 알맞은 자리에 닿으면 연다', () {
      session = false;
      top = Routes.login;
      final intake = build();
      intake.accept(link('A7K3M9'));
      expect(opened, 0);
      expect(inbox.hasPending, isTrue);

      // 로그인하고 이름 화면에 닿았다
      session = true;
      top = Routes.onboardingName;
      expect(intake.tryOpen(), isTrue);
      expect(opened, 1);
    });

    for (final where in [
      Routes.consent,
      Routes.roleSelect,
      Routes.onboardingGoals,
      Routes.onboardingCharacter,
      Routes.onboardingPin,
      Routes.guardianSettings,
      Routes.routineInput,
      Routes.routineReview,
      Routes.inviteEnter,
      Routes.linkCode,
    ]) {
      test('$where 에서는 하던 일을 끊지 않는다 — 맡겨 둔다', () {
        top = where;
        build().accept(link('A7K3M9'));
        expect(opened, 0);
        expect(inbox.hasPending, isTrue);
      });
    }

    test('하던 일을 마치고 홈에 돌아오면 그때 연다', () {
      top = Routes.routineInput;
      final intake = build();
      intake.accept(link('A7K3M9'));
      expect(opened, 0);

      top = Routes.guardian;
      expect(intake.tryOpen(), isTrue);
      expect(opened, 1);
    });

    test('이룸이 휴대폰에서 열린 링크는 우편함에도 두지 않고 무시한다', () {
      elumi = true;
      var notified = 0;
      inbox.addListener(() => notified++);
      build().accept(link('A7K3M9'));

      expect(opened, 0);
      expect(inbox.hasPending, isFalse);
      // 열려 있는 입력 화면(이룸이 휴대폰에는 없지만)도 깨우지 않는다
      expect(notified, 0);
    });

    test('맡겨 둔 뒤 이룸이 휴대폰이 되었다면 버린다 — 이어 줄 이유가 없다', () {
      session = false;
      final intake = build();
      intake.accept(link('A7K3M9'));
      expect(inbox.hasPending, isTrue);

      elumi = true;
      session = true;
      expect(intake.tryOpen(), isFalse);
      expect(inbox.hasPending, isFalse);
      expect(opened, 0);
    });

    test('코드를 못 쓰는 링크도 연다 — 입력 화면이 에러 안내를 띄운다', () {
      build().accept(link(null));

      expect(opened, 1);
      final p = inbox.take();
      expect(p, isNotNull);
      expect(p!.code, isNull);
    });

    test('10분이 지난 링크는 열지 않는다', () {
      var now = DateTime(2026, 10, 1, 12);
      inbox = InviteInbox(now: () => now);
      session = false;
      final intake = build();
      intake.accept(link('A7K3M9'));

      now = now.add(const Duration(minutes: 11));
      session = true;
      expect(intake.tryOpen(), isFalse);
      expect(opened, 0);
    });

    test('맡긴 것이 없으면 아무 일도 하지 않는다', () {
      expect(build().tryOpen(), isFalse);
      expect(opened, 0);
    });

    test('위치를 알 수 없으면(null) 열지 않는다', () {
      top = null;
      build().accept(link('A7K3M9'));
      expect(opened, 0);
    });
  });

  group('받는 쪽 — InviteLinkHost (OS 가 켜진 앱에 링크를 밀어 넣을 때)', () {
    late GoRouter router;
    late InviteInbox inbox;
    late bool session;
    late bool elumi;

    Widget placeholder(String name) => Scaffold(body: Text(name));

    Future<void> pump(WidgetTester tester) async {
      inbox = InviteInbox();
      session = true;
      elumi = false;
      router = GoRouter(
        initialLocation: Routes.guardian,
        routes: [
          GoRoute(path: Routes.guardian, builder: (_, _) => placeholder('보호자 홈')),
          GoRoute(path: Routes.guardianSettings, builder: (_, _) => placeholder('설정')),
          GoRoute(path: Routes.routineInput, builder: (_, _) => placeholder('일과 만들기')),
          // 진짜 입력 화면은 열릴 때 우편함에서 코드를 꺼낸다 — 같은 모양으로 흉내 낸다
          GoRoute(
            path: Routes.inviteEnter,
            builder: (_, _) => _FakeEnterScreen(inbox: inbox),
          ),
        ],
        // 라우터가 초대 주소를 받으면 오류 화면이 뜬다 — 관찰자가 먼저 가져갔는지 눈으로 보려는 장치
        errorBuilder: (_, _) => placeholder('라우터가 받았다'),
      );
      final intake = InviteLinkIntake(
        inbox: inbox,
        isElumiDevice: () => elumi,
        hasSession: () => session,
        topLocation: () => router.routerDelegate.currentConfiguration.lastOrNull?.matchedLocation,
        open: () => router.push(Routes.inviteEnter),
      );
      await tester.pumpWidget(
        InviteLinkHost(
          router: router,
          intake: intake,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pushFromOs(WidgetTester tester, String uri) async {
      final message = const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', {'location': uri}),
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        message,
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    testWidgets('홈에서 링크가 오면 입력 화면이 홈 위에 얹히고 뒤로 가면 홈이다', (tester) async {
      await pump(tester);

      await pushFromOs(tester, 'elum://invite?code=A7K3M9');

      expect(find.text('초대 코드 입력'), findsOneWidget);
      expect(find.text('라우터가 받았다'), findsNothing);
      expect(inbox.hasPending, isFalse); // 입력 화면이 열리면서 꺼냈다

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('보호자 홈'), findsOneWidget);
    });

    testWidgets('다른 화면을 쌓아 둔 채 링크가 와도 그 화면과 아래 스택이 그대로다', (tester) async {
      await pump(tester);
      router.push(Routes.routineInput);
      await tester.pumpAndSettle();
      expect(find.text('일과 만들기'), findsOneWidget);

      await pushFromOs(tester, 'elum://invite?code=A7K3M9');

      // 하던 일을 끊지 않고, 입력 화면도 얹지 않는다
      expect(find.text('일과 만들기'), findsOneWidget);
      expect(find.text('초대 코드 입력'), findsNothing);
      expect(find.text('라우터가 받았다'), findsNothing);
      expect(inbox.hasPending, isTrue);

      // 일과 만들기를 마치고 홈으로 돌아오면 그때 열린다
      router.go(Routes.guardian);
      await tester.pumpAndSettle();
      expect(find.text('초대 코드 입력'), findsOneWidget);
    });

    testWidgets('설정 하위 화면(홈 위에 쌓은 화면) 위에도 얹지 않는다', (tester) async {
      await pump(tester);
      router.push(Routes.guardianSettings);
      await tester.pumpAndSettle();

      await pushFromOs(tester, 'elum://invite?code=A7K3M9');

      expect(find.text('설정'), findsOneWidget);
      expect(find.text('초대 코드 입력'), findsNothing);
    });

    testWidgets('초대 링크가 아닌 주소는 라우터가 받는다 — 소셜 로그인 콜백 등을 가로채지 않는다', (tester) async {
      await pump(tester);

      await pushFromOs(tester, '/somewhere-else');

      expect(find.text('라우터가 받았다'), findsOneWidget);
      expect(inbox.hasPending, isFalse);
    });

    testWidgets('이룸이 휴대폰에서는 라우터에도 넘기지 않고 조용히 삼킨다', (tester) async {
      await pump(tester);
      elumi = true;

      await pushFromOs(tester, 'elum://invite?code=A7K3M9');

      expect(find.text('보호자 홈'), findsOneWidget);
      expect(find.text('초대 코드 입력'), findsNothing);
      expect(find.text('라우터가 받았다'), findsNothing);
      expect(inbox.hasPending, isFalse);
    });

    testWidgets('로그인 전에 받은 링크는 로그인 뒤 홈에 닿으면 연다', (tester) async {
      await pump(tester);
      router.go(Routes.guardianSettings);
      await tester.pumpAndSettle();
      session = false;

      await pushFromOs(tester, 'elum://invite?code=A7K3M9');
      expect(find.text('초대 코드 입력'), findsNothing);

      session = true;
      router.go(Routes.guardian);
      await tester.pumpAndSettle();
      expect(find.text('초대 코드 입력'), findsOneWidget);
    });

    testWidgets('같은 링크를 연달아 눌러도 입력 화면이 두 겹 쌓이지 않는다', (tester) async {
      await pump(tester);

      await pushFromOs(tester, 'elum://invite?code=A7K3M9');
      // 입력 화면이 이미 열려 있다 — 새로 얹지 않는다 (채우는 일은 그 화면이 우편함을 듣고 한다)
      await pushFromOs(tester, 'elum://invite?code=A7K3M9');

      expect(find.text('초대 코드 입력', skipOffstage: false), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      // 한 겹만 쌓였으니 한 번 뒤로 가면 홈이다
      expect(find.text('보호자 홈'), findsOneWidget);
    });
  });
}
