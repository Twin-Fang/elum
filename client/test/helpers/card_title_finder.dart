import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 카드 제목 글자를 찾는다.
///
/// 그림이 없는 이룸이 카드(#458)는 제목이 그림 자리로 올라가는데, 큰 글자에서 어절이
/// 갈라지지 않게 띄어쓰기에서만 줄바꿈하려고 끊김 방지 표시(U+2060)가 들어간다 — 그래서
/// `find.text(제목)`이 못 찾는다. 원문은 `semanticsLabel`(낭독 이름)에 있다.
Finder cardTitle(String title) => find.byWidgetPredicate(
  (w) => w is Text && (w.data == title || w.semanticsLabel == title),
);
