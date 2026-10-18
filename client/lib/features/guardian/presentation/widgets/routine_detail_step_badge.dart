import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';

/// 단계 번호 뱃지. **순서를 바꿔도 움직이지 않는다**.
///
/// 번호는 카드의 이름표가 아니라 몇 번째 자리인가를 뜻한다. 그래서 카드
/// 목록과 떼어 왼쪽 칸에 세워 두고, 끌기에도 들어올림에도 끼지 않는다. 카드를
/// 옮기면 왼쪽 줄은 1·2·3·4 그대로 서 있고 오른쪽 내용만 자리를 바꾼다.
class RoutineDetailStepBadge extends StatelessWidget {
  const RoutineDetailStepBadge({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // 네 색을 차례로 쓰고 다섯 번째부터 다시 처음으로 (카드는 최대 10장이다).
    final palette = [
      colors.stepBadge1,
      colors.stepBadge2,
      colors.stepBadge3,
      colors.stepBadge4,
    ];

    return Container(
      width: 40.w,
      height: 68.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette[index % palette.length],
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Text(
        '${index + 1}',
        style: context.typo.stepBadgeNumber.copyWith(color: colors.surface),
      ),
    );
  }
}
