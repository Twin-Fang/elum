import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../../shared/models/routine.dart';
import '../../application/library_entries.dart';
import '../../application/routine_group_controller.dart';
import '../../domain/routine_group.dart';
import 'routine_group_sheet_row.dart';

/// 묶음 시트가 닫히며 화면에 맡기는 동작 (토스트·다음 시트는 화면이 띄운다)
enum GroupSheetAction { send, addRoutines, openRoutine, ungroupedLastOne }

typedef GroupSheetResult = ({GroupSheetAction action, Routine? routine});

/// 묶음(폴더) 열기 (#807): 이름 · 순서대로 일과 · 손잡이로 순서 바꾸기 · ⊖ 빼기 · 일과 넣기 · 오늘 보내기
///
/// 순서·빼기는 시트 안에서 바로 서버에 반영한다. 목록이 다시 오면 시트도 따라 바뀐다.
Future<GroupSheetResult?> showRoutineGroupSheet(
  BuildContext context, {
  required String groupId,
  bool startsEditing = false,
}) {
  return showElumSheet<GroupSheetResult>(
    context: context,
    builder: (_) =>
        _RoutineGroupSheet(groupId: groupId, startsEditing: startsEditing),
  );
}

class _RoutineGroupSheet extends ConsumerStatefulWidget {
  const _RoutineGroupSheet({
    required this.groupId,
    required this.startsEditing,
  });

  final String groupId;

  /// 순서 편집 상태로 연다 (메뉴 `순서 바꾸기`)
  final bool startsEditing;

  @override
  ConsumerState<_RoutineGroupSheet> createState() => _RoutineGroupSheetState();
}

class _RoutineGroupSheetState extends ConsumerState<_RoutineGroupSheet> {
  /// 서버 반영 전 먼저 보여 주는 순서 (끌어 놓자마자 제자리에 있게). null 이면 서버 순서
  List<Routine>? _pendingOrder;
  bool _isSaving = false;

  /// 순서 편집 중인가 (⊖ · 손잡이가 보인다)
  late bool _isEditing = widget.startsEditing;

  /// 이름 칸: 그 자리에서 바로 고친다. 끝내면(완료 키·칸 밖) 저장
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  String _savedName = '';

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _saveName();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// 이름 저장: 비었거나 그대로면 서버에 보내지 않고 되돌린다
  Future<void> _saveName() async {
    final entry = _currentEntry();
    if (entry == null) return;
    final name = _nameController.text.trim();
    if (name.isEmpty || name == entry.group.name) {
      _nameController.text = entry.group.name;
      return;
    }
    final renamed = await ref
        .read(routineGroupControllerProvider)
        .rename(entry.group, name);
    if (!mounted || renamed.isOk) return;
    _nameController.text = entry.group.name;
    await _showFailure(renamed.failure, 'E-GRP-RENAME');
  }

  LibraryGroupEntry? _currentEntry() => ref
      .read(libraryEntriesProvider)
      .value
      ?.whereType<LibraryGroupEntry>()
      .where((candidate) => candidate.group.id == widget.groupId)
      .firstOrNull;

  /// 시트 높이 (화면 대비)
  static const _heightRatio = 0.85;

  void _close(GroupSheetAction action, [Routine? routine]) =>
      Navigator.of(context).pop((action: action, routine: routine));

  /// 순서 바꾸기: 화면 먼저 > 서버 반영 > 실패면 서버 순서로 되돌림
  Future<void> _reorder(LibraryGroupEntry entry, int from, int to) async {
    final next = [..._pendingOrder ?? entry.routines];
    final moved = next.removeAt(from);
    next.insert(to > from ? to - 1 : to, moved);
    setState(() {
      _pendingOrder = next;
      _isSaving = true;
    });
    final reordered = await ref.read(routineGroupControllerProvider).reorder(
      entry.group,
      [for (final routine in next) routine.id],
    );
    if (!mounted) return;
    setState(() {
      _pendingOrder = null;
      _isSaving = false;
    });
    if (reordered.isOk) return;
    await _showFailure(reordered.failure, 'E-GRP-ORDER');
  }

  /// 빼기: 하나만 남으면 묶음이 풀려 시트를 닫는다
  Future<void> _remove(LibraryGroupEntry entry, Routine routine) async {
    setState(() => _isSaving = true);
    final removal = await ref
        .read(routineGroupControllerProvider)
        .remove(entry.group, routine.id);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (removal.failure != null) {
      await _showFailure(removal.failure, 'E-GRP-REMOVE');
      return;
    }
    if (removal.outcome == RemoveOutcome.ungrouped) {
      _close(GroupSheetAction.ungroupedLastOne);
    }
  }

  Future<void> _showFailure(Object? failure, String code) => showFailure(
    context,
    failure,
    title: context.l10n.routineGroupActionFailedTitle,
    fallback: context.l10n.routineLibraryActionFailedFallback,
    fallbackCode: code,
  );

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(libraryEntriesProvider).value ?? const [];
    final entry = entries
        .whereType<LibraryGroupEntry>()
        .where((candidate) => candidate.group.id == widget.groupId)
        .firstOrNull;
    final media = MediaQuery.of(context);
    return ElumSheetSurface(
      height: media.size.height * _heightRatio,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.space.md.w,
          context.space.lg.h,
          context.space.md.w,
          context.space.md.h + media.padding.bottom,
        ),
        // 다른 기기에서 풀었거나 목록을 다시 받는 중 — 빈 시트 대신 닫기만 남긴다
        child: entry == null
            ? const SizedBox.shrink()
            : _buildBody(context, entry),
      ),
    );
  }

  Widget _buildBody(BuildContext context, LibraryGroupEntry entry) {
    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;
    final routines = _pendingOrder ?? entry.routines;
    // 서버 이름이 바뀌었고 지금 입력 중이 아니면 칸을 따라 맞춘다
    if (!_nameFocus.hasFocus && _savedName != entry.group.name) {
      _savedName = entry.group.name;
      _nameController.text = entry.group.name;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 이름 (그 자리에서 바로 고침) + 순서 편집 / 완료
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameController,
                focusNode: _nameFocus,
                maxLength: RoutineGroup.nameMaxLength,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _nameFocus.unfocus(),
                style: context.typo.sectionTitle.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  border: InputBorder.none,
                  hintText: l10n.routineGroupNameHint,
                  suffixIcon: Icon(
                    Icons.edit_rounded,
                    size: space.md.w,
                    color: colors.textSecondary,
                  ),
                  suffixIconConstraints: BoxConstraints(minWidth: space.xl.w),
                ),
              ),
            ),
            AppPressable(
              onTap: _isSaving
                  ? null
                  : () => setState(() => _isEditing = !_isEditing),
              scaleDown: AppPressable.scaleIcon,
              child: Padding(
                padding: EdgeInsets.all(space.xs.w),
                child: Text(
                  _isEditing
                      ? l10n.libraryArrangeDone
                      : l10n.routineGroupEditOrder,
                  style: context.typo.tileLabel.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: space.xs.h / 2),
        Text(
          _isEditing
              ? '${l10n.routineGroupSheetCount(routines.length)} · '
                    '${l10n.routineGroupSheetDragHint}'
              : l10n.routineGroupSheetCount(routines.length),
          style: context.typo.caption.copyWith(color: colors.textSecondary),
        ),
        SizedBox(height: space.sm.h),
        // 순서대로 일과 (손잡이로 끌어 순서 바꾸기)
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: routines.length,
            onReorder: _isSaving
                ? (_, _) {}
                : (from, to) => _reorder(entry, from, to),
            itemBuilder: (context, index) {
              final routine = routines[index];
              return RoutineGroupSheetRow(
                key: ValueKey(routine.id),
                index: index,
                routine: routine,
                isEnabled: !_isSaving,
                isEditing: _isEditing,
                onTap: () => _close(GroupSheetAction.openRoutine, routine),
                onRemove: () => _remove(entry, routine),
              );
            },
          ),
        ),
        SizedBox(height: space.sm.h),
        // 일과 넣기 · 오늘 보내기
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ElumButton(
                label: l10n.routineGroupSheetAdd,
                backgroundColor: colors.buttonNeutral,
                labelColor: colors.buttonNeutralText,
                onPressed: _isSaving
                    ? null
                    : () => _close(GroupSheetAction.addRoutines),
              ),
            ),
            SizedBox(width: space.xs.w),
            Expanded(
              flex: 3,
              child: ElumButton(
                label: l10n.routineLibrarySendToday,
                loading: _isSaving,
                onPressed: () => _close(GroupSheetAction.send),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
