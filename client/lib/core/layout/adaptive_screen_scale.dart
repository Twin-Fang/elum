import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'adaptive_scope.dart';
import 'layout_metrics.dart';

/// 앱 루트의 크기 배율 연결: 창 크기 > [LayoutMetrics] > ScreenUtil 디자인 크기
///
/// 방식 M1: `ScreenUtilInit.designSize` 를 창 크기에 맞춰 바꿔 `.w` 와 `.h` 가 같은 배율 s 를 갖게 한다.
/// compact(폰)는 기본 디자인 크기를 그대로 줘 기존 `ScreenUtilInit` 과 같다.
class AdaptiveScreenScale extends StatefulWidget {
  const AdaptiveScreenScale({
    super.key,
    required this.baseDesignSize,
    required this.builder,
    this.minTextAdapt = true,
  });

  /// 시안 프레임 크기 (393x852)
  final Size baseDesignSize;
  final Widget Function(BuildContext context, Widget? child) builder;
  final bool minTextAdapt;

  @override
  State<AdaptiveScreenScale> createState() => _AdaptiveScreenScaleState();
}

class _AdaptiveScreenScaleState extends State<AdaptiveScreenScale>
    with WidgetsBindingObserver {
  Size _windowSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 첫 빌드 전에 창 크기를 잡는다 (build 가 이어서 불리므로 setState 불필요)
    _windowSize = _readWindowSize() ?? _windowSize;
  }

  @override
  void didChangeMetrics() {
    final nextSize = _readWindowSize();
    if (nextSize == null || nextSize == _windowSize) return;
    setState(() => _windowSize = nextSize);
  }

  /// 앱 창 크기 (dp). View 가 없으면 null
  Size? _readWindowSize() {
    final view = View.maybeOf(context);
    if (view == null) return null;
    return view.physicalSize / view.devicePixelRatio;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = LayoutMetrics.fromWindowSize(_windowSize);

    return ScreenUtilInit(
      designSize: metrics.designSizeFor(widget.baseDesignSize),
      minTextAdapt: widget.minTextAdapt,
      builder: (context, child) => AdaptiveScope(
        metrics: metrics,
        child: widget.builder(context, child),
      ),
    );
  }
}
