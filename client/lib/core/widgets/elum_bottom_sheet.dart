import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';

/// 바닥에서 올라오는 시트를 연다.
///
/// 시트 면(둥근 모서리·배경)은 [ElumSheetSurface] 가 그리므로 라우트 배경은 투명으로 둔다.
/// [barrierColor] 는 화면마다 달라 그대로 넘긴다 — null 이면 Material 기본 색이다.
Future<T?> showElumSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? barrierColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // 키보드 때문에 시트가 화면 위까지 자랄 수 있다
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: barrierColor,
    builder: builder,
  );
}

/// 시트 맨 위 손잡이. 40x4 둥근 막대.
///
/// 시트 안 흐름 속에 직접 놓아야 할 때(내용과 함께 스크롤되는 경우) 쓴다.
class ElumSheetHandle extends StatelessWidget {
  const ElumSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
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
    final decoration = BoxDecoration(
      color: context.colors.background,
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius.r)),
    );

    // passthrough 로 부모 제약(고정 높이 등)을 자식에 그대로 전한다
    final body = showHandle
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
        child: body,
      );
    }
    return Container(
      height: height,
      width: double.infinity,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: decoration,
      child: body,
    );
  }
}
