import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../layout/layout_context_ext.dart';
import '../theme/app_motion.dart';
import '../theme/theme_context_ext.dart';

/// 바닥에서 올라오는 시트를 연다.
///
/// 시트 면(둥근 모서리·배경)은 [ElumSheetSurface] 가 그리므로 라우트 배경은 투명으로 둔다.
/// [barrierColor] 는 화면마다 달라 그대로 넘긴다 — null 이면 Material 기본 색이다.
/// [isSidePanelOnWideTablet] 이면 가로 태블릿에서 오른쪽 옆 패널로 연다 (폰·세로는 그대로 시트, #789).
Future<T?> showElumSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? barrierColor,
  bool isSidePanelOnWideTablet = false,
}) {
  if (isSidePanelOnWideTablet && shouldUseSidePanel(context)) {
    return _showElumSidePanel<T>(
      context: context,
      builder: builder,
      barrierColor: barrierColor,
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    // 키보드 때문에 시트가 화면 위까지 자랄 수 있다
    isScrollControlled: true,
    // 큰 화면에서는 전폭으로 펴지 않고 폭 상한으로 가운데에 둔다 (폰은 창 폭이 더 작아 그대로)
    constraints: BoxConstraints(maxWidth: context.layout.sheetMaxWidth.w),
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor,
    builder: builder,
  );
}

/// 옆 패널로 열 창인가: 가로 태블릿이고 높이가 넉넉할 때 (분할 보기처럼 낮으면 시트)
bool shouldUseSidePanel(BuildContext context) {
  final metrics = context.layoutMetrics;
  return metrics.isScaleOverridden &&
      metrics.isLandscape &&
      !metrics.isShortHeight;
}

/// 오른쪽에서 밀려 나오는 옆 패널 (높이 전체, 폭 토큰). 바깥을 누르면 닫힌다
Future<T?> _showElumSidePanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? barrierColor,
}) {
  final panelWidth = context.layout.sidePanelWidth.w;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor ?? context.colors.sheetScrim,
    transitionDuration: AppMotion.normal,
    pageBuilder: (dialogContext, animation, secondaryAnimation) => Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: panelWidth,
        height: double.infinity,
        child: ElumSheetPresentation(
          isSidePanel: true,
          child: Material(
            type: MaterialType.transparency,
            child: Builder(builder: builder),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.standard,
      );
      return SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

/// 시트 내용이 지금 어떤 모양으로 떠 있는지 (바닥 시트 / 옆 패널)
class ElumSheetPresentation extends InheritedWidget {
  const ElumSheetPresentation({
    super.key,
    required this.isSidePanel,
    required super.child,
  });

  final bool isSidePanel;

  /// 옆 패널 안이면 true. 바닥 시트·그 밖은 false
  static bool isSidePanelOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ElumSheetPresentation>()
          ?.isSidePanel ??
      false;

  @override
  bool updateShouldNotify(ElumSheetPresentation oldWidget) =>
      oldWidget.isSidePanel != isSidePanel;
}

/// 시트 맨 위 손잡이. 40x4 둥근 막대.
///
/// 시트 안 흐름 속에 직접 놓아야 할 때(내용과 함께 스크롤되는 경우) 쓴다.
class ElumSheetHandle extends StatelessWidget {
  const ElumSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    // 옆 패널은 끌어내려 닫지 않는다 — 자리만 두고 그리지 않는다 (배치가 흔들리지 않게)
    if (ElumSheetPresentation.isSidePanelOf(context)) {
      return SizedBox(width: 40.w, height: 4.h);
    }
    return Container(
      width: 40.w,
      height: 4.h,
      decoration: BoxDecoration(
        color: context.colors.sheetHandle,
        borderRadius: BorderRadius.circular(2.r),
      ),
    );
  }
}

/// 시트의 면. 위쪽 두 모서리만 둥근 배경이고, 손잡이를 맨 위에 겹쳐 그린다.
///
/// 손잡이는 내용 위에 얹히므로 [child] 의 배치를 바꾸지 않는다. 내용 쪽은 손잡이 자리
/// ([handleTop] + 4)를 비워 두면 된다.
class ElumSheetSurface extends StatelessWidget {
  const ElumSheetSurface({
    super.key,
    required this.child,
    this.showHandle = true,
    this.handleTop = defaultHandleTop,
    this.height,
    this.padding,
    this.clipBehavior = Clip.none,
    this.animationDuration,
    this.animationCurve = Curves.linear,
  });

  final Widget child;

  /// 맨 위 손잡이를 그릴지.
  final bool showHandle;

  /// 시트 윗변에서 손잡이 윗변까지.
  final double handleTop;

  /// 고정 높이. null 이면 내용 높이를 따른다.
  final double? height;

  final EdgeInsetsGeometry? padding;

  /// 자식을 둥근 모서리로 잘라야 하면(배경을 전체 폭에 까는 자식) antiAlias 로 둔다.
  final Clip clipBehavior;

  /// 값이 있으면 [height] 변화를 이 시간 동안 애니메이션한다 (키보드가 올라올 때 등).
  final Duration? animationDuration;
  final Curve animationCurve;

  static const radius = 20.0;
  static const defaultHandleTop = 14.0;

  @override
  Widget build(BuildContext context) {
    // 옆 패널: 왼쪽 두 모서리만 둥글고, 높이 전체를 채우며, 손잡이(끌어내리기 신호)는 없다
    final isSidePanel = ElumSheetPresentation.isSidePanelOf(context);
    final decoration = BoxDecoration(
      color: context.colors.background,
      borderRadius: isSidePanel
          ? BorderRadius.horizontal(left: Radius.circular(radius.r))
          : BorderRadius.vertical(top: Radius.circular(radius.r)),
    );
    final height = isSidePanel ? double.infinity : this.height;

    // passthrough 로 부모 제약(고정 높이 등)을 자식에 그대로 전한다
    final body = showHandle && !isSidePanel
        ? Stack(
            fit: StackFit.passthrough,
            children: [
              child,
              Positioned(
                top: handleTop.h,
                left: 0,
                right: 0,
                child: const Center(child: ElumSheetHandle()),
              ),
            ],
          )
        : child;
    // 옆 패널은 화면 위 끝까지 올라가므로 상태 표시줄만큼 내용을 내린다
    final placedBody = isSidePanel
        ? Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: body,
          )
        : body;

    final duration = animationDuration;
    if (duration != null) {
      return AnimatedContainer(
        duration: duration,
        curve: animationCurve,
        height: height,
        width: double.infinity,
        padding: padding,
        clipBehavior: clipBehavior,
        decoration: decoration,
        child: placedBody,
      );
    }
    return Container(
      height: height,
      width: double.infinity,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: decoration,
      child: placedBody,
    );
  }
}
