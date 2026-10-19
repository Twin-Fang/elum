import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'layout_context_ext.dart';
import 'layout_metrics.dart';
import 'screen_layout_kind.dart';

/// 라우트 한 화면을 [ScreenLayoutKind] 에 맞게 담는 프레임
///
/// compact(폰)는 자식을 그대로 둔다. medium·expanded 에서만 열을 만든다.
/// 자식에 GlobalKey 를 걸어, 회전·분할로 감싸는 구조가 바뀌어도 입력 글·스크롤 상태를 잇는다.
class AdaptivePageFrame extends StatefulWidget {
  const AdaptivePageFrame({
    super.key,
    required this.kind,
    required this.child,
    this.isBackgroundPainted = true,
  });

  final ScreenLayoutKind kind;
  final Widget child;

  /// 열 바깥을 배경색으로 칠할지. 흐름 배경(오로라)이 이미 깔린 화면은 false
  final bool isBackgroundPainted;

  @override
  State<AdaptivePageFrame> createState() => _AdaptivePageFrameState();
}

class _AdaptivePageFrameState extends State<AdaptivePageFrame> {
  /// 감싸는 구조가 바뀌어도 자식 Element 를 옮겨 상태를 유지하는 키
  final _childKey = GlobalKey();

  /// 시안 높이가 창보다 이만큼(px) 넘어야 스크롤로 접는다 (부동소수점 오차 흡수)
  static const _scrollToleranceHeight = 1.0;

  @override
  Widget build(BuildContext context) {
    final metrics = context.layoutMetrics;
    final child = KeyedSubtree(key: _childKey, child: widget.child);

    final isFramed =
        metrics.isScaleOverridden && widget.kind != ScreenLayoutKind.adaptive;
    if (!isFramed) return child;

    final media = MediaQuery.of(context);
    final column = switch (widget.kind) {
      ScreenLayoutKind.phoneColumn => _buildPhoneColumn(media, metrics, child),
      ScreenLayoutKind.contentColumn => _buildContentColumn(
        media,
        metrics,
        child,
      ),
      ScreenLayoutKind.adaptive => child,
    };

    if (!widget.isBackgroundPainted) return column;
    // AppTheme 이 scaffoldBackgroundColor 를 colors.background 로 둔다 (테마 확장 없이도 동작)
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: column,
    );
  }

  /// 폰 비율 열: 폭 393 x s, 높이 max(창, 852 x s). 높이가 모자라면 열 전체가 세로 스크롤
  Widget _buildPhoneColumn(
    MediaQueryData media,
    LayoutMetrics metrics,
    Widget child,
  ) {
    final columnWidth = metrics.phoneColumnWidthPixels;
    final requiredHeight = metrics.layout.designHeight * metrics.scale;
    final isScrollNeeded =
        requiredHeight - media.size.height > _scrollToleranceHeight;
    final columnHeight = isScrollNeeded ? requiredHeight : media.size.height;

    final column = SizedBox(
      width: columnWidth,
      height: columnHeight,
      child: MediaQuery(
        data: _columnMediaQuery(
          media,
          Size(columnWidth, columnHeight),
          // 스크롤 중에는 키보드 높이만큼 뷰포트를 줄이므로 안쪽은 이미 반영된 것으로 본다
          isViewInsetConsumed: isScrollNeeded,
        ),
        child: child,
      ),
    );

    if (!isScrollNeeded) {
      return Align(alignment: Alignment.topCenter, child: column);
    }
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SingleChildScrollView(
        child: Align(alignment: Alignment.topCenter, child: column),
      ),
    );
  }

  /// 가운데 열: 폭 상한(560 x s)과 창 폭 중 작은 쪽, 높이는 창 전체
  Widget _buildContentColumn(
    MediaQueryData media,
    LayoutMetrics metrics,
    Widget child,
  ) {
    final columnWidth = math.min(
      metrics.layout.contentColumnMaxWidth * metrics.scale,
      media.size.width,
    );
    final columnSize = Size(columnWidth, media.size.height);

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: columnSize.width,
        height: columnSize.height,
        child: MediaQuery(
          data: _columnMediaQuery(media, columnSize, isViewInsetConsumed: false),
          child: child,
        ),
      ),
    );
  }

  /// 열 안쪽 MediaQuery: 크기는 열 크기, 좌우 안전영역은 0 (열이 이미 가장자리에서 떨어져 있다)
  MediaQueryData _columnMediaQuery(
    MediaQueryData media,
    Size columnSize, {
    required bool isViewInsetConsumed,
  }) {
    return media.copyWith(
      size: columnSize,
      padding: media.padding.copyWith(left: 0, right: 0),
      viewPadding: media.viewPadding.copyWith(left: 0, right: 0),
      viewInsets: isViewInsetConsumed
          ? media.viewInsets.copyWith(bottom: 0)
          : media.viewInsets,
    );
  }
}
