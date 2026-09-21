import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 약관 전체 동의 버튼 (Figma `726:5062` · 이슈 #226).
///
/// **항목과 같은 무게로 두지 않는다.** 다섯 개 중 하나처럼 읽히면 "전부"라는 뜻이
/// 흐려진다. 그래서 항목(50)보다 높고(68), 눌리면 통째로 색이 찬다.
///
/// 누르면 **선택 항목까지 전부** 켜진다 (이슈 #235). 한때 필수만 켰는데,
/// `전체 동의`라고 써 놓고 일부만 켜면 다 켜진 줄 알고 넘어간다.
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

  /// 상자 왼쪽 → 체크 (Figma x=51). **가운데 정렬이 아니다** — 가운데로 두면
  /// 글자 폭이 시안과 조금만 달라도 통째로 밀린다. 실제로 6이 밀려 있었다 (#297).
  static const _checkLeft = 51.0;

  /// 체크 상자와 그 안 획 (Figma `726:4843` Union 13.09×9.75)
  static const _checkBox = 16.0;
  static const _checkMarkW = 13.09;
  static const _checkMarkH = 9.75;

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
          children: [
            // 테두리가 안쪽 자리를 그만큼 먹는다 — 빼 주지 않으면 2가 밀린다
            SizedBox(width: (_checkLeft - space.selectedBorderWidth).w),
            // Material 체크는 획 끝이 달라 시안과 다르게 보인다 — 같은 에셋을 쓴다
            SizedBox(
              width: _checkBox.w,
              height: _checkBox.w,
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.iconCheckMark,
                  width: _checkMarkW.w,
                  height: _checkMarkH.w,
                  colorFilter: ColorFilter.mode(
                    checked ? colors.surface : point,
                    BlendMode.srcIn,
                  ),
                ),
              ),
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
