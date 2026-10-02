import 'package:elum/core/l10n/batchim.dart';
import 'package:elum/l10n/app_localizations.dart';
import 'package:elum/shared/utils/korean_particle.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';

/// 이름 끝 글자의 받침 판정 — 기존 `KoreanParticle` 과 판정이 같아야 `ko` 문구가 안 바뀐다.
void main() {
  test('받침이 있는 한글이면 yes', () {
    expect(batchimOf('민준'), 'yes'); // 준 → ㄴ
    expect(batchimOf('민수'), 'no'); // 수 → 받침 없음 (반례)
    expect(batchimOf('지은'), 'yes');
    expect(batchimOf('지훈'), 'yes');
    expect(batchimOf('김민준'), 'yes'); // 마지막 글자만 본다
  });

  test('ㄹ 받침도 받침 있음 — 기존 KoreanParticle 규칙(하늘+과)이 정답', () {
    expect(batchimOf('하늘'), 'yes');
    expect('하늘'.withParticle, '과');
  });

  test('받침이 없는 한글이면 no', () {
    expect(batchimOf('루미'), 'no');
    expect(batchimOf('서연이'), 'no');
    expect(batchimOf('아이'), 'no');
    expect(batchimOf('김루미'), 'no');
  });

  test('한글이 아니면 no — 영문·숫자·이모지·빈 문자열은 받침 없음으로 본다', () {
    expect(batchimOf('Alex'), 'no');
    expect(batchimOf('3'), 'no');
    expect(batchimOf('7'), 'no');
    expect(batchimOf('😀'), 'no');
    expect(batchimOf(''), 'no');
    expect(batchimOf(' '), 'no');
    expect(batchimOf('민준 '), 'no'); // 끝이 공백이면 공백을 본다(기존과 같다)
  });

  test('한글 자모 단독·호환 자모·완성형 밖 문자는 no', () {
    expect(batchimOf('ᆫ'), 'no'); // 종성 ㄴ (U+11AB, 조합용 자모)
    expect(batchimOf('ᄀ'), 'no'); // 초성 ㄱ
    expect(batchimOf('ㄴ'), 'no'); // 호환 자모 U+3134
    expect(batchimOf('ㅏ'), 'no');
    expect(batchimOf('가'), 'no'); // 가: 완성형 첫 글자
    expect(batchimOf('각'), 'yes'); // 각: 완성형 첫 받침
    expect(batchimOf('힣'), 'yes'); // 힣: 완성형 마지막
    expect(batchimOf('힤'), 'no'); // 완성형 바로 밖
    expect(batchimOf('꯿'), 'no');
    expect(batchimOf('日本'), 'no');
  });

  test('기존 KoreanParticle 테스트의 모든 이름에서 같은 판정이다', () {
    const names = [
      '민준', '서연', '지훈', '하늘', '루미', '포포', '루루', '하나', 'Alex', '7', '', //
      '김민준', '김루미', '이룸이', '   ',
    ];
    for (final n in names) {
      // 기존 조사는 받침 여부에서 나온다 — 이/가 가 받침 유무와 1:1 이다
      expect(batchimOf(n) == 'yes', n.subjectParticle == '이', reason: '"$n"');
      expect(batchimOf(n) == 'yes', n.objectParticle == '을', reason: '"$n"');
      expect(batchimOf(n) == 'yes', n.topicParticle == '은', reason: '"$n"');
      expect(batchimOf(n) == 'yes', n.withParticle == '과', reason: '"$n"');
    }
  });

  test('ICU select 가 gen-l10n 으로 생성돼 AppLocalizations 호출로 동작한다', () {
    // 조사 문구(`{batchim, select, yes{이} other{가}}`)는 Task 13 이 ARB 에 넣는다. 여기서는
    // 같은 select 문법으로 이미 생성된 weekdayShort 를 실제 호출해 분기·other 대체를 값으로 본다.
    final ko = lookupAppLocalizations(const Locale('ko'));
    expect(ko.weekdayShort('mon'), '월');
    expect(ko.weekdayShort('sun'), '일');
    expect(ko.weekdayShort('xxx'), ''); // other 분기
    // batchimOf 의 반환값이 select 키와 같은 'yes'/'other' 규약인지 — yes 가 아니면 other 로 간다
    expect(Intl.select(batchimOf('민준'), {'yes': '이', 'other': '가'}), '이');
    expect(Intl.select(batchimOf('루미'), {'yes': '이', 'other': '가'}), '가');
  });
}
