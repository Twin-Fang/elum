import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
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

  final CardCharacter character;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    // 캐릭터별 선택 색 — enum이 늘면 여기서 컴파일 에러가 난다
    final selection = colors.characterSelected(character);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      decoration: BoxDecoration(
        color: isSelected ? selection.fill : colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius),
        border: Border.all(
          color: isSelected ? selection.border : colors.border,
          width: isSelected ? space.selectedBorderWidth : space.borderWidth,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            AppAssets.character(character),
            width: _illustrationSize,
            height: _illustrationSize,
          ),
          // Figma는 이 자리(Ellipse 2/3, y=451)를 회색 알약으로 비워뒀다.
          // 이름이 정해져 텍스트로 채운다.
          Text(
            character.displayName,
            style: context.typo.body.copyWith(color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}
