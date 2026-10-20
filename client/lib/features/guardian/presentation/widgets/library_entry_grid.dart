import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/routine.dart';
import '../../application/library_entries.dart';
import 'library_arrange_shell.dart';
import 'library_grid_geometry.dart';
import 'library_grid_lifted_tile.dart';
import 'library_group_tile.dart';
import 'library_routine_tile.dart';

part 'library_entry_grid_cells.dart';

/// 길게 누른 칸의 화면 자리와 그 칸 모양 (칸 옆 메뉴가 쓴다)
typedef LibraryMenuAnchor = ({Rect rect, Widget tile});

/// 일과관리 격자 (#807, #837): 묶음 칸 + 낱개 칸. 창 폭으로 열 수를 정한다 (폰 4열, 넓으면 늘어남)
///
/// 칸 길게 누르기: 그냥 떼면 칸 옆 메뉴, 누른 채 움직이면 정리 상태로 들어가 끌기.
/// 끄는 칸은 손가락에 붙어 다니고, 칸 사이로 가면 이웃 칸이 비켜 빈자리가 생긴다.
/// 낱개를 다른 칸 그림 위에 겹쳐 놓으면 묶기(새 묶음 · 묶음에 넣기), 빈자리에 놓으면 자리 옮기기.
/// 정리 상태([isArranging]): 칸이 흔들리고 칸마다 ⊖ (지우기 · 묶음 풀기), 누르자마자 끌 수 있다.
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
    this.firstRoutineTileKey,
    this.secondRoutineTileKey,
  });

  final List<LibraryEntry> entries;
  final Set<String> sentIds;
  final double bottomSpace;

  /// 정리 상태인가 (흔들림 · ⊖ · 바로 끌기)
  final bool isArranging;

  /// 다른 동작이 도는 중이면 null — 같은 요청이 두 번 가지 않게. 메뉴가 null 이면 그 칸은 끌리지 않는다
  final ValueChanged<Routine>? onRoutineTap;
  final void Function(Routine routine, LibraryMenuAnchor anchor)? onRoutineMenu;
  final ValueChanged<LibraryGroupEntry>? onGroupTap;
  final void Function(LibraryGroupEntry entry, LibraryMenuAnchor anchor)?
  onGroupMenu;

  /// (끌어 온 일과, 겹쳐 놓은 칸의 일과 · 묶음). 끝나면 격자가 숨겼던 칸을 다시 본다
  final Future<void> Function(Routine dragged, Routine target)? onDropOnRoutine;
  final Future<void> Function(Routine dragged, LibraryGroupEntry target)?
  onDropOnGroup;

  /// 빈자리에 놓았다: [dragged] 를 [target] 앞([isBefore])이나 뒤로 옮긴다. 저장했으면 true (#837)
  final Future<bool> Function(
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

  /// 코치마크가 가리킬 낱개 일과 칸의 첫째 · 둘째 (묶음 칸은 세지 않는다)
  final GlobalKey? firstRoutineTileKey;
  final GlobalKey? secondRoutineTileKey;

  @override
  State<LibraryEntryGrid> createState() => _LibraryEntryGridState();
}

class _LibraryEntryGridState extends State<LibraryEntryGrid>
    with TickerProviderStateMixin {
  /// 이만큼 안 움직이고 떼면 끌기가 아니라 메뉴 열기로 본다 (논리 픽셀)
  static const _menuSlopPixels = 12.0;

  /// 집은 칸을 키우는 비율 · 묶음에 빨려 들어갈 때 줄이는 비율
  static const _liftScale = 0.12;
  static const _mergeLandScale = 0.4;

  /// 손가락이 화면 위아래 끝 이 거리 안이면 격자를 굴린다 · 최고 속도(px/s)
  static const _edgeScrollZone = 56.0;
  static const _edgeScrollSpeed = 520.0;

  final _viewportKey = GlobalKey();
  final _contentKey = GlobalKey();
  final _scroll = ScrollController();
  late final _lift = AnimationController(vsync: this, duration: AppMotion.fast);
  late final _land = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
  );
  late final Ticker _edgeTicker = createTicker(_onEdgeTick);
  Duration _lastEdgeTick = Duration.zero;

  LibraryGridGeometry? _geometry;

  /// 놓은 직후 서버 목록이 오기 전까지 보여 줄 칸 순서 (id). 서버 순서가 같아지면 지운다
  List<String>? _orderOverride;

  /// 묶음에 넣는 중이라 숨긴 칸 (요청이 끝나면 다시 본다 — 실패면 제자리로 돌아온다)
  String? _hiddenId;
  String? _mergeInFlightId;

  // --- 끌기 ---
  String? _dragId;
  int _dragFrom = 0;
  LibraryGridHover? _hover;
  Offset _fingerGlobal = Offset.zero;
  Offset _startGlobal = Offset.zero;

  /// 집은 지점 (칸 왼쪽 위 기준). 칸이 커져도 이 점이 손가락 밑에 남는다
  Offset _grab = Offset.zero;
  bool _hasMoved = false;
  bool _isLongPressDrag = false;

  /// 놓은 뒤 안착 움직임 (null 이면 끄는 중이거나 쉬는 중)
  _LandingPlan? _landing;

  double get _easedLift => Curves.easeOutCubic.transform(_lift.value);
  double get _easedLand => Curves.easeOutCubic.transform(_land.value);

  @override
  void didUpdateWidget(LibraryEntryGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final override = _orderOverride;
    final ids = [for (final entry in widget.entries) entry.id];
    // 서버 목록이 놓은 순서와 같아졌거나, 칸이 늘거나 줄었으면(덧씌우기가 낡음) 걷는다
    if (override != null &&
        (listEquals(ids, override) ||
            !setEquals(ids.toSet(), override.toSet()))) {
      _orderOverride = null;
    }
    // 끌던 칸이 목록에서 사라졌다 — 끌기를 접는다
    final dragId = _dragId;
    if (dragId != null && !widget.entries.any((entry) => entry.id == dragId)) {
      _resetDrag();
    }
  }

  @override
  void dispose() {
    _edgeTicker.dispose();
    _lift.dispose();
    _land.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 화면 좌표 > 격자 내용(스크롤 안) 좌표
  Offset _toContent(Offset global) {
    final box = _contentKey.currentContext?.findRenderObject();
    return box is RenderBox ? box.globalToLocal(global) : global;
  }

  Rect? _globalRectOf(Rect contentRect) {
    final box = _contentKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(contentRect.topLeft) & contentRect.size;
  }

  // ---------------------------------------------------------------------------
  // 집기 · 끌기 · 놓기
  // ---------------------------------------------------------------------------

  /// 집기: 칸을 들어 손가락 밑에 붙인다. 빈자리는 아직 제자리 (움직여야 이웃이 비킨다)
  Drag? _startDrag(
    LibraryEntry entry,
    Offset globalPosition, {
    required bool isLongPress,
  }) {
    final geometry = _geometry;
    final shown = _shownEntries;
    final index = shown.indexWhere((candidate) => candidate.id == entry.id);
    if (_dragId != null || _landing != null || geometry == null || index < 0) {
      return null;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _dragId = entry.id;
      _dragFrom = index;
      _hover = LibraryGridHover(gap: index);
      _fingerGlobal = globalPosition;
      _startGlobal = globalPosition;
      _grab = _toContent(globalPosition) - geometry.slotRect(index).topLeft;
      // 정리 상태에서 바로 끈 것은 처음부터 끌기 (메뉴 아님)
      _hasMoved = !isLongPress;
      _isLongPressDrag = isLongPress;
    });
    _lift.forward(from: 0);
    _lastEdgeTick = Duration.zero;
    _edgeTicker.start();
    return _GridDrag(
      onUpdate: _onDragUpdate,
      onEnd: (_) => _onDrop(),
      onCancel: _onCancel,
    );
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dragId == null || _landing != null) return;
    _fingerGlobal = details.globalPosition;
    if (!_hasMoved &&
        (_fingerGlobal - _startGlobal).distance >= _menuSlopPixels) {
      _hasMoved = true;
      if (_isLongPressDrag) widget.onArrangeStart?.call();
    }
    _updateHover();
    setState(() {});
  }

  /// 끄는 칸 그림 가운데로 빈자리 · 묶을 칸을 다시 잰다
  void _updateHover() {
    final geometry = _geometry;
    final hover = _hover;
    if (!_hasMoved || geometry == null || hover == null) return;
    final shown = _shownEntries;
    final dragged = shown.where((entry) => entry.id == _dragId).firstOrNull;
    if (dragged == null) return;
    final scale = 1 + _liftScale * _easedLift;
    final iconCenterInTile = Offset(
      geometry.tileWidth / 2,
      geometry.iconSize / 2,
    );
    final next = geometry.resolveHover(
      draggedIconCenter:
          _toContent(_fingerGlobal) + (iconCenterInTile - _grab) * scale,
      otherCount: shown.length - 1,
      gap: hover.gap,
      canMerge:
          dragged is LibraryRoutineEntry &&
          widget.onDropOnRoutine != null &&
          widget.onDropOnGroup != null,
    );
    if (next == hover) return;
    if (next.mergeOtherIndex != null) HapticFeedback.lightImpact();
    setState(() => _hover = next);
  }

  void _onDrop() {
    final dragId = _dragId;
    final hover = _hover;
    final geometry = _geometry;
    if (dragId == null || hover == null || geometry == null || _landing != null) {
      return;
    }
    final shown = _shownEntries;
    final dragged = shown.where((entry) => entry.id == dragId).firstOrNull;
    if (dragged == null) return _resetDrag();
    // 안 움직이고 뗐다 — 칸 옆 메뉴 (메뉴가 칸 모양을 그리므로 들린 칸은 바로 내린다)
    if (!_hasMoved) {
      _resetDrag();
      return _openMenu(dragged, geometry.slotRect(_dragFrom));
    }
    final others = _othersOf(shown);
    final mergeIndex = hover.mergeOtherIndex;
    if (mergeIndex != null && dragged is LibraryRoutineEntry) {
      final targetSlot = mergeIndex < hover.gap ? mergeIndex : mergeIndex + 1;
      _beginLanding(
        geometry.slotRect(targetSlot),
        toScale: _mergeLandScale,
        toOpacity: 0,
      );
      _merge(dragged.routine, others[mergeIndex]);
      return;
    }
    _beginLanding(geometry.slotRect(hover.gap));
    if (hover.gap != _dragFrom && others.isNotEmpty) {
      _move(dragged, others, hover.gap);
    }
  }

  /// 손가락이 끊겼다(전화 수신 등): 옮기지 않고 원래 자리로 돌려놓는다
  void _onCancel() {
    final geometry = _geometry;
    if (_dragId == null || _landing != null || geometry == null) return;
    setState(() => _hover = LibraryGridHover(gap: _dragFrom));
    _beginLanding(geometry.slotRect(_dragFrom));
  }

  /// 빈자리로 옮기기: 놓은 순서를 바로 덧씌우고 저장. 실패하면 덧씌우기를 걷어 제자리로 돌아간다
  Future<void> _move(
    LibraryEntry dragged,
    List<LibraryEntry> others,
    int gap,
  ) async {
    final onMoveCell = widget.onMoveCell;
    if (onMoveCell == null) return;
    final ordered = [...others]..insert(gap, dragged);
    _orderOverride = [for (final entry in ordered) entry.id];
    final isBefore = gap < others.length;
    final target = isBefore ? others[gap] : others.last;
    final isSaved = await onMoveCell(dragged, target, isBefore: isBefore);
    if (!isSaved && mounted) setState(() => _orderOverride = null);
  }

  /// 묶기: 빨려 들어간 칸은 요청이 끝날 때까지 숨긴다 (성공이면 묶음 안으로, 실패면 제자리로)
  Future<void> _merge(Routine dragged, LibraryEntry target) async {
    final call = switch (target) {
      LibraryRoutineEntry(:final routine) => widget.onDropOnRoutine?.call(
        dragged,
        routine,
      ),
      final LibraryGroupEntry group => widget.onDropOnGroup?.call(
        dragged,
        group,
      ),
    };
    _mergeInFlightId = dragged.id;
    await call;
    if (!mounted) return;
    setState(() {
      _mergeInFlightId = null;
      _hiddenId = null;
    });
  }

  void _openMenu(LibraryEntry entry, Rect contentRect) {
    final rect = _globalRectOf(contentRect);
    if (rect == null) return;
    switch (entry) {
      case LibraryRoutineEntry(:final routine):
        widget.onRoutineMenu?.call(routine, (
          rect: rect,
          tile: _routineTile(routine),
        ));
      case final LibraryGroupEntry group:
        widget.onGroupMenu?.call(group, (rect: rect, tile: _groupTile(group)));
    }
  }

  /// 들린 칸을 [to] 자리로 내려놓는다 (크기 · 투명도도 함께)
  void _beginLanding(Rect to, {double toScale = 1, double toOpacity = 1}) {
    _edgeTicker.stop();
    setState(() {
      _landing = _LandingPlan(
        from: _overlayRect(),
        fromScale: _overlayScale(),
        to: to,
        toScale: toScale,
        toOpacity: toOpacity,
      );
    });
    _land.forward(from: 0).whenComplete(_finishLanding);
  }

  void _finishLanding() {
    if (!mounted || _landing == null) return;
    final landedId = _dragId;
    final isMerge = _landing?.toOpacity == 0;
    HapticFeedback.selectionClick();
    setState(() {
      // 묶음 요청이 아직 끝나지 않았으면 빨려 들어간 칸을 숨긴 채 둔다
      if (isMerge && landedId != null && _mergeInFlightId == landedId) {
        _hiddenId = landedId;
      }
      _clearDragState();
    });
  }

  void _resetDrag() {
    _edgeTicker.stop();
    _land.stop();
    if (mounted) setState(_clearDragState);
  }

  void _clearDragState() {
    _dragId = null;
    _hover = null;
    _landing = null;
    _hasMoved = false;
    _lift.value = 0;
    _land.value = 0;
  }

  /// 손가락이 화면 위아래 끝에 닿으면 격자를 굴린다
  void _onEdgeTick(Duration elapsed) {
    final seconds = (elapsed - _lastEdgeTick).inMicroseconds / 1e6;
    _lastEdgeTick = elapsed;
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (_dragId == null ||
        !_hasMoved ||
        _landing != null ||
        viewport is! RenderBox ||
        !_scroll.hasClients) {
      return;
    }
    final fingerY = viewport.globalToLocal(_fingerGlobal).dy;
    final zone = _edgeScrollZone.h;
    final height = viewport.size.height;
    var velocity = 0.0;
    if (fingerY < zone) {
      velocity = -((zone - fingerY) / zone).clamp(0.0, 1.0) * _edgeScrollSpeed;
    } else if (fingerY > height - zone) {
      velocity =
          ((fingerY - (height - zone)) / zone).clamp(0.0, 1.0) *
          _edgeScrollSpeed;
    }
    if (velocity == 0) return;
    final position = _scroll.position;
    final next = (position.pixels + velocity * seconds).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) return;
    _scroll.jumpTo(next);
    _updateHover();
    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // 그리기
  // ---------------------------------------------------------------------------

  /// 끄는 동안 들린 칸 상자 (손가락 - 집은 지점), 안착 중이면 내려앉는 자리
  Rect _overlayRect() {
    final landing = _landing;
    if (landing != null) {
      return Rect.lerp(landing.from, landing.to, _easedLand)!;
    }
    final geometry = _geometry!;
    final topLeft = _toContent(_fingerGlobal) - _grab;
    return topLeft & Size(geometry.tileWidth, geometry.tileHeight);
  }

  double _overlayScale() {
    final landing = _landing;
    if (landing != null) {
      return lerpDouble(landing.fromScale, landing.toScale, _easedLand)!;
    }
    return 1 + _liftScale * _easedLift;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = _geometryFor(context, constraints.maxWidth);
        _geometry = geometry;
        return AnimatedBuilder(
          animation: Listenable.merge([_lift, _land]),
          builder: (context, _) => _buildGrid(geometry, constraints),
        );
      },
    );
  }
}
