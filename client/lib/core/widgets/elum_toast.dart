import 'package:flutter/material.dart';

/// 저장·변경 뒤 잠깐 뜨는 알림(토스트)을 띄운다. 앱의 토스트는 모두 여기로 띄운다.
///
/// 모양은 테마(`snackBarTheme`) 한 곳이 정한다 — 여기서도 화면에서도 스타일을 덧쓰지 않는다.
void showElumToast(BuildContext context, String message) =>
    showElumToastOn(ScaffoldMessenger.maybeOf(context), message);

/// 화면을 옮기기 전에 잡아 둔 [messenger] 로 띄운다 — 옮긴 뒤에는 앞 화면의 context 가 없다.
void showElumToastOn(ScaffoldMessengerState? messenger, String message) {
  if (messenger == null) {
    // 알림 하나 못 띄웠다고 동작을 멈출 일은 아니다. 대신 흔적은 남긴다.
    debugPrint('[화면] 토스트를 띄울 자리가 없어 건너뜀: $message');
    return;
  }
  // 앞 알림을 지운다. 그대로 두면 연달아 누를 때 4초씩 줄 서서 뒤늦게 뜬다.
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
