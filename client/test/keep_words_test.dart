import 'package:elum/core/text/keep_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 어절 단위 줄바꿈 (이슈 #390 · #385 A).
///
/// 앱은 한글을 **글자 단위**로 끊는다 — "자세한 내용은 방 / 침에서". 관리자 미리보기는
/// 어절 단위(`keep-all`)라 관리자가 본 줄과 보호자가 본 줄이 달랐다. 공지 팝업만
/// 어절 단위로 바꾸고, 미리보기(`notice-preview.js` 의 `keepWords`)도 **같은 규칙**을 쓴다.
void main() {
  const wj = '\u2060';

  group('keepWords — 띄어쓰기 사이에만 끊을 자리를 남긴다', () {
    test('붙은 글자 사이에 끊지 말라는 표시를 넣는다', () {
      expect(keepWords('방침에서'), '방$wj침$wj에$wj서');
    });



    test('이모지 한 덩어리 안에는 넣지 않는다 — 넣으면 그림이 갈라진다', () {
      const family = '👨‍👩‍👧';
      expect(keepWords('a$family'), 'a$wj$family');
    });

  });


  group('실제로 그려 보면', () {
    // 폭 260 에 16 글자 크기 — 공지 본문과 같은 조건에서 줄을 센다
    List<String> lines(WidgetTester tester, String text, double width) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(fontFamily: 'Pretendard', fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      final out = <String>[];
      var offset = 0;
      while (offset < text.length) {
        final range = painter.getLineBoundary(TextPosition(offset: offset));
        if (range.end <= offset) {
          offset++;
          continue;
        }
        out.add(text.substring(offset, range.end).replaceAll(wj, '').trim());
        offset = range.end;
      }
      painter.dispose();
      return out;
    }

    testWidgets('어절 가운데서 끊지 않는다 — 운영 실측 "방 / 침에서"', (tester) async {
      const body = '카드 그림을 만드는 업체가 하나 늘어요. 자세한 내용은 방침에서 확인할 수 있어요.';
      // 글자 단위로는 어느 어절이든 가운데서 끊길 수 있다. 어절 단위면 줄 끝이 늘 띄어쓰기다.
      final words = body.split(' ');
      bool splitsAWord(List<String> ls) =>
          ls.any((l) => l.split(' ').any((p) => !words.contains(p)));
      // 이 테스트가 헛돌지 않는지 — 표시 없이 그리면 실제로 어절이 잘린다
      expect(
        [
          200.0,
          230.0,
          260.0,
          294.0,
        ].any((w) => splitsAWord(lines(tester, body, w))),
        isTrue,
      );
      for (final width in [200.0, 230.0, 260.0, 294.0]) {
        final kept = lines(tester, keepWords(body), width);
        for (final line in kept) {
          for (final piece in line.split(' ')) {
            expect(
              words,
              contains(piece),
              reason: '폭 $width 에서 "$piece" 로 잘렸다',
            );
          }
        }
      }
    });

    testWidgets('한 어절이 줄보다 길면 그때만 글자에서 끊는다 — 넘치지 않는다', (tester) async {
      final long = '가' * 60;
      final kept = lines(tester, keepWords(long), 200);
      expect(kept.length, greaterThan(1));
      expect(kept.join(), long);
    });

  });
}
