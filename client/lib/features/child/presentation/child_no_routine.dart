import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_pull_to_refresh.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../shared/models/character.dart';

/// 보호자가 아직 일과를 만들지 않았다 (Figma 343:4543).
class ChildNoRoutine extends StatelessWidget {
  const ChildNoRoutine({
    super.key,
    required this.childName,
    required this.character,
    required this.isElumiDevice,
    this.errorCode,
  });

  final String childName;

  /// 이룸이 휴대폰인가. 두 휴대폰의 시안 문구가 다르다.
  ///
  /// 보호자 휴대폰 시안(`343:4543`)은 `보호자 화면에서`, 이룸이 휴대폰 시안(`1197:6846`)은
  /// `보호자 모드에서`다. 한 위젯을 같이 쓰므로 휴대폰별로 갈라 각자 시안대로 맞춘다.
  final bool isElumiDevice;

  /// 온보딩에서 고른 캐릭터. 시무룩한 일러스트·글로우 색이 갈린다.
  final CardCharacter character;

  /// 조회 실패 시 제보 추적용 코드. null이면 표시하지 않는다.
  final String? errorCode;

  /// 상단 줄 아래부터 제목까지 — 시안(343:4543)은 제목이 234 에서 시작한다.
  /// 상단 줄 아래 → 시무룩한 그림. 상단을 6 올린 만큼 여기서 되돌린다.
  static double get _emptyTop => 109.h;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 캐릭터별 일러스트·글로우 — 고양이는 파랑, 여우는 주황 (Figma 343:4543)
    final (glowColor, sadAsset) = switch (character) {
      CardCharacter.cat => (colors.catSelectedFill, AppAssets.ruruSad),
      CardCharacter.fox => (colors.foxSelectedFill, AppAssets.popoSad),
    };

    // 작은 화면·큰 글꼴에서도 넘치지 않게 스크롤로 감싼다.
    //
    // **`Center`가 아니다.** 세로 가운데에 두면 화면 높이에 따라 글자가 오르내려
    // 시안과 어긋난다 — 실제로 81 아래에 있었다. 시안(343:4543)은 제목이 234 에서
    // 시작하므로 위 여백을 고정한다.
    // 일과가 0건이어도 당겨서 새로고침이 되게 항상 스크롤 가능 (튕김 없음)
    return SingleChildScrollView(
      physics: ElumPullToRefresh.calmPhysics,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: _emptyTop),
          Text(
            context.l10n.childHomeEmptyTitle(childName),
            textAlign: TextAlign.center,
            style: context.typo.greeting.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: 14.h),
          Text(
            isElumiDevice
                ? context.l10n.childHomeEmptyHintDevice
                : context.l10n.childHomeEmptyHint,
            style: context.typo.body.copyWith(color: colors.textSecondary),
          ),
          if (errorCode != null) ...[
            SizedBox(height: 8.h),
            Text(
              '($errorCode)',
              style: context.typo.caption.copyWith(color: colors.textSecondary),
            ),
          ],
          // 설명 → 시무룩한 그림. 48을 쓰면 그림이 15 내려간다.
          SizedBox(height: 35.h),
          // 캐릭터 뒤 은은한 빛 — 단순 원이라 코드로 그린다
          // (Figma blur 100 ≈ sigma 50)
          SizedBox(
            width: 200.w,
            height: 200.w,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 50.w, sigmaY: 50.w),
                  child: Container(
                    width: 180.w,
                    height: 180.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: glowColor,
                    ),
                  ),
                ),
                // 발밑 그림자 (Figma Ellipse 2 — 64×16). 캐릭터보다 뒤에 깐다
                Positioned(
                  bottom: 10.w,
                  child: ClipOval(
                    child: SizedBox(
                      width: 64.w,
                      height: 16.w,
                      child: ColoredBox(color: colors.childEmptyShadow),
                    ),
                  ),
                ),
                // 시무룩한 캐릭터 — 형태가 있는 일러스트는 반드시 에셋
                SvgPicture.asset(sadAsset, width: 164.w, height: 164.w),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
