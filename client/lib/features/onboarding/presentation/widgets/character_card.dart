import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/character.dart';

/// 캐릭터 선택 카드. Figma 기준 176×202.
///
/// 선택 색이 **캐릭터마다 다르다** — 여우는 복숭아, 고양이는 파랑.
/// (Figma 온보딩_캐릭터_여우 204:1121 / 온보딩_캐릭터_고양이 204:1134)
/// 목표 칩(민트)과도 다르므로 색을 공유하지 않는다.
class CharacterCard extends StatelessWidget {
  const CharacterCard({
    super.key,
    required this.character,
    required this.isSelected,
  });

  /// Figma 실측 — 카드 176×202
  static const height = 202.0;

  /// 카드 안 일러스트 152×152 (카드 상단에서 29 내려온 자리)
  static const _illustrationSize = 152.0;

  /// 카드 상단(y=279) → 일러스트 상단(y=308)
  static const _illustrationTop = 29.0;

  /// 발밑 그림자 (Figma `204:1037` 그림자 — 카드 기준 x=53, y=172, 64×16).
  /// 없으면 캐릭터가 허공에 뜬다 — 실제로 빠져 있었다 (#297).
  static const _shadowWidth = 64.0;
  static const _shadowHeight = 16.0;
  static const _shadowTop = 172.0;

  /// 카드 하단(481) → 이름(493). 이름은 **카드 밖**에 있다.
  static const nameGap = 12.0;

  final CardCharacter character;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    // 캐릭터별 선택 색 — enum이 늘면 여기서 컴파일 에러가 난다
    final selection = colors.characterSelected(character);

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      height: height.h,
      decoration: BoxDecoration(
        color: isSelected ? selection.fill : colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
        border: Border.all(
          color: isSelected ? selection.border : colors.border,
          width: isSelected ? space.selectedBorderWidth : space.borderWidth,
        ),
      ),
      // 그림자를 **일러스트보다 먼저** 깐다 — 발 뒤에 깔려야 한다.
      //
      // 이름(루루·포포)은 이 카드 밖, 카드 아래 12 자리에 놓인다
      // (Figma `732:5320` / `732:5319`). 카드 안에 넣으면 높이가 202를 넘는다.
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: _shadowTop.h,
            child: Container(
              width: _shadowWidth.w,
              height: _shadowHeight.h,
              decoration: BoxDecoration(
                color: colors.characterCardShadow,
                borderRadius: BorderRadius.all(
                  Radius.elliptical(_shadowWidth.w / 2, _shadowHeight.h / 2),
                ),
              ),
            ),
          ),
          Positioned(
            top: _illustrationTop.h,
            child: SvgPicture.asset(
              AppAssets.character(character),
              width: _illustrationSize.w,
              height: _illustrationSize.w,
            ),
          ),
        ],
      ),
    );
  }
}
