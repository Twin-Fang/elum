import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/models/routine.dart';
import '../../link/application/linked_device_check.dart';
import 'home_routines.dart';
import 'routine_providers.dart';

/// 보호자 홈 「다음에 할 일」 6가지: 첫 날 흐름 순서 (만들기 > 보내기 > 기기 연결 > 첫 완료 기다리기) · 하루 지나도 안 해 봄 · 없음
enum HomeNextStep { makeFirstRoutine, sendFirstRoutine, linkDevice, waitFirstCompletion, encourageFirstTry, none }

/// 보낸 뒤 이만큼 지나도 카드 체크가 없으면 첫 체험 권유 (24시간)
const firstTryEncourageDelay = Duration(hours: 24);

/// 첫 체험 권유를 닫으면 숨기는 기간 (7일)
const firstTryEncourageHiddenDuration = Duration(days: 7);

/// 「다음에 할 일」 판정 입력 (모두 서버 목록·연결 상태에서 옴)
@immutable
class HomeNextStepInputs {
  const HomeNextStepInputs({
    required this.isRoutineListLoaded,
    required this.hasSentOwnRoutine,
    required this.hasDraftRoutine,
    required this.hasCompletedRoutine,
    required this.isDeviceLinked,
    required this.isLinkDeviceSuggestionDismissed,
    this.hasSentOwnRoutineOverDelay = false,
    this.hasCheckedAnyStep = false,
    this.isFirstTryEncourageHidden = false,
  });

  /// 오늘 · 지난 목록을 둘 다 받았는가 (모르는 채로 권하지 않음)
  final bool isRoutineListLoaded;

  /// 예시가 아닌 일과를 이룸이 기기로 보낸 적 있는가 (오늘 · 지난 목록)
  final bool hasSentOwnRoutine;

  /// 이어서 만들 임시저장이 있는가
  final bool hasDraftRoutine;

  /// 이룸이가 끝낸 일과가 하나라도 있는가 (예시 포함)
  final bool hasCompletedRoutine;

  /// 기기 연결: true 붙음 · false 없음 · null 모름
  final bool? isDeviceLinked;

  /// 기기 연결 권유를 닫았는가 (닫으면 연결 없이 다음 단계로, #1435)
  final bool isLinkDeviceSuggestionDismissed;

  /// 보낸 일과 중 [firstTryEncourageDelay] 넘게 지난 것이 있는가 (일과 날짜 기준)
  final bool hasSentOwnRoutineOverDelay;

  /// 이룸이가 카드 한 장이라도 체크했는가 (예시 포함)
  final bool hasCheckedAnyStep;

  /// 첫 체험 권유를 닫고 [firstTryEncourageHiddenDuration] 이 안 지났는가
  final bool isFirstTryEncourageHidden;
}

/// 입력 > 지금 보일 한 가지. 판매·광고는 넣지 않음 (첫날 흐름 안내만)
///
/// 첫 완료가 생기면 끝 (none). 연결 상태를 모르면 틀리게 권하지 않고 숨김
/// 보내고 하루가 지나도 체크가 없으면 첫 체험 권유가 연결 권유보다 먼저 (닫으면 7일 동안 none)
HomeNextStep resolveHomeNextStep(HomeNextStepInputs inputs) {
  if (!inputs.isRoutineListLoaded || inputs.hasCompletedRoutine) return HomeNextStep.none;
  if (!inputs.hasSentOwnRoutine) {
    return inputs.hasDraftRoutine ? HomeNextStep.sendFirstRoutine : HomeNextStep.makeFirstRoutine;
  }
  if (inputs.hasSentOwnRoutineOverDelay && !inputs.hasCheckedAnyStep) {
    return inputs.isFirstTryEncourageHidden ? HomeNextStep.none : HomeNextStep.encourageFirstTry;
  }
  return switch (inputs.isDeviceLinked) {
    null => HomeNextStep.none,
    // 연결은 권유: 보호자 화면에서 이룸이 화면으로 바로 쓸 수 있어 닫으면 건너뜀
    false => inputs.isLinkDeviceSuggestionDismissed ? HomeNextStep.waitFirstCompletion : HomeNextStep.linkDevice,
    true => HomeNextStep.waitFirstCompletion,
  };
}

/// 홈 「다음에 할 일」: 목록 > 판정 입력 > [resolveHomeNextStep]
/// 임시저장 · 연결 상태는 그 단계에 닿았을 때만 조회 (첫 완료 뒤에는 요청 없음)
final homeNextStepProvider = Provider.autoDispose<HomeNextStep>((ref) {
  final todayRoutines = ref.watch(homeRoutinesProvider);
  final isTodayLoaded = ref.watch(todayRoutinesProvider).hasValue;
  final pastRoutines = ref.watch(pastRoutinesProvider).value;
  final isRoutineListLoaded = isTodayLoaded && pastRoutines != null;
  final allRoutines = [...todayRoutines, ...?pastRoutines];
  final hasCompletedRoutine = allRoutines.any((routine) => routine.isFinished);
  final hasSentOwnRoutine = allRoutines.any(_isOwnSentRoutine);
  final now = DateTime.now();
  final hasSentOwnRoutineOverDelay = allRoutines.any((routine) => _isOwnSentRoutineOverDelay(routine, now));
  final hasCheckedAnyStep = allRoutines.any((routine) => routine.hasStarted);

  final needsDraftCheck = isRoutineListLoaded && !hasCompletedRoutine && !hasSentOwnRoutine;
  final needsLinkCheck = isRoutineListLoaded && !hasCompletedRoutine && hasSentOwnRoutine;
  final hasDraftRoutine = needsDraftCheck && (ref.watch(draftRoutinesProvider).value?.isNotEmpty ?? false);
  final isDeviceLinked = needsLinkCheck ? ref.watch(hasLinkedDeviceProvider) : null;

  return resolveHomeNextStep(
    HomeNextStepInputs(
      isRoutineListLoaded: isRoutineListLoaded,
      hasSentOwnRoutine: hasSentOwnRoutine,
      hasDraftRoutine: hasDraftRoutine,
      hasCompletedRoutine: hasCompletedRoutine,
      isDeviceLinked: isDeviceLinked,
      isLinkDeviceSuggestionDismissed: ref.watch(isLinkDeviceSuggestionDismissedProvider),
      hasSentOwnRoutineOverDelay: hasSentOwnRoutineOverDelay,
      hasCheckedAnyStep: hasCheckedAnyStep,
      isFirstTryEncourageHidden: isFirstTryEncourageHiddenAt(ref.watch(firstTryEncourageDismissedAtProvider), now),
    ),
  );
});

/// 기기 연결 권유 닫음 여부 (기기 범위 저장, #1435)
class LinkDeviceSuggestionDismissalNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(localStorageProvider).isLinkDeviceSuggestionDismissed;

  /// 거절 ("이 기기에서 쓸게요"): 화면에서 먼저 넘기고 저장
  Future<void> dismiss() async {
    if (state) return;
    state = true;
    try {
      await ref.read(localStorageProvider).setLinkDeviceSuggestionDismissed(true);
    } catch (error, stack) {
      // 안내용 기록이라 저장 실패로 화면을 막지 않음 (이번 실행에서는 닫힌 채 유지)
      AppLogger.error('[home next step] link suggestion dismiss save failed', error, stack);
    }
  }
}

final isLinkDeviceSuggestionDismissedProvider = NotifierProvider<LinkDeviceSuggestionDismissalNotifier, bool>(
  LinkDeviceSuggestionDismissalNotifier.new,
);

/// 첫 체험 권유 닫은 시각 (계정 범위 저장, 없으면 null)
class FirstTryEncourageDismissalNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => ref.read(localStorageProvider).firstTryEncourageDismissedAt;

  /// 닫기 x: 화면에서 먼저 숨기고 저장
  Future<void> dismiss() async {
    final now = DateTime.now();
    state = now;
    try {
      await ref.read(localStorageProvider).setFirstTryEncourageDismissedAt(now);
    } catch (error, stack) {
      // 안내용 기록이라 저장 실패로 화면을 막지 않음 (이번 실행에서는 닫힌 채 유지)
      AppLogger.error('[home next step] first try dismiss save failed', error, stack);
    }
  }
}

final firstTryEncourageDismissedAtProvider = NotifierProvider<FirstTryEncourageDismissalNotifier, DateTime?>(
  FirstTryEncourageDismissalNotifier.new,
);

/// 닫은 시각 > 아직 숨김 기간인가
bool isFirstTryEncourageHiddenAt(DateTime? dismissedAt, DateTime now) =>
    dismissedAt != null && now.difference(dismissedAt) < firstTryEncourageHiddenDuration;

/// 보낸 일과 중 보호자가 만든 것 (온보딩 예시는 첫 일과로 세지 않음)
bool _isOwnSentRoutine(Routine routine) => !routine.isExample && routine.isVisibleToChild;

/// 보호자가 보낸 일과가 [firstTryEncourageDelay] 넘게 지났는가 (서버 보낸 시각이 없어 일과 날짜로 봄)
bool _isOwnSentRoutineOverDelay(Routine routine, DateTime now) {
  final scheduledAt = routine.scheduledAt;
  return _isOwnSentRoutine(routine) && scheduledAt != null && now.difference(scheduledAt) >= firstTryEncourageDelay;
}
