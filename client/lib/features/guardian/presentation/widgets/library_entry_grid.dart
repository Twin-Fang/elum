import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/routine.dart';
import '../../application/library_entries.dart';
import 'arrange_remove_badge.dart';
import 'library_group_tile.dart';
import 'library_routine_tile.dart';

/// 길게 누른 칸의 화면 자리와 그 칸 모양 (칸 옆 메뉴가 쓴다)
typedef LibraryMenuAnchor = ({Rect rect, Widget tile});

/// 일과관리 격자 (#807, #837): 묶음 칸 + 낱개 칸. 창 폭으로 열 수를 정한다 (폰 4열, 넓으면 늘어남)
///
/// 낱개 칸 길게 누르기: 그냥 떼면 칸 옆 메뉴, 누른 채 움직이면 정리 상태로 들어가 끌기
/// > 다른 일과 위에 놓으면 새 묶음, 묶음 위에 놓으면 그 묶음에 넣기.
/// 정리 상태([isArranging]): 칸이 흔들리고 칸마다 ⊖ (지우기 · 묶음 풀기), 바로 끌 수 있다.
class LibraryEntryGrid extends StatefulWidget {
  const LibraryEntryGrid({
    super.key,
    required this.entries,
    required this.sentIds,
    required this.bottomSpace,
    required this.isArranging,
    required this.onRoutineTap,
    required this.onRoutineMenu,
    required this.onGroupTap,
    required this.onGroupMenu,
    required this.onDropOnRoutine,
    required this.onDropOnGroup,
    required this.onArrangeStart,
    required this.onRemoveRoutine,
    required this.onRemoveGroup,
    this.firstTileKey,
  });

  final List<LibraryEntry> entries;
  final Set<String> sentIds;
  final double bottomSpace;

  /// 정리 상태인가 (흔들림 · ⊖ · 바로 끌기)
  final bool isArranging;

  /// 다른 동작이 도는 중이면 null — 같은 요청이 두 번 가지 않게
  final ValueChanged<Routine>? onRoutineTap;
  final void Function(Routine routine, LibraryMenuAnchor anchor)? onRoutineMenu;
  final ValueChanged<LibraryGroupEntry>? onGroupTap;
  final void Function(LibraryGroupEntry entry, LibraryMenuAnchor anchor)?
  onGroupMenu;

  /// (끌어 온 일과, 놓은 자리의 일과)
  final void Function(Routine dragged, Routine target)? onDropOnRoutine;
  final void Function(Routine dragged, LibraryGroupEntry target)? onDropOnGroup;

  /// 길게 누른 채 움직이기 시작했다 — 정리 상태로 들어간다
  final VoidCallback? onArrangeStart;

  /// 정리 상태 ⊖: 일과 지우기 · 묶음 풀기
  final ValueChanged<Routine>? onRemoveRoutine;
  final ValueChanged<LibraryGroupEntry>? onRemoveGroup;

  /// 코치마크가 가리킬 첫 칸에 붙일 키 (#834)
  final GlobalKey? firstTileKey;

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

  /// 길게 누른 손가락의 처음 자리 (움직인 거리로 메뉴/끌기를 가른다)
  Offset? _pointerOrigin;

  /// 이번 길게 누르기에서 이미 정리 상태로 넘겼는가 (한 번만 알린다)
  bool _hasStartedArranging = false;

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
          itemBuilder: (context, index) {
            final tile = switch (widget.entries[index]) {
              final LibraryGroupEntry entry => _buildGroup(entry, index),
              final LibraryRoutineEntry entry => _buildRoutine(
                entry.routine,
                index,
              ),
            };
            final coachKey = widget.firstTileKey;
            if (index != 0 || coachKey == null) return tile;
            return KeyedSubtree(key: coachKey, child: tile);
          },
        );
      },
    );
  }

  /// 묶음 칸: 끌어 온 일과를 받는다
  Widget _buildGroup(LibraryGroupEntry entry, int index) {
    final isSentToday = entry.routines.every(
      (routine) => widget.sentIds.contains(routine.id),
    );
    LibraryGroupTile groupTile({
      bool isDropTarget = false,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
    }) => LibraryGroupTile(
      entry: entry,
      isSentToday: isSentToday,
      isDropTarget: isDropTarget,
      onTap: onTap ?? () {},
      onLongPress: onLongPress ?? () {},
    );
    return Builder(
      key: ValueKey('group-${entry.group.id}'),
      builder: (tileContext) => DragTarget<Routine>(
        onWillAcceptWithDetails: (_) => widget.onDropOnGroup != null,
        onAcceptWithDetails: (details) =>
            widget.onDropOnGroup?.call(details.data, entry),
        builder: (context, candidates, _) => _ArrangeShell(
          isArranging: widget.isArranging,
          isAlternatePhase: index.isOdd,
          isRemovable: true,
          onRemove: () => widget.onRemoveGroup?.call(entry),
          child: groupTile(
            isDropTarget: candidates.isNotEmpty,
            onTap: widget.isArranging
                ? null
                : () => widget.onGroupTap?.call(entry),
            onLongPress: widget.isArranging
                ? null
                : () {
                    final rect = _rectOf(tileContext);
                    if (rect == null) return;
                    widget.onGroupMenu?.call(entry, (
                      rect: rect,
                      tile: groupTile(),
                    ));
                  },
          ),
        ),
      ),
    );
  }

  /// 낱개 칸: 끌 수 있고, 다른 일과를 받으면 새 묶음
  Widget _buildRoutine(Routine routine, int index) {
    final isSentToday = widget.sentIds.contains(routine.id);
    final isDragEnabled = widget.onRoutineMenu != null;
    LibraryRoutineTile routineTile({VoidCallback? onTap}) => LibraryRoutineTile(
      routine: routine,
      isSentToday: isSentToday,
      onTap: onTap ?? () {},
    );
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
            child: routineTile(
              onTap: widget.isArranging
                  ? null
                  : () => widget.onRoutineTap?.call(routine),
            ),
          );
          final dragged = !isDragEnabled
              ? tile
              : _buildDraggable(
                  routine: routine,
                  tile: tile,
                  tileContext: tileContext,
                  menuTile: routineTile(),
                );
          return _ArrangeShell(
            isArranging: widget.isArranging,
            isAlternatePhase: index.isOdd,
            isRemovable: routine.isEditableByMe,
            onRemove: () => widget.onRemoveRoutine?.call(routine),
            child: dragged,
          );
        },
      ),
    );
  }

  /// 정리 상태면 바로 끌리고, 아니면 길게 눌러야 끌린다
  Widget _buildDraggable({
    required Routine routine,
    required Widget tile,
    required BuildContext tileContext,
    required Widget menuTile,
  }) {
    final feedback = _DragFeedback(routine: routine);
    final childWhenDragging = Opacity(opacity: _draggingOpacity, child: tile);
    if (widget.isArranging) {
      return Draggable<Routine>(
        data: routine,
        feedback: feedback,
        childWhenDragging: childWhenDragging,
        child: tile,
      );
    }
    return LongPressDraggable<Routine>(
      data: routine,
      onDragStarted: () {
        _pointerOrigin = null;
        _hasStartedArranging = false;
      },
      // 길게 누른 채 움직이면 정리 상태로 — 한 번만 알린다
      onDragUpdate: (details) {
        if (_hasStartedArranging) return;
        final origin = _pointerOrigin ??= details.globalPosition;
        // 한 번에 크게 움직였거나, 처음 자리에서 충분히 멀어졌으면 끌기
        final isMenuGesture =
            details.delta.distance < _menuSlopPixels &&
            (details.globalPosition - origin).distance < _menuSlopPixels;
        if (isMenuGesture) return;
        _hasStartedArranging = true;
        widget.onArrangeStart?.call();
      },
      // 아무 데도 안 놓였다: 거의 안 움직였으면 칸 옆 메뉴, 아니면 제자리
      onDraggableCanceled: (_, offset) {
        final rect = _rectOf(tileContext);
        if (!_hasStartedArranging && rect != null) {
          widget.onRoutineMenu?.call(routine, (rect: rect, tile: menuTile));
        }
        _pointerOrigin = null;
      },
      onDragCompleted: () => _pointerOrigin = null,
      feedback: feedback,
      childWhenDragging: childWhenDragging,
      child: tile,
    );
  }

  Rect? _rectOf(BuildContext tileContext) {
    if (tileContext.findRenderObject() case final RenderBox box
        when box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return null;
  }
}

/// 정리 상태 껍데기: 흔들리고 왼쪽 위에 ⊖ 를 단다. 정리 상태가 아니면 그대로 지나간다
class _ArrangeShell extends StatefulWidget {
  const _ArrangeShell({
    required this.isArranging,
    required this.isAlternatePhase,
    required this.isRemovable,
    required this.onRemove,
    required this.child,
  });

  final bool isArranging;

  /// 이웃 칸과 어긋나게 흔든다 (시안: 짝수 칸은 반 박자 늦게)
  final bool isAlternatePhase;

  /// ⊖ 를 달 수 있는가 — 남이 만든 일과는 지울 수 없어 달지 않는다 (메뉴가 지우기를 숨기는 것과 같다)
  final bool isRemovable;
  final VoidCallback onRemove;
  final Widget child;

  @override
  State<_ArrangeShell> createState() => _ArrangeShellState();
}

class _ArrangeShellState extends State<_ArrangeShell>
    with SingleTickerProviderStateMixin {
  /// 흔들림 한 번(왕복의 절반) 시간 · 최대 기울기(도)
  static const _jiggleHalfPeriod = Duration(milliseconds: 260);
  static const _maxTiltDegrees = 2.4;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _jiggleHalfPeriod);
    if (widget.isArranging) _startJiggle();
  }

  @override
  void didUpdateWidget(_ArrangeShell old) {
    super.didUpdateWidget(old);
    if (widget.isArranging == old.isArranging) return;
    if (widget.isArranging) {
      _startJiggle();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  void _startJiggle() {
    // 이웃과 어긋나게 시작 위치를 반 박자 옮긴다
    _controller.value = widget.isAlternatePhase ? 0.5 : 0;
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isArranging) return widget.child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.rotate(
            angle:
                (_controller.value * 2 - 1) * _maxTiltDegrees * math.pi / 180,
            child: child,
          ),
          child: widget.child,
        ),
        if (widget.isRemovable)
          Positioned(
            top: -4.h,
            left: 2.w,
            child: ArrangeRemoveBadge(
              onTap: widget.onRemove,
              semanticLabel: context.l10n.libraryArrangeRemove,
            ),
          ),
      ],
    );
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
