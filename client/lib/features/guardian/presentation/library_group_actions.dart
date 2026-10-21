import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/server_error_code.dart';
import '../../../core/state/busy_state_mixin.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../shared/models/routine.dart';
import '../application/library_entries.dart';
import '../application/routine_group_controller.dart';
import '../application/routine_library_controller.dart';
import '../application/routine_providers.dart';
import '../domain/routine_group.dart';
import 'widgets/library_entry_grid.dart' show LibraryMenuAnchor;
import 'widgets/library_quick_menu.dart';
import 'widgets/routine_group_picker_sheet.dart';
import 'widgets/routine_group_sheet.dart';
import 'widgets/routine_rename_sheet.dart';

/// 일과관리 칸의 묶음 동작 (#807): 열기 · 메뉴 · 만들기 · 넣기 · 끌어 묶기 · 보내기 · 이름 · 복사 · 풀기
///
/// 성공은 토스트, 실패는 에러 코드 팝업(E-GRP-*). 격자는 실패해도 그대로 둔다.
mixin LibraryGroupActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, BusyStateMixin<T> {
  /// 묶음 안 일과를 눌렀을 때 — 낱개 상세와 같은 길
  Future<void> openRoutineDetail(Routine routine, {bool isInGroup = false});

  /// 새 일과 만들기 흐름 (크레딧 확인 포함)
  Future<void> startCreateRoutine();

  RoutineGroupController get _groups =>
      ref.read(routineGroupControllerProvider);

  /// 묶음 밖 낱개 원본 (새 묶음·넣기 후보)
  List<Routine> get _looseRoutines => [
    for (final entry in ref.read(libraryEntriesProvider).value ?? const [])
      if (entry case LibraryRoutineEntry(:final routine)) routine,
  ];

  List<LibraryGroupEntry> get _groupEntries => [
    ...?ref.read(libraryEntriesProvider).value?.whereType<LibraryGroupEntry>(),
  ];

  // --- 열기 · 메뉴 ---

  Future<void> openGroup(
    LibraryGroupEntry entry, {
    bool startsEditing = false,
  }) async {
    final sheetResult = await showRoutineGroupSheet(
      context,
      groupId: entry.group.id,
      startsEditing: startsEditing,
    );
    if (!mounted || sheetResult == null) return;
    switch (sheetResult.action) {
      case GroupSheetAction.send:
        await _sendGroup(entry);
      case GroupSheetAction.addRoutines:
        await _pickIntoGroup(entry.group);
      case GroupSheetAction.openRoutine:
        if (sheetResult.routine case final routine?) {
          await openRoutineDetail(routine, isInGroup: true);
        }
      case GroupSheetAction.ungroupedLastOne:
        showElumToast(context, context.l10n.routineGroupUngroupedLastOne);
    }
  }

  Future<void> openGroupMenu(
    LibraryGroupEntry entry,
    LibraryMenuAnchor anchor,
  ) async {
    final action = await showGroupQuickMenu(
      context,
      anchor: anchor.rect,
      highlight: anchor.tile,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case GroupMenuAction.send:
        await _sendGroup(entry);
      case GroupMenuAction.rename:
        await _renameGroup(entry.group);
      // 순서는 묶음을 순서 편집 상태로 열어 바꾼다
      case GroupMenuAction.reorder:
        await openGroup(entry, startsEditing: true);
      case GroupMenuAction.copy:
        await _run(
          () => _failureOf(_groups.copy(entry.group)),
          success: context.l10n.routineLibraryCopied,
          code: 'E-GRP-COPY',
        );
      case GroupMenuAction.ungroup:
        await confirmUngroup(entry.group);
    }
  }

  // --- 만들기 · 넣기 ---

  /// `+ 일과 만들기`: 묶을 낱개가 2개 이상이면 새 일과/새 묶음 고르기, 아니면 바로 새 일과
  Future<void> onCreatePressed() async {
    if (_looseRoutines.length < RoutineGroup.minimumRoutineCount) {
      return startCreateRoutine();
    }
    final l10n = context.l10n;
    // value: 새 묶음인가
    final isNewGroup = await showQuickMenuSheet<bool>(
      context,
      title: l10n.routineGroupCreateMenuTitle,
      rows: [
        (
          value: false,
          icon: Icons.add_rounded,
          label: l10n.routineGroupCreateRoutine,
          isDanger: false,
        ),
        (
          value: true,
          icon: Icons.create_new_folder_outlined,
          label: l10n.routineGroupCreateGroup,
          isDanger: false,
        ),
      ],
    );
    if (!mounted || isNewGroup == null) return;
    return isNewGroup ? createGroupWithPicker() : startCreateRoutine();
  }

  /// 새 묶음: 고르기 시트(이름 + 2개 이상) > 만들기. [preselectedIds] 는 먼저 골라 둔 일과
  Future<void> createGroupWithPicker({
    List<String> preselectedIds = const [],
  }) async {
    final picked = await showRoutineGroupPicker(
      context,
      candidates: _looseRoutines,
      preselectedIds: preselectedIds,
    );
    if (!mounted || picked == null) return;
    await _run(
      () => _failureOf(_groups.create(picked.name, picked.routineIds)),
      success: context.l10n.routineGroupCreated,
      code: 'E-GRP-CREATE',
    );
  }

  /// 낱개 메뉴 `묶음에 넣기`: 묶음이 있으면 고르게, 없으면 바로 새 묶음
  Future<void> chooseGroupFor(Routine routine) async {
    final groups = _groupEntries;
    if (groups.isEmpty) {
      await createGroupWithPicker(preselectedIds: [routine.id]);
      return;
    }
    final l10n = context.l10n;
    final target = await showQuickMenuSheet<({RoutineGroup? group})>(
      context,
      title: l10n.routineGroupChooseTitle,
      rows: [
        for (final entry in groups)
          (
            value: (group: entry.group),
            icon: Icons.folder_rounded,
            label: entry.group.name,
            isDanger: false,
          ),
        (
          value: (group: null),
          icon: Icons.create_new_folder_outlined,
          label: l10n.routineGroupCreateGroup,
          isDanger: false,
        ),
      ],
    );
    if (!mounted || target == null) return;
    final group = target.group;
    if (group == null) {
      await createGroupWithPicker(preselectedIds: [routine.id]);
      return;
    }
    await addToGroup(group, [routine.id]);
  }

  Future<void> addToGroup(RoutineGroup group, List<String> routineIds) => _run(
    () => _failureOf(_groups.add(group, routineIds)),
    success: context.l10n.routineGroupAdded,
    code: 'E-GRP-ADD',
  );

  /// 끌어 묶기: 놓인 자리 일과가 앞, 끌어 온 일과가 뒤. 이름은 기본 이름 (나중에 바꾼다)
  Future<void> groupByDrop(Routine dragged, Routine target) => _run(
    () => _failureOf(
      _groups.create(context.l10n.routineGroupDefaultName, [
        target.id,
        dragged.id,
      ]),
    ),
    success: context.l10n.routineGroupCreated,
    code: 'E-GRP-CREATE',
  );

  Future<void> _pickIntoGroup(RoutineGroup group) async {
    final picked = await showRoutineGroupPicker(
      context,
      candidates: _looseRoutines,
      groupName: group.name,
    );
    if (!mounted || picked == null) return;
    await addToGroup(group, picked.routineIds);
  }

  // --- 보내기 · 이름 · 풀기 ---

  /// 묶음째 오늘 보내기. 안의 일과를 이미 다 보냈으면 서버에 가지 않는다
  Future<void> _sendGroup(LibraryGroupEntry entry) async {
    final l10n = context.l10n;
    final sentIds = ref.read(sentTodaySourceIdsProvider);
    if (entry.routines.every((routine) => sentIds.contains(routine.id))) {
      showElumToast(context, l10n.routineGroupAllSentAlready);
      return;
    }
    final sendAttempt = await runBusy(() => _groups.sendToday(entry.group));
    if (sendAttempt == null || !mounted) return;
    if (sendAttempt.isOk) {
      showElumToast(context, l10n.routineGroupSent(entry.group.name));
      return;
    }
    // 다른 기기에서 먼저 다 보냈다 — 실패 팝업이 아니라 안내로 충분하다
    if (sendAttempt.failure?.server?.code ==
        ServerErrorCode.routineAlreadySentToday) {
      ref.refreshRoutines();
      showElumToast(context, l10n.routineGroupAllSentAlready);
      return;
    }
    await showFailure(
      context,
      sendAttempt.failure,
      title: l10n.routineLibrarySendFailedTitle,
      fallback: l10n.routineLibraryActionFailedFallback,
      fallbackCode: 'E-GRP-SEND',
    );
  }

  Future<void> _renameGroup(RoutineGroup group) async {
    final name = await showRoutineRenameSheet(
      context,
      currentTitle: group.name,
      maxLength: RoutineGroup.nameMaxLength,
      hintText: context.l10n.routineGroupNameHint,
    );
    if (!mounted || name == null) return;
    await _run(
      () => _failureOf(_groups.rename(group, name)),
      success: context.l10n.routineLibraryRenamed,
      code: 'E-GRP-RENAME',
    );
  }

  /// 풀기: 확인 팝업 > 풀기 (안의 일과는 낱개로 남는다)
  /// 묶음 풀기 확인 > 풀기. 정리 상태 ⊖ 와 메뉴가 같이 쓴다
  Future<void> confirmUngroup(RoutineGroup group) async {
    final l10n = context.l10n;
    final isConfirmed = await showElumDialog<bool>(
      context: context,
      icon: ElumDialogIcon.alert,
      title: l10n.routineGroupUngroupConfirmTitle,
      message: l10n.routineGroupUngroupConfirmMessage,
      keepWordsInMessage: true,
      actions: [
        ElumDialogAction(
          label: l10n.commonCancel,
          value: false,
          tone: ElumDialogTone.neutral,
        ),
        ElumDialogAction(
          label: l10n.routineGroupMenuUngroup,
          value: true,
          tone: ElumDialogTone.primary,
        ),
      ],
    );
    if (isConfirmed != true || !mounted) return;
    await _run(
      () => _groups.ungroup(group),
      success: l10n.routineGroupUngrouped,
      code: 'E-GRP-UNGROUP',
    );
  }

  Future<AppFailure?> _failureOf<R>(Future<Attempt<R>> call) async =>
      (await call).failure;

  /// 묶음 동작 공통: 잠금 > 실행 > 성공 토스트 / 실패 팝업
  Future<void> _run(
    Future<AppFailure?> Function() task, {
    required String success,
    required String code,
  }) async {
    final outcome = await runBusy(() async => (failure: await task()));
    if (outcome == null || !mounted) return;
    if (outcome.failure == null) {
      showElumToast(context, success);
      return;
    }
    await showFailure(
      context,
      outcome.failure,
      title: context.l10n.routineGroupActionFailedTitle,
      fallback: context.l10n.routineLibraryActionFailedFallback,
      fallbackCode: code,
    );
  }
}
