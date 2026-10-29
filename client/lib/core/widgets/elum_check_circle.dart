import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../theme/app_motion.dart';
import '../theme/theme_context_ext.dart';

/// 원형 체크 (시안 739:3747 ↔ 726:5056 약관 동의): 꺼짐 = 회색 테두리 + 회색 체크, 켜짐 = 민트 원 + 흰 체크
/// 꺼져 있어도 체크가 보인다 — 원만 비워 두면 눌러야 할 자리인지 알기 어렵다. 앱의 체크는 이 하나만 쓴다
class ElumCheckCircle extends StatelessWidget {
  const ElumCheckCircle({super.key, required this.isChecked, this.size = defaultSize});

  final bool isChecked;

  /// 원 지름 (시안 20)
  final double size;

  static const defaultSize = 20.0;

  /// 원 안 체크 비율 (시안 원 20 안 10.91×8.13, `726:4867` Union)
  static const _markWidthRatio = 10.91 / 20;
  static const _markHeightRatio = 8.13 / 20;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isChecked ? colors.checkDone : Colors.transparent,
        border: Border.all(
          // border(#EFEFEF)는 배경(#F7F2EF)과 거의 같아 원이 사라진다
          color: isChecked ? colors.checkDone : colors.consentCheckIdle,
          width: context.space.borderWidth,
        ),
      ),
      // Material 체크는 획 끝이 달라 시안과 다르게 보인다 — 같은 에셋을 쓴다
      child: Center(
        child: SvgPicture.asset(
          AppAssets.iconCheckMark,
          width: (size * _markWidthRatio).w,
          height: (size * _markHeightRatio).w,
          colorFilter: ColorFilter.mode(
            isChecked ? colors.surface : colors.consentCheckIdle,
            BlendMode.srcIn,
          ),
          // 켜짐 상태는 쓰는 쪽 Semantics(checked) 가 알린다. 빈 이름 그림 노드를 남기지 않는다
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
