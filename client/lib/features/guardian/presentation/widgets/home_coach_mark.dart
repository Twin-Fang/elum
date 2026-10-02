import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/character_badge.dart';
import '../../../../core/widgets/coach_mark_overlay.dart';
import '../../application/home_coach_notifier.dart';
import 'routine_swipe_actions.dart';

/// 보호자 홈 코치마크 (Figma 코치마크 1291:10801 — 코치마크_1·2·3 · 이슈 #505).
///
/// 어떤 단계를 보여줄지는 [homeCoachProvider] 가 정하고, 여기서는 그 단계를 홈의 어느
/// 위젯에 어떤 글로 연결할지만 안다. 가리킬 위젯은 홈이 [GlobalKey] 로 넘겨준다.
class HomeCoachMark extends ConsumerStatefulWidget {
  const HomeCoachMark({
    super.key,
    required this.createKey,
    required this.swipeKey,
    required this.modeKey,
  });

  /// `새로운 일과 만들기` 버튼
  final GlobalKey createKey;

  /// 오늘 일과의 밀 수 있는 첫 줄
  final GlobalKey swipeKey;

  /// 캐릭터 배지
  final GlobalKey modeKey;

  @override
  ConsumerState<HomeCoachMark> createState() => _HomeCoachMarkState();
}

class _HomeCoachMarkState extends ConsumerState<HomeCoachMark> {
  /// 사라지는 연출이 끝날 때까지 직전 단계 목록을 들고 있는다.
  /// 상태는 닫는 순간 비워지지만 막은 부드럽게 걷혀야 한다.
  List<HomeCoachStep>? _retained;
  int _retainedIndex = 0;

  /// 시안 1274:10280 — 버튼 높이 68의 절반. 알약이라 반지름이 높이의 절반이다.
  static const _pillRadius = 34.0;

  /// 시안 1291:10730 — 화살표가 배지 바닥(126)에서 3 떨어진 129 에서 시작한다.
  static const _badgeGap = 3.0;

  /// 가리키는 글과 모양 (시안 1274:10400 · 1291:10454 · 1291:10733)
  CoachMarkStep _stepFor(HomeCoachStep step, BuildContext context) {
    switch (step) {
      case HomeCoachStep.createRoutine:
        return CoachMarkStep(
          target: widget.createKey,
          message: context.l10n.homeCoachCreate,
          holeRadius: _pillRadius.h,
          // 버튼이 자기 빛(글로우)을 갖고 있다. 칼같이 오리면 그 빛이 어둡게 잘린다.
          feather: 8.w,
        );
      case HomeCoachStep.swipeRoutine:
        // 열린 줄에서 삭제·수정 두 버튼의 가운데를 가리킨다 (시안 화살표 x=305).
        final rowWidth = 1.sw - 32.w;
        final actions =
            (RoutineSwipeActions.deleteWidth +
                    RoutineSwipeActions.actionGap +
                    RoutineSwipeActions.editWidth)
                .w;
        return CoachMarkStep(
          target: widget.swipeKey,
          message: context.l10n.homeCoachSwipe,
          align: CoachMarkAlign.end,
          holeRadius: context.space.cardRadius,
          // 밀려 나간 카드가 화면 왼쪽 끝에서 잘려 보이는 것까지 밝힌다.
          bleedLeft: true,
          pointerAt: 1 - (actions / 2) / rowWidth,
          // 열린 줄은 카드 · 삭제 · 수정이 4 간격으로 서 있다. 그 틈은 어둡다 (시안 1291:10401).
          partRadius: context.space.cardRadius,
          partsOf: (row) {
            final gap = RoutineSwipeActions.actionGap.w;
            final edit = row.right - RoutineSwipeActions.editWidth.w;
            final delete = edit - gap - RoutineSwipeActions.deleteWidth.w;
            final cardRight = row.right - RoutineSwipeActions.revealWidth.w;
            return [
              Rect.fromLTRB(0, row.top, cardRight, row.bottom),
              Rect.fromLTRB(delete, row.top, edit - gap, row.bottom),
              Rect.fromLTRB(edit, row.top, row.right, row.bottom),
            ];
          },
        );
      case HomeCoachStep.switchMode:
        return CoachMarkStep(
          target: widget.modeKey,
          message: context.l10n.homeCoachSwitch,
          align: CoachMarkAlign.end,
          holeRadius: CharacterBadge.radius.w,
          // 시안의 화살표는 배지 바닥에서 3 떨어져 시작한다. 구멍을 키운 것이 아니다 —
          // 키우면 배지 바깥에 밝은 테두리가 생긴다.
          pointerGap: _badgeGap.w,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeCoachProvider);
    if (state.active) {
      _retained = state.steps;
      _retainedIndex = state.index;
    }
    final steps = _retained;
    if (steps == null) return const SizedBox.shrink();

    final notifier = ref.read(homeCoachProvider.notifier);
    return CoachMarkOverlay(
      steps: [for (final s in steps) _stepFor(s, context)],
      index: state.active ? state.index : _retainedIndex,
      visible: state.active,
      onNext: notifier.next,
      onClose: notifier.finish,
      onDismissed: () {
        if (mounted) setState(() => _retained = null);
      },
    );
  }
}
