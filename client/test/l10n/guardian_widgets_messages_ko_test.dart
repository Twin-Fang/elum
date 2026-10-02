import 'package:elum/core/l10n/l10n_context.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 단위·복수·보간을 ARB 가 넘겨받아도 `ko` 문구가 옛 조립과 같다.
void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('카드 검토 머리 — 만든 카드 수', () {
    expect(ko.cardReviewMade(5), '카드 5개를 만들었어요');
    expect(ko.cardReviewMade(12), '카드 12개를 만들었어요');
  });

  test('AI 크레딧 카드의 숫자 줄', () {
    expect(ko.creditAmountLeft(72, 100), '72 / 100 크레딧 남음');
    expect(ko.creditAmountLeft(0, 50), '0 / 50 크레딧 남음');
    // 큰 숫자만 따로 강조하므로 나머지 조각은 앞에 공백이 있다
    expect(ko.creditAmountRest(100), ' / 100 크레딧 남음');
    expect(ko.creditAmountRest(7), ' / 7 크레딧 남음');
    expect(ko.aiCreditResetLine('9월 28일(월) 0시'), '9월 28일(월) 0시에 다시 채워져요');
    expect(ko.aiCreditResetLine('다음 주 월요일 0시'), '다음 주 월요일 0시에 다시 채워져요');
  });

  test('AI 크레딧 안내 팝업 — 서버 단가를 문장에 넣는다', () {
    expect(ko.creditCostTitle, 'AI 크레딧은 이렇게 줄어요');
    expect(ko.creditCostLine(1, 2), '일과 글을 만들 때 1개, 그림이 완성된 카드 1장마다 2개씩 써요.');
    expect(ko.creditCostLine(3, 12), '일과 글을 만들 때 3개, 그림이 완성된 카드 1장마다 12개씩 써요.');
    expect(ko.creditCostKeepGoing, '크레딧이 남아 있을 때 시작한 일과는 그림이 많아도 끝까지 만들어져요.');
    expect(ko.creditWeeklyRefill, '매주 월요일 0시에 다시 채워져요.');
  });

  test('오늘 일과에 담았어요 — 조사는 옛 문구 그대로 을(를)', () {
    expect(ko.todayRoutineCopied('비 오는 날 등교'), '비 오는 날 등교을(를) 오늘 일과에 담았어요');
    expect(ko.todayRoutineCopied('양치'), '양치을(를) 오늘 일과에 담았어요');
  });

  test('사진 올리기 실패 팝업 제목 — 사유를 줄 아래에 잇는다', () {
    expect(
      ko.cardPhotoUploadFailedDialog('사진이 너무 커요. 다른 사진을 골라 주세요'),
      '사진을 올리지 못했어요.\n사진이 너무 커요. 다른 사진을 골라 주세요',
    );
    expect(ko.cardPhotoUploadFailedDialog('서버 문구'), '사진을 올리지 못했어요.\n서버 문구');
  });

  test('카드 검토 보상 줄 앞말은 끝 공백을 지킨다', () {
    expect(ko.cardReviewRewardLead, '완료 시 ');
  });

  test('홈 코치마크 문구 — 강조 표식과 줄바꿈 유지', () {
    expect(ko.homeCoachCreate, '이룸이가 수행할 *새로운\n일과를 만들 수 있어요*');
    expect(ko.homeCoachSwipe, '일과를 *왼쪽으로 스와이프*하면\n*수정하거나 삭제*할 수 있어요');
    expect(ko.homeCoachSwitch, '캐릭터 아이콘을 누르면\n*이룸이모드로 바꿀 수 있어요*');
  });

  test('나가기 팝업 — 설명 줄바꿈을 손으로 둔 그대로', () {
    expect(
      ko.routineLeaveDraftWhenReadyMessage,
      '카드가 다 만들어지면 임시저장에 남아요\n설정에서 이어서 만들 수 있어요',
    );
    expect(ko.routineLeaveDraftMessage, '설정의 임시저장에서\n이어서 만들 수 있어요');
  });

  test('순서 옮기기 낭독 동작', () {
    expect(ko.cardMoveForward, '앞으로 옮기기');
    expect(ko.cardMoveBackward, '뒤로 옮기기');
  });
}
