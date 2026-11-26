import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/layout/app_text_scale.dart';
import '../../../../core/text/keep_words.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 내 요금제 카드 공통 치수 (Pro · Free 같은 틀)
abstract final class MyPlanCardLayout {
  /// 카드 안쪽 여백
  static const padding = 20.0;

  /// 칩 > 제목 · 제목 > 한 줄
  static const chipToTitle = 10.0;
  static const titleToSubline = 4.0;

  /// 글 묶음 > 루미
  static const textToMascot = 12.0;
}

/// 카드 머리: [칩 > 제목 > 한 줄] | 루미 (큰 글자면 루미를 빼고 글에 폭을 줌)
class MyPlanHeader extends StatelessWidget {
  const MyPlanHeader({
    super.key,
    required this.chip,
    required this.title,
    required this.subline,
    required this.mascot,
  });

  final Widget chip;
  final Widget title;
  final Widget? subline;
  final Widget mascot;

  @override
  Widget build(BuildContext context) {
    final subline = this.subline;
    final shouldShowMascot = !AppTextScale.isLargeTextOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              chip,
              SizedBox(height: MyPlanCardLayout.chipToTitle.h),
              title,
              if (subline != null) ...[
                SizedBox(height: MyPlanCardLayout.titleToSubline.h),
                subline,
              ],
            ],
          ),
        ),
        if (shouldShowMascot) ...[
          SizedBox(width: MyPlanCardLayout.textToMascot.w),
          mascot,
        ],
      ],
    );
  }
}

/// 카드 제목 + (있으면) 끝 이모지 그림. 기기 글꼴과 무관하게 같은 그림, 크기는 글자와 같이 커짐 (글 안 그림은 Text 가 배율을 곱함)
class MyPlanTitle extends StatelessWidget {
  const MyPlanTitle({super.key, required this.title, this.emojiAsset});

  final String title;
  final String? emojiAsset;

  /// 글자 > 이모지 간격
  static const _emojiGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final style = context.typo.proPlanTeaserTitle.copyWith(color: context.colors.textPrimary);
    final emojiAsset = this.emojiAsset;
    final keptTitle = keepWords(title, locale: context.appLocale);
    if (emojiAsset == null) return Text(keptTitle, semanticsLabel: title, style: style);
    final emojiSize = style.fontSize ?? 0;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: keptTitle),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(left: _emojiGap.w),
              child: SvgPicture.asset(emojiAsset, width: emojiSize, height: emojiSize, excludeFromSemantics: true),
            ),
          ),
        ],
      ),
      semanticsLabel: title,
      style: style,
    );
  }
}

/// 오른쪽 루미: 둥근 빛 위 그림 (Pro 는 손 흔드는 루미, Free 는 얼굴 루미)
class MyPlanMascot extends StatelessWidget {
  const MyPlanMascot._({required this.isPro});

  factory MyPlanMascot.pro() => const MyPlanMascot._(isPro: true);
  factory MyPlanMascot.free() => const MyPlanMascot._(isPro: false);

  final bool isPro;

  /// 둥근 빛 지름 · 그 안 그림
  static const _haloSize = 76.0;
  static const _proPictureSize = 60.0;
  static const _freePictureSize = 56.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final haloColor = isPro ? colors.proPlanMyCardHalo : colors.proPlanMyCardFreeHalo;
    return ExcludeSemantics(
      child: Container(
        width: _haloSize.w,
        height: _haloSize.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: haloColor, shape: BoxShape.circle),
        child: isPro
            ? Image.asset(AppAssets.myPlanProLumi, width: _proPictureSize.w, height: _proPictureSize.w)
            : Image.asset(AppAssets.guardianProfileLumi, width: _freePictureSize.w, height: _freePictureSize.w),
      ),
    );
  }
}
