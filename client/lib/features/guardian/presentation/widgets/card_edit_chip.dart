import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/pro_badge.dart';

/// 칩 모양: 알약 (시안 모서리 100)
const cardEditChipPillRadius = 100.0;

/// 칩 앞 아이콘 (`fi-br` 16, 남색)
class CardEditChipIcon extends StatelessWidget {
  const CardEditChipIcon({super.key, required this.asset});

  final String asset;

  static const _size = 16.0;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: _size.w,
      height: _size.w,
      excludeFromSemantics: true,
      colorFilter: ColorFilter.mode(
        context.colors.textPrimary,
        BlendMode.srcIn,
      ),
    );
  }
}

/// 그림 아래 칩 (`사진 바꾸기` · `다시 그리기`) — 보이는 알약은 작아도 누름 영역은 48 이상이다.
/// Free 권유 칩은 글자 뒤 Pro 배지, 낭독은 [semanticLabel] (`Pro로 다시 그리기`)
class CardEditChip extends StatelessWidget {
  const CardEditChip({
    super.key,
    required this.asset,
    required this.label,
    required this.onTap,
    this.shouldShowProBadge = false,
    this.semanticLabel,
  });

  final String asset;
  final String label;
  final VoidCallback? onTap;
  final bool shouldShowProBadge;

  /// null 이면 [label] 을 읽음
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      semanticLabel: semanticLabel ?? label,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 48.h < 48 ? 48 : 48.h),
        child: Align(
          widthFactor: 1,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: colors.editChipBg,
              borderRadius: BorderRadius.circular(cardEditChipPillRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CardEditChipIcon(asset: asset),
                SizedBox(width: 6.w),
                LabelWithProBadge(
                  label: Text(
                    label,
                    style: context.typo.editChipLabel.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  shouldShowProBadge: shouldShowProBadge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
