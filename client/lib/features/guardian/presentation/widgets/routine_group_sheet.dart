import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_dialog.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/reorder_finger_follow.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../../../shared/models/routine.dart';
import '../../application/library_entries.dart';
import '../../application/routine_group_controller.dart';
import 'routine_detail_step_badge.dart';
import 'routine_group_sheet_header.dart';
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

  /// 지금 끌려가는 줄의 자리 (들어올림 연출을 이어 가려고 줄에 알려 준다)
  int? _draggingIndex;

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

  /// 시트 윗변 > 제목 (`ElumSheetFrame` 과 같은 40)
  static const _titleTop = 40.0;

  /// 왼쪽 번호 칸 폭 · 번호 칸 ↔ 카드
  static const _badgeWidth = 40.0;
  static const _badgeToCard = 4.0;

  /// 아래 두 버튼 사이 (시트 버튼 둘 결)
  static const _buttonGap = 4.0;

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

  /// 빼기: 확인 > 묶음에서 빼기, 하나만 남으면 묶음이 풀려 시트를 닫는다
  Future<void> _remove(LibraryGroupEntry entry, Routine routine) async {
    if (!await _confirmRemove(routine) || !mounted) return;
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

  /// ⊖ 확인: 지우기가 아니라 묶음에서 빼기 (일과는 일과 관리에 남는다). 빼기를 골랐으면 true
  Future<bool> _confirmRemove(Routine routine) async {
    final l10n = context.l10n;
    final isConfirmed = await showElumDialog<bool>(
      context: context,
      icon: ElumDialogIcon.alert,
      title: l10n.routineGroupRemoveConfirmTitle(routine.displayTitle),
      message: l10n.routineGroupRemoveConfirmMessage,
      keepWordsInMessage: true,
      actions: [
        ElumDialogAction(
          label: l10n.commonCancel,
          value: false,
          tone: ElumDialogTone.neutral,
        ),
        ElumDialogAction(
          label: l10n.routineGroupRemoveConfirmAction,
          value: true,
          tone: ElumDialogTone.primary,
        ),
      ],
    );
    return isConfirmed == true;
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
    return PopScope(
      // 편집 중 뒤로가기는 편집만 끝낸다 (시트는 한 번 더 눌러야 닫힘). ✕ · 끌어 내리기는 그대로 닫는다
      canPop: !_isEditing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _isEditing = false);
      },
      child: ElumSheetSurface(
        height: media.size.height * _heightRatio,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.space.md.w,
            _titleTop.h,
            context.space.md.w,
            context.space.md.h + media.padding.bottom,
          ),
          // 다른 기기에서 풀었거나 목록을 다시 받는 중 — 빈 시트 대신 닫기만 남긴다
          child: entry == null
              ? const SizedBox.shrink()
              : _buildBody(context, entry),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, LibraryGroupEntry entry) {
    final l10n = context.l10n;
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
        // 머리 (시트 제목 결, 왼쪽 x=24): 이름(그 자리에서 고침) · 편집/완료 · ✕, 아래 일과 N개
        RoutineGroupSheetHeader(
          nameController: _nameController,
          nameFocus: _nameFocus,
          routineCount: routines.length,
          isEditing: _isEditing,
          onEditToggle: _isSaving
              ? null
              : () => setState(() => _isEditing = !_isEditing),
        ),
        SizedBox(height: space.lg.h),
        // 순서대로 일과: 번호 칸과 카드 칸을 나란히 따로 둔다 (행동카드 순서 변경과 같은 구조).
        // 한 줄로 묶으면 끄는 동안 번호가 카드를 따라 미끄러진다. 번호는 몇 번째 자리인가를 뜻하므로
        // 제자리에 두고 카드만 순서 바꾸기에 올린다. 한 스크롤 안이라 가장자리 자동 스크롤도 하나로 돈다
        Expanded(
          // 들린 줄을 가로로도 손가락에 붙인다
          child: ReorderFingerFollow(
            builder: (context, follow) => CustomScrollView(
              slivers: [
                SliverCrossAxisGroup(
                  slivers: [
                    SliverConstrainedCrossAxis(
                      // 번호 칸 40 + 카드와의 틈 4
                      maxExtent: (_badgeWidth + _badgeToCard).w,
                      sliver: SliverList.builder(
                        itemCount: routines.length,
                        itemBuilder: (context, index) => Padding(
                          padding: EdgeInsets.only(
                            right: _badgeToCard.w,
                            bottom: space.xs.h,
                          ),
                          child: RoutineDetailStepBadge(index: index),
                        ),
                      ),
                    ),
                    SliverReorderableList(
                      // 기본 프록시는 시트 밖 화면 위로 떠올라 엉뚱한 자리에 그려진다.
                      // 들어올림은 줄이 직접 그리므로 여기서는 자리만 잡아 준다
                      proxyDecorator: (child, index, animation) =>
                          follow.decorate(
                            Material(color: Colors.transparent, child: child),
                          ),
                      itemCount: routines.length,
                      onReorder: _isSaving
                          ? (_, _) {}
                          : (from, to) => _reorder(entry, from, to),
                      onReorderStart: (index) {
                        follow.start();
                        setState(() => _draggingIndex = index);
                      },
                      onReorderEnd: (_) {
                        follow.end();
                        setState(() => _draggingIndex = null);
                      },
                      itemBuilder: (context, index) {
                        final routine = routines[index];
                        // 전역 키로 한 번 더 감싼다: 끌기가 시작되면 목록이 이 줄을 빼고 사본으로
                        // 다시 그려, 키가 없으면 줄 상태가 버려져 놓을 때 들림 연출 되돌리기가 터진다
                        return KeyedSubtree(
                          key: ValueKey(routine.id),
                          child: KeyedSubtree(
                            key: _RowItemKey(routine.id, this),
                            child: Padding(
                              padding: EdgeInsets.only(bottom: space.xs.h),
                              child: RoutineGroupSheetRow(
                                index: index,
                                routine: routine,
                                isEnabled: !_isSaving,
                                isEditing: _isEditing,
                                isDragging: _draggingIndex == index,
                                onTap: () => _close(
                                  GroupSheetAction.openRoutine,
                                  routine,
                                ),
                                onRemove: () => _remove(entry, routine),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: space.sm.h),
        // 일과 넣기(보조, 웜그레이 + 남색 글) · 사이 4 · 오늘 보내기
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ElumButton(
                label: l10n.routineGroupSheetAdd,
                backgroundColor: context.colors.buttonNeutral,
                labelColor: context.colors.buttonNeutralText,
                onPressed: _isSaving
                    ? null
                    : () => _close(GroupSheetAction.addRoutines),
              ),
            ),
            SizedBox(width: _buttonGap.w),
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

/// 줄의 전역 키. 같은 일과면 같은 키가 되도록 id 와 시트 상태로 비교한다
class _RowItemKey extends GlobalObjectKey {
  const _RowItemKey(this.id, this.sheet) : super(id);

  final String id;
  final State sheet;

  @override
  bool operator ==(Object other) =>
      other is _RowItemKey && other.id == id && other.sheet == sheet;

  @override
  int get hashCode => Object.hash(id, sheet);
}
