import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../haptics/tap_haptics.dart';
import '../theme/app_motion.dart';
import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';
import 'elum_dialog.dart';
import 'elum_row_card.dart';
import 'kept_text.dart';

/// 보호자 홈 안내 카드 (알림 꺼짐 · 크레딧 부족 · 권유): 루미 타일 + 굵은 제목 · 회색 설명 > 받는 것 알약 > 채운 민트 버튼, 오른쪽 위 닫기 x
/// 글은 줄이지 않고 어절 단위로 줄을 바꿈 (큰 글자, 긴 번역에서도 잘리지 않게). 누름은 햅틱과 함께
class HomeNoticeCard extends StatelessWidget {
  const HomeNoticeCard({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
    required this.dismissLabel,
    required this.tileAsset,
    this.highlights = const [],
  });

  /// 제목 (앞에 이모지 1개까지, 문구에 포함)
  final String title;
  final String body;
  final String actionLabel;

  /// 왼쪽 타일 그림 (종류마다 다름)
  final String tileAsset;

  /// 받는 것 알약 2~3개 (비면 자리 없음)
  final List<String> highlights;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  /// 닫기 x 낭독 글
  final String dismissLabel;

  static const _minHeight = 76.0;

  /// 카드 판 안쪽 위아래 여백 더함 (판 기본 8 + 8 = 16)
  static const _extraVerticalPadding = 8.0;

  /// 그림 타일 44 (모서리 12), 그림은 안쪽 여백 4로 전체가 보임
  static const _tileSize = 44.0;
  static const _tileRadius = 12.0;
  static const _tilePadding = 4.0;

  /// 제목 > 설명 간격
  static const _titleToBody = 4.0;

  /// 닫기 x: 보이는 크기 10, 누름 영역 36 (카드 오른쪽 위 모서리). 글은 x 자리만큼 비켜 둠
  static const _closeIconSize = 10.0;
  static const _closeTapSize = 36.0;
  static const _closeTextGap = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    return Stack(
      children: [
        ElumRowCardFrame(
          minHeight: _minHeight.h,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: _extraVerticalPadding.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 머리: 타일 > 제목 · 설명
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NoticeTile(asset: tileAsset, size: _tileSize, radius: _tileRadius, padding: _tilePadding),
                    SizedBox(width: space.sm.w),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          KeptText(
                            title,
                            style: typo.creditTitle.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: _titleToBody.h),
                          KeptText(body, style: typo.creditBody.copyWith(color: colors.textSecondary)),
                        ],
                      ),
                    ),
                    SizedBox(width: _closeTextGap.w),
                  ],
                ),
                // 받는 것 알약 (있을 때만)
                if (highlights.isNotEmpty) ...[
                  SizedBox(height: space.sm.h),
                  Wrap(
                    spacing: space.xs.w,
                    runSpacing: space.xs.h,
                    children: [for (final highlight in highlights) _HighlightPill(label: highlight)],
                  ),
                ],
                // 주 버튼 1개 (채운 민트)
                SizedBox(height: space.sm.h),
                ElumDialogButton(label: actionLabel, onTap: withTapHaptic(onAction)),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: AppPressable(
            onTap: withTapHaptic(onDismiss),
            scaleDown: AppPressable.scaleIcon,
            semanticLabel: dismissLabel,
            child: SizedBox(
              width: _closeTapSize.w,
              height: _closeTapSize.w,
              child: Center(
                child: SvgPicture.asset(
                  AppAssets.iconClose,
                  width: _closeIconSize.w,
                  height: _closeIconSize.w,
                  excludeFromSemantics: true,
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 왼쪽 그림 타일 (안내 창 그림 타일과 같은 바탕색)
class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.asset, required this.size, required this.radius, required this.padding});

  final String asset;
  final double size;
  final double radius;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius.r),
      child: Container(
        width: size.w,
        height: size.w,
        color: context.colors.proPlanTileExtra,
        padding: EdgeInsets.all(padding.w),
        child: Image.asset(asset, fit: BoxFit.contain, excludeFromSemantics: true),
      ),
    );
  }
}

/// 받는 것 알약: 민트 체크 + 짧은 글
class _HighlightPill extends StatelessWidget {
  const _HighlightPill({required this.label});

  final String label;

  static const _checkSize = 12.0;
  static const _pillRadius = 100.0;
  static const _horizontalPadding = 10.0;
  static const _verticalPadding = 4.0;
  static const _checkToLabel = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _horizontalPadding.w, vertical: _verticalPadding.h),
      decoration: BoxDecoration(
        color: colors.proPlanTileExtra,
        borderRadius: BorderRadius.circular(_pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            AppAssets.iconCheckMark,
            width: _checkSize.w,
            height: _checkSize.w,
            excludeFromSemantics: true,
            colorFilter: ColorFilter.mode(colors.checkDone, BlendMode.srcIn),
          ),
          SizedBox(width: _checkToLabel.w),
          Flexible(
            child: Text(label, style: context.typo.creditBody.copyWith(color: colors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// 홈 안내 카드 자리 전환: 나타날 때 아래에서 살짝 올라오며 또렷해지고, 사라질 때 접히며 흐려짐
/// 자식의 key 가 바뀌면 바뀐 것으로 봄. null 이면 빈 자리. 동작 줄이기면 바로 끝 모습
class HomeNoticeSwitcher extends StatelessWidget {
  const HomeNoticeSwitcher({super.key, required this.child});

  final Widget? child;

  /// 올라오는 거리 (카드 높이 대비)
  static const _enterSlideFraction = 0.08;

  @override
  Widget build(BuildContext context) {
    final isReducedMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: isReducedMotion ? Duration.zero : AppMotion.normal,
      switchInCurve: AppMotion.entry,
      switchOutCurve: AppMotion.standard,
      // 위에서부터 쌓아 접히는 동안 아래 목록이 함께 올라옴
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1,
        child: FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, _enterSlideFraction), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
      ),
      child: child ?? const SizedBox.shrink(key: ValueKey('home-notice-empty')),
    );
  }
}
