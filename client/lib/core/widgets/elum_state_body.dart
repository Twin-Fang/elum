import 'package:flutter/material.dart';

/// 화면 본문 전체가 로딩·빈 상태·실패일 때 놓는 자리.
///
/// 셋이 **같은 자리(남는 높이의 세로 가운데)**에 놓여야 로딩에서 실패로 바뀔 때
/// 내용이 튀지 않는다. 화면마다 위 여백을 따로 주면 자리가 제각각이 된다.
/// 글자가 커져 내용이 높이를 넘으면 잘리지 않게 스크롤한다.
///
/// 화면 한 구역만 상태일 때(홈 목록 한 칸 등)는 쓰지 않는다 — 그 구역의 칸에 둔다.
class ElumStateBody extends StatelessWidget {
  const ElumStateBody({super.key, required this.child});

  const ElumStateBody.loading({super.key})
    : child = const CircularProgressIndicator();

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 바깥이 스크롤이면 높이를 몰라 가운데를 잡을 기준이 없다 — 위에 그대로 둔다.
        if (!constraints.hasBoundedHeight) return Center(child: child);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
