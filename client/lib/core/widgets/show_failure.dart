import 'package:flutter/material.dart';

import '../network/app_failure.dart';
import 'elum_dialog.dart';

/// 실패를 팝업으로 알린다 — **앱에서 실패를 말하는 방법은 이것 하나다.**
///
/// 무엇이 던져졌든 받는다. [AppFailure.of] 가 판정하고, 서버가 문구를 줬으면
/// 그 문구가 [fallback] 을 이긴다.
///
/// ```dart
/// } catch (e) {
///   await showFailure(context, e,
///       title: '로그인하지 못했어요',
///       fallback: '잠시 후 다시 해주세요',
///       fallbackCode: 'E-AUTH');
/// }
/// ```
///
/// **식별자는 반드시 붙는다.** 서버 코드가 있으면 그것을, 없으면 [fallbackCode] 를
/// 붙인다. 사용자에게는 뜻이 없지만 제보를 받았을 때 추적할 유일한 단서다
/// (docs 예외처리 규칙).
///
/// 앱이 스스로 끊은 요청([NetworkFault.cancelled])이면 **아무것도 띄우지 않는다** —
/// 사용자가 한 적 없는 실패를 보여주는 꼴이 된다.
Future<void> showFailure(
  BuildContext context,
  Object? error, {
  required String title,
  required String fallback,
  required String fallbackCode,
}) async {
  final failure = AppFailure.of(error);
  if (failure.isSilent) return;

  await showElumDialog<void>(
    context: context,
    title: title,
    message: failure.describe(fallback, fallbackCode),
    // 이룸이도 보는 화면이라 붉은 경고를 쓰지 않는다.
    icon: ElumDialogIcon.warning,
  );
}


/// 실패를 스낵바로 알린다 — **흐름을 막지 않아도 되는 실패에.**
///
/// 저장은 실패했지만 화면은 계속 쓸 수 있을 때 쓴다(보상 저장·카드 문장 수정 등).
/// 판정은 [showFailure] 와 **같은 곳**을 쓴다 — 보여주는 방법만 다르다.
///
/// 팝업으로 막을지 스낵바로 알릴지는 **되돌릴 수 있는가**로 정한다. 다음 화면으로
/// 넘어가면 사용자가 다시 시도할 수 없게 되는 실패는 팝업으로 막는다.
void showFailureSnack(
  BuildContext context,
  Object? error, {
  required String fallback,
  required String fallbackCode,
}) {
  final failure = AppFailure.of(error);
  if (failure.isSilent) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(failure.describe(fallback, fallbackCode))),
  );
}
