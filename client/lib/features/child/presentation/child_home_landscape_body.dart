import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/layout/layout_context_ext.dart';
import '../../../core/layout/tablet_two_pane.dart';
import '../../../core/widgets/elum_pull_to_refresh.dart';
import '../../../core/widgets/tablet_hero_scene.dart';
import '../../../shared/models/character.dart';

/// 이룸이 홈 가로 태블릿 본문: 왼쪽 인사말·장면 그림, 오른쪽 일과 목록(스크롤)
///
/// 장면에는 캐릭터 **전신** 그림을 쓴다. 테두리 배지는 보호자 화면 가기 버튼과 같은 그림이라 장식으로 쓰지 않는다 (#789).
class ChildHomeLandscapeBody extends StatelessWidget {
  const ChildHomeLandscapeBody({
    super.key,
    required this.greeting,
    required this.character,
    required this.routineList,
    required this.listScrollWrapper,
  });

  final Widget greeting;

  /// 온보딩에서 고른 캐릭터 (장면 속 그림)
  final CardCharacter character;
  final Widget routineList;

  /// 오른쪽 목록 스크롤을 감싸는 것 (당겨서 새로고침 — 동그라미가 목록 칸 위에 나옴)
  final Widget Function(Widget listScroll) listScrollWrapper;

  /// 인사말 > 장면 간격 (393 기준)
  static const _greetingToScene = 20.0;

  @override
  Widget build(BuildContext context) {
    final margin = context.layout.pageMarginFor(context.sizeClass).w;

    return TabletTwoPane(
      leadingPane: Padding(
        padding: EdgeInsets.only(bottom: margin / 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8.h),
            greeting,
            SizedBox(height: _greetingToScene.h),
            Expanded(
              child: TabletHeroScene(
                characterAsset: AppAssets.character(character),
              ),
            ),
          ],
        ),
      ),
      trailingPane: listScrollWrapper(
        SingleChildScrollView(
          physics: ElumPullToRefresh.calmPhysics,
          padding: EdgeInsets.only(top: 8.h, bottom: 32.h),
          child: routineList,
        ),
      ),
    );
  }
}
