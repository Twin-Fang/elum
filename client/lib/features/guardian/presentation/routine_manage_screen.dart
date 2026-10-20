import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/server_error_code.dart';
import '../../../core/router/routes.dart';
import '../../notification/application/push_permission_prompt.dart';
import '../../../core/state/busy_state_mixin.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_spinner.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../shared/models/routine.dart';
import '../../credit/application/credit_start_gate.dart';
import '../application/library_entries.dart';
import '../application/routine_library_controller.dart';
import '../application/routine_notifier.dart';
import '../application/routine_providers.dart';
import 'guardian_home_screen.dart';
import 'library_group_actions.dart';
import 'widgets/library_entry_grid.dart';
import 'widgets/library_parts.dart';
import 'widgets/library_quick_menu.dart';
import 'widgets/routine_manage_coach_mark.dart';
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
  /// 정리 상태: 칸이 흔들리고 ⊖ 가 붙고 바로 끌 수 있다 (#837)
  bool _isArranging = false;

  // --- 동작 ---

  /// 다른 탭으로 가면(탭 묶음이 이 화면 TickerMode 를 끈다) 정리 상태를 끝낸다 — 돌아왔을 때 흔들리고 있지 않게
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 바로 뒤에 build 가 돌므로 setState 없이 값만 바꾼다
    if (!TickerMode.of(context)) _isArranging = false;
  }

  /// 정리 상태 끝내기 (완료 버튼 · 빈 곳 누르기 · 뒤로가기 공통)
  void _stopArranging() {
    if (!_isArranging) return;
    setState(() => _isArranging = false);
  }

  @override
  Future<void> openRoutineDetail(
    Routine routine, {
    bool isInGroup = false,
  }) async {
    final action = await RoutineDetailSheet.show(
      context,
      routine,
      isLibrary: true,
      isInGroup: isInGroup,
    );
    if (!mounted) return;
    switch (action) {
      case RoutineSheetAction.send:
        await _send(routine);
      case RoutineSheetAction.edit:
        _editCards(routine);
      case RoutineSheetAction.more:
        await _openMenuSheet(routine);
      case RoutineSheetAction.rerun || null:
        return;
    }
  }

  /// 길게 누른 칸 옆 메뉴
  Future<void> _openMenu(Routine routine, LibraryMenuAnchor anchor) async {
    final action = await showLibraryQuickMenu(
      context,
      routine,
      anchor: anchor.rect,
      highlight: anchor.tile,
    );
    await _runMenuAction(routine, action);
  }

  /// 상세 시트 ⋯ 로 연 같은 메뉴 (눌린 칸이 없어 아래 시트)
  Future<void> _openMenuSheet(Routine routine) async => _runMenuAction(
    routine,
    await showLibraryQuickMenuSheet(context, routine),
  );

  Future<void> _runMenuAction(
    Routine routine,
    LibraryMenuAction? action,
  ) async {
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
      // 일과를 보낸 보호자에게 알림 권한 안내 (한 번만, 기다리지 않음)
      unawaited(ref.read(pushPermissionPromptProvider).maybeAsk(context));
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

  /// 칸 사이에 놓아 자리 옮기기: 새 전체 순서를 만들어 서버에 저장한다 (#837, #844). 저장했으면 true
  Future<bool> _moveCell(
    List<LibraryEntry> entries,
    LibraryEntry dragged,
    LibraryEntry target, {
    required bool isBefore,
  }) async {
    final cells = reorderCells(
      entries,
      movedId: dragged.id,
      targetId: target.id,
      isBefore: isBefore,
    );
    // 성공도 null 이라 기록으로 감싸 다른 동작 중이라 건너뛴 경우(saveAttempt == null)와 가른다
    final saveAttempt = await runBusy(
      () async => (
        failure: await ref.read(routineLibraryControllerProvider).saveOrder([
          for (final cell in cells) (type: cell.type.wire, id: cell.id),
        ]),
      ),
    );
    if (saveAttempt == null) return false;
    final failure = saveAttempt.failure;
    if (failure == null) return true;
    if (!mounted) return false;
    // 팝업을 기다리지 않는다 — 격자가 먼저 제자리로 돌아가야 무엇이 안 됐는지 보인다
    unawaited(
      showFailure(
        context,
        failure,
        title: context.l10n.routineGroupActionFailedTitle,
        fallback: context.l10n.routineLibraryActionFailedFallback,
        fallbackCode: 'E-LIB-ORDER',
      ),
    );
    return false;
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
    final bottomSpace = CreateRoutineFab.scrollBottomSpace.h;

    final Widget body = switch (async) {
      AsyncValue(:final value?) when value.isNotEmpty => LibraryEntryGrid(
        entries: value,
        sentIds: sentIds,
        bottomSpace: bottomSpace,
        onRoutineTap: busy ? null : openRoutineDetail,
        onRoutineMenu: busy ? null : _openMenu,
        onGroupTap: busy ? null : openGroup,
        onGroupMenu: busy ? null : openGroupMenu,
        isArranging: _isArranging,
        onArrangeStart: () => setState(() => _isArranging = true),
        onMoveCell: busy
            ? null
            : (dragged, target, {required isBefore}) =>
                  _moveCell(value, dragged, target, isBefore: isBefore),
        onRemoveRoutine: busy ? null : _remove,
        onRemoveGroup: busy ? null : (entry) => confirmUngroup(entry.group),
        onDropOnRoutine: busy ? null : groupByDrop,
        onDropOnGroup: busy
            ? null
            : (dragged, target) => addToGroup(target.group, [dragged.id]),
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

    final scaffold = Scaffold(
      backgroundColor: colors.background,
      // 떠 있는 버튼으로 두어야 알림(토스트)이 버튼을 가리지 않고 그 위에 뜬다
      floatingActionButtonLocation: CreateRoutineFab.location,
      floatingActionButton: CreateRoutineFab(
        isBusy: busy,
        isArranging: _isArranging,
        // 정리 상태에서는 가운데 버튼이 `완료`
        onTap: _isArranging ? _stopArranging : onCreatePressed,
      ),
      // 정리 상태에서 칸·버튼 밖 빈 곳을 누르면 끝낸다 (칸 · ⊖ · 머리 버튼은 자기 탭이 먼저 이긴다)
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _isArranging ? _stopArranging : null,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LibraryManageHeader(),
              SizedBox(height: space.md.h),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );

    // 정리 상태에서 뒤로가기는 화면을 떠나지 않고 정리 상태만 끝낸다
    return PopScope(
      canPop: !_isArranging,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopArranging();
      },
      child: Stack(
        children: [
          scaffold,
          // 처음 들어왔을 때만 연습 무대를 띄운다. 이 자리에는 아무것도 그리지 않는다
          const RoutineManageCoachTrigger(),
        ],
      ),
    );
  }
}
