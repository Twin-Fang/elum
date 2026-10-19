import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/routine.dart';
import '../../application/library_entries.dart';
import 'library_group_tile.dart';
import 'library_routine_tile.dart';

/// 일과관리 격자 (#807): 묶음 칸 + 낱개 칸. 창 폭으로 열 수를 정한다 (폰 4열, 넓으면 늘어남)
///
/// 낱개 칸 길게 누르기: 그냥 떼면 메뉴, 누른 채 움직이면 끌기
/// > 다른 일과 위에 놓으면 새 묶음, 묶음 위에 놓으면 그 묶음에 넣기.
class LibraryEntryGrid extends StatefulWidget {
  const LibraryEntryGrid({
    super.key,
    required this.entries,
    required this.sentIds,
    required this.bottomSpace,
    required this.onRoutineTap,
    required this.onRoutineMenu,
    required this.onGroupTap,
    required this.onGroupMenu,
    required this.onDropOnRoutine,
    required this.onDropOnGroup,
  });

  final List<LibraryEntry> entries;
  final Set<String> sentIds;
  final double bottomSpace;

  /// 다른 동작이 도는 중이면 null — 같은 요청이 두 번 가지 않게
  final ValueChanged<Routine>? onRoutineTap;
  final ValueChanged<Routine>? onRoutineMenu;
  final ValueChanged<LibraryGroupEntry>? onGroupTap;
  final ValueChanged<LibraryGroupEntry>? onGroupMenu;

  /// (끌어 온 일과, 놓은 자리의 일과)
  final void Function(Routine dragged, Routine target)? onDropOnRoutine;
  final void Function(Routine dragged, LibraryGroupEntry target)? onDropOnGroup;

  @override
  State<LibraryEntryGrid> createState() => _LibraryEntryGridState();
}

class _LibraryEntryGridState extends State<LibraryEntryGrid> {
  /// 칸 한 개가 차지하는 최소 폭(393 기준). 이 폭으로 열 수를 정한다 (폰 4열)
  static const _tileMinWidth = 84.0;
  static const _minColumns = 4;
  static const _maxColumns = 8;

  /// 이만큼 안 움직이고 떼면 끌기가 아니라 메뉴 열기로 본다 (논리 픽셀)
  static const _menuSlopPixels = 12.0;

  /// 끌어 온 일과가 위에 있을 때 키우는 비율 · 끄는 동안 제자리 칸 흐리기
  static const _dropTargetScale = 1.1;
  static const _draggingOpacity = 0.3;

  /// 끌기를 시작한 칸의 화면 위치 (놓은 자리와 견줘 메뉴/끌기를 가른다)
  Offset? _dragOrigin;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / _tileMinWidth.w).floor().clamp(
          _minColumns,
          _maxColumns,
        );
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            space.md.w,
            space.xs.h,
            space.md.w,
            widget.bottomSpace,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: space.md.h,
            crossAxisSpacing: space.xs.w,
            // 그림 칸 + 이름 두 줄이 들어가는 높이
            mainAxisExtent:
                LibraryRoutineTile.iconSize.w + space.xs.h + space.xl.h * 1.4,
          ),
          itemCount: widget.entries.length,
          itemBuilder: (context, index) => switch (widget.entries[index]) {
            final LibraryGroupEntry entry => _buildGroup(entry),
            final LibraryRoutineEntry entry => _buildRoutine(entry.routine),
          },
        );
      },
    );
  }

  /// 묶음 칸: 끌어 온 일과를 받는다
  Widget _buildGroup(LibraryGroupEntry entry) {
    final isSentToday = entry.routines.every(
      (routine) => widget.sentIds.contains(routine.id),
    );
    return DragTarget<Routine>(
      key: ValueKey('group-${entry.group.id}'),
      onWillAcceptWithDetails: (_) => widget.onDropOnGroup != null,
      onAcceptWithDetails: (details) =>
          widget.onDropOnGroup?.call(details.data, entry),
      builder: (context, candidates, _) => LibraryGroupTile(
        entry: entry,
        isSentToday: isSentToday,
        isDropTarget: candidates.isNotEmpty,
        onTap: () => widget.onGroupTap?.call(entry),
        onLongPress: () => widget.onGroupMenu?.call(entry),
      ),
    );
  }

  /// 낱개 칸: 끌 수 있고, 다른 일과를 받으면 새 묶음
  Widget _buildRoutine(Routine routine) {
    final isSentToday = widget.sentIds.contains(routine.id);
    final isDragEnabled = widget.onRoutineMenu != null;
    return Builder(
      key: ValueKey(routine.id),
      builder: (tileContext) => DragTarget<Routine>(
        onWillAcceptWithDetails: (details) =>
            widget.onDropOnRoutine != null && details.data.id != routine.id,
        onAcceptWithDetails: (details) =>
            widget.onDropOnRoutine?.call(details.data, routine),
        builder: (context, candidates, _) {
          final tile = AnimatedScale(
            scale: candidates.isNotEmpty ? _dropTargetScale : 1,
            duration: AppMotion.fast,
            child: LibraryRoutineTile(
              routine: routine,
              isSentToday: isSentToday,
              onTap: () => widget.onRoutineTap?.call(routine),
            ),
          );
          if (!isDragEnabled) return tile;
          return LongPressDraggable<Routine>(
            data: routine,
            onDragStarted: () => _dragOrigin = _originOf(tileContext),
            // 아무 데도 안 놓였다: 거의 안 움직였으면 메뉴, 아니면 제자리
            onDraggableCanceled: (_, offset) {
              if (_isMenuGesture(offset)) widget.onRoutineMenu?.call(routine);
              _dragOrigin = null;
            },
            onDragCompleted: () => _dragOrigin = null,
            feedback: _DragFeedback(routine: routine),
            childWhenDragging: Opacity(opacity: _draggingOpacity, child: tile),
            child: tile,
          );
        },
      ),
    );
  }

  Offset? _originOf(BuildContext tileContext) {
    if (tileContext.findRenderObject() case final RenderBox box
        when box.hasSize) {
      return box.localToGlobal(Offset.zero);
    }
    return null;
  }

  bool _isMenuGesture(Offset dropOffset) {
    final origin = _dragOrigin;
    // 시작 위치를 못 잡았으면 메뉴로 본다 (끌기보다 안전한 쪽)
    if (origin == null) return true;
    return (dropOffset - origin).distance < _menuSlopPixels;
  }
}

/// 끌고 다니는 그림: 칸과 같은 모양을 살짝 키우고 그림자
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.routine});

  final Routine routine;

  /// 끄는 그림 확대 비율 · 그림자 번짐
  static const _scale = 1.1;
  static const _shadowBlur = 16.0;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(LibraryRoutineTile.iconRadius.w);
    return Transform.scale(
      scale: _scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: context.colors.textPrimary.withValues(alpha: 0.25),
              blurRadius: _shadowBlur,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox.square(
            dimension: LibraryRoutineTile.iconSize.w,
            child: LibraryRoutineThumbnail(routine: routine),
          ),
        ),
      ),
    );
  }
}
