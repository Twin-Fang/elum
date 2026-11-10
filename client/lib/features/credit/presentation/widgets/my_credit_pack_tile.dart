import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/credit_pack.dart';

/// 꾸러미 칸 한 개: 그림 > 개수 > (원래 값 줄 그음) > 값. 할인율은 오른쪽 위, 인기는 아래 가운데에 걸친 알약
///
/// 그림은 작은 꾸러미부터 한 장 / 두 장 겹침 / 여러 장 (칸 순서로 정함)
class MyCreditPackTile extends StatelessWidget {
  const MyCreditPackTile({
    super.key,
    required this.offer,
    required this.index,
    required this.listPriceLabel,
    required this.isSelected,
    required this.onTap,
  });

  final CreditPackOffer offer;

  /// 개수 적은 순서의 칸 번호 (그림 · 바탕색을 고름)
  final int index;

  /// 원래 값 문자열 (할인 없으면 null). 통화 모양은 부르는 쪽이 만듦
  final String? listPriceLabel;
  final bool isSelected;
  final VoidCallback? onTap;

  static const _tilePadding = 8.0;
  static const _pictureBoxSize = 64.0;
  static const _pictureSize = 48.0;
  static const _borderWidth = 2.0;
  static const _pillOverhang = 10.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final listPriceLabel = this.listPriceLabel;
    final discountPercent = offer.discountPercent;
    final isPopular = offer.pack.isPopular;
    return Semantics(
      button: true,
      selected: isSelected,
      label: l10n.myCreditPackTileLabel(offer.pack.credits, offer.price.label),
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: isPopular ? colors.creditPackTilePeach : colors.surface,
                borderRadius: BorderRadius.circular(space.cardRadius.r),
                border: Border.all(
                  color: isSelected ? colors.creditPackPopularBorder : Colors.transparent,
                  width: _borderWidth.w,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(_tilePadding.w, _tilePadding.h, _tilePadding.w, space.sm.h),
                child: Column(
                  children: [
                    _PictureBox(index: index, fill: _pictureFill(colors)),
                    SizedBox(height: space.xs.h),
                    Text('${offer.pack.credits}', style: context.typo.subtitle.copyWith(color: colors.textPrimary)),
                    SizedBox(height: space.xs.h / 2),
                    // 원래 값 자리는 할인 없는 칸도 비워 둠 (칸마다 값 높이가 같게)
                    Text(
                      listPriceLabel ?? '-',
                      style: context.typo.creditCaption.copyWith(
                        color: colors.textSecondary,
                        decoration: listPriceLabel == null ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    SizedBox(height: space.xs.h / 2),
                    Text(
                      offer.price.label,
                      textAlign: TextAlign.center,
                      style: context.typo.creditTitle.copyWith(color: colors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            if (discountPercent != null)
              Positioned(
                top: -_pillOverhang.h,
                right: -_pillOverhang.w / 2,
                child: _Pill(label: l10n.myCreditPackDiscount(discountPercent), fill: colors.creditPackDiscountFill),
              ),
            if (isPopular)
              Positioned(
                bottom: -_pillOverhang.h,
                left: 0,
                right: 0,
                child: Center(child: _Pill(label: l10n.myCreditPackPopular, fill: colors.danger)),
              ),
          ],
        ),
      ),
    );
  }

  Color _pictureFill(AppColors colors) => index == 0 ? colors.creditPackTileMint : colors.creditPackTileCream;
}

/// 둥근 알약 (할인율 · 인기)
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.fill});

  final String label;
  final Color fill;

  static const _padH = 8.0;
  static const _padV = 4.0;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(context.space.pillRadius.r)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
        child: Text(label, style: context.typo.proPlanBadgeLabel.copyWith(color: context.colors.surface)),
      ),
    );
  }
}

/// 칸 그림: 한 장 / 두 장 겹침 / 여러 장
class _PictureBox extends StatelessWidget {
  const _PictureBox({required this.index, required this.fill});

  final int index;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final size = MyCreditPackTile._pictureSize.w;
    return DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(context.space.sm.r)),
      child: SizedBox(
        width: MyCreditPackTile._pictureBoxSize.w,
        height: MyCreditPackTile._pictureBoxSize.w,
        child: Center(
          child: switch (index) {
            0 => Image.asset(AppAssets.creditTicketTilted, width: size, excludeFromSemantics: true),
            1 => SizedBox(
              width: size,
              height: size,
              child: Stack(
                children: [
                  Positioned(left: 0, bottom: 0, child: Image.asset(AppAssets.creditTicketTilted, width: size * 0.75, excludeFromSemantics: true)),
                  Positioned(right: 0, top: 0, child: Image.asset(AppAssets.creditTicketTilted, width: size * 0.75, excludeFromSemantics: true)),
                ],
              ),
            ),
            _ => Image.asset(AppAssets.creditTicketStack, width: size, excludeFromSemantics: true),
          },
        ),
      ),
    );
  }
}
