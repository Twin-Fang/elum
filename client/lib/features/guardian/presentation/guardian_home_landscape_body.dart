import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/layout/layout_context_ext.dart';
import '../../../core/layout/tablet_two_pane.dart';
import '../../../core/theme/theme_context_ext.dart';

/// 보호자 홈 가로 태블릿 본문: 전폭 머리 줄(로고 · 이룸이 화면 가기 · 설정) > 왼쪽(인사말·새 일과 만들기·루미 장면) · 오른쪽(목록) (#789)
///
/// 왼쪽은 목록 칸 폭 토큰(`masterPaneWidth`) 고정, 오른쪽이 남는 폭. 코치마크가 목록을 잠글 때는 오른쪽 칸만 [listPhysics] 로 잠근다.
class GuardianHomeLandscapeBody extends StatelessWidget {
  const GuardianHomeLandscapeBody({
    super.key,
    required this.greeting,
    required this.createButton,
    required this.sections,
    required this.listController,
    required this.listPhysics,
  });

  final Widget greeting;
  final Widget createButton;
  final Widget sections;

  /// 오른쪽 칸 스크롤 컨트롤러 (코치마크가 맨 위로 되돌릴 때 쓴다)
  final ScrollController listController;
  final ScrollPhysics? listPhysics;

  /// 인사말 > 버튼 간격 (393 기준)
  static const _greetingToButton = 28.0;

  @override
  Widget build(BuildContext context) {
    final margin = context.layout.pageMarginFor(context.sizeClass).w;
    final space = context.space;

    // 로고·이룸이 화면 입구는 옆 메뉴에 있다 (#798) — 두 칸이 바로 시작한다
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  // 버튼 아래는 비워 둔다: 보호자 커뮤니티(#786)가 열리면 이 자리에 붙인다
                  const Spacer(),
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
