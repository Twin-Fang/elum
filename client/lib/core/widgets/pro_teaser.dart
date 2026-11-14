import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/l10n_context.dart';
import '../text/keep_words.dart';
import '../theme/theme_context_ext.dart';
import 'elum_label_chip.dart';
import 'elum_secondary_button.dart';
import 'pro_badge.dart';
import 'pro_upsell_button.dart';

/// Pro 미리 보기: 또렷한 견본(아래로 사라짐, 입력·낭독 막음) + 떠 있는 카드 (PRO · 예시 화면 > 제목 > 한 줄 > 민트 버튼 > 혜택 모두 보기)
/// 보이는 조건은 부르는 쪽 (`PlanAccess.shouldShowTeaserFor`, 보호자 화면만), 요금제 화면은 [actions] 로 엶
class ProTeaser extends StatelessWidget {
  const ProTeaser({
    super.key,
    required this.title,
    required this.benefit,
    required this.actions,
    required this.child,
  });

  /// 기능별 제목 ("이렇게 쓸 수 있어요" 톤)
  final String title;

  /// 제목 아래 한 줄
  final String benefit;

  /// 버튼 문구(체험 기간) · 요금제 화면 열기
  final ProUpsellActions actions;

  /// 깔 견본 화면 (실제 사용자 기록이 아닌 예시 값)
  final Widget child;

  /// 카드: 바깥 16 · 안쪽 20 · 모서리 24 · 배지 > 제목 12 · 제목 > 한 줄 6 · 한 줄 > 버튼 16 · 버튼 > 링크 8 · 배지 사이 4
  static const _cardPadding = 20.0;
  static const _cardRadius = 24.0;
  static const _badgeToTitle = 12.0;
  static const _titleToBenefit = 6.0;
  static const _benefitToButton = 16.0;
  static const _buttonToLink = 8.0;
  static const _badgeGap = 4.0;

  /// 카드 그림자 (아래 14 · 번짐 34)
  static const _cardShadowOffsetY = 14.0;
  static const _cardShadowBlur = 34.0;

  /// 견본이 사라지기 시작 · 다 사라지는 높이 비율 (위쪽 견본은 또렷하게 읽힘)
  static const _fadeStartStop = 0.38;
  static const _fadeEndStop = 0.62;

  /// 견본이 짧아도 카드가 넘치지 않는 최소 높이
  static const _minHeight = 300.0;

  /// 견본을 보이는 최대 높이: 긴 견본(주간 리포트)에서도 카드가 첫 화면 안에 오게 아래를 자름
  static const _maxSampleHeight = 560.0;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: _minHeight.h),
      // 견본·카드 둘 다 높이를 정함 (큰 글자로 카드가 견본보다 길면 카드 높이만큼 자람)
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 견본: 또렷 + 아래로 사라짐 + 입력·낭독 막음 (가짜 줄을 눌러 시트가 열리지 않게)
          ExcludeSemantics(child: IgnorePointer(child: _FadingSample(child: child))),
          Padding(
            padding: EdgeInsets.all(context.space.md.w),
            child: _card(context),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(_cardPadding.w),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_cardRadius.r),
        boxShadow: [
          BoxShadow(
            color: colors.proPlanTeaserCardShadow,
            offset: Offset(0, _cardShadowOffsetY.h),
            blurRadius: _cardShadowBlur.r,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 또렷한 견본을 진짜 기록으로 오해하지 않게 `예시 화면` 을 함께 둠
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: _badgeGap.w,
            runSpacing: _badgeGap.h,
            children: [
              const ProBadge(),
              ElumLabelChip(
                label: l10n.proTeaserSampleLabel,
                background: colors.editChipBg,
                foreground: colors.textPrimary,
              ),
            ],
          ),
          SizedBox(height: _badgeToTitle.h),
          // 낱말 단위로 줄바꿈 (`쓸 / 수 있어요` 처럼 꺾이지 않게, #1169)
          Text(
            keepWords(title, locale: context.appLocale),
            semanticsLabel: title,
            textAlign: TextAlign.center,
            style: context.typo.proPlanTeaserTitle.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: _titleToBenefit.h),
          Text(
            keepWords(benefit, locale: context.appLocale),
            semanticsLabel: benefit,
            textAlign: TextAlign.center,
            style: context.typo.proPlanTeaserBody.copyWith(color: colors.proPlanBenefitDetail),
          ),
          SizedBox(height: _benefitToButton.h),
          ProUpsellButton(
            style: ProUpsellStyle.filled,
            freeTrialLabel: actions.freeTrialLabel,
            onTap: actions.onStart,
          ),
          SizedBox(height: _buttonToLink.h),
          ElumSecondaryButton(label: l10n.planSeeAllBenefits, onTap: actions.onSeeAllBenefits),
        ],
      ),
    );
  }
}

/// 견본 위에 배경색 막을 아래로 짙게 덮음 (위쪽은 또렷, 카드 자리부터 배경)
class _FadingSample extends StatelessWidget {
  const _FadingSample({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final background = context.colors.background;
    return Stack(
      children: [
        // 최대 높이까지만 (넘치는 아래쪽은 어차피 배경으로 사라지는 자리)
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: ProTeaser._maxSampleHeight.h),
          // 견본 높이만큼, 최대를 넘으면 그 높이에서 잘림 (스크롤은 막음)
          child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: child),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [background.withValues(alpha: 0), background.withValues(alpha: 0), background, background],
                stops: const [0, ProTeaser._fadeStartStop, ProTeaser._fadeEndStop, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
