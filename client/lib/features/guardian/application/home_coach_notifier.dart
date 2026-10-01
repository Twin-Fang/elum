import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../onboarding/application/onboarding_notifier.dart';

/// 보호자 홈 코치마크가 가리키는 순서 (Figma 코치마크 섹션 1291:10801 · 이슈 #505).
enum HomeCoachStep {
  /// 새로운 일과 만들기 버튼 (코치마크_1)
  createRoutine,

  /// 오늘 일과를 왼쪽으로 밀기 (코치마크_2)
  swipeRoutine,

  /// 캐릭터 배지로 이룸이 화면 가기 (코치마크_3)
  switchMode,
}

/// 코치마크 진행 상태. [steps]가 비어 있으면 꺼진 상태다.
class HomeCoachState {
  const HomeCoachState({this.steps = const [], this.index = 0});

  final List<HomeCoachStep> steps;
  final int index;

  bool get active => steps.isNotEmpty;

  HomeCoachStep? get current => active ? steps[index] : null;

  /// 지금 일과 카드를 열어 보여 줘야 하는가. 설명만으로는 밀면 뭐가 나오는지 모른다.
  bool get demoSwipeOpen => current == HomeCoachStep.swipeRoutine;
}

final homeCoachProvider = NotifierProvider<HomeCoachNotifier, HomeCoachState>(
  HomeCoachNotifier.new,
);

/// 홈 코치마크의 시작 조건과 진행을 맡는다.
///
/// **한 번 본 것은 휴대폰에 남긴다.** 끝까지 봐도, 건너뛰어도, 닫아도 같다 —
/// 안내를 닫은 사람에게 다시 보여 주면 닫은 뜻이 사라진다.
class HomeCoachNotifier extends Notifier<HomeCoachState> {
  /// 이번 실행에서 이미 띄웠는가. 저장에 실패해도 **같은 실행에서 두 번 뜨지 않는다.**
  /// 홈은 화면을 오갈 때마다 다시 만들어지는데, 그때마다 뜨면 쓰기 실패가 곧 무한 반복이다.
  bool _shownThisRun = false;

  @override
  HomeCoachState build() => const HomeCoachState();

  /// 읽지 못하면 **봤다고 친다.** 안내는 없어도 앱이 돌지만, 못 읽는 저장소에서
  /// 매번 뜨는 안내는 닫을 방법 없는 반복이 된다.
  bool _alreadySeen() {
    try {
      return ref.read(localStorageProvider).isHomeCoachSeen;
    } catch (e) {
      AppLogger.error('HomeCoach.read', e);
      return true;
    }
  }

  /// 조건이 맞으면 코치마크를 켠다. 켰으면 true.
  ///
  /// [hasSwipeTarget] — 밀어 볼 수 있는 일과가 있는가. 없으면 2단계를 건너뛴다.
  /// 가리킬 카드가 없는데 "일과를 밀어 보라"고 하면 빈 화면을 가리키게 된다.
  bool maybeStart({required bool hasSwipeTarget}) {
    if (state.active || _shownThisRun || _alreadySeen()) return false;
    _shownThisRun = true;
    state = HomeCoachState(
      steps: [
        HomeCoachStep.createRoutine,
        if (hasSwipeTarget) HomeCoachStep.swipeRoutine,
        HomeCoachStep.switchMode,
      ],
    );
    AppLogger.notifierCall('HomeCoachNotifier', 'start', {
      'steps': state.steps.length,
    });
    return true;
  }

  /// 다음 단계로. 마지막이면 끝낸다.
  void next() {
    if (!state.active) return;
    if (state.index + 1 >= state.steps.length) {
      finish();
      return;
    }
    state = HomeCoachState(steps: state.steps, index: state.index + 1);
  }

  /// 끝낸다 — 마지막까지 봤든 중간에 닫았든 "본 것"으로 남긴다.
  Future<void> finish() async {
    if (!state.active) return;
    state = const HomeCoachState();
    try {
      await ref.read(localStorageProvider).setHomeCoachSeen(true);
    } catch (e) {
      // 못 남겨도 이번 실행에서는 [_shownThisRun] 이 다시 뜨는 것을 막는다.
      AppLogger.error('HomeCoach.write', e);
    }
  }
}
