import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/child/presentation/mode_switch_screen.dart';
import 'package:elum/features/child/presentation/widgets/reward_banner.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';
import '../helpers/test_storage.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';

/// 이룸이 화면의 실패 안내·기기별 분기·접두 조립을 화면 단위로 확인한다.
/// 시험마다 새 상태를 만든다 — 선언 순서나 앞 시험의 값에 기대지 않는다.
void main() {
  useFigmaViewport();

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
        todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
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
    LocalStorage? storage,
    SpeechService? speech,
  }) async {
    await pumpWithLocale(
      tester,
      screen,
      wrap: (app) => scope(
        app,
        member: member,
        elumiDevice: elumiDevice,
        pin: pin,
        storage: storage,
        speech: speech,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('이룸이 홈 빈 상태', () {
    testWidgets('이룸이 휴대폰은 보호자 휴대폰에서 만들라고 안내한다', (tester) async {
      await pump(
        tester,
        const ChildHomeScreen(),
        member: const Member(nickname: '하늘'),
        elumiDevice: true,
      );
      expect(find.text('아직 하늘의\n일과가 없어요'), findsOneWidget);
      expect(find.text('보호자 휴대폰에서 일과를 만들 수 있어요'), findsOneWidget);
    });

    testWidgets('보호자 휴대폰은 보호자 화면에서 만들라고 안내한다', (tester) async {
      await pump(
        tester,
        const ChildHomeScreen(),
        member: const Member(nickname: '루미'),
      );
      expect(find.text('아직 루미의\n일과가 없어요'), findsOneWidget);
      expect(find.text('보호자 화면에서 일과를 만들 수 있어요'), findsOneWidget);
    });
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

  group('화면 전환', () {
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
