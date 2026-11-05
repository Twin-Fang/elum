import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_check_circle.dart';
import '../../../core/widgets/elum_text_link.dart';
import '../../../core/widgets/settings_group.dart';
import '../application/plan_benefits.dart';
import '../domain/plan_benefit.dart';
import '../domain/plan_catalog.dart';

/// 혜택 묶음: 흰 판 안에 혜택 줄 (앱에 있는 Pro 차이만) + 아래 "끝나도 그대로" 안내
class PlanBenefitsGroup extends StatelessWidget {
  const PlanBenefitsGroup({super.key, this.highlight});

  /// 맨 위로 올릴 혜택 (요금제 화면을 연 기능)
  final PlanBenefit? highlight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsGroup(
      header: l10n.planBenefitsSection,
      footer: l10n.planKeepContentNotice,
      children: [
        for (final benefit in proPlanBenefits(highlight: highlight))
          _PlanTextRow(
            title: switch (benefit) {
              PlanBenefit.aiImageStyles => l10n.planBenefitAiImageStyles,
              PlanBenefit.adsRemoved => l10n.planBenefitAdsRemoved,
              PlanBenefit.weeklyReport => l10n.planBenefitWeeklyReport,
              PlanBenefit.routineSchedule => l10n.planBenefitRoutineSchedule,
              PlanBenefit.routineMemory => l10n.planBenefitRoutineMemory,
              PlanBenefit.expertRoutines => l10n.planBenefitExpertRoutines,
              PlanBenefit.guardianVoice => l10n.planBenefitGuardianVoice,
              PlanBenefit.routineTranslate => l10n.planBenefitRoutineTranslate,
              PlanBenefit.freeImageRegenerate => l10n.planBenefitFreeImageRegenerate,
              PlanBenefit.moreWeeklyCredits => l10n.planBenefitMoreWeeklyCredits,
              PlanBenefit.cardExportWithoutWatermark =>
                l10n.planBenefitCardExportWithoutWatermark,
              PlanBenefit.cardExportAllThemes => l10n.planBenefitCardExportAllThemes,
            },
          ),
      ],
    );
  }
}

/// 기간 고르기 묶음: 기간 이름 + 기간당 가격(스토어 문자열) + 고른 표시
class PlanOffersGroup extends StatelessWidget {
  const PlanOffersGroup({
    super.key,
    required this.catalog,
    required this.selectedPeriod,
    required this.onSelected,
  });

  final PlanCatalog catalog;
  final PlanPeriod selectedPeriod;

  /// null 이면 고를 수 없음 (결제 진행 중)
  final ValueChanged<PlanPeriod>? onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onSelected = this.onSelected;
    return SettingsGroup(
      header: l10n.planOffersSection,
      children: [
        for (final offer in catalog.offers)
          Semantics(
            inMutuallyExclusiveGroup: true,
            checked: offer.period == selectedPeriod,
            child: AppPressable(
              onTap: onSelected == null ? null : () => onSelected(offer.period),
              child: _PlanTextRow(
                title: planPeriodName(context, offer.period),
                caption: planPriceLabel(context, offer),
                trailing: ElumCheckCircle(isChecked: offer.period == selectedPeriod),
              ),
            ),
          ),
      ],
    );
  }
}

/// 기간 이름 (`1개월` · `1년`)
String planPeriodName(BuildContext context, PlanPeriod period) => switch (period) {
  PlanPeriod.monthly => context.l10n.planPeriodMonthly,
  PlanPeriod.yearly => context.l10n.planPeriodYearly,
};

/// 기간당 가격 (`₩9,900 / 1개월마다 자동 갱신`)
String planPriceLabel(BuildContext context, PlanOffer offer) => switch (offer.period) {
  PlanPeriod.monthly => context.l10n.planPricePerMonth(offer.priceLabel),
  PlanPeriod.yearly => context.l10n.planPricePerYear(offer.priceLabel),
};

/// 애플 필수 안내: 자동 갱신·청구 · 해지 방법 (스토어별 문장)
class PlanLegalNotice extends StatelessWidget {
  const PlanLegalNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final style = context.typo.caption.copyWith(color: context.colors.textSecondary);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.space.xs.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isAndroid ? l10n.planLegalBillingPlayStore : l10n.planLegalBillingAppStore,
            style: style,
          ),
          SizedBox(height: context.space.xs.h),
          Text(
            isAndroid ? l10n.planLegalCancelPlayStore : l10n.planLegalCancelAppStore,
            style: style,
          ),
        ],
      ),
    );
  }
}

/// 글자 버튼 줄: 이용약관 · 개인정보처리방침 · 구매 복원 (가격을 못 불러와도 늘 보임)
class PlanLinksRow extends StatelessWidget {
  const PlanLinksRow({
    super.key,
    required this.onTermsTap,
    required this.onPrivacyTap,
    required this.onRestoreTap,
  });

  final VoidCallback? onTermsTap;
  final VoidCallback? onPrivacyTap;
  final VoidCallback? onRestoreTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: context.space.xs.w,
      children: [
        ElumTextLink(label: l10n.planTermsOfUse, onTap: onTermsTap),
        ElumTextLink(label: l10n.planPrivacyPolicy, onTap: onPrivacyTap),
        ElumTextLink(label: l10n.planRestore, onTap: onRestoreTap),
      ],
    );
  }
}

/// 흰 판 안 한 줄: 제목 (+ 회색 설명) (+ 오른쪽 표시)
class _PlanTextRow extends StatelessWidget {
  const _PlanTextRow({required this.title, this.caption, this.trailing});

  final String title;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final caption = this.caption;
    final trailing = this.trailing;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.space.md.w,
        vertical: context.space.sm.h,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.typo.settingsTileLabel.copyWith(
                    color: colors.settingsCardLabel,
                  ),
                ),
                if (caption != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    caption,
                    style: context.typo.caption.copyWith(color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: context.space.sm.w),
            trailing,
          ],
        ],
      ),
    );
  }
}
