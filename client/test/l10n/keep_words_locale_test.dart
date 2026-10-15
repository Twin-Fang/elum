
import 'package:elum/core/text/keep_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';

void main() {
  useFigmaViewport();

  const wj = '⁠';
  const zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');

  group('keepWords — 한국어만 어절 표시를 넣는다', () {
    test('ko 는 표시를 넣는다', () {
      expect(keepWords('방침에서', locale: const Locale('ko')), '방$wj침$wj에$wj서');
    });

    test(
      'en·es·ja·zh(zh, zh-Hans) 는 한글이 없으면 원문 그대로다 — 일본어·중국어에 넣으면 줄바꿈이 막힌다',
      () {
        for (final l in [
          const Locale('en'),
          const Locale('es'),
          const Locale('ja'),
          const Locale('zh'),
          zhHans,
        ]) {
          final out = keepWords('Hello 日本語', locale: l);
          expect(out, 'Hello 日本語', reason: '$l');
          expect(out, isNot(contains(wj)), reason: '$l');
        }
      },
    );

  });

  group('keepWords — 글자에 한글이 있으면 언어와 무관하게 어절 표시를 넣는다', () {
    // 번역 전에는 영어·일본어 OS 에서도 화면 글이 한국어라 끊김을 막아야 한다
    test('ja 의 한글 없는 일본어 문구에는 표시가 없다', () {
      expect(keepWords('方針について', locale: const Locale('ja')), '方針について');
    });

    test('ja 여도 번역 전 한국어 문구에는 표시가 있다', () {
      expect(keepWords('방침에서', locale: const Locale('ja')), '방$wj침$wj에$wj서');
    });

  });


}
