import 'package:flutter/widgets.dart';

import '../../../../core/layout/layout_context_ext.dart';
import 'child_card_pager.dart';

/// 카드 넘기기 컨트롤러 관리: 창 등급별 한 장 폭, 등급이 바뀌면 보던 카드에서 다시 만들기 (#789)
///
/// 폰은 옆 카드가 걸치게 한 장 폭(카드 + 간격)만큼 자르고, 태블릿은 한 장이 자리를 꽉 채운다.
mixin ChildCardPageControllerMixin<T extends StatefulWidget> on State<T> {
  PageController? _pageController;
  bool? _isFullCardPager;

  PageController get cardPageController => _pageController!;

  /// 지금 가운데 카드 순번. 붙기 전에는 시작 순번
  int get currentCardIndex {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) {
      return controller?.initialPage ?? 0;
    }
    return (controller.page ?? controller.initialPage.toDouble()).round();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPageController();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  /// 창 등급에 맞는 컨트롤러 준비 (처음 + 폰 <-> 태블릿 전환 시)
  void _syncPageController() {
    final isFullCardPager = context.layoutMetrics.isScaleOverridden;
    if (_isFullCardPager == isFullCardPager) return;
    final previous = _pageController;
    final initialPage = previous == null ? 0 : currentCardIndex;
    _pageController = PageController(
      viewportFraction: isFullCardPager ? 1.0 : ChildCardPager.viewportFraction,
      initialPage: initialPage,
    );
    _isFullCardPager = isFullCardPager;
    // 옛 컨트롤러는 새 PageView 가 붙은 뒤에 정리 (build 전에 버리면 붙어 있던 위젯이 깨진다)
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }
}
