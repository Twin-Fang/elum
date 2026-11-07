import 'package:flutter/material.dart';

import '../l10n/l10n_context.dart';
import 'elum_dialog.dart';

/// 위험 확인 팝업 위 아이콘 2개 (기준: [ElumDialogIcon] 문서)
enum ElumDangerIcon {
  /// 눈에 보이는 하나를 지움 (일과·카드·임시저장·녹음·글·댓글·메모) — 보호자 화면만
  trash,

  /// 지우는 것이 아닌 위험 (연결 끊기·로그아웃·탈퇴·그만두기·숨기기·잃는 나가기)
  alert,
}

/// 위험 동작 한 번 확인: 아이콘 + 제목 + (설명) + `취소`(회색) · 행동 이름(빨강). 누르면 true (#1171)
///
/// 확인 단계 기준 (docs/08-design-principles.md §5-6)
/// - 계정·이룸이 전체 데이터가 사라짐 > 이것 다음에 입력 확인(`confirmByTyping`) 한 단계 더
/// - 하나를 지우거나 되돌릴 수 있는 위험 > 이것 한 번
/// - 잃는 것 없음(묶음 풀기·임시저장 나가기) > 아이콘 없는 일반 팝업 (`showElumDialog`, 주 버튼)
/// [actionLabel] 은 `확인` 이 아니라 행동 이름 (`삭제` · `지우기` · `연결 끊기` · `탈퇴하기`)
/// 바깥 누름·뒤로가기 = 취소 (false)
Future<bool> confirmDangerousAction(
  BuildContext context, {
  required String title,
  required String actionLabel,
  required ElumDangerIcon icon,
  String? message,
  String? cancelLabel,
  bool keepWordsInMessage = false,
}) async {
  final isConfirmed = await showElumDialog<bool>(
    context: context,
    icon: switch (icon) {
      ElumDangerIcon.trash => ElumDialogIcon.trash,
      ElumDangerIcon.alert => ElumDialogIcon.alert,
    },
    title: title,
    message: message,
    keepWordsInMessage: keepWordsInMessage,
    actions: [
      ElumDialogAction(
        // 비우면 `취소` (만들기 흐름은 `계속 만들기`)
        label: cancelLabel ?? context.l10n.commonCancel,
        value: false,
        tone: ElumDialogTone.neutral,
      ),
      ElumDialogAction(
        label: actionLabel,
        value: true,
        tone: ElumDialogTone.danger,
      ),
    ],
  );
  return isConfirmed ?? false;
}
