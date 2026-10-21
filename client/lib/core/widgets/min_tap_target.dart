import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 작은 글자·아이콘의 누르기 영역을 최소 44로 넓힌다 (보이는 크기는 그대로, 가운데 정렬)
/// AppPressable 안쪽에 넣어 눌리는 면적만 키운다
class MinTapTarget extends StatelessWidget {
  const MinTapTarget({super.key, required this.child});

  final Widget child;

  /// 접근성 최소 누르기 크기 (줄 높이를 이 값에 맞추는 곳이 읽음)
  static const minimumSize = 44.0;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      minWidth: minimumSize.w,
      minHeight: minimumSize.w,
    ),
    child: Center(widthFactor: 1, heightFactor: 1, child: child),
  );
}
