import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/text/keep_words.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/pro_badge.dart';

/// 요금제 화면 머리 (#1189 시안 A): 민트 빛 > PRO 배지 > 제목 > 설명 > Free 카드 → Pro 카드
///
/// 같은 일과(이 닦기)를 Free(이모지) · Pro(캐릭터 그림) 로 나란히 두어 차이를 글보다 먼저 보여 줌
class PlanPaywallHero extends StatelessWidget {
  const PlanPaywallHero({super.key});

  /// 위 40 (손잡이 · ✕ 자리) · 아래 24 · 좌우 16 · 배지 > 제목 10 · 제목 > 설명 4 · 설명 > 카드 20
  static const _padTop = 40.0;
  static const _padBottom = 24.0;
  static const _badgeToTitle = 10.0;
  static const _titleToSubline = 4.0;
  static const _sublineToCompare = 20.0;

  /// 빛 가운데 (오른쪽 위) · 퍼짐 · 배경으로 다 바뀌는 지점
  static const _glowCenter = Alignment(0.4, -0.8);
  static const _glowSpread = 1.2;
  static const _glowFadeStop = 0.7;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final locale = context.appLocale;
    return Container(
      padding: EdgeInsets.fromLTRB(context.space.md.w, _padTop.h, context.space.md.w, _padBottom.h),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: _glowCenter,
          radius: _glowSpread,
          colors: [colors.proPlanHeroGlow, colors.background],
          stops: const [0, _glowFadeStop],
        ),
      ),
      child: Column(
        children: [
          const ProBadge(),
          SizedBox(height: _badgeToTitle.h),
          Semantics(
            header: true,
            child: Text(
              keepWords(l10n.planHeroHeadline, locale: locale),
              semanticsLabel: l10n.planHeroHeadline,
              textAlign: TextAlign.center,
              style: context.typo.proPlanHeadline.copyWith(color: colors.textPrimary),
            ),
          ),
          SizedBox(height: _titleToSubline.h),
          Text(
            keepWords(l10n.planHeroSubline, locale: locale),
            semanticsLabel: l10n.planHeroSubline,
            textAlign: TextAlign.center,
            style: context.typo.proPlanSubline.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: _sublineToCompare.h),
          const _PlanCompareRow(),
        ],
      ),
    );
  }
}

/// Free 카드 → Pro 카드. 큰 글자·좁은 폭이면 줄 전체를 폭에 맞춰 줄임 (잘리지 않게)
class _PlanCompareRow extends StatelessWidget {
  const _PlanCompareRow();

  static const _cardToArrow = 10.0;
  static const _arrowSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cardTitle = l10n.proTeaserSampleRoutineBrush;
    return Semantics(
      label: l10n.planHeroCompareSemantics,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CompareCard(title: cardTitle, tag: l10n.planHeroFreeTag, isPro: false),
            SizedBox(width: _cardToArrow.w),
            // 시안 `→`: 앱 화살표(아래 보는 원본)를 반시계 90° 로 돌려 씀
            Transform.rotate(
              angle: -math.pi / 2,
              child: SvgPicture.asset(
                AppAssets.iconAngleSmall,
                width: _arrowSize.w,
                height: _arrowSize.w,
                colorFilter: ColorFilter.mode(context.colors.proPlanArrow, BlendMode.srcIn),
              ),
            ),
            SizedBox(width: _cardToArrow.w),
            _CompareCard(title: cardTitle, tag: l10n.planHeroProTag, isPro: true),
          ],
        ),
      ),
    );
  }
}

/// 비교 카드 하나: 그림 자리 > 일과 이름 > 작은 설명. Pro 는 더 크고 민트 테두리·빛 + 살짝 기울임
class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.title, required this.tag, required this.isPro});

  final String title;
  final String tag;
  final bool isPro;

  /// 시안 실측: 폭 Free 118 · Pro 142, 그림 자리 높이 96 · 118, 그림 52 · 108
  static const _freeWidth = 118.0;
  static const _proWidth = 142.0;
  static const _freePictureHeight = 96.0;
  static const _proPictureHeight = 118.0;
  static const _freePictureSize = 52.0;
  static const _proPictureSize = 108.0;

  /// 안쪽 10 · 카드 모서리 20 · 그림 자리 모서리 16 · 그림 > 이름 8 · 이름 > 설명 2
  static const _cardPadding = 10.0;
  static const _cardRadius = 20.0;
  static const _pictureRadius = 16.0;
  static const _pictureToTitle = 8.0;
  static const _titleToTag = 2.0;

  /// Pro 카드: 민트 테두리 3 · 빛 번짐 30 · 기울기 2°
  static const _proRingWidth = 3.0;
  static const _proGlowBlur = 30.0;
  static const _proGlowOffsetY = 14.0;
  static const _proTiltDegrees = 2.0;
  static const _shadowBlur = 16.0;
  static const _shadowOffsetY = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final card = Container(
      width: (isPro ? _proWidth : _freeWidth).w,
      padding: EdgeInsets.all(_cardPadding.w),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_cardRadius.r),
        boxShadow: isPro
            ? [
                BoxShadow(color: colors.proPlanProCardRing, spreadRadius: _proRingWidth.w),
                BoxShadow(
                  color: colors.proPlanProCardShadow,
                  offset: Offset(0, _proGlowOffsetY.h),
                  blurRadius: _proGlowBlur.r,
                ),
              ]
            : [
                BoxShadow(
                  color: colors.proPlanCardShadow,
                  offset: Offset(0, _shadowOffsetY.h),
                  blurRadius: _shadowBlur.r,
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _picture(context),
          SizedBox(height: _pictureToTitle.h),
          // 카드 폭은 그림 크기라 고정: 큰 글자면 글자만 폭에 맞춰 줄임 (잘리지 않게)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 1,
              style: context.typo.proPlanCompareTitle.copyWith(color: colors.textPrimary),
            ),
          ),
          SizedBox(height: _titleToTag.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tag,
              maxLines: 1,
              style: context.typo.proPlanCompareTag.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
    if (!isPro) return card;
    return Transform.rotate(angle: _proTiltDegrees * math.pi / 180, child: card);
  }

  Widget _picture(BuildContext context) {
    final colors = context.colors;
    final size = (isPro ? _proPictureSize : _freePictureSize).w;
    return Container(
      height: (isPro ? _proPictureHeight : _freePictureHeight).w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isPro ? null : colors.proPlanFreePicture,
        gradient: isPro
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.proPlanProPictureStart, colors.proPlanProPictureEnd],
              )
            : null,
        borderRadius: BorderRadius.circular(_pictureRadius.r),
      ),
      child: isPro
          ? Image.asset(AppAssets.planHeroProPicture, width: size, height: size, fit: BoxFit.contain)
          : SvgPicture.asset(AppAssets.planHeroFreePicture, width: size, height: size),
    );
  }
}
