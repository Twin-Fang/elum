import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';

/// 이름 옆 작은 칩 (나 · 보호자 · 선생님): 함께하는 사람 줄, 내 정보 닉네임 카드
///
/// 테두리는 있을 때만. 패딩 12·6, 모서리 8 (시안 1027:4617 · 1736:8780)
class ElumLabelChip extends StatelessWidget {
  const ElumLabelChip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? border;

  static const _padH = 12.0;
  static const _padV = 6.0;
  static const _radius = 8.0;
  static const _borderWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    // 시안은 테두리가 칩 크기 안쪽이라 테두리 두께만큼 여백을 덜어 같은 크기로 맞춤
    final border = this.border;
    final inset = border == null ? 0.0 : _borderWidth;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (_padH - inset).w,
        vertical: (_padV - inset).h,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_radius.r),
        border: border == null ? null : Border.all(color: border, width: _borderWidth),
      ),
      child: Text(label, maxLines: 1, style: context.typo.peopleChipLabel.copyWith(color: foreground)),
    );
  }
}
