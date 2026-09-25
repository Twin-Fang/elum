import 'package:dio/dio.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/link/presentation/widgets/code_boxes.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/link/presentation/link_enter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/semantics_audit.dart';

/// 연결 암호 넣기 화면 (이슈 #205 · 명세 §5-2).
///
/// **실패 경로를 정상 경로만큼 고정한다.** 이룸이(당사자)가 쓰는 화면이라
/// 틀렸을 때 무엇을 해야 하는지 화면이 말해 주지 않으면 거기서 멈춘다.
void main() {
  useFigmaViewport();

  late _FakeLink repo;

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.linkEnter,
      routes: [
        GoRoute(
          path: Routes.linkEnter,
          builder: (context, state) => const LinkEnterScreen(),
        ),
        GoRoute(
          path: Routes.child,
          builder: (context, state) => const Scaffold(body: Text('이룸이 홈')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [deviceLinkRepositoryProvider.overrideWithValue(repo)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  setUp(() => repo = _FakeLink());

  Future<void> type(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.pumpAndSettle();
  }

  testWidgets('어디서 암호를 받는지 화면이 알려준다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 이룸이 혼자 보고도 다음 행동을 알 수 있어야 한다.
    expect(find.textContaining('보호자 휴대폰에서'), findsOneWidget);
    expect(find.textContaining('설정 → 이룸이 휴대폰 연결하기'), findsOneWidget);
  });

  testWidgets('여섯 칸 자리가 연결 암호 넣기로 읽히고 넣은 글자를 알린다 (#339)', (tester) async {
    // 실제 입력칸은 투명이라 화면 낭독기에 드러나지 않는다. 칸에 보이는 글자는
    // 값으로 함께 읽혀야 무엇을 넣었는지 들을 수 있다.
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expectLabeledButton(tester, '연결 암호 넣기');
    expect(unnamedTapTargets(tester), isEmpty);

    await type(tester, 'a7k');

    expect(
      tester.getSemantics(find.bySemanticsLabel('연결 암호 넣기')),
      containsSemantics(value: 'A7K'),
    );
  });

  testWidgets('여섯 자를 채우면 확인 버튼 없이 바로 보낸다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await type(tester, 'A7K3M9');

    expect(repo.sent, ['A7K3M9']);
    expect(find.text('이룸이 홈'), findsOneWidget);
  });

  testWidgets('소문자·공백으로 쳐도 대문자로 보낸다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await type(tester, 'a7k 3m9');

    expect(repo.sent, ['A7K3M9']);
  });

  testWidgets('틀리면 입력을 비우고 무엇이 잘못됐는지 말한다', (tester) async {
    repo.outcome = RedeemOutcome.notFound;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await type(tester, 'A7K3M9');

    expect(find.text('암호가 맞지 않아요'), findsOneWidget);
    expect(find.text('이룸이 홈'), findsNothing);
    // 비우지 않으면 다시 치려고 지우는 것부터 해야 한다.
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  // 틀린 뒤 칸을 눌러도 키보드가 안 올라와 다시 칠 수 없었다 (#428, Android·iOS
  // 실측). 보낼 때 키보드를 내렸다가 실패하면 포커스만 돌아오고, 칸을 누르면
  // requestFocus 가 이미 포커스가 있어 아무 일도 안 했다.
  testWidgets('틀린 뒤 칸을 누르면 키보드를 다시 띄운다 (#428)', (tester) async {
    repo.outcome = RedeemOutcome.notFound;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await type(tester, 'A7K3M9');
    expect(find.text('암호가 맞지 않아요'), findsOneWidget);

    tester.testTextInput.log.clear();
    await tester.tap(find.bySemanticsLabel('연결 암호 넣기'));
    await tester.pumpAndSettle();

    expect(
      tester.testTextInput.log.map((call) => call.method),
      contains('TextInput.show'),
      reason: '포커스가 이미 있어도 키보드를 다시 올려야 칠 수 있다',
    );
  });

  // 이룸이가 보는 화면이다. 틀림은 흔들림으로 알리고 색으로 겁주지 않는다
  // (docs/08-design-principles.md §6 — 코드 틀림 빨간 테두리 ❌, #427 ①).
  testWidgets('틀려도 칸 테두리에 경고색을 쓰지 않는다 (#427)', (tester) async {
    repo.outcome = RedeemOutcome.notFound;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await type(tester, 'A7K3M9');

    final danger = AppTheme.light.extension<AppColors>()!.danger;
    final borders = tester
        .widgetList<Container>(find.descendant(
          of: find.byType(CodeBoxes),
          matching: find.byType(Container),
        ))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.border)
        .whereType<Border>()
        .map((b) => b.top.color)
        .toList();
    expect(borders, isNotEmpty);
    expect(borders, everyElement(isNot(danger)));
  });

  testWidgets('만료와 못 맞춤을 구분해 말한다 — 할 일이 다르다', (tester) async {
    repo.outcome = RedeemOutcome.expired;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await type(tester, 'A7K3M9');

    expect(find.textContaining('새 암호를 받아주세요'), findsOneWidget);
  });

  testWidgets('네트워크가 끊겨도 화면이 멈추지 않고 에러 코드를 보여준다', (tester) async {
    repo.outcome = RedeemOutcome.offline;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await type(tester, 'A7K3M9');

    expect(find.textContaining('E-NET'), findsOneWidget);
  });

  testWidgets('만들 수 없는 모양은 서버에 보내지 않는다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 0 은 서버가 만들지 않는 글자다. 보내 봐야 시도 횟수만 축낸다.
    await type(tester, 'A0K3M9');

    expect(repo.sent, isEmpty);
    expect(find.text('암호가 맞지 않아요'), findsOneWidget);
  });
}

class _FakeLink extends DeviceLinkRepository {
  _FakeLink()
      : super(dio: Dio(), tokens: InMemoryTokenStore(), storage: InMemoryStorage());

  final List<String> sent = [];
  RedeemOutcome outcome = RedeemOutcome.linked;

  @override
  Future<RedeemResult> redeem(String code) async {
    sent.add(code);
    return RedeemResult(outcome);
  }
}
