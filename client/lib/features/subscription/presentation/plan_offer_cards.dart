import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../application/plan_offer_labels.dart';
import '../domain/plan_catalog.dart';

/// 기간 고르기 (#1189 시안 A): 1년 > 1개월 카드. 1년에 `N% 아껴요` 띠 + `한 달에 X원 꼴` (스토어 가격으로 계산, 같은 통화일 때만)
/// 체험 안내는 결제 버튼 아래 한 줄과 법적 안내에만 둠 (#1265: 세 번 겹쳤음)
class PlanOfferCards extends StatelessWidget {
  const PlanOfferCards({
    super.key,
    required this.catalog,
    required this.selectedPeriod,
    required this.onSelected,
  });

  final PlanCatalog catalog;
  final PlanPeriod selectedPeriod;

  /// null 이면 고를 수 없음 (결제 진행 중)
  final ValueChanged<PlanPeriod>? onSelected;

  /// 카드 사이 8 (띠가 있는 카드는 띠가 위로 튀어나온 만큼 더 띄움)
  static const _cardGap = 8.0;
  static const _ribbonRoom = 10.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final savings = catalog.yearlySavings;
    final onSelected = this.onSelected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, offer) in catalog.offersYearlyFirst.indexed) ...[
          if (index > 0) SizedBox(height: _cardGap.h),
          // 띠가 있으면 카드 위로 튀어나온 자리를 비움 (앞 줄·머리와 겹치지 않게)
          if (_ribbonOf(l10n, offer, savings) != null) SizedBox(height: _ribbonRoom.h),
          _OfferCard(
            offer: offer,
            caption: _captionOf(l10n, offer, savings),
            ribbon: _ribbonOf(l10n, offer, savings),
            isSelected: offer.period == selectedPeriod,
            onTap: onSelected == null ? null : () => onSelected(offer.period),
          ),
        ],
      ],
    );
  }

  /// 1년: 한 달 꼴(알면) · 자동 갱신, 1개월: 자동 갱신
  static String _captionOf(AppLocalizations l10n, PlanOffer offer, PlanYearlySavings? savings) =>
      switch (offer.period) {
        PlanPeriod.yearly => savings == null ? l10n.planRenewsYearly : planMonthlyEquivalentRenewsYearlyLabel(l10n, savings),
        PlanPeriod.monthly => l10n.planRenewsMonthly,
      };

  static String? _ribbonOf(AppLocalizations l10n, PlanOffer offer, PlanYearlySavings? savings) =>
      offer.period == PlanPeriod.yearly && savings != null ? l10n.planYearlySaving(savings.savedPercent) : null;
}

/// 기간 카드 하나: 라디오 · 이름 · 설명 · 가격(스토어 문자열) + 단위. 고르면 진한 테두리
class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.caption,
    required this.ribbon,
    required this.isSelected,
    required this.onTap,
  });

  final PlanOffer offer;
  final String caption;
  final String? ribbon;
  final bool isSelected;
  final VoidCallback? onTap;

  /// 안쪽 위아래 14 · 좌우 16 · 모서리 18 · 라디오 > 글 12 · 이름 > 설명 2 · 글 > 가격 8
  static const _padV = 14.0;
  static const _padH = 16.0;
  static const _cardRadius = 18.0;
  static const _radioToText = 12.0;
  static const _nameToCaption = 2.0;
  static const _textToPrice = 8.0;

  /// 라디오 22 · 테두리 안 고름 2 / 고름 7 (가운데가 흰 점으로 남음)
  static const _radioSize = 22.0;
  static const _radioRingWidth = 2.0;
  static const _radioSelectedRingWidth = 7.0;

  /// 띠: 카드 윗변에서 9 위 · 왼쪽 14 · 안쪽 가로 10 세로 4
  static const _ribbonTop = -9.0;
  static const _ribbonLeft = 14.0;
  static const _ribbonPadH = 10.0;
  static const _ribbonPadV = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final ribbon = this.ribbon;
    final card = Container(
      padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_cardRadius.r),
        border: Border.all(
          color: isSelected ? colors.proPlanOptionSelectedBorder : colors.proPlanOptionBorder,
          width: isSelected ? space.selectedBorderWidth : space.borderWidth,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: _radioSize.w,
            height: _radioSize.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surface,
              border: Border.all(
                color: isSelected ? colors.proPlanOptionSelectedBorder : colors.proPlanRadioBorder,
                width: (isSelected ? _radioSelectedRingWidth : _radioRingWidth).w,
              ),
            ),
          ),
          SizedBox(width: _radioToText.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  planPeriodName(l10n, offer.period),
                  style: context.typo.proPlanOptionName.copyWith(color: colors.textPrimary),
                ),
                SizedBox(height: _nameToCaption.h),
                Text(caption, style: context.typo.proPlanOptionCaption.copyWith(color: colors.textSecondary)),
              ],
            ),
          ),
          SizedBox(width: _textToPrice.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                offer.priceLabel,
                style: context.typo.proPlanOptionPrice.copyWith(color: colors.textPrimary),
              ),
              Text(
                planPriceUnit(l10n, offer.period),
                style: context.typo.proPlanOptionCaption.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: isSelected,
      button: true,
      child: AppPressable(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            card,
            if (ribbon != null)
              Positioned(
                top: _ribbonTop.h,
                left: _ribbonLeft.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: _ribbonPadH.w, vertical: _ribbonPadV.h),
                  decoration: BoxDecoration(
                    color: colors.proPlanSaveRibbon,
                    borderRadius: BorderRadius.circular(space.pillRadius.r),
                  ),
                  child: Text(
                    ribbon,
                    style: context.typo.proPlanRibbon.copyWith(color: colors.proPlanSaveRibbonText),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
