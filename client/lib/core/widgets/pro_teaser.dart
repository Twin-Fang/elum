import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/l10n_context.dart';
import '../theme/app_effects.dart';
import '../theme/theme_context_ext.dart';
import 'elum_floating_pill_button.dart';
import 'elum_label_chip.dart';

/// Pro 미리 보기: 견본 화면을 흐리게 깔고 위에 `Pro` · `예시 화면` 배지 + 한 줄 혜택 + `Pro로 보기`
///
/// 견본은 누르거나 읽히지 않음 (입력·낭독 막음). 버튼은 부르는 쪽이 요금제 화면을 열도록 [onUnlock] 으로 받음.
/// 보이는 조건(판매 중 · Free · 보호자 화면)은 부르는 쪽이 정함 (`PlanAccess.shouldShowTeaserFor`). 이룸이 화면에는 두지 않음
class ProTeaser extends StatelessWidget {
  const ProTeaser({
    super.key,
    required this.benefit,
    required this.onUnlock,
    required this.child,
  });

  /// 한 줄 혜택 ("더 할 수 있어요" 톤)
  final String benefit;

  /// `Pro로 보기` 누름 (요금제 화면)
  final VoidCallback onUnlock;

  /// 흐리게 깔 견본 화면 (실제 사용자 기록이 아닌 예시 값)
  final Widget child;

  /// 안내 판: 안쪽 20 · 배지 > 혜택 12 · 혜택 > 버튼 16 · 배지 사이 4
  static const _panelPadding = 20.0;
  static const _badgeToBenefit = 12.0;
  static const _benefitToButton = 16.0;
  static const _badgeGap = 4.0;

  /// 견본이 짧아도 안내 판이 넘치지 않는 최소 높이
  static const _minHeight = 300.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: _minHeight.h),
      // 견본·안내 판 둘 다 높이를 정함 (글자가 커져 판이 견본보다 길면 판 높이만큼 자람)
      child: Stack(
      alignment: Alignment.center,
      children: [
        // 견본: 흐림 + 입력·낭독 막음 (가짜 줄을 눌러 시트가 열리지 않게)
        ExcludeSemantics(
          child: IgnorePointer(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: AppEffects.proTeaserBlurSigma,
                sigmaY: AppEffects.proTeaserBlurSigma,
              ),
              child: child,
            ),
          ),
        ),
        Padding(
              padding: EdgeInsets.all(context.space.md.w),
              child: Container(
                padding: EdgeInsets.all(_panelPadding.w),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(context.space.cardRadius),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: _badgeGap.w,
                      runSpacing: _badgeGap.h,
                      children: [
                        ElumLabelChip(
                          label: l10n.proTeaserBadge,
                          background: colors.accentYellow,
                          foreground: colors.textPrimary,
                        ),
                        ElumLabelChip(
                          label: l10n.proTeaserSampleLabel,
                          background: colors.editChipBg,
                          foreground: colors.textPrimary,
                        ),
                      ],
                    ),
                    SizedBox(height: _badgeToBenefit.h),
                    Text(
                      benefit,
                      textAlign: TextAlign.center,
                      style: context.typo.dialogSentence.copyWith(color: colors.textPrimary),
                    ),
                    SizedBox(height: _benefitToButton.h),
                    ElumFloatingPillButton(
                      label: l10n.proTeaserUnlock,
                      leading: null,
                      onTap: onUnlock,
                    ),
                  ],
                ),
              ),
        ),
      ],
      ),
    );
  }
}
