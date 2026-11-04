import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_spinner.dart';

/// 칩 모양: 알약 (사진 바꾸기 칩과 같은 시안 모서리 100)
const _chipPillRadius = 100.0;

/// 녹음 칸 바탕: 흰 판 · 1px 테두리 · 모서리 20 (시트 입력칸과 같은 모양)
class CardVoiceFrame extends StatelessWidget {
  const CardVoiceFrame({super.key, required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: colors.border),
      ),
      // 낭독기가 녹음 상태가 바뀔 때마다 바로 읽는다
      child: Semantics(liveRegion: true, child: child),
    );
  }
}

/// 왼쪽 글자 (제목 1줄 · 설명 2줄까지) + 오른쪽 버튼들
class CardVoiceRow extends StatelessWidget {
  const CardVoiceRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Row(
      children: [
        if (leading != null) ...[leading!, SizedBox(width: 8.w)],
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typo.editChipLabel.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 2.h),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: typo.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        for (final action in actions) ...[SizedBox(width: 4.w), action],
      ],
    );
  }
}

/// 녹음 칸 버튼: 아이콘 + 글자 알약. 보이는 알약은 작아도 누름 영역은 48 이상
class CardVoiceChip extends StatelessWidget {
  const CardVoiceChip({super.key, required this.label, required this.onTap, this.iconAsset});

  final String label;
  final String? iconAsset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppPressable(
      onTap: onTap,
      semanticLabel: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Align(
          widthFactor: 1,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: colors.editChipBg,
              borderRadius: BorderRadius.circular(_chipPillRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconAsset != null) ...[CardVoiceIcon(asset: iconAsset!), SizedBox(width: 4.w)],
                Text(
                  label,
                  style: context.typo.editChipLabel.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `fi-br` 16 아이콘 (남색)
class CardVoiceIcon extends StatelessWidget {
  const CardVoiceIcon({super.key, required this.asset});

  final String asset;

  static const _size = 16.0;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: _size.w,
      height: _size.w,
      excludeFromSemantics: true,
      colorFilter: ColorFilter.mode(context.colors.textPrimary, BlendMode.srcIn),
    );
  }
}

/// 올리는 중 표시
class CardVoiceSpinner extends StatelessWidget {
  const CardVoiceSpinner({super.key});

  @override
  Widget build(BuildContext context) =>
      ElumSpinner(size: 20.w, strokeWidth: 2, color: context.colors.textPrimary);
}
