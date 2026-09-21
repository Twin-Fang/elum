import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// 특정 에셋 경로를 쓰는 SvgPicture를 찾는다.
///
/// Figma 도형을 Container로 직접 그리다 형태가 어긋나는 사고를 막기 위해,
/// "에셋으로 렌더링되는가"를 테스트가 직접 확인한다.
Finder svgWithAsset(String assetPath) {
  return find.byWidgetPredicate((widget) {
    if (widget is! SvgPicture) return false;
    final loader = widget.bytesLoader;
    return loader is SvgAssetLoader && loader.assetName == assetPath;
  });
}

/// `Image.asset(path)` 로 그려진 위젯을 찾는다.
///
/// 블러·안쪽 그림자가 들어간 그림은 SVG로 둘 수 없어 PNG를 쓴다 —
/// flutter_svg가 `filter`를 통째로 버리기 때문이다. 그런 에셋은 이 finder로
/// 검증한다 (`svgWithAsset`은 SVG 전용이라 잡지 못한다).
Finder imageWithAsset(String assetPath) => find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == assetPath,
    );
