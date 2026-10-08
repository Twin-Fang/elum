import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/child/presentation/child_stars_screen.dart';
import 'package:elum/features/child/presentation/mode_switch_screen.dart';
import 'package:elum/features/child/presentation/routine_done_screen.dart';
import 'package:elum/features/child/presentation/widgets/reward_banner.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';
import '../helpers/test_storage.dart';
import 'package:elum/features/member/application/member_providers.dart';

/// 이룸이 화면이 앱 문구를 ARB 에서 읽는지 정확한 문자열로 확인한다.
/// 시험마다 새 상태를 만든다 — 선언 순서나 앞 시험의 값에 기대지 않는다.
void main() {
  useFigmaViewport();
  // 비 ko 로 띄운 시험이 전역 `appL10n` 을 남기지 않게 되돌린다
  tearDown(setAppL10nForTest);

  const cards = [
    ActionCard(id: 'c1', title: '옷을 입어요', description: '옷을 입어요', stepOrder: 1),
    ActionCard(
      id: 'c2',
      title: '우산을 챙겨요',
      description: '우산을 챙겨요',
      stepOrder: 2,
    ),
  ];
  const routine = Routine(
    id: 'r1',
    title: '학교 가기',
    status: 'CONFIRMED',
    steps: cards,
    rewardText: '젤리 먹기',
    rewardPresetKey: 'SNACK',
  );

  Widget scope(
    Widget screen, {
    Member? member,
    bool elumiDevice = false,
    String? pin,
    List<Routine> today = const [],
    LocalStorage? storage,
    SpeechService? speech,
  }) {
    return ProviderScope(
      overrides: [
        if (storage != null)
          localStorageProvider.overrideWithValue(storage)
        else
          testStorageOverride(
            onboardingCompleted: true,
            elumiDevice: elumiDevice,
            pin: pin,
          ),
        if (speech != null) speechServiceProvider.overrideWithValue(speech),
        myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        todayRoutinesProvider.overrideWith((ref) async => today),
        memberProvider.overrideWith((ref) async => member),
      ],
      child: screen,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Member? member,
    bool elumiDevice = false,
    String? pin,
    List<Routine> today = const [],
    Locale locale = const Locale('ko'),
    LocalStorage? storage,
    SpeechService? speech,
  }) async {
    await pumpWithLocale(
      tester,
      screen,
      locale: locale,
      wrap: (app) => scope(
        app,
        member: member,
        elumiDevice: elumiDevice,
        pin: pin,
        today: today,
        storage: storage,
        speech: speech,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('이룸이 홈', () {
    // 값마다 새 시험·새 상태로 띄운다(같은 트리를 다시 띄우면 앞 값이 남는다)
    for (final c in [
      (
        name: '민준',
        stars: 7,
        greeting: '오늘 민준이\n할 일들이에요. 힘내봐요!',
        label: '별 7개 모았어요',
      ),
      (
        name: '루미',
        stars: 12,
        greeting: '오늘 루미가\n할 일들이에요. 힘내봐요!',
        label: '별 12개 모았어요',
      ),
    ]) {
      testWidgets('인사말·별·보상 접두어·보호자 이름 — ${c.name}', (tester) async {
        final handle = tester.ensureSemantics();
        await pump(
          tester,
          const ChildHomeScreen(),
          member: Member(nickname: c.name, totalStars: c.stars),
          today: const [routine],
        );
        expect(find.text(c.greeting), findsOneWidget);
        expect(find.bySemanticsLabel(c.label), findsOneWidget);
        expect(find.bySemanticsLabel('보호자 화면으로 가기'), findsOneWidget);
        expect(find.text('다하면'), findsOneWidget);
        handle.dispose();
      });
    }

    testWidgets('이룸이 휴대폰은 톱니 이름, 빈 상태 제목과 안내', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const ChildHomeScreen(),
        member: const Member(nickname: '하늘'),
        elumiDevice: true,
      );
      expect(find.bySemanticsLabel('설정 열기'), findsOneWidget);
      expect(find.text('아직 하늘의\n일과가 없어요'), findsOneWidget);
      expect(find.text('보호자 휴대폰에서 일과를 만들 수 있어요'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('보호자 휴대폰의 빈 상태 안내', (tester) async {
      await pump(
        tester,
        const ChildHomeScreen(),
        member: const Member(nickname: '루미'),
      );
      expect(find.text('아직 루미의\n일과가 없어요'), findsOneWidget);
      expect(find.text('보호자 화면에서 일과를 만들 수 있어요'), findsOneWidget);
    });

    testWidgets('비 ko 언어는 번역 전이라 ko 문구로 떨어진다', (tester) async {
      await pump(
        tester,
        const ChildHomeScreen(),
        member: const Member(nickname: '민준'),
        locale: const Locale('en'),
      );
      expect(find.text('아직 민준의\n일과가 없어요'), findsOneWidget);
    });
  });

  for (final c in [
    (stars: 7, text: '7개의 별을 얻었어요\n할 일을 해내고 별을 더 찾아봐요!'),
    (stars: 120, text: '120개의 별을 얻었어요\n할 일을 해내고 별을 더 찾아봐요!'),
  ]) {
    testWidgets('별 화면 — ${c.stars}개', (tester) async {
      await pump(
        tester,
        const ChildStarsScreen(),
        member: Member(totalStars: c.stars),
      );
      expect(find.text(c.text), findsOneWidget);
    });
  }

  testWidgets('카드 상세 — 체크 버튼 이름과 카드 위치 낭독', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const ChildRoutineDetailScreen(routine: routine));
    expect(find.bySemanticsLabel('다 했어요'), findsOneWidget);
    expect(find.bySemanticsLabel('카드 2장 중 1번째'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('카드 상세 — 소리를 못 내면 실패 팝업 문구와 에러 코드', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      const ChildRoutineDetailScreen(routine: routine),
      speech: _FailingSpeech(),
    );
    await tester.tap(find.bySemanticsLabel('소리로 듣기').first);
    await tester.pumpAndSettle();
    expect(find.text('소리를 재생하지 못했어요.\n휴대폰 소리를 켜고 다시 눌러주세요'), findsOneWidget);
    expect(find.text('E-TTS'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('보상 칩 — 다하면 접두어는 한 칸 띄운다', (tester) async {
    await pump(tester, Scaffold(body: RewardBanner.maybe(routine)));
    expect(find.text('다하면 🍪 젤리 먹기'), findsOneWidget);
  });

  testWidgets('일과 완료 화면 — 제목과 버튼', (tester) async {
    await pump(tester, const RoutineDoneScreen());
    expect(find.text('일과를 끝냈어요!'), findsOneWidget);
    expect(find.text('오예!'), findsOneWidget);
  });

  group('화면 전환', () {
    testWidgets('이룸이 화면으로 — 제목·안내·점 이름', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const ModeSwitchScreen(target: ModeSwitchTarget.child),
        pin: '1234',
      );
      expect(find.text('비밀암호를 입력하세요'), findsOneWidget);
      expect(find.text('암호를 입력하면 이룸이 화면으로 바뀌어요'), findsOneWidget);
      expect(find.bySemanticsLabel('암호 넣기'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('보호자 화면으로 — 안내, 틀리면 실패 안내', (tester) async {
      await pump(
        tester,
        const ModeSwitchScreen(target: ModeSwitchTarget.guardian),
        pin: '1234',
      );
      expect(find.text('암호를 입력하면 보호자 화면으로 바뀌어요'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '0000');
      await tester.pumpAndSettle();
      expect(find.text('암호가 달라요. 다시 넣어주세요'), findsOneWidget);
      expect(find.text('암호를 입력하면 보호자 화면으로 바뀌어요'), findsNothing);
    });

    testWidgets('암호를 읽지 못하면 실패 팝업 문구와 에러 코드', (tester) async {
      await pump(
        tester,
        const ModeSwitchScreen(target: ModeSwitchTarget.guardian),
        storage: _UnreadablePinStorage(),
      );
      expect(find.text('암호를 확인하지 못했어요.\n잠시 후 다시 해주세요'), findsOneWidget);
      expect(find.text('E-PIN-READ'), findsOneWidget);
    });

    testWidgets('암호 없는 이룸이 휴대폰은 보호자 화면이 막힌다', (tester) async {
      await pump(
        tester,
        const ModeSwitchScreen(target: ModeSwitchTarget.guardian),
        elumiDevice: true,
      );
      expect(find.text('보호자 휴대폰에서\n열어 주세요'), findsOneWidget);
      expect(find.text('이 휴대폰에서는 보호자 화면을 열 수 없어요'), findsOneWidget);
      expect(find.text('돌아가기'), findsOneWidget);
    });
  });
}

/// 소리를 못 내는 읽기 엔진.
class _FailingSpeech implements SpeechService {
  @override
  Future<bool> speak(String text, {String language = 'ko'}) async => false;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

/// 암호 읽기에서 예외가 나는 저장소.
class _UnreadablePinStorage extends InMemoryStorage {
  _UnreadablePinStorage() : super(onboardingCompleted: true);

  @override
  Future<bool> hasPin() async => throw StateError('읽기 실패');
}
