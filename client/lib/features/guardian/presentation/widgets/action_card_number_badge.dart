import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';

/// 순서 배지 (40×40, r12)
class ActionCardNumberBadge extends StatelessWidget {
  const ActionCardNumberBadge({
    super.key,
    required this.order,
    required this.color,
  });

  /// 배지 한 변. 아래 줄의 스피커 칸도 이 폭을 쓴다.
  static const size = 40.0;

  final int order;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // 정사각형 배지라 가로세로 모두 .w
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12.w),
      ),
      // Text만 Container.alignment로 두면 실제 렌더링 시 글자가 오른쪽으로
      // 치우쳐 보인다(폰트 line box가 advance width보다 넓게 잡힘) — 이슈 재현
      // 스크린샷에서 좌우 여백이 약 3배 차이 났다. textAlign.center로 텍스트
      // 캔버스 자체를 중앙 정렬해 이를 바로잡는다.
      child: Text(
        '$order',
        textAlign: TextAlign.center,
        style: context.typo.cardHeadline.copyWith(
          color: context.colors.surface,
        ),
      ),
    );
  }
}
