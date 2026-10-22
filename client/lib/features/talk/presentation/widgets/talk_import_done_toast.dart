import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/layout/layout_context_ext.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_fade_slide_in.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 가져오기 완료 토스트: 흰 카드 · 민트 체크 · 문구 · `보러 가기 ›` 알약
/// 공통 토스트(검정 한 줄)와 달리 다음 걸음이 있는 완료라 따로 그린다. 화면을 옮기기 전에 잡아 둔 [messenger] 로 띄운다
void showTalkImportDoneToast(
  ScaffoldMessengerState? messenger, {
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
}) {
  if (messenger == null) {
    debugPrint('[화면] 가져오기 완료 토스트를 띄울 자리가 없어 건너뜀: $message');
    return;
  }
  // 큰 화면(태블릿)에서는 전폭으로 늘리지 않고 폭 상한으로 가운데에 둔다
  final metrics = messenger.context.layoutMetrics;
  final maxWidth = metrics.isScaleOverridden
      ? metrics.layout.sheetMaxWidth * metrics.scale
      : null;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // 판 · 그림자는 안쪽 카드가 그린다
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        width: maxWidth,
        // 누를 시간을 넉넉히 준다 (동작이 있어도 저절로 사라지게)
        persist: false,
        duration: _toastDuration,
        content: _ImportDoneCard(
          message: message,
          actionLabel: actionLabel,
          onAction: () {
            messenger.hideCurrentSnackBar();
            onAction();
          },
        ),
      ),
    );
}

// 토스트가 떠 있는 시간 (공통 토스트의 동작 있음과 같은 6초)
const _toastDuration = Duration(seconds: 6);

/// 토스트 카드 본체
class _ImportDoneCard extends StatelessWidget {
  const _ImportDoneCard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  /// 카드 반지름 · 안쪽 (왼쪽 14 · 오른쪽 10 · 위아래 12)
  static const _radius = 20.0;
  static const _padLeft = 14.0;
  static const _padRight = 10.0;
  static const _padV = 12.0;
  static const _checkToMessage = 12.0;
  static const _messageToAction = 8.0;

  /// 그림자 (0 6 24 · 검정 12%)
  static const _shadowBlur = 24.0;
  static const _shadowOffsetY = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: AppFadeSlideIn(
        offset: 12,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            _padLeft.w,
            _padV.h,
            _padRight.w,
            _padV.h,
          ),
          decoration: BoxDecoration(
            color: colors.talkToastFill,
            borderRadius: BorderRadius.circular(_radius.r),
            boxShadow: [
              BoxShadow(
                color: colors.talkToastShadow,
                blurRadius: _shadowBlur,
                offset: const Offset(0, _shadowOffsetY),
              ),
            ],
          ),
          child: Row(
            children: [
              const _PoppingCheck(),
              SizedBox(width: _checkToMessage.w),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.typo.talkToastMessage.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: _messageToAction.w),
              _ActionPill(label: actionLabel, onTap: onAction),
            ],
          ),
        ),
      ),
    );
  }
}

/// 민트 원 안 체크: 카드가 떠오른 뒤 튀어나온다
class _PoppingCheck extends StatelessWidget {
  const _PoppingCheck();

  static const _size = 32.0;
  static const _iconSize = 14.0;

  /// 카드가 거의 다 떠오른 뒤 튀어나오게 늦추는 시간
  static const _popDelayMs = 120;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.emphasis,
      builder: (context, progress, child) {
        // 앞 구간은 비우고 남은 구간에서 탄성 있게 커진다
        final delayFraction = _popDelayMs / AppMotion.emphasis.inMilliseconds;
        final local = ((progress - delayFraction) / (1 - delayFraction)).clamp(
          0.0,
          1.0,
        );
        final scale = AppMotion.springOut.transform(local);
        return Transform.scale(scale: math.max(0, scale), child: child);
      },
      child: Container(
        width: _size.w,
        height: _size.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.goalSelectedFill,
        ),
        child: SvgPicture.asset(
          AppAssets.iconCheckMark,
          width: _iconSize.w,
          height: _iconSize.w,
          excludeFromSemantics: true,
          colorFilter: ColorFilter.mode(colors.talkAccentText, BlendMode.srcIn),
        ),
      ),
    );
  }
}

/// `보러 가기 ›` 알약 (연민트 판 · 짙은 민트 글자)
class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static const _height = 34.0;
  static const _padLeft = 14.0;
  static const _padRight = 8.0;
  static const _chevronSize = 16.0;
  static const _labelToChevron = 2.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        child: Container(
          height: _height.h,
          padding: EdgeInsets.only(left: _padLeft.w, right: _padRight.w),
          decoration: BoxDecoration(
            color: colors.talkChoiceSelectedFill,
            borderRadius: BorderRadius.circular((_height / 2).r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.typo.talkToastAction.copyWith(
                  color: colors.talkAccentText,
                ),
              ),
              SizedBox(width: _labelToChevron.w),
              // 시안 꺾쇠 (설정 줄 `>` 와 같은 SVG): 원본이 아래를 보므로 반시계 90° 돌린다
              Transform.rotate(
                angle: -math.pi / 2,
                child: SvgPicture.asset(
                  AppAssets.iconAngleSmall,
                  width: _chevronSize.w,
                  height: _chevronSize.w,
                  excludeFromSemantics: true,
                  colorFilter: ColorFilter.mode(
                    colors.talkAccentText,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
