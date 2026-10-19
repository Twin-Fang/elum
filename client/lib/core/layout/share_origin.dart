import 'package:flutter/widgets.dart';

/// 공유 시트를 띄울 기준 사각형(화면 좌표): 누른 위젯의 영역
///
/// 아이패드는 공유 시트가 팝오버라 기준이 없으면 예외가 난다. 아직 그려지지 않았으면 null.
Rect? shareOriginOf(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}
