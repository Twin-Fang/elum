import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/coach_mark_overlay.dart';
import '../../../../core/widgets/coach_mark_step.dart';
import '../../application/library_coach_notifier.dart';
import 'library_routine_tile.dart';

/// 일과관리 코치마크 (#834): 처음 한 번, 일과 칸 > `+ 일과 만들기` 순서로 가리킨다
///
/// 어떤 단계를 보여줄지는 [libraryCoachProvider] 가 정하고, 여기서는 단계를 글과 대상 위젯에 잇는다.
class LibraryCoachMark extends ConsumerStatefulWidget {
  const LibraryCoachMark({
    super.key,
    required this.tileKey,
    required this.createKey,
  });

  /// 첫 일과 칸
  final GlobalKey tileKey;

  /// `+ 일과 만들기` 버튼
  final GlobalKey createKey;

  @override
  ConsumerState<LibraryCoachMark> createState() => _LibraryCoachMarkState();
}

class _LibraryCoachMarkState extends ConsumerState<LibraryCoachMark> {
  /// 사라지는 연출이 끝날 때까지 직전 단계 목록을 들고 있는다
  List<LibraryCoachStep>? _retained;
  int _retainedIndex = 0;

  /// 버튼 높이 54의 절반 — 알약
  static const _pillRadius = 27.0;

  CoachMarkStep _stepFor(LibraryCoachStep step, BuildContext context) {
    switch (step) {
      case LibraryCoachStep.openMenu:
        return CoachMarkStep(
          target: widget.tileKey,
          message: context.l10n.libraryCoachMenu,
          holeRadius: LibraryRoutineTile.iconRadius.w,
          holePadding: EdgeInsets.all(6.w),
        );
      case LibraryCoachStep.createGroup:
        return CoachMarkStep(
          target: widget.createKey,
          message: context.l10n.libraryCoachCreate,
          holeRadius: _pillRadius.h,
          feather: 8.w,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryCoachProvider);
    if (state.isActive) {
      _retained = state.steps;
      _retainedIndex = state.index;
    }
    final steps = _retained;
    if (steps == null) return const SizedBox.shrink();

    final notifier = ref.read(libraryCoachProvider.notifier);
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
