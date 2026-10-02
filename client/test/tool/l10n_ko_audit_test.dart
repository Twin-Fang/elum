import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/l10n_ko_audit.dart';

void main() {
  group('literalsOf — 소스 리터럴의 실제 값', () {
    test('주석과 코드의 글은 뽑지 않는다', () {
      const src = "// 주석 속 문구\n/* 블록 문구 */\nfinal a = 진짜(1);\nText('리터럴');";
      expect(literalsOf(src), ['리터럴']);
    });

    test('붙여 쓴 리터럴과 + 로 이은 리터럴은 하나로 잇는다', () {
      expect(literalsOf("x('가나 '\n  '다라');"), ['가나 다라']);
      expect(literalsOf("x('가나 ' + '다라');"), ['가나 다라']);
      expect(literalsOf("x('가나', '다라');"), ['가나', '다라']);
    });

    test('이스케이프를 해석한다', () {
      expect(literalsOf(r"x('가\n나\t다\\라\'마\$바');"), ["가\n나\t다\\라'마\$바"]);
      expect(literalsOf(r'x("가\"나");'), ['가"나']);
      expect(literalsOf(r"x('A\u{1F600}\x42');"), ['A\u{1F600}B']);
    });

    test('보간은 자리 하나로 본다 — \$x · \${..} · 중첩', () {
      expect(literalsOf(r"x('가$n나${a.b}다${m['k']}라');"), [
        '가\u0001나\u0001다\u0001라',
      ]);
      expect(literalsOf(r"x('$a$b');"), ['\u0001\u0001']);
      // 식별자 뒤 한글은 이름의 일부가 아니다
      expect(literalsOf(r"x('$n명');"), ['\u0001명']);
    });

    test('raw 는 이스케이프·보간을 해석하지 않는다', () {
      expect(literalsOf(r"x(r'a\nb$c');"), [r'a\nb$c']);
    });

    test('삼중 따옴표는 실제 줄바꿈을 값으로 가진다', () {
      expect(literalsOf("x('''가\n나''');"), ['가\n나']);
    });

    test('주석 속 따옴표가 리터럴을 열지 않는다', () {
      expect(literalsOf("// it's\nx('가나');"), ['가나']);
    });
  });

  group('variantsOf — ARB 문구를 대조 값으로', () {
    List<String> canons(String m) => variantsOf(m).map((v) => v.canon).toList();

    test('자리표시자는 자리 하나, 줄바꿈·공백은 그대로', () {
      expect(canons(' 가 {a}나\n\n다 '), [' 가 \u0001나\n\n다 ']);
    });

    test('select 는 분기마다 앞뒤 글을 붙여 펼친다', () {
      expect(canons('{n}{k, select, yes{이} other{가}} 해요'), [
        '\u0001이 해요',
        '\u0001가 해요',
      ]);
    });

    test('plural 의 # 는 자리 하나, plural 밖의 # 는 글자', () {
      expect(canons('{n, plural, =0{없어요} other{# 개}}'), ['없어요', '\u0001 개']);
      expect(canons('번호 #1'), ['번호 #1']);
    });

    test('ICU 따옴표를 푼다', () {
      expect(canons("중괄호 '{'열기 ''끝''"), ["중괄호 {열기 '끝'"]);
      expect(canons("따옴표 '완전히 다른' 문구"), ["따옴표 '완전히 다른' 문구"]);
    });

    test('빈 분기는 건너뛰고 글이 있는 분기만 남긴다', () {
      expect(canons('{w, select, mon{월요일} other{}}'), ['월요일']);
    });

    test('풀 수 없는 문구는 이유와 함께 Unverifiable', () {
      for (final m in [
        '{count, number}', // 지원하지 않는 형식
        '{name}', // 글이 없다
        '', // 빈 문구
        '{a}{b}', // 자리표시자뿐
        '{n, plural, offset:1 other{가}}', // offset
        '{n, plural, other{가나', // 안 닫힘
        '가나}', // 짝 없는 }
        '{n, select, }', // 분기 없음
      ]) {
        expect(() => variantsOf(m), throwsA(isA<Unverifiable>()), reason: m);
      }
    });
  });

  group('auditArb — 리뷰가 거짓 통과를 확인한 입력 전부', () {
    // 기준 소스(3cfec577 의 실제 리터럴 모양). 주석에도 조각을 흩어 둔다.
    final literals = literalsOf(r"""
// 지금은 광고로 크레딧을 받을 수 없어요 / 일과는 만들 수 있어요 / 다음에 / 취소
final a = '지금은 광고로 크레딧을 받을 수 없어요.\n계정 상태를 확인해주세요';
final b = '오늘 $childName${childName.subjectParticle}\n할 일들이에요. 힘내봐요!';
final c = '카드 ${total}장 중 $n번째';
final d = '일과를 마친 뒤 기다리는 것이 있으면 이룸이가 끝까지 해낼 힘이 생겨요.\n'
    '한 달 뒤 선물보다 오늘 바로 줄 수 있는 작은 것이 더 잘 통해요.\n'
    '정하지 않아도 일과는 만들 수 있어요.';
final e = '다음';
final f = '취소';
final g = '다음에 하기';
final h = '정하지 않아도 일과는 만들 수 있어요.';
final i = '이 휴대폰은 누가\n사용하나요?';
final j = '따옴표 \'이것\' 문구';
final k = '지금은 광고로 크레딧을 받을 수 없어요.';
final l = '$name님의 일과가 끝났어요';
final m = '$n카드';
""");
    const l1 = '일과를 마친 뒤 기다리는 것이 있으면 이룸이가 끝까지 해낼 힘이 생겨요.';
    const l2 = '한 달 뒤 선물보다 오늘 바로 줄 수 있는 작은 것이 더 잘 통해요.';
    const l3 = '정하지 않아도 일과는 만들 수 있어요.';
    List<String> run(String message, {Set<String> accepted = const {}}) =>
        auditArb({'k': message}, literals, accepted: accepted).missing;

    // 도구가 아무것도 통과시키지 못하는 상태가 아님을 먼저 보인다.
    final originals = <String>[
      '지금은 광고로 크레딧을 받을 수 없어요.\n계정 상태를 확인해주세요',
      '오늘 {childName}{p}\n할 일들이에요. 힘내봐요!',
      '카드 {total}장 중 {n}번째',
      '$l1\n$l2\n$l3',
      '다음',
      '취소',
      '이 휴대폰은 누가\n사용하나요?',
      "따옴표 '이것' 문구",
      '{name}님의 일과가 끝났어요',
      '{n, plural, =1{{n}카드} other{다음에 하기}}',
    ];
    for (final m in originals) {
      test('원문은 통과한다: ${m.replaceAll('\n', '⏎')}', () {
        expect(run(m), isEmpty);
      });
    }

    // [문구, 설명]. 전부 실패해야 한다.
    final mutants = <String, String>{
      // 1. 줄바꿈 개수·위치
      '지금은 광고로 크레딧을 받을 수 없어요.\n\n계정 상태를 확인해주세요': '빈 줄 추가',
      '\n지금은 광고로 크레딧을 받을 수 없어요.\n계정 상태를 확인해주세요': '앞 개행',
      '지금은 광고로 크레딧을 받을 수 없어요.\n계정 상태를 확인해주세요\n': '뒤 개행',
      '지금은 광고로 크레딧을 받을 수 없어요. 계정 상태를 확인해주세요': '개행→공백',
      '$l1\n$l2\n$l3\n\n': '세 줄 + 뒤 빈 줄',
      '$l1\n\n$l2\n$l3': '세 줄 사이 빈 줄',
      // 2. 둘째 줄 이후의 줄머리
      '오늘 {childName}{p}\n일들이에요. 힘내봐요!': '둘째 줄 `할 ` 삭제',
      '오늘 {childName}{p}\n할 일들이에요 힘내봐요!': '둘째 줄 안쪽 마침표 삭제',
      // 3. 자리표시자 옆 글자
      '{childName}{p}\n할 일들이에요. 힘내봐요!': '`오늘 ` 삭제',
      '오늘{childName}{p}\n할 일들이에요. 힘내봐요!': '공백 삭제',
      '카드 {total}장 중 {n}': '`번째` 삭제',
      '카드 {total}장 중 {n}번': '`째` 삭제',
      '카드 {total}장 {n}번째': '`중` 삭제',
      '{total}장 중 {n}번째': '`카드 ` 삭제',
      '카드 {total} 장 중 {n}번째': '공백 추가',
      // 4. 따옴표 든 문구
      '따옴표 \'완전히 다른\' 문구': '따옴표 든 다른 문구',
      "따옴표 '이것' 문구.": '따옴표 든 문구 + 마침표',
      "따옴표 \"이것\" 문구": '작은→큰따옴표',
      // 이전 라운드
      '지금은 광고로 크레딧을 받을 수 없어요': '끝 마침표 삭제',
      '지금은 광고로 크레딧을 받을 수': '끝 단어 삭제',
      '광고로 크레딧을 받을 수 없어요.': '앞 단어 삭제',
      '일과는 만들 수 있어요': '앞 구절 삭제',
      '정하지 않아도 일과는 만들 수 있어요': '마침표 삭제',
      '다음에': '더 긴 문구',
      '취소 ': '끝 공백',
      ' 취소': '앞 공백',
      '$l2\n$l1\n$l3': '줄 순서 바뀜',
      '$l1\n$l2': '마지막 줄 삭제',
      '$l1\n$l2\n일과는 만들 수 있어요.': '마지막 줄 앞 구절 삭제',
      '$l1\n$l2\n$l3.': '마지막 줄 마침표 추가',
      '{name}님의 일과가 끝났어요.': '자리표시자 문구 끝 마침표 추가',
      '{name}님은 일과가 끝났어요': '조사 바꿈',
      '{name}{x}님의 일과가 끝났어요': '자리표시자 하나 더',
      '님의 일과가 끝났어요': '자리표시자 삭제',
    };
    mutants.forEach((message, name) {
      test('변이 실패: $name', () {
        final missing = run(message);
        expect(missing, isNotEmpty, reason: message);
        expect(missing.single, startsWith('k: "'));
      });
    });

    test('실패 메시지는 어느 키의 어느 문구인지 말한다 (줄바꿈은 \\n 으로)', () {
      expect(run('다음에 \n'), ['k: "다음에 \\n" ← 기준 소스에 이 문구와 같은 문자열 리터럴이 없다']);
    });

    test('ICU: 분기 하나가 단독 리터럴이어도 통과하고, 한 글자 다르면 실패', () {
      final lits = literalsOf(r"x(n == 0 ? '카드가 없어요' : '카드 $n장');");
      List<String> r(String m) => auditArb({'k': m}, lits).missing;
      expect(r('{n, plural, =0{카드가 없어요} other{카드 {n}장}}'), isEmpty);
      expect(r('{n, plural, =0{카드가 없어요.} other{카드 {n}장}}'), hasLength(1));
      expect(r('{n, plural, =0{카드가 없어요} other{카드 {n} 장}}'), hasLength(1));
      expect(r('{n, plural, =0{카드가 없어요} other{카드 #장}}'), isEmpty);
    });

    test('ICU: 앞뒤 글이 있으면 분기마다 전체 문구로 대조한다', () {
      final lits = literalsOf(r"x('오늘 $n개'); y('오늘 없어요');");
      List<String> r(String m) => auditArb({'k': m}, lits).missing;
      expect(r('오늘 {n, plural, =0{없어요} other{{n}개}}'), isEmpty);
      expect(r('내일 {n, plural, =0{없어요} other{{n}개}}'), hasLength(2));
    });

    test('검증 불가 문구는 통과시키지 않고 이유를 말한다', () {
      final r = auditArb({
        'num': '{count, number}',
        'only': '{name}',
        'ok': '다음',
      }, literals);
      expect(r.missing, hasLength(2));
      expect(r.missing[0], startsWith('검증 불가: num, '));
      expect(r.missing[1], startsWith('검증 불가: only, '));
    });

    test('수용 목록: 키 단위(검증 불가)와 문구 단위(소스에 없음)', () {
      expect(
        auditArb(
          {'num': '{count, number}'},
          literals,
          accepted: {'num'},
        ).missing,
        isEmpty,
      );
      expect(run('없는 문구예요', accepted: {'k: "없는 문구예요"'}), isEmpty);
      // 수용한 문구가 바뀌면 다시 실패한다
      expect(run('없는 문구예요.', accepted: {'k: "없는 문구예요"'}), isNotEmpty);
    });

    test('parseAccepted — 사유가 없는 줄은 무시한다', () {
      expect(
        parseAccepted(['a: "가나" # 조사 도우미로 조립', 'b', 'c # ', '', '  d # 이유 ']),
        {'a: "가나"', 'd'},
      );
    });

    test('@ 메타와 문자열이 아닌 값은 건너뛴다', () {
      final r = auditArb({'@x': '없는 문구예요', 'n': 3}, literals);
      expect(r.missing, isEmpty);
      expect(r.checked, 0);
    });
  });

  group('실제 git — 임시 저장소', () {
    late Directory repo;
    late String commit;
    late String arbPath;

    ProcessResult git(List<String> a) =>
        Process.runSync('git', a, workingDirectory: repo.path);

    setUpAll(() {
      repo = Directory.systemTemp.createTempSync('l10n_audit_');
      git(['init', '-q']);
      Directory('${repo.path}/lib').createSync();
      File('${repo.path}/lib/a.dart').writeAsStringSync(
        "// 주석에만 있어요\nText('안녕하세요 반가워요.');\nText('다음에');\n"
        r"Text('$name님\n두 줄');"
        "\n",
      );
      File('${repo.path}/other.txt').writeAsStringSync("'밖에만 있어요'\n");
      git(['add', '.']);
      git([
        '-c',
        'user.email=t@t',
        '-c',
        'user.name=t',
        'commit',
        '-q',
        '-m',
        'base',
      ]);
      commit = (git(['rev-parse', 'HEAD']).stdout as String).trim();
      arbPath = '${repo.path}/ko.arb';
    });

    tearDownAll(() => repo.deleteSync(recursive: true));

    int audit(
      Map<String, String> arb,
      String base,
      StringBuffer out,
      StringBuffer err,
    ) {
      File(arbPath).writeAsStringSync(jsonEncode(arb));
      return runAudit(
        [
          '--base',
          base,
          '--arb',
          arbPath,
          '--accepted',
          '${repo.path}/none.txt',
        ],
        workingDirectory: repo.path,
        out: out,
        err: err,
      );
    }

    test('원문은 종료 코드 0', () {
      final out = StringBuffer();
      expect(
        audit(
          {'a': '안녕하세요 반가워요.', 'b': '다음에', 'c': '{name}님\n두 줄'},
          commit,
          out,
          StringBuffer(),
        ),
        0,
      );
      expect(out.toString(), contains('3개 중 실패 0건'));
    });

    test('한 글자·개행·주석·lib 밖 문구는 종료 코드 1 과 키·문구 메시지', () {
      for (final m in [
        '안녕하세요 반가워요',
        '안녕하세요 반가워요..',
        '다음',
        '주석에만 있어요',
        '밖에만 있어요',
        '다음에\n',
      ]) {
        final out = StringBuffer();
        expect(audit({'a': m}, commit, out, StringBuffer()), 1, reason: m);
        expect(out.toString(), contains('a: "'));
      }
    });

    test('검증 불가 문구만 있어도 0 이 아니다', () {
      final out = StringBuffer();
      expect(audit({'a': '{count, number}'}, commit, out, StringBuffer()), 1);
      expect(out.toString(), contains('검증 불가: a, '));
    });

    test('존재하지 않는 기준 커밋은 종료 코드 2 와 원인 메시지', () {
      final err = StringBuffer();
      expect(
        audit(
          {'a': '다음에'},
          '0123456789abcdef0123456789abcdef01234567',
          StringBuffer(),
          err,
        ),
        2,
      );
      expect(err.toString(), contains('로컬에 없다'));
      expect(err.toString(), contains('git fetch origin'));
    });

    test('저장소가 아닌 곳에서 돌려도 종료 코드 2', () {
      final dir = Directory.systemTemp.createTempSync('l10n_audit_nogit_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/ko.arb').writeAsStringSync('{"a":"다음에"}');
      final err = StringBuffer();
      final code = runAudit(
        [
          '--base',
          commit,
          '--arb',
          '${dir.path}/ko.arb',
          '--accepted',
          '${dir.path}/none.txt',
        ],
        workingDirectory: dir.path,
        out: StringBuffer(),
        err: err,
      );
      expect(code, 2);
      expect(err.toString(), isNotEmpty);
    });

    test('--base 가 없으면 종료 코드 2', () {
      final err = StringBuffer();
      expect(runAudit([], out: StringBuffer(), err: err), 2);
      expect(err.toString(), contains('--base'));
    });

    test('loadBaseLiterals 는 커밋이 없으면 BaseCommitError 를 던진다', () {
      expect(
        () => loadBaseLiterals('deadbeef', workingDirectory: repo.path),
        throwsA(isA<BaseCommitError>()),
      );
    });
  });
}
