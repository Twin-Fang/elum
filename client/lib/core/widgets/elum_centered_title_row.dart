import 'package:flutter/material.dart';

/// 가운데 제목 한 줄: [왼쪽 칸] [제목] [오른쪽 칸], 양옆 칸 폭이 같아 제목이 정가운데
/// 상단 바 · 시트 머리 공통. 칸이 비어도 폭은 남기고, 칸 안 위젯은 칸 폭에 맞춰진다
class ElumCenteredTitleRow extends StatelessWidget {
  const ElumCenteredTitleRow({
    super.key,
    required this.sideSlotWidth,
    required this.title,
    this.leading,
    this.trailing,
  });

  /// 양옆 칸 폭 (이미 화면 배율을 곱한 값)
  final double sideSlotWidth;

  /// 가운데 제목. 글자 가운데 맞춤은 제목 위젯이 한다 (textAlign: center)
  final Widget title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: sideSlotWidth, child: leading),
        Expanded(child: title),
        SizedBox(width: sideSlotWidth, child: trailing),
      ],
    );
  }
}
