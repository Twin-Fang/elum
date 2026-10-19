import 'app_layout.dart';

/// 앱 창 폭 등급 (Material 3 기준): compact 폰, medium 작은 태블릿·세로, expanded 큰 태블릿·가로
///
/// 기기 종류가 아니라 **창 폭**으로 가른다 — 아이패드 분할 보기·안드로이드 분할 화면에서도 맞다.
enum WindowSizeClass {
  compact,
  medium,
  expanded;

  /// 창 폭(dp) > 등급. 경계값은 [AppLayout] 토큰
  static WindowSizeClass fromWidth(double width, AppLayout layout) {
    if (width >= layout.expandedMinWidth) return WindowSizeClass.expanded;
    if (width >= layout.mediumMinWidth) return WindowSizeClass.medium;
    return WindowSizeClass.compact;
  }
}
