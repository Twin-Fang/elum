import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import '../theme/theme_context_ext.dart';
import 'kept_text.dart';

/// 하이라이트 띠 색 2가지: 민트 (좋은 소식·다음 할 일) · 피치 (살짝 주의·권유)
enum ElumHighlightTone { mint, peach }

/// 하이라이트 띠: 연한 바탕 + 3D 아이콘 + 한 줄 (카드 안·목록 위 강조 한 줄)
/// 글은 어절 단위로 줄바꿈 (큰 글자에서도 잘리지 않게)
class ElumHighlight extends StatelessWidget {
  const ElumHighlight({
    super.key,
    required this.iconAsset,
    required this.text,
    this.tone = ElumHighlightTone.mint,
  });

  /// 3D 아이콘 PNG (AppAssets.featureIcon*)
  final String iconAsset;
  final String text;
  final ElumHighlightTone tone;

  static const _iconSize = 32.0;
  static const _horizontalPadding = 14.0;
  static const _verticalPadding = 10.0;
  static const _radius = 16.0;
  static const _iconToText = 10.0;

  Color _fillOf(AppColors colors) => switch (tone) {
    ElumHighlightTone.mint => colors.infoHighlightMintFill,
    ElumHighlightTone.peach => colors.infoHighlightPeachFill,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _horizontalPadding.w, vertical: _verticalPadding.h),
      decoration: BoxDecoration(color: _fillOf(colors), borderRadius: BorderRadius.circular(_radius.r)),
      child: Row(
        children: [
          Image.asset(iconAsset, width: _iconSize.w, height: _iconSize.w, fit: BoxFit.contain, excludeFromSemantics: true),
          SizedBox(width: _iconToText.w),
          Expanded(
            child: KeptText(text, style: context.typo.creditBody.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
