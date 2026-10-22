import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/coach_mark_overlay.dart';
import '../../../../core/widgets/coach_mark_step.dart';
import '../../../../shared/models/action_card.dart';
import '../../../../shared/models/routine.dart';
import '../../application/library_entries.dart';
import '../../application/routine_manage_coach_notifier.dart';
import 'coach_demo_content.dart';
import 'coach_demo_layers.dart';
import 'library_entry_grid.dart';
import 'library_parts.dart';
import 'library_routine_tile.dart';

/// 일과관리 안내 무대 (#861): 예시 일과가 놓인 일과관리 화면 위에서 코치마크를 보여 준다
///
/// 루트 위 전체 화면이라 하단 바까지 터치가 막힌다. 칸·버튼은 실제 위젯과 같은 모양이지만 눌러도 아무 일도 없고,
/// 서버·실제 일과는 건드리지 않는다. 일과가 0개인 사용자도 같은 장면을 본다.
class RoutineManageCoachStage extends ConsumerStatefulWidget {
  const RoutineManageCoachStage({super.key});

  /// 루트 내비게이터에 올리는 전체 화면 경로 (부드럽게 나타나고 사라진다)
  static Route<void> route() => PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: AppMotion.normal,
    reverseTransitionDuration: AppMotion.fast,
    pageBuilder: (_, _, _) => const RoutineManageCoachStage(),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  @override
  ConsumerState<RoutineManageCoachStage> createState() =>
      _RoutineManageCoachStageState();
}

class _RoutineManageCoachStageState
    extends ConsumerState<RoutineManageCoachStage> {
  /// 코치마크 ✕ 가 차지하는 위쪽 높이 (안전영역 아래 8 + 버튼 40)
  static const _closeButtonSpace = 48.0;

  /// 안내 화면의 칸: 예시 일과 첫째 · 둘째, `+ 일과 만들기`
  final _firstTileKey = GlobalKey();
  final _secondTileKey = GlobalKey();
  final _createButtonKey = GlobalKey();

  /// 사라지는 연출이 끝날 때까지 직전 단계 목록을 들고 있는다
  List<RoutineManageCoachStep>? _retainedSteps;
  int _retainedIndex = 0;

  /// 예시 일과 3개 (카드 3장씩). 첫 카드 픽토그램이 칸 그림이 된다: 일어나기, 양치, 가방
  static const _samplePictogramIds = [
    'wake_up_,_to',
    'brush_teeth_,_to',
    'school_bag',
  ];

  List<Routine> _sampleRoutines(BuildContext context) {
    final l10n = context.l10n;
    final titles = [
      l10n.routineManageCoachSampleMorning,
      l10n.routineManageCoachSampleBrush,
      l10n.routineManageCoachSampleBag,
    ];
    return [
      for (final (index, title) in titles.indexed)
        Routine(
          id: 'coach-sample-$index',
          title: title,
          status: 'CONFIRMED',
          createdByMe: true,
          steps: [
            for (var order = 1; order <= 3; order++)
              ActionCard(
                // 카드 id 비움: 그림 서버 요청을 건너뛰고 픽토그램으로 바로 그린다
                id: '',
                title: title,
                stepOrder: order,
                description: '',
                pictogramId: _samplePictogramIds[index],
              ),
          ],
        ),
    ];
  }

  CoachMarkStep _stepFor(
    RoutineManageCoachStep step,
    BuildContext context,
    List<Routine> samples,
  ) {
    final l10n = context.l10n;
    final tileRadius = context.space.md;
    switch (step) {
      case RoutineManageCoachStep.tapRoutine:
        return CoachMarkStep(
          target: _firstTileKey,
          message: l10n.routineManageCoachTapMessage,
          holeRadius: tileRadius,
          demoBuilder: tapDemo,
        );
      case RoutineManageCoachStep.longPressRoutine:
        return CoachMarkStep(
          target: _firstTileKey,
          message: l10n.routineManageCoachLongPressMessage,
          holeRadius: tileRadius,
          demoBuilder: longPressDemo,
          // 칸 옆 메뉴가 칸보다 길게 내려오므로 말풍선은 메뉴 아래에
          pointerGap: _menuOverhangBelowTile(),
        );
      case RoutineManageCoachStep.sentBadge:
        return CoachMarkStep(
          target: _firstTileKey,
          message: l10n.routineManageCoachSentMessage,
          holeRadius: tileRadius,
          demoBuilder: (context, rect) => sentBadgeDemo(
            context,
            rect,
            routineTitle: samples.first.displayTitle,
          ),
        );
      case RoutineManageCoachStep.dragToGroup:
        return CoachMarkStep(
          target: _firstTileKey,
          message: l10n.routineManageCoachDragMessage,
          holeRadius: tileRadius,
          demoBuilder: (context, firstRect) => dragToGroupDemo(
            context,
            firstRect,
            _secondTileRect(firstRect),
            ghost: LibraryRoutineThumbnail(routine: samples.first),
            // 놓으면 생기는 묶음 칸: 끈 일과 + 받은 일과
            groupItems: [
              for (final routine in samples.take(2))
                LibraryRoutineThumbnail(routine: routine),
            ],
          ),
        );
      case RoutineManageCoachStep.createGroup:
        return CoachMarkStep(
          target: _createButtonKey,
          message: l10n.routineManageCoachCreateGroupMessage,
          // 알약 버튼: 높이 절반으로 깎아야 구멍 모서리가 버튼 밖으로 비치지 않음
          holeRadius: CreateRoutineFab.height.h / 2,
          demoBuilder: createGroupDemo,
        );
    }
  }

  /// 칸 옆 메뉴가 첫 칸 아래로 삐져나오는 길이 + 간격. 칸을 아직 못 쟀으면 0
  double _menuOverhangBelowTile() {
    final box = _firstTileKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return 0;
    final menuHeight =
        CoachDemoAnchoredMenu.rowHeight.h * CoachDemoAnchoredMenu.rowCount;
    final overhang = menuHeight - box.size.height;
    return overhang > 0 ? overhang + context.space.sm.h : 0;
  }

  /// 예시 칸 줄 아래 끝 + 간격 (무대 좌표). 칸을 아직 못 쟀으면 null
  double? _belowTileRow() {
    final stageBox = context.findRenderObject();
    final box = _firstTileKey.currentContext?.findRenderObject();
    if (stageBox is! RenderBox || box is! RenderBox || !box.attached) {
      return null;
    }
    final origin = box.localToGlobal(Offset.zero, ancestor: stageBox);
    return origin.dy + box.size.height + context.space.xl.h;
  }

  /// 둘째 칸 상자 (무대 좌표). 못 재면 첫 칸 오른쪽 옆으로 본다
  Rect _secondTileRect(Rect firstRect) {
    final stageBox = context.findRenderObject();
    final box = _secondTileKey.currentContext?.findRenderObject();
    if (stageBox is RenderBox && box is RenderBox && box.attached) {
      final origin = box.localToGlobal(Offset.zero, ancestor: stageBox);
      return origin & box.size;
    }
    return firstRect.shift(Offset(firstRect.width, 0));
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
  }

  /// 예시 일과 격자: 실제 일과관리 격자 위젯 그대로 (눌러도 아무 일도 없다)
  Widget _buildSampleGrid(List<Routine> samples, bool isArranging) =>
      LibraryEntryGrid(
        entries: [for (final routine in samples) LibraryRoutineEntry(routine)],
        sentIds: const {},
        bottomSpace: CreateRoutineFab.scrollBottomSpace.h,
        isArranging: isArranging,
        onRoutineTap: null,
        onRoutineMenu: null,
        onGroupTap: null,
        onGroupMenu: null,
        onDropOnRoutine: null,
        onDropOnGroup: null,
        onMoveCell: null,
        onArrangeStart: null,
        onRemoveRoutine: null,
        onRemoveGroup: null,
        firstRoutineTileKey: _firstTileKey,
        secondRoutineTileKey: _secondTileKey,
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(routineManageCoachProvider);
    if (state.isActive) {
      _retainedSteps = state.steps;
      _retainedIndex = state.index;
    }
    final steps = _retainedSteps ?? const [];
    // 보여 줄 단계 없이 열렸으면(이미 끝남) 빈 안내 화면에 갇히지 않게 바로 닫는다
    if (steps.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _close());
    }
    final samples = _sampleRoutines(context);
    final notifier = ref.read(routineManageCoachProvider.notifier);
    // 끌어서 묶기 단계에서는 실제처럼 정리 상태(흔들림 · ⊖ · 가운데 버튼 완료)를 켠다
    final isArrangingDemo =
        state.isActive && state.current == RoutineManageCoachStep.dragToGroup;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: colors.background,
          floatingActionButtonLocation: CreateRoutineFab.location,
          floatingActionButton: KeyedSubtree(
            key: _createButtonKey,
            child: CreateRoutineFab(
              isBusy: false,
              isArranging: isArrangingDemo,
              onTap: () {},
            ),
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 위 왼쪽 ✕ 자리만큼 제목을 내린다 (✕ 가 제목 첫 글자를 덮지 않게)
                SizedBox(height: _closeButtonSpace.h),
                const LibraryManageHeader(),
                Expanded(child: _buildSampleGrid(samples, isArrangingDemo)),
              ],
            ),
          ),
        ),
        if (steps.isNotEmpty)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: CoachMarkOverlay(
                steps: [
                  for (final step in steps) _stepFor(step, context, samples),
                ],
                index: state.isActive ? state.index : _retainedIndex,
                visible: state.isActive,
                // 점·문구를 위로 옮길 때 제목·칸 줄 아래에 둔다
                footerTopOffset: _belowTileRow(),
                onNext: notifier.next,
                onClose: notifier.finish,
                // 다 사라지면 무대를 닫는다 (본 것 저장은 띄운 쪽이 맡는다)
                onDismissed: _close,
              ),
            ),
          ),
      ],
    );
  }
}
