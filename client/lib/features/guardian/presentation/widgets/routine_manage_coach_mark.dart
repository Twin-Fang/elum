import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/routine_manage_coach_notifier.dart';
import 'routine_manage_coach_stage.dart';

/// 일과관리 코치마크 트리거: 이 칸이 보이는 순간 연습 무대를 띄운다 (#861)
///
/// 화면에는 아무것도 그리지 않는다. 안내는 루트 위 전체 화면 연습 무대가 맡아 하단 바까지 터치를 막는다.
class RoutineManageCoachTrigger extends ConsumerStatefulWidget {
  const RoutineManageCoachTrigger({super.key});

  @override
  ConsumerState<RoutineManageCoachTrigger> createState() =>
      _RoutineManageCoachTriggerState();
}

class _RoutineManageCoachTriggerState
    extends ConsumerState<RoutineManageCoachTrigger> {
  /// 다른 화면이 위에 있을 때 다시 볼 간격 · 최대 횟수
  static const _retryEvery = Duration(milliseconds: 500);
  static const _maxRetries = 60;

  Timer? _retry;
  int _retryCount = 0;
  bool _isWaitingRoute = false;

  /// 연습 무대를 띄운 상태인가 (같은 무대를 두 번 띄우지 않게)
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

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  /// 띄울 때인지 보고 맞으면 바로 띄운다
  ///
  /// 조건 3개: 이 칸이 보이는 탭, 이 화면이 맨 앞, 화면 전환이 끝남. 기다리는 시간은 두지 않는다.
  void _maybeOpen() {
    if (!mounted || _isStageOpen || !TickerMode.of(context)) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _retryLater();
      return;
    }
    final animation = route?.animation;
    if (animation != null && animation.status != AnimationStatus.completed) {
      if (_isWaitingRoute) return;
      _isWaitingRoute = true;
      void onStatus(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(onStatus);
        _isWaitingRoute = false;
        _maybeOpen();
      }

      animation.addStatusListener(onStatus);
      return;
    }

    final notifier = ref.read(routineManageCoachProvider.notifier);
    if (ref.read(routineManageCoachProvider).isReplayRequested) {
      notifier.replay();
    } else if (!notifier.maybeStart()) {
      return;
    }
    _openStage();
  }

  void _retryLater() {
    if (_retry?.isActive ?? false) return;
    if (_retryCount++ >= _maxRetries) return;
    _retry = Timer(_retryEvery, _maybeOpen);
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
