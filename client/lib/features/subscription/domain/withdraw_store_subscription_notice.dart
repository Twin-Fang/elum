/// 회원탈퇴 경고에 덧붙이는 스토어 구독 안내 3종: 없음, 탈퇴가 해지함(Google Play), 직접 해지(App Store)
enum WithdrawStoreSubscriptionNotice {
  /// 갱신 중인 스토어 구독 없음
  none,

  /// 서버가 탈퇴 때 자동 갱신을 해지함 (Google Play)
  cancelledOnWithdraw,

  /// 서버가 해지할 수 없음 > 스토어에서 직접 해지 (App Store)
  cancelInStore,
}
