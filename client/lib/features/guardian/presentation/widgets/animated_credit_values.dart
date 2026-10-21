import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../credit/application/credit_last_shown.dart';

/// 크레딧 숫자·막대를 마지막으로 보여 준 값 > 새 값으로 움직임 (본 적 없으면 0 에서 채움)
///
/// 화면에 보일 때만 움직임: 숨은 탭에서 값이 바뀌면 기다렸다가 탭이 보일 때 줄어듦.
/// 끝까지 보여 준 값을 기억해 다음 출발점으로 씀. 기기 "동작 줄이기"면 바로 새 값
class AnimatedCreditValues extends ConsumerStatefulWidget {
  const AnimatedCreditValues({
    super.key,
    required this.available,
    required this.ratio,
    required this.builder,
  });

  final int available;
  final double ratio;

  /// 지금 보여 줄 남은 수 · 막대 비율로 그림
  final Widget Function(BuildContext context, int available, double ratio)
  builder;

  @override
  ConsumerState<AnimatedCreditValues> createState() =>
      _AnimatedCreditValuesState();
}

class _AnimatedCreditValuesState extends ConsumerState<AnimatedCreditValues>
    with SingleTickerProviderStateMixin {
  /// 움직이기 전 쉼: 카드가 자리 잡는 것과 숫자가 세는 것이 한꺼번에 일어나지 않게
  static const _startDelay = AppMotion.fast;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _startDelay + AppMotion.valueChange,
  );

  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _startDelay.inMicroseconds /
          (_startDelay + AppMotion.valueChange).inMicroseconds,
      1,
      curve: AppMotion.decelerate,
    ),
  );

  late CreditShownValue _from;
  late CreditShownValue _to;

  /// 아직 보여 주지 못한 변화가 있음 (숨은 탭이었거나 막 생김)
  bool _hasPendingChange = false;

  CreditShownValue get _target =>
      CreditShownValue(available: widget.available, ratio: widget.ratio);

  /// 지금 화면에 그려진 값 (움직이는 중이면 중간값)
  CreditShownValue get _shown {
    final t = _progress.value;
    return CreditShownValue(
      available: (_from.available + (_to.available - _from.available) * t)
          .round(),
      ratio: lerpDouble(_from.ratio, _to.ratio, t) ?? _to.ratio,
    );
  }

  @override
  void initState() {
    super.initState();
    _to = _target;
    _from = ref.read(creditLastShownProvider) ?? CreditShownValue.empty;
    _hasPendingChange = _from != _to;
    if (!_hasPendingChange) _controller.value = 1;
    // 처음 값 맞춤이 끝난 뒤에 들음 (이미 본 값을 다시 기억하지 않게)
    _controller.addStatusListener(_onStatusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 탭이 보이게 됐거나 동작 줄이기 설정이 바뀜
    _startIfVisible();
  }

  @override
  void didUpdateWidget(AnimatedCreditValues oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _target;
    if (target == _to) return;
    // 움직이던 중이면 지금 보이는 자리에서 다시 출발 (튀지 않게)
    _from = _shown;
    _to = target;
    _controller.value = 0;
    _hasPendingChange = true;
    _startIfVisible();
  }

  /// 보일 때만 출발: 숨은 탭(TickerMode 꺼짐)이면 다음 기회로 미룸
  void _startIfVisible() {
    if (!_hasPendingChange) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _hasPendingChange = false;
      _controller.value = 1;
      _rememberShown();
      return;
    }
    if (!TickerMode.of(context)) return;
    _hasPendingChange = false;
    _controller.forward(from: 0);
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) _rememberShown();
  }

  /// 그리는 중(didChangeDependencies)에도 불리므로 provider 는 그리기가 끝난 뒤 바꿈
  void _rememberShown() {
    final shown = _to;
    Future.microtask(() {
      if (!mounted) return;
      ref.read(creditLastShownProvider.notifier).remember(shown);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final shown = _shown;
        return widget.builder(context, shown.available, shown.ratio);
      },
    );
  }
}
