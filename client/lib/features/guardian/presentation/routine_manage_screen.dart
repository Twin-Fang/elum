import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/server_error_code.dart';
import '../../../core/router/routes.dart';
import '../../../core/state/busy_state_mixin.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_spinner.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../shared/models/routine.dart';
import '../../credit/application/credit_start_gate.dart';
import '../application/library_coach_notifier.dart';
import '../application/library_entries.dart';
import '../application/routine_library_controller.dart';
import '../application/routine_notifier.dart';
import '../application/routine_providers.dart';
import 'guardian_home_screen.dart';
import 'library_group_actions.dart';
import 'widgets/library_coach_mark.dart';
import 'widgets/library_entry_grid.dart';
import 'widgets/library_parts.dart';
import 'widgets/library_quick_menu.dart';
import 'widgets/routine_detail_sheet.dart';
import 'widgets/routine_rename_sheet.dart';

/// 하단 바 일과관리 칸: 만들어 둔 원본 일과를 바탕화면 아이콘처럼 모아 둔다 (#805, 설계 #797)
///
/// 누르면 상세 시트(오늘 보내기 · 카드 고치기), 길게 누르면 빠른 메뉴(보내기 · 이름 · 묶음에 넣기 · 복사 · 지우기).
/// 묶음(폴더, #807)은 격자 앞에 오고, 낱개를 끌어 다른 일과·묶음 위에 놓으면 묶인다. 묶음 동작은 [LibraryGroupActions].
class RoutineManageScreen extends ConsumerStatefulWidget {
  const RoutineManageScreen({super.key});

  @override
  ConsumerState<RoutineManageScreen> createState() =>
      _RoutineManageScreenState();
}

class _RoutineManageScreenState extends ConsumerState<RoutineManageScreen>
    with
        BusyStateMixin<RoutineManageScreen>,
        LibraryGroupActions<RoutineManageScreen> {
  /// `+ 일과 만들기` 버튼 높이 · 버튼 둘레 여백 (목록 끝이 버튼에 가리지 않게 그만큼 비운다)
  static const _createButtonHeight = 54.0;
  static const _createButtonMargin = 16.0;

  /// 코치마크가 가리킬 첫 일과 칸 · `+ 일과 만들기` 버튼 (#834)
  final _firstTileKey = GlobalKey();
  final _createKey = GlobalKey();

  /// 이 칸이 맨 위에 보이는 지금일 때만 코치마크를 켠다. 숨은 칸(다른 탭)이나 다른 화면 위에서는 켜지 않는다
  void _maybeStartCoach() {
    if (!mounted || !TickerMode.of(context)) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    ref.read(libraryCoachProvider.notifier).maybeStart(hasTileTarget: true);
  }

  // --- 동작 ---

  @override
  Future<void> openRoutineDetail(Routine routine) async {
    final action = await RoutineDetailSheet.show(
      context,
      routine,
      isLibrary: true,
    );
    if (!mounted) return;
    switch (action) {
      case RoutineSheetAction.send:
        await _send(routine);
      case RoutineSheetAction.edit:
        _editCards(routine);
      case RoutineSheetAction.more:
        await _openMenu(routine);
      case RoutineSheetAction.rerun || null:
        return;
    }
  }

  Future<void> _openMenu(Routine routine) async {
    final action = await showLibraryQuickMenu(context, routine);
    if (!mounted || action == null) return;
    switch (action) {
      case LibraryMenuAction.send:
        await _send(routine);
      case LibraryMenuAction.rename:
        await _rename(routine);
      case LibraryMenuAction.addToGroup:
        await chooseGroupFor(routine);
      case LibraryMenuAction.copy:
        await _copy(routine);
      case LibraryMenuAction.remove:
        await _remove(routine);
    }
  }

  /// 오늘 보내기. 이미 보냈으면 서버에 가지 않고 알린다 (두 번 보내기는 서버도 막는다)
  Future<void> _send(Routine routine) async {
    final l10n = context.l10n;
    if (ref.read(sentTodaySourceIdsProvider).contains(routine.id)) {
      showElumToast(context, l10n.routineLibraryAlreadySent);
      return;
    }
    final result = await runBusy(
      () => ref.read(routineLibraryControllerProvider).sendToday(routine.id),
    );
    if (result == null || !mounted) return;
    final failure = result.failure;
    if (failure == null) {
      showElumToast(context, l10n.routineLibrarySent(routine.displayTitle));
      return;
    }
    // 다른 기기에서 먼저 보냈다 — 실패 팝업이 아니라 안내로 충분하다
    if (failure.server?.code == ServerErrorCode.routineAlreadySentToday) {
      ref.refreshRoutines();
      showElumToast(context, l10n.routineLibraryAlreadySent);
      return;
    }
    await showFailure(
      context,
      failure,
      title: l10n.routineLibrarySendFailedTitle,
      fallback: l10n.routineLibraryActionFailedFallback,
      fallbackCode: 'E-LIB-SEND',
    );
  }

  Future<void> _copy(Routine routine) async {
    final l10n = context.l10n;
    final result = await runBusy(
      () => ref.read(routineLibraryControllerProvider).copy(routine.id),
    );
    if (result == null || !mounted) return;
    if (result.isOk) {
      showElumToast(context, l10n.routineLibraryCopied);
      return;
    }
    await showFailure(
      context,
      result.failure,
      title: l10n.routineLibraryCopyFailedTitle,
      fallback: l10n.routineLibraryActionFailedFallback,
      fallbackCode: 'E-LIB-COPY',
    );
  }

  Future<void> _rename(Routine routine) async {
    final l10n = context.l10n;
    final title = await showRoutineRenameSheet(
      context,
      currentTitle: routine.displayTitle,
    );
    if (title == null || !mounted) return;
    final result = await runBusy(
      () =>
          ref.read(routineLibraryControllerProvider).rename(routine.id, title),
    );
    if (result == null || !mounted) return;
    if (result.isOk) {
      showElumToast(context, l10n.routineLibraryRenamed);
      return;
    }
    await showFailure(
      context,
      result.failure,
      title: l10n.routineLibraryRenameFailedTitle,
      fallback: l10n.routineLibraryActionFailedFallback,
      fallbackCode: 'E-LIB-RENAME',
    );
  }

  /// 지우기: 확인 팝업 > 일과관리에서 뺀다 (이룸이가 한 기록은 서버가 남긴다)
  Future<void> _remove(Routine routine) async {
    final l10n = context.l10n;
    final isConfirmed = await showElumDialog<bool>(
      context: context,
      icon: ElumDialogIcon.alert,
      title: l10n.routineLibraryRemoveConfirmTitle,
      message: l10n.routineLibraryRemoveConfirmMessage,
      // "남아요"가 "남아 / 요"로 끊기지 않게 낱말 단위로 줄바꿈
      keepWordsInMessage: true,
      actions: [
        ElumDialogAction(
          label: l10n.commonCancel,
          value: false,
          tone: ElumDialogTone.neutral,
        ),
        ElumDialogAction(
          label: l10n.routineLibraryMenuRemove,
          value: true,
          tone: ElumDialogTone.danger,
        ),
      ],
    );
    if (isConfirmed != true || !mounted) return;
    final result = await runBusy(
      () async => (
        failure: await ref
            .read(routineLibraryControllerProvider)
            .removeFromLibrary(routine.id),
      ),
    );
    if (result == null || !mounted) return;
    if (result.failure == null) {
      showElumToast(context, l10n.routineLibraryRemoved);
      return;
    }
    await showFailure(
      context,
      result.failure,
      title: l10n.routineLibraryRemoveFailedTitle,
      fallback: l10n.routineLibraryActionFailedFallback,
      fallbackCode: 'E-LIB-DEL',
    );
  }

  /// 카드 고치기: 이미 만든 일과를 검토 화면에 올린다 (홈 `편집하기`와 같은 길)
  void _editCards(Routine routine) {
    ref.read(routineFlowProvider.notifier).loadExisting(routine);
    context.push(Routes.routineReview);
  }

  /// 새 일과: 크레딧 확인 > 일과 만들기 흐름 (홈 버튼과 같은 길)
  @override
  Future<void> startCreateRoutine() async {
    final check = await runBusy(
      () async => (blocked: await creditBlocksRoutineStart(ref)),
    );
    if (check == null || !mounted) return;
    await continueRoutineStart(context, ref, check.blocked);
  }

  // --- 화면 ---

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final async = ref.watch(libraryEntriesProvider);
    final sentIds = ref.watch(sentTodaySourceIdsProvider);
    final bottomSpace = (_createButtonHeight + _createButtonMargin * 2).h;

    final Widget body = switch (async) {
      AsyncValue(:final value?) when value.isNotEmpty => LibraryEntryGrid(
        entries: value,
        sentIds: sentIds,
        bottomSpace: bottomSpace,
        onRoutineTap: busy ? null : openRoutineDetail,
        onRoutineMenu: busy ? null : _openMenu,
        onGroupTap: busy ? null : openGroup,
        onGroupMenu: busy ? null : openGroupMenu,
        onDropOnRoutine: busy ? null : groupByDrop,
        onDropOnGroup: busy
            ? null
            : (dragged, target) => addToGroup(target.group, [dragged.id]),
        firstTileKey: _firstTileKey,
      ),
      AsyncValue(:final value?) when value.isEmpty => LibraryEmptyState(
        bottomSpace: bottomSpace,
      ),
      AsyncValue(:final error?) => ElumErrorView.failure(
        error,
        fallback: context.l10n.routineLibraryLoadFailedFallback,
        fallbackCode: 'E-LIB',
        onRetry: () => ref
          ..invalidate(routineLibraryProvider)
          ..invalidate(routineGroupsProvider),
      ),
      _ => const Center(child: ElumSpinner()),
    };

    // 일과 칸이 그려진 뒤(가리킬 곳이 있을 때) 처음 한 번 안내를 켠다
    if (async.value?.isNotEmpty ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartCoach());
    }

    final scaffold = Scaffold(
      backgroundColor: colors.background,
      // 떠 있는 버튼으로 두어야 알림(토스트)이 버튼을 가리지 않고 그 위에 뜬다
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: KeyedSubtree(
        key: _createKey,
        child: CreateRoutineFab(
          height: _createButtonHeight.h,
          isBusy: busy,
          onTap: onCreatePressed,
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LibraryManageHeader(),
            SizedBox(height: space.md.h),
            Expanded(child: body),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        scaffold,
        // 처음 들어왔을 때만 뜨는 안내. 평소에는 아무것도 그리지 않는다
        Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: LibraryCoachMark(
              tileKey: _firstTileKey,
              createKey: _createKey,
            ),
          ),
        ),
      ],
    );
  }
}
