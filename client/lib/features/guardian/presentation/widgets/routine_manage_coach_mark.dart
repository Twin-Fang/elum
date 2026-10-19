import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/coach_mark_overlay.dart';
import '../../../../core/widgets/coach_mark_step.dart';
import '../../application/library_entries.dart';
import '../../application/routine_manage_coach_notifier.dart';
import 'coach_demo_layers.dart';

/// 일과관리 코치마크: 언제 띄울지와 단계를 칸·글·시범에 연결한다 (설계 #832)
///
/// 가리킬 칸은 화면이 [GlobalKey] 로 넘겨준다. 목록이 도착한 뒤 맨 앞에서 잠시 가만히 있을 때만 켠다.
class RoutineManageCoachMark extends ConsumerStatefulWidget {
  const RoutineManageCoachMark({
    super.key,
    required this.entries,
    required this.firstRoutineTileKey,
    required this.secondRoutineTileKey,
    required this.createButtonKey,
  });

  /// 받아 온 격자 항목. 불러오는 중·실패면 null (가리킬 칸이 있는지 모른다)
  final List<LibraryEntry>? entries;

  /// 낱개 일과 칸의 첫째 · 둘째, `+ 일과 만들기` 버튼
  final GlobalKey firstRoutineTileKey;
  final GlobalKey secondRoutineTileKey;
  final GlobalKey createButtonKey;

  @override
  ConsumerState<RoutineManageCoachMark> createState() =>
      _RoutineManageCoachMarkState();
}

class _RoutineManageCoachMarkState
    extends ConsumerState<RoutineManageCoachMark> {
  /// 맨 앞에서 이만큼 가만히 있어야 켠다 (홈 코치마크와 같다)
  static const _settleFor = Duration(milliseconds: 1200);

  /// 다시 보기는 사용자가 방금 눌러서 온 것이라 오래 기다리게 하지 않는다
  static const _replaySettleFor = Duration(milliseconds: 300);
  static const _retryEvery = Duration(milliseconds: 500);
  static const _maxRetries = 60;

  Timer? _settle;
  Timer? _retry;
  int _retries = 0;
  bool _isWaitingRoute = false;

  /// 사라지는 연출이 끝날 때까지 직전 단계 목록을 들고 있는다
  List<RoutineManageCoachStep>? _retained;
  int _retainedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  @override
  void didUpdateWidget(covariant RoutineManageCoachMark old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  @override
  void dispose() {
    _settle?.cancel();
    _retry?.cancel();
    super.dispose();
  }

  /// 코치마크를 띄워도 되는 때인지 보고, 맞으면 켠다.
  ///
  /// 조건 3개: 목록을 받아 옴, 이 화면이 맨 앞이고 전환이 끝남, 그 상태로 [_settleFor] 유지.
  void _maybeStart() {
    if (!mounted || widget.entries == null) return;

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _settle?.cancel();
      _settle = null;
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
        _maybeStart();
      }

      animation.addStatusListener(onStatus);
      return;
    }
    if (_settle?.isActive ?? false) return;
    final isReplay = ref.read(routineManageCoachProvider).isReplayRequested;
    _settle = Timer(isReplay ? _replaySettleFor : _settleFor, _startNow);
  }

  void _retryLater() {
    if (_retry?.isActive ?? false) return;
    if (_retries++ >= _maxRetries) return;
    _retry = Timer(_retryEvery, _maybeStart);
  }

  void _startNow() {
    _settle = null;
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _retryLater();
      return;
    }
    // 기다리는 사이 목록이 바뀌었을 수 있어 지금 값으로 다시 센다
    final entries = widget.entries;
    if (entries == null) return;
    final notifier = ref.read(routineManageCoachProvider.notifier);
    final routineCount = _routineCountOf(entries);
    final groupCount = entries.whereType<LibraryGroupEntry>().length;
    if (ref.read(routineManageCoachProvider).isReplayRequested) {
      notifier.replay(routineCount: routineCount, groupCount: groupCount);
      return;
    }
    notifier.maybeStart(
      routineCount: routineCount,
      groupCount: groupCount,
      hasFirstRoutineTile: entries.any((entry) => entry is LibraryRoutineEntry),
    );
  }

  /// 묶음 안 일과까지 센 일과 수
  int _routineCountOf(List<LibraryEntry> entries) => entries.fold(
    0,
    (count, entry) => switch (entry) {
      LibraryRoutineEntry() => count + 1,
      LibraryGroupEntry(:final routines) => count + routines.length,
    },
  );

  /// 보낸 뒤 시범에 쓸 일과 이름: 첫 낱개 칸의 이름
  String _firstRoutineTitle() {
    final entry = widget.entries?.whereType<LibraryRoutineEntry>().firstOrNull;
    return entry?.routine.displayTitle ?? '';
  }

  CoachMarkStep _stepFor(RoutineManageCoachStep step, BuildContext context) {
    final l10n = context.l10n;
    final tileRadius = context.space.md;
    switch (step) {
      case RoutineManageCoachStep.tapRoutine:
        return CoachMarkStep(
          target: widget.firstRoutineTileKey,
          message: l10n.routineManageCoachTapMessage,
          holeRadius: tileRadius,
          demoBuilder: tapDemo,
        );
      case RoutineManageCoachStep.longPressRoutine:
        return CoachMarkStep(
          target: widget.firstRoutineTileKey,
          message: l10n.routineManageCoachLongPressMessage,
          holeRadius: tileRadius,
          demoBuilder: longPressDemo,
        );
      case RoutineManageCoachStep.sentBadge:
        final title = _firstRoutineTitle();
        return CoachMarkStep(
          target: widget.firstRoutineTileKey,
          message: l10n.routineManageCoachSentMessage,
          holeRadius: tileRadius,
          demoBuilder: (context, rect) =>
              sentBadgeDemo(context, rect, routineTitle: title),
        );
      case RoutineManageCoachStep.dragToGroup:
        return CoachMarkStep(
          target: widget.firstRoutineTileKey,
          message: l10n.routineManageCoachDragMessage,
          holeRadius: tileRadius,
          demoBuilder: (context, firstRect) =>
              dragToGroupDemo(context, firstRect, _secondTileRect(firstRect)),
        );
      case RoutineManageCoachStep.createGroup:
        return CoachMarkStep(
          target: widget.createButtonKey,
          message: l10n.routineManageCoachCreateGroupMessage,
          holeRadius: tileRadius,
          demoBuilder: createGroupDemo,
        );
    }
  }

  /// 둘째 칸 상자 (오버레이 좌표). 못 재면 첫 칸 오른쪽 옆으로 본다
  Rect _secondTileRect(Rect firstRect) {
    final overlayBox = context.findRenderObject();
    final box = widget.secondRoutineTileKey.currentContext?.findRenderObject();
    if (overlayBox is RenderBox && box is RenderBox && box.attached) {
      final origin = box.localToGlobal(Offset.zero, ancestor: overlayBox);
      return origin & box.size;
    }
    return firstRect.shift(Offset(firstRect.width, 0));
  }

  @override
  Widget build(BuildContext context) {
    // 내정보에서 다시 보기를 눌러 이미 떠 있는 이 화면으로 돌아온 경우
    ref.listen(
      routineManageCoachProvider.select((state) => state.isReplayRequested),
      (_, isRequested) {
        if (isRequested) _maybeStart();
      },
    );
    final state = ref.watch(routineManageCoachProvider);
    if (state.isActive) {
      _retained = state.steps;
      _retainedIndex = state.index;
    }
    final steps = _retained;
    if (steps == null) return const SizedBox.shrink();

    final notifier = ref.read(routineManageCoachProvider.notifier);
    return CoachMarkOverlay(
      steps: [for (final step in steps) _stepFor(step, context)],
      index: state.isActive ? state.index : _retainedIndex,
      visible: state.isActive,
      onNext: notifier.next,
      onClose: notifier.finish,
      onDismissed: () {
        if (mounted) setState(() => _retained = null);
      },
    );
  }
}
