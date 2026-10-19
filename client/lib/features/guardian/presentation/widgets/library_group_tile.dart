import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../application/library_entries.dart';
import 'library_routine_tile.dart';

/// 일과관리 격자의 묶음(폴더) 칸: 안 일과 그림 최대 4개(2×2) + 묶음 이름 + 일과 수 (#807)
///
/// 휴대폰 바탕화면 폴더처럼 보인다. 안의 일과를 모두 오늘 보냈으면 ✓.
class LibraryGroupTile extends StatelessWidget {
  const LibraryGroupTile({
    super.key,
    required this.entry,
    required this.isSentToday,
    required this.isDropTarget,
    required this.onTap,
    required this.onLongPress,
  });

  final LibraryGroupEntry entry;
  final bool isSentToday;

  /// 끌어 온 일과가 이 묶음 위에 있다 — 넣을 자리라는 걸 키워서 보여 준다
  final bool isDropTarget;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// 미리보기 칸 수 (2×2)
  static const _previewCount = 4;

  /// 끌어 온 일과가 위에 있을 때 키우는 비율
  static const _dropScale = 1.12;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final size = LibraryRoutineTile.iconSize.w;
    final gap = space.xs.w / 2;
    final previews = entry.routines.take(_previewCount).toList();
    final count = entry.routines.length;
    final label = context.l10n.routineGroupTileLabel(entry.group.name, count);

    return Semantics(
      label: isSentToday
          ? '$label, ${context.l10n.routineLibrarySentBadge}'
          : label,
      hint: context.l10n.routineLibraryTileHint,
      button: true,
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        onLongPress: onLongPress,
        scaleDown: AppPressable.scaleIcon,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isDropTarget ? _dropScale : 1,
                  duration: AppMotion.fast,
                  child: Container(
                    width: size,
                    height: size,
                    padding: EdgeInsets.all(gap * 2),
                    decoration: BoxDecoration(
                      color: isDropTarget
                          ? colors.navSelectedFill
                          : colors.folderFill,
                      borderRadius: BorderRadius.circular(
                        LibraryRoutineTile.iconRadius.w,
                      ),
                    ),
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: gap,
                      crossAxisSpacing: gap,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        for (final routine in previews)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(gap * 2),
                            child: LibraryRoutineThumbnail(routine: routine),
                          ),
                      ],
                    ),
                  ),
                ),
                if (isSentToday)
                  Positioned(
                    right: -space.xs.w / 2,
                    bottom: -space.xs.w / 2,
                    child: LibrarySentBadge(
                      size: LibraryRoutineTile.badgeSize.w,
                    ),
                  ),
              ],
            ),
            SizedBox(height: space.xs.h),
            Text(
              entry.group.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.typo.caption.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
