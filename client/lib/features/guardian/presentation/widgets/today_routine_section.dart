import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/config/ad_ids.dart';
import '../../../ads/presentation/ad_native_slot.dart';
import '../../../../core/network/server_error_code.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_error_view.dart';
import 'routine_detail_sheet.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../child/application/child_routine_notifier.dart';
import '../../application/home_coach_notifier.dart';
import '../../application/routine_notifier.dart';
import '../../../../shared/models/routine.dart';
import 'routine_summary_tile.dart';
import 'routine_swipe_actions.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../../../core/widgets/elum_toast.dart';
import '../../application/routine_providers.dart';
import '../../../../core/router/routes.dart';

// (참고) 제목 fallback은 Routine.displayTitle이 처리한다.

/// 홈에 보여줄 일과 목록 — 방금 저장한 일과 + 서버 목록을 병합한다.
///
/// 서버 목록에 아직 없는 새 일과만 먼저 둔다. 서버가 같은 일과를 돌려주면
/// 최신 완료 상태를 쓴다 — 생성 직후의 옛 값이 다른 휴대폰의 체크를 가리지 않게 한다.
/// steps가 빈 일과는 보여줄 것이 없어 제외한다.
///
/// **흐름에 남은 일과가 임시저장(`PENDING_REVIEW`)이면 붙이지 않는다** (#387 결함 C).
/// 카드 확인에서 `나가기`로 끝내면 흐름에 그 일과가 남는데, 상태를 안 보고 붙여서
/// 아직 이룸이에게 보내지 않은 것이 오늘 일과 맨 앞에 떴다 — 앱을 다시 켜야
/// 사라졌다. 오늘 일과는 저장(승인)한 것만이다 (#353).
final homeRoutinesProvider = Provider<List<Routine>>((ref) {
  final current = ref.watch(routineFlowProvider).routine;
  // `.value`는 재조회(invalidate) 중에도 직전 값을 준다. `asData`를 쓰면 동기화 뒤
  // 목록을 다시 읽는 동안 화면이 순간 비어 보인다 (이슈 #140).
  // **오늘 것만 본다.** 전체 목록(`myRoutinesProvider`)을 보고 있어서 어제 것도,
  // 아직 이룸이에게 보내지 않은 것도 오늘 할 일로 보였다. 이룸이 홈과 같은
  // 목록을 봐야 보호자가 믿는 것과 이룸이 화면이 같아진다 (#353).
  final fetched = ref.watch(todayRoutinesProvider).value ?? const <Routine>[];

  // 날짜를 한 번 더 본다 — 앱이 자정을 넘겨 켜져 있으면 받아 둔 값과 흐름에 남은
  // 일과가 어제 것이 된다. 다시 받아 오기 전에도 어제 일과가 남지 않게 한다 (#353).
  final now = DateTime.now();
  final currentFetched = fetched.any((r) => r.id == current?.id);

  return [
    if (current != null &&
        !currentFetched &&
        current.steps.isNotEmpty &&
        current.isTodayOn(now))
      current,
    ...fetched.where((r) => r.steps.isNotEmpty && r.isTodayOn(now)),
  ];
});

/// 일과의 진행률(0.0~1.0).
///
/// 서버에 아직 못 보낸 체크가 있는 동안(오프라인 포함)에만 기기 기록이 기준이다 —
/// 방금 체크한 카드가 바로 보여야 하고, 로컬에서 푼 카드는 빠져야 한다.
/// 다 보낸 뒤에는 서버 값이 기준이다. 기록이 남아 있다는 이유로 계속 따르면
/// 다른 휴대폰이 끝낸 카드가 이 휴대폰에는 반영되지 않는다.
double routineProgress(Routine routine, ChildRoutineState progress) {
  if (routine.steps.isEmpty) return 0;
  // 서버에 올리지 않는 로컬 일과는 보낼 곳이 없으므로 항상 기기 기록이 기준이다
  final isLocalOnly = routine.id.isEmpty || routine.id == 'local';
  final useLocal = isLocalOnly || progress.pending.contains(routine.id);
  final done = routine.steps
      .where(
        (s) => useLocal ? progress.isChecked(routine.id, s) : s.completed,
      )
      .length;
  return done / routine.steps.length;
}

/// 카드 사이 간격 (Figma 931:4013 — gap 8)
const _tileGap = 8.0;

/// 지난 일과 사이 광고가 일과 카드와 떨어지는 만큼 더한 간격(오클릭 방지, #465).
/// 광고가 없으면 이 간격도 없다.
const _adExtraGap = 8.0;

/// 광고가 목록 끝에 붙을 때(지난 일과 1개) 아래로 더 띄우는 간격.
///
/// 끝에 붙으면 바로 아래가 하단 고정 배너라 광고 둘이 가깝게 보인다. 오클릭을 줄이려고
/// 사이 광고(아래 8)보다 넓게 띄운다 (#540).
const _adTrailingGap = 24.0;

/// 광고를 끼울 일과 순번(이 일과 다음). 지난 일과가 1개 이상일 때만 부른다 (#540).
///
/// 3개 이상이면 두 번째 다음, 2개면 첫 번째 다음이라 광고는 언제나 일과 **사이**에 든다
/// (#465 의 오클릭 방지 의도). 1개만 사이가 없어 끝에 붙는다. 0개면 넣지 않는다 —
/// 빈 상태 아래에 두면 하단 배너와 함께 내용 없는 화면에 광고 둘이 붙어 AdMob 정책 위험이 있다.
int _nativeAdAfterIndex(int count) => count >= 3 ? 1 : 0;

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
  const TodayRoutineSection({super.key, this.coachKey});

  /// 코치마크가 가리킬 줄(밀 수 있는 첫 줄)에 달 키 (#505).
  final GlobalKey? coachKey;

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
    // await 뒤에 쓸 문구를 미리 잡아 둔다
    final l10n = context.l10n;
    // ReorderableListView는 "빼내기 전" 기준으로 목적지를 준다.
    final to = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (to == oldIndex) return;

    final next = [...routines];
    next.insert(to, next.removeAt(oldIndex));
    final ids = [for (final r in next) r.id];
    setState(() => _order = ids);

    final failure = await ref.read(routineRepositoryProvider).reorder(ids);
    if (!mounted) return;
    if (failure != null) {
      // 서버가 받지 못했으면 화면만 바뀐 채로 두지 않는다 —
      // 다음에 열면 옛 순서로 돌아와 보호자가 바꾼 적 없다고 여긴다.
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

  /// 이룸이가 한 단계라도 한 일과인가 (#533). 같은 휴대폰에서 방금 체크한 것은 서버에
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

  /// 이룸이가 다 끝낸 일과인가 (#534). 같은 휴대폰의 기기 기록도 본다 — 서버 반영 전에도
  /// 링이 체크로 바뀌는데 편집만 열려 있으면 둘이 어긋난다.
  bool _isFinished(Routine routine) =>
      routine.isFinished ||
      routineProgress(routine, ref.read(childRoutineProvider)) >= 1;

  Future<void> _delete(Routine routine) async {
    final l10n = context.l10n;
    // 시작한 일과는 서버가 지우지 않는다(수행 기록·별). 묻고 나서 실패 팝업을 띄우면
    // 보호자는 "삭제가 고장났다"고 여긴다 (#533). 누르기 전에 이유를 먼저 알린다.
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

    final failure = await ref
        .read(routineRepositoryProvider)
        .delete(routine.id);
    if (!mounted) return;
    if (failure != null) {
      // 묻는 사이에 이룸이가 시작했다 — 서버가 상태로 거절한다 (#533).
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
  /// 보낸다 (이슈 #266).
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
      // 로딩·빈 상태·실패를 셋으로 나눈다. 예전에는 실패까지 빈 상태로 흡수해
      // "아직 만든 일과가 없어요"를 띄웠는데, 그러면 보호자는 자기가 만든
      // 일과가 사라진 줄 안다.
      if (async.hasError) {
        // 로딩·빈 상태와 같은 회색 칸 안에 둔다 — 지난 일과 실패와 같은 자리.
        return _GreyTileShell(
          height: _errorShellHeight,
          child: ElumErrorView.failure(
            async.error,
            fallback: context.l10n.todayRoutineLoadFailedFallback,
            fallbackCode: 'E-HOME',
            onRetry: ref.refreshRoutines,
            compact: true,
          ),
        );
      }
      return async.isLoading ? const _LoadingTile() : const EmptyRoutines();
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
          child: ReorderableDelayedDragStartListener(
            // 코치마크가 가리키는 줄에만 키를 단다. 목록 항목의 키(위 Padding)와는 따로다.
            key: routine.id == coachId ? widget.coachKey : null,
            index: index,
            child: RoutineSwipeActions(
              // 남이 만든 일과는 밀어도 삭제·수정이 나오지 않는다 — 서버가 403 으로 막는 동작이다
              // (다중 보호자 #362 · E46). 만든 사람을 모르면 지금처럼 민다.
              //
              // 다 끝낸 일과도 밀리지 않는다 (#534) — 이룸이 화면은 끝낸 일과를 다시 그리지
              // 않아 고쳐도 반영되지 않고, 삭제는 서버가 막는다(#533). 줄을 누르면 시트에서
              // `다 끝낸 일과예요`로 이유를 본다.
              enabled: routine.isEditableByMe && !_isFinished(routine),
              isOpen:
                  _openId == routine.id || (demoOpen && routine.id == coachId),
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
                    (demoOpen && routine.id == coachId),
                // **손잡이를 그리지 않는다.** 시안(931:3896)에서 빠졌다 — 홈에서는
                // 줄을 밀어 편집·삭제하고, 순서는 줄을 눌러 여는 시트에서 바꾼다.
                // 손잡이가 있으면 링이 그만큼 왼쪽으로 밀려 시안과 어긋난다.
                //
                // 길게 눌러 끄는 길은 남겨 둔다 — 목록이 `ReorderableListView` 라
                // 아래 `ReorderableDelayedDragStartListener` 가 그 역할을 한다.
                dragHandle: null,
                // 밀려 있을 때 탭하면 닫기만 한다 — 열어놓고 실수로 누르는 자리다.
                onTap: () => _openId == routine.id
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
    final l10n = context.l10n;
    if (_rerunning != null) return;
    setState(() => _rerunning = routine.id);

    final copy = await ref
        .read(routineRepositoryProvider)
        .duplicate(routine.id);
    if (!mounted) return;
    setState(() => _rerunning = null);

    if (!copy.isOk) {
      showFailure(
        context,
        copy.failure,
        title: l10n.todayRoutineRerunFailedTitle,
        fallback: l10n.todayRoutineRerunFailedFallback,
        fallbackCode: 'E-DUP',
      );
      return;
    }
    ref.refreshRoutines();
    showElumToast(context, l10n.todayRoutineCopied(copy.value!.displayTitle));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pastRoutinesProvider);
    final routines = async.value ?? const <Routine>[];

    if (routines.isEmpty) {
      if (async.hasError) {
        return _GreyTileShell(
          // 세 줄(문구·안내·다시 시도)이 들어간다.
          height: _errorShellHeight,
          child: ElumErrorView.failure(
            async.error,
            fallback: context.l10n.todayRoutinePastLoadFailedFallback,
            fallbackCode: 'E-PAST',
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
              // **날짜와 다시하기를 붙이지 않는다.** 시안(931:3896)에서 둘 다
              // 빠졌다 — 지난 일과도 오늘 일과와 같은 68 짜리 줄이다.
              // 다시하기는 줄을 눌러 여는 시트 안에 있다 (#310).
              return RoutineSummaryTile(
                routine: routine,
                // 지난 일과는 서버가 셈해 둔 값이 기준이다. 기기 기록은 오늘 것만 있다.
                progress: routine.progressPercent / 100,
                // 시안(980:4777)에는 지난 일과를 눌러 여는 시트가 있는데 화면이
                // 없었다. #299 로 목록 자체가 안 보이던 동안 아무도 열어 보지
                // 못해 빠진 것이 드러나지 않았다 (#310).
                onTap: () => _openPastSheet(routine),
                highlighted: _rerunning == routine.id,
              );
            },
          ),
          // 지난 일과 네이티브 광고 한 개 (#465 · #540). 로드에 실패하면 항목 자체가
          // 없어 빈 자리가 남지 않는다. 오늘 일과에는 끼우지 않는다.
          if (index == _nativeAdAfterIndex(routines.length))
            AdNativeSlot(
              placement: AdPlacement.nativeHomePast,
              padding: EdgeInsets.only(
                top: (_tileGap + _adExtraGap).h,
                // 마지막 줄 다음이면 아래가 하단 배너다 — 더 띄운다.
                bottom:
                    (index == routines.length - 1
                            ? _adTrailingGap
                            : _adExtraGap)
                        .h,
              ),
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
            context.l10n.todayRoutineEmptyTitle,
            style: typo.routineEmptyTitle.copyWith(
              color: colors.routineTileLabel,
            ),
          ),
          SizedBox(height: _emptyLineGap.h),
          Text(
            context.l10n.todayRoutineEmptyHint,
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
        context.l10n.todayRoutinePastEmpty,
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
        child: ElumSpinner(size: 20.w, strokeWidth: 2.w),
      ),
    );
  }
}

/// 빈 상태·로딩의 회색 껍데기 (Figma 931:3906 — 361×68, r20, #EEE9E6).
/// 실패를 담을 때의 회색 칸 높이. 한 줄(68)로는 세 줄이 안 들어간다.
const double _errorShellHeight = 96;

class _GreyTileShell extends StatelessWidget {
  const _GreyTileShell({required this.child, this.height});

  final Widget child;

  /// 기본은 일과 한 줄과 같은 68.
  ///
  /// **실패를 담을 때는 늘린다.** 실패는 무엇이 안 됐는지·무엇을 하면 되는지·
  /// 추적 코드까지 세 줄이라 한 줄 높이에 들어가지 않는다 — 실기기에서
  /// 11px 넘쳤다 (#352 QA). 늘어나는 것은 실패했을 때뿐이라 평소 리듬은 그대로다.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      height: (height ?? 68).h,
      padding: EdgeInsets.symmetric(horizontal: RoutineSummaryTile.padLeft.w),
      decoration: BoxDecoration(
        color: context.colors.routineTileBg,
        borderRadius: BorderRadius.circular(space.cardRadius),
      ),
      child: child,
    );
  }
}
