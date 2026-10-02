import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/l10n_ko_audit.dart';

void main() {
  group('fragmentsOf', () {
    test('줄바꿈을 기준으로 조각낸다', () {
      expect(fragmentsOf('이 휴대폰은 누가\n사용하나요?'), ['이 휴대폰은 누가', '사용하나요?']);
    });

    test('자리표시자와 ICU 가지 이름을 걷어낸다 — 공백은 자르지 않는다', () {
      expect(
        fragmentsOf(
          '{name}{batchim, select, yes{이} other{가}} 할 일을 해내서\n루루가 선물을 가져왔다고 해요',
        ),
        [' 할 일을 해내서', '루루가 선물을 가져왔다고 해요'],
      );
      expect(fragmentsOf('{weekday, select, mon{월} tue{화} other{}}'), isEmpty);
    });

    test('한 글자 조각은 버린다 (문구 전체일 때만 남는다)', () {
      expect(fragmentsOf('{count, plural, other{{count}개}}'), isEmpty);
      expect(fragmentsOf('저'), ['저']);
    });

    test('소스 표기와 달라지는 따옴표·역슬래시가 든 조각은 버린다', () {
      expect(fragmentsOf("it's 좋아요"), isEmpty);
    });

    test('자리표시자 앞뒤 한글을 각각 조각으로 나눈다', () {
      expect(fragmentsOf('오늘 {name}님의 일과가 끝났어요'), ['오늘 ', '님의 일과가 끝났어요']);
      expect(fragmentsOf('{a}와 {b}를 함께 해요'), ['를 함께 해요']);
    });

    test('plural 의 각 가지 문구를 따로 조각낸다', () {
      expect(
        fragmentsOf('{n, plural, =0{카드가 없어요} =1{카드 한 장} other{카드 {n}장}}'),
        ['카드가 없어요', '카드 한 장', '카드 '],
      );
    });

    test('조각 앞뒤 공백은 그대로 둔다', () {
      expect(fragmentsOf('  가나다  \n  라마바  '), ['  가나다  ', '  라마바  ']);
    });

    test('시작·끝 표시 — 앞뒤에 자리표시자가 없을 때만 선다', () {
      final ps = piecesOf('{n}번째 일과를 해요');
      expect(ps.single.atStart, isFalse);
      expect(ps.single.atEnd, isTrue);
      final whole = piecesOf('일과를 해요').single;
      expect(whole.atStart && whole.atEnd, isTrue);
    });
  });

  group('chainsOf — 소스의 문자열 리터럴만 뽑는다', () {
    test('주석과 코드의 글은 뽑지 않는다', () {
      const src = "// 주석 속 문구\n/* 블록 문구 */\nfinal a = 진짜(1);\nText('리터럴');";
      expect(chainsOf(src), ['리터럴']);
    });

    test('붙여 쓴 리터럴은 하나로 묶는다', () {
      expect(chainsOf("x('가나 '\n  '다라');"), ['가나 다라']);
      expect(chainsOf("x('가나', '다라');"), ['가나', '다라']);
    });

    test('이스케이프·보간은 소스 표기 그대로 남긴다', () {
      expect(chainsOf(r"x('가\n나 $name ${a['b']}');"), [
        r"가\n나 $name ${a['b']}",
      ]);
    });

    test('주석 속 따옴표가 리터럴을 열지 않는다', () {
      expect(chainsOf("// it's\nx('가나');"), ['가나']);
    });
  });

  group('auditArb', () {
    // 기준 소스(3cfec577 의 흉내). 주석과 코드에도 같은 글의 조각을 일부러 흩어 둔다 —
    // 예전 방식(소스 어디든 부분 문자열)이면 이 조각들 때문에 거짓 통과한다.
    final chains = chainsOf(r"""
// 지금은 광고로 크레딧을 받을 수 없어요 / 일과는 만들 수 있어요 / 다음에
final a = '지금은 광고로 크레딧을 받을 수 없어요.';
final b = '정하지 않아도 일과는 만들 수 있어요.';
final c = '다음';
final d = '취소';
final e = '이 휴대폰은 누가\n사용하나요?';
final f = '$name님의 일과가 끝났어요';
final g = '오늘 $name님의 $tail 하루';
final h = '다음에 하기';
void k() { 지금은광고로(); /* 취소 다음 */ }
""");
    Map<String, dynamic> arb(String message) => {'k': message};
    List<String> run(String message) => auditArb(arb(message), chains).missing;

    test('원본 그대로는 통과한다 (평문·줄바꿈·보간)', () {
      for (final m in [
        '지금은 광고로 크레딧을 받을 수 없어요.',
        '정하지 않아도 일과는 만들 수 있어요.',
        '다음',
        '취소',
        '이 휴대폰은 누가\n사용하나요?',
        '{name}님의 일과가 끝났어요',
        '오늘 {name}님의 {tail} 하루',
      ]) {
        expect(run(m), isEmpty, reason: m);
      }
    });

    // 리뷰가 실제로 거짓 통과를 확인한 입력들 — 모두 실패해야 한다.
    final mutants = <String, String>{
      '끝 마침표 삭제': '지금은 광고로 크레딧을 받을 수 없어요',
      '끝 단어 삭제': '지금은 광고로 크레딧을 받을 수',
      '앞 단어 삭제': '광고로 크레딧을 받을 수 없어요.',
      '앞 구절 삭제': '일과는 만들 수 있어요',
      '마침표 삭제': '정하지 않아도 일과는 만들 수 있어요',
      '더 긴 문구(다음에)': '다음에',
      '끝 공백 추가(취소 )': '취소 ',
      '앞 공백 추가': ' 취소',
      '끝 마침표 추가': '다음.',
    };
    mutants.forEach((name, message) {
      test('변이 실패: $name', () {
        final missing = run(message);
        expect(missing, isNotEmpty, reason: message);
        // 어느 키의 어느 조각인지 말한다
        expect(missing.single, startsWith('k: "'));
        expect(missing.single, contains(message));
      });
    });

    test('줄바꿈 문구에서 조각 순서가 바뀌면 실패한다', () {
      expect(run('사용하나요?\n이 휴대폰은 누가'), isNotEmpty);
    });

    test('줄바꿈 사이에 다른 글이 끼어도 실패한다 (원문은 \\n 하나뿐)', () {
      final c2 = chainsOf(r"x('가나다\n라마바\n사아자');");
      expect(auditArb({'k': '가나다\n사아자'}, c2).missing, isNotEmpty);
      expect(auditArb({'k': '가나다\n라마바\n사아자'}, c2).missing, isEmpty);
    });

    test('보간 문구는 조각이 한 리터럴 안에 순서대로 있어야 한다', () {
      // 조각이 각각 다른 리터럴에 있으면 통과하지 않는다
      final c2 = chainsOf("x('가나다 ');\ny('라마바');");
      final r = auditArb({'k': '가나다 {n}라마바'}, c2).missing;
      expect(r.single, startsWith('k: 조각들이 기준 소스의 한 문자열 안에 이 순서로 있지 않다'));
      // 같은 리터럴이지만 순서가 바뀌면 실패
      final c3 = chainsOf(r"x('$n라마바 가나다 $m');");
      expect(auditArb({'k': '{n}가나다 {m}라마바'}, c3).missing, isNotEmpty);
    });

    test('보간 문구의 시작 조각은 리터럴 맨 앞이어야 한다', () {
      expect(run('다른 오늘 {name}님의 {tail} 하루'), isNotEmpty);
      expect(run('어제 {name}님의 {tail} 하루'), isNotEmpty);
    });

    test('보간 문구의 끝 조각은 리터럴 맨 끝이어야 한다', () {
      expect(run('오늘 {name}님의 {tail} 하루가 간다'), isNotEmpty);
    });

    test('안쪽 조각은 부분 문자열이라 약하다 — 한계를 값으로 못박는다', () {
      // 같은 리터럴 안에 같은 글이 있으면 안쪽 한 글자 차이는 못 잡는다
      final c2 = chainsOf(r"x('가나다라 $n 마바사아 가나다 라마바');");
      expect(auditArb({'k': '가나다라 {n}마바사아 가나다 라마바'}, c2).missing, isEmpty);
    });

    test('ICU select 는 조각을 각각 맞댄다', () {
      final c2 = chainsOf("x(n == 0 ? '카드가 없어요' : '카드 한 장');");
      expect(
        auditArb({'k': '{n, plural, =0{카드가 없어요} other{카드 한 장}}'}, c2).missing,
        isEmpty,
      );
      expect(
        auditArb({'k': '{n, plural, =0{카드가 없어요.} other{카드 한 장}}'}, c2).missing,
        ['k: "카드가 없어요."'],
      );
    });

    test('수용 목록에 적은 조각은 통과한다', () {
      final r = auditArb({'x': '없는 문구예요'}, chains, accepted: {'없는 문구예요'});
      expect(r.missing, isEmpty);
    });

    test('역슬래시 글자가 남은 문구는 실패한다', () {
      expect(
        auditArb({'x': r'가나\n다라'}, chains).missing.single,
        startsWith('x: 역슬래시'),
      );
    });

    test('@ 메타와 문자열이 아닌 값은 건너뛴다', () {
      final r = auditArb({'@x': '없는 문구예요', 'n': 3}, chains);
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
      File(
        '${repo.path}/lib/a.dart',
      ).writeAsStringSync("// 주석에만 있어요\nText('안녕하세요 반가워요.');\nText('다음에');\n");
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
        audit({'a': '안녕하세요 반가워요.', 'b': '다음에'}, commit, out, StringBuffer()),
        0,
      );
      expect(out.toString(), contains('기준 커밋에 없는 것 0개'));
    });

    test('한 글자·마침표·주석·lib 밖 문구는 종료 코드 1 과 키·조각 메시지', () {
      for (final m in [
        '안녕하세요 반가워요',
        '안녕하세요 반가워요..',
        '다음',
        '주석에만 있어요',
        '밖에만 있어요',
      ]) {
        final out = StringBuffer();
        expect(audit({'a': m}, commit, out, StringBuffer()), 1, reason: m);
        expect(out.toString(), contains('a: "$m"'));
      }
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

    test('loadBaseChains 는 커밋이 없으면 BaseCommitError 를 던진다', () {
      expect(
        () => loadBaseChains('deadbeef', workingDirectory: repo.path),
        throwsA(isA<BaseCommitError>()),
      );
    });
  });
}
