import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 글이 **띄어쓰기에서만** 줄을 바꿨는지 본다 (#393 S4·S5).
///
/// Flutter 는 한글을 글자 단위로 끊는다 — `이룸이 / 가`, `있나 / 요?`. 줄마다 끝난
/// 자리의 앞이나 뒤가 공백·줄바꿈이 아니면 낱말 가운데서 끊긴 것이다.
///
/// 줄이 몇 개인지와 상관없이 본다 — 한 줄이면 아무것도 끊기지 않았으니 통과한다.
void expectBreaksOnlyAtSpaces(WidgetTester tester, Finder text) {
  // semanticsLabel 을 준 Text 는 Semantics 로 한 겹 싸인다 — 안쪽 RichText 를 잡는다.
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText), matchRoot: true),
  );
  // RenderParagraph 는 줄 경계를 내주지 않는다. 같은 글·배율·폭으로 다시 잰다.
  final painter = TextPainter(
    text: paragraph.text,
    textAlign: paragraph.textAlign,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    locale: paragraph.locale,
  )..layout(maxWidth: paragraph.constraints.maxWidth);
  addTearDown(painter.dispose);
  final plain = paragraph.text.toPlainText();
  bool isSpace(int i) => i >= 0 && i < plain.length && plain[i].trim().isEmpty;

  final broken = <String>[];
  var offset = 0;
  while (offset < plain.length) {
    final line = painter.getLineBoundary(TextPosition(offset: offset));
    final end = line.end;
    if (end <= offset) {
      offset++;
      continue;
    }
    if (end < plain.length && !isSpace(end - 1) && !isSpace(end)) {
      final visible = plain.replaceAll('⁠', '');
      final at = plain.substring(0, end).replaceAll('⁠', '').length;
      broken.add('${visible.substring(0, at)} / ${visible.substring(at)}');
    }
    offset = end;
  }
  expect(broken, isEmpty, reason: '낱말 가운데서 줄이 바뀌었다: $broken');
}
