import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// [finder] 글이 **제약 없이 제 모양대로** 차지하는 높이를 잰다.
///
/// `tester.getRect(find.text(..))` 는 쓰지 않는다. `RenderParagraph` 는 크기를 부모 제약으로
/// clamp 하므로 글이 몇 줄이 되든 상자 높이를 못 넘는다 - 넘친 글은 그려지기만 상자 밖에 그려지고
/// rect 는 안 변한다. 그래서 같은 글·글꼴·배율·폭 제약으로 `TextPainter` 를 다시 배치해 잰다.
double textNaturalHeight(WidgetTester tester, Finder finder) =>
    _measure(tester, finder).height;

({double height, bool exceededMaxLines}) _measure(
  WidgetTester tester,
  Finder finder,
) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  // 글이 실제로 받은 최대 폭. 같은 폭으로 배치해야 같은 줄바꿈이 나온다.
  final maxWidth = paragraph.constraints.maxWidth;
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textAlign: paragraph.textAlign,
    textScaler: paragraph.textScaler,
    maxLines: paragraph.maxLines,
    locale: paragraph.locale,
    strutStyle: paragraph.strutStyle,
    textWidthBasis: paragraph.textWidthBasis,
    textHeightBehavior: paragraph.textHeightBehavior,
  )..layout(maxWidth: maxWidth);
  final result = (
    height: painter.height,
    exceededMaxLines: painter.didExceedMaxLines,
  );
  painter.dispose();
  return result;
}

/// [finder] 글의 자연 높이가 [maxHeight] 안에 들어가는지 단언한다.
///
/// [maxHeight] 는 **위젯 구조에서 아는 허용 높이**(예: 고정 높이 버튼의 `getSize`)를 준다.
/// `maxLines` 로 잘리는 글(`didExceedMaxLines`)도 넘친 것으로 본다.
void expectTextFits(
  WidgetTester tester,
  Finder finder, {
  required double maxHeight,
  String? label,
}) {
  final m = _measure(tester, finder);
  final name = label ?? finder.toString();
  expect(
    m.height,
    lessThanOrEqualTo(maxHeight + 0.01),
    reason: '$name: 글 자연 높이 ${m.height.toStringAsFixed(1)} 가 허용 높이 $maxHeight 를 넘는다',
  );
  expect(m.exceededMaxLines, isFalse, reason: '$name: maxLines 로 글이 잘린다');
}
