import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import '../theme/theme_context_ext.dart';

/// 에러 코드 한 줄: 본문 아래 작은 회색 글 (#1171)
///
/// 실패 팝업([ElumDialogCard]) · 실패 화면([ElumErrorView]) · 화면 안 실패 안내가 모두 이 모양
/// `다시 시도` 버튼·링크 글 안에 괄호로 넣지 않음 (찾기 어렵고 버튼 문구가 길어짐)
class ElumErrorCodeText extends StatelessWidget {
  const ElumErrorCodeText(
    this.code, {
    super.key,
    this.textAlign = TextAlign.center,
  });

  /// 추적용 식별자 (`E-NET-OFFLINE` · 서버 코드 등)
  final String code;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      code,
      textAlign: textAlign,
      style: context.typo.bodySmall.paragraph.copyWith(
        color: context.colors.textSecondary,
      ),
    );
  }
}
