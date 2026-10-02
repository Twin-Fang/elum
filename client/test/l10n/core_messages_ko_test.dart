import 'package:elum/core/l10n/l10n_context.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 옮긴 공용 문구가 옛 한국어와 같다 — 코드가 조립하던 것(보간·접두)은 값으로 고정한다.
void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('팝업·뒤로가기·찾을 수 없는 화면', () {
    expect(ko.commonPopupClose, '팝업 닫기');
    expect(ko.commonBack, '뒤로 가기');
    expect(ko.commonScreenNotFound, '화면을 찾을 수 없어요');
    expect(ko.commonRetryLater, '잠시 후 다시 해주세요');
    expect(ko.commonAd, '광고');
    expect(ko.commonAppInfo, '앱 정보');
  });

  test('다시 시도 — 에러 코드가 있으면 괄호로 붙는다', () {
    expect(ko.commonRetry, '다시 시도');
    expect(ko.commonRetryWithCode('E-NET-OFFLINE'), '다시 시도 (E-NET-OFFLINE)');
  });

  test('코치마크 낭독 문구', () {
    expect(
      ko.coachStepLabel(2, 3, '이룸이가 수행할 새로운 일과를 만들 수 있어요'),
      '안내 2/3. 이룸이가 수행할 새로운 일과를 만들 수 있어요',
    );
    expect(ko.coachStepLabel(10, 12, '끝'), '안내 10/12. 끝');
    expect(ko.coachCloseHint, '안내 닫기');
    expect(ko.coachNextHint, '다음 안내');
    expect(ko.coachTapToClose, '화면을 누르면 닫혀요');
    expect(ko.coachTapToNext, '화면을 누르면 다음으로 넘어가요');
  });

  test('네트워크 안내와 문장 끝', () {
    expect(ko.failureHintOffline, '인터넷 연결을 확인해주세요');
    expect(ko.failureHintTimeout, '연결이 느려요. 잠시 후 다시 해주세요');
    expect(ko.failureHintBadCertificate, '안전하지 않은 연결이에요. 다른 망에서 해주세요');
    expect(ko.sentenceStop, '.');
  });

  test('앱 상태 화면 문구 — 업데이트 설명은 두 줄이다', () {
    expect(ko.appStatusMaintenanceTitle, '잠시 쉬고 있어요');
    expect(ko.appStatusMaintenanceBody, '조금 뒤에 다시 열어주세요');
    expect(ko.appStatusRecheck, '다시 확인하기');
    expect(ko.appStatusUpdateTitle, '새 이룸이 나왔어요');
    expect(
      ko.appStatusUpdateBody,
      '앱을 새로 받아야 이어서 쓸 수 있어요.\n스토어에서 이룸을 업데이트해주세요',
    );
    expect(ko.appStatusUpdated, '업데이트했어요');
    expect(ko.appStatusGoUpdate, '업데이트하러 가기');
    expect(ko.appStatusStoreOpenFailedTitle, '스토어를 열지 못했어요');
    expect(ko.appStatusStoreOpenFailedFallback, '스토어에서 이룸을 찾아 업데이트해주세요');
    expect(ko.loginSceneEyebrow, '오늘의 하루,');
    expect(ko.loginSceneTitle, '차근차근 함께해요');
  });
}
