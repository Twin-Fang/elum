import 'dart:convert';
import 'dart:io';

import 'package:elum/features/link/domain/link_code.dart';
import 'package:elum/features/profile/domain/invite_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// 초대 링크 안내 페이지 (#365) — 앱이 없는 휴대폰이 링크를 누르면 닿는 곳.
///
/// 페이지 원본은 `docs/public-pages/invite/index.html` 이고, 게시는 `gh-pages` 브랜치의 `invite/index.html`
/// 로 복사해서 한다. 이 테스트는 **페이지가 코드를 어디로도 보내지 않는다는 것**과 **앱의 코드 규칙과 같은
/// 규칙을 쓴다는 것**을 고정한다. 페이지 쪽 규칙이 앱과 어긋나면 안내 페이지가 보여 준 코드를 앱이 거절한다.
void main() {
  final file = File('../docs/public-pages/invite/index.html');
  final html = file.readAsStringSync();

  /// `<script>…</script>` 본문 — 주석 속 낱말을 코드로 오인하지 않게 주석을 걷는다.
  final script = RegExp(
    r'<script>(.*?)</script>',
    dotAll: true,
  ).firstMatch(html)!.group(1)!;
  final scriptCode = script
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');

  group('코드를 어디로도 보내지 않는다', () {
    test('네트워크 호출이 없다', () {
      for (final call in [
        'fetch(',
        'XMLHttpRequest',
        'sendBeacon',
        'WebSocket',
        'new Image',
        'EventSource',
        'importScripts',
      ]) {
        expect(scriptCode, isNot(contains(call)), reason: call);
      }
    });

    test('외부 스크립트·분석 도구가 없다', () {
      expect(html, isNot(contains('<script src')));
      expect(html, isNot(matches(RegExp(r'google-analytics|gtag|googletagmanager|clarity|hotjar', caseSensitive: false))));
    });

    test('외부 글꼴·스타일을 부르지 않는다 — 페이지가 여는 모든 요청이 같은 사이트 안이다', () {
      expect(html, isNot(contains('cdn.jsdelivr.net')));
      expect(html, isNot(matches(RegExp(r'<link[^>]+rel="stylesheet"'))));
      expect(html, isNot(matches(RegExp(r'<link[^>]+rel="preconnect"'))));
    });

    test('검색에 잡히지 않고 리퍼러를 보내지 않는다', () {
      expect(html, contains('name="robots" content="noindex'));
      expect(html, contains('name="referrer" content="no-referrer"'));
    });

    test('코드를 저장하지 않는다 (쿠키·저장소)', () {
      for (final api in ['localStorage', 'sessionStorage', 'document.cookie', 'indexedDB']) {
        expect(scriptCode, isNot(contains(api)), reason: api);
      }
    });
  });

  group('앱과 같은 규칙을 쓴다', () {
    test('코드 모양 정규식이 앱의 LinkCode.alphabet 과 정확히 같은 집합이다', () {
      final m = RegExp(r'var SHAPE = /\^\[([^\]]+)\]\{6\}\$/;').firstMatch(script);
      expect(m, isNotNull, reason: 'SHAPE 정규식을 찾지 못했다');
      final shape = RegExp('^[${m!.group(1)}]\$');

      const all = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      for (final ch in all.split('')) {
        expect(
          shape.hasMatch(ch),
          LinkCode.alphabet.contains(ch),
          reason: '글자 $ch — 페이지와 앱의 허용 여부가 어긋났다',
        );
      }
    });

    test('앱 주소 모양이 InviteLink.appUrl 과 같다', () {
      final m = RegExp(r"var APP_URL = '([^']+)';").firstMatch(script);
      expect(m, isNotNull);
      expect('${m!.group(1)}A7K3M9', InviteLink.appUrl('A7K3M9'));
    });

    test('이 페이지 주소가 앱이 만드는 공유 링크의 기준 주소와 같은 자리다', () {
      // gh-pages 의 invite/index.html → https://twin-fang.github.io/elum/invite/
      expect(InviteLink.webBase, 'https://twin-fang.github.io/elum/invite/');
    });

    test('스토어 주소가 앱에 들어 있는 값과 같다', () {
      expect(html, contains('https://play.google.com/store/apps/details?id=kr.twinfang.elum'));
      expect(html, contains('https://apps.apple.com/kr/app/id6792970508'));
    });
  });

  group('용어 규칙', () {
    // 사용자에게 보이는 글 — 태그와 스크립트를 걷고 읽는다
    final visible = html
        .replaceAll(RegExp(r'<script>.*?</script>', dotAll: true), '')
        .replaceAll(RegExp(r'<style>.*?</style>', dotAll: true), '')
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

    test('이룸이·초대 코드·휴대폰을 쓰고 아이·연결 암호·기기는 쓰지 않는다', () {
      expect(visible, contains('이룸이'));
      expect(visible, contains('초대 코드'));
      for (final banned in ['아이', '아동', '연결 암호', '기기']) {
        expect(visible, isNot(contains(banned)), reason: banned);
      }
    });

    test('10분 만료를 알린다', () {
      expect(visible, contains('10분'));
    });
  });

  group('페이지의 코드 해석이 앱과 같은 답을 낸다 (node 가 있을 때)', () {
    final hasNode = Process.runSync('which', ['node']).exitCode == 0;

    // [검색(?…), 조각(#…)] — 같은 입력을 앱 해석기에도 넣어 본다
    const cases = <List<String>>[
      ['', '#code=A7K3M9'],
      ['?code=A7K3M9', ''],
      ['?code=a7k-3m9', ''],
      ['', '#code=A7K%203M9'],
      ['', '#code=A7K+3M9'],
      ['?CODE=A7K3M9', ''],
      ['?utm=x&code=A7K3M9', ''],
      ['?code=A7K3M9', '#code=B2C4D6'],
      ['?code=A7K%25203M9', ''],
      ['?code=A7K%2525203M9', ''],
      ['?code=BAD&code=A7K3M9', ''],
      ['?code=', ''],
      ['', ''],
      ['?c=A7K3M9', ''],
      ['?code=A0K3M9', ''],
      ['?code=A7K3M', ''],
      ['?code=A7K3M9X', ''],
      ['?code=%', ''],
      ['?code=%E0%A4%A', ''],
      ['?code=%ZZ', ''],
      ['?code=%EA%B0%80%EB%82%98%EB%8B%A4%EB%9D%BC%EB%A7%88%EB%B0%94', ''],
    ];

    test('같은 입력에 같은 코드(또는 같은 거절)를 낸다', () {
      final driver = [
        'const fs=require("fs");',
        'const html=fs.readFileSync(process.argv[1],"utf8");',
        r'const src=/<script>([\s\S]*?)<\/script>/.exec(html)[1];',
        'const m={exports:{}}; new Function("module", src)(m);',
        'const cases=JSON.parse(process.argv[2]);',
        'console.log(JSON.stringify(cases.map(c=>m.exports.parseCode(c[0],c[1]))));',
      ].join('\n');
      final result = Process.runSync(
        'node',
        ['-e', driver, file.path, jsonEncode(cases)],
        stdoutEncoding: utf8,
      );
      expect(result.exitCode, 0, reason: '${result.stderr}');

      final fromPage = (jsonDecode((result.stdout as String).trim()) as List).cast<String?>();
      final fromApp = [
        for (final c in cases)
          InviteLink.parse('https://twin-fang.github.io/elum/invite/${c[0]}${c[1]}')?.code,
      ];
      for (var i = 0; i < cases.length; i++) {
        expect(fromPage[i], fromApp[i], reason: '입력 ${cases[i]} — 페이지와 앱의 답이 다르다');
      }
      // 시험이 비어 있지 않은지 — 맞는 코드가 실제로 나오는 줄이 있어야 한다
      expect(fromPage.whereType<String>(), isNotEmpty);
    }, skip: hasNode ? false : 'node 가 없어 건너뜀');
  });
}
