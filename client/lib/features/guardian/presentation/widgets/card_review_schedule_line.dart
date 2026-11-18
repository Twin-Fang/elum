import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 카드 확인 도구 줄 아래 고른 반복 한 줄: 달력 + `평일 오전 8:00마다 이룸이에게 보내요` + `바꾸기` (#1457)
/// 글이 길면 두 줄까지 늘어남 (도구 칸 크기는 그대로)
class CardReviewScheduleLine extends StatelessWidget {
  const CardReviewScheduleLine({super.key, required this.summary, required this.onChange});

  /// 반복 요약 (`평일 오전 8:00`)
  final String summary;

  /// `바꾸기`: 반복 고르기 시트 다시 열기 (null 이면 꺼짐)
  final VoidCallback? onChange;

  /// 안쪽 여백 · 달력 그림 · 그림 > 글 · 글 > 바꾸기
  static const _horizontalPadding = 12.0;
  static const _verticalPadding = 8.0;
  static const _iconSize = 14.0;
  static const _iconToText = 6.0;
  static const _textToChange = 8.0;
  static const _radius = 10.0;
  static const _maxLines = 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final labelStyle = context.typo.editChipLabel;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _horizontalPadding.w, vertical: _verticalPadding.h),
      decoration: BoxDecoration(
        color: colors.infoHighlightMintFill,
        borderRadius: BorderRadius.circular(_radius.r),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            AppAssets.iconCalendar,
            width: _iconSize.w,
            height: _iconSize.w,
            colorFilter: ColorFilter.mode(colors.infoHighlightMintAccent, BlendMode.srcIn),
          ),
          SizedBox(width: _iconToText.w),
          Expanded(
            child: Text(
              l10n.cardReviewScheduleLine(summary),
              maxLines: _maxLines,
              overflow: TextOverflow.ellipsis,
              style: labelStyle.copyWith(color: colors.infoHighlightMintAccent, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: _textToChange.w),
          AppPressable(
            onTap: onChange,
            semanticLabel: l10n.cardReviewScheduleChange,
            child: Text(
              l10n.cardReviewScheduleChange,
              style: labelStyle.copyWith(color: colors.editChipLabel, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
