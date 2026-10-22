import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/routine_preview_hook.dart';
import '../../../../shared/models/routine.dart';

/// 가져오기 시트 묶음 한 칸: 묶음 id · 이름 · 안 일과 (그림 미리보기용)
typedef TalkImportGroupChoice = ({
  String id,
  String name,
  List<Routine> routines,
});

/// 가져오기 시트 묶음 격자 (시안 1860:8578): 4열 폴더 칸, 누르면 고르고 다시 누르면 풀린다
/// 아무것도 안 고르면 묶음 없이 넣는다 (부르는 쪽이 판단)
class TalkImportGroupGrid extends StatelessWidget {
  const TalkImportGroupGrid({
    super.key,
    required this.groups,
    required this.selectedGroupId,
    required this.onSelected,
  });

  final List<TalkImportGroupChoice> groups;
  final String? selectedGroupId;

  /// 고른 칸을 다시 누르면 null (null 이면 누를 수 없다: 넣는 중)
  final ValueChanged<String?>? onSelected;

  /// 칸 폭 · 칸 사이 · 줄 사이 (시안 84 · 8 · 16, 본문 361 에 4칸)
  static const _cellWidth = 84.0;
  static const _columnGap = 8.0;
  static const _rowGap = 16.0;

  @override
  Widget build(BuildContext context) {
    final onSelected = this.onSelected;
    return Wrap(
      spacing: _columnGap.w,
      runSpacing: _rowGap.h,
      children: [
        for (final group in groups)
          SizedBox(
            width: _cellWidth.w,
            child: _GroupCell(
              group: group,
              isSelected: group.id == selectedGroupId,
              onTap: onSelected == null
                  ? null
                  : () => onSelected(
                      group.id == selectedGroupId ? null : group.id,
                    ),
            ),
          ),
      ],
    );
  }
}

/// 폴더 칸 68 (안 일과 그림 2×2) > 이름 (시안 1869:8958)
class _GroupCell extends ConsumerWidget {
  const _GroupCell({
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  final TalkImportGroupChoice group;
  final bool isSelected;
  final VoidCallback? onTap;

  /// 폴더 한 변 · 둥글기 · 안쪽 · 테두리 · 폴더 > 이름 (일과관리 폴더 칸과 같은 68 · 16 · 8 · 1, 시안 8)
  static const _iconSize = 68.0;
  static const _iconRadius = 16.0;
  static const _iconPadding = 8.0;
  static const _strokeWidth = 1.0;
  static const _iconToLabel = 8.0;
  static const _labelMaxLines = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final radius = BorderRadius.circular(_iconRadius.w);
    final buildPreview = ref.watch(routineGroupPreviewBuilderProvider);

    return Semantics(
      button: true,
      selected: isSelected,
      label: group.name,
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        scaleDown: AppPressable.scaleIcon,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              width: _iconSize.w,
              height: _iconSize.w,
              padding: EdgeInsets.all(_iconPadding.w),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.talkImportGroupSelectedFill
                    : colors.folderFill,
                borderRadius: radius,
              ),
              // 테두리는 위에 덧그린다 (안쪽 그림이 두께만큼 밀리지 않게)
              foregroundDecoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: isSelected
                      ? colors.talkImportGroupSelectedStroke
                      : colors.folderStroke,
                  width: _strokeWidth,
                ),
              ),
              child: buildPreview(group.routines),
            ),
            SizedBox(height: _iconToLabel.h),
            Text(
              group.name,
              maxLines: _labelMaxLines,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.typo.libraryTileLabel.copyWith(
                color: colors.libraryTileLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
