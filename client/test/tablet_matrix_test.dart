import 'package:elum/core/layout/adaptive_page_frame.dart';
import 'package:elum/core/layout/screen_layout_kind.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/child/presentation/reward_screen.dart';
import 'package:elum/features/child/presentation/routine_done_screen.dart';
import 'package:elum/features/child/presentation/widgets/child_night_sky_backdrop.dart';
import 'package:elum/features/child/presentation/child_stars_screen.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/guardian/presentation/routine_input_screen.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/adaptive_test_app.dart';
import 'helpers/fake_dio.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';

/// 태블릿·분할 창 크기 × 글자 배율에서 화면이 깨지지 않는다.
///
/// 오버플로·예외는 `flutter_test_config.dart` 가 자동으로 실패시키므로 렌더가 통과하면 버틴 것이다.
/// 깨지면: 아이패드·안드로이드 태블릿(가로·세로)이나 분할 보기에서 화면이 잘리거나 빨간 줄이 뜬다.
/// 화면은 P2~P4 에서 적응형으로 올릴 때마다 아래 목록에 더한다.
void main() {
  /// 화면비가 가장 다른 창을 고른다 (회전·분할 포함)
  const windows = <String, Size>{
    '폰 (393×852)': Size(393, 852),
    '아이패드 mini 세로': Size(744, 1133),
    '아이패드 mini 가로': Size(1133, 744),
    '아이패드 11 세로': Size(820, 1180),
    '아이패드 11 가로': Size(1180, 820),
    '아이패드 13 세로': Size(1024, 1366),
    '아이패드 13 가로': Size(1366, 1024),
    '안드로이드 10 세로': Size(800, 1280),
    '안드로이드 10 가로': Size(1280, 800),
    '안드로이드 8 세로': Size(600, 960),
    '안드로이드 8 가로': Size(960, 600),
    '분할 보기 좁음': Size(320, 1024),
    '분할 보기 낮음': Size(1024, 320),
  };

  const textScales = [1.0, 2.0];

  Routine routine(String id, String title, {int percent = 0}) => Routine(
    id: id,
    title: title,
    status: 'CONFIRMED',
    rewardText: '유튜브 시청 20분',
    progressPercent: percent,
    steps: const [
      ActionCard(id: 'c1', stepOrder: 1, description: '첫 단계'),
      ActionCard(id: 'c2', stepOrder: 2, description: '둘째 단계'),
    ],
  );

  Widget screenApp(
    Widget screen,
    double textScale, {
    ScreenLayoutKind kind = ScreenLayoutKind.phoneColumn,
    Widget? backdrop,
  }) => ProviderScope(
    overrides: [
      offlineDioOverride(),
      speechServiceProvider.overrideWithValue(_SilentSpeech()),
      testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
      routineRepositoryProvider.overrideWithValue(_StubRepo()),
      myRoutinesProvider.overrideWith(
        (ref) async => [
          routine('r1', '스스로 옷을 입어요', percent: 50),
          routine('r2', '밥 먹기 전에 손을 씻어요', percent: 100),
        ],
      ),
      todayRoutinesProvider.overrideWith(
        (ref) async => [routine('r1', '스스로 옷을 입어요', percent: 50)],
      ),
      pastRoutinesProvider.overrideWith(
        (ref) async => [routine('p1', '학교에 갈 준비를 해요', percent: 100)],
      ),
      memberProvider.overrideWith(
        (ref) async => Member(nickname: '하늘이', totalStars: 15),
      ),
    ],
    child: adaptiveTestApp(
      textScale: textScale,
      // 라우터가 하는 일과 같이 화면이 선언한 종류로 감싼다
      home: AdaptivePageFrame(kind: kind, backdrop: backdrop, child: screen),
    ),
  );

  void runOnAllWindows(
    String name,
    Widget Function() build, {
    ScreenLayoutKind kind = ScreenLayoutKind.phoneColumn,
    Widget? backdrop,
    List<double> scales = textScales,
  }) {
    for (final window in windows.entries) {
      for (final textScale in scales) {
        testWidgets('$name · ${window.key} · 글자 x$textScale', (tester) async {
          setTestWindowSize(tester, window.value);

          await tester.pumpWidget(
            screenApp(build(), textScale, kind: kind, backdrop: backdrop),
          );
          // 오로라·별처럼 끝나지 않는 움직임이 있어 settle 을 기다리지 않는다
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  runOnAllWindows('보호자 홈', () => const GuardianHomeScreen());
  runOnAllWindows(
    '별 모으기',
    () => const ChildStarsScreen(),
    backdrop: const ChildNightSkyBackdrop(),
  );
  runOnAllWindows('일과 만들기 입력', () => const RoutineInputScreen());

  // 이룸이 화면 (태블릿 주 사용자)
  runOnAllWindows(
    '이룸이 홈',
    () => const ChildHomeScreen(),
    kind: ScreenLayoutKind.adaptive,
  );
  runOnAllWindows(
    '이룸이 카드 상세',
    () => ChildRoutineDetailScreen(routine: _detailRoutine),
    kind: ScreenLayoutKind.adaptive,
  );
  runOnAllWindows(
    '일과 완료',
    () => const RoutineDoneScreen(reward: (emoji: '🍪', text: '젤리 먹기')),
    backdrop: const ChildNightSkyBackdrop(sky: ChildNightSky.routineDone),
    // 시안 좌표로 고정한 화면이라 폰(393x852)에서도 글자 2배는 넘친다 (기존 한계, 태블릿 문제가 아님)
    scales: const [1.0],
  );
  runOnAllWindows(
    '카드 보상',
    () => const RewardScreen(reward: (emoji: '🍪', text: '젤리 먹기')),
    backdrop: const ChildNightSkyBackdrop(),
    // 일과 완료와 같은 이유: 시안 좌표 고정 화면의 글자 2배 한계
    scales: const [1.0],
  );
}

/// 서버를 타지 않는 저장소. 이 테스트는 레이아웃만 본다.
class _StubRepo with FakeRewardApi implements RoutineRepository {
  @override
  Future<List<Routine>> getMyRoutines() async => const [];

  @override
  Future<List<Routine>> getTodayRoutines() async => const [];

  @override
  Future<List<Routine>> getPastRoutines() async => const [];

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 카드 상세 매트릭스용 일과 (id 를 local 로 둔다: 서버 동기화를 타지 않는다)
const _detailRoutine = Routine(
  id: 'local',
  title: '아침에 학교 갈 준비',
  status: 'CONFIRMED',
  rewardText: '젤리 먹기',
  steps: [
    ActionCard(
      id: 'c1',
      stepOrder: 1,
      title: '세수해요',
      description: '물로 얼굴을 씻어요',
    ),
    ActionCard(
      id: 'c2',
      stepOrder: 2,
      title: '옷을 입어요',
      description: '옷을 차례대로 입어요',
    ),
    ActionCard(
      id: 'c3',
      stepOrder: 3,
      title: '신발을 신어요',
      description: '현관에서 신발을 신어요',
    ),
  ],
);

class _SilentSpeech implements SpeechService {
  @override
  Future<bool> speak(
    String text, {
    String language = 'ko',
    StoredSpeechSource? stored,
  }) async => true;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
