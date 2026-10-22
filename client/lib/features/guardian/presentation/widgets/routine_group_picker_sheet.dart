import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../core/widgets/elum_sheet_text_field.dart';
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

  /// 목록 최대 높이 (화면 대비)
  static const _listHeightRatio = 0.4;

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
    final groupName = widget.groupName;
    // 목록 최대 높이 — 목록이 길어도 이름 칸과 버튼이 한 화면에 보이게
    final listMaxHeight = MediaQuery.sizeOf(context).height * _listHeightRatio;

    // 틀 (시안 1877:9740): 제목 > 안내 > 이름 칸 > 고를 일과 목록 > 버튼
    return ElumSheetFrame(
      title: groupName == null
          ? l10n.routineGroupNewTitle
          : l10n.routineGroupAddTitle(groupName),
      description: _isNewGroup
          ? l10n.routineGroupPickHintNew
          : l10n.routineGroupPickHint,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 새 묶음이면 이름 칸 (안내는 칸 안 placeholder)
          if (_isNewGroup) ...[
            ElumSheetTextField(
              controller: _nameController,
              hintText: l10n.routineGroupNameHint,
              maxLength: RoutineGroup.nameMaxLength,
            ),
            SizedBox(height: space.md.h),
          ],
          // 고를 일과 목록
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: listMaxHeight),
            child: widget.candidates.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: space.lg.h),
                    child: Text(
                      l10n.routineGroupPickEmpty,
                      textAlign: TextAlign.center,
                      style: context.typo.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: widget.candidates.length,
                    separatorBuilder: (_, _) => SizedBox(height: space.xs.h),
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
          SizedBox(height: space.lg.h),
          ElumButton(
            label: _isNewGroup
                ? l10n.routineGroupPickConfirmNew(_picked.length)
                : l10n.routineGroupPickConfirmAdd(_picked.length),
            onPressed: _canConfirm ? _confirm : null,
          ),
        ],
      ),
    );
  }
}

/// 고르기 한 줄 (웜그레이 판 r20, 고름 = 민트 연 면 + 1px 민트): 그림 + 이름 + 누른 순서 번호(안 골랐으면 빈 원)
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
    final isPicked = number != null;
    return Semantics(
      selected: isPicked,
      button: true,
      child: AppPressable(
        onTap: onTap,
        scaleDown: AppPressable.scaleCard,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: EdgeInsets.all(space.xs.w),
          decoration: BoxDecoration(
            color: isPicked ? colors.goalSelectedFill : colors.editChipBg,
            borderRadius: BorderRadius.circular(space.cardRadius.r),
            border: Border.all(
              color: isPicked ? colors.checkDone : colors.editChipBg,
              width: space.borderWidth,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(space.sm.r),
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
                    style: context.typo.routineTileTitle.copyWith(
                      color: colors.settingsCardLabel,
                    ),
                  ),
                ),
              ),
              SizedBox(width: space.sm.w),
              // 순서 원: 안 고름 = 회색 테두리, 고름 = 민트 원 + 흰 번호 (체크 원과 같은 결)
              Container(
                width: _orderSize.w,
                height: _orderSize.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPicked ? colors.checkDone : null,
                  border: Border.all(
                    color: isPicked
                        ? colors.checkDone
                        : colors.consentCheckIdle,
                    width: space.borderWidth,
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
