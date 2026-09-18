import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 약관 전체 동의 버튼 (Figma `726:5062` · 이슈 #226).
///
/// **항목과 같은 무게로 두지 않는다.** 다섯 개 중 하나처럼 읽히면 "전부"라는 뜻이
/// 흐려진다. 그래서 항목(50)보다 높고(68), 눌리면 통째로 색이 찬다.
///
/// 누르면 **필수 항목만** 켜진다 (이슈 #189). 선택 항목은 화면 아래로 밀려 보이지
/// 않을 수 있어, 여기서 함께 켜면 본 적 없는 것에 동의하게 된다.
class ConsentAllAgreeButton extends StatelessWidget {
  const ConsentAllAgreeButton({
    super.key,
    required this.checked,
    required this.onTap,
  });

  /// Figma 실측 — 344×68 r20
  static const height = 68.0;

  /// 체크(16)와 문구 사이 (75 - 51 - 16)
  static const _checkToLabel = 8.0;

  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    // 켜지면 채우고, 꺼지면 테두리만. 둘 다 같은 포인트색이라 상태가 이어져 보인다.
    final point = colors.checkDone;

    return AppPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        height: height.h,
        decoration: BoxDecoration(
          color: checked ? point : Colors.transparent,
          borderRadius: BorderRadius.circular(space.cardRadius.r),
          border: Border.all(color: point, width: space.selectedBorderWidth),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check,
              size: space.md.w,
              color: checked ? colors.surface : point,
            ),
            SizedBox(width: _checkToLabel.w),
            Text(
              '서비스 이용약관 전체 동의',
              style: context.typo.consentAllAgree.copyWith(
                color: checked ? colors.surface : point,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
