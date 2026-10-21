import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/routine_manage_coach_notifier.dart';
import 'coach_mark_start_gate.dart';
import 'routine_manage_coach_stage.dart';

/// 일과관리 코치마크 트리거: 이 칸이 보이는 순간 안내 무대를 띄운다 (#861)
///
/// 화면에는 아무것도 그리지 않는다. 안내는 루트 위 전체 화면 안내 무대가 맡아 하단 바까지 터치를 막는다.
class RoutineManageCoachTrigger extends ConsumerStatefulWidget {
  const RoutineManageCoachTrigger({super.key});

  @override
  ConsumerState<RoutineManageCoachTrigger> createState() =>
      _RoutineManageCoachTriggerState();
}

class _RoutineManageCoachTriggerState
    extends ConsumerState<RoutineManageCoachTrigger>
    with CoachMarkStartGate<RoutineManageCoachTrigger> {
  /// 안내 무대를 띄운 상태인가 (같은 무대를 두 번 띄우지 않게)
  bool _isStageOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpen());
  }

  /// 탭 화면은 안 보이는 동안에도 살아 있다. 이 칸이 보이게 되는 순간(TickerMode 변화) 다시 따진다
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpen());
  }

  /// 띄울 때인지 보고 맞으면 바로 띄운다
  ///
  /// 조건: 이 칸이 보이는 탭 + [CoachMarkStartGate] (화면 맨 앞, 전환 끝, 추적 허용 팝업 끝)
  void _maybeOpen() {
    if (!mounted || _isStageOpen || !TickerMode.of(context)) return;
    checkCoachMarkStart();
  }

  @override
  void onCoachMarkStartReady() {
    // 기다리는 사이 탭이 바뀌었거나 무대가 열렸을 수 있다
    if (_isStageOpen || !TickerMode.of(context)) return;
    final notifier = ref.read(routineManageCoachProvider.notifier);
    if (ref.read(routineManageCoachProvider).isReplayRequested) {
      notifier.replay();
    } else if (!notifier.maybeStart()) {
      return;
    }
    _openStage();
  }

  Future<void> _openStage() async {
    _isStageOpen = true;
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(RoutineManageCoachStage.route());
    // 무대를 닫는 길이 무엇이든(✕ · 뒤로가기 · 마지막 단계) 본 것으로 남긴다
    await ref.read(routineManageCoachProvider.notifier).finish();
    if (mounted) _isStageOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    // 내정보에서 다시 보기를 눌러 이미 떠 있는 이 칸으로 돌아온 경우
    ref.listen(
      routineManageCoachProvider.select((state) => state.isReplayRequested),
      (_, isRequested) {
        if (isRequested) _maybeOpen();
      },
    );
    return const SizedBox.shrink();
  }
}
