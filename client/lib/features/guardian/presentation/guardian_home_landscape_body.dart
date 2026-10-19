import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/layout/layout_context_ext.dart';
import '../../../core/layout/tablet_two_pane.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/tablet_hero_scene.dart';

/// 보호자 홈 가로 태블릿 본문: 전폭 머리 줄(로고 · 이룸이 화면 가기 · 설정) > 왼쪽(인사말·새 일과 만들기·루미 장면) · 오른쪽(목록) (#789)
///
/// 왼쪽은 목록 칸 폭 토큰(`masterPaneWidth`) 고정, 오른쪽이 남는 폭. 코치마크가 목록을 잠글 때는 오른쪽 칸만 [listPhysics] 로 잠근다.
class GuardianHomeLandscapeBody extends StatelessWidget {
  const GuardianHomeLandscapeBody({
    super.key,
    required this.topRow,
    required this.greeting,
    required this.createButton,
    required this.sections,
    required this.listController,
    required this.listPhysics,
  });

  /// 전폭 머리 줄 (태블릿 앱 관례: 로고 왼쪽, 이동·설정 오른쪽 끝)
  final Widget topRow;
  final Widget greeting;
  final Widget createButton;
  final Widget sections;

  /// 오른쪽 칸 스크롤 컨트롤러 (코치마크가 맨 위로 되돌릴 때 쓴다)
  final ScrollController listController;
  final ScrollPhysics? listPhysics;

  /// 인사말 > 버튼 > 장면 간격 (393 기준)
  static const _greetingToButton = 28.0;
  static const _buttonToScene = 24.0;

  @override
  Widget build(BuildContext context) {
    final margin = context.layout.pageMarginFor(context.sizeClass).w;
    final space = context.space;
    // 머리말·버튼은 자체 좌우 여백(screenH)을 가진다 — 바깥 여백과 겹치지 않게 뺀다
    final innerInset = margin - space.screenH.w;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: innerInset),
          child: topRow,
        ),
        Expanded(
          child: TabletTwoPane(
            leadingWidth: context.layout.masterPaneWidth,
            leadingPane: Padding(
              padding: EdgeInsets.only(bottom: margin / 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 24.h),
                  Transform.translate(
                    offset: Offset(-space.screenH.w, 0),
                    child: greeting,
                  ),
                  SizedBox(height: _greetingToButton.h),
                  Transform.translate(
                    offset: Offset(-space.screenH.w, 0),
                    child: createButton,
                  ),
                  SizedBox(height: _buttonToScene.h),
                  // 루미가 일과를 만들어 준다는 장면 (새 일과 만들기 아래 빈 칸 채우기)
                  const Expanded(
                    child: TabletHeroScene(
                      characterAsset: AppAssets.homeNewRoutineChick,
                      characterHeightRatio: 0.45,
                    ),
                  ),
                ],
              ),
            ),
            trailingPane: SingleChildScrollView(
              controller: listController,
              physics: listPhysics,
              padding: EdgeInsets.only(top: 24.h, bottom: space.xl),
              child: sections,
            ),
          ),
        ),
      ],
    );
  }
}
