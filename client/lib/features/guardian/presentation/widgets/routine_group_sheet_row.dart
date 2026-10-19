import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../shared/models/routine.dart';
import 'library_routine_tile.dart';

/// 묶음 시트 한 줄: ⊖ 빼기 · 순서 번호 · 그림 · 이름(누르면 상세) · 끌기 손잡이 (#807)
class RoutineGroupSheetRow extends StatelessWidget {
  const RoutineGroupSheetRow({
    super.key,
    required this.index,
    required this.routine,
    required this.isEnabled,
    required this.onTap,
    required this.onRemove,
  });

  /// 묶음 안 순서 (0부터) — 화면에는 1부터
  final int index;
  final Routine routine;

  /// 저장 중이면 누르기·빼기를 막는다
  final bool isEnabled;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  /// 그림 한 변 · 아이콘 한 변
  static const _thumbnailSize = 44.0;
  static const _iconSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return Padding(
      padding: EdgeInsets.only(bottom: space.xs.h),
      child: Container(
        padding: EdgeInsets.all(space.xs.w),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(space.sm.w),
        ),
        child: Row(
          children: [
            // 빼기
            AppPressable(
              onTap: isEnabled ? onRemove : null,
              scaleDown: AppPressable.scaleIcon,
              semanticLabel: context.l10n.routineGroupSheetRemove(
                routine.displayTitle,
              ),
              child: Icon(
                Icons.remove_circle_rounded,
                size: _iconSize.w,
                color: colors.danger,
              ),
            ),
            SizedBox(width: space.xs.w),
            // 순서 번호
            Text(
              '${index + 1}',
              style: context.typo.caption.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: space.xs.w),
            // 그림 + 이름 (누르면 상세)
            Expanded(
              child: AppPressable(
                onTap: isEnabled ? onTap : null,
                scaleDown: AppPressable.scaleCard,
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
                  ],
                ),
              ),
            ),
            // 끌기 손잡이 (누르자마자 끌린다)
            ReorderableDragStartListener(
              index: index,
              enabled: isEnabled,
              child: Padding(
                padding: EdgeInsets.all(space.xs.w),
                child: Icon(
                  Icons.drag_handle_rounded,
                  size: _iconSize.w,
                  color: colors.navIconUnselected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
