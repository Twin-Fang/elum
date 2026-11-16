import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/models/routine.dart';
import '../../link/application/linked_device_check.dart';
import 'home_routines.dart';
import 'routine_providers.dart';

/// 보호자 홈 「다음에 할 일」 5가지: 첫 날 흐름 순서 (만들기 > 보내기 > 기기 연결 > 첫 완료 기다리기) · 없음
enum HomeNextStep { makeFirstRoutine, sendFirstRoutine, linkDevice, waitFirstCompletion, none }

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
}

/// 입력 > 지금 보일 한 가지. 판매·광고는 넣지 않음 (첫날 흐름 안내만)
///
/// 첫 완료가 생기면 끝 (none). 연결 상태를 모르면 틀리게 권하지 않고 숨김
HomeNextStep resolveHomeNextStep(HomeNextStepInputs inputs) {
  if (!inputs.isRoutineListLoaded || inputs.hasCompletedRoutine) return HomeNextStep.none;
  if (!inputs.hasSentOwnRoutine) {
    return inputs.hasDraftRoutine ? HomeNextStep.sendFirstRoutine : HomeNextStep.makeFirstRoutine;
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
    ),
  );
});

/// 기기 연결 권유 닫음 여부 (기기 범위 저장, #1435)
class LinkDeviceSuggestionDismissalNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(localStorageProvider).isLinkDeviceSuggestionDismissed;

  /// 닫기(x): 화면에서 먼저 넘기고 저장
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

/// 보낸 일과 중 보호자가 만든 것 (온보딩 예시는 첫 일과로 세지 않음)
bool _isOwnSentRoutine(Routine routine) => !routine.isExample && routine.isVisibleToChild;
