import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../shared/models/routine.dart';
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

  /// null 이면 길게 누르기를 바깥(끌기)에 맡긴다
  final VoidCallback? onLongPress;

  /// 미리보기 칸 수 (2×2, 왼쪽 위부터 줄 순서로 채운다)
  static const _previewCount = 4;
  static const _previewColumns = 2;

  /// 미리보기 그림 한 변 · 둥글기 · 칸 안쪽 여백 · 그림 사이 (시안 1664:6876: 68 칸 = 8 + 24 + 4 + 24 + 8)
  static const _previewCellSize = 24.0;
  static const _previewCellRadius = 4.0;
  static const _previewPadding = 8.0;
  static const _previewGap = 4.0;

  /// 칸 테두리 두께 (안쪽)
  static const _strokeWidth = 1.0;

  /// 미리보기 그림을 먼저 그리는 크기 (논리 픽셀). 이 크기로 그려 칸에 맞춰 줄인다
  static const _previewRenderSize = 100.0;

  /// 끌어 온 일과가 위에 있을 때 키우는 비율
  static const _dropScale = 1.12;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final size = LibraryRoutineTile.iconSize.w;
    final radius = BorderRadius.circular(LibraryRoutineTile.iconRadius.w);
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
                    padding: EdgeInsets.all(_previewPadding.w),
                    decoration: BoxDecoration(
                      color: isDropTarget
                          ? colors.navSelectedFill
                          : colors.folderFill,
                      borderRadius: radius,
                    ),
                    // 테두리는 위에 덧그린다 — decoration 에 넣으면 두께만큼 안쪽 그림이 밀린다
                    foregroundDecoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: colors.folderStroke,
                        width: _strokeWidth,
                      ),
                    ),
                    child: RoutineGroupPreviewGrid(routines: previews),
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

/// 묶음 안 일과 그림 2×2 (빈 자리는 바탕만). 이야기 가져오기 시트도 core 연결 고리로 쓴다
class RoutineGroupPreviewGrid extends StatelessWidget {
  const RoutineGroupPreviewGrid({super.key, required this.routines});

  final List<Routine> routines;

  @override
  Widget build(BuildContext context) {
    final cellSize = LibraryGroupTile._previewCellSize.w;
    final gap = LibraryGroupTile._previewGap.w;
    final rowCount =
        (LibraryGroupTile._previewCount / LibraryGroupTile._previewColumns)
            .ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var row = 0; row < rowCount; row++) ...[
          if (row > 0) SizedBox(height: gap),
          Row(
            children: [
              for (
                var column = 0;
                column < LibraryGroupTile._previewColumns;
                column++
              ) ...[
                if (column > 0) SizedBox(width: gap),
                _cell(
                  row * LibraryGroupTile._previewColumns + column,
                  cellSize,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _cell(int index, double cellSize) {
    if (index >= routines.length) return SizedBox.square(dimension: cellSize);
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        LibraryGroupTile._previewCellRadius.w,
      ),
      // 큰 칸에 그린 뒤 줄인다 — 그림 둘레 여백이 px 고정이라 작은 칸에 바로 그리면 빈 칸이 된다
      child: SizedBox.square(
        dimension: cellSize,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox.square(
            dimension: LibraryGroupTile._previewRenderSize,
            child: LibraryRoutineThumbnail(routine: routines[index]),
          ),
        ),
      ),
    );
  }
}
