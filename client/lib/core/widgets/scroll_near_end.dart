import 'package:flutter/widgets.dart';

/// 목록 끝 근처 판정: 다음 쪽 받기(무한 스크롤) 화면 공통
extension ScrollNearEnd on ScrollController {
  /// 끝까지 이만큼(논리 픽셀) 남으면 다음 쪽을 미리 받음
  static const loadMoreTriggerExtent = 320.0;

  /// 끝까지 [loadMoreTriggerExtent] 보다 적게 남았는가
  bool get isNearListEnd => position.extentAfter < loadMoreTriggerExtent;
}
