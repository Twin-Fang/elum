import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 어절 단위 줄바꿈 표시(U+2060)를 뺀 글로 [Text]를 찾는다.
///
/// `keepWords` 를 거친 글은 글자 사이마다 보이지 않는 표시가 끼어 있어 `find.text` 로는 못 찾는다.
/// [exact] 가 true 면 전체가 같아야 하고, 아니면 일부만 들어 있어도 찾는다.
Finder findKept(String text, {bool exact = false}) => find.byWidgetPredicate((w) {
  if (w is! Text) return false;
  final data = w.data;
  if (data == null) return false;
  final plain = data.replaceAll('⁠', '');
  return exact ? plain == text : plain.contains(text);
});
