import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/layout/layout_context_ext.dart';
import '../../../core/theme/theme_context_ext.dart';

/// 보호자 홈 가로 태블릿 본문: 왼쪽(머리말·새 일과 만들기), 오른쪽(오늘·지난 일과 목록)
///
/// 왼쪽은 목록 칸 폭 토큰(`masterPaneWidth`)으로 고정하고 오른쪽이 남는 폭을 쓴다.
/// 두 칸이 따로 스크롤된다. 코치마크가 목록을 잠글 때는 오른쪽 칸만 [listPhysics] 로 잠근다.
class GuardianHomeLandscapeBody extends StatelessWidget {
  const GuardianHomeLandscapeBody({
    super.key,
    required this.header,
    required this.createButton,
    required this.sections,
    required this.listController,
    required this.listPhysics,
  });

  final Widget header;
  final Widget createButton;
  final Widget sections;

  /// 오른쪽 칸 스크롤 컨트롤러 (코치마크가 맨 위로 되돌릴 때 쓴다)
  final ScrollController listController;
  final ScrollPhysics? listPhysics;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final margin = layout.pageMarginFor(context.sizeClass).w;
    final space = context.space;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: layout.masterPaneWidth.w + margin,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(left: margin - space.screenH.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                SizedBox(height: 32.h),
                createButton,
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: listController,
            physics: listPhysics,
            padding: EdgeInsets.only(
              top: 32.h,
              right: margin - 16.w,
              bottom: space.xl,
            ),
            child: sections,
          ),
        ),
      ],
    );
  }
}
