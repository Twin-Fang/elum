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
