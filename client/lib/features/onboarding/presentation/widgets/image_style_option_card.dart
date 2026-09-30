import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/text/keep_words.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/character.dart';
import '../../domain/image_style.dart';

/// 그림 방식 선택 카드 한 장 — 온보딩과 보호자 설정이 같이 쓴다 (이슈 #458).
///
/// ⚠️ **임시 시안이다** (디자이너 확정 전 제시용 — 목업 opt1_A · opt1_C). 예시 그림도
/// 임시다: 만화는 이미 있는 캐릭터 일러스트를 쓰고, 실사·직접 사진은 **회색 자리표시
/// 상자**다. 최종 예시 그림은 디자이너가 정한다(design-brief 질문 4).
///
/// 두 화면이 같은 카드를 쓰므로 여기서만 고친다. 선택 색은 목표 칩과 같은 민트
/// (`goalSelected*`)다 — 셋 중 하나를 고르는 라디오 카드이지 캐릭터 고르기가 아니다.
class ImageStyleOptionCard extends StatelessWidget {
  const ImageStyleOptionCard({
    super.key,
    required this.style,
    required this.isSelected,
    this.character = CardCharacter.cat,
  });

  final ImageStyle style;
  final bool isSelected;

  /// 만화 예시에 그릴 캐릭터. 온보딩에서 고른 친구가 그대로 보이게 한다.
  final CardCharacter character;

  /// 시안(임시) 실측 — 카드 높이 최소 93, 예시 자리 64×64, 라디오 24.
  static const minHeight = 93.0;
  static const _exampleSize = 64.0;
  static const _radioSize = 24.0;

  /// 화면 낭독기가 읽는 이름. 제목과 설명을 함께 읽는다 —
  /// `직접 사진`만 들으면 "글은 계속 만들어 준다"는 핵심을 놓친다.
  static String semanticLabel(ImageStyle style) =>
      '${style.label}, ${style.description}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      constraints: BoxConstraints(minHeight: minHeight.h),
      // 글자를 키우면 카드가 늘어난다 — 고정 높이면 설명이 잘린다
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: isSelected ? colors.goalSelectedFill : colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
        border: Border.all(
          color: isSelected ? colors.goalSelectedBorder : colors.border,
          width: isSelected ? space.selectedBorderWidth : space.borderWidth,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _exampleSize.w,
            height: _exampleSize.w,
            child: _Example(style: style, character: character),
          ),
          SizedBox(width: space.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  style.label,
                  style: context.typo.subtitle.copyWith(color: colors.textPrimary),
                ),
                SizedBox(height: space.xs.h / 2),
                Text(
                  // Flutter 는 한글을 글자 단위로 끊어 `넣어/요.` 처럼 갈라진다 —
                  // 띄어쓰기에서만 줄바꿈하게 한다. 낭독기에는 원문을 준다.
                  keepWords(style.description),
                  semanticsLabel: style.description,
                  style: context.typo.body.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(width: space.xs.w),
          _Radio(isSelected: isSelected),
        ],
      ),
    );
  }
}

/// 예시 그림 자리 64×64.
class _Example extends StatelessWidget {
  const _Example({required this.style, required this.character});

  final ImageStyle style;
  final CardCharacter character;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    switch (style) {
      case ImageStyle.cartoon:
        // 형태 있는 일러스트는 에셋이다 — 코드로 그리지 않는다
        return SvgPicture.asset(
          AppAssets.character(character),
          fit: BoxFit.contain,
        );
      case ImageStyle.realistic:
        return _Placeholder(label: '실사 예시', fill: colors.imageStyleExampleFill);
      case ImageStyle.photoOnly:
        return _Placeholder(
          label: '내 사진',
          fill: colors.imageStyleExampleFill,
          icon: Icons.photo_camera_outlined,
        );
    }
  }
}

/// 회색 자리표시 상자 — 최종 예시 그림이 나오면 이 자리를 그림으로 바꾼다.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.label, required this.fill, this.icon});

  final String label;
  final Color fill;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10.r),
      ),
      // 글자를 키워도 64 상자를 넘지 않게 줄여서 담는다
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  Icon(icon, size: 24.w, color: colors.imageStyleExampleLabel),
                Text(
                  label,
                  style: context.typo.caption.copyWith(
                    color: colors.imageStyleExampleLabel,
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

/// 라디오 표시 — 고르면 민트 링 안에 점이 찬다.
class _Radio extends StatelessWidget {
  const _Radio({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = ImageStyleOptionCard._radioSize.w;

    return AnimatedContainer(
      duration: AppMotion.fast,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? colors.goalSelectedBorder : colors.border,
          width: 2.w,
        ),
      ),
      child: isSelected
          ? Container(
              width: size / 2,
              height: size / 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.goalSelectedBorder,
              ),
            )
          : null,
    );
  }
}
