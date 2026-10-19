import 'package:flutter/material.dart';

import 'window_size_class.dart';

/// 레이아웃 토큰: 창 등급 경계, 배율 범위, 폭 상한, 여백
///
/// 화면 코드는 숫자를 직접 쓰지 않고 `context.layout` 으로 읽는다.
/// 폭 상한은 `.w` 적용 전 값(시안 393 기준)이다.
@immutable
class AppLayout extends ThemeExtension<AppLayout> {
  const AppLayout({
    required this.mediumMinWidth,
    required this.expandedMinWidth,
    required this.shortHeightMax,
    required this.phoneColumnWidth,
    required this.designHeight,
    required this.minFrameScale,
    required this.maxFrameScale,
    required this.contentColumnMaxWidth,
    required this.readingMaxWidth,
    required this.masterPaneWidth,
    required this.paneGutter,
    required this.sheetMaxWidth,
    required this.sidePanelWidth,
  });

  /// medium 시작 폭 (dp)
  final double mediumMinWidth;

  /// expanded 시작 폭 (dp)
  final double expandedMinWidth;

  /// 이 높이(dp) 미만이면 한 열 스크롤로 접는다
  final double shortHeightMax;

  /// 폰 비율 열의 기준 폭 = 시안 프레임 폭
  final double phoneColumnWidth;

  /// 시안 프레임 높이. 절대 좌표 뼈대가 이 높이를 전제로 한다
  final double designHeight;

  /// 태블릿 배율 s 의 하한·상한 (창이 작으면 줄이고, 아무리 커도 이 이상 키우지 않는다)
  final double minFrameScale;
  final double maxFrameScale;

  /// 폼·설정 화면 가운데 열의 폭 상한
  final double contentColumnMaxWidth;

  /// 약관 같은 긴 글의 폭 상한
  final double readingMaxWidth;

  /// 2단 레이아웃의 왼쪽(목록) 폭과 두 단 사이 간격
  final double masterPaneWidth;
  final double paneGutter;

  /// 바텀시트·토스트 폭 상한 (확인 팝업 카드는 폭이 이미 고정이라 상한이 없다)
  final double sheetMaxWidth;

  /// 가로 태블릿에서 오른쪽에서 나오는 옆 패널 폭 (시트를 대신한다, #789)
  final double sidePanelWidth;

  static const standard = AppLayout(
    mediumMinWidth: 600,
    expandedMinWidth: 840,
    shortHeightMax: 480,
    phoneColumnWidth: 393,
    designHeight: 852,
    minFrameScale: 0.8,
    maxFrameScale: 1.3,
    contentColumnMaxWidth: 560,
    readingMaxWidth: 640,
    masterPaneWidth: 360,
    paneGutter: 24,
    sheetMaxWidth: 560,
    sidePanelWidth: 440,
  );

  /// 등급별 좌우 여백 (dp)
  double pageMarginFor(WindowSizeClass sizeClass) {
    return switch (sizeClass) {
      WindowSizeClass.compact => 24,
      WindowSizeClass.medium => 40,
      WindowSizeClass.expanded => 56,
    };
  }

  @override
  AppLayout copyWith({
    double? mediumMinWidth,
    double? expandedMinWidth,
    double? shortHeightMax,
    double? phoneColumnWidth,
    double? designHeight,
    double? minFrameScale,
    double? maxFrameScale,
    double? contentColumnMaxWidth,
    double? readingMaxWidth,
    double? masterPaneWidth,
    double? paneGutter,
    double? sheetMaxWidth,
    double? sidePanelWidth,
  }) {
    return AppLayout(
      mediumMinWidth: mediumMinWidth ?? this.mediumMinWidth,
      expandedMinWidth: expandedMinWidth ?? this.expandedMinWidth,
      shortHeightMax: shortHeightMax ?? this.shortHeightMax,
      phoneColumnWidth: phoneColumnWidth ?? this.phoneColumnWidth,
      designHeight: designHeight ?? this.designHeight,
      minFrameScale: minFrameScale ?? this.minFrameScale,
      maxFrameScale: maxFrameScale ?? this.maxFrameScale,
      contentColumnMaxWidth:
          contentColumnMaxWidth ?? this.contentColumnMaxWidth,
      readingMaxWidth: readingMaxWidth ?? this.readingMaxWidth,
      masterPaneWidth: masterPaneWidth ?? this.masterPaneWidth,
      paneGutter: paneGutter ?? this.paneGutter,
      sheetMaxWidth: sheetMaxWidth ?? this.sheetMaxWidth,
      sidePanelWidth: sidePanelWidth ?? this.sidePanelWidth,
    );
  }

  /// 레이아웃 토큰은 애니메이션하지 않는다
  @override
  AppLayout lerp(ThemeExtension<AppLayout>? other, double t) => this;
}
