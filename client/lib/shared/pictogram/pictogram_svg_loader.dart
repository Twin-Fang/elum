import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/assets/app_assets.dart';
import 'svg_style_inliner.dart';

/// 픽토그램 SVG 를 읽는 로더 (#469).
///
/// 번들의 원본을 그대로 읽되, flutter_svg 가 못 읽는 `<style>` 클래스 색만 메모리에서
/// 속성으로 풀어 넘긴다([inlineSvgClassStyles]). 풀이는 SVG 를 파싱하는 격리(isolate) 안에서
/// 돌아 화면 스레드를 막지 않는다. 결과는 flutter_svg 캐시에 id 별로 한 번만 만든다.
class PictogramSvgLoader extends SvgLoader<String> {
  const PictogramSvgLoader(this.id, {this.bundle});

  final String id;

  /// 테스트가 끼워 넣는 번들. 보통은 화면의 기본 번들을 쓴다.
  final AssetBundle? bundle;

  @override
  Future<String?> prepareMessage(BuildContext? context) {
    final b = bundle ?? (context != null ? DefaultAssetBundle.of(context) : rootBundle);
    return b.loadString(AppAssets.pictogram(id));
  }

  @override
  String provideSvg(String? message) => inlineSvgClassStyles(message ?? '');

  @override
  int get hashCode => Object.hash(id, bundle);

  @override
  bool operator ==(Object other) =>
      other is PictogramSvgLoader && other.id == id && other.bundle == bundle;
}
