import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/text/keep_words.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_count_up.dart';
import '../../../core/widgets/app_pop_in.dart';
import '../../../core/widgets/app_reveal.dart';
import '../../../core/widgets/pro_badge.dart';
import '../../../core/widgets/pro_member_card.dart';
import '../../../core/widgets/twinkle_star_field.dart';
import '../application/plan_status_providers.dart';
import '../application/pro_member_benefit_labels.dart';
import '../domain/plan_status.dart';

/// 내 요금제 시트 머리 (#1516): 금빛 회원 카드 위 루미 > 요금제 칩 > 큰 글 > 혜택 알약 (가운데 정렬)
///
/// 움직임 4개: 루미 톡 튀어나옴 · 빛 띠 한 번 · 남은 날 세기 · 알약 차례로 (동작 줄이기면 끝 모습)
/// 큰 글은 [planSheetHeadline] 한 곳이 정함. 혜택 권한이 다 꺼졌으면 알약 줄 없음
class MyPlanSheetHero extends ConsumerWidget {
  const MyPlanSheetHero({super.key, required this.status});

  final PlanStatus status;

  /// 카드 안쪽 여백 · 루미 > 칩 10 · 칩 > 큰 글 8
  static const _padding = 20.0;
  static const _lumiToChip = 10.0;
  static const _chipToHeadline = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final headline = planSheetHeadline(l10n, status, DateTime.now());
    final pillLabels = watchProMemberBenefitLabels(context, ref);
    return Semantics(
      // 칩 · 큰 글 · 알약을 한 번에 읽음
      label: [l10n.planSettingsLabel, planStatusShortLabel(l10n, status), headline.text, ...pillLabels].join(', '),
      excludeSemantics: true,
      child: ProMemberCardSurface(
        hasShineSweep: true,
        child: Padding(
          padding: EdgeInsets.all(_padding.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TwinklingLumi(),
              SizedBox(height: _lumiToChip.h),
              Center(child: PlanTierChip(tier: planTierOf(status))),
              SizedBox(height: _chipToHeadline.h),
              _Headline(text: headline.text, countedDays: headline.countedDays),
              if (pillLabels.isNotEmpty) ...[
                SizedBox(height: context.space.md.h),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: ProMemberBenefitPill.gap.w,
                  runSpacing: ProMemberBenefitPill.gap.h,
                  children: [
                    for (final (index, label) in pillLabels.indexed)
                      AppReveal(
                        index: index,
                        delay: AppMotion.normal,
                        child: ProMemberBenefitPill(label: label),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 둥근 빛 위 손 흔드는 루미 (톡 튀어나옴) + 둘레에서 천천히 반짝이는 네 갈래 빛
class _TwinklingLumi extends StatelessWidget {
  const _TwinklingLumi();

  /// 둥근 빛 지름 · 그 안 그림
  static const _haloSize = 92.0;
  static const _pictureSize = 74.0;

  /// 반짝이 개수 · 자리 고정 값 (크기는 부품 기본값)
  static const _sparkleCount = 9;
  static const _sparkleSeed = 16;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: _haloSize.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: TwinkleStarField(
              color: colors.surface,
              starCount: _sparkleCount,
              seed: _sparkleSeed,
              isFourPointed: true,
            ),
          ),
          AppPopIn(
            child: Container(
              width: _haloSize.w,
              height: _haloSize.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.proPlanMyCardHalo, shape: BoxShape.circle),
              child: Image.asset(AppAssets.myPlanProLumi, width: _pictureSize.w, height: _pictureSize.w),
            ),
          ),
        ],
      ),
    );
  }
}

/// 큰 글 한 줄: [countedDays] 가 글 안에 있으면 그 숫자만 크게, 0 에서 세어 올라감 (내 크레딧 `N개 남았어요` 와 같은 글자 짝)
class _Headline extends StatelessWidget {
  const _Headline({required this.text, required this.countedDays});

  final String text;
  final int? countedDays;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final countedDays = this.countedDays;
    final numberStart = countedDays == null ? -1 : text.indexOf('$countedDays');
    if (countedDays == null || numberStart < 0) {
      return Text(
        keepWords(text, locale: context.appLocale),
        textAlign: TextAlign.center,
        style: context.typo.proPlanTeaserTitle.copyWith(color: colors.textPrimary),
      );
    }
    final wordStyle = context.typo.creditTitle.copyWith(color: colors.textPrimary);
    final before = text.substring(0, numberStart);
    final after = text.substring(numberStart + '$countedDays'.length);
    // 긴 번역 · 큰 글자면 줄 전체를 폭에 맞춰 줄임 (숫자와 뒷말이 다른 줄로 갈라지지 않게)
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (before.isNotEmpty) Text(before, style: wordStyle),
          AppCountUp(
            from: 0,
            to: countedDays,
            format: (value) => '$value',
            style: context.typo.creditNumber.copyWith(color: colors.textPrimary),
            delay: AppMotion.normal,
          ),
          if (after.isNotEmpty) Text(after, style: wordStyle),
        ],
      ),
    );
  }
}
