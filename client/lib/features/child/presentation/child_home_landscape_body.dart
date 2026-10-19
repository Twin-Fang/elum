import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/layout/layout_context_ext.dart';
import '../../../shared/models/character.dart';

/// 이룸이 홈 가로 태블릿 본문: 왼쪽 인사말·캐릭터, 오른쪽 일과 목록(스크롤)
///
/// 두 칸 비율 5:6. 목록이 길면 오른쪽만 스크롤되고 인사말은 제자리에 있다.
class ChildHomeLandscapeBody extends StatelessWidget {
  const ChildHomeLandscapeBody({
    super.key,
    required this.greeting,
    required this.character,
    required this.routineList,
  });

  final Widget greeting;

  /// 온보딩에서 고른 캐릭터 (인사말 아래 그림)
  final CardCharacter character;
  final Widget routineList;

  /// 인사말 칸 : 목록 칸 = 5 : 6
  static const _greetingFlex = 5;
  static const _listFlex = 6;

  /// 캐릭터 그림 크기 (393 기준, `.w`)
  static const _characterSize = 220.0;

  @override
  Widget build(BuildContext context) {
    final margin = context.layout.pageMarginFor(context.sizeClass).w;
    // 밝은 배경에서도 또렷한 테두리 배지 (고양이 파랑, 여우 주황). 보상 화면의 흰색 그림은 어두운 배경용
    final characterAsset = AppAssets.characterBadgeFramed(character);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: _greetingFlex,
          child: Padding(
            padding: EdgeInsets.only(left: margin, right: margin / 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                greeting,
                SizedBox(height: 32.h),
                // 그림은 장식이라 화면 낭독기에 내놓지 않는다
                ExcludeSemantics(
                  child: SvgPicture.asset(
                    characterAsset,
                    width: _characterSize.w,
                    height: _characterSize.w,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: _listFlex,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: margin / 2,
              right: margin,
              top: 8.h,
              bottom: 32.h,
            ),
            child: routineList,
          ),
        ),
      ],
    );
  }
}
