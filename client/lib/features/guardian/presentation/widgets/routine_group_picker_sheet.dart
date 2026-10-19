import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_text_field.dart';
import '../../../../shared/models/routine.dart';
import '../../domain/routine_group.dart';
import 'library_routine_tile.dart';

/// 일과 고르기 결과: 묶음 이름(새 묶음일 때) + 누른 순서대로의 일과 id
typedef RoutinePickResult = ({String name, List<String> routineIds});

/// 일과 고르기 시트 (#807): 끌기를 몰라도 묶음을 만들고 넣을 수 있는 길
///
/// 누른 순서대로 1·2·3 번호가 붙고 그 순서가 묶음 순서가 된다.
/// [groupName] 이 null 이면 새 묶음(이름 + 2개 이상), 있으면 그 묶음에 넣기(1개 이상).
Future<RoutinePickResult?> showRoutineGroupPicker(
  BuildContext context, {
  required List<Routine> candidates,
  String? groupName,
  List<String> preselectedIds = const [],
}) {
  return showElumSheet<RoutinePickResult>(
    context: context,
    builder: (_) => _RoutineGroupPicker(
      candidates: candidates,
      groupName: groupName,
      preselectedIds: preselectedIds,
    ),
  );
}

class _RoutineGroupPicker extends StatefulWidget {
  const _RoutineGroupPicker({
    required this.candidates,
    required this.groupName,
    required this.preselectedIds,
  });

  final List<Routine> candidates;
  final String? groupName;
  final List<String> preselectedIds;

  @override
  State<_RoutineGroupPicker> createState() => _RoutineGroupPickerState();
}

class _RoutineGroupPickerState extends State<_RoutineGroupPicker> {
  late final _nameController = TextEditingController();
  late final List<String> _picked = [...widget.preselectedIds];

  /// 시트 높이 (화면 대비) — 목록이 길어도 이름 칸과 버튼이 늘 보이게
  static const _heightRatio = 0.85;

  bool get _isNewGroup => widget.groupName == null;

  bool get _canConfirm => _isNewGroup
      ? _picked.length >= RoutineGroup.minimumRoutineCount
      : _picked.isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggle(String id) => setState(() {
    if (!_picked.remove(id)) _picked.add(id);
  });

  void _confirm() {
    if (!_canConfirm) return;
    // 이름을 비우면 기본 이름 — 나중에 바꿀 수 있다
    final typed = _nameController.text.trim();
    final name = typed.isEmpty ? context.l10n.routineGroupDefaultName : typed;
    Navigator.of(context).pop((name: name, routineIds: List.of(_picked)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;
    final media = MediaQuery.of(context);
    final groupName = widget.groupName;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ElumSheetSurface(
        height: media.size.height * _heightRatio,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            space.md.w,
            space.lg.h,
            space.md.w,
            space.md.h + media.padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 제목
              Text(
                groupName == null
                    ? l10n.routineGroupNewTitle
                    : l10n.routineGroupAddTitle(groupName),
                style: context.typo.sectionTitle.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              // 새 묶음이면 이름 칸
              if (_isNewGroup) ...[
                SizedBox(height: space.sm.h),
                ElumTextField(
                  controller: _nameController,
                  hintText: l10n.routineGroupNameHint,
                  maxLength: RoutineGroup.nameMaxLength,
                ),
              ],
              SizedBox(height: space.xs.h),
              Text(
                _isNewGroup
                    ? l10n.routineGroupPickHintNew
                    : l10n.routineGroupPickHint,
                style: context.typo.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: space.sm.h),
              // 고를 일과 목록
              Expanded(
                child: widget.candidates.isEmpty
                    ? Center(
                        child: Text(
                          l10n.routineGroupPickEmpty,
                          textAlign: TextAlign.center,
                          style: context.typo.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: widget.candidates.length,
                        separatorBuilder: (_, _) =>
                            SizedBox(height: space.xs.h),
                        itemBuilder: (context, index) {
                          final routine = widget.candidates[index];
                          final order = _picked.indexOf(routine.id);
                          return _PickRow(
                            routine: routine,
                            order: order < 0 ? null : order + 1,
                            onTap: () => _toggle(routine.id),
                          );
                        },
                      ),
              ),
              SizedBox(height: space.sm.h),
              ElumButton(
                label: _isNewGroup
                    ? l10n.routineGroupPickConfirmNew(_picked.length)
                    : l10n.routineGroupPickConfirmAdd(_picked.length),
                onPressed: _canConfirm ? _confirm : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 고르기 한 줄: 그림 + 이름 + 누른 순서 번호(안 골랐으면 빈 원)
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.routine,
    required this.order,
    required this.onTap,
  });

  final Routine routine;

  /// 고른 순서(1부터). 안 골랐으면 null
  final int? order;
  final VoidCallback onTap;

  /// 그림 한 변 · 순서 원 한 변
  static const _thumbnailSize = 44.0;
  static const _orderSize = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final number = order;
    return Semantics(
      selected: number != null,
      button: true,
      child: AppPressable(
        onTap: onTap,
        scaleDown: AppPressable.scaleCard,
        child: Container(
          padding: EdgeInsets.all(space.xs.w),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(space.sm.w),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(space.xs.w),
                child: SizedBox.square(
                  dimension: _thumbnailSize.w,
                  child: LibraryRoutineThumbnail(routine: routine),
                ),
              ),
              SizedBox(width: space.sm.w),
              Expanded(
                child: ContentLocale(
                  language: routine.language,
                  child: Text(
                    routine.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typo.tileLabel.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              Container(
                width: _orderSize.w,
                height: _orderSize.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: number == null ? null : colors.textPrimary,
                  border: Border.all(
                    color: number == null
                        ? colors.navIconUnselected
                        : colors.textPrimary,
                    width: 2,
                  ),
                ),
                child: number == null
                    ? null
                    : Text(
                        '$number',
                        style: context.typo.caption.copyWith(
                          color: colors.surface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
