import 'package:elum/l10n/app_localizations.dart';
import 'package:elum/shared/models/reward_preset.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:elum/shared/utils/korean_particle.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 조사·날짜를 ARB 가 넘겨받아도 `ko` 결과가 옛 직접 조립과 같다.
void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('만든 사람 문구 — 받침에 따라 이/가', () {
    expect(ko.routineForeignCreator('민준', 'yes'), '민준이 만든 일과예요');
    expect(ko.routineForeignCreator('루미', 'no'), '루미가 만든 일과예요');
    expect(ko.routineForeignCreatorUnknown, '다른 보호자가 만든 일과예요');
  });

  test('Routine 의 문구 getter 는 API 그대로 ko 문구를 준다', () {
    const base = Routine(id: 'r1', createdByMe: false);
    expect(base.foreignCreatorLabel, '다른 보호자가 만든 일과예요');
    expect(base.copyWith(creatorName: '엄마').foreignCreatorLabel, '엄마가 만든 일과예요');
    expect(base.copyWith(creatorName: '아빠').foreignCreatorLabel, '아빠가 만든 일과예요');
    expect(base.copyWith(creatorName: '선생님').foreignCreatorLabel, '선생님이 만든 일과예요');
    expect(base.copyWith(creatorName: '민준').foreignCreatorLabel, '민준이 만든 일과예요');
    expect(base.copyWith(creatorName: '루미').foreignCreatorLabel, '루미가 만든 일과예요');
    // 공백뿐인 이름은 이름을 모르는 것과 같다
    expect(base.copyWith(creatorName: '  ').foreignCreatorLabel, '다른 보호자가 만든 일과예요');
    // 내가 만들었거나 모르면 문구가 없다
    expect(const Routine(id: 'r5', createdByMe: true).foreignCreatorLabel, isNull);
    expect(const Routine(id: 'r6').foreignCreatorLabel, isNull);
    expect(const Routine(id: 'r2').displayTitle, '오늘의 일과');
    expect(const Routine(id: 'r7', title: ' 산책 ').displayTitle, '산책');
    expect(
      Routine(id: 'r3', scheduledAt: DateTime(2026, 9, 20)).scheduledDateLabel,
      '2026년 9월 20일',
    );
    expect(
      Routine(id: 'r8', scheduledAt: DateTime(2027, 1, 5)).scheduledDateLabel,
      '2027년 1월 5일',
    );
    expect(const Routine(id: 'r4').scheduledDateLabel, '');
  });

  test('만든 사람 문구는 옛 조사 확장의 출력과 글자 하나까지 같다', () {
    for (final name in ['엄마', '아빠', '선생님', '민준', '루미', 'Tom', '철수1', '']) {
      final old = '$name${name.subjectParticle} 만든 일과예요';
      expect(ko.routineForeignCreator(name, batchimOfForTest(name)), old, reason: name);
    }
  });

  test('보상 프리셋 서버 키', () {
    expect(RewardPreset.snack.key, 'SNACK');
    expect(RewardPreset.snack.emoji, '🍪');
  });
}

/// 테스트가 batchimOf 를 직접 부르는 대신 옛 판정(KoreanParticle)으로 yes/no 를 정한다.
String batchimOfForTest(String name) => name.subjectParticle == '이' ? 'yes' : 'no';
