import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../features/onboarding/domain/character.dart';
import '../assets/app_assets.dart';

/// 홈 오른쪽 위 캐릭터 배지 — 보호자 홈과 이룸이 홈이 함께 쓴다.
///
/// **여우만 경계 밖을 잘라낸다** (#311). 여우 에셋은 시안에서 마스크가 셋 겹쳐
/// 나오는데 `flutter_svg` 가 그것을 온전히 그리지 못해 캐릭터가 둥근 사각형
/// 밖으로 삐져나온다. 시안에서 다시 받아도 마스크는 그대로 셋이라 에셋 교체로는
/// 풀리지 않는다.
///
/// **고양이에는 씌우지 않는다.** 멀쩡한 것을 잘라내면 모서리가 미세하게 깎여
/// 시안 대조 테스트가 어긋난다 — 실제로 그렇게 나왔다.
///
/// 두 홈이 각자 그리던 때는 보호자 홈만 고쳐지고 이룸이 홈은 그대로 깨져 있었다.
/// 한 곳에 두어 다시 어긋나지 않게 한다.
class CharacterBadge extends StatelessWidget {
  const CharacterBadge({super.key, required this.character});

  final CardCharacter character;

  /// 배지 한 변. 시안 356:5106(보호자) · 356:5079(이룸이) 모두 56이다.
  static const size = 56.0;

  /// 배지 모서리. 시안 356:5106 · 382:3257 이 16 이다.
  static const radius = 16.0;

  @override
  Widget build(BuildContext context) {
    final badge = SvgPicture.asset(
      AppAssets.characterBadgeFramed(character),
      // 정사각형 배지 — 찌그러지지 않게 가로세로 모두 .w
      width: size.w,
      height: size.w,
    );
    if (character != CardCharacter.fox) return badge;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius.r),
      child: badge,
    );
  }
}
