import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../haptics/tap_haptics.dart';
import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';
import 'kept_text.dart';

/// 작은 안내 카드 그림 자리 2가지: 왼쪽 (목록·홈 안내) · 위 (빈 상태·소개)
enum ElumInfoCardLayout { leading, top }

/// 작은 안내 카드: 3D 그림 + 굵은 제목 + 회색 한 줄 + (선택) 행동 알약 · 닫기 x
/// 흰 판 · 모서리 20 · 옅은 그림자. [onTap] 이 있으면 카드 전체가 눌림 (햅틱 포함)
class ElumInfoCard extends StatelessWidget {
  const ElumInfoCard({
    super.key,
    required this.illustrationAsset,
    required this.title,
    required this.body,
    this.layout = ElumInfoCardLayout.leading,
    this.actionLabel,
    this.onAction,
    this.onTap,
    this.onClose,
    this.closeLabel,
  }) : assert(onClose == null || closeLabel != null, 'closeLabel 은 닫기 x 낭독 글이라 onClose 와 함께 준다'); // l10n-ignore: assert 메시지

  /// 3D 그림 PNG (AppAssets.featureIcon* · emptyState* · celebration*)
  final String illustrationAsset;
  final String title;

  /// 회색 한 줄 (길면 어절 단위로 줄바꿈, 자르지 않음)
  final String body;
  final ElumInfoCardLayout layout;

  /// 행동 알약 글 (onAction 과 함께 있을 때만 보임)
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 카드 전체 누름 (null 이면 눌리지 않는 카드)
  final VoidCallback? onTap;

  /// 닫기 x (null 이면 x 없음) · 낭독 글
  final VoidCallback? onClose;
  final String? closeLabel;

  /// 그림 크기: 왼쪽 56 · 위 96
  static const _leadingArtSize = 56.0;
  static const _topArtSize = 96.0;

  /// 판 안쪽 여백
  static const _padding = 16.0;

  /// 제목 > 한 줄 간격
  static const _titleToBody = 4.0;

  /// 그림자: 아래로 2, 번짐 12 (판 경계만 살짝 띄움)
  static const _shadowOffsetY = 2.0;
  static const _shadowBlur = 12.0;

  /// 닫기 x: 보이는 크기 10, 누름 영역 36. 글은 x 자리만큼 비켜 둠
  static const _closeIconSize = 10.0;
  static const _closeTapSize = 36.0;
  static const _closeTextGap = 20.0;

  bool get _hasAction => actionLabel != null && onAction != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final card = Container(
      padding: EdgeInsets.all(_padding.w),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(color: colors.infoCardShadow, offset: Offset(0, _shadowOffsetY.h), blurRadius: _shadowBlur.r),
        ],
      ),
      child: layout == ElumInfoCardLayout.leading ? _leadingBody(context) : _topBody(context),
    );
    final pressableCard = onTap == null
        ? card
        : AppPressable(onTap: withTapHaptic(onTap), scaleDown: AppPressable.scaleCard, child: card);
    if (onClose == null) return pressableCard;
    // 닫기 x 는 카드 눌림과 분리 (x 를 눌러도 카드가 같이 줄지 않게)
    return Stack(
      children: [
        pressableCard,
        Positioned(top: 0, right: 0, child: _closeButton(context)),
      ],
    );
  }

  /// 왼쪽 그림 > 제목 · 한 줄 · 행동
  Widget _leadingBody(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _art(_leadingArtSize),
        SizedBox(width: context.space.sm.w),
        Expanded(child: _texts(context, CrossAxisAlignment.start)),
        if (onClose != null) SizedBox(width: _closeTextGap.w),
      ],
    );
  }

  /// 위 그림 > 가운데 정렬 제목 · 한 줄 · 행동
  Widget _topBody(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _art(_topArtSize),
        SizedBox(height: context.space.xs.h),
        _texts(context, CrossAxisAlignment.center),
      ],
    );
  }

  Widget _art(double size) => Image.asset(
    illustrationAsset,
    width: size.w,
    height: size.w,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );

  Widget _texts(BuildContext context, CrossAxisAlignment alignment) {
    final colors = context.colors;
    final typo = context.typo;
    final textAlign = alignment == CrossAxisAlignment.center ? TextAlign.center : TextAlign.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        Text(
          title,
          textAlign: textAlign,
          style: typo.creditTitle.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: _titleToBody.h),
        alignment == CrossAxisAlignment.center
            ? Text(body, textAlign: textAlign, style: typo.creditBody.copyWith(color: colors.textSecondary))
            : KeptText(body, style: typo.creditBody.copyWith(color: colors.textSecondary)),
        if (_hasAction) ...[
          SizedBox(height: context.space.xs.h),
          _ActionPill(label: actionLabel!, onTap: withTapHaptic(onAction)!),
        ],
      ],
    );
  }

  Widget _closeButton(BuildContext context) {
    return AppPressable(
      onTap: withTapHaptic(onClose),
      scaleDown: AppPressable.scaleIcon,
      semanticLabel: closeLabel,
      child: SizedBox(
        width: _closeTapSize.w,
        height: _closeTapSize.w,
        child: Center(
          child: SvgPicture.asset(
            AppAssets.iconClose,
            width: _closeIconSize.w,
            height: _closeIconSize.w,
            excludeFromSemantics: true,
            colorFilter: ColorFilter.mode(context.colors.textSecondary, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}

/// 행동 알약: 연한 민트 바탕 + 진한 민트 굵은 글
class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  static const _horizontalPadding = 14.0;
  static const _verticalPadding = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: _horizontalPadding.w, vertical: _verticalPadding.h),
        decoration: BoxDecoration(
          color: colors.infoHighlightMintFill,
          borderRadius: BorderRadius.circular(context.space.pillRadius),
        ),
        child: Text(
          label,
          style: context.typo.creditBody.copyWith(color: colors.infoHighlightMintAccent, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
