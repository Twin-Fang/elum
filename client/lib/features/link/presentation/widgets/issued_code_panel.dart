import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_state_body.dart';
import '../../domain/link_status.dart';
import 'link_code_text.dart';

/// 발급된 코드를 보여 주는 덩어리 — 만드는 중 → 코드 → 남은 시간 → 다시 만들기 칩.
///
/// 연결 암호 만들기와 초대 코드 만들기가 같은 배치를 쓴다. 발급·타이머·폴링 같은
/// 화면별 로직은 각 화면이 들고, 이 위젯은 받은 값을 그리기만 한다.
/// 부모가 `crossAxisAlignment.stretch` 인 Column 이고 높이가 정해지지 않은 스크롤 안이라는
/// 전제다 — 그 자리에서 [ElumStateBody.loading] 은 스피너를 가운데에 그대로 둔다.
class IssuedCodePanel extends StatelessWidget {
  const IssuedCodePanel({
    super.key,
    required this.loading,
    required this.issued,
    required this.expiredLabel,
    required this.onRetry,
    this.retryLabel,
    this.showStatus = true,
    this.replacement,
    this.footer = const [],
  });

  /// 코드를 만드는 중. 스피너만 보인다.
  final bool loading;

  /// 발급된 코드. null 이면 코드 자리가 비어 있다.
  final IssuedLinkCode? issued;

  /// 만료됐을 때 남은 시간 자리에 쓰는 문구.
  final String expiredLabel;

  /// `다시 만들기` 칩 글자. null 이면 칩의 기본 문구다.
  final String? retryLabel;

  final VoidCallback? onRetry;

  /// 남은 시간과 다시 만들기 칩을 보일지. 연결되면 더 기다릴 이유가 없어 끈다.
  final bool showStatus;

  /// 있으면 코드 대신 이것을 보인다 (실패·빈 상태). 로딩이 우선한다.
  final Widget? replacement;

  /// 칩 아래에 이어 붙는 위젯. 앞에 간격이 필요하면 [timerToRetry] 를 쓴다.
  final List<Widget> footer;

  /// 설명 하단(227) → 코드 상단(299). 시안 `732:5656` 실측.
  static const descriptionToCode = 72.0;
  static const codeToTimer = 24.0;
  static const timerToRetry = 16.0;

  /// 암호 여섯 글자 사이 간격. 시안은 3-3으로 묶고 가운데를 더 벌린다
  /// (글자 좌표 0·47·100 | 164·211·258).
  static const codeLetterGap = 20.0;
  static const codeGroupGap = 40.0;

  /// 남은 시간 `MM:SS`. 올림이 아니라 **내림**이다 — 실제보다 길게 말하면 믿고 기다리다 만료된다.
  static String remainingLabel(IssuedLinkCode issued, String expiredLabel) {
    if (issued.isExpired) return expiredLabel;
    final total = issued.remaining().inSeconds;
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final issued = this.issued;
    final replacement = this.replacement;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: descriptionToCode.h),
        if (loading)
          const ElumStateBody.loading()
        else if (replacement != null)
          replacement
        else if (issued != null) ...[
          LinkCodeText(
            code: issued.code,
            dimmed: issued.isExpired,
            letterGap: codeLetterGap,
            groupGap: codeGroupGap,
          ),
          if (showStatus) ...[
            SizedBox(height: codeToTimer.h),
            Text(
              remainingLabel(issued, expiredLabel),
              textAlign: TextAlign.center,
              style: context.typo.linkTimer.copyWith(color: colors.linkTimer),
            ),
            SizedBox(height: timerToRetry.h),
            Center(child: LinkRetryChip(label: retryLabel, onTap: onRetry)),
            ...footer,
          ],
        ],
      ],
    );
  }
}
