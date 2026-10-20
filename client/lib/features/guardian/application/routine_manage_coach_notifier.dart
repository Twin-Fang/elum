import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';

/// 일과관리 코치마크가 가리키는 순서 (기본 3단계 + 묶음 2단계)
enum RoutineManageCoachStep {
  /// 일과 칸 누르기 > 상세 시트
  tapRoutine,

  /// 일과 칸 길게 누르기 > 빠른 메뉴
  longPressRoutine,

  /// 오늘 보낸 칸의 ✓ 배지
  sentBadge,

  /// 일과를 끌어 다른 일과 위에 놓아 묶기
  dragToGroup,

  /// `+ 일과 만들기` > 새 묶음 만들기
  createGroup,
}

/// 기본 단계 묶음 / 묶음 단계 묶음 — "봤음"도 이 단위로 따로 남긴다
const _basicSteps = [
  RoutineManageCoachStep.tapRoutine,
  RoutineManageCoachStep.longPressRoutine,
  RoutineManageCoachStep.sentBadge,
];
const _groupSteps = [
  RoutineManageCoachStep.dragToGroup,
  RoutineManageCoachStep.createGroup,
];

/// 코치마크 진행 상태. [steps]가 비어 있으면 꺼진 상태다.
class RoutineManageCoachState {
  const RoutineManageCoachState({
    this.steps = const [],
    this.index = 0,
    this.isReplayRequested = false,
  });

  final List<RoutineManageCoachStep> steps;
  final int index;

  /// 다시 보기를 요청받았고 아직 켜지 않았는가 (일과관리 화면이 아직 없을 때도 요청은 남는다)
  final bool isReplayRequested;

  bool get isActive => steps.isNotEmpty;

  RoutineManageCoachStep? get current => isActive ? steps[index] : null;
}

final routineManageCoachProvider =
    NotifierProvider<RoutineManageCoachNotifier, RoutineManageCoachState>(
      RoutineManageCoachNotifier.new,
    );

/// 일과관리 코치마크의 시작 조건과 진행을 맡는다. 규칙은 홈 코치마크와 같다.
///
/// **한 번 본 것은 기기에 남긴다.** 끝까지 봐도, 건너뛰어도, 닫아도 같다.
class RoutineManageCoachNotifier extends Notifier<RoutineManageCoachState> {
  /// 이번 실행에서 이미 띄웠는가. 저장에 실패해도 같은 실행에서 두 번 뜨지 않는다.
  bool _hasShownThisRun = false;

  @override
  RoutineManageCoachState build() {
    // invalidate 는 Notifier 를 새로 만들지 않고 build 만 다시 부른다 — 필드도 함께 되돌린다
    _hasShownThisRun = false;
    return const RoutineManageCoachState();
  }

  /// 읽지 못하면 **봤다고 친다.** 못 읽는 저장소에서 매번 뜨는 안내는 닫을 방법 없는 반복이다.
  bool _isSeen(bool Function(LocalStorage storage) read) {
    try {
      return read(ref.read(localStorageProvider));
    } catch (e) {
      AppLogger.error('RoutineManageCoach.read', e);
      return true;
    }
  }

  /// 안 본 단계가 있으면 켠다 (켰으면 true). 연습 무대의 예시 일과로 보여 주므로 실제 일과 수와 무관하다
  bool maybeStart() {
    if (state.isActive || _hasShownThisRun) return false;
    final steps = [
      if (!_isSeen((storage) => storage.isManageCoachSeen)) ..._basicSteps,
      if (!_isSeen((storage) => storage.isGroupCoachSeen)) ..._groupSteps,
    ];
    if (steps.isEmpty) return false;
    _hasShownThisRun = true;
    _turnOn(steps);
    return true;
  }

  /// 다시 보기 요청: 일과관리 칸이 보이면 [replay] 로 켠다. 내정보 설정 줄이 부른다
  void requestReplay() {
    state = RoutineManageCoachState(
      steps: state.steps,
      index: state.index,
      isReplayRequested: true,
    );
  }

  /// 다시 보기: 봤어도 다섯 단계를 모두 켠다. 봤음 기록은 바꾸지 않는다 (이미 true)
  void replay() {
    if (state.isActive) return;
    _turnOn(const [..._basicSteps, ..._groupSteps]);
  }

  void _turnOn(List<RoutineManageCoachStep> steps) {
    state = RoutineManageCoachState(steps: steps);
    AppLogger.notifierCall('RoutineManageCoachNotifier', 'start', {
      'steps': steps.length,
    });
  }

  /// 다음 단계로. 마지막이면 끝낸다.
  void next() {
    if (!state.isActive) return;
    if (state.index + 1 >= state.steps.length) {
      finish();
      return;
    }
    state = RoutineManageCoachState(steps: state.steps, index: state.index + 1);
  }

  /// 끝낸다 — 마지막까지 봤든 중간에 닫았든 보여 준 단계 묶음을 "본 것"으로 남긴다.
  Future<void> finish() async {
    if (!state.isActive) return;
    final shownSteps = state.steps;
    state = const RoutineManageCoachState();
    final storage = ref.read(localStorageProvider);
    await _remember(
      isShown: shownSteps.any(_basicSteps.contains),
      write: storage.setManageCoachSeen,
    );
    await _remember(
      isShown: shownSteps.any(_groupSteps.contains),
      write: storage.setGroupCoachSeen,
    );
  }

  /// 못 남겨도 이번 실행에서는 [_hasShownThisRun] 이 다시 뜨는 것을 막는다.
  Future<void> _remember({
    required bool isShown,
    required Future<void> Function(bool) write,
  }) async {
    if (!isShown) return;
    try {
      await write(true);
    } catch (e) {
      AppLogger.error('RoutineManageCoach.write', e);
    }
  }
}
