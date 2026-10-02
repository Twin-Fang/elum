import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/action_card.dart';
import 'action_card_view.dart';

/// 끌던 카드가 들어갈 자리 — 손가락이 가리키는 **사이**를 센다 (#471).
///
/// [contentX] 는 스크롤 내용 안의 가로 좌표(줌아웃 전 크기 기준)다. 끌고 있는 카드를 뺀
/// 나머지 [count]장이 [leading] 에서 시작해 [extent] 간격으로 서 있고, 지금 [gap] 번째
/// 앞에 카드 한 장 폭의 틈이 벌어져 있다고 본다. 중심이 [contentX] 보다 왼쪽에 있는
/// 카드 수가 곧 들어갈 자리(0~count)다.
///
/// **눈에 보이는 배치(벌어진 틈 포함)로 잰다.** 그래야 손가락이 틈 안에 있는 동안은 자리가
/// 바뀌지 않는다 — 이웃의 중심을 지나야 틈이 옮겨 가므로 깜빡이지 않는다.
int reorderInsertionIndex({
  required double contentX,
  required int count,
  required double leading,
  required double extent,
  required int gap,
}) {
  var k = 0;
  for (var j = 0; j < count; j++) {
    final center = leading + j * extent + (j >= gap ? extent : 0) + extent / 2;
    if (center < contentX) k = j + 1;
  }
  return k;
}

/// 순서 변경 모드의 카드 줄 — 길게 눌러 손가락을 따라 옮긴다 (시안 1197:5798 · #471).
///
/// 평소에는 기본 화면과 같은 자리(카드 333 @ x=30, 사이 10)에 서서 한 장씩 정면에 붙는다.
/// **길게 눌러 카드를 집으면** 화면 전체가 [_zoomScale] 로 줌아웃해 옆 카드 여럿이 보이고,
/// 집은 카드는 손가락 아래에 붙어 좌우·상하로 따라온다. 카드를 사이에 가져다 대면 그 자리가
/// 벌어지고, **놓으면** 벌어진 자리로 안착하는 움직임과 줌인이 한 번에 끝난다.
///
/// 가로 `ReorderableListView` 는 축이 고정이고 이웃이 절반을 넘어야 비켜서 이 동작을
/// 만들 수 없어 직접 만들었다.
class CardReviewReorderList extends StatefulWidget {
  const CardReviewReorderList({
    super.key,
    required this.cards,
    required this.routineId,
    required this.cardWidth,
    required this.cardGap,
    required this.onReorder,
    this.initialIndex = 0,
    this.onFocusChanged,
  });

  final List<ActionCard> cards;
  final String routineId;

  /// 카드 폭과 카드 사이 (기본 화면과 같은 값 — 모드를 바꿔도 카드가 움직이지 않는다)
  final double cardWidth;
  final double cardGap;

  /// `ReorderableListView.onReorder` 와 같은 약속이다 — 아래로 옮길 때 [newIndex] 는
  /// 빼기 전 위치를 기준으로 한다. 알림자(`moveStep`)가 이 값을 그대로 받는다.
  final void Function(int oldIndex, int newIndex) onReorder;

  /// 모드에 들어올 때 정면에 세울 카드. 보던 카드에서 시작해야 1번으로 튀지 않는다.
  final int initialIndex;

  /// 정면에 선 카드가 바뀔 때(스크롤이 멎거나 놓았을 때). 모드를 나올 때 그 카드에서
  /// 기본 화면을 이어 열려고 화면이 기억한다.
  final ValueChanged<int>? onFocusChanged;

  @override
  State<CardReviewReorderList> createState() => _CardReviewReorderListState();
}

class _CardReviewReorderListState extends State<CardReviewReorderList>
    with TickerProviderStateMixin {
  /// 집었을 때 화면 전체가 줄어드는 비율. 5장 안팎의 순서를 한눈에 보려는 값이다.
  /// **시안에 없는 값**이라 디자이너 확인 뒤 바뀔 수 있다 (#471).
  static const _zoomScale = 0.4;

  /// 집은 카드가 이웃보다 더 커 보이는 비율
  static const _liftScale = 0.04;

  /// 가장자리 자동 스크롤의 최고 속도(px/s). 예전에는 카드가 두세 장씩 밀렸다.
  static const _edgeSpeed = 360.0;

  /// 자리가 벌어지고 닫히는 시간
  static const _slotDuration = Duration(milliseconds: 220);

  final _areaKey = GlobalKey();

  late final _scroll = ScrollController(initialScrollOffset: _initialOffset());
  late final _zoom = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
  );
  late final _land = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
  );
  late final Ticker _ticker = createTicker(_onTick);

  /// 카드 id → 색·번호를 정하는 자리. 안착한 **다음에** 새 자리로 갱신한다 — 옮겨지는
  /// 도중에 색이 바뀌면 어지럽다 (#451).
  late Map<String, int> _shown = _indexOf(widget.cards);

  double _viewW = 0;
  double _viewH = 0;

  // --- 끌기 상태 ---
  String? _dragId;
  int _dragFrom = 0;

  /// 끌고 있는 카드를 뺀 줄에서 들어갈 자리. null 이면 벌어진 곳이 없다.
  int? _gap;

  /// 손가락 위치 (줄 영역 안 좌표, 화면 그대로의 크기)
  Offset _finger = Offset.zero;

  /// 집는 순간 손가락이 카드 안 어디였나 (줌아웃 전 크기). 카드가 줄어들어도 이 점이
  /// 손가락 아래에 남는다.
  Offset _grab = Offset.zero;
  double _grabScroll = 0;
  double _grabX = 0;
  Duration _lastTick = Duration.zero;

  // --- 안착 상태 ---
  bool _landing = false;
  double _landScale0 = 1;
  double _landOverlayScale0 = 1;
  double _landScroll0 = 0;
  double _landScrollTo = 0;
  Offset _landTopLeft0 = Offset.zero;

  double get _pad => 25.w;
  double get _ext => (widget.cardWidth + widget.cardGap).w;

  double get _easedZoom => Curves.easeOutCubic.transform(_zoom.value);
  double get _easedLand => Curves.easeOutCubic.transform(_land.value);

  /// 지금 줄이 줄어든 비율. 평소 1, 집으면 [_zoomScale] 까지 줄고 놓으면 1 로 돌아온다.
  double get _scale => _landing
      ? lerpDouble(_landScale0, 1, _easedLand)!
      : lerpDouble(1, _zoomScale, _easedZoom)!;

  double get _overlayScale => _landing
      ? lerpDouble(_landOverlayScale0, 1, _easedLand)!
      : _scale * (1 + _liftScale * _easedZoom);

  /// 들린 카드의 왼쪽 위. 끄는 동안은 손가락에 붙고, 놓은 뒤에는 안착 자리로 간다.
  Offset get _overlayTopLeft => _landing
      ? Offset.lerp(_landTopLeft0, Offset(_pad, 0), _easedLand)!
      : _finger - _grab * _overlayScale;

  static Map<String, int> _indexOf(List<ActionCard> cards) => {
    for (var i = 0; i < cards.length; i++) cards[i].id: i,
  };

  double _initialOffset() {
    final last = math.max(0, widget.cards.length - 1);
    return widget.initialIndex.clamp(0, last) * _ext;
  }

  /// 줄어들 때 손가락 밑의 내용을 붙잡아 두려면 필요한 스크롤 위치. 손가락 x 를 기준점으로
  /// 줌아웃한다 — 가운데 근처 카드를 집으면 그 카드의 원래 자리가 손가락 아래에 남는다.
  ///
  /// 양 끝 카드는 스크롤 범위를 넘어 기준점을 지킬 수 없다. 빈 여백을 만들어 지키면 화면의
  /// 절반이 비어 순서를 읽을 수 없으므로, 범위 안에서 가장 가깝게 맞춘다 (실기기 실측).
  double _pivotScroll(double scale) => scale * (_grabScroll + _grabX) - _grabX;

  /// [scale] 로 줄였을 때 스크롤할 수 있는 끝. 끄는 동안에도 카드 수(빈 자리 포함)는 그대로라
  /// 내용 폭이 변하지 않는다.
  double _maxScroll(double scale) =>
      math.max(0.0, (2 * _pad + widget.cards.length * _ext) * scale - _viewW);

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_onZoomTick);
    _land.addListener(_onLandTick);
  }

  @override
  void didUpdateWidget(CardReviewReorderList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragId != null && !widget.cards.any((c) => c.id == _dragId)) {
      // 끌던 카드가 목록에서 사라졌다 — 상태를 정리하고 평소로 돌아간다
      _ticker.stop();
      _zoom.value = 0;
      _land.value = 0;
      _dragId = null;
      _landing = false;
      _gap = null;
    }
    // 끄는 중에는 안착이 끝난 뒤에 갱신한다. 그 밖(접근성 동작 등)은 바로 새 자리 색이다.
    if (_dragId == null) _shown = _indexOf(widget.cards);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _zoom.dispose();
    _land.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Offset _toLocal(Offset global) {
    final box = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(global) ?? global;
  }

  void _jump(double target) {
    if (!_scroll.hasClients) return;
    final value = target.clamp(0.0, _maxScroll(_scale));
    if (value != _scroll.offset) _scroll.jumpTo(value);
  }

  // ---------------------------------------------------------------------------
  // 집기 · 끌기 · 놓기
  // ---------------------------------------------------------------------------

  void _onGrab(ActionCard card, int index, LongPressStartDetails d) {
    // 카드가 한 장이면 옮길 곳이 없다. 이미 집었거나 안착 중이면 두 번째 손가락은 무시한다.
    if (_dragId != null || widget.cards.length < 2 || !_scroll.hasClients) {
      return;
    }
    HapticFeedback.mediumImpact();
    final local = _toLocal(d.globalPosition);
    setState(() {
      _dragId = card.id;
      _dragFrom = index;
      _gap = index;
      _finger = local;
      // 평소(줌아웃 전)에 집으므로 눌린 곳의 좌표가 곧 줌아웃 전 크기의 좌표다
      _grab = d.localPosition;
      _grabScroll = _scroll.offset;
      _grabX = local.dx;
    });
    _lastTick = Duration.zero;
    _ticker.start();
    _zoom.forward(from: 0);
  }

  void _onMove(LongPressMoveUpdateDetails d) {
    if (_dragId == null || _landing) return;
    _finger = _toLocal(d.globalPosition);
    _updateGap();
    setState(() {});
  }

  /// 손가락이 가리키는 사이를 다시 재서 바뀌었으면 자리를 옮긴다.
  void _updateGap() {
    if (_dragId == null || _landing || !_scroll.hasClients) return;
    final current = _gap;
    if (current == null) return;
    final contentX = (_scroll.offset + _finger.dx) / _scale;
    final k = reorderInsertionIndex(
      contentX: contentX,
      count: widget.cards.length - 1,
      leading: _pad,
      extent: _ext,
      gap: current,
    );
    if (k != current) setState(() => _gap = k);
  }

  void _onDrop() {
    if (_dragId == null || _landing) return;
    final from = _dragFrom;
    final to = _gap ?? _dragFrom;
    if (to != from) widget.onReorder(from, to > from ? to + 1 : to);
    _beginLanding(to);
  }

  /// 제스처가 끊겼다(전화 수신·시스템 제스처 등). 옮기지 않고 원래 자리로 돌려놓는다.
  void _onCancel() {
    if (_dragId == null || _landing) return;
    setState(() => _gap = _dragFrom);
    _beginLanding(_dragFrom);
  }

  /// 안착과 줌인을 한 번에 시작한다 — 화면이 두 번 출렁이지 않게 한 컨트롤러로 묶는다.
  void _beginLanding(int landedIndex) {
    _ticker.stop();
    _landScale0 = _scale;
    _landOverlayScale0 = _overlayScale;
    _landTopLeft0 = _overlayTopLeft;
    _landScroll0 = _scroll.hasClients ? _scroll.offset : 0;
    // 안착한 카드가 기본 화면처럼 x=30 에 서도록 잡는다
    _landScrollTo = math.min(landedIndex * _ext, _maxScroll(1));
    setState(() {
      _landing = true;
      _gap = null;
    });
    _land.forward(from: 0).whenComplete(() => _finishLanding(landedIndex));
  }

  void _finishLanding(int landedIndex) {
    if (!mounted || !_landing) return;
    setState(() {
      _dragId = null;
      _landing = false;
      _gap = null;
      _zoom.value = 0;
      _land.value = 0;
    });
    widget.onFocusChanged?.call(landedIndex);
    // 카드가 제자리에 들어간 **다음 프레임에** 색·번호를 바꾼다. 같은 프레임에 바꾸면
    // 새로 그려진 카드가 처음부터 새 색으로 서서 섞이는 움직임이 없다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dragId != null) return;
      HapticFeedback.selectionClick();
      setState(() => _shown = _indexOf(widget.cards));
    });
  }

  void _onZoomTick() {
    if (_dragId == null || _landing) return;
    // 줌아웃 도중에도 집은 자리 밑의 내용이 그대로 있도록 스크롤을 맞춘다
    _jump(_pivotScroll(_scale));
    _updateGap();
  }

  void _onLandTick() {
    if (!_landing) return;
    _jump(lerpDouble(_landScroll0, _landScrollTo, _easedLand)!);
  }

  /// 손가락이 화면 가장자리에 닿으면 줄을 스크롤한다. 줌아웃이 끝난 뒤에만 켠다 —
  /// 집자마자 가장자리 카드가 도망가면 곤란하다.
  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (_dragId == null ||
        _landing ||
        !_zoom.isCompleted ||
        !_scroll.hasClients) {
      return;
    }
    final edge = 64.w;
    var velocity = 0.0;
    if (_finger.dx < edge) {
      velocity = -((edge - _finger.dx) / edge).clamp(0.0, 1.0) * _edgeSpeed;
    } else if (_finger.dx > _viewW - edge) {
      velocity =
          ((_finger.dx - (_viewW - edge)) / edge).clamp(0.0, 1.0) * _edgeSpeed;
    }
    if (velocity == 0) return;
    final before = _scroll.offset;
    _jump(before + velocity * dt);
    if (_scroll.offset != before) _updateGap();
  }

  void _reportFocus() {
    if (!_scroll.hasClients || widget.cards.isEmpty) return;
    final index = (_scroll.offset / _ext).round().clamp(
      0,
      widget.cards.length - 1,
    );
    widget.onFocusChanged?.call(index);
  }

  /// 스크린리더용 — 끌지 못하는 사람이 카드를 한 칸씩 옮긴다.
  void _nudge(int index, int delta) {
    final to = index + delta;
    if (_dragId != null || to < 0 || to >= widget.cards.length) return;
    widget.onReorder(index, delta < 0 ? to : to + 1);
    widget.onFocusChanged?.call(to);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        math.min(to * _ext, _maxScroll(1)),
        duration: AppMotion.normal,
        curve: Curves.easeOutCubic,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 그리기
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _viewW = box.maxWidth;
        _viewH = box.maxHeight;
        return AnimatedBuilder(
          animation: Listenable.merge([_zoom, _land]),
          builder: (context, _) => _buildArea(context),
        );
      },
    );
  }

  Widget _buildArea(BuildContext context) {
    final scale = _scale;
    final cards = widget.cards;
    final others = [
      for (final c in cards)
        if (c.id != _dragId) c,
    ];
    final gap = _gap;
    final gapBeforeId = gap != null && gap < others.length
        ? others[gap].id
        : null;
    final trailingGap = gap != null && gap >= others.length;
    ActionCard? dragged;
    for (final c in cards) {
      if (c.id == _dragId) dragged = c;
    }

    return NotificationListener<ScrollEndNotification>(
      onNotification: (_) {
        // 끄는 동안의 스크롤은 우리가 옮기는 것이다 — 정면 카드를 알리지 않는다
        if (_dragId == null) _reportFocus();
        return false;
      },
      child: Stack(
        key: _areaKey,
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: _viewW,
            height: _viewH,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              // 끄는 동안은 손가락으로 스크롤하지 않는다(두 번째 손가락 대비)
              physics: _dragId != null
                  ? const NeverScrollableScrollPhysics()
                  : _CardSnapPhysics(itemExtent: _ext),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: _pad * scale),
                  for (var i = 0; i < cards.length; i++)
                    _slot(
                      cards[i],
                      i,
                      scale,
                      gapBefore: cards[i].id == gapBeforeId,
                    ),
                  _spacer('trailing', trailingGap ? 1 : 0, scale),
                  SizedBox(width: _pad * scale),
                ],
              ),
            ),
          ),
          if (dragged != null) _overlay(context, dragged),
        ],
      ),
    );
  }

  /// 자리가 벌어지고 닫히는 폭 — 카드 한 장 폭의 [factor] 배.
  Widget _spacer(String name, double factor, double scale) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('spacer_$name'),
      tween: Tween(end: factor),
      duration: _slotDuration,
      curve: Curves.easeOutCubic,
      builder: (context, f, _) => SizedBox(width: _ext * scale * f),
    );
  }

  Widget _slot(
    ActionCard card,
    int index,
    double scale, {
    required bool gapBefore,
  }) {
    // 끌려간 카드의 자리는 닫힌다. 안착하는 동안은 다시 열려 카드가 들어올 자리가 된다.
    final open = (card.id == _dragId && !_landing) ? 0.0 : 1.0;
    final canMove = widget.cards.length > 1;

    Widget child = GestureDetector(
      onLongPressStart: (d) => _onGrab(card, index, d),
      onLongPressMoveUpdate: _onMove,
      onLongPressEnd: (_) => _onDrop(),
      onLongPressCancel: _onCancel,
      child: card.id == _dragId
          // 들린 카드는 위에 떠 있다. 자리에는 아무것도 그리지 않는다.
          ? const SizedBox.shrink()
          : SizedBox(
              width: _ext * scale,
              height: _viewH * scale,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: _ext,
                  height: _viewH,
                  child: _cardBody(card, index),
                ),
              ),
            ),
    );

    if (canMove) {
      final l10n = context.l10n;
      child = Semantics(
        customSemanticsActions: {
          if (index > 0)
            CustomSemanticsAction(label: l10n.cardMoveForward): () =>
                _nudge(index, -1),
          if (index < widget.cards.length - 1)
            CustomSemanticsAction(label: l10n.cardMoveBackward): () =>
                _nudge(index, 1),
        },
        child: child,
      );
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey('slot_${card.id}'),
      tween: Tween(end: open + (gapBefore ? 1 : 0)),
      duration: _slotDuration,
      curve: Curves.easeOutCubic,
      builder: (context, f, content) => SizedBox(
        width: _ext * scale * f,
        // 카드는 자리의 오른쪽 끝에 붙는다 — 벌어진 틈이 카드 **앞**에 생긴다
        child: Align(alignment: Alignment.centerRight, child: content),
      ),
      child: child,
    );
  }

  Widget _cardBody(ActionCard card, int index) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: (widget.cardGap / 2).w),
      child: ActionCardView(
        key: ValueKey(card.id),
        card: card,
        // 색·번호는 안착한 뒤에 새 자리로 바뀐다
        index: _shown[card.id] ?? index,
        routineId: widget.routineId,
        // 모드 안에서는 소리를 읽지 않는다 — 카드가 움직이는 중이다
        onSpeak: () {},
        isSpeaking: false,
        onDelete: null,
      ),
    );
  }

  /// 손가락을 따라다니는 카드. 이웃보다 조금 크게 그리고 그림자를 깐다.
  Widget _overlay(BuildContext context, ActionCard card) {
    final top = _overlayTopLeft;
    final strength = _landing ? 1 - _easedLand : _easedZoom;
    final radius = context.space.cardRadius;
    final index = widget.cards.indexWhere((c) => c.id == card.id);

    return Positioned(
      left: top.dx,
      top: top.dy,
      width: _ext,
      height: _viewH,
      child: IgnorePointer(
        child: Transform.scale(
          scale: _overlayScale,
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: (widget.cardGap / 2).w),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24 * strength),
                    blurRadius: 24 * strength,
                    offset: Offset(0, 10 * strength),
                  ),
                ],
              ),
              child: ActionCardView(
                key: ValueKey(card.id),
                card: card,
                index: _shown[card.id] ?? index,
                routineId: widget.routineId,
                onSpeak: () {},
                isSpeaking: false,
                onDelete: null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 스크롤을 놓으면 가장 가까운 카드가 정면(정중앙)에 붙는 물리.
///
/// 기본 화면의 페이지 뷰와 같은 동작이다. 속도가 있으면 그 방향 다음 카드로 넘어간다.
class _CardSnapPhysics extends ScrollPhysics {
  const _CardSnapPhysics({required this.itemExtent, super.parent});

  final double itemExtent;

  @override
  _CardSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _CardSnapPhysics(itemExtent: itemExtent, parent: buildParent(ancestor));

  double _targetPixels(ScrollMetrics position, double velocity) {
    var page = position.pixels / itemExtent;
    if (velocity < -toleranceFor(position).velocity) {
      page -= 0.5;
    } else if (velocity > toleranceFor(position).velocity) {
      page += 0.5;
    }
    return page.roundToDouble() * itemExtent;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // 양 끝 밖으로 나가 있으면 기본 물리가 되돌린다
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final target = _targetPixels(
      position,
      velocity,
    ).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target == position.pixels) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}
