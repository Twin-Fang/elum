import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../haptics/tap_haptics.dart';
import '../l10n/l10n_context.dart';
import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';

/// PRO 배지 단일 부품: 둥근 금빛 그라데이션 알약 + 반짝 표시 + `PRO` (#1170 · #1189)
///
/// Free 에게 보이는 Pro 입구(미리 보기 판 · 그림 방식 · 인쇄 디자인 칩 · 일과관리 입구 · 설정 줄 · 일과 메뉴 줄 · 반복 줄 · 카드 그림 칩 · 요금제 화면)와
/// 내 크레딧 머리(Pro 회원의 요금제 태그)는 모두 이것만 씀
/// 금빛 토큰(`proPlanBadge*`)·문구(`planProBadge`)는 이 파일 밖에서 쓰지 않음 (tool/design_rules.yaml `restricted_tokens`)
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  /// 안쪽 여백 가로 8 · 세로 4, 반짝 > 글자 4
  static const _padH = 8.0;
  static const _padV = 4.0;
  static const _sparkToLabel = 4.0;

  /// 반짝 표시 높이 (글자 12 보다 조금 작게)
  static const _sparkHeight = 10.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = context.l10n.planProBadge;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [colors.proPlanBadgeStart, colors.proPlanBadgeEnd]),
          borderRadius: BorderRadius.circular(context.space.pillRadius.r),
          border: Border.all(color: colors.proPlanBadgeOutline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              AppAssets.iconSparkles,
              height: _sparkHeight.w,
              colorFilter: ColorFilter.mode(colors.proPlanBadgeText, BlendMode.srcIn),
            ),
            SizedBox(width: _sparkToLabel.w),
            Text(
              label,
              maxLines: 1,
              style: context.typo.proPlanBadgeLabel.copyWith(color: colors.proPlanBadgeText),
            ),
          ],
        ),
      ),
    );
  }
}

/// 글자 뒤 [ProBadge] 한 줄: 글자가 길면 글자만 줄고 배지는 남음. [shouldShowProBadge] 가 false 면 글자만
///
/// 설정 줄 · 빠른 메뉴 줄 · 일과 상세 반복 줄 · 카드 그림 칩이 같은 간격으로 씀
class LabelWithProBadge extends StatelessWidget {
  const LabelWithProBadge({
    super.key,
    required this.label,
    required this.shouldShowProBadge,
  });

  /// 글자 위젯 (줄 수·말줄임·색은 부르는 쪽이 정함)
  final Widget label;
  final bool shouldShowProBadge;

  /// 글자 > 배지 간격
  static const _labelToBadge = 6.0;

  @override
  Widget build(BuildContext context) {
    if (!shouldShowProBadge) return label;
    // 글자 폭만큼만 차지 (칩처럼 폭이 정해지지 않은 자리에서도 늘어나지 않게)
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: label),
        SizedBox(width: _labelToBadge.w),
        const ProBadge(),
      ],
    );
  }
}

/// 흐름 안 Pro 표시: [ProBadge] + 회색 `자세히 보기` (누르면 부르는 쪽이 Pro 기능 설명 시트, 햅틱 포함)
///
/// 하던 일(카드 검토 등) 안에서 요금제 화면으로 바로 넘기지 않는 작은 입구. 누름 영역은 최소 높이 36
class ProFeatureMark extends StatelessWidget {
  const ProFeatureMark({super.key, required this.onTap});

  final VoidCallback onTap;

  /// 배지 > 글자 간격 · 최소 누름 높이
  static const _badgeToLabel = 6.0;
  static const _minTapHeight = 36.0;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.proFeatureMarkLabel;
    return AppPressable(
      onTap: withTapHaptic(onTap),
      semanticLabel: '${context.l10n.planProBadge} $label',
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: _minTapHeight.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ProBadge(),
            SizedBox(width: _badgeToLabel.w),
            Text(label, style: context.typo.creditCaption.copyWith(color: context.colors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// 지금 요금제 표시 3가지 (내 요금제 줄 값)
enum PlanTier { free, pro, proGift }

/// 내 요금제 칩: Free 는 회색 알약 `Free`, Pro 는 [ProBadge], 선물받은 Pro 는 배지 + `선물`
///
/// 글자 `Free`·`Pro` 대신 모양으로 차이를 보여 줌 (#1189)
class PlanTierChip extends StatelessWidget {
  const PlanTierChip({super.key, required this.tier});

  final PlanTier tier;

  static const _padH = 8.0;
  static const _padV = 4.0;
  static const _badgeToGift = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return switch (tier) {
      PlanTier.free => Container(
        padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
        decoration: BoxDecoration(
          color: colors.proPlanFreeChipFill,
          borderRadius: BorderRadius.circular(context.space.pillRadius.r),
        ),
        child: Text(
          l10n.planStatusFree,
          maxLines: 1,
          style: context.typo.proPlanBadgeLabel.copyWith(color: colors.proPlanFreeChipText),
        ),
      ),
      PlanTier.pro => const ProBadge(),
      PlanTier.proGift => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProBadge(),
          SizedBox(width: _badgeToGift.w),
          Text(
            l10n.planTierGift,
            style: context.typo.settingsTileLabel.copyWith(color: colors.settingsCardValue),
          ),
        ],
      ),
    };
  }
}
