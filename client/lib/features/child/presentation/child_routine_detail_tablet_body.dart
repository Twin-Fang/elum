import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 이룸이 카드 상세 태블릿 본문: 카드를 가능한 만큼 크게, 체크 버튼은 손이 닿는 자리에
///
/// 카드 자리는 폰 시안 상자(393x410)를 통째로 [FittedBox] 로 키운다. 카드·옆 카드 걸침·글자가 같은 비율로 커져
/// 폰의 모양과 넘기는 느낌이 그대로다. 태블릿은 양손으로 잡으므로
/// - 가로: 체크 버튼을 오른쪽 가장자리 칸(엄지 자리)에 두고, 카드는 왼쪽 같은 폭을 비워 가운데에 맞춘다
/// - 세로: 카드 아래 가운데
class ChildRoutineDetailTabletBody extends StatelessWidget {
  const ChildRoutineDetailTabletBody({
    super.key,
    required this.topBar,
    required this.rewardBanner,
    required this.pager,
    required this.checkButton,
    required this.isLandscape,
  });

  final Widget topBar;

  /// 보상 칩. 보상이 없으면 빈 위젯
  final Widget rewardBanner;

  /// 폰 시안 크기(393x410) 카드 넘기기 상자
  final Widget pager;

  final Widget checkButton;
  final bool isLandscape;

  /// 가로에서 체크 버튼 칸 폭 (393 기준, `.w`). 왼쪽에도 같은 폭을 비워 카드를 가운데에 둔다
  static const _railWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    // Expanded 가 주는 꽉 찬 제약 안에서 contain 으로 키운다 (느슨한 제약이면 키우지 않는다)
    final cardArea = FittedBox(fit: BoxFit.contain, child: pager);

    return Column(
      children: [
        SizedBox(height: 8.h),
        topBar,
        SizedBox(height: 16.h),
        Center(child: rewardBanner),
        SizedBox(height: 16.h),
        Expanded(
          child: isLandscape
              ? Row(
                  children: [
                    SizedBox(width: _railWidth.w),
                    Expanded(child: cardArea),
                    SizedBox(
                      width: _railWidth.w,
                      child: Center(child: checkButton),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Expanded(child: cardArea),
                    SizedBox(height: 24.h),
                    checkButton,
                  ],
                ),
        ),
        SizedBox(height: isLandscape ? 24.h : 40.h),
      ],
    );
  }
}
