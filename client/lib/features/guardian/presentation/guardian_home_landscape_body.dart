import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/layout/tablet_two_pane.dart';
import '../../../core/theme/theme_context_ext.dart';

/// 보호자 홈 가로 태블릿 본문: 왼쪽(인사말 · 새 일과 만들기 · 오늘 · 지난 일과, 스크롤) | 오른쪽(고른 일과 상세) (#1455)
///
/// 로고·이룸이 화면 입구는 옆 메뉴 (#798). 코치마크가 목록을 잠글 때는 왼쪽 칸만 [listPhysics] 로 잠근다.
class GuardianHomeLandscapeBody extends StatelessWidget {
  const GuardianHomeLandscapeBody({
    super.key,
    required this.greeting,
    required this.createButton,
    required this.sections,
    required this.detailPane,
    required this.listController,
    required this.listPhysics,
    required this.listScrollWrapper,
  });

  final Widget greeting;
  final Widget createButton;
  final Widget sections;

  /// 오른쪽 칸 (고른 일과 상세)
  final Widget detailPane;

  /// 왼쪽 칸 스크롤 컨트롤러 (코치마크가 맨 위로 되돌릴 때 쓴다)
  final ScrollController listController;
  final ScrollPhysics? listPhysics;

  /// 왼쪽 목록 스크롤을 감싸는 것 (당겨서 새로고침)
  final Widget Function(Widget listScroll) listScrollWrapper;

  /// 칸 위 여백 · 인사말 > 버튼 · 버튼 > 목록 (393 기준)
  static const _paneTop = 24.0;
  static const _greetingToButton = 28.0;
  static const _buttonToSections = 32.0;

  /// 왼쪽 목록 : 오른쪽 상세 폭 비율
  static const _listFlex = 5;
  static const _detailFlex = 6;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return TabletTwoPane(
      leadingFlex: _listFlex,
      trailingFlex: _detailFlex,
      leadingPane: listScrollWrapper(
        SingleChildScrollView(
          controller: listController,
          physics: listPhysics,
          padding: EdgeInsets.only(top: _paneTop.h, bottom: space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 인사말은 머리말 안쪽 여백만큼 당겨 버튼·목록과 왼쪽 끝을 맞춤
              Transform.translate(offset: Offset(-space.screenH.w, 0), child: greeting),
              SizedBox(height: _greetingToButton.h),
              createButton,
              SizedBox(height: _buttonToSections.h),
              sections,
            ],
          ),
        ),
      ),
      trailingPane: Padding(
        padding: EdgeInsets.only(top: _paneTop.h, bottom: _paneTop.h),
        child: detailPane,
      ),
    );
  }
}
