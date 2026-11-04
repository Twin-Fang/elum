/// 요금제·결제 화면 자리 코드 (서버 코드가 없을 때 배지에 쓰는 값)
abstract final class PlanErrorCode {
  /// 스토어 가격 불러오기 실패
  static const price = 'E-PLAN-PRICE';

  /// 스토어 결제창이 실패를 알림
  static const store = 'E-PLAN-STORE';

  /// 결제 확인 요청 실패 (결제는 스토어에 남아 있음)
  static const verify = 'E-PLAN-VERIFY';

  /// 서버가 확인했지만 Pro 가 켜지지 않음 (결제 대기·환불·만료)
  static const inactive = 'E-PLAN-INACTIVE';

  /// 회원 id 를 몰라 구매를 계정에 묶을 수 없음
  static const account = 'E-PLAN-ACCOUNT';

  /// 구매 복원 실패
  static const restore = 'E-PLAN-RESTORE';

  /// 스토어 구독 관리 화면을 열지 못함
  static const manage = 'E-PLAN-MANAGE';

  /// 약관·개인정보처리방침 링크를 열지 못함
  static const legalLink = 'E-PLAN-LINK';
}
