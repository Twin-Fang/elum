part of 'library_entry_grid.dart';

/// 일과관리 격자 그리기: 칸 목록 · 자리 계산 · 칸 모양 · 들린 칸 (끌기 상태는 읽기만 한다)
extension _LibraryGridCells on _LibraryEntryGridState {
  /// 칸 한 개가 차지하는 최소 폭(393 기준). 이 폭으로 열 수를 정한다 (폰 4열)
  static const _tileMinWidth = 84.0;
  static const _minColumns = 4;
  static const _maxColumns = 8;

  /// 끌어 온 일과가 그림 위에 겹친 칸을 키우는 비율
  static const _mergeTargetScale = 1.1;

  /// 칸 이름 두 줄 높이를 잴 때 쓰는 글 (줄바꿈으로 정확히 두 줄, 줄 높이는 글자와 무관)
  static const _twoLineSample = 'A\nA';

  /// 화면 좌표 > 격자 내용(스크롤 안) 좌표
  Offset _toContent(Offset global) {
    final box = _contentKey.currentContext?.findRenderObject();
    return box is RenderBox ? box.globalToLocal(global) : global;
  }

  /// 격자 내용 좌표 상자 > 화면 좌표 상자 (메뉴 자리)
  Rect? _globalRectOf(Rect contentRect) {
    final box = _contentKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(contentRect.topLeft) & contentRect.size;
  }

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

  /// 들린 칸 크기: 끄는 동안 집은 만큼 키우고, 안착 중이면 내려앉는 크기
  double _overlayScale() {
    final landing = _landing;
    if (landing != null) {
      return lerpDouble(landing.fromScale, landing.toScale, _easedLand)!;
    }
    return 1 + _LibraryEntryGridState._liftScale * _easedLift;
  }

  /// 칸 옆 메뉴 열기 (진짜 메뉴 — 손가락을 뗀 뒤에만 띄운다)
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

  /// 칸 옆 메뉴 미리보기를 띄운다 (누를 수 없는 같은 모양)
  void _showMenuPreview(LibraryEntry entry, Rect contentRect) {
    final rect = _globalRectOf(contentRect);
    if (rect == null) return;
    _menuPreviewTarget = (entry: entry, rect: rect);
    _menuPreview.show();
  }

  void _hideMenuPreview() {
    if (!mounted || _menuPreviewTarget == null) return;
    _menuPreviewTarget = null;
    _menuPreview.hide();
  }

  /// 보이는 칸: 서버 목록 > 놓은 순서 덧씌우기 > 숨긴 칸 빼기
  List<LibraryEntry> get _shownEntries {
    final override = _orderOverride;
    var entries = widget.entries;
    if (override != null) {
      final byId = {for (final entry in entries) entry.id: entry};
      entries = [for (final id in override) ?byId.remove(id), ...byId.values];
    }
    return [
      for (final entry in entries)
        if (entry.id != _hiddenId) entry,
    ];
  }

  /// 칸마다 설 자리: 끄는 중이면 나머지가 빈자리를 건너뛰고, 끄는 칸은 빈자리에(보이지 않게)
  List<({LibraryEntry entry, int slot})> _placements(List<LibraryEntry> shown) {
    final dragId = _dragId;
    final gap = _hover?.gap;
    if (dragId == null || gap == null) {
      return [
        for (final (index, entry) in shown.indexed) (entry: entry, slot: index),
      ];
    }
    return [
      for (final (index, entry) in _othersOf(shown).indexed)
        (entry: entry, slot: index < gap ? index : index + 1),
      for (final entry in shown)
        if (entry.id == dragId) (entry: entry, slot: gap),
    ];
  }

  /// 끄는 칸을 뺀 나머지 칸
  List<LibraryEntry> _othersOf(List<LibraryEntry> shown) => [
    for (final entry in shown)
      if (entry.id != _dragId) entry,
  ];

  LibraryGridGeometry _geometryFor(BuildContext context, double width) {
    final space = context.space;
    final columns = (width / _tileMinWidth.w).floor().clamp(
      _minColumns,
      _maxColumns,
    );
    final spacingX = space.xs.w;
    final paddingX = space.md.w;
    return LibraryGridGeometry(
      columns: columns,
      tileWidth: (width - paddingX * 2 - spacingX * (columns - 1)) / columns,
      // 그림 칸 + 이름 두 줄이 들어가는 높이 (글자 크기 설정 반영)
      tileHeight:
          LibraryRoutineTile.iconSize.w +
          space.xs.h +
          _twoLineLabelHeight(context),
      iconSize: LibraryRoutineTile.iconSize.w,
      spacingX: spacingX,
      spacingY: space.md.h,
      paddingLeft: paddingX,
      paddingTop: space.sm.h,
    );
  }

  /// 칸 이름 두 줄 높이: 칸 이름 글자 기준 실제 측정 (글자 배율 반영, 기본 크기면 시안 24)
  double _twoLineLabelHeight(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: _twoLineSample,
        style: context.typo.libraryTileLabel,
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout();
    final measured = painter.height;
    painter.dispose();
    return measured;
  }

  /// 낱개 일과 칸 중 첫째 · 둘째에 코치마크 키를 붙인다 (일과 id > 키)
  Map<String, GlobalKey> _coachKeysByRoutineId(List<LibraryEntry> shown) {
    final looseRoutines = shown
        .whereType<LibraryRoutineEntry>()
        .map((entry) => entry.routine.id)
        .take(2)
        .toList();
    return {
      if (looseRoutines.isNotEmpty && widget.firstRoutineTileKey != null)
        looseRoutines[0]: widget.firstRoutineTileKey!,
      if (looseRoutines.length > 1 && widget.secondRoutineTileKey != null)
        looseRoutines[1]: widget.secondRoutineTileKey!,
    };
  }

  /// 격자 전체: 칸마다 자리로 미끄러져 서고(빈자리 · 순서 변화), 끄는 칸은 맨 위에 들린 채
  Widget _buildGrid(LibraryGridGeometry geometry, BoxConstraints constraints) {
    final shown = _shownEntries;
    final coachKeys = _coachKeysByRoutineId(shown);
    final mergeIndex = _hover?.mergeOtherIndex;
    final mergeTargetId = mergeIndex == null
        ? null
        : _othersOf(shown).elementAtOrNull(mergeIndex)?.id;
    final dragged = shown.where((entry) => entry.id == _dragId).firstOrNull;
    final landing = _landing;
    return SingleChildScrollView(
      key: _viewportKey,
      controller: _scroll,
      // 끄는 동안은 손가락으로 굴리지 않는다 (가장자리 자동 굴림만)
      physics: _dragId != null
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        width: constraints.maxWidth,
        height: geometry.contentHeight(shown.length, widget.bottomSpace),
        child: Stack(
          key: _contentKey,
          clipBehavior: Clip.none,
          children: [
            for (final (:entry, :slot) in _placements(shown))
              AnimatedPositioned.fromRect(
                key: ValueKey('cell-${entry.id}'),
                rect: geometry.slotRect(slot),
                duration: AppMotion.fast,
                curve: Curves.easeOutCubic,
                child: Opacity(
                  // 끄는 칸의 제자리는 비워 둔다 (손가락 밑의 들린 칸이 그 칸이다)
                  opacity: entry.id == _dragId ? 0 : 1,
                  child: KeyedSubtree(
                    key: coachKeys[entry.id],
                    child: _buildCell(
                      entry,
                      slot,
                      isMergeTarget: entry.id == mergeTargetId,
                    ),
                  ),
                ),
              ),
            if (dragged != null)
              LibraryGridLiftedTile(
                rect: _overlayRect(),
                anchor: Alignment(
                  _grab.dx / geometry.tileWidth * 2 - 1,
                  _grab.dy / geometry.tileHeight * 2 - 1,
                ),
                scale: _overlayScale(),
                lift: landing == null ? _easedLift : 1 - _easedLand,
                opacity: landing == null
                    ? 1
                    : lerpDouble(1, landing.toOpacity, _easedLand)!,
                child: switch (dragged) {
                  LibraryRoutineEntry(:final routine) => _routineTile(routine),
                  final LibraryGroupEntry group => _groupTile(group),
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 길게 누르는 동안의 칸 옆 메뉴: 손을 떼면 같은 자리에 뜨는 진짜 메뉴와 같은 모양 (누를 수 없음)
  Widget _buildMenuPreview(BuildContext context) {
    final target = _menuPreviewTarget;
    if (target == null) return const SizedBox.shrink();
    final Widget view = switch (target.entry) {
      LibraryRoutineEntry(:final routine) =>
        AnchoredQuickMenuView<LibraryMenuAction>(
          anchor: target.rect,
          highlight: _routineTile(routine),
          rows: libraryMenuRows(context, routine),
        ),
      final LibraryGroupEntry group => AnchoredQuickMenuView<GroupMenuAction>(
        anchor: target.rect,
        highlight: _groupTile(group),
        rows: groupMenuRows(context),
      ),
    };
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.fast,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: view,
      ),
    );
  }

  /// 칸 하나: 정리 껍데기(흔들림 · ⊖) > 끌기 제스처 > 칸 모양
  Widget _buildCell(
    LibraryEntry entry,
    int slot, {
    required bool isMergeTarget,
  }) {
    final isArranging = widget.isArranging;
    final Widget tile = switch (entry) {
      LibraryRoutineEntry(:final routine) => AnimatedScale(
        scale: isMergeTarget ? _mergeTargetScale : 1,
        duration: AppMotion.fast,
        child: _routineTile(
          routine,
          onTap: isArranging ? null : () => widget.onRoutineTap?.call(routine),
        ),
      ),
      final LibraryGroupEntry group => _groupTile(
        group,
        isDropTarget: isMergeTarget,
        onTap: isArranging ? null : () => widget.onGroupTap?.call(group),
      ),
    };
    return LibraryArrangeShell(
      isArranging: isArranging && entry.id != _dragId,
      isAlternatePhase: slot.isOdd,
      isRemovable: switch (entry) {
        LibraryRoutineEntry(:final routine) => routine.isEditableByMe,
        LibraryGroupEntry() => true,
      },
      onRemove: () => switch (entry) {
        LibraryRoutineEntry(:final routine) => widget.onRemoveRoutine?.call(
          routine,
        ),
        final LibraryGroupEntry group => widget.onRemoveGroup?.call(group),
      },
      child: _canDrag(entry) ? _withDragGesture(entry, tile) : tile,
    );
  }

  /// 메뉴가 있는 칸만 끌린다 (다른 동작이 도는 중이면 메뉴가 null)
  bool _canDrag(LibraryEntry entry) => switch (entry) {
    LibraryRoutineEntry() => widget.onRoutineMenu != null,
    LibraryGroupEntry() => widget.onGroupMenu != null,
  };

  /// 길게 눌러 집기 (정리 상태면 누르자마자 끌기도). 끄는 중에 정리 상태로 바뀌어도
  /// 길게 누르기 인식기는 그대로 두어 지금 끄는 손가락이 끊기지 않는다
  Widget _withDragGesture(LibraryEntry entry, Widget tile) {
    return RawGestureDetector(
      gestures: {
        DelayedMultiDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              DelayedMultiDragGestureRecognizer
            >(
              () => DelayedMultiDragGestureRecognizer(debugOwner: this),
              (recognizer) =>
                  recognizer.onStart = (position) =>
                      _startDrag(entry, position, isLongPress: true),
            ),
        if (widget.isArranging)
          ImmediateMultiDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                ImmediateMultiDragGestureRecognizer
              >(
                () => ImmediateMultiDragGestureRecognizer(debugOwner: this),
                (recognizer) =>
                    recognizer.onStart = (position) =>
                        _startDrag(entry, position, isLongPress: false),
              ),
      },
      child: tile,
    );
  }

  Widget _routineTile(Routine routine, {VoidCallback? onTap}) =>
      LibraryRoutineTile(
        routine: routine,
        isSentToday: widget.sentIds.contains(routine.id),
        onTap: onTap ?? () {},
      );

  Widget _groupTile(
    LibraryGroupEntry entry, {
    bool isDropTarget = false,
    VoidCallback? onTap,
  }) => LibraryGroupTile(
    entry: entry,
    isSentToday: entry.routines.every(
      (routine) => widget.sentIds.contains(routine.id),
    ),
    isDropTarget: isDropTarget,
    onTap: onTap ?? () {},
    onLongPress: null,
  );
}

/// 놓은 뒤 안착 계획: 들린 칸 상자 · 크기에서 자리 상자 · 크기 · 투명도로
class _LandingPlan {
  const _LandingPlan({
    required this.from,
    required this.fromScale,
    required this.to,
    required this.toScale,
    required this.toOpacity,
  });

  final Rect from;
  final double fromScale;
  final Rect to;
  final double toScale;
  final double toOpacity;
}

/// 끌기 제스처 한 번을 격자 콜백으로 잇는다
class _GridDrag extends Drag {
  _GridDrag({
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;
  final VoidCallback onCancel;

  @override
  void update(DragUpdateDetails details) => onUpdate(details);

  @override
  void end(DragEndDetails details) => onEnd(details);

  @override
  void cancel() => onCancel();
}
