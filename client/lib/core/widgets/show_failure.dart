import 'package:flutter/material.dart';

import '../l10n/l10n_context.dart';
import '../network/app_failure.dart';
import 'elum_dialog.dart';

/// 실패를 팝업으로 알린다 — **앱에서 실패를 말하는 방법은 이것 하나다.**
///
/// 시안 `팝업` 변형 `로그인실패`(1045:5079) 그대로다 — 붉은 느낌표, 문장 하나,
/// 붉은 `확인`. 예전에는 노란 경고 팝업과 스낵바로 나눠 보였는데, 시안에는 둘 다
/// 없다 (#433). 스낵바는 화면 아래에 잠깐 떴다 사라져 놓치기 쉬웠다.
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
/// [title] 은 `무엇이 안 됐는지`, [fallback] 은 `무엇을 하면 되는지`다. 둘을 두 줄
/// 문장으로 잇는다. [fallback] 이 이미 온전한 문장이면 [title] 을 비운다.
/// 서버가 문구를 줬으면 그 문구가 [fallback] 을 이긴다.
///
/// **식별자는 반드시 붙는다.** 서버 코드가 있으면 그것을, 없으면 [fallbackCode] 를
/// 문장 아래에 적는다. 사용자에게는 뜻이 없지만 제보를 받았을 때 추적할 유일한
/// 단서다 (docs 예외처리 규칙).
///
/// 앱이 스스로 끊은 요청([NetworkFault.cancelled])이면 **아무것도 띄우지 않는다** —
/// 사용자가 한 적 없는 실패를 보여주는 꼴이 된다.
Future<void> showFailure(
  BuildContext context,
  Object? error, {
  String? title,
  required String fallback,
  required String fallbackCode,
}) async {
  final failure = AppFailure.of(error);
  if (failure.isSilent) return;

  final l10n = context.l10n;
  await showElumDialog<void>(
    context: context,
    // 제목이 `무엇이 안 됐는지`를 이미 말하므로, 네트워크 안내가 있으면 할 일
    // 자리를 그 안내로 바꾼다. 둘을 잇으면 할 일이 두 개가 된다 (#428).
    title: failureSentence(
      title,
      title == null
          ? failure.bodyOr(fallback)
          : failure.serverMessage ?? failure.hint ?? fallback,
      stop: l10n.sentenceStop,
    ),
    code: failure.badgeOr(fallbackCode),
    icon: ElumDialogIcon.alert,
    actions: [
      ElumDialogAction(label: l10n.commonConfirm, tone: ElumDialogTone.danger),
    ],
  );
}

/// 제목과 할 일을 시안 문장 모양(`로그인하지 못했어요.\n잠시 후 다시 시도해주세요`)으로 잇는다.
///
/// 제목이 이미 문장부호로 끝나면 문장부호를 더하지 않는다 — `?` 뒤에 `.` 가 붙는다.
/// 전각 문장부호(`。！？`)도 문장 끝이다. 붙일 문장부호는 언어마다 달라 [stop] 으로 받는다.
@visibleForTesting
String failureSentence(String? title, String body, {String stop = '.'}) {
  if (title == null || title.isEmpty) return body;
  final ended = RegExp(r'[.!?。！？]$').hasMatch(title);
  return '${ended ? title : '$title$stop'}\n$body';
}
