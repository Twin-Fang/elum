import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/network/server_error_code.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../../core/widgets/elum_error_view.dart';
import 'routine_detail_sheet.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../child/application/child_routine_notifier.dart';
import '../../application/home_coach_notifier.dart';
import '../../application/routine_notifier.dart';
import '../../../../shared/models/routine.dart';
import 'empty_routines.dart';
import 'grey_tile_shell.dart';
import 'routine_loading_tile.dart';
import 'routine_tile_gap.dart';
import 'routine_summary_tile.dart';
import 'routine_swipe_actions.dart';
import '../../../../core/state/busy_state_mixin.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../../../core/widgets/reorder_finger_follow.dart';
import '../../application/guardian_home_controller.dart';
import '../../application/routine_providers.dart';
import '../../application/home_routines.dart';
import '../../../../core/router/routes.dart';

// (참고) 제목 fallback은 Routine.displayTitle이 처리한다.

/// 보호자 홈 `오늘 일과` (Figma 931:3896 / 931:4179 / 931:4879).
///
/// 개편으로 세 가지가 한꺼번에 들어왔다.
///
/// - **밀면 삭제·수정이 나온다.** 목록에 버튼을 상시 세우지 않으려는 선택이다 —
///   일과가 늘어나면 버튼이 제목보다 넓어진다.
/// - **손잡이로 순서를 바꾼다.** 예정 시각순 고정이던 것을 보호자가 정한다.
/// - **펼치기가 없다.** 카드 목록은 수정 화면에서 본다. 여러 개가 펼쳐지면
///   화면이 끝없이 길어지고, 줄 높이가 달라져 순서를 바꿀 때 자리가 튄다.
class TodayRoutineSection extends ConsumerStatefulWidget {
  const TodayRoutineSection({super.key, this.coachKey});

  /// 코치마크가 가리킬 줄(밀 수 있는 첫 줄)에 달 키.
  final GlobalKey? coachKey;

  @override
  ConsumerState<TodayRoutineSection> createState() =>
      _TodayRoutineSectionState();
}

class _TodayRoutineSectionState extends ConsumerState<TodayRoutineSection>
    with BusyStateMixin<TodayRoutineSection> {
  /// 지금 밀려서 열려 있는 일과. **한 번에 하나만 연다** —
  /// 둘이 열리면 어느 버튼이 누구 것인지 알 수 없다.
  String? _openId;

  /// 들려서 자리를 옮기는 중인 일과.
  String? _draggingId;

  /// 보호자가 방금 정한 순서(일과 id). 서버 목록이 아직 이전 순서로 오는 동안
  /// 화면이 되돌아가지 않게 덮어쓴다. 새 순서가 도착하면 자연히 같은 값이 되어
  /// 아무 일도 하지 않으므로 따로 치우지 않아도 된다.
  List<String>? _order;

  /// 들어 올릴 때 커지는 정도. 더 키우면 옆 카드를 덮어 어디로 가는지 안 보인다.
  static const _liftScale = 0.03;

  /// 화면에 보이는 순서를 [_order]에 맞춘다.
  ///
  /// 그 사이에 생긴 일과는 뒤에 붙이고, 사라진 것은 그냥 빠진다 —
  /// 저장해 둔 순서가 낡아도 목록이 깨지지 않아야 한다.
  List<Routine> _applyOrder(List<Routine> routines) {
    final ids = _order;
    if (ids == null) return routines;

    final remaining = {for (final r in routines) r.id: r};
    final ordered = <Routine>[];
    for (final id in ids) {
      final found = remaining.remove(id);
      if (found != null) ordered.add(found);
    }
    ordered.addAll(remaining.values);
    return ordered;
  }

  Future<void> _reorder(
    List<Routine> routines,
    int oldIndex,
    int newIndex,
  ) async {
    // await 뒤에 쓸 문구를 미리 잡아 둔다
    final l10n = context.l10n;
    // ReorderableListView는 "빼내기 전" 기준으로 목적지를 준다.
    final to = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (to == oldIndex) return;

    final next = [...routines];
    next.insert(to, next.removeAt(oldIndex));
    final ids = [for (final r in next) r.id];
    setState(() => _order = ids);

    final failure = await ref.read(guardianHomeControllerProvider).reorder(ids);
    if (!mounted) return;
    if (failure != null) {
      // 서버가 받지 못했으면 화면만 바뀐 채로 두지 않는다 —
      // 다음에 열면 이전 순서로 돌아와 보호자가 바꾼 적 없다고 여긴다.
      setState(() => _order = null);
      showFailure(
        context,
        failure,
        title: l10n.todayRoutineReorderFailedTitle,
        fallback: l10n.todayRoutineReorderFailedFallback,
        fallbackCode: 'E-ORDER',
      );
      return;
    }
    ref.refreshRoutines();
  }

  /// 이룸이가 한 단계라도 한 일과인가. 같은 휴대폰에서 방금 체크한 것은 서버에
  /// 아직 안 갔을 수 있어 기기 기록도 함께 본다.
  bool _hasStarted(Routine routine) =>
      routine.hasStarted ||
      routineProgress(routine, ref.read(childRoutineProvider)) > 0;

  /// 시작한 일과를 지우려 할 때의 안내. 실패가 아니라 정해진 규칙이라 확인 하나만 둔다.
  Future<void> _showStartedNotice() => showElumDialog<void>(
    context: context,
    title: context.l10n.todayRoutineStartedTitle,
    message: context.l10n.todayRoutineStartedMessage,
    icon: ElumDialogIcon.alert,
    code: 'E-DEL-STARTED',
    actions: [ElumDialogAction(label: context.l10n.commonConfirm)],
  );

  /// 이룸이가 다 끝낸 일과인가. 같은 휴대폰의 기기 기록도 본다 — 서버 반영 전에도
  /// 링이 체크로 바뀌는데 편집만 열려 있으면 둘이 어긋난다.
  bool _isFinished(Routine routine) =>
      routine.isFinished ||
      routineProgress(routine, ref.read(childRoutineProvider)) >= 1;

  Future<void> _delete(Routine routine) async {
    final l10n = context.l10n;
    // 시작한 일과는 서버가 지우지 않는다(수행 기록·별). 묻고 나서 실패 팝업을 띄우면
    // 보호자는 "삭제가 고장났다"고 여긴다. 누르기 전에 이유를 먼저 알린다.
    if (_hasStarted(routine)) {
      setState(() => _openId = null);
      await _showStartedNotice();
      return;
    }

    final confirmed = await showElumDialog<bool>(
      context: context,
      title: l10n.todayRoutineDeleteConfirmTitle,
      icon: ElumDialogIcon.trash,
      actions: [
        ElumDialogAction(
          label: l10n.commonCancel,
          value: false,
          tone: ElumDialogTone.neutral,
        ),
        ElumDialogAction(
          label: l10n.todayRoutineDeleteAction,
          value: true,
          tone: ElumDialogTone.danger,
        ),
      ],
    );
    if (confirmed != true || !mounted) return;

    // 같은 일과를 두 번 지우면 서버가 거절해 실패 팝업이 뜬다 — 일과 단위로 잠근다.
    // 성공도 null 이라 기록으로 감싸 진행 중이라 건너뛴 경우(result == null)와 가른다.
    final result = await runBusy(
      () async => (
        failure: await ref
            .read(guardianHomeControllerProvider)
            .delete(routine.id),
      ),
      key: routine.id,
    );
    if (result == null || !mounted) return;
    final failure = result.failure;
    if (failure != null) {
      // 묻는 사이에 이룸이가 시작했다 — 서버가 상태로 거절한다.
      // 새로 받아 와야 화면도 시작한 일과로 바뀐다.
      // showFailure 를 쓰지 않는다 — 서버 문구(`현재 상태에서는 처리할 수 없습니다`)가
      // 이 안내를 덮어 왜 안 되는지 알 수 없다.
      if (failure.server?.code == ServerErrorCode.routineInvalidStatus) {
        setState(() => _openId = null);
        ref.refreshRoutines();
        await _showStartedNotice();
        return;
      }
      showFailure(
        context,
        failure,
        title: l10n.todayRoutineDeleteFailedTitle,
        fallback: l10n.todayRoutineDeleteFailedFallback,
        fallbackCode: 'E-DEL',
      );
      return;
    }
    // 방금 만든 일과를 지웠다면 흐름에 남은 것도 함께 치운다 —
    // 안 치우면 서버에 없는 일과가 홈 맨 위에 그대로 남는다.
    if (ref.read(routineFlowProvider).routine?.id == routine.id) {
      ref.read(routineFlowProvider.notifier).reset();
    }
    setState(() => _openId = null);
    ref.refreshRoutines();
    ref.invalidate(pastRoutinesProvider);
  }

  /// 이미 만든 일과를 검토 화면에 올린다. 거기서 카드 문구와 보상을 고친다.
  void _edit(Routine routine) {
    setState(() => _openId = null);
    ref.read(routineFlowProvider.notifier).loadExisting(routine);
    context.push(Routes.routineReview);
  }

  /// 일과를 눌렀을 때 — 먼저 시트로 보여주고, `편집하기`를 눌렀을 때만 편집 화면으로
  /// 보낸다.
  ///
  /// **편집 화면으로 갈 때는 시트를 먼저 닫는다.** 시트를 띄운 채 화면을 밀면 편집에서
  /// 뒤로 나올 때 시트를 한 번 더 지나야 한다. 편집 화면이 같은 일과를 보여주므로
  /// 맥락은 끊기지 않는다.
  Future<void> _openSheet(Routine routine) async {
    setState(() => _openId = null);
    final action = await RoutineDetailSheet.show(
      context,
      routine,
      isFinished: _isFinished(routine),
    );
    if (action != RoutineSheetAction.edit || !mounted) return;
    _edit(routine);
  }

  @override
  Widget build(BuildContext context) {
    final routines = _applyOrder(ref.watch(homeRoutinesProvider));

    if (routines.isEmpty) {
      final async = ref.watch(todayRoutinesProvider);
      // 로딩·빈 상태·실패를 셋으로 나눈다. 실패까지 빈 상태로 흡수해
      // "아직 만든 일과가 없어요"를 띄우면 보호자는 자기가 만든
      // 일과가 사라진 줄 안다.
      if (async.hasError) {
        // 로딩·빈 상태와 같은 회색 칸 안에 둔다 — 지난 일과 실패와 같은 자리.
        return GreyTileShell(
          height: greyTileErrorShellHeight,
          child: ElumErrorView.failure(
            async.error,
            fallback: context.l10n.todayRoutineLoadFailedFallback,
            fallbackCode: 'E-HOME',
            onRetry: ref.refreshRoutines,
            compact: true,
          ),
        );
      }
      return async.isLoading
          ? const RoutineLoadingTile()
          : const EmptyRoutines();
    }

    final progress = ref.watch(childRoutineProvider);

    // 코치마크가 "밀어 보세요"를 말하는 동안, 밀 수 있는 첫 줄을 실제로 열어 보여준다.
    // 말로만 하면 밀면 뭐가 나오는지 알 수 없다. 열고 닫는 것은 줄이 스스로 미끄러진다.
    final demoOpen = ref.watch(
      homeCoachProvider.select((s) => s.demoSwipeOpen),
    );
    final coachId = routines
        .where((r) => r.isEditableByMe && !_isFinished(r))
        .firstOrNull
        ?.id;

    return ReorderFingerFollow(
      builder: (context, follow) => _buildReorderList(
        routines: routines,
        progress: progress,
        isDemoSwipeOpen: demoOpen,
        coachId: coachId,
        follow: follow,
      ),
    );
  }

  /// 오늘 일과 목록: 길게 눌러 끌어 순서 바꾸기 (들린 줄은 손가락에 붙음) · 밀어서 편집 · 삭제
  Widget _buildReorderList({
    required List<Routine> routines,
    required ChildRoutineState progress,
    required bool isDemoSwipeOpen,
    required String? coachId,
    required ReorderFingerFollowState follow,
  }) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      // 바깥 화면이 이미 스크롤한다. 여기까지 스크롤하면 둘이 맞물려 튄다.
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      // 손잡이를 쥐었을 때만 들린다. 기본값은 어디를 잡아도 들려서
      // 밀어서 지우기와 부딪힌다.
      buildDefaultDragHandles: false,
      itemCount: routines.length,
      onReorderStart: (index) {
        HapticFeedback.mediumImpact();
        follow.start();
        setState(() {
          _draggingId = routines[index].id;
          // 들고 있는 카드가 밀려 있으면 버튼만 제자리에 남는다.
          _openId = null;
        });
      },
      onReorderEnd: (_) {
        follow.end();
        setState(() => _draggingId = null);
      },
      onReorder: (oldIndex, newIndex) => _reorder(routines, oldIndex, newIndex),
      proxyDecorator: (child, index, animation) => follow.decorate(
        AnimatedBuilder(
          animation: animation,
          builder: (context, inner) {
            final lift = Curves.easeOut.transform(animation.value);
            return Transform.scale(
              scale: 1 + _liftScale * lift,
              child: Material(type: MaterialType.transparency, child: inner),
            );
          },
          child: child,
        ),
      ),
      itemBuilder: (context, index) {
        final routine = routines[index];
        return Padding(
          key: ValueKey(routine.id),
          padding: EdgeInsets.only(
            bottom: index == routines.length - 1 ? 0 : routineTileGap.h,
          ),
          child: ReorderableDelayedDragStartListener(
            // 코치마크가 가리키는 줄에만 키를 단다. 목록 항목의 키(위 Padding)와는 따로다.
            key: routine.id == coachId ? widget.coachKey : null,
            index: index,
            child: RoutineSwipeActions(
              // 남이 만든 일과는 밀어도 삭제·수정이 나오지 않는다 — 서버가 403 으로 막는 동작이다
              //. 만든 사람을 모르면 지금처럼 민다.
              //
              // 다 끝낸 일과도 밀리지 않는다 — 이룸이 화면은 끝낸 일과를 다시 그리지
              // 않아 고쳐도 반영되지 않고, 삭제는 서버가 막는다. 줄을 누르면 시트에서
              // `다 끝낸 일과예요`로 이유를 본다.
              enabled:
                  routine.isEditableByMe &&
                  !_isFinished(routine) &&
                  !isBusy(routine.id),
              isOpen:
                  _openId == routine.id ||
                  (isDemoSwipeOpen && routine.id == coachId),
              onOpenChanged: (open) =>
                  setState(() => _openId = open ? routine.id : null),
              onDelete: () => _delete(routine),
              onEdit: () => _edit(routine),
              child: RoutineSummaryTile(
                routine: routine,
                progress: routineProgress(routine, progress),
                highlighted:
                    _openId == routine.id ||
                    _draggingId == routine.id ||
                    (isDemoSwipeOpen && routine.id == coachId),
                // **손잡이를 그리지 않는다.** 시안(931:3896)에서 빠졌다 — 홈에서는
                // 줄을 밀어 편집·삭제하고, 순서는 줄을 눌러 여는 시트에서 바꾼다.
                // 손잡이가 있으면 링이 그만큼 왼쪽으로 밀려 시안과 어긋난다.
                //
                // 길게 눌러 끄는 길은 남겨 둔다 — 목록이 `ReorderableListView` 라
                // 아래 `ReorderableDelayedDragStartListener` 가 그 역할을 한다.
                // 지우는 중인 줄만 오른쪽 끝에 스피너를 둔다.
                dragHandle: isBusy(routine.id)
                    ? ElumSpinner(size: 18.w, strokeWidth: 2.w)
                    : null,
                // 밀려 있을 때 탭하면 닫기만 한다 — 열어놓고 실수로 누르는 자리다.
                onTap: isBusy(routine.id)
                    ? null
                    : () => _openId == routine.id
                          ? setState(() => _openId = null)
                          : _openSheet(routine),
              ),
            ),
          ),
        );
      },
    );
  }
}
