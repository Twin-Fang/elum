import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/text/keep_words.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../member/application/plan_access.dart';
import '../application/plan_benefits.dart';
import '../domain/plan_benefit.dart';

/// 혜택 4묶음 (#1189 시안 A): 묶음마다 아이콘 타일 + 제목 + 한 줄(혜택을 ` · ` 로 이음) > 아래 "끝나도 그대로" 한 줄
///
/// 서버 Pro 권한이 실제로 주는 것만 (#1165). 빈 묶음은 빠지고, 다 비면(운영이 Pro 권한을 다 끔) 통째로 그리지 않음
class PlanBenefitCards extends ConsumerWidget {
  const PlanBenefitCards({super.key, this.highlight});

  /// 맨 위로 올릴 혜택 (요금제 화면을 연 기능)
  final PlanBenefit? highlight;

  /// 묶음 사이 10 · 묶음 > 안내 12
  static const _cardGap = 10.0;
  static const _cardsToNotice = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(planAccessProvider);
    final sections = proPlanBenefitSections(
      proPlan: access.proPlanEntitlements,
      current: access.entitlements,
      highlight: highlight,
    );
    if (sections.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, section) in sections.indexed) ...[
          if (index > 0) SizedBox(height: _cardGap.h),
          _BenefitGroupCard(section: section),
        ],
        SizedBox(height: _cardsToNotice.h),
        Text(
          keepWords(context.l10n.planKeepContentNotice, locale: context.appLocale),
          semanticsLabel: context.l10n.planKeepContentNotice,
          textAlign: TextAlign.center,
          style: context.typo.proPlanFinePrint.copyWith(color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

/// 묶음 카드 하나 (흰 판 · 모서리 20)
class _BenefitGroupCard extends StatelessWidget {
  const _BenefitGroupCard({required this.section});

  final PlanBenefitSection section;

  /// 안쪽 위아래 14 · 좌우 16 · 타일 > 글 12 · 제목 > 한 줄 4 · 타일 42 · 아이콘 24 · 타일 모서리 12
  static const _padV = 14.0;
  static const _padH = 16.0;
  static const _tileToText = 12.0;
  static const _titleToDetail = 4.0;
  static const _tileSize = 42.0;
  static const _iconSize = 24.0;
  static const _tileRadius = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final group = section.group;
    final detail = section.benefits
        .map((benefit) => planBenefitLabel(l10n, benefit))
        .join(l10n.planBenefitSeparator);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
      ),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: _tileSize.w,
              height: _tileSize.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _tileColor(colors, group),
                borderRadius: BorderRadius.circular(_tileRadius.r),
              ),
              child: SvgPicture.asset(_icon(group), width: _iconSize.w, height: _iconSize.w),
            ),
            SizedBox(width: _tileToText.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    keepWords(_title(l10n, group), locale: context.appLocale),
                    semanticsLabel: _title(l10n, group),
                    style: context.typo.proPlanBenefitTitle.copyWith(color: colors.textPrimary),
                  ),
                  SizedBox(height: _titleToDetail.h),
                  // 낱말 중간에서 꺾이지 않게 (`광고 없 / 음`)
                  Text(
                    keepWords(detail, locale: context.appLocale),
                    semanticsLabel: detail,
                    style: context.typo.proPlanBenefitDetail.copyWith(color: colors.proPlanBenefitDetail),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _title(AppLocalizations l10n, PlanBenefitGroup group) => switch (group) {
    PlanBenefitGroup.prettierCards => l10n.planBenefitGroupCards,
    PlanBenefitGroup.readyRoutines => l10n.planBenefitGroupRoutines,
    PlanBenefitGroup.weekAtAGlance => l10n.planBenefitGroupWeek,
    PlanBenefitGroup.plentyWithoutAds => l10n.planBenefitGroupExtra,
  };

  static String _icon(PlanBenefitGroup group) => switch (group) {
    PlanBenefitGroup.prettierCards => AppAssets.planBenefitIconCards,
    PlanBenefitGroup.readyRoutines => AppAssets.planBenefitIconRoutines,
    PlanBenefitGroup.weekAtAGlance => AppAssets.planBenefitIconWeek,
    PlanBenefitGroup.plentyWithoutAds => AppAssets.planBenefitIconExtra,
  };

  static Color _tileColor(AppColors colors, PlanBenefitGroup group) => switch (group) {
    PlanBenefitGroup.prettierCards => colors.proPlanTileCards,
    PlanBenefitGroup.readyRoutines => colors.proPlanTileRoutines,
    PlanBenefitGroup.weekAtAGlance => colors.proPlanTileWeek,
    PlanBenefitGroup.plentyWithoutAds => colors.proPlanTileExtra,
  };
}

/// 혜택 하나 > 짧은 이름 (묶음 한 줄에 ` · ` 로 이어 붙임)
String planBenefitLabel(AppLocalizations l10n, PlanBenefit benefit) => switch (benefit) {
  PlanBenefit.aiImageStyles => l10n.planBenefitAiImageStyles,
  PlanBenefit.adsRemoved => l10n.planBenefitAdsRemoved,
  PlanBenefit.weeklyReport => l10n.planBenefitWeeklyReport,
  PlanBenefit.routineSchedule => l10n.planBenefitRoutineSchedule,
  PlanBenefit.routineMemory => l10n.planBenefitRoutineMemory,
  PlanBenefit.expertRoutines => l10n.planBenefitExpertRoutines,
  PlanBenefit.guardianVoice => l10n.planBenefitGuardianVoice,
  PlanBenefit.routineTranslate => l10n.planBenefitRoutineTranslate,
  PlanBenefit.freeRoutineText => l10n.planBenefitFreeRoutineText,
  PlanBenefit.freeImageRegenerate => l10n.planBenefitFreeImageRegenerate,
  PlanBenefit.moreWeeklyCredits => l10n.planBenefitMoreWeeklyCredits,
  PlanBenefit.cardExportWithoutWatermark => l10n.planBenefitCardExportWithoutWatermark,
  PlanBenefit.cardExportAllThemes => l10n.planBenefitCardExportAllThemes,
  PlanBenefit.cardExportAllLayouts => l10n.planBenefitCardExportAllLayouts,
};
