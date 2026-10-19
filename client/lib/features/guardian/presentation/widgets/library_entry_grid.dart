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
    required this.onMoveCell,
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

  /// 칸 가장자리에 놓았다: [dragged] 를 [target] 앞([isBefore])이나 뒤로 옮긴다 (#837)
  final void Function(
    LibraryEntry dragged,
    LibraryEntry target, {
    required bool isBefore,
  })?
  onMoveCell;

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

  /// 끌어 온 칸이 지금 어느 칸의 어느 자리 위에 있는가 (놓을 자리 표시)
  ({String id, _DropZone zone})? _hover;

  /// 칸 가장자리로 보는 폭 비율 (앞·뒤 각 25%, 가운데는 묶기)
  static const _edgeFraction = 0.25;

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

  /// 끌어 온 칸이 [tileContext] 칸의 어느 자리 위에 놓였는가 (앞·가운데·뒤)
  _DropZone _zoneOf(
    BuildContext tileContext,
    DragTargetDetails<LibraryEntry> d,
  ) {
    final rect = _rectOf(tileContext);
    if (rect == null || rect.width <= 0) return _DropZone.center;
    // 끄는 그림 한가운데를 손가락 자리로 본다
    final x = d.offset.dx + LibraryRoutineTile.iconSize.w / 2;
    final fraction = (x - rect.left) / rect.width;
    if (fraction < _edgeFraction) return _DropZone.before;
    if (fraction > 1 - _edgeFraction) return _DropZone.after;
    return _DropZone.center;
  }

  void _setHover(String id, _DropZone? zone) {
    final next = zone == null ? null : (id: id, zone: zone);
    if (_hover == next) return;
    setState(() => _hover = next);
  }

  /// 놓았다: 낱개를 가운데에 놓으면 묶기, 그 밖(가장자리 · 묶음을 끌어 온 경우)은 자리 이동
  void _handleDrop(LibraryEntry target, LibraryEntry dragged, _DropZone zone) {
    _setHover(target.id, null);
    if (zone == _DropZone.center && dragged is LibraryRoutineEntry) {
      switch (target) {
        case LibraryRoutineEntry():
          widget.onDropOnRoutine?.call(dragged.routine, target.routine);
        case LibraryGroupEntry():
          widget.onDropOnGroup?.call(dragged.routine, target);
      }
      return;
    }
    widget.onMoveCell?.call(dragged, target, isBefore: zone != _DropZone.after);
  }

  /// 놓을 자리 막대: 앞이면 칸 왼쪽, 뒤면 오른쪽에 세로로
  Widget _withDropBar(String id, Widget tile) {
    final hover = _hover;
    final zone = hover != null && hover.id == id ? hover.zone : null;
    if (zone == null || zone == _DropZone.center) return tile;
    final colors = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        Positioned(
          left: zone == _DropZone.before ? -5.w : null,
          right: zone == _DropZone.after ? -5.w : null,
          top: 4.h,
          child: Container(
            width: 3.w,
            height: LibraryRoutineTile.iconSize.w,
            decoration: BoxDecoration(
              color: colors.textSecondary,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        ),
      ],
    );
  }

  /// 묶음 칸: 끌어 온 칸을 받는다 (낱개 가운데 = 넣기, 가장자리 = 자리 이동)
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
      builder: (tileContext) => DragTarget<LibraryEntry>(
        onWillAcceptWithDetails: (details) => details.data.id != entry.id,
        onMove: (details) => _setHover(entry.id, _zoneOf(tileContext, details)),
        onLeave: (_) => _setHover(entry.id, null),
        onAcceptWithDetails: (details) =>
            _handleDrop(entry, details.data, _zoneOf(tileContext, details)),
        builder: (context, candidates, _) {
          final isCenter =
              _hover?.id == entry.id && _hover?.zone == _DropZone.center;
          final tile = _ArrangeShell(
            isArranging: widget.isArranging,
            isAlternatePhase: index.isOdd,
            isRemovable: true,
            onRemove: () => widget.onRemoveGroup?.call(entry),
            child: groupTile(
              isDropTarget: candidates.isNotEmpty && isCenter,
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
          );
          // 정리 상태에서는 묶음도 끌어 자리를 옮길 수 있다
          final draggable = widget.isArranging && widget.onMoveCell != null
              ? Draggable<LibraryEntry>(
                  data: entry,
                  feedback: const _GroupDragFeedback(),
                  childWhenDragging: Opacity(
                    opacity: _draggingOpacity,
                    child: tile,
                  ),
                  child: tile,
                )
              : tile;
          return _withDropBar(entry.id, draggable);
        },
      ),
    );
  }

  /// 낱개 칸: 끌 수 있고, 다른 칸을 받으면 (가운데 = 새 묶음, 가장자리 = 자리 이동)
  Widget _buildRoutine(Routine routine, int index) {
    final entry = LibraryRoutineEntry(routine);
    final isSentToday = widget.sentIds.contains(routine.id);
    final isDragEnabled = widget.onRoutineMenu != null;
    LibraryRoutineTile routineTile({VoidCallback? onTap}) => LibraryRoutineTile(
      routine: routine,
      isSentToday: isSentToday,
      onTap: onTap ?? () {},
    );
    return Builder(
      key: ValueKey(routine.id),
      builder: (tileContext) => DragTarget<LibraryEntry>(
        onWillAcceptWithDetails: (details) => details.data.id != routine.id,
        onMove: (details) =>
            _setHover(routine.id, _zoneOf(tileContext, details)),
        onLeave: (_) => _setHover(routine.id, null),
        onAcceptWithDetails: (details) =>
            _handleDrop(entry, details.data, _zoneOf(tileContext, details)),
        builder: (context, candidates, _) {
          final isCenter =
              _hover?.id == routine.id && _hover?.zone == _DropZone.center;
          final tile = AnimatedScale(
            scale: candidates.isNotEmpty && isCenter ? _dropTargetScale : 1,
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
                  entry: entry,
                  routine: routine,
                  tile: tile,
                  tileContext: tileContext,
                  menuTile: routineTile(),
                );
          return _withDropBar(
            routine.id,
            _ArrangeShell(
              isArranging: widget.isArranging,
              isAlternatePhase: index.isOdd,
              isRemovable: routine.isEditableByMe,
              onRemove: () => widget.onRemoveRoutine?.call(routine),
              child: dragged,
            ),
          );
        },
      ),
    );
  }

  /// 정리 상태면 바로 끌리고, 아니면 길게 눌러야 끌린다
  Widget _buildDraggable({
    required LibraryEntry entry,
    required Routine routine,
    required Widget tile,
    required BuildContext tileContext,
    required Widget menuTile,
  }) {
    final feedback = _DragFeedback(routine: routine);
    final childWhenDragging = Opacity(opacity: _draggingOpacity, child: tile);
    if (widget.isArranging) {
      return Draggable<LibraryEntry>(
        data: entry,
        feedback: feedback,
        childWhenDragging: childWhenDragging,
        child: tile,
      );
    }
    return LongPressDraggable<LibraryEntry>(
      data: entry,
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

/// 놓은 자리: 칸 앞 · 가운데(묶기) · 뒤
enum _DropZone { before, center, after }

/// 묶음 칸을 끌 때 따라다니는 그림 (폴더 모양)
class _GroupDragFeedback extends StatelessWidget {
  const _GroupDragFeedback();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(LibraryRoutineTile.iconRadius.w);
    return Container(
      width: LibraryRoutineTile.iconSize.w,
      height: LibraryRoutineTile.iconSize.w,
      decoration: BoxDecoration(
        color: context.colors.folderFill,
        borderRadius: radius,
      ),
      child: Icon(
        Icons.folder_rounded,
        size: 28.w,
        color: context.colors.textSecondary,
      ),
    );
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
