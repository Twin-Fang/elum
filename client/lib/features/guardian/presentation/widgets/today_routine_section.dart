import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_error_view.dart';
import 'routine_detail_sheet.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../child/application/child_routine_notifier.dart';
import '../../application/routine_notifier.dart';
import '../../data/routine_repository.dart';
import '../../../../shared/models/routine.dart';
import 'routine_summary_tile.dart';
import 'routine_swipe_actions.dart';

// (참고) 제목 fallback은 Routine.displayTitle이 처리한다.

/// 홈에 보여줄 일과 목록 — 방금 만든 일과 + 서버 목록을 병합한다.
///
/// 방금 만든 일과를 먼저 둔다. 서버 목록 갱신을 기다리면 승인 직후 홈에
/// 아무것도 없는 것처럼 보인다 (docs 원칙 6번 — 데모는 끊기지 않는다).
/// steps가 빈 일과는 보여줄 것이 없어 제외한다.
final homeRoutinesProvider = Provider<List<Routine>>((ref) {
  final current = ref.watch(routineFlowProvider).routine;
  // `.value`는 재조회(invalidate) 중에도 직전 값을 준다. `asData`를 쓰면 동기화 뒤
  // 목록을 다시 읽는 동안 화면이 순간 비어 보인다 (이슈 #140).
  final fetched = ref.watch(myRoutinesProvider).value ?? const <Routine>[];

  return [
    if (current != null && current.steps.isNotEmpty) current,
    ...fetched.where((r) => r.id != current?.id && r.steps.isNotEmpty),
  ];
});

/// 일과의 진행률(0.0~1.0).
///
/// 기기 기록이 있으면 그것이 기준이다 — 서버 반영이 늦어도(오프라인 포함)
/// 방금 체크한 카드가 진행률에 바로 보여야 하고, 로컬에서 푼 카드는 빠져야 한다.
double routineProgress(Routine routine, ChildRoutineState progress) {
  if (routine.steps.isEmpty) return 0;
  final done = routine.steps
      .where((s) => progress.isChecked(routine.id, s))
      .length;
  return done / routine.steps.length;
}

/// 카드 사이 간격 (Figma 931:4013 — gap 8)
const _tileGap = 8.0;

/// 보호자 홈 `오늘 일과` (Figma 931:3896 / 931:4179 / 931:4879 · 이슈 #258).
///
/// 개편으로 세 가지가 한꺼번에 들어왔다.
///
/// - **밀면 삭제·수정이 나온다.** 목록에 버튼을 상시 세우지 않으려는 선택이다 —
///   일과가 늘어나면 버튼이 제목보다 넓어진다.
/// - **손잡이로 순서를 바꾼다.** 예정 시각순 고정이던 것을 보호자가 정한다.
/// - **펼치기가 없다.** 카드 목록은 수정 화면에서 본다. 여러 개가 펼쳐지면
///   화면이 끝없이 길어지고, 줄 높이가 달라져 순서를 바꿀 때 자리가 튄다.
class TodayRoutineSection extends ConsumerStatefulWidget {
  const TodayRoutineSection({super.key});

  @override
  ConsumerState<TodayRoutineSection> createState() =>
      _TodayRoutineSectionState();
}

class _TodayRoutineSectionState extends ConsumerState<TodayRoutineSection> {
  /// 지금 밀려서 열려 있는 일과. **한 번에 하나만 연다** —
  /// 둘이 열리면 어느 버튼이 누구 것인지 알 수 없다.
  String? _openId;

  /// 들려서 자리를 옮기는 중인 일과.
  String? _draggingId;

  /// 보호자가 방금 정한 순서(일과 id). 서버 목록이 아직 옛 순서로 오는 동안
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
    // ReorderableListView는 "빼내기 전" 기준으로 목적지를 준다.
    final to = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (to == oldIndex) return;

    final next = [...routines];
    next.insert(to, next.removeAt(oldIndex));
    final ids = [for (final r in next) r.id];
    setState(() => _order = ids);

    final ok = await ref.read(routineRepositoryProvider).reorder(ids);
    if (!mounted) return;
    if (!ok) {
      // 서버가 받지 못했으면 화면만 바뀐 채로 두지 않는다 —
      // 다음에 열면 옛 순서로 돌아와 보호자가 바꾼 적 없다고 여긴다.
      setState(() => _order = null);
      _toast('순서를 저장하지 못했어요 (E-ORDER)');
      return;
    }
    ref.invalidate(myRoutinesProvider);
  }

  Future<void> _delete(Routine routine) async {
    final confirmed = await showElumDialog<bool>(
      context: context,
      title: '일과를 삭제하실건가요?',
      icon: ElumDialogIcon.trash,
      actions: const [
        ElumDialogAction(
          label: '취소',
          value: false,
          tone: ElumDialogTone.neutral,
        ),
        ElumDialogAction(label: '삭제', value: true, tone: ElumDialogTone.danger),
      ],
    );
    if (confirmed != true || !mounted) return;

    final ok = await ref.read(routineRepositoryProvider).delete(routine.id);
    if (!mounted) return;
    if (!ok) {
      _toast('일과를 삭제하지 못했어요 (E-DEL)');
      return;
    }
    // 방금 만든 일과를 지웠다면 흐름에 남은 것도 함께 치운다 —
    // 안 치우면 서버에 없는 일과가 홈 맨 위에 그대로 남는다.
    if (ref.read(routineFlowProvider).routine?.id == routine.id) {
      ref.read(routineFlowProvider.notifier).reset();
    }
    setState(() => _openId = null);
    ref.invalidate(myRoutinesProvider);
    ref.invalidate(pastRoutinesProvider);
  }

  /// 이미 만든 일과를 검토 화면에 올린다. 거기서 카드 문구와 보상을 고친다.
  void _edit(Routine routine) {
    setState(() => _openId = null);
    ref.read(routineFlowProvider.notifier).loadExisting(routine);
    context.push(Routes.routineReview);
  }

  /// 일과를 눌렀을 때 — 먼저 시트로 보여주고, `편집하기`를 눌렀을 때만 편집 화면으로
  /// 보낸다 (이슈 #266).
  ///
  /// **편집 화면으로 갈 때는 시트를 먼저 닫는다.** 시트를 띄운 채 화면을 밀면 편집에서
  /// 뒤로 나올 때 시트를 한 번 더 지나야 한다. 편집 화면이 같은 일과를 보여주므로
  /// 맥락은 끊기지 않는다.
  Future<void> _openSheet(Routine routine) async {
    setState(() => _openId = null);
    final action = await RoutineDetailSheet.show(context, routine);
    if (action != RoutineSheetAction.edit || !mounted) return;
    _edit(routine);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final routines = _applyOrder(ref.watch(homeRoutinesProvider));

    if (routines.isEmpty) {
      final async = ref.watch(myRoutinesProvider);
      // 로딩·빈 상태·실패를 셋으로 나눈다. 예전에는 실패까지 빈 상태로 흡수해
      // "아직 만든 일과가 없어요"를 띄웠는데, 그러면 보호자는 자기가 만든
      // 일과가 사라진 줄 안다.
      if (async.hasError) {
        return ElumErrorView(
          message: '일과를 불러오지 못했어요',
          errorCode: 'E-HOME',
          onRetry: () => ref.invalidate(myRoutinesProvider),
          compact: true,
        );
      }
      return async.isLoading ? const _LoadingTile() : const EmptyRoutines();
    }

    final progress = ref.watch(childRoutineProvider);

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
        setState(() {
          _draggingId = routines[index].id;
          // 들고 있는 카드가 밀려 있으면 버튼만 제자리에 남는다.
          _openId = null;
        });
      },
      onReorderEnd: (_) => setState(() => _draggingId = null),
      onReorder: (oldIndex, newIndex) => _reorder(routines, oldIndex, newIndex),
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
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
      itemBuilder: (context, index) {
        final routine = routines[index];
        return Padding(
          key: ValueKey(routine.id),
          padding: EdgeInsets.only(
            bottom: index == routines.length - 1 ? 0 : _tileGap.h,
          ),
          child: RoutineSwipeActions(
            isOpen: _openId == routine.id,
            onOpenChanged: (open) =>
                setState(() => _openId = open ? routine.id : null),
            onDelete: () => _delete(routine),
            onEdit: () => _edit(routine),
            child: RoutineSummaryTile(
              routine: routine,
              progress: routineProgress(routine, progress),
              highlighted: _openId == routine.id || _draggingId == routine.id,
              dragHandle: ReorderableDragStartListener(
                index: index,
                child: const RoutineDragHandle(),
              ),
              // 밀려 있을 때 탭하면 닫기만 한다 — 열어놓고 실수로 누르는 자리다.
              onTap: () => _openId == routine.id
                  ? setState(() => _openId = null)
                  : _openSheet(routine),
            ),
          ),
        );
      },
    );
  }
}

/// 보호자 홈 `지난 일과` (Figma 931:3896 — 지난일과_1).
///
/// 오늘 목록과 달리 **밀리지도 않고 순서도 바꾸지 않는다.** 지나간 것을
/// 고칠 일이 없고, 순서는 날짜가 정한다.
///
/// 다 끝낸 일과에만 `일과 다시하기`가 붙는다 — 그대로 한 번 더 시킬 값어치가
/// 있다는 뜻이고, 하다 만 것을 복제하면 같은 일과가 둘이 되어 헷갈린다.
class PastRoutineSection extends ConsumerStatefulWidget {
  const PastRoutineSection({super.key});

  @override
  ConsumerState<PastRoutineSection> createState() => _PastRoutineSectionState();
}

class _PastRoutineSectionState extends ConsumerState<PastRoutineSection> {
  /// 다시 만드는 중인 일과. 두 번 눌러 둘이 생기는 것을 막는다.
  String? _rerunning;

  /// 지난 일과 시트를 띄우고, `일과 다시하기`를 누르면 오늘로 복제한다.
  ///
  /// 복제는 타일의 다시하기와 **같은 길을 쓴다** — 두 자리에서 각각 만들면
  /// 한쪽만 고쳐져 어긋난다.
  Future<void> _openPastSheet(Routine routine) async {
    final action = await RoutineDetailSheet.show(
      context,
      routine,
      isPast: true,
    );
    if (action != RoutineSheetAction.rerun || !mounted) return;
    await _rerun(routine);
  }

  Future<void> _rerun(Routine routine) async {
    if (_rerunning != null) return;
    setState(() => _rerunning = routine.id);

    final copy = await ref
        .read(routineRepositoryProvider)
        .duplicate(routine.id);
    if (!mounted) return;
    setState(() => _rerunning = null);

    if (copy == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('일과를 다시 만들지 못했어요 (E-DUP)')));
      return;
    }
    ref.invalidate(myRoutinesProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${copy.displayTitle}을(를) 오늘 일과에 담았어요')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pastRoutinesProvider);
    final routines = async.value ?? const <Routine>[];

    if (routines.isEmpty) {
      if (async.hasError) {
        return _GreyTileShell(
          child: ElumErrorView(
            message: '지난 일과를 불러오지 못했어요',
            errorCode: 'E-PAST',
            onRetry: () => ref.invalidate(pastRoutinesProvider),
            compact: true,
          ),
        );
      }
      return async.isLoading
          ? const _LoadingTile()
          : const _GreyTileShell(child: _EmptyPastLabel());
    }

    return Column(
      children: [
        for (final (index, routine) in routines.indexed) ...[
          if (index > 0) SizedBox(height: _tileGap.h),
          Builder(
            builder: (context) {
              // 시안은 다 끝낸 일과에만 날짜와 다시하기를 붙인다(931:4072 vs 931:4160).
              // 하다 만 것은 복제할 값어치가 없고, 링이 몇 %인지가 더 중요한 정보다.
              final done = routine.progressPercent >= 100;
              return RoutineSummaryTile(
                routine: routine,
                // 지난 일과는 서버가 셈해 둔 값이 기준이다. 기기 기록은 오늘 것만 있다.
                progress: routine.progressPercent / 100,
                showDate: done,
                onRerun: done ? () => _rerun(routine) : null,
                // 시안(980:4777)에는 지난 일과를 눌러 여는 시트가 있는데 화면이
                // 없었다. #299 로 목록 자체가 안 보이던 동안 아무도 열어 보지
                // 못해 빠진 것이 드러나지 않았다 (#310).
                onTap: () => _openPastSheet(routine),
                highlighted: _rerunning == routine.id,
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Figma 빈 상태 (217:2655 — 361×68, #EEE9E6) — `아직 만든 일과가 없어요`
///
/// 개편 시안에서 **캐릭터 배지가 빠졌다.** 일과 카드와 같은 상자에 같은 자리에서
/// 글이 시작해야 "여기가 일과가 들어올 자리"로 읽힌다 — 그림이 붙으면 다른
/// 종류의 알림처럼 보인다.
class EmptyRoutines extends StatelessWidget {
  const EmptyRoutines({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return _GreyTileShell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '아직 만든 일과가 없어요',
            style: typo.routineEmptyTitle.copyWith(
              color: colors.routineTileLabel,
            ),
          ),
          SizedBox(height: _emptyLineGap.h),
          Text(
            '오늘의 첫 행동카드를 만들어보세요',
            style: typo.routineTileMeta.copyWith(
              color: colors.routineEmptyHint,
            ),
          ),
        ],
      ),
    );
  }
}

/// 빈 상태 두 줄 사이 (일과 카드의 제목↔보상 간격과 같다)
const _emptyLineGap = 8.0;

/// 지난 일과가 0건일 때. 오늘 빈 상태와 달리 **권하지 않는다** —
/// 지난 일과는 시간이 지나면 저절로 쌓이는 것이라 할 일이 없다.
class _EmptyPastLabel extends StatelessWidget {
  const _EmptyPastLabel();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '지난 일과가 없어요',
        style: context.typo.routineEmptyPast.copyWith(
          color: context.colors.routineTileLabel,
        ),
      ),
    );
  }
}

/// 목록 조회 중. 빈 상태와 구분되는 자리 표시.
class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return _GreyTileShell(
      child: Center(
        child: SizedBox(
          width: 20.w,
          height: 20.w,
          child: CircularProgressIndicator(strokeWidth: 2.w),
        ),
      ),
    );
  }
}

/// 빈 상태·로딩의 회색 껍데기 (Figma 931:3906 — 361×68, r20, #EEE9E6).
class _GreyTileShell extends StatelessWidget {
  const _GreyTileShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      height: 68.h,
      padding: EdgeInsets.symmetric(horizontal: RoutineSummaryTile.padLeft.w),
      decoration: BoxDecoration(
        color: context.colors.routineTileBg,
        borderRadius: BorderRadius.circular(space.cardRadius),
      ),
      child: child,
    );
  }
}
