import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/l10n_ko_audit.dart';

void main() {
  group('fragmentsOf', () {
    test('줄바꿈을 기준으로 조각낸다', () {
      expect(fragmentsOf('이 휴대폰은 누가\n사용하나요?'), ['이 휴대폰은 누가', '사용하나요?']);
    });

    test('자리표시자와 ICU 가지 이름을 걷어낸다', () {
      expect(
        fragmentsOf(
          '{name}{batchim, select, yes{이} other{가}} 할 일을 해내서\n루루가 선물을 가져왔다고 해요',
        ),
        ['할 일을 해내서', '루루가 선물을 가져왔다고 해요'],
      );
      expect(fragmentsOf('{weekday, select, mon{월} tue{화} other{}}'), isEmpty);
    });

    test('한 글자 조각은 어디에나 있으므로 버린다', () {
      expect(fragmentsOf('{count, plural, other{{count}개}}'), isEmpty);
    });

    test('소스 표기와 달라지는 따옴표·역슬래시가 든 조각은 버린다', () {
      expect(fragmentsOf("it's 좋아요"), isEmpty);
    });

    test('자리표시자 앞뒤 한글을 각각 조각으로 나눈다', () {
      expect(fragmentsOf('오늘 {name}님의 일과가 끝났어요'), ['오늘', '님의 일과가 끝났어요']);
      expect(fragmentsOf('{a}와 {b}를 함께 해요'), ['를 함께 해요']);
    });

    test('plural 의 각 가지 문구를 따로 조각낸다', () {
      expect(
        fragmentsOf('{n, plural, =0{카드가 없어요} =1{카드 한 장} other{카드 {n}장}}'),
        ['카드가 없어요', '카드 한 장', '카드'],
      );
    });

    test('조각 앞뒤 공백은 걷어낸다', () {
      expect(fragmentsOf('  가나다  \n  라마바  '), ['가나다', '라마바']);
    });
  });

  group('auditArb', () {
    // 기준 소스를 문자열 하나로 흉내 낸다 (git grep -F 와 같은 부분 문자열 일치).
    const source =
        "Text('이 휴대폰은 누가');\nText('사용하나요?');\n"
        "Text('할 일을 해내서');\nText('님의 일과가 끝났어요');";
    bool inSource(String f) => source.contains(f);

    final arb = <String, dynamic>{
      '@@locale': 'ko',
      'a': '이 휴대폰은 누가\n사용하나요?',
      '@a': {'description': '설명 — 감사 대상 아님'},
      'b': '{name}님의 일과가 끝났어요',
    };

    test('원본에 그대로 있는 문구는 통과한다', () {
      final r = auditArb(arb, inSource);
      expect(r.missing, isEmpty);
      expect(r.checked, 3); // 누가, 사용하나요?, 님의 일과가 끝났어요
    });

    test('마침표 하나를 더하면 실패한다', () {
      final r = auditArb({...arb, 'a': '이 휴대폰은 누가\n사용하나요?.'}, inSource);
      expect(r.missing, ['a: "사용하나요?."']);
    });

    test('조사 하나를 바꾸면 실패한다', () {
      final r = auditArb({...arb, 'b': '{name}님은 일과가 끝났어요'}, inSource);
      expect(r.missing, ['b: "님은 일과가 끝났어요"']);
    });

    test('공백 하나를 바꾸면 실패한다', () {
      final r = auditArb({...arb, 'a': '이 휴대폰은  누가\n사용하나요?'}, inSource);
      expect(r.missing, ['a: "이 휴대폰은  누가"']);
    });

    test('기준에 없는 조각은 어느 키의 어느 조각인지 말한다', () {
      final r = auditArb({'x': '없는 문구예요\n할 일을 해내서'}, inSource);
      expect(r.missing, ['x: "없는 문구예요"']);
    });

    test('수용 목록에 적은 조각은 통과한다', () {
      final r = auditArb({'x': '없는 문구예요'}, inSource, accepted: {'없는 문구예요'});
      expect(r.missing, isEmpty);
    });

    test('역슬래시 글자가 남은 문구는 실패한다', () {
      final r = auditArb({'x': r'가나\n다라'}, inSource);
      expect(r.missing.single, startsWith('x: 역슬래시'));
    });

    test('@ 메타와 문자열이 아닌 값은 건너뛴다', () {
      final r = auditArb({'@x': '없는 문구예요', 'n': 3}, inSource);
      expect(r.missing, isEmpty);
      expect(r.checked, 0);
    });
  });

  group('gitGrepIn — 실제 git 으로 기준 커밋을 묻는다', () {
    late Directory repo;
    late String commit;

    setUpAll(() {
      repo = Directory.systemTemp.createTempSync('l10n_audit_');
      void git(List<String> a) {
        final r = Process.runSync('git', a, workingDirectory: repo.path);
        if (r.exitCode != 0) fail('git ${a.join(' ')}: ${r.stderr}');
      }

      git(['init', '-q']);
      Directory('${repo.path}/lib').createSync();
      File(
        '${repo.path}/lib/a.dart',
      ).writeAsStringSync("Text('안녕하세요 반가워요');\n");
      // lib 밖 파일에만 있는 문구는 기준이 아니다
      File('${repo.path}/other.txt').writeAsStringSync('밖에만 있어요\n');
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
      commit = Process.runSync('git', [
        'rev-parse',
        'HEAD',
      ], workingDirectory: repo.path).stdout.toString().trim();
    });

    tearDownAll(() => repo.deleteSync(recursive: true));

    test('lib 소스에 있으면 true, 한 글자 다르면 false', () {
      final inBase = gitGrepIn(commit, workingDirectory: repo.path);
      expect(inBase('안녕하세요 반가워요'), isTrue);
      expect(inBase('안녕하세요 반가워요.'), isFalse);
      expect(inBase('안녕하세요  반가워요'), isFalse);
      expect(inBase('밖에만 있어요'), isFalse);
    });

    test('옵션처럼 생긴 조각도 -e 로 안전하게 묻는다', () {
      final inBase = gitGrepIn(commit, workingDirectory: repo.path);
      expect(inBase('-q 가나'), isFalse);
    });
  });
}
