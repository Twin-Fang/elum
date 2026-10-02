import 'package:flutter/widgets.dart';

/// 끊지 말라는 표시 (U+2060 WORD JOINER). 폭이 0 이라 보이지 않는다.
const _joiner = '\u2060';

bool _isSpace(String ch) => ch.trim().isEmpty;

/// 끊지 말라는 표시를 넣는 언어인가 — **한국어만** 넣는다.
///
/// 한국어는 띄어쓰기가 있는데도 글자 단위로 끊겨서 표시가 필요하다. 영어·스페인어는 띄어쓰기에서만
/// 끊기고, 일본어·중국어는 띄어쓰기가 없어 표시를 넣으면 **줄바꿈이 아예 막힌다**.
/// [locale] 이 null 이면 한국어로 본다(언어를 모르는 기존 호출·테스트와 같다).
///
/// 관리자 미리보기(`notice-preview.js`)의 같은 함수도 이 규칙을 따라야 한다.
bool usesWordJoiner(Locale? locale) =>
    locale == null || locale.languageCode == 'ko';

/// 글에 한글 음절이 하나라도 있는가.
///
/// 번역 전에는 영어·일본어 휴대폰에서도 화면 글이 한국어다. 언어 설정만 보면 그 한국어가 글자
/// 단위로 끊기므로 글 자체도 함께 본다.
bool _hasHangul(String text) {
  for (final unit in text.runes) {
    if (unit >= 0xAC00 && unit <= 0xD7A3) return true;
  }
  return false;
}

/// 한글을 **어절 단위로** 줄바꿈하게 만든다 (이슈 #390 · #385 A).
///
/// Flutter 는 한글을 글자 단위로 끊는다 — "자세한 내용은 방 / 침에서". CSS 의
/// `word-break: keep-all` 같은 설정이 없어서, 붙어 있는 글자 사이마다 끊지 말라는
/// 표시를 넣어 **띄어쓰기에서만** 끊기게 한다. 한 어절이 줄보다 길면 그때는
/// 엔진이 글자에서 끊는다(넘치지 않는다).
///
/// **정해 둔 곳에만 쓴다** — 공지 팝업(#390), 보상 도움말 팝업·추가 질문 제목(#393
/// S4·S5). 앱의 다른 화면은 시안 대조가 글자 단위 줄에 맞춰져 있어 앱 전체 규칙으로
/// 바꾸지 않았다.
/// 관리자 미리보기(`notice-preview.js` 의 `keepWords`)가 **같은 규칙**으로 표시를
/// 넣는다 — 한쪽만 바꾸면 관리자가 본 줄과 보호자가 본 줄이 다시 달라진다.
///
/// [locale] 이 한국어가 아니어도 글에 한글이 있으면 같은 규칙을 건다. 한글이 없는 글은
/// 원문을 그대로 돌려준다 ([usesWordJoiner]).
/// 화면 낭독기에 표시가 섞이지 않게, 그리는 쪽은 원문을 `semanticsLabel` 로 준다.
String keepWords(String text, {Locale? locale}) =>
    keepWordsParts([text], locale: locale).single;

/// [keepWords] 를 여러 조각에 걸쳐 한다. 강조(`**…**`)로 나뉜 제목처럼 한 줄 글이
/// 여러 조각일 때, **조각 경계도** 붙어 있으면 한 어절로 본다 — "9월 30일"+"에".
List<String> keepWordsParts(List<String> parts, {Locale? locale}) {
  // 언어가 한국어이거나 글에 한글이 있을 때만 건다 (번역 전 한국어 폴백 보호)
  if (!usesWordJoiner(locale) && !parts.any(_hasHangul)) return List.of(parts);

  final out = <String>[];
  String? prev;
  for (final part in parts) {
    final buffer = StringBuffer();
    // 이모지처럼 여러 코드 포인트가 한 글자인 것은 통째로 다룬다 — 안에 넣으면 그림이 갈라진다
    for (final ch in part.characters) {
      if (prev != null && !_isSpace(prev) && !_isSpace(ch)) {
        buffer.write(_joiner);
      }
      buffer.write(ch);
      prev = ch;
    }
    out.add(buffer.toString());
  }
  return out;
}
