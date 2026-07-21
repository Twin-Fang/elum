import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/character.dart';

/// 캐릭터 선택 카드. Figma 기준 176×202.
///
/// 목표 칩과 선택 색은 같지만 레이아웃이 달라 별도 위젯으로 둔다.
/// (같은 것은 토큰으로 공유하고, 다른 것은 분리한다)
class CharacterCard extends StatelessWidget {
  const CharacterCard({
    super.key,
    required this.character,
    required this.isSelected,
  });

  final CardCharacter character;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 202,
      decoration: BoxDecoration(
        color: isSelected ? colors.selectedFill : colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius),
        border: Border.all(
          color: isSelected ? colors.selectedBorder : colors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Center(
        child: SvgPicture.asset(
          AppAssets.character(character),
          width: 152,
          height: 152,
        ),
      ),
    );
  }
}
