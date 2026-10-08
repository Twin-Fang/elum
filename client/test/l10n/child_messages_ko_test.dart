import 'package:elum/core/l10n/batchim.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/shared/models/reward_character.dart';
import 'package:elum/features/child/presentation/mode_switch_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 조사가 든 문구의 기대값은 옛 코드(`KoreanParticle`)가 실제로 내던 값이다.
/// 이름마다 `이/가` 를 옛 확장으로 한 번 돌려 얻은 결과를 그대로 적었다.
const _oldGreeting = <String, String>{
  '민준': '오늘 민준이\n할 일들이에요. 힘내봐요!', // 받침 ㄴ
  '루미': '오늘 루미가\n할 일들이에요. 힘내봐요!', // 받침 없음
  '하늘': '오늘 하늘이\n할 일들이에요. 힘내봐요!', // 받침 ㄹ
  '각': '오늘 각이\n할 일들이에요. 힘내봐요!', // 받침 있는 첫 음절(U+AC01)
  '가': '오늘 가가\n할 일들이에요. 힘내봐요!', // 한글 범위 시작(U+AC00)
  '힣': '오늘 힣이\n할 일들이에요. 힘내봐요!', // 한글 범위 끝(U+D7A3)
  'Alex': '오늘 Alex가\n할 일들이에요. 힘내봐요!', // 한글 아님
  '7': '오늘 7가\n할 일들이에요. 힘내봐요!',
  '': '오늘 가\n할 일들이에요. 힘내봐요!',
  '김민준': '오늘 김민준이\n할 일들이에요. 힘내봐요!',
};

void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('이룸이 홈 인사말 — 받침 있음·없음·경계 이름이 옛 조사 결과와 같다', () {
    _oldGreeting.forEach((name, expected) {
      expect(
        ko.childHomeGreeting(name, batchimOf(name)),
        expected,
        reason: '이름 "$name"',
      );
    });
  });

  test('이룸이 홈 인사말 — 손으로 쓴 한국어', () {
    expect(ko.childHomeGreeting('민준', 'yes'), '오늘 민준이\n할 일들이에요. 힘내봐요!');
    expect(ko.childHomeGreeting('루미', 'no'), '오늘 루미가\n할 일들이에요. 힘내봐요!');
  });

  test('빈 상태 문구와 안내', () {
    expect(ko.childHomeEmptyTitle('하늘'), '아직 하늘의\n일과가 없어요');
    expect(ko.childHomeEmptyTitle('루미'), '아직 루미의\n일과가 없어요');
    expect(ko.childHomeEmptyHint, '보호자 화면에서 일과를 만들 수 있어요');
    expect(ko.childHomeEmptyHintDevice, '보호자 휴대폰에서 일과를 만들 수 있어요');
  });

  test('홈 낭독 이름과 보상 접두어', () {
    expect(ko.childHomeToGuardianLabel, '보호자 화면으로 가기');
    expect(ko.childHomeSettingsLabel, '설정 열기');
    expect(ko.childHomeRewardPrefix, '다하면');
    expect(ko.rewardBannerPrefix, '다하면 ');
  });

  test('별 화면의 개수 문구 — 값 3개', () {
    expect(ko.childStarsEarned(0), '0개의 별을 얻었어요\n할 일을 해내고 별을 더 찾아봐요!');
    expect(ko.childStarsEarned(7), '7개의 별을 얻었어요\n할 일을 해내고 별을 더 찾아봐요!');
    expect(ko.childStarsEarned(120), '120개의 별을 얻었어요\n할 일을 해내고 별을 더 찾아봐요!');
    expect(ko.childStarsSemantics(7), '별 7개 모았어요');
    expect(ko.childStarsSemantics(12), '별 12개 모았어요');
  });

  test('카드 페이저 낭독 문구', () {
    expect(ko.childCardPagerLabel(5, 2), '카드 5장 중 2번째');
    expect(ko.childCardPagerLabel(12, 11), '카드 12장 중 11번째');
  });

  test('카드 상세 문구', () {
    expect(ko.childDetailSoundFailedTitle, '소리를 재생하지 못했어요');
    expect(ko.childDetailSoundFailedFallback, '휴대폰 소리를 켜고 다시 눌러주세요');
    expect(ko.childDetailCheckLabel, '다 했어요');
  });

  test('보상 화면 — 캐릭터마다 제목·문구·버튼이 다르다', () {
    expect(RewardCharacter.lumi.title, '축하해요!');
    expect(RewardCharacter.lumi.buttonLabel, '오예!');
    expect(
      RewardCharacter.lumi.messageFor('하늘'),
      '할 일을 해내서 루미가\n하늘에게 별을 가져왔어요',
    );
    expect(
      RewardCharacter.lumi.messageFor('루미'),
      '할 일을 해내서 루미가\n루미에게 별을 가져왔어요',
    );
    expect(RewardCharacter.popo.title, '잘했어요!');
    expect(RewardCharacter.popo.buttonLabel, '좋아요!');
    expect(
      RewardCharacter.popo.messageFor('하늘'),
      '포포가 하늘에게\n축하의 선물로 큰 별을 가져왔어요',
    );
    expect(RewardCharacter.ruru.title, '멋져요!');
    expect(RewardCharacter.ruru.buttonLabel, '신난다!');
  });

  test('루루 문구 — 옛 조사 결과와 같다(받침 있음·없음·경계)', () {
    // 옛 코드: '{name}{josa} 할 일을 해내서\n루루가 선물을 가져왔다고 해요' 에 이름과 subjectParticle 치환
    const old = <String, String>{
      '민준': '민준이 할 일을 해내서\n루루가 선물을 가져왔다고 해요',
      '루미': '루미가 할 일을 해내서\n루루가 선물을 가져왔다고 해요',
      '하늘': '하늘이 할 일을 해내서\n루루가 선물을 가져왔다고 해요',
      '각': '각이 할 일을 해내서\n루루가 선물을 가져왔다고 해요',
      '가': '가가 할 일을 해내서\n루루가 선물을 가져왔다고 해요',
      '힣': '힣이 할 일을 해내서\n루루가 선물을 가져왔다고 해요',
      'Alex': 'Alex가 할 일을 해내서\n루루가 선물을 가져왔다고 해요',
      '7': '7가 할 일을 해내서\n루루가 선물을 가져왔다고 해요',
      '  ': '이룸이가 할 일을 해내서\n루루가 선물을 가져왔다고 해요', // 이름이 비면 이룸이
      ' 민준 ': '민준이 할 일을 해내서\n루루가 선물을 가져왔다고 해요', // 앞뒤 공백은 뗀다
    };
    old.forEach((name, expected) {
      expect(
        RewardCharacter.ruru.messageFor(name),
        expected,
        reason: '이름 "$name"',
      );
    });
  });

  test('이름이 비면 이룸이로 대신한다', () {
    expect(RewardCharacter.lumi.messageFor(''), '할 일을 해내서 루미가\n이룸이에게 별을 가져왔어요');
    expect(
      RewardCharacter.popo.messageFor('  '),
      '포포가 이룸이에게\n축하의 선물로 큰 별을 가져왔어요',
    );
  });

  test('화면 전환 문구', () {
    expect(ModeSwitchTarget.child.description, '암호를 입력하면 이룸이 화면으로 바뀌어요');
    expect(ModeSwitchTarget.guardian.description, '암호를 입력하면 보호자 화면으로 바뀌어요');
    expect(ko.modeSwitchTitle, '비밀암호를 입력하세요');
    expect(ko.modeSwitchMismatch, '암호가 달라요. 다시 넣어주세요');
    expect(ko.modeSwitchPinLabel, '암호 넣기');
    expect(ko.modeSwitchReadFailedTitle, '암호를 확인하지 못했어요');
    expect(ko.modeSwitchReadFailedFallback, '잠시 후 다시 해주세요');
    expect(ko.modeSwitchBlockedTitle, '보호자 휴대폰에서\n열어 주세요');
    expect(ko.modeSwitchBlockedDescription, '이 휴대폰에서는 보호자 화면을 열 수 없어요');
    expect(ko.modeSwitchBlockedBack, '돌아가기');
  });

  test('일과 완료 문구', () {
    expect(ko.routineDoneTitle, '일과를 끝냈어요!');
    expect(ko.routineDoneButton, '오예!');
  });
}
