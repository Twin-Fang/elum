import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/l10n_context.dart';
import '../assets/app_assets.dart';
import '../theme/app_motion.dart';
import '../theme/theme_context_ext.dart';
import 'coach_mark_parts.dart';

/// 말풍선 글을 어느 쪽에 맞출지.
enum CoachMarkAlign { center, end }

/// 코치마크 한 단계 — 무엇을 가리키고 뭐라고 말하는가.
class CoachMarkStep {
  const CoachMarkStep({
    required this.target,
    required this.message,
    this.align = CoachMarkAlign.center,
    this.holePadding = EdgeInsets.zero,
    this.holeRadius = 0,
    this.feather = 0,
    this.bleedLeft = false,
    this.pointerAt = 0.5,
    this.pointerGap = 0,
    this.partsOf,
    this.partRadius = 0,
  });

  /// 가리킬 위젯. 화면에 그려져 있어야 잴 수 있다.
  final GlobalKey target;

  /// 말풍선 글. `*강조*` 로 감싼 부분은 강조색으로 나온다.
  final String message;

  final CoachMarkAlign align;

  /// 대상보다 구멍을 얼마나 키울지.
  final EdgeInsets holePadding;
  final double holeRadius;

  /// 가장자리를 풀어 줄 정도 — 대상이 빛나면(글로우) 준다.
  final double feather;

  /// 구멍을 화면 왼쪽 끝까지 넓힌다. 밀려 나간 카드가 화면 가장자리에서 잘려 보이는 자리다
  /// (시안 1291:10401).
  final bool bleedLeft;

  /// 화살표가 대상 가로의 어디를 가리키는가(0~1). 밀어서 열린 줄은 버튼 쪽을 가리킨다.
  final double pointerAt;

  /// 구멍 가장자리에서 화살표가 시작하기까지 띄울 거리 (시안 1291:10730 은 배지에서 3 떨어진다).
  final double pointerGap;

  /// 대상 안에서 실제로 밝을 모양들. 대상 상자를 받아 돌려준다. 없으면 상자 전체가 밝다.
  final List<Rect> Function(Rect target)? partsOf;
  final double partRadius;
}

/// 화면을 어둡게 덮고 대상 하나만 밝게 뚫어 한 번에 하나씩 가리키는 안내 (Figma 코치마크 1291:10801).
///
/// - **어디든 누르면 다음으로**, 마지막에서는 닫는다. 닫기 ✕ 는 어느 단계에서나 있다.
/// - 구멍은 앞 단계에서 뒤 단계로 **미끄러져 이동**하고, 말풍선은 겹쳐 바뀐다.
///   동작 줄이기를 켠 사람에게는 이동 없이 바로 바꾼다.
/// - 가리킬 대상을 못 재면(아직 안 그려졌거나 화면 밖) 그 단계는 건너뛴다.
///
/// 몇 단계를 보여줄지, 언제 띄울지는 부르는 쪽이 정한다. 이 위젯은 그리기만 한다.
class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({
    super.key,
    required this.steps,
    required this.index,
    required this.visible,
    required this.onNext,
    required this.onClose,
    required this.onDismissed,
  });

  final List<CoachMarkStep> steps;
  final int index;

  /// false가 되면 사라지는 연출을 거친 뒤 [onDismissed]를 부른다.
  final bool visible;

  /// 마지막이 아닌 단계에서 눌렸을 때, 또는 대상을 못 재서 건너뛸 때.
  final VoidCallback onNext;

  /// 마지막 단계에서 눌렸거나 ✕·뒤로가기로 닫을 때.
  final VoidCallback onClose;

  /// 사라지는 연출이 끝났을 때. 이제 위젯을 치워도 된다.
  final VoidCallback onDismissed;

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// 0 → 1: 막이 나타난다 / 1 → 0: 사라진다.
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
    reverseDuration: AppMotion.fast,
  );

  /// 구멍이 앞 단계에서 뒤 단계로 옮겨 가는 진행도.
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
    value: 1,
  );

  /// 화살표가 대상 쪽으로 살짝 오갔다 온다. 등속이면 기계 같아 보여 이징을 탄다.
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// 글·점·닫기는 막이 어느 정도 내려앉은 뒤에 떠오른다. 막과 같이 나타나면 한 덩어리로 툭 뜬다.
  late final Animation<double> _contentFade = CurvedAnimation(
    parent: _enter,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );

  CoachHole? _from;
  CoachHole? _to;

  /// [_to] 가 몇 번째 단계를 잰 것인가. 단계가 바뀐 직후 한 프레임은 이전 위치라 말풍선을 아직 안 그린다.
  int? _measuredIndex;
  double _anchorX = 0;

  static const _arrowW = 12.0;
  static const _arrowH = 31.0;

  /// 화살표 끝 ↔ 글 (시안 실측 11)
  static const _arrowToText = 11.0;
  static const _sideMargin = 16.0;
  static const _bobDistance = 3.0;

  /// 처음 나타날 때 구멍이 대상보다 얼마나 넓게 시작하는가.
  static const _introSpread = 28.0;

  /// 아래 점과 안내 문구가 차지하는 자리. 말풍선이 여기를 침범하지 않게 한다.
  static const _bottomReserve = 176.0;

  /// 점과 문구를 화면 바닥에서 띄우는 거리(안전영역 제외). 하단 배너 광고(약 60~100) 위에 놓는다 —
  /// 광고와 겹치면 글자가 광고 위에 얹혀 지저분하다.
  static const _footerBottom = 112.0;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply(first: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      _bob.stop();
    } else if (!_bob.isAnimating && widget.visible) {
      _bob.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant CoachMarkOverlay old) {
    super.didUpdateWidget(old);
    if (old.visible && !widget.visible) {
      _bob.stop();
      _enter.reverse().whenComplete(() {
        if (mounted) widget.onDismissed();
      });
      return;
    }
    if (old.index != widget.index && widget.visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
    }
  }

  /// 화면 크기가 바뀌면(회전·분할 화면) 대상 위치가 달라진다. 움직임 없이 다시 잰다.
  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.visible) _apply(animate: false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _enter.dispose();
    _move.dispose();
    _bob.dispose();
    super.dispose();
  }

  CoachHole? get _hole {
    final to = _to;
    if (to == null) return null;
    final from = _from;
    if (from == null) return to;
    return CoachHole.lerp(
      from,
      to,
      AppMotion.decelerate.transform(_move.value),
    );
  }

  /// 구멍 안에서 다시 어두워야 할 틈. 옮겨 가는 동안 앞 단계의 틈은 옅어지고 뒤 단계의 틈은 짙어진다.
  List<({Path path, double alpha})> _gaps() {
    final t = AppMotion.decelerate.transform(_move.value);
    final from = _from;
    final to = _to;
    return [
      if (from != null && t < 1 && from.gapPath != null)
        (path: from.gapPath!, alpha: 1 - t),
      if (to != null && to.gapPath != null)
        (path: to.gapPath!, alpha: from == null ? 1.0 : t),
    ];
  }

  /// 대상을 재서 구멍을 옮긴다. 못 재면 이 단계는 건너뛴다.
  void _apply({bool first = false, bool animate = true}) {
    if (!mounted || !widget.visible) return;
    final step = widget.steps[widget.index];
    final measured = _measure(step);
    if (measured == null) {
      // 다시 잴 때(화면 크기 변화)는 이전 위치를 그대로 둔다 — 건너뛰는 것은 새 단계일 때만이다.
      if (animate) _skip();
      return;
    }

    final (hole, anchorX) = measured;
    final canTravel = animate && !first && _to != null && !_reduceMotion;
    // 처음 나타날 때는 넓게 열린 구멍이 대상으로 좁혀 들어온다 — 스포트라이트가 내려앉는 느낌.
    final intro = first && !_reduceMotion;
    setState(() {
      _from = canTravel
          ? _hole
          : intro
          ? CoachHole(
              rect: hole.rect.inflate(_introSpread),
              radius: hole.radius + _introSpread,
              feather: hole.feather + _introSpread / 2,
            )
          : null;
      _to = hole;
      _anchorX = anchorX;
      _measuredIndex = widget.index;
    });
    if (canTravel || intro) {
      _move.forward(from: 0);
    } else {
      _move.value = 1;
    }
    if (first) {
      if (_reduceMotion) {
        _enter.value = 1;
      } else {
        _enter.forward();
      }
    }
  }

  void _skip() {
    if (widget.index + 1 >= widget.steps.length) {
      widget.onClose();
    } else {
      widget.onNext();
    }
  }

  /// 대상의 위치를 이 위젯 기준 좌표로 잰다. 못 재거나 화면 밖이면 null.
  (CoachHole, double)? _measure(CoachMarkStep step) {
    final self = context.findRenderObject();
    final target = step.target.currentContext?.findRenderObject();
    if (self is! RenderBox || !self.hasSize) return null;
    if (target is! RenderBox || !target.attached || !target.hasSize) {
      return null;
    }

    final origin = target.localToGlobal(Offset.zero, ancestor: self);
    final box = origin & target.size;
    // 일부라도 화면 밖에 걸쳐 있으면 가리켜도 알아볼 수 없다.
    final screen = (Offset.zero & self.size).inflate(1);
    if (!screen.contains(box.topLeft) || !screen.contains(box.bottomRight)) {
      return null;
    }

    var rect = step.holePadding.inflateRect(box);
    if (step.bleedLeft) {
      rect = Rect.fromLTRB(0, rect.top, rect.right, rect.bottom);
    }
    final anchorX = box.left + box.width * step.pointerAt;
    return (
      CoachHole(rect: rect, radius: step.holeRadius, feather: step.feather),
      anchorX,
    );
  }

  void _tap() {
    if (!widget.visible) return;
    HapticFeedback.selectionClick();
    if (widget.index + 1 >= widget.steps.length) {
      widget.onClose();
    } else {
      widget.onNext();
    }
  }

  void _close() {
    if (!widget.visible) return;
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final step = widget.steps[widget.index];
    final last = widget.index + 1 >= widget.steps.length;

    final base = typo.coachMessage.copyWith(color: colors.coachText);
    final accent = base.copyWith(color: colors.coachAccent);
    final spans = coachMessageSpans(step.message, base: base, accent: accent);
    final textAlign = step.align == CoachMarkAlign.end
        ? TextAlign.right
        : TextAlign.center;
    final reduce = _reduceMotion;

    return BlockSemantics(
      child: PopScope(
        canPop: false,
        // 뒤로가기는 홈을 떠나는 것이 아니라 안내만 닫는다.
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Semantics(
          container: true,
          liveRegion: true,
          label: context.l10n.coachStepLabel(
            widget.index + 1,
            widget.steps.length,
            coachPlainMessage(step.message),
          ),
          onTap: _tap,
          onTapHint: last
              ? context.l10n.coachCloseHint
              : context.l10n.coachNextHint,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_enter, _move]),
                    builder: (context, _) => CustomPaint(
                      painter: CoachScrimPainter(
                        color: colors.coachScrim.withValues(
                          alpha:
                              colors.coachScrim.a *
                              AppMotion.entry.transform(_enter.value),
                        ),
                        hole: _hole,
                        gaps: _gaps(),
                      ),
                    ),
                  ),
                ),
                if (_to != null)
                  FadeTransition(
                    opacity: _contentFade,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedSwitcher(
                          duration: reduce ? Duration.zero : AppMotion.normal,
                          switchInCurve: AppMotion.entry,
                          switchOutCurve: Curves.easeIn,
                          layoutBuilder: (current, previous) => Stack(
                            fit: StackFit.expand,
                            children: [...previous, ?current],
                          ),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0, 0.012),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: _measuredIndex == widget.index
                              ? KeyedSubtree(
                                  key: ValueKey(widget.index),
                                  child: _buildBubble(
                                    context,
                                    hole: _to!,
                                    anchorX: _anchorX,
                                    spans: spans,
                                    textAlign: textAlign,
                                    alignEnd: step.align == CoachMarkAlign.end,
                                    gapY: step.pointerGap,
                                  ),
                                )
                              : null,
                        ),
                        _buildFooter(context, last: last),
                        _buildCloseButton(context),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 화살표 + 글. 아래에 자리가 모자라면 위에 놓고 화살표를 뒤집는다.
  Widget _buildBubble(
    BuildContext context, {
    required CoachHole hole,
    required double anchorX,
    required List<TextSpan> spans,
    required TextAlign textAlign,
    required bool alignEnd,
    required double gapY,
  }) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final arrow = Size(_arrowW.w, _arrowH.h);
    final gap = _arrowToText.h;

    // 글 높이를 먼저 잰다 — 글자 크기를 키운 사람은 석 줄이 될 수 있다.
    final painter = TextPainter(
      text: TextSpan(children: spans),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      textScaler: media.textScaler,
    )..layout(maxWidth: size.width - _sideMargin.w * 2);
    final need = arrow.height + gap + painter.height;
    final roomBelow =
        size.height -
        media.padding.bottom -
        _bottomReserve.h -
        hole.rect.bottom;
    final roomAbove = hole.rect.top - media.padding.top;
    final below = roomBelow >= need || roomBelow >= roomAbove;

    final reduce = _reduceMotion;
    return CustomMultiChildLayout(
      delegate: CoachBubbleLayout(
        anchorX: anchorX,
        edgeY: below
            ? hole.rect.bottom + gapY
            : hole.rect.top - gapY,
        below: below,
        alignEnd: alignEnd,
        arrowSize: arrow,
        gap: gap,
        margin: _sideMargin.w,
      ),
      children: [
        LayoutId(
          id: CoachBubbleLayout.arrowId,
          child: ExcludeSemantics(
            child: AnimatedBuilder(
              animation: _bob,
              builder: (context, child) {
                final dy = reduce
                    ? 0.0
                    : Curves.easeInOut.transform(_bob.value) * _bobDistance;
                return Transform.translate(
                  offset: Offset(0, below ? dy : -dy),
                  // 아래를 가리키는 그림이라 위에 놓을 때 180° 돌린다.
                  child: Transform.rotate(
                    angle: below ? 0 : 3.141592653589793,
                    child: child,
                  ),
                );
              },
              child: SvgPicture.asset(
                AppAssets.coachArrow,
                width: arrow.width,
                height: arrow.height,
              ),
            ),
          ),
        ),
        LayoutId(
          id: CoachBubbleLayout.textId,
          child: ExcludeSemantics(
            child: Text.rich(TextSpan(children: spans), textAlign: textAlign),
          ),
        ),
      ],
    );
  }

  /// 아래쪽 진행 점과 안내 문구.
  Widget _buildFooter(BuildContext context, {required bool last}) {
    final media = MediaQuery.of(context);
    final colors = context.colors;
    final typo = context.typo;

    return Positioned(
      left: 0,
      right: 0,
      bottom: media.padding.bottom + _footerBottom.h,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoachDots(count: widget.steps.length, index: widget.index),
            SizedBox(height: 12.h),
            // 문구가 바뀔 때 툭 바뀌지 않고 겹쳐 사라지고 나타난다.
            AnimatedSwitcher(
              duration: _reduceMotion ? Duration.zero : AppMotion.fast,
              child: Text(
                last
                    ? context.l10n.coachTapToClose
                    : context.l10n.coachTapToNext,
                key: ValueKey(last),
                style: typo.body.copyWith(
                  color: colors.coachText.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 닫기 ✕ (시안 1291:10802 — 안전영역 아래 8, 왼쪽 18).
  ///
  /// 시안은 마지막 단계에만 그렸다. 첫 단계에서 이미 보고 싶지 않은 사람이 두 번 더 눌러야
  /// 닫히는 것은 불친절해 모든 단계에 둔다. 터치 영역은 48로 넓힌다.
  Widget _buildCloseButton(BuildContext context) {
    final media = MediaQuery.of(context);
    const hit = 48.0;
    const icon = 40.0;

    return Positioned(
      left: 18.w - (hit - icon) / 2,
      top: media.padding.top + 8.h - (hit - icon) / 2,
      child: Semantics(
        button: true,
        label: context.l10n.coachCloseHint,
        onTap: _close,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            _close();
          },
          child: SizedBox(
            width: hit,
            height: hit,
            child: Center(
              child: ExcludeSemantics(
                child: SvgPicture.asset(
                  AppAssets.coachClose,
                  width: icon,
                  height: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
