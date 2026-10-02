import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_hangul_literals.dart';

void main() {
  List<String> scanLines(String source) => scan('a.dart', source);

  // 줄 번호만 뽑아 위치를 단언한다.
  List<int> hitLines(String source) =>
      scanLines(source).map((h) => int.parse(h.split(':')[1])).toList();

  group('잡아야 하는 것', () {
    test('문자열 안의 한글을 줄 번호와 함께 찾는다', () {
      expect(scanLines("final a = 1;\nfinal t = Text('확인');"), [
        "a.dart:2: final t = Text('확인');",
      ]);
    });

    test('Text 위젯·큰따옴표·const 문자열', () {
      expect(hitLines("Text('안녕')"), [1]);
      expect(hitLines('Text("안녕")'), [1]);
      expect(hitLines("const label = '안녕';"), [1]);
    });

    test('보간 문자열 — 한글이 보간 앞·뒤에 있어도, 보간 안의 문자열도', () {
      expect(hitLines(r"final s = '$n명';"), [1]);
      expect(hitLines(r"final s = '${n}명';"), [1]);
      expect(hitLines(r"final s = '총 ${items.length} 개';"), [1]);
      expect(hitLines(r"final s = '${cond ? '있음' : 'x'}';"), [1]);
    });

    test('여러 줄 문자열은 한글이 있는 줄만 잡는다', () {
      const source =
          "final s = 'abc'\n"
          "    '가나다'\n"
          "    'def';";
      expect(hitLines(source), [2]);
    });

    test('삼중 따옴표 문자열 — 안의 // 와 따옴표도 문자열이다', () {
      const source =
          "final s = '''\n"
          "첫 줄\n"
          "// 주석처럼 보여도 문자열이다 확인\n"
          "it's 'quoted' 끝\n"
          "''';\n"
          "final t = 1;";
      expect(hitLines(source), [2, 3, 4]);
    });

    test('상수·enum 안의 한글 라벨', () {
      const source =
          "enum Mood {\n"
          "  happy('기쁨'),\n"
          "  sad('슬픔');\n"
          "  const Mood(this.label);\n"
          "  final String label;\n"
          "}\n"
          "const kTitles = {'a': '제목'};";
      expect(hitLines(source), [2, 3, 7]);
    });

    test('접근성 semanticsLabel', () {
      expect(hitLines("Semantics(semanticsLabel: '닫기 버튼')"), [1]);
    });

    test('raw 문자열 — 역슬래시·\$ 가 글자 그대로여도 한글을 잡는다', () {
      expect(hitLines(r"final s = r'\$가나';"), [1]);
    });
  });

  group('놔둬야 하는 것', () {
    test('주석은 건너뛴다 — 줄 주석·줄 끝 주석·블록 주석·문서 주석', () {
      const source =
          "// 확인\n"
          "final a = 1; // 확인\n"
          "/* 확인\n"
          "   확인 */\n"
          "/// 확인\n"
          "final b = 2; /* 확인 */";
      expect(scanLines(source), isEmpty);
    });

    test('주석 안의 따옴표를 문자열 시작으로 오해하지 않는다', () {
      // 잘못 오해하면 다음 줄의 진짜 문자열이 가려지거나 주석 한글이 잡힌다
      const source =
          "final a = 1; // don't 확인\n"
          "/* it's 확인 */ final b = 2;\n"
          "// 'quoted 확인\n"
          "final t = Text('진짜');";
      expect(hitLines(source), [4]);
    });

    test('한 줄에 문자열과 주석이 같이 있으면 문자열만 본다', () {
      expect(hitLines("final a = '가나'; // 주석"), [1]);
      expect(scanLines("final a = 'abc'; // 가나 주석"), isEmpty);
    });

    test('문자열 안의 // 는 주석이 아니다', () {
      expect(hitLines("final u = 'http://가나다';"), [1]);
      expect(hitLines("final u = 'http://a.com/확인';"), [1]);
    });

    test('블록 주석 뒤 같은 줄의 문자열은 본다', () {
      expect(hitLines("/* 설명 */ final a = '확인';"), [1]);
    });

    test('식별자·타입에는 한글이 없으므로 따옴표 없는 줄은 놔둔다', () {
      expect(scanLines("final x = foo(1, 2);"), isEmpty);
    });

    test('로그·예외·정규식·assert·키는 사용자에게 보이지 않으므로 건너뛴다', () {
      const source =
          "AppLogger.error('실패');\n"
          "debugPrint('실패');\n"
          "throw StateError('실패');\n"
          "throw const FormatException('실패');\n"
          "final r = RegExp(r'[가-힣]');\n"
          "assert(x, '실패');\n"
          "const k = Key('광고 틀');";
      expect(scanLines(source), isEmpty);
    });

    test('줄 끝 l10n-ignore 표식은 건너뛴다', () {
      expect(scanLines("x('실패'); // l10n-ignore: 로그"), isEmpty);
    });

    test('표식은 그 줄만 가린다 — 다음 줄은 계속 잡는다', () {
      const source =
          "x('실패'); // l10n-ignore: 로그\n"
          "y('실패');";
      expect(hitLines(source), [2]);
    });
  });

  group('경계', () {
    test('이스케이프된 따옴표는 문자열을 끝내지 않는다', () {
      expect(hitLines(r"final s = 'it\'s 확인';"), [1]);
      expect(hitLines(r'final s = "say \"확인\"";'), [1]);
      // 이스케이프 뒤에 진짜로 닫히고 나면 // 는 주석이다
      expect(scanLines(r"final s = 'a\''; // 확인"), isEmpty);
    });

    test('이스케이프된 역슬래시 뒤의 따옴표는 문자열을 끝낸다', () {
      expect(scanLines(r"final s = 'a\\'; // 확인"), isEmpty);
    });

    test('이모지와 한글이 섞여도 잡는다, 이모지만 있으면 놔둔다', () {
      expect(hitLines("Text('🎉 완료')"), [1]);
      expect(hitLines("Text('완료 🎉')"), [1]);
      expect(scanLines("Text('🎉')"), isEmpty);
    });

    test('완성형 음절(U+AC00–D7A3)만 한글로 본다 — 자모·호환 자모 단독은 놔둔다', () {
      expect(scanLines("Text('ㅋㅋ')"), isEmpty); // U+314B 호환 자모
      expect(scanLines("Text('가')"), isEmpty); // U+1100 조합용 자모
      expect(hitLines("Text('가')"), [1]); // 가, 경계 시작
      expect(hitLines("Text('힣')"), [1]); // 힣, 경계 끝
      expect(scanLines("Text('꯿힤')"), isEmpty); // 바로 바깥
    });

    test('줄 번호는 여러 줄 문자열·블록 주석을 지난 뒤에도 정확하다', () {
      const source =
          "/* a\n"
          "b */\n"
          "final s = '''x\n"
          "y''';\n"
          "final t = '가';";
      expect(hitLines(source), [5]);
    });

    test('보간 안의 중괄호가 중첩돼도 문자열 상태가 어긋나지 않는다', () {
      const source =
          r"final s = '${{'a': 1}['a']}'; // 확인"
          "\n"
          "final t = '가';";
      expect(hitLines(source), [2]);
    });
  });
}
