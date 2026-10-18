import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import 'routine_input_screen.dart';

/// 입력창 안 전송 버튼 (Figma 32×32 원)
class RoutineSendButton extends StatelessWidget {
  const RoutineSendButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      key: RoutineInputScreen.sendButtonKey,
      onTap: onTap,
      scaleDown: AppPressable.scaleIcon,
      // 입력창 안 화살표뿐이라 무엇을 하는 버튼인지 이름으로 알린다
      semanticLabel: context.l10n.routineInputSend,
      child: Container(
        // 원형 버튼이라 가로세로 모두 .w
        width: 32.w,
        height: 32.w,
        // **흰 원에 짙은 꺾쇠다** (Figma `262:4106`). 검은 원에 흰 위쪽 화살표로
        // 그리고 있었는데 색이 반대였고 모양도 달랐다.
        decoration: BoxDecoration(
          color: context.colors.surface,
          shape: BoxShape.circle,
        ),
        // 아래를 보는 원본을 반시계 90° 돌려 `>`로 만든다 — 약관 줄과 같은 에셋.
        child: Center(
          child: Transform.rotate(
            angle: -math.pi / 2,
            child: SvgPicture.asset(
              AppAssets.iconAngleSmall,
              width: 24.w,
              height: 24.w,
              colorFilter: ColorFilter.mode(
                context.colors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
