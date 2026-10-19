import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 정리 상태의 ⊖ (회색 원 + 흰 −): 일과관리 격자와 묶음 열기가 같은 모양을 쓴다 (시안)
class ArrangeRemoveBadge extends StatelessWidget {
  const ArrangeRemoveBadge({
    super.key,
    required this.onTap,
    required this.semanticLabel,
  });

  /// null 이면 눌러도 아무 일도 없다 (저장 중)
  final VoidCallback? onTap;
  final String semanticLabel;

  /// 원 한 변 · − 아이콘 한 변
  static const size = 22.0;
  static const _iconSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleIcon,
      semanticLabel: semanticLabel,
      child: Container(
        width: size.w,
        height: size.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.textSecondary,
        ),
        child: Icon(
          Icons.remove_rounded,
          size: _iconSize.w,
          color: colors.surface,
        ),
      ),
    );
  }
}
