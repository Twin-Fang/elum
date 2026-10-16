import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/settings_tile.dart';

/// 크레딧 카드 맨 아래 `크레딧 사용 내역 보기 >` 줄 (Figma `1532:7501`).
///
/// 글자와 화살표는 시안 높이(24)이고, 누름 영역은 위아래 12씩 넓혀 48이다 — 위 간격(시안 16)에서
/// 12를 덜고 카드 아래 여백([AiCreditFrame.padBottomWithHistoryLink])이 나머지를 받아 눈에 보이는 자리는 시안과 같다.
class CreditHistoryLink extends StatelessWidget {
  const CreditHistoryLink({super.key});

  static const linkKey = ValueKey('credit-history-link');

  /// 누름 영역을 글자 높이(24) 위아래로 넓힌 만큼
  static const tapExtraVertical = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppPressable(
      key: linkKey,
      onTap: () => context.push(Routes.guardianCreditHistory),
      semanticLabel: context.l10n.creditHistoryLink,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: tapExtraVertical.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.creditHistoryLink,
                style: context.typo.settingsTileLabel.copyWith(
                  color: colors.settingsCardLabel,
                ),
              ),
            ),
            // 시안과 같은 SVG: 원본이 아래를 보므로 반시계 90°를 돌려 `>` 로 쓴다
            Transform.rotate(
              angle: -math.pi / 2,
              child: SvgPicture.asset(
                AppAssets.iconAngleSmall,
                width: SettingsTile.cardChevronSize.w,
                height: SettingsTile.cardChevronSize.w,
                colorFilter: ColorFilter.mode(
                  colors.settingsChevron,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
