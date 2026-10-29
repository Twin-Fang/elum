import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 코치마크 다시 보기 `?` 버튼 (카드 검토 상단바 · 일과관리 머리)
///
/// 자리 24 안에 물음표 원 20 — 물음표 원은 테두리까지 꽉 찬 그림이라 24 로 그리면 옆 24 아이콘보다 커 보인다.
/// 누름 영역은 자리 위로 40×40 을 덮는다 (자리째 키우면 줄 높이가 바뀐다).
class CoachHelpButton extends StatelessWidget {
  const CoachHelpButton({super.key, required this.onTap});

  final VoidCallback onTap;

  /// 자리 · 그림 · 누름 영역 한 변
  static const slotSize = 24.0;
  static const glyphSize = 20.0;
  static const touchSize = 40.0;

  @override
  Widget build(BuildContext context) => AppPressable(
    onTap: onTap,
    scaleDown: AppPressable.scaleIcon,
    semanticLabel: context.l10n.coachHelpLabel,
    child: SizedBox.square(
      dimension: slotSize.w,
      child: OverflowBox(
        maxWidth: touchSize.w,
        maxHeight: touchSize.w,
        child: SizedBox.square(
          dimension: touchSize.w,
          child: Center(
            child: SvgPicture.asset(
              AppAssets.iconQuestionCircle,
              width: glyphSize.w,
              height: glyphSize.w,
              colorFilter: ColorFilter.mode(
                context.colors.topBarActionText,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
