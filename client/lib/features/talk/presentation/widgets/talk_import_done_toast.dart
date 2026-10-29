import 'package:flutter/material.dart';

import '../../../../core/widgets/elum_toast.dart';

/// 가져오기 완료 토스트: 공통 토스트 + `보러 가기` 동작 (모양은 공통 토스트 한 곳이 정한다)
/// 화면을 옮기기 전에 잡아 둔 [messenger] 로 띄운다
void showTalkImportDoneToast(
  ScaffoldMessengerState? messenger, {
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
}) => showElumToastOn(
  messenger,
  message,
  actionLabel: actionLabel,
  onAction: onAction,
);
