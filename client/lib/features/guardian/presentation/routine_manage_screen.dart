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
import '../application/routine_library_controller.dart';
import '../application/routine_notifier.dart';
import '../application/routine_providers.dart';
import 'guardian_home_screen.dart';
import 'widgets/library_parts.dart';
import 'widgets/library_quick_menu.dart';
import 'widgets/routine_detail_sheet.dart';
import 'widgets/routine_rename_sheet.dart';

/// 하단 바 일과관리 칸: 만들어 둔 원본 일과를 바탕화면 아이콘처럼 모아 둔다 (#805, 설계 #797)
///
/// 누르면 상세 시트(오늘 보내기 · 카드 고치기), 길게 누르면 빠른 메뉴(보내기 · 이름 · 복사 · 지우기).
/// 가운데 아래 `+ 일과 만들기`. 묶음(폴더)은 #807 에서 이 격자 위에 얹는다.
class RoutineManageScreen extends ConsumerStatefulWidget {
  const RoutineManageScreen({super.key});

  @override
  ConsumerState<RoutineManageScreen> createState() =>
      _RoutineManageScreenState();
}

class _RoutineManageScreenState extends ConsumerState<RoutineManageScreen>
    with BusyStateMixin<RoutineManageScreen> {
  /// `+ 일과 만들기` 버튼 높이 · 아래 여백 (목록 끝이 버튼에 가리지 않게 같은 만큼 비운다)
  static const _createButtonHeight = 54.0;
  static const _createButtonBottom = 16.0;

  // --- 동작 ---

  Future<void> _openDetail(Routine routine) async {
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

  /// `+ 일과 만들기`: 크레딧 확인 > 일과 만들기 흐름 (홈 버튼과 같은 길)
  Future<void> _startCreate() async {
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
    final async = ref.watch(routineLibraryProvider);
    final sentIds = ref.watch(sentTodaySourceIdsProvider);
    final bottomSpace = (_createButtonHeight + _createButtonBottom * 2).h;

    final Widget body = switch (async) {
      AsyncValue(:final value?) when value.isNotEmpty => LibraryGrid(
        routines: value,
        sentIds: sentIds,
        bottomSpace: bottomSpace,
        onTap: busy ? null : _openDetail,
        onLongPress: busy ? null : _openMenu,
      ),
      AsyncValue(:final value?) when value.isEmpty => LibraryEmptyState(
        bottomSpace: bottomSpace,
      ),
      AsyncValue(:final error?) => ElumErrorView.failure(
        error,
        fallback: context.l10n.routineLibraryLoadFailedFallback,
        fallbackCode: 'E-LIB',
        onRetry: () => ref.invalidate(routineLibraryProvider),
      ),
      _ => const Center(child: ElumSpinner()),
    };

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LibraryManageHeader(),
                SizedBox(height: space.md.h),
                Expanded(child: body),
              ],
            ),
            // 가운데 아래 떠 있는 `+ 일과 만들기`
            Positioned(
              left: 0,
              right: 0,
              bottom: _createButtonBottom.h,
              child: Center(
                child: CreateRoutineFab(
                  height: _createButtonHeight.h,
                  isBusy: busy,
                  onTap: _startCreate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
