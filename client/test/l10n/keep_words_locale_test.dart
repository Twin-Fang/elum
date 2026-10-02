import 'dart:io';

import 'package:elum/core/text/keep_words.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/features/notice/domain/app_notice.dart';
import 'package:elum/features/notice/presentation/widgets/notice_slide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';

void main() {
  useFigmaViewport();

  const wj = '⁠';
  const zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');

  group('keepWords — 한국어만 어절 표시를 넣는다', () {
    test('locale 이 null 이면 한국어다 — 기존 호출이 그대로 동작한다', () {
      expect(keepWords('방침에서'), '방$wj침$wj에$wj서');
      expect(keepWords('방침에서'), keepWords('방침에서', locale: const Locale('ko')));
    });

    test('ko 는 표시를 넣는다', () {
      expect(
        keepWords('방침에서', locale: const Locale('ko')),
        '방$wj침$wj에$wj서',
      );
    });

    test('en·es·ja·zh(zh, zh-Hans) 는 원문 그대로다 — 일본어·중국어에 넣으면 줄바꿈이 막힌다', () {
      for (final l in [
        const Locale('en'),
        const Locale('es'),
        const Locale('ja'),
        const Locale('zh'),
        zhHans,
      ]) {
        final out = keepWords('Hello 日本語 방침에서', locale: l);
        expect(out, 'Hello 日本語 방침에서', reason: '$l');
        expect(out, isNot(contains(wj)), reason: '$l');
      }
    });

    test('같은 입력의 ko 결과와 ja 결과는 서로 다르다', () {
      expect(
        keepWords('방침에서', locale: const Locale('ko')),
        isNot(keepWords('方針について', locale: const Locale('ja'))),
      );
      expect(
        keepWords('日本語', locale: const Locale('ko')),
        isNot(keepWords('日本語', locale: const Locale('ja'))),
      );
    });

    test('keepWordsParts 도 같은 규칙이다 — ko 는 조각 경계도 한 어절로 본다', () {
      expect(
        keepWordsParts(['9월', '30일'], locale: const Locale('ko')),
        ['9$wj월', '${wj}3${wj}0$wj일'],
      );
      expect(keepWordsParts(['9월', '30일']), ['9$wj월', '${wj}3${wj}0$wj일']);
      for (final l in [const Locale('ja'), const Locale('en'), const Locale('zh'), zhHans]) {
        expect(keepWordsParts(['9월', '30일'], locale: l), ['9월', '30일'], reason: '$l');
      }
    });

    test('usesWordJoiner', () {
      expect(usesWordJoiner(null), isTrue);
      expect(usesWordJoiner(const Locale('ko')), isTrue);
      expect(usesWordJoiner(const Locale('ja')), isFalse);
      expect(usesWordJoiner(const Locale('en')), isFalse);
      expect(usesWordJoiner(const Locale('es')), isFalse);
      expect(usesWordJoiner(const Locale('zh')), isFalse);
      expect(usesWordJoiner(zhHans), isFalse);
    });
  });

  group('호출처 소스 계약 — 모든 호출이 앱 언어를 넘긴다', () {
    // 주석 안의 호출에 속지 않도록 // 와 /* */ 를 걷어낸다
    String stripComments(String s) => s
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
        .replaceAll(RegExp(r'//.*'), '');

    /// `keepWords(`/`keepWordsParts(` 호출의 괄호 안 전체를 돌려준다(중첩 괄호 포함).
    List<String> callsIn(String src) {
      final calls = <String>[];
      for (final m in RegExp(r'\bkeepWords(?:Parts)?\(').allMatches(src)) {
        var depth = 1;
        var i = m.end;
        while (i < src.length && depth > 0) {
          if (src[i] == '(') depth++;
          if (src[i] == ')') depth--;
          i++;
        }
        calls.add(src.substring(m.end, i - 1));
      }
      return calls;
    }

    final defFile = 'lib/core/text/keep_words.dart'.replaceAll('/', Platform.pathSeparator);
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && f.path != defFile)
        .toList();

    // 카드 제목은 일과 언어를 따른다 — 화면 언어(appLocale)가 아니라 ContentLocale 이 입힌 글자 locale 이다
    const cardTitleLocale = 'locale: DefaultTextStyle.of(context).style.locale';

    test('정의 파일 밖의 호출은 8곳이고 앱 언어(카드 제목은 일과 언어)를 넘긴다', () {
      final all = <String>[];
      final where = <String>[];
      for (final f in sources) {
        final calls = callsIn(stripComments(f.readAsStringSync()));
        all.addAll(calls);
        where.addAll(calls.map((_) => f.path));
      }
      expect(all.length, 8, reason: '호출이 늘면 locale 을 넘기는지 확인하고 이 숫자를 고친다: $where');
      for (var i = 0; i < all.length; i++) {
        expect(
          all[i],
          where[i].endsWith('default_card_art.dart')
              ? contains(cardTitleLocale)
              : contains('locale: context.appLocale'),
          reason: '${where[i]} 의 호출이 언어를 넘기지 않는다 — ja·zh 에서 줄바꿈이 막힌다',
        );
      }
    });

    test('주석 속 호출은 세지 않는다', () {
      expect(callsIn(stripComments('// keepWords(a)\n/* keepWords(b) */\nkeepWords(c)')), ['c']);
    });
  });

  group('팝업 설명', () {
    Future<String> shownMessage(WidgetTester tester, Locale locale) async {
      await pumpWithLocale(
        tester,
        const Scaffold(
          body: Center(
            child: ElumDialogCard<void>(
              title: '제목',
              message: '방침에서 확인해요',
              keepWordsInMessage: true,
            ),
          ),
        ),
        locale: locale,
      );
      // 낭독기에는 원문을 주므로(semanticsLabel) 그것으로 위젯을 찾는다
      final text = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.semanticsLabel == '방침에서 확인해요',
        ),
      );
      expect(text.semanticsLabel, isNot(contains(wj)));
      return text.data!;
    }

    testWidgets('ko 팝업 설명에는 어절 표시가 들어간다 — 지금과 같다', (tester) async {
      expect(await shownMessage(tester, const Locale('ko')), contains(wj));
    });

    testWidgets('ja 팝업 설명에는 표시가 없다', (tester) async {
      expect(await shownMessage(tester, const Locale('ja')), isNot(contains(wj)));
    });
  });

  group('공지 내용', () {
    Future<(String, String)> shown(WidgetTester tester, Locale locale) async {
      const notice = AppNotice(
        id: 'n1',
        revision: 1,
        title: '새 **기능**이 생겼어요',
        body: '자세한 내용은 방침에서 확인해요',
      );
      await pumpWithLocale(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: NoticeContent(
              notice: notice,
              showImage: false,
              imageFor: (_) => throw StateError('그림 없음'),
              onImageError: (_) {},
            ),
          ),
        ),
        locale: locale,
      );
      final title = tester.widget<Text>(find.byKey(const ValueKey('notice-title-n1')));
      final body = tester.widget<Text>(find.byKey(const ValueKey('notice-body-n1')));
      expect(body.semanticsLabel, '자세한 내용은 방침에서 확인해요');
      expect(title.semanticsLabel, '새 기능이 생겼어요');
      return (title.textSpan!.toPlainText(), body.data!);
    }

    testWidgets('ko 제목·본문에는 어절 표시가 들어간다', (tester) async {
      final (title, body) = await shown(tester, const Locale('ko'));
      expect(title, contains(wj));
      expect(body, contains(wj));
    });

    testWidgets('ja 제목·본문에는 표시가 없다 — 원문 그대로', (tester) async {
      final (title, body) = await shown(tester, const Locale('ja'));
      expect(title, '새 기능이 생겼어요');
      expect(body, '자세한 내용은 방침에서 확인해요');
    });
  });
}
