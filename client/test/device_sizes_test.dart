import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/child/presentation/child_stars_screen.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/guardian/presentation/routine_input_screen.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';

/// **시안은 아이폰 한 기종으로만 그려져 있다.**
///
/// 시안 대조(`figma_conformance_test.dart`)는 그 기준 기기(393×852) 하나에서만
/// 돈다. 거기서 맞는다고 다른 기기에서도 맞는 것은 아니다 — 가로가 좁으면 글자가
/// 다른 자리에서 꺾이고, 세로가 짧으면 아래가 잘린다.
///
/// 여기서는 **화면비가 다른 기기들에서 화면이 깨지지 않는지**만 본다. 시안과
/// 픽셀로 맞대지는 않는다(크기가 다르니 애초에 맞출 수 없다). 오버플로는
/// `flutter_test_config.dart`가 자동으로 실패시키므로, **렌더가 통과하는 것만으로
/// 레이아웃이 버틴다는 뜻**이 된다.
///
/// 기기를 늘릴 때는 **화면비가 가장 다른 것**을 고른다. 비슷한 것을 여러 개 넣어도
/// 같은 자리만 반복해 확인하게 된다.
void main() {
  /// 폭·높이 비가 서로 다른 넷. 아이폰과 안드로이드를 섞는다.
  const devices = <String, Size>{
    // 시안 기준 — 여기서 어긋나면 대조 테스트가 먼저 잡는다
    'iPhone 16 (393×852)': Size(393, 852),
    // 가장 좁고 짧다. 잘림이 가장 먼저 드러나는 자리
    'iPhone SE (375×667)': Size(375, 667),
    // 안드로이드에서 가장 흔한 폭
    'Galaxy (360×800)': Size(360, 800),
    // 가장 넓고 길다. 남는 자리를 어떻게 쓰는지 본다
    'Galaxy Ultra (412×915)': Size(412, 915),
  };

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

  Widget wrap(Widget home, Size size) => ProviderScope(
    overrides: [
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
    child: ScreenUtilInit(
      // designSize는 시안 크기 그대로 둔다 — 화면이 커지면 그만큼 커져야 한다.
      designSize: const Size(393, 852),
      useInheritedMediaQuery: true,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: home,
      ),
    ),
  );

  /// 화면 하나를 기기 넷에서 세워 본다.
  ///
  /// 세로가 짧은 기기에서 **키보드까지 올라오면** 본문이 더 줄어든다. 입력이 있는
  /// 화면은 그 상태도 함께 본다 — 실제로 이름·PIN 화면이 그 조건에서 깨진 적이 있다.
  void runOnAllDevices(String name, Widget Function() build) {
    for (final entry in devices.entries) {
      testWidgets('$name — ${entry.key}', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = entry.value;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(wrap(build(), entry.value));
        // 오로라·별처럼 끝나지 않는 움직임이 있어 settle 을 기다리지 않는다.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // 여기까지 왔으면 오버플로도 예외도 없었다는 뜻이다
        // (flutter_test_config.dart 가 둘 다 실패로 만든다).
        expect(tester.takeException(), isNull);
      });
    }
  }

  runOnAllDevices('보호자 홈', () => const GuardianHomeScreen());
  runOnAllDevices('이룸이 홈', () => const ChildHomeScreen());
  runOnAllDevices('별 모으기', () => const ChildStarsScreen());
  runOnAllDevices('일과 만들기 입력', () => const RoutineInputScreen());
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
